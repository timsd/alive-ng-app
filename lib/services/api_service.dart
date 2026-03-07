import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'storage_service.dart';
import 'auth_service.dart';
import '../utils/logger.dart';
import '../utils/app_exception.dart';

class ApiService {
  static ApiService? _instance;
  static ApiService get instance => _instance ??= ApiService._();

  ApiService._() {
    _initializeDio();
  }

  static final Logger _logger = Logger('ApiService');

  late Dio _dio;
  final StorageService _storage = StorageService.instance;
  final AuthService _authService = AuthService.instance;

  // Base URLs for different environments
  static const String _baseUrlProd = 'https://api.alive-app.com';
  static const String _baseUrlDev = 'https://dev-api.alive-app.com';

  String get baseUrl {
    if (kDebugMode) {
      return _baseUrlDev;
    }
    return _baseUrlProd;
  }

  // Initialize Dio with interceptors
  void _initializeDio() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add interceptors
    _dio.interceptors.add(_AuthInterceptor(_authService, _storage));
    _dio.interceptors.add(_LoggingInterceptor());
    _dio.interceptors.add(_RetryInterceptor());
    _dio.interceptors.add(_CacheInterceptor(_storage));
  }

  // Generic GET request
  Future<T> get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    bool useCache = false,
    Duration? cacheMaxAge,
  }) async {
    try {
      await _checkConnectivity();

      final response = await _dio.get(
        endpoint,
        queryParameters: queryParameters,
        options: options?.copyWith(
              extra: {
                'useCache': useCache,
                'cacheMaxAge': cacheMaxAge?.inMilliseconds,
              },
            ) ??
            Options(
              extra: {
                'useCache': useCache,
                'cacheMaxAge': cacheMaxAge?.inMilliseconds,
              },
            ),
      );

      return response.data as T;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Unexpected error during GET request',
          originalError: e);
    }
  }

  // Generic POST request
  Future<T> post<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      await _checkConnectivity();

      final response = await _dio.post(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );

      return response.data as T;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Unexpected error during POST request',
          originalError: e);
    }
  }

  // Generic PUT request
  Future<T> put<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      await _checkConnectivity();

      final response = await _dio.put(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );

      return response.data as T;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Unexpected error during PUT request',
          originalError: e);
    }
  }

  // Generic PATCH request
  Future<T> patch<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      await _checkConnectivity();

      final response = await _dio.patch(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );

      return response.data as T;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Unexpected error during PATCH request',
          originalError: e);
    }
  }

  // Generic DELETE request
  Future<T> delete<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      await _checkConnectivity();

      final response = await _dio.delete(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );

      return response.data as T;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Unexpected error during DELETE request',
          originalError: e);
    }
  }

  // File upload
  Future<Response> uploadFile(
    Uint8List fileBytes, {
    required String fileName,
    String fieldName = 'file',
    required String endpoint,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? fields,
  }) async {
    try {
      final formData = FormData();
      // Add fields
      if (fields != null) {
        fields.forEach((key, value) {
          formData.fields.add(MapEntry(key, value.toString()));
        });
      }
      // Add file using bytes for web compatibility
      formData.files.add(
        MapEntry(
          fieldName,
          MultipartFile.fromBytes(
            fileBytes,
            filename: fileName,
          ),
        ),
      );

      final response = await _dio.post(
        endpoint,
        data: formData,
        options: Options(headers: headers),
      );
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      _logger.error('File upload error', e);
      throw AppException('File upload error', originalError: e);
    }
  }

  // Download file
  Future<String> downloadFile(
    String url,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      await _checkConnectivity();

      await _dio.download(
        url,
        savePath,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
      );

      return savePath;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException('Unexpected error during file download',
          originalError: e);
    }
  }

  // Bible API methods removed as we now use local bible files.

  // Check connectivity
  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (results.contains(ConnectivityResult.none)) {
      throw NetworkException('No internet connection');
    }
  }

  // Handle Dio errors
  Exception _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return NetworkException(
            'Connection error. Please check your internet connection.',
            originalError: error);

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final message = _getErrorMessage(error.response?.data);

        switch (statusCode) {
          case 400:
            return ValidationException(message ?? 'Bad request');
          case 401:
            return AuthException(message ?? 'Unauthorized',
                originalError: error);
          case 403:
            return AuthException(message ?? 'Forbidden', originalError: error);
          case 404:
            return NotFoundException(message ?? 'Not found');
          case 422:
            return ValidationException(message ?? 'Validation error');
          case 500:
            return AppException(message ?? 'Server error',
                code: 'SERVER_ERROR', originalError: error);
          default:
            return AppException(message ?? 'HTTP error: $statusCode',
                code: 'HTTP_$statusCode', originalError: error);
        }

      case DioExceptionType.cancel:
        return AppException('Request cancelled',
            code: 'CANCELLED', originalError: error);

      default:
        return NetworkException('Network error: ${error.message}',
            originalError: error);
    }
  }

  // Extract error message from response
  String? _getErrorMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['message'] ?? data['error'] ?? data['detail'];
    }
    return data?.toString();
  }

  // Clear cache
  Future<void> clearCache() async {
    // Implementation depends on cache strategy
  }

  // Get Dio instance for advanced usage
  Dio get dio => _dio;
}

