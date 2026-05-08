import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/foundation.dart';

import 'collaboration_models.dart';

void _hfBleLog(String message) {
  if (kDebugMode) {
    debugPrint('[HF_BLE] $message');
  }
}

typedef BluetoothStateCallback =
    void Function(PairConnectionState state, String message);
typedef BluetoothRemoteProfileCallback =
    void Function(SignedInProfile profile);
typedef BluetoothRemoteEventCallback =
    Future<void> Function(FinanceSyncEvent event, SignedInProfile? remoteProfile);
typedef BluetoothSyncRequestCallback = Future<void> Function();

class BluetoothSyncService {
  BluetoothSyncService({
    required BluetoothStateCallback onStateChanged,
    required BluetoothRemoteProfileCallback onRemoteProfile,
    required BluetoothRemoteEventCallback onRemoteEvent,
    required BluetoothSyncRequestCallback onSyncRequest,
  })  : _onStateChanged = onStateChanged,
        _onRemoteProfile = onRemoteProfile,
        _onRemoteEvent = onRemoteEvent,
        _onSyncRequest = onSyncRequest;

  static final UUID _serviceUuid =
      UUID.fromString('6E5644F5-6A28-4DA3-B25C-100C1F0A4D01');
  static final UUID _syncCharacteristicUuid =
      UUID.fromString('6E5644F5-6A28-4DA3-B25C-100C1F0A4D02');

  final BluetoothStateCallback _onStateChanged;
  final BluetoothRemoteProfileCallback _onRemoteProfile;
  final BluetoothRemoteEventCallback _onRemoteEvent;
  final BluetoothSyncRequestCallback _onSyncRequest;

  final Map<String, _InboundMessageBuffer> _inboundBuffers =
      <String, _InboundMessageBuffer>{};

  CentralManager? _centralManager;
  PeripheralManager? _peripheralManager;
  StreamSubscription<dynamic>? _centralStateSubscription;
  StreamSubscription<dynamic>? _peripheralStateSubscription;
  StreamSubscription<dynamic>? _discoveredSubscription;
  StreamSubscription<dynamic>? _connectionStateSubscription;
  StreamSubscription<dynamic>? _notifySubscription;
  StreamSubscription<dynamic>? _writeRequestSubscription;
  StreamSubscription<dynamic>? _notifyStateSubscription;

  Peripheral? _connectedPeripheral;
  Central? _connectedCentral;
  GATTCharacteristic? _connectedCharacteristic;
  GATTCharacteristic? _localSyncCharacteristic;
  String? _activeSessionCode;
  String _statusMessage = 'Bluetooth session is idle.';
  bool _initialized = false;
  bool _supported = true;

  bool get supported => _supported;
  bool get isConnected =>
      _connectedCharacteristic != null &&
      (_connectedPeripheral != null || _connectedCentral != null);
  String get statusMessage => _statusMessage;

  Future<void> startHosting({required String sessionCode}) async {
    _hfBleLog('startHosting session=$sessionCode');
    final ready = await _ensureInitialized(requirePeripheral: true);
    if (!ready || _peripheralManager == null) {
      _hfBleLog('startHosting aborted (not ready or no peripheral)');
      return;
    }
    await stop();
    _activeSessionCode = sessionCode;
    _connectedCentral = null;
    _connectedCharacteristic = null;
    _localSyncCharacteristic = GATTCharacteristic.mutable(
      uuid: _syncCharacteristicUuid,
      properties: const [
        GATTCharacteristicProperty.read,
        GATTCharacteristicProperty.write,
        GATTCharacteristicProperty.writeWithoutResponse,
        GATTCharacteristicProperty.notify,
        GATTCharacteristicProperty.indicate,
      ],
      permissions: const [
        GATTCharacteristicPermission.read,
        GATTCharacteristicPermission.write,
      ],
      descriptors: const [],
    );
    await _peripheralManager!.removeAllServices();
    final service = GATTService(
      uuid: _serviceUuid,
      isPrimary: true,
      includedServices: const [],
      characteristics: [_localSyncCharacteristic!],
    );
    await _peripheralManager!.addService(service);
    final advertisement = Advertisement(
      name: _advertisementName(sessionCode),
      serviceUUIDs: [_serviceUuid],
    );
    await _peripheralManager!.startAdvertising(advertisement);
    _hfBleLog('advertising as ${_advertisementName(sessionCode)}');
    _setState(
      PairConnectionState.advertising,
      'Hosting Bluetooth session $sessionCode. Ask the second device to join with this code.',
    );
  }

