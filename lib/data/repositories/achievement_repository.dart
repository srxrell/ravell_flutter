import 'package:dio/dio.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../models/achievement.dart';

/// Repository for achievement operations
class AchievementRepository {
  final DioClient _dioClient;

  AchievementRepository(this._dioClient);

  /// Get user achievements
  Future<List<UserAchievement>> getUserAchievements(int userId) async {
    try {
      final response = await _dioClient.dio.get(
        ApiEndpoints.userAchievements(userId),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> achievementsJson =
            data is Map ? (data['achievements'] ?? []) : data;

        return achievementsJson
            .map((json) => UserAchievement.fromJson(json))
            .toList();
      }

      throw Exception('Failed to load achievements');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to load achievements');
    }
  }

  /// Get all available achievements
  Future<List<Achievement>> getAllAchievements() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.achievements);

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> achievementsJson =
            data is Map ? (data['achievements'] ?? []) : data;

        return achievementsJson.map((json) => Achievement.fromJson(json)).toList();
      }

      throw Exception('Failed to load achievements');
    } on DioException catch (e) {
      throw Exception(e.message ?? 'Failed to load achievements');
    }
  }
}
