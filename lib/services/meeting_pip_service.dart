import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges Flutter active-meeting state with Android Picture-in-Picture (PiP)
/// so minimizing the app during a live ALIVE Meet session transitions into a
/// floating system overlay window (like Zoom / Google Meet).
class MeetingPipService {
  MeetingPipService._();

  static final MeetingPipService instance = MeetingPipService._();
  static const MethodChannel _channel =
      MethodChannel('com.alive.alivengandroidapp/pip');

  bool _initialized = false;
  bool? _lastActiveState;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Registers the native callback that notifies Flutter whenever OS PiP mode
  /// starts or stops.
  void init(void Function(bool isInPipMode) onPipModeChanged) {
    if (!_isAndroid || _initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipModeChanged') {
        final isPip = call.arguments == true;
        onPipModeChanged(isPip);
      }
    });
  }

  /// Tells Android whether a live meeting is currently connected so pressing
  /// Home / switching apps auto-enters Picture-in-Picture mode.
  Future<void> setMeetingActive(bool active) async {
    if (!_isAndroid || _lastActiveState == active) return;
    _lastActiveState = active;
    try {
      await _channel.invokeMethod<bool>('setMeetingActive', {'active': active});
    } on MissingPluginException {
      // Ignored in tests or unsupported runners.
    } on PlatformException {
      // Ignored if Activity is detaching.
    }
  }

  /// Explicitly requests entering OS Picture-in-Picture mode if supported.
  Future<bool> enterPipMode() async {
    if (!_isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('enterPipMode');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
