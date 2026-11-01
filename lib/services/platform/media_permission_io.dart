import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Mobile / Desktop (IO) implementation using `permission_handler`.
Future<bool> requestMediaPermissions() async {
  try {
    final statuses = await [
      Permission.microphone,
      Permission.camera,
    ].request();
    debugPrint('[IOMediaPermission] Direct permissions requested: $statuses');
    return statuses[Permission.microphone]?.isGranted == true ||
        statuses[Permission.camera]?.isGranted == true;
  } catch (e) {
    debugPrint('[IOMediaPermission] Permission request note: $e');
  }
  return false;
}

