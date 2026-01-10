import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/api_endpoints.dart';

/// Repository for authentication operations
class AuthRepository {
  final DioClient _dioClient;

  AuthRepository(this._dioClient);

  /// Login with username and password
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.login,
        data: {
          'username': username,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final tokens = data['tokens'];
        final userId = data['user_id'];

        // Save auth data to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', tokens['access_token']);
        await prefs.setString('refresh_token', tokens['refresh_token']);
        await prefs.setInt('user_id', userId);

        print('✅ Login successful, user_id: $userId');

        return {
          'user_id': userId,
          'access_token': tokens['access_token'],
          'refresh_token': tokens['refresh_token'],
        };
      } else {
        throw Exception('Login failed with status: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Login failed');
    }
  }

  /// Register new user
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.register,
        data: {
          'username': username,
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 201) {
        final data = response.data;
        final tokens = data['tokens'];
        final userId = data['user_id'];

        // Save auth data to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', tokens['access_token']);
        await prefs.setString('refresh_token', tokens['refresh_token']);
        await prefs.setInt('user_id', userId);

        print('✅ Registration successful, user_id: $userId');

        return {
          'user_id': userId,
          'access_token': tokens['access_token'],
          'refresh_token': tokens['refresh_token'],
        };
      } else {
        throw Exception('Registration failed with status: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Registration failed');
    }
  }

  /// Refresh access token
  Future<void> refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');

      if (refreshToken == null) {
        throw Exception('No refresh token available');
      }

      final response = await _dioClient.dio.post(
        ApiEndpoints.refreshToken,
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final tokens = response.data['tokens'];
        await prefs.setString('access_token', tokens['access_token']);

        if (tokens.containsKey('refresh_token')) {
          await prefs.setString('refresh_token', tokens['refresh_token']);
        }

        print('✅ Token refreshed successfully');
      }
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Token refresh failed');
    }
  }

  /// Logout - clear all auth data
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_id');
    await prefs.remove('username');
    await prefs.remove('email');
    await prefs.remove('avatar_url');
    print('✅ Logout successful');
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') != null &&
        prefs.getString('refresh_token') != null &&
        prefs.getInt('user_id') != null;
  }

  /// Get current user ID
  Future<int?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');
  }

  /// Send player ID for push notifications
  Future<void> sendPlayerId(String playerId) async {
    try {
      await _dioClient.dio.post(
        ApiEndpoints.savePlayer,
        data: {'player_id': playerId},
      );
      print('✅ Player ID sent successfully');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to send player ID');
    }
  }
}