// Auth Interceptor
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._authService, this._storage);

  final AuthService _authService;
  final StorageService _storage;

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    // Add auth token if available
    if (_authService.isAuthenticated) {
      final token = await _storage.getSecureString(StorageKeys.authToken);
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    // Add user agent
    options.headers['User-Agent'] = 'AliveApp/1.0.0';

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Handle 401 errors (token refresh)
    if (err.response?.statusCode == 401) {
      try {
        // Attempt to refresh token
        final refreshToken =
            await _storage.getSecureString(StorageKeys.refreshToken);
        if (refreshToken != null) {
          // Implement token refresh logic here
          // For now, just sign out the user
          await _authService.signOut();
        }
      } catch (e) {
        // Token refresh failed, sign out user
        await _authService.signOut();
      }
    }

    handler.next(err);
  }
}

// Logging Interceptor
class _LoggingInterceptor extends Interceptor {
  final Logger _logger = Logger('ApiLogging');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      _logger.debug('🚀 REQUEST: ${options.method} ${options.uri}');
      _logger.debug('📤 Headers: ${options.headers}');
      if (options.data != null) {
        _logger.debug('📤 Data: ${options.data}');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      _logger.debug(
          '✅ RESPONSE: ${response.statusCode} ${response.requestOptions.uri}');
      _logger.debug('📥 Data: ${response.data}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      _logger.error(
          '❌ ERROR: ${err.response?.statusCode} ${err.requestOptions.uri}');
      _logger.error('❌ Message: ${err.message}');
      if (err.response?.data != null) {
        _logger.error('❌ Data: ${err.response?.data}');
      }
    }
    handler.next(err);
  }
}

// Retry Interceptor
class _RetryInterceptor extends Interceptor {
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 1);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final extra = err.requestOptions.extra;
    final retryCount = extra['retryCount'] ?? 0;

    // Only retry on network errors and timeouts
    if (retryCount < maxRetries && _shouldRetry(err)) {
      extra['retryCount'] = retryCount + 1;

      // Wait before retrying
      await Future.delayed(retryDelay * (retryCount + 1));

      try {
        final response = await Dio().fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (e) {
        // Continue with original error if retry fails
      }
    }

    handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.response?.statusCode != null && err.response!.statusCode! >= 500);
  }
}

// Cache Interceptor
class _CacheInterceptor extends Interceptor {
  _CacheInterceptor(this._storage);

  final StorageService _storage;

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final useCache = options.extra['useCache'] == true;
    final cacheMaxAge = options.extra['cacheMaxAge'];

    if (useCache && options.method.toLowerCase() == 'get') {
      final cacheKey = _getCacheKey(options);
      final cachedResponse = await _storage.getJson(cacheKey);

      if (cachedResponse != null) {
        final cacheTime = DateTime.parse(cachedResponse['timestamp']);
        final maxAge = cacheMaxAge != null
            ? Duration(milliseconds: cacheMaxAge)
            : const Duration(minutes: 5);

        if (DateTime.now().difference(cacheTime) < maxAge) {
          // Return cached response
          handler.resolve(Response(
            requestOptions: options,
            data: cachedResponse['data'],
            statusCode: 200,
            extra: {'fromCache': true},
          ));
          return;
        }
      }
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final useCache = response.requestOptions.extra['useCache'] == true;

    if (useCache && response.requestOptions.method.toLowerCase() == 'get') {
      final cacheKey = _getCacheKey(response.requestOptions);
      await _storage.setJson(cacheKey, {
        'data': response.data,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    handler.next(response);
  }

  String _getCacheKey(RequestOptions options) {
    final uri = options.uri.toString();
    return 'api_cache_${uri.hashCode}';
  }
}

// Riverpod providers
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService.instance;
});

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (results) => !results.contains(ConnectivityResult.none),
    loading: () => true, // Assume online while loading
    error: (_, __) => false,
  );
});
