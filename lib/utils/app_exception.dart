class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  AppException(this.message, {this.code, this.originalError, this.stackTrace});

  @override
  String toString() {
    if (code != null) {
      return 'AppException: [$code] $message';
    }
    return 'AppException: $message';
  }
}

class NetworkException extends AppException {
  NetworkException(super.message, {super.originalError, super.stackTrace})
      : super(code: 'NETWORK_ERROR');
}

class DatabaseException extends AppException {
  DatabaseException(super.message, {super.originalError, super.stackTrace})
      : super(code: 'DATABASE_ERROR');
}

class ValidationException extends AppException {
  ValidationException(super.message, {super.originalError, super.stackTrace})
      : super(code: 'VALIDATION_ERROR');
}

class AuthException extends AppException {
  AuthException(super.message, {super.originalError, super.stackTrace})
      : super(code: 'AUTH_ERROR');
}

class StorageException extends AppException {
  StorageException(super.message, {super.originalError, super.stackTrace})
      : super(code: 'STORAGE_ERROR');
}

class NotFoundException extends AppException {
  NotFoundException(super.message, {super.originalError, super.stackTrace})
      : super(code: 'NOT_FOUND');
}