  Future<void> startJoining({required String sessionCode}) async {
    _hfBleLog('startJoining session=$sessionCode');
    final ready = await _ensureInitialized();
    if (!ready || _centralManager == null) {
      _hfBleLog('startJoining aborted (not ready or no central)');
      return;
    }
    await stop();
    _activeSessionCode = sessionCode;
    _connectedPeripheral = null;
    _connectedCharacteristic = null;
    await _centralManager!.startDiscovery(serviceUUIDs: [_serviceUuid]);
    _hfBleLog('discovery started for ${_advertisementName(sessionCode)}');
    _setState(
      PairConnectionState.scanning,
      'Searching for Bluetooth session $sessionCode.',
    );
  }

  Future<void> sendProfile(SignedInProfile profile) async {
    await _sendLogicalMessage(
      <String, dynamic>{
        'kind': 'hello',
        'profile': profile.toJson(),
      },
    );
  }

  Future<void> requestFullSync() async {
    await _sendLogicalMessage(
      <String, dynamic>{
        'kind': 'sync_request',
      },
    );
  }

  Future<void> sendSyncEvent(
    FinanceSyncEvent event, {
    SignedInProfile? profile,
  }) async {
    await _sendLogicalMessage(
      <String, dynamic>{
        'kind': 'sync',
        'profile': profile?.toJson(),
        'event': event.toJson(),
      },
    );
  }

  Future<void> showAppSettings() async {
    try {
      if (_centralManager != null) {
        await _centralManager!.showAppSettings();
        return;
      }
      if (_peripheralManager != null) {
        await _peripheralManager!.showAppSettings();
      }
    } catch (_) {
      // Best effort only.
    }
  }

  Future<void> stop() async {
    _activeSessionCode = null;
    final connectedPeripheral = _connectedPeripheral;
    _connectedPeripheral = null;
    _connectedCentral = null;
    _connectedCharacteristic = null;
    _inboundBuffers.clear();
    try {
      await _centralManager?.stopDiscovery();
    } catch (_) {}
    try {
      if (connectedPeripheral != null) {
        await _centralManager?.disconnect(connectedPeripheral);
      }
    } catch (_) {}
    try {
      await _peripheralManager?.stopAdvertising();
    } catch (_) {}
    _setState(PairConnectionState.disconnected, 'Bluetooth session disconnected.');
  }

  Future<void> dispose() async {
    await stop();
    await _centralStateSubscription?.cancel();
    await _peripheralStateSubscription?.cancel();
    await _discoveredSubscription?.cancel();
    await _connectionStateSubscription?.cancel();
    await _notifySubscription?.cancel();
    await _writeRequestSubscription?.cancel();
    await _notifyStateSubscription?.cancel();
  }

  Future<bool> _ensureInitialized({bool requirePeripheral = false}) async {
    if (_initialized) {
      if (requirePeripheral && _peripheralManager == null) {
        _setUnsupportedMessage();
        return false;
      }
      return _supported;
    }

    if (kIsWeb) {
      _setUnsupportedMessage();
      return false;
    }

    try {
      _centralManager = CentralManager();
    } catch (_) {
      _supported = false;
    }
    try {
      _peripheralManager = PeripheralManager();
    } catch (_) {
      if (requirePeripheral) {
        _supported = false;
      }
    }

    if (_centralManager == null || (requirePeripheral && _peripheralManager == null)) {
      _setUnsupportedMessage();
      _initialized = true;
      return false;
    }

    await _listenToManagerState();
    _listenToCentralEvents();
    _listenToPeripheralEvents();
    _initialized = true;
    return true;
  }

  Future<void> _listenToManagerState() async {
    _centralStateSubscription = _centralManager?.stateChanged.listen((event) async {
      if (Platform.isAndroid &&
          event.state == BluetoothLowEnergyState.unauthorized) {
        try {
          await _centralManager?.authorize();
        } catch (_) {}
      }
    });
    _peripheralStateSubscription =
        _peripheralManager?.stateChanged.listen((event) async {
      if (Platform.isAndroid &&
          event.state == BluetoothLowEnergyState.unauthorized) {
        try {
          await _peripheralManager?.authorize();
        } catch (_) {}
      }
    });
  }

