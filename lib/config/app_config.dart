import 'package:flutter/foundation.dart';

/// Global app configuration toggles.
class AppConfig {
  /// Live mode disables placeholder content and requires real data.
  static bool isLiveMode = false;

  /// When true, only use local Bible assets/database, no remote APIs.
  static const bool useLocalBibleOnly = true;

  /// Helper to detect development environment where certain services can be disabled.
  static bool get isWebDev => kIsWeb;

  /// In production, admin preview is strictly disabled; role-based access control is enforced.
  static bool get isAdminPreviewMode => false;

  /// Toggle live mode
  static void toggleLiveMode() {
    isLiveMode = !isLiveMode;
  }

  /// In production, toggling admin preview is a no-op
  static Future<void> toggleAdminPreviewMode() async {}
}
