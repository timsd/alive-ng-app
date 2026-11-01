import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Web implementation using browser `window.navigator.mediaDevices.getUserMedia`.
/// Triggers the native browser camera and microphone permission prompt immediately.
Future<bool> requestMediaPermissions() async {
  try {
    final mediaDevices = html.window.navigator.mediaDevices;
    if (mediaDevices != null) {
      final stream = await mediaDevices.getUserMedia({'audio': true, 'video': true});
      // Release test tracks so device hardware is completely freed for LiveKit
      for (final track in stream.getTracks()) {
        try {
          track.stop();
        } catch (_) {}
      }
      debugPrint('[WebMediaPermission] Camera & microphone permissions granted by browser');
      return true;
    }
  } catch (e) {
    debugPrint('[WebMediaPermission] Note (falling back to listen-only mode): $e');
  }
  return false;
}

