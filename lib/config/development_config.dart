/// Development configuration for bypassing security checks
/// WARNING: This should ONLY be used in development mode
/// Runtime overrides are persisted using SharedPreferences in non-release builds.
library;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DevelopmentConfig {
  // Preference keys
  static const String _prefBypassRoleGuardsKey = 'dev_bypass_role_guards';
  static const String _prefAdminPreviewKey = 'dev_enable_admin_preview';

  // Default values for development builds
  static const bool _defaultBypassRoleGuards = false;
  static const bool _defaultAdminPreview = false;

  // Runtime state (non-release only)
  static bool _bypassRoleGuards = _defaultBypassRoleGuards;
  static bool _adminPreviewEnabled = _defaultAdminPreview;

  /// Check if we consider this development mode (non-release + any dev flag)
  static bool get isDevelopmentMode => !kReleaseMode && (
        _bypassRoleGuards || _adminPreviewEnabled
      );

  /// Check if role guards should be bypassed
  static bool get shouldBypassRoleGuards => false; // Strict security: never bypass role guards

  /// Check if admin preview is enabled
  static bool get isAdminPreviewEnabled => false; // Strict security: disabled by default

  /// Initialize runtime values from SharedPreferences (no-op in release mode)
  static Future<void> initializeFromPrefs() async {
    if (kReleaseMode) return; // Never enable in release builds
    try {
      final prefs = await SharedPreferences.getInstance();
      _bypassRoleGuards = prefs.getBool(_prefBypassRoleGuardsKey) ?? _defaultBypassRoleGuards;
      _adminPreviewEnabled = prefs.getBool(_prefAdminPreviewKey) ?? _defaultAdminPreview;
    } catch (e) {
      // Fallback to defaults in case of error
      _bypassRoleGuards = _defaultBypassRoleGuards;
      _adminPreviewEnabled = _defaultAdminPreview;
    }
  }

  /// Enable/disable role guard bypass (persisted for dev builds)
  static Future<void> setBypassRoleGuards(bool value) async {
    if (kReleaseMode) return; // Disallow changing in release builds
    _bypassRoleGuards = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefBypassRoleGuardsKey, value);
    } catch (_) {}
  }

  /// Enable/disable admin preview (persisted for dev builds)
  static Future<void> setAdminPreviewEnabled(bool value) async {
    if (kReleaseMode) return; // Disallow changing in release builds
    _adminPreviewEnabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefAdminPreviewKey, value);
    } catch (_) {}
  }

  /// Reset overrides back to defaults for dev builds
  static Future<void> resetToDefaults() async {
    if (kReleaseMode) return;
    _bypassRoleGuards = _defaultBypassRoleGuards;
    _adminPreviewEnabled = _defaultAdminPreview;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefBypassRoleGuardsKey);
      await prefs.remove(_prefAdminPreviewKey);
    } catch (_) {}
  }

  /// Log development mode warnings
  static void logDevelopmentWarning(String feature) {
    if (!kReleaseMode && isDevelopmentMode) {
      // Avoid spamming logs in release mode
      debugPrint('⚠️ DEVELOPMENT MODE: $feature bypass is active');
      debugPrint('⚠️ Remember to disable before production deployment!');
    }
  }
}