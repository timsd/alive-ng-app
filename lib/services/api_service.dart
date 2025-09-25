import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'storage_service.dart';
import 'auth_service.dart';

class ApiService {
  static ApiService? _instance;
  static ApiService get instance => _instance ??= ApiService._();

  ApiService._() {
    _initializeDio();
  }

  // Bible API methods
  Future<ApiResponse<Map<String, dynamic>>> getBibleVerse(String reference) async {
    try {
      // Using Bible API (bible-api.com) as a free alternative
      final response = await _dio.get(
        'https://bible-api.com/$reference',
        options: Options(
          headers: {
            'Accept': 'application/json',
          },
        ),
      );
      
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return _handleDioError<Map<String, dynamic>>(e);
    } catch (e) {
      return ApiResponse.error('Failed to fetch Bible verse: $e');
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> searchBibleVerses(String query) async {
    try {
      // This is a placeholder - you would implement actual search functionality
      // For now, return empty results
      return ApiResponse.success([]);
    } catch (e) {
      return ApiResponse.error('Failed to search Bible verses: $e');
    }
  }

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
  Future<ApiResponse<T>> get<T>(
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

      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return _handleDioError<T>(e);
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  // Generic POST request
  Future<ApiResponse<T>> post<T>(
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

      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return _handleDioError<T>(e);
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  // Generic PUT request
  Future<ApiResponse<T>> put<T>(
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

      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return _handleDioError<T>(e);
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  // Generic PATCH request
  Future<ApiResponse<T>> patch<T>(
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

      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return _handleDioError<T>(e);
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  // Generic DELETE request
  Future<ApiResponse<T>> delete<T>(
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

      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return _handleDioError<T>(e);
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  // File upload
  Future<ApiResponse<T>> uploadFile<T>(
    String endpoint,
    File file, {
    String fieldName = 'file',
    Map<String, dynamic>? data,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      await _checkConnectivity();

      final formData = FormData();

      // Add file
      formData.files.add(MapEntry(
        fieldName,
        await MultipartFile.fromFile(file.path),
      ));

      // Add additional data
      if (data != null) {
        data.forEach((key, value) {
          formData.fields.add(MapEntry(key, value.toString()));
        });
      }

      final response = await _dio.post(
        endpoint,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
        onSendProgress: onSendProgress,
      );

      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return _handleDioError<T>(e);
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  // Download file
  Future<ApiResponse<String>> downloadFile(
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

      return ApiResponse.success(savePath);
    } on DioException catch (e) {
      return _handleDioError<String>(e);
    } catch (e) {
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  // Check connectivity
  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw const ApiException(
        message: 'No internet connection',
        type: ApiErrorType.network,
      );
    }
  }

  // Handle Dio errors
  ApiResponse<T> _handleDioError<T>(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiResponse.error(
          'Connection timeout. Please check your internet connection.',
          type: ApiErrorType.timeout,
        );

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final message = _getErrorMessage(error.response?.data);

        switch (statusCode) {
          case 400:
            return ApiResponse.error(message ?? 'Bad request',
                type: ApiErrorType.badRequest);
          case 401:
            return ApiResponse.error(message ?? 'Unauthorized',
                type: ApiErrorType.unauthorized);
          case 403:
            return ApiResponse.error(message ?? 'Forbidden',
                type: ApiErrorType.forbidden);
          case 404:
            return ApiResponse.error(message ?? 'Not found',
                type: ApiErrorType.notFound);
          case 422:
            return ApiResponse.error(message ?? 'Validation error',
                type: ApiErrorType.validation);
          case 500:
            return ApiResponse.error(message ?? 'Server error',
                type: ApiErrorType.server);
          default:
            return ApiResponse.error(
              message ?? 'HTTP error: $statusCode',
              type: ApiErrorType.server,
            );
        }

      case DioExceptionType.cancel:
        return ApiResponse.error('Request cancelled',
            type: ApiErrorType.cancelled);

      case DioExceptionType.connectionError:
        return ApiResponse.error(
          'Connection error. Please check your internet connection.',
          type: ApiErrorType.network,
        );

      default:
        return ApiResponse.error(
          'Network error: ${error.message}',
          type: ApiErrorType.network,
        );
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
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      print('🚀 REQUEST: ${options.method} ${options.uri}');
      print('📤 Headers: ${options.headers}');
      if (options.data != null) {
        print('📤 Data: ${options.data}');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      print(
          '✅ RESPONSE: ${response.statusCode} ${response.requestOptions.uri}');
      print('📥 Data: ${response.data}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      print('❌ ERROR: ${err.response?.statusCode} ${err.requestOptions.uri}');
      print('❌ Message: ${err.message}');
      if (err.response?.data != null) {
        print('❌ Data: ${err.response?.data}');
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

// API Response wrapper
class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String? error;
  final ApiErrorType? errorType;
  final int? statusCode;

  ApiResponse._(
      {required this.isSuccess,
      this.data,
      this.error,
      this.errorType,
      this.statusCode});

  factory ApiResponse.success(T data, {int? statusCode}) {
    return ApiResponse._(
      isSuccess: true,
      data: data,
      statusCode: statusCode,
    );
  }

  factory ApiResponse.error(String error,
      {ApiErrorType? type, int? statusCode}) {
    return ApiResponse._(
      isSuccess: false,
      error: error,
      errorType: type,
      statusCode: statusCode,
    );
  }
}

// API Exception
class ApiException implements Exception {
  final String message;
  final ApiErrorType type;
  final int? statusCode;

  const ApiException({
    required this.message,
    required this.type,
    this.statusCode,
  });

  @override
  String toString() => 'ApiException: $message';
}

// API Error Types
enum ApiErrorType {
  network,
  timeout,
  server,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  validation,
  cancelled,
  unknown,
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
