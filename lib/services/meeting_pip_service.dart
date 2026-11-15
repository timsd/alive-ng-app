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
  bool? _lastMutedState;
  void Function(String action)? _onPipAction;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Registers the native callback that notifies Flutter whenever OS PiP mode
  /// starts or stops, or when the user taps an OS PiP RemoteAction button.
  void init(
    void Function(bool isInPipMode) onPipModeChanged, {
    void Function(String action)? onPipAction,
  }) {
    if (!_isAndroid) return;
    _onPipAction = onPipAction;
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipModeChanged') {
        final isPip = call.arguments == true;
        onPipModeChanged(isPip);
      } else if (call.method == 'onPipAction') {
        final action = call.arguments?.toString();
        if (action != null && action.isNotEmpty) {
          _onPipAction?.call(action);
        }
      }
    });
  }

  /// Tells Android whether a live meeting is currently connected so pressing
  /// Home / switching apps auto-enters Picture-in-Picture mode, and keeps the
  /// OS PiP Mute/Unmute RemoteAction icon in sync.
  Future<void> setMeetingActive(bool active, {bool? isMuted}) async {
    if (!_isAndroid) return;
    if (_lastActiveState == active &&
        (isMuted == null || _lastMutedState == isMuted)) {
      return;
    }
    _lastActiveState = active;
    if (isMuted != null) {
      _lastMutedState = isMuted;
    }
    try {
      await _channel.invokeMethod<bool>('setMeetingActive', {
        'active': active,
        if (isMuted != null) 'isMuted': isMuted,
      });
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
