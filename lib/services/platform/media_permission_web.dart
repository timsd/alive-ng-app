import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Web implementation using browser `window.navigator.mediaDevices.getUserMedia`.
/// Triggers the native browser camera and microphone permission prompt immediately.
/// Gracefully falls back to audio-only if camera hardware is unavailable or blocked.
Future<bool> requestMediaPermissions() async {
  try {
    final mediaDevices = web.window.navigator.mediaDevices;
    web.MediaStream? stream;
    try {
      // Try audio + video upfront
      stream = await mediaDevices
          .getUserMedia(
              web.MediaStreamConstraints(audio: true.toJS, video: true.toJS))
          .toDart;
    } catch (e) {
      debugPrint(
          '[WebMediaPermission] Video/Audio combo unavailable ($e). Falling back to audio-only.');
      try {
        // Fall back to microphone only
        stream = await mediaDevices
            .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
            .toDart;
      } catch (audioErr) {
        debugPrint(
            '[WebMediaPermission] Audio-only permission request failed: $audioErr');
      }
    }

    if (stream != null) {
      // Release test tracks so device hardware is completely freed for LiveKit WebRTC
      for (final track in stream.getTracks().toDart) {
        try {
          track.stop();
        } catch (_) {}
      }
      debugPrint('[WebMediaPermission] Media permissions successfully initialized');
      return true;
    }
  } catch (e) {
    debugPrint('[WebMediaPermission] Note (falling back to listen-only mode): $e');
  }
  return false;
}