  void _listenToCentralEvents() {
    _discoveredSubscription = _centralManager?.discovered.listen((event) async {
      final code = _activeSessionCode;
      if (code == null) return;
      if (event.advertisement.name != _advertisementName(code)) {
        return;
      }
      _hfBleLog('discovered peer name=${event.advertisement.name}');
      try {
        await _centralManager?.stopDiscovery();
      } catch (_) {}
      _connectedPeripheral = event.peripheral;
      _setState(
        PairConnectionState.scanning,
        'Bluetooth device found for session $code. Connecting now.',
      );
      await _connectToHostPeripheral(event.peripheral);
    });

    _connectionStateSubscription =
        _centralManager?.connectionStateChanged.listen((event) async {
      if (_connectedPeripheral == null || event.peripheral != _connectedPeripheral) {
        return;
      }
      if (event.state == ConnectionState.connected) {
        _setState(
          PairConnectionState.scanning,
          'Connected to host device. Preparing shared finance sync.',
        );
      } else {
        _connectedCharacteristic = null;
        _setState(
          PairConnectionState.disconnected,
          'Bluetooth connection ended.',
        );
      }
    });

    _notifySubscription = _centralManager?.characteristicNotified.listen((event) async {
      if (_connectedCharacteristic == null ||
          event.characteristic.uuid != _connectedCharacteristic!.uuid) {
        return;
      }
      await _receiveChunk(event.value);
    });
  }

  void _listenToPeripheralEvents() {
    _writeRequestSubscription =
        _peripheralManager?.characteristicWriteRequested.listen((event) async {
      if (_localSyncCharacteristic == null ||
          event.characteristic.uuid != _localSyncCharacteristic!.uuid) {
        return;
      }
      _connectedCentral = event.central;
      try {
        await _peripheralManager?.respondWriteRequest(event.request);
      } catch (_) {}
      await _receiveChunk(event.request.value);
    });

    _notifyStateSubscription =
        _peripheralManager?.characteristicNotifyStateChanged.listen((event) {
      if (_localSyncCharacteristic == null ||
          event.characteristic.uuid != _localSyncCharacteristic!.uuid) {
        return;
      }
      if (event.state) {
        _connectedCentral = event.central;
        _connectedCharacteristic = _localSyncCharacteristic;
        _setState(
          PairConnectionState.paired,
          'Second device connected. Shared finance data is live.',
        );
      }
    });
  }

  Future<void> _connectToHostPeripheral(Peripheral peripheral) async {
    _hfBleLog('connecting to peripheral');
    await _centralManager?.connect(peripheral);
    if (Platform.isAndroid) {
      try {
        await _centralManager?.requestMTU(peripheral, mtu: 517);
        _hfBleLog('MTU request sent');
      } catch (e) {
        _hfBleLog('MTU request failed: $e');
      }
    }
    final services = await _centralManager!.discoverGATT(peripheral);
    _hfBleLog('GATT services count=${services.length}');
    for (final service in services) {
      if (service.uuid != _serviceUuid) continue;
      for (final characteristic in service.characteristics) {
        if (characteristic.uuid != _syncCharacteristicUuid) continue;
        _connectedCharacteristic = characteristic;
        await _centralManager!.setCharacteristicNotifyState(
          peripheral,
          characteristic,
          state: true,
        );
        _setState(
          PairConnectionState.paired,
          'Connected to host device. Finance updates will sync in real time.',
        );
        return;
      }
    }
    _hfBleLog('sync service/characteristic not found after discovery');
    _setState(
      PairConnectionState.disconnected,
      'Connected to device, but the finance sync service was not found.',
    );
  }

