import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'navigation_keys.dart';
import 'error_handler.dart';

/// Utility class for showing toast and snackbar notifications throughout the app.
class ToastUtils {
  /// Show success message
  static void showSuccess(String message) {
    if (kDebugMode) {
      debugPrint('✅ SUCCESS: $message');
    }
    _showSnackBar(message, isError: false);
  }

  /// Show user-friendly error message, automatically translating technical errors.
  static void showError(dynamic error, [String? fallback]) {
    final friendlyMsg = ErrorHandler.getUserFriendlyMessage(error, fallback);
    if (kDebugMode) {
      debugPrint('❌ ERROR: $friendlyMsg (raw: $error)');
    }
    _showSnackBar(friendlyMsg, isError: true);
  }

  /// Show info message
  static void showInfo(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ INFO: $message');
    }
    _showSnackBar(message, isError: false);
  }

  /// Show warning message
  static void showWarning(String message) {
    if (kDebugMode) {
      debugPrint('⚠️ WARNING: $message');
    }
    _showSnackBar(message, isError: true);
  }

  static void _showSnackBar(String text, {required bool isError}) {
    try {
      final messenger = rootScaffoldMessengerKey.currentState;
      if (messenger == null) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor:
              isError ? const Color(0xFFDC2626) : const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (_) {}
  }
}
