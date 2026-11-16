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
  bool? _lastVideoActiveState;
  bool? _lastVideoVerticalState;
  void Function(bool isInPipMode)? _onPipModeChanged;
  void Function(String action)? _onPipAction;

  /// Broadcasts OS Picture-in-Picture state to any active player (meeting or video).
  final ValueNotifier<bool> isInPipModeNotifier = ValueNotifier<bool>(false);

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Registers the native callback that notifies Flutter whenever OS PiP mode
  /// starts or stops, or when the user taps an OS PiP RemoteAction button.
  void init(
    void Function(bool isInPipMode) onPipModeChanged, {
    void Function(String action)? onPipAction,
  }) {
    if (!_isAndroid) return;
    _onPipModeChanged = onPipModeChanged;
    _onPipAction = onPipAction;
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipModeChanged') {
        final isPip = call.arguments == true;
        isInPipModeNotifier.value = isPip;
        _onPipModeChanged?.call(isPip);
      } else if (call.method == 'onPipAction') {
        final action = call.arguments?.toString();
        if (action != null && action.isNotEmpty) {
          _onPipAction?.call(action);
        }
      }
    });
  }

  /// Ensures the native PiP channel listener is active even outside meetings
  /// (e.g., when playing a video in [StandardVideoPlayerModal]).
  void ensureListenerRegistered() {
    if (!_isAndroid || _initialized) return;
    init((_) {});
  }

  /// Tells Android whether a video player is actively playing so minimizing the
  /// app enters OS Picture-in-Picture mode in 16:9 (landscape) or 9:16 (portrait).
  Future<void> setVideoPipState(bool active, {bool isVertical = false}) async {
    if (!_isAndroid) return;
    ensureListenerRegistered();
    if (_lastVideoActiveState == active &&
        _lastVideoVerticalState == isVertical) {
      return;
    }
    _lastVideoActiveState = active;
    _lastVideoVerticalState = isVertical;
    try {
      await _channel.invokeMethod<bool>('setVideoPipState', {
        'active': active,
        'isVertical': isVertical,
      });
    } on MissingPluginException {
      // Ignored in tests or unsupported runners.
    } on PlatformException {
      // Ignored if Activity is detaching.
    }
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

  /// Starts the Android `mediaProjection` foreground service required on
  /// Android 14+ before requesting screen capture, and temporarily suppresses
  /// auto-PiP while the system screen-share permission prompt is shown.
  Future<void> startScreenShareService() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('startScreenShareService');
    } on MissingPluginException {
      // Ignored in tests or unsupported runners.
    } on PlatformException {
      // Handled by caller if MediaProjection fails.
    }
  }

  /// Stops the Android `mediaProjection` foreground service when screen sharing ends.
  Future<void> stopScreenShareService() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('stopScreenShareService');
    } on MissingPluginException {
      // Ignored in tests or unsupported runners.
    } on PlatformException {
      // Ignored if Activity is detaching.
    }
  }

  /// Clears/sets the flag suppressing auto-PiP during the screen-share consent prompt.
  Future<void> setRequestingScreenShare(bool requesting) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('setRequestingScreenShare', {
        'requesting': requesting,
      });
    } on MissingPluginException {
      // Ignored in tests.
    } on PlatformException {
      // Ignored if Activity is detaching.
    }
  }
}
