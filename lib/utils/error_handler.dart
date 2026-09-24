import 'app_exception.dart';
import 'logger.dart';

class ErrorHandler {
  static final Logger _logger = Logger('ErrorHandler');

  static void handleError(dynamic error, {StackTrace? stackTrace}) {
    if (error is AppException) {
      _logger.error(
          error.message, error.originalError, stackTrace ?? error.stackTrace);
    } else if (_isBackendException(error)) {
      _logger.error('Backend Error: ${_errorMessage(error)}', error, stackTrace);
    } else {
      _logger.error('Unexpected Error: $error', error, stackTrace);
    }
  }

  static String getUserFriendlyMessage(dynamic error) {
    if (error is AppException) {
      return error.message;
    }
    if (_isBackendException(error)) {
      switch (_errorCode(error)) {
        case 'permission-denied':
        case '401':
        case '403':
          return 'You do not have permission to perform this action.';
        case 'unavailable':
          return 'The service is currently unavailable. Please check your internet connection.';
        case 'not-found':
        case '404':
          return 'The requested resource was not found.';
        default:
          return _errorMessage(error) ?? 'An error occurred with the server.';
      }
    }
    return 'Something went wrong. Please try again.';
  }

  static AppException convertToAppException(dynamic error) {
    if (error is AppException) return error;

    if (_isBackendException(error)) {
      return DatabaseException(
        _errorMessage(error) ?? 'Backend operation failed',
        originalError: error,
        stackTrace: _errorStackTrace(error),
      );
    }

    return AppException(
      'An unexpected error occurred',
      originalError: error,
    );
  }

  static bool _isBackendException(dynamic error) {
    final typeName = error.runtimeType.toString();
    return typeName == 'AppwriteException';
  }

  static String? _errorCode(dynamic error) {
    try {
      final code = error.code;
      return code?.toString();
    } catch (_) {
      return null;
    }
  }

  static String? _errorMessage(dynamic error) {
    try {
      final message = error.message;
      return message?.toString();
    } catch (_) {
      return null;
    }
  }

  static StackTrace? _errorStackTrace(dynamic error) {
    try {
      final stackTrace = error.stackTrace;
      return stackTrace is StackTrace ? stackTrace : null;
    } catch (_) {
      return null;
    }
  }
}
