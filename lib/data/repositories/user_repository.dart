import 'package:dio/dio.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/api_endpoints.dart';

/// Repository for user profile operations
class UserRepository {
  final DioClient _dioClient;

  UserRepository(this._dioClient);

  /// Get user profile
  Future<Map<String, dynamic>> getUserProfile(int userId) async {
    try {
      final response = await _dioClient.dio.get(
        ApiEndpoints.userProfile(userId),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        // Handle both nested and flat response structures
        return data['user_data'] ?? data;
      }

      throw Exception('Failed to load user profile');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to load user profile');
    }
  }

  /// Get user by ID
  Future<Map<String, dynamic>> getUser(int userId) async {
    try {
      final response = await _dioClient.dio.get(
        ApiEndpoints.userById(userId),
      );

      if (response.statusCode == 200) {
        return response.data;
      }

      throw Exception('Failed to load user');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to load user');
    }
  }

  /// Update user profile
  Future<Map<String, dynamic>> updateProfile({
    required int userId,
    String? username,
    String? email,
    String? firstName,
    String? lastName,
    String? bio,
    String? avatarUrl,
  }) async {
    try {
      final response = await _dioClient.dio.put(
        ApiEndpoints.userProfile(userId),
        data: {
          if (username != null) 'username': username,
          if (email != null) 'email': email,
          if (firstName != null) 'first_name': firstName,
          if (lastName != null) 'last_name': lastName,
          if (bio != null) 'bio': bio,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
        },
      );

      if (response.statusCode == 200) {
        return response.data;
      }

      throw Exception('Failed to update profile');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to update profile');
    }
  }

  /// Get user followers
  Future<List<Map<String, dynamic>>> getUserFollowers(int userId) async {
    try {
      final response = await _dioClient.dio.get(
        ApiEndpoints.userFollowers(userId),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> followersJson =
            data is Map ? (data['followers'] ?? []) : data;
        return followersJson.cast<Map<String, dynamic>>();
      }

      throw Exception('Failed to load followers');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to load followers');
    }
  }

  /// Get user following
  Future<List<Map<String, dynamic>>> getUserFollowing(int userId) async {
    try {
      final response = await _dioClient.dio.get(
        ApiEndpoints.userFollowing(userId),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> followingJson =
            data is Map ? (data['following'] ?? []) : data;
        return followingJson.cast<Map<String, dynamic>>();
      }

      throw Exception('Failed to load following');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to load following');
    }
  }

  /// Get user activity
  Future<List<Map<String, dynamic>>> getUserActivity(int userId) async {
    try {
      final response = await _dioClient.dio.get(
        ApiEndpoints.userActivity(userId),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> activityJson =
            data is Map ? (data['activity'] ?? []) : data;
        return activityJson.cast<Map<String, dynamic>>();
      }

      throw Exception('Failed to load activity');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to load activity');
    }
  }

  /// Get user streak
  Future<Map<String, dynamic>> getUserStreak(int userId) async {
    try {
      final response = await _dioClient.dio.get(
        ApiEndpoints.userStreak(userId),
      );

      if (response.statusCode == 200) {
        return response.data;
      }

      throw Exception('Failed to load streak');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to load streak');
    }
  }
}
