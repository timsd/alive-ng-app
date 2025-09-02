import 'package:flutter/foundation.dart';

/// Simple logger utility for debugging and monitoring
class Logger {
  final String _name;

  Logger(this._name);

  /// Log debug messages (only in debug mode)
  void debug(String message) {
    if (kDebugMode) {
      print('[DEBUG] $_name: $message');
    }
  }

  /// Log info messages
  void info(String message) {
    if (kDebugMode) {
      print('[INFO] $_name: $message');
    }
  }

  /// Log warning messages
  void warning(String message) {
    if (kDebugMode) {
      print('[WARNING] $_name: $message');
    }
  }

  /// Log error messages
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('[ERROR] $_name: $message');
      if (error != null) {
        print('Error: $error');
      }
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }
  }

  /// Log critical errors (always shown)
  void critical(String message, [Object? error, StackTrace? stackTrace]) {
    print('[CRITICAL] $_name: $message');
    if (error != null) {
      print('Error: $error');
    }
    if (stackTrace != null) {
      print('Stack trace: $stackTrace');
    }
  }
}
