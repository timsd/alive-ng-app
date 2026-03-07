import 'package:flutter/foundation.dart';

/// Simple logger utility for debugging and monitoring
class Logger {
  final String _name;

  Logger(this._name);

  /// Log debug messages (only in debug mode)
  void debug(String message) {
    if (kDebugMode) {
      debugPrint('[DEBUG] $_name: $message');
    }
  }

  /// Log info messages
  void info(String message) {
    if (kDebugMode) {
      debugPrint('[INFO] $_name: $message');
    }
  }

  /// Log warning messages
  void warning(String message) {
    if (kDebugMode) {
      debugPrint('[WARNING] $_name: $message');
    }
  }

  /// Log error messages
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[ERROR] $_name: $message');
      if (error != null) {
        debugPrint('Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  /// Log critical errors (always shown)
  void critical(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[CRITICAL] $_name: $message');
    if (error != null) {
      debugPrint('Error: $error');
    }
    if (stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }
  }
}