  Future<void> _sendLogicalMessage(Map<String, dynamic> payload) async {
    if (_connectedCharacteristic == null) {
      _hfBleLog('send skipped: no characteristic');
      return;
    }
    final encoded = utf8.encode(jsonEncode(payload));
    final messageId = DateTime.now().microsecondsSinceEpoch.toString();
    final chunks = await _chunkPayload(encoded);
    if (chunks.isEmpty) {
      _hfBleLog('send skipped: empty chunks');
      return;
    }
    _hfBleLog('send kind=${payload['kind']} chunks=${chunks.length} bytes=${encoded.length}');
    for (var index = 0; index < chunks.length; index++) {
      final envelope = <String, dynamic>{
        'messageId': messageId,
        'index': index,
        'total': chunks.length,
        'data': base64Encode(chunks[index]),
      };
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
      if (_connectedPeripheral != null) {
        await _centralManager!.writeCharacteristic(
          _connectedPeripheral!,
          _connectedCharacteristic!,
          value: bytes,
          type: GATTCharacteristicWriteType.withResponse,
        );
      } else if (_connectedCentral != null) {
        await _peripheralManager!.notifyCharacteristic(
          _connectedCentral!,
          _connectedCharacteristic!,
          value: bytes,
        );
      }
    }
  }

  Future<List<Uint8List>> _chunkPayload(List<int> bytes) async {
    final maxLength = await _maxPayloadLength();
    final chunks = <Uint8List>[];
    var offset = 0;
    while (offset < bytes.length) {
      final end = (offset + maxLength < bytes.length)
          ? offset + maxLength
          : bytes.length;
      chunks.add(Uint8List.fromList(bytes.sublist(offset, end)));
      offset = end;
    }
    return chunks;
  }

  Future<int> _maxPayloadLength() async {
    const envelopeOverhead = 140;
    if (_connectedPeripheral != null) {
      final maximum = await _centralManager!.getMaximumWriteLength(
        _connectedPeripheral!,
        type: GATTCharacteristicWriteType.withResponse,
      );
      return (maximum - envelopeOverhead).clamp(32, 320);
    }
    if (_connectedCentral != null) {
      final maximum = await _peripheralManager!.getMaximumNotifyLength(
        _connectedCentral!,
      );
      return (maximum - envelopeOverhead).clamp(32, 320);
    }
    return 160;
  }

  Future<void> _receiveChunk(Uint8List rawValue) async {
    final decoded = jsonDecode(utf8.decode(rawValue)) as Map<String, dynamic>;
    final messageId = decoded['messageId'] as String;
    final index = decoded['index'] as int;
    final total = decoded['total'] as int;
    final bytes = base64Decode(decoded['data'] as String);
    final buffer = _inboundBuffers.putIfAbsent(
      messageId,
      () => _InboundMessageBuffer(total),
    );
    buffer.add(index, bytes);
    if (!buffer.isComplete) {
      return;
    }
    _inboundBuffers.remove(messageId);
    final payload = jsonDecode(utf8.decode(buffer.toBytes())) as Map<String, dynamic>;
    final kind = payload['kind'] as String? ?? 'sync';
    final remoteProfileJson = payload['profile'] as Map<String, dynamic>?;
    final remoteProfile = remoteProfileJson == null
        ? null
        : SignedInProfile.fromJson(remoteProfileJson);
    if (remoteProfile != null) {
      _onRemoteProfile(remoteProfile);
    }
    if (kind == 'sync') {
      final event = FinanceSyncEvent.fromJson(
        payload['event'] as Map<String, dynamic>,
      );
      await _onRemoteEvent(event, remoteProfile);
      _setState(
        PairConnectionState.paired,
        'Finance data synced with the connected device.',
      );
    } else if (kind == 'sync_request') {
      await _onSyncRequest();
    }
  }

  void _setUnsupportedMessage() {
    _supported = false;
    _setState(
      PairConnectionState.disconnected,
      'Bluetooth hosting is not available on this platform yet.',
    );
  }

  void _setState(PairConnectionState state, String message) {
    _statusMessage = message;
    _onStateChanged(state, message);
  }

  String _advertisementName(String code) => 'HF-$code';
}

class _InboundMessageBuffer {
  _InboundMessageBuffer(this.total) : _parts = List<Uint8List?>.filled(total, null);

  final int total;
  final List<Uint8List?> _parts;

  bool get isComplete => _parts.every((part) => part != null);

  void add(int index, Uint8List value) {
    if (index < 0 || index >= total) return;
    _parts[index] = value;
  }

  Uint8List toBytes() {
    final builder = BytesBuilder(copy: false);
    for (final part in _parts) {
      if (part != null) {
        builder.add(part);
      }
    }
    return builder.toBytes();
  }
}
