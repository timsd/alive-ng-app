import 'package:firebase_core/firebase_core.dart';
import 'app_exception.dart';
import 'logger.dart';

class ErrorHandler {
  static final Logger _logger = Logger('ErrorHandler');

  static void handleError(dynamic error, {StackTrace? stackTrace}) {
    if (error is AppException) {
      _logger.error(
          error.message, error.originalError, stackTrace ?? error.stackTrace);
    } else if (error is FirebaseException) {
      _logger.error('Firebase Error: ${error.message}', error, stackTrace);
    } else {
      _logger.error('Unexpected Error: $error', error, stackTrace);
    }
  }

  static String getUserFriendlyMessage(dynamic error) {
    if (error is AppException) {
      return error.message;
    }
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You do not have permission to perform this action.';
        case 'unavailable':
          return 'The service is currently unavailable. Please check your internet connection.';
        case 'not-found':
          return 'The requested resource was not found.';
        default:
          return error.message ?? 'An error occurred with the server.';
      }
    }
    return 'Something went wrong. Please try again.';
  }

  static AppException convertToAppException(dynamic error) {
    if (error is AppException) return error;

    if (error is FirebaseException) {
      return DatabaseException(
        error.message ?? 'Firebase operation failed',
        originalError: error,
        stackTrace: error.stackTrace,
      );
    }

    return AppException(
      'An unexpected error occurred',
      originalError: error,
    );
  }
}
