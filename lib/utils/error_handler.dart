import 'package:appwrite/appwrite.dart' show AppwriteException;
import 'app_exception.dart';
import 'logger.dart';

/// Legacy alias for describeError, delegating directly to [ErrorHandler.getUserFriendlyMessage].
String describeError(Object error) => ErrorHandler.getUserFriendlyMessage(error);

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

  /// Whether the error is caused by a network disconnection or offline state.
  static bool isNetworkError(dynamic error) {
    if (error == null) return false;
    final str = error.toString().toLowerCase();
    return str.contains('failed to fetch') ||
        str.contains('clientexception') ||
        str.contains('socketexception') ||
        str.contains('failed host lookup') ||
        str.contains('network is unreachable') ||
        str.contains('no address associated with hostname') ||
        str.contains('connection refused') ||
        str.contains('connection timed out') ||
        str.contains('connection reset') ||
        str.contains('connection closed') ||
        str.contains('handshakeexception') ||
        str.contains('tlsexception') ||
        str.contains('timeoutexception') ||
        str.contains('xmlhttprequest error') ||
        str.contains('networkrequestfailed') ||
        str.contains('network_error') ||
        str.contains('errno = 7') ||
        str.contains('errno = 101') ||
        str.contains('errno = 111') ||
        (error is AppwriteException &&
            (error.code == 0 || error.code == null));
  }

  /// Converts any technical backend, network, or platform exception into
  /// a clear, user-friendly English sentence that normal users can understand.
  static String getUserFriendlyMessage(dynamic error, [String? fallback]) {
    if (error == null) {
      return fallback ?? 'An unexpected error occurred. Please try again.';
    }

    if (error is AppException) {
      return error.message;
    }

    final rawString = error.toString();
    final lower = rawString.toLowerCase();

    // 1. Network / Offline Errors
    if (isNetworkError(error)) {
      return 'Unable to connect to the server. Please check your internet connection and try again.';
    }

    // 2. Appwrite / Backend Specific Handling
    if (_isBackendException(error) || error is AppwriteException) {
      final code = _errorCode(error);
      final type = _errorType(error);

      // Check Appwrite error type
      if (type != null && type.isNotEmpty) {
        switch (type.toLowerCase()) {
          case 'user_invalid_credentials':
          case 'user_password_mismatch':
            return 'Incorrect email or password. Please verify your details and try again.';
          case 'user_already_exists':
            return 'An account with this email address already exists. Please sign in instead.';
          case 'user_blocked':
          case 'user_disabled':
            return 'Your account has been deactivated. Please contact ALIVE Nigeria support.';
          case 'user_not_found':
            return 'No account was found with that email address.';
          case 'user_unauthorized':
          case 'general_unauthorized_scope':
            return 'Your session has expired or requires authentication. Please sign in again.';
          case 'general_rate_limit_exceeded':
            return 'Too many requests. Please wait a moment before trying again.';
          case 'password_recently_used':
            return 'This password was used recently. Please choose a different password.';
          case 'password_personal_data':
            return 'Password is too similar to your personal information. Please create a stronger password.';
          case 'storage_file_empty':
            return 'The selected file is empty. Please choose a valid file.';
          case 'storage_file_size_exceeded':
            return 'The file size exceeds the allowed limit. Please select a smaller file.';
          case 'storage_file_type_unsupported':
            return 'This file format is not supported.';
          case 'document_not_found':
            return 'The requested record could not be found.';
        }
      }

      // Check numeric HTTP / Appwrite code
      if (code != null) {
        switch (code) {
          case '0':
            return 'Unable to connect to the server. Please check your internet connection and try again.';
          case '400':
            return 'Invalid request. Please verify your input and try again.';
          case '401':
            return 'Your session has expired. Please sign in to continue.';
          case '403':
          case 'permission-denied':
            return 'You do not have permission to perform this action.';
          case '404':
          case 'not-found':
            return 'The requested item could not be found.';
          case '409':
            return 'A conflicting record already exists.';
          case '413':
            return 'File size is too large. Please select a smaller file.';
          case '429':
            return 'Too many requests. Please wait a few moments before trying again.';
          case '500':
          case '502':
          case '503':
            return 'The server is temporarily unavailable. Please try again shortly.';
        }
      }

      final errMsg = _errorMessage(error);
      if (errMsg != null && errMsg.trim().isNotEmpty) {
        final sanitized = _cleanTechnicalMessage(errMsg);
        if (sanitized.isNotEmpty) return sanitized;
      }
    }

    // 3. Live Broadcast & Streaming Errors
    if (lower.contains('invalid api key') ||
        lower.contains('broadcast failed') ||
        lower.contains('livekit_api_key') ||
        lower.contains('egress')) {
      return 'Live broadcast service configuration error: invalid streaming API credentials. Please contact the administrator to verify streaming settings.';
    }
    if (lower.contains('youtube stream key') ||
        lower.contains('stream key is not configured') ||
        lower.contains('stream key is required')) {
      return 'YouTube live stream key is not configured. Please check the YouTube stream key in settings.';
    }
    if (lower.contains('permission to broadcast')) {
      return 'You do not have permission to start a live broadcast from this room.';
    }

    // 4. Meeting & Conference Room Policies
    if (lower.contains('screen sharing is not supported') ||
        lower.contains('screen sharing is not supported on mobile devices') ||
        lower.contains('getdisplaymedia')) {
      return 'Screen sharing on mobile web browsers is restricted by iOS Safari and Android Chrome. To share your screen, please use the installed ALIVE mobile app or join from a desktop browser.';
    }
    if (lower.contains('only alive leaders')) {
      return 'Only ALIVE leaders and administrators can start new meeting rooms.';
    }
    if (lower.contains('do not have access to this alive meet room') ||
        lower.contains('private alive meet rooms')) {
      return 'You do not have permission to access this private meeting room.';
    }
    if (lower.contains('token not found in alive meet')) {
      return 'Unable to generate meeting access token. Please verify your account permissions.';
    }

    // 5. Payment Specific Messages
    if (lower.contains('currency not supported')) {
      return 'USD payment could not be processed with current settings. Please try NGN or contact support.';
    }
    if (lower.contains('paystack_payments') ||
        lower.contains('executions') ||
        lower.contains('bad state') ||
        lower.contains('no element')) {
      return 'Payment service temporarily unavailable. Please try again or contact support.';
    }

    // 6. Common keywords in stringified exceptions
    if (lower.contains('failed to activate new user')) {
      return 'Account created! Your login is pending administrative approval before full access is enabled.';
    }
    if (lower.contains('smtp') || lower.contains('failed to send email')) {
      return 'Email service is temporarily unavailable. Please try again later.';
    }
    if (lower.contains('user_already_exists') || lower.contains('user already exists')) {
      return 'An account with this email address already exists. Please switch to Sign In.';
    }
    if (lower.contains('invalid_credentials') || lower.contains('invalid credentials')) {
      return 'Incorrect email or password. Please check your credentials and try again.';
    }
    if (lower.contains('rate_limit_exceeded') || lower.contains('rate limit')) {
      return 'Too many attempts. Please wait a few moments before trying again.';
    }
    if (lower.contains('permission-denied') || lower.contains('unauthorized')) {
      return 'You do not have permission to perform this action.';
    }
    if (lower.contains('not-found') || lower.contains('not found')) {
      return 'The requested resource was not found.';
    }

    // 7. Clean any technical exception prefixes and URLs
    final cleaned = _cleanTechnicalMessage(rawString);
    if (cleaned.isNotEmpty && !isNetworkError(cleaned)) {
      return cleaned;
    }

    return fallback ?? 'An unexpected error occurred. Please try again or contact support.';
  }

  static String _cleanTechnicalMessage(String text) {
    var cleaned = text
        .replaceAll(
          RegExp(
            r'(Exception|AppwriteException|ClientException|PlatformException|DatabaseException|NetworkException|AuthException|StorageException):\s*',
          ),
          '',
        )
        .replaceAll(RegExp(r'Appwrite,\s*'), '')
        .replaceAll(RegExp(r'Go Live failed:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'Stop Live failed:\s*', caseSensitive: false), '')
        .trim();

    // Strip trailing status codes like "(0)" or "[500]"
    cleaned = cleaned.replaceAll(RegExp(r'\s*\(\d+\)$'), '').trim();

    // If message leaks internal URIs or Appwrite function endpoints, sanitize it
    if (cleaned.contains('uri=') ||
        cleaned.contains('http://') ||
        cleaned.contains('https://') ||
        cleaned.contains('/v1/functions/') ||
        cleaned.toLowerCase().contains('clientexception')) {
      if (cleaned.toLowerCase().contains('failed to fetch') ||
          cleaned.toLowerCase().contains('network') ||
          cleaned.toLowerCase().contains('socket')) {
        return 'Unable to connect to the server. Please check your internet connection and try again.';
      }
      return 'An error occurred while connecting to the server. Please try again.';
    }

    // Strip leading "Error: " if followed by a sentence
    if (cleaned.startsWith('Error: ')) {
      cleaned = cleaned.substring(7).trim();
    }

    return cleaned;
  }

  static AppException convertToAppException(dynamic error) {
    if (error is AppException) return error;

    if (isNetworkError(error)) {
      return NetworkException(
        getUserFriendlyMessage(error),
        originalError: error,
        stackTrace: _errorStackTrace(error),
      );
    }

    if (_isBackendException(error)) {
      return DatabaseException(
        _errorMessage(error) ?? 'Backend operation failed',
        originalError: error,
        stackTrace: _errorStackTrace(error),
      );
    }

    return AppException(
      getUserFriendlyMessage(error),
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

  static String? _errorType(dynamic error) {
    try {
      final type = error.type;
      return type?.toString();
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
