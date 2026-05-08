import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'finance_controller.dart';

class AndroidSmsImportController extends ChangeNotifier {
  AndroidSmsImportController._(this._financeController);

  static const _methodChannel = MethodChannel('home_finance/sms_methods');
  static const _eventChannel = EventChannel('home_finance/sms_events');

  final FinanceController _financeController;
  StreamSubscription<dynamic>? _subscription;

  bool _isSupported = false;
  bool _hasPermission = false;
  bool _isLoading = false;
  String _statusMessage = 'SMS auto-import is available on Android only.';

  bool get isSupported => _isSupported;
  bool get hasPermission => _hasPermission;
  bool get isLoading => _isLoading;
  String get statusMessage => _statusMessage;

  static Future<AndroidSmsImportController> load(
    FinanceController financeController,
    {bool enablePlatformIntegration = true}
  ) async {
    final controller = AndroidSmsImportController._(financeController);
    if (enablePlatformIntegration) {
      await controller.initialize();
    } else {
      controller._isSupported = false;
      controller._hasPermission = false;
      controller._statusMessage = 'SMS auto-import is disabled in tests.';
    }
    return controller;
  }

  Future<void> initialize() async {
    _isSupported = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (!_isSupported) {
      _statusMessage = 'SMS auto-import is available on Android only.';
      notifyListeners();
      return;
    }
    _isLoading = true;
    notifyListeners();
    try {
      _hasPermission =
          (await _methodChannel.invokeMethod<bool>('hasSmsPermissions')) ?? false;
      await _consumePendingMessages();
      await _configureStream();
      _statusMessage = _hasPermission
          ? 'Auto-import is active for new SMS messages.'
          : 'Enable SMS permission to auto-import bank messages.';
    } on MissingPluginException {
      _isSupported = false;
      _statusMessage = 'Android SMS bridge is not available in this build.';
    } on PlatformException catch (error) {
      _statusMessage = error.message ?? 'Unable to initialize SMS import.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> requestPermissions() async {
    if (!_isSupported) return;
    _isLoading = true;
    notifyListeners();
    try {
      _hasPermission =
          (await _methodChannel.invokeMethod<bool>('requestSmsPermissions')) ??
              false;
      await _consumePendingMessages();
      await _configureStream();
      _statusMessage = _hasPermission
          ? 'SMS permission granted. New SMS messages will import automatically.'
          : 'SMS permission was not granted.';
    } on MissingPluginException {
      _statusMessage = 'Android SMS bridge is not available in this build.';
    } on PlatformException catch (error) {
      _statusMessage = error.message ?? 'Unable to request SMS permission.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshStatus() async {
    if (!_isSupported) return;
    try {
      _hasPermission =
          (await _methodChannel.invokeMethod<bool>('hasSmsPermissions')) ?? false;
      await _consumePendingMessages();
      await _configureStream();
      _statusMessage = _hasPermission
          ? 'Auto-import is active for new SMS messages.'
          : 'Enable SMS permission to auto-import bank messages.';
    } on MissingPluginException {
      _statusMessage = 'Android SMS bridge is not available in this build.';
    }
    notifyListeners();
  }

  Future<void> _configureStream() async {
    await _subscription?.cancel();
    if (!_hasPermission) return;
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (event) => _handleIncomingEvent(event),
      onError: (Object error) {
        _statusMessage = 'SMS stream error: $error';
        notifyListeners();
      },
    );
  }

  Future<void> _consumePendingMessages() async {
    if (!_isSupported) return;
    final rawList = await _methodChannel.invokeMethod<List<dynamic>>(
      'consumePendingSms',
    );
    if (rawList == null) return;
    for (final item in rawList) {
      await _handleIncomingEvent(item);
    }
  }

  Future<void> _handleIncomingEvent(dynamic event) async {
    if (event is! Map) return;
    final map = Map<String, dynamic>.from(event.cast<String, dynamic>());
    final body = (map['body'] as String? ?? '').trim();
    if (body.isEmpty) return;
    final timestamp = (map['timestamp'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;
    final messageId = (map['messageId'] as String? ?? '').trim();
    final sender = (map['sender'] as String? ?? '').trim();
    await _financeController.autoImportSmsExpense(
      messageId: messageId.isEmpty
          ? '${timestamp}_${body.hashCode}'
          : messageId,
      rawMessage: body,
      sender: sender,
      receivedAt: DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
