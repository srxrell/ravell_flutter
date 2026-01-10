import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_endpoints.dart';

/// Dio HTTP client with interceptors for authentication, logging, and error handling
class DioClient {
  late final Dio _dio;

  DioClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
      ),
    );

    // Add interceptors
    _dio.interceptors.addAll([
      _authInterceptor(),
      _loggingInterceptor(),
      _errorInterceptor(),
    ]);
  }

  Dio get dio => _dio;

  /// Authentication interceptor - adds Bearer token to requests
  Interceptor _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Skip auth for login/register endpoints
        if (options.path.contains('/login') ||
            options.path.contains('/register')) {
          return handler.next(options);
        }

        // Get access token from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final accessToken = prefs.getString('access_token');

        if (accessToken != null && accessToken.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $accessToken';
          print('🔑 Auth token added to request: ${options.path}');
        }

        return handler.next(options);
      },
      onError: (error, handler) async {
        // Handle 401 Unauthorized - attempt token refresh
        if (error.response?.statusCode == 401) {
          print('🔄 401 Unauthorized - attempting token refresh');

          try {
            // Get refresh token
            final prefs = await SharedPreferences.getInstance();
            final refreshToken = prefs.getString('refresh_token');

            if (refreshToken == null) {
              print('❌ No refresh token available');
              return handler.reject(error);
            }

            // Attempt to refresh token
            final refreshDio = Dio(BaseOptions(baseUrl: ApiEndpoints.baseUrl));
            final response = await refreshDio.post(
              ApiEndpoints.refreshToken,
              data: {'refresh_token': refreshToken},
            );

            if (response.statusCode == 200) {
              final tokens = response.data['tokens'];
              final newAccessToken = tokens['access_token'];

              // Save new access token
              await prefs.setString('access_token', newAccessToken);

              // Optionally update refresh token if provided
              if (tokens.containsKey('refresh_token')) {
                await prefs.setString('refresh_token', tokens['refresh_token']);
              }

              print('✅ Token refreshed successfully');

              // Retry the original request with new token
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newAccessToken';

              final retryResponse = await _dio.request(
                opts.path,
                options: Options(
                  method: opts.method,
                  headers: opts.headers,
                ),
                data: opts.data,
                queryParameters: opts.queryParameters,
              );

              return handler.resolve(retryResponse);
            }
          } catch (e) {
            print('❌ Token refresh failed: $e');
            // Clear auth data on refresh failure
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('access_token');
            await prefs.remove('refresh_token');
            await prefs.remove('user_id');
          }
        }

        return handler.next(error);
      },
    );
  }

  /// Logging interceptor - logs requests and responses
  Interceptor _loggingInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        print('📡 REQUEST[${options.method}] => ${options.path}');
        if (options.data != null) {
          print('📤 Data: ${options.data}');
        }
        if (options.queryParameters.isNotEmpty) {
          print('🔍 Query: ${options.queryParameters}');
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print(
          '📥 RESPONSE[${response.statusCode}] <= ${response.requestOptions.path}',
        );
        return handler.next(response);
      },
      onError: (error, handler) {
        print(
          '❌ ERROR[${error.response?.statusCode}] <= ${error.requestOptions.path}',
        );
        print('❌ Message: ${error.message}');
        if (error.response?.data != null) {
          print('❌ Error Data: ${error.response?.data}');
        }
        return handler.next(error);
      },
    );
  }

  /// Error interceptor - handles common errors
  Interceptor _errorInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) {
        String errorMessage;

        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout) {
          errorMessage = 'Connection timeout. Please check your internet connection.';
        } else if (error.type == DioExceptionType.connectionError) {
          errorMessage = 'No internet connection. Please check your network.';
        } else if (error.response != null) {
          final statusCode = error.response!.statusCode;
          final data = error.response!.data;

          switch (statusCode) {
            case 400:
              errorMessage = data['error'] ?? 'Bad request';
              break;
            case 401:
              errorMessage = 'Unauthorized. Please login again.';
              break;
            case 403:
              errorMessage = 'Access forbidden';
              break;
            case 404:
              errorMessage = 'Resource not found';
              break;
            case 500:
              errorMessage = 'Server error. Please try again later.';
              break;
            default:
              errorMessage = data['error'] ?? 'An error occurred';
          }
        } else {
          errorMessage = 'An unexpected error occurred';
        }

        // Attach user-friendly error message
        error = error.copyWith(
          message: errorMessage,
        );

        return handler.next(error);
      },
    );
  }
}
