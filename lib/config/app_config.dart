import 'package:flutter/foundation.dart';
import 'development_config.dart';

/// Global app configuration toggles.
class AppConfig {
  /// Live mode disables placeholder content and requires real data.
  static bool isLiveMode = false;
  
  /// When true, only use local Bible assets/database, no remote APIs.
  static const bool useLocalBibleOnly = true;

  /// Helper to detect development environment where certain services can be disabled.
  static bool get isWebDev => kIsWeb;
  
  /// When true, admin preview mode is enabled
  static bool get isAdminPreviewMode => DevelopmentConfig.isAdminPreviewEnabled;
  
  /// Toggle live mode
  static void toggleLiveMode() {
    isLiveMode = !isLiveMode;
  }
  
  /// Toggle admin preview mode
  static Future<void> toggleAdminPreviewMode() async {
    await DevelopmentConfig.setAdminPreviewEnabled(!DevelopmentConfig.isAdminPreviewEnabled);
  }
}