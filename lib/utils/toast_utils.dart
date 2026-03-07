import 'package:flutter/foundation.dart';

/// Utility class for showing toast messages
/// Note: This is a simplified implementation that logs messages
/// In a production app, you would integrate with a proper toast library
class ToastUtils {
  /// Show success message
  static void showSuccess(String message) {
    if (kDebugMode) {
      debugPrint('✅ SUCCESS: $message');
    }
  }

  /// Show error message
  static void showError(String message) {
    if (kDebugMode) {
      debugPrint('❌ ERROR: $message');
    }
  }

  /// Show info message
  static void showInfo(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ INFO: $message');
    }
  }

  /// Show warning message
  static void showWarning(String message) {
    if (kDebugMode) {
      debugPrint('⚠️ WARNING: $message');
    }
  }
}



