import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bluetooth_sync_service.dart';
import 'collaboration_models.dart';
import 'finance_controller.dart';
import 'models.dart';

class CollaborationController extends ChangeNotifier {
  CollaborationController._(this._prefs, this._financeController);

  static const _profileKey = 'collab_profile_v1';
  static const _sessionKey = 'collab_session_v1';
  static const _pendingEventsKey = 'collab_pending_events_v1';

  final SharedPreferences _prefs;
  final FinanceController _financeController;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  late final BluetoothSyncService _bluetoothService;

  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSubscription;
  StreamSubscription<FinanceSyncEvent>? _syncSubscription;

  SignedInProfile? _profile;
  PairSession? _session;
  final List<FinanceSyncEvent> _pendingEvents = <FinanceSyncEvent>[];
  bool _googleConfigured = true;
  bool _loading = false;
  bool _applyingRemoteChange = false;
  bool _disposed = false;
  String _bluetoothStatusMessage = 'Bluetooth session is idle.';

  SignedInProfile? get profile => _profile;
  PairSession? get session => _session;
  bool get isSignedIn => _profile != null;
  bool get loading => _loading;
  bool get googleConfigured => _googleConfigured;
  int get pendingEventCount => _pendingEvents.length;
  List<FinanceSyncEvent> get pendingEvents => List.unmodifiable(_pendingEvents);
  String get bluetoothStatusMessage => _bluetoothStatusMessage;
  bool get bluetoothSupported => _bluetoothService.supported;

  static Future<CollaborationController> load(
    FinanceController financeController,
    {bool enableExternalServices = true}
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final controller = CollaborationController._(prefs, financeController);
    controller._bluetoothService = BluetoothSyncService(
      onStateChanged: controller._handleBluetoothStateChanged,
      onRemoteProfile: controller._handleRemoteProfile,
      onRemoteEvent: controller._handleRemoteEvent,
      onSyncRequest: controller._handleSyncRequest,
    );
    await controller._restore();
    if (enableExternalServices) {
      await controller._initializeGoogle();
    } else {
      controller._googleConfigured = false;
    }
    controller._listenForLocalChanges();
    return controller;
  }

  Future<void> _restore() async {
    final rawProfile = _prefs.getString(_profileKey);
    if (rawProfile != null && rawProfile.isNotEmpty) {
      _profile = SignedInProfile.fromJson(
        jsonDecode(rawProfile) as Map<String, dynamic>,
      );
    }
    final rawSession = _prefs.getString(_sessionKey);
    if (rawSession != null && rawSession.isNotEmpty) {
      _session = PairSession.fromJson(
        jsonDecode(rawSession) as Map<String, dynamic>,
      );
    }
    final rawEvents = _prefs.getStringList(_pendingEventsKey) ?? const <String>[];
    _pendingEvents.addAll(
      rawEvents.map(
        (event) => FinanceSyncEvent.fromJson(
          jsonDecode(event) as Map<String, dynamic>,
        ),
      ),
    );
  }

  Future<void> _persist() async {
    if (_profile == null) {
      await _prefs.remove(_profileKey);
    } else {
      await _prefs.setString(_profileKey, jsonEncode(_profile!.toJson()));
    }
    if (_session == null) {
      await _prefs.remove(_sessionKey);
    } else {
      await _prefs.setString(_sessionKey, jsonEncode(_session!.toJson()));
    }
    await _prefs.setStringList(
      _pendingEventsKey,
      _pendingEvents.map((event) => event.encode()).toList(),
    );
  }

  Future<void> _initializeGoogle() async {
    try {
      await _googleSignIn.initialize();
      _authSubscription = _googleSignIn.authenticationEvents.listen(
        _handleAuthEvent,
        onError: (_) {
          _googleConfigured = false;
          notifyListeners();
        },
      );
      await _googleSignIn.attemptLightweightAuthentication();
    } catch (_) {
      _googleConfigured = false;
      notifyListeners();
    }
  }

  void _handleAuthEvent(GoogleSignInAuthenticationEvent event) {
    final GoogleSignInAccount? account = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };
    _profile = account == null
        ? null
        : SignedInProfile(
            displayName: account.displayName ?? account.email,
            email: account.email,
            id: account.id,
            photoUrl: account.photoUrl,
          );

    if (_session != null) {
      _session = _session!.copyWith(localUser: _profile);
    }
    _persist();
    notifyListeners();
  }

  void _listenForLocalChanges() {
    _syncSubscription = _financeController.syncEvents.listen((event) async {
      if (_applyingRemoteChange) {
        return;
      }
      if (_session == null ||
          _session!.connectionState == PairConnectionState.disconnected) {
        return;
      }
      _pendingEvents.add(event);
      await _persist();
      await _flushPendingEvents();
      notifyListeners();
    });
  }

  Future<void> signIn() async {
    _loading = true;
    notifyListeners();
    try {
      await _googleSignIn.authenticate();
    } catch (_) {
      _googleConfigured = false;
    } finally {
      _loading = false;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _bluetoothService.stop();
    await _googleSignIn.signOut();
    _profile = null;
    _session = null;
    _pendingEvents.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> createSession() async {
    _session = PairSession(
      sessionCode: _generateSessionCode(),
      role: PairSessionRole.host,
      connectionState: PairConnectionState.advertising,
      createdAt: DateTime.now(),
      localUser: _profile,
    );
    await _bluetoothService.startHosting(sessionCode: _session!.sessionCode);
    await _persist();
    notifyListeners();
  }

  Future<void> joinSession(String code) async {
    _session = PairSession(
      sessionCode: code.trim().toUpperCase(),
      role: PairSessionRole.guest,
      connectionState: PairConnectionState.scanning,
      createdAt: DateTime.now(),
      localUser: _profile,
    );
    await _bluetoothService.startJoining(sessionCode: _session!.sessionCode);
    await _persist();
    notifyListeners();
  }

  Future<void> disconnectSession() async {
    await _bluetoothService.stop();
    _session = null;
    _pendingEvents.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> openBluetoothSettings() async {
    await _bluetoothService.showAppSettings();
  }

  Future<void> _handleRemoteEvent(
    FinanceSyncEvent event,
    SignedInProfile? remoteProfile,
  ) async {
    if (_disposed) return;
    final remoteData = FinanceData.fromJson(
      jsonDecode(event.snapshot) as Map<String, dynamic>,
    );
    _applyingRemoteChange = true;
    try {
      await _financeController.replaceAllData(
        remoteData,
        recordId: event.recordId,
      );
    } finally {
      _applyingRemoteChange = false;
    }
    if (_session != null) {
      _session = _session!.copyWith(
        remoteUser: remoteProfile ?? _session!.remoteUser,
        connectionState: PairConnectionState.paired,
        lastSyncedAt: DateTime.now(),
      );
      await _persist();
      notifyListeners();
    }
  }

  void _handleRemoteProfile(SignedInProfile profile) {
    if (_disposed) return;
    if (_session == null) {
      return;
    }
    _session = _session!.copyWith(remoteUser: profile);
    _persist();
    notifyListeners();
  }

  Future<void> _flushPendingEvents() async {
    if (_session == null ||
        _session!.connectionState != PairConnectionState.paired ||
        _pendingEvents.isEmpty) {
      return;
    }
    _session = _session!.copyWith(connectionState: PairConnectionState.syncing);
    notifyListeners();
    final sentEvents = <FinanceSyncEvent>[];
    for (final event in List<FinanceSyncEvent>.from(_pendingEvents)) {
      try {
        await _bluetoothService.sendSyncEvent(event, profile: _profile);
        sentEvents.add(event);
      } catch (_) {
        break;
      }
    }
    _pendingEvents.removeWhere((event) => sentEvents.contains(event));
    if (_session != null) {
      _session = _session!.copyWith(
        connectionState: PairConnectionState.paired,
        lastSyncedAt: sentEvents.isEmpty ? _session!.lastSyncedAt : DateTime.now(),
      );
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _handleSyncRequest() async {
    if (_disposed || _session == null) return;
    await _bluetoothService.sendSyncEvent(
      FinanceSyncEvent(
        id: _generateSessionCode(),
        entityType: SyncEntityType.settings,
        actionType: SyncActionType.replaced,
        recordId: 'full-sync',
        timestamp: DateTime.now(),
        snapshot: _financeController.data.encode(),
      ),
      profile: _profile,
    );
    if (_session != null) {
      _session = _session!.copyWith(
        connectionState: PairConnectionState.paired,
        lastSyncedAt: DateTime.now(),
      );
      await _persist();
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  Future<void> _handleBluetoothStateChanged(
    PairConnectionState state,
    String message,
  ) async {
    if (_disposed) return;
    _bluetoothStatusMessage = message;
    if (_session != null) {
      final previousState = _session!.connectionState;
      _session = _session!.copyWith(connectionState: state);
      final becamePaired =
          state == PairConnectionState.paired &&
          previousState != PairConnectionState.paired &&
          previousState != PairConnectionState.syncing;
      if (becamePaired) {
        if (_session!.role == PairSessionRole.host) {
          await _handleSyncRequest();
        } else {
          if (_profile != null) {
            await _bluetoothService.sendProfile(_profile!);
          }
          await _bluetoothService.requestFullSync();
        }
        await _flushPendingEvents();
      }
      await _persist();
    }
    if (!_disposed) {
      notifyListeners();
    }
  }

  String _generateSessionCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(
      6,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    _syncSubscription?.cancel();
    unawaited(_bluetoothService.dispose());
    super.dispose();
  }
}
