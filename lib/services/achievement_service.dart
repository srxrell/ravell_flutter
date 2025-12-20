import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:readreels/models/achievement.dart';
import 'auth_service.dart';

class AchievementService {
  final AuthService _authService = AuthService();
  static const String baseUrl = 'https://ravell-backend-1.onrender.com';

  Future<List<UserAchievement>> fetchAchievements({required int userId}) async {
    final myUserId = await _authService.getMyUserId();
    final headers = <String, String>{'Content-Type': 'application/json'};

    // Добавляем токен только если это мои ачивки
    if (userId == myUserId) {
      final token = await _authService.getAccessToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }

    final url = '$baseUrl/users/$userId/achievements';

    // ================== ЛОГИ ==================
    print('=== AchievementService.fetchAchievements ===');
    print('URL: $url');
    print('Headers: $headers');
    print('Requested userId: $userId, myUserId: $myUserId');
    // ==========================================

    final res = await http.get(Uri.parse(url), headers: headers);

    // ================== ЛОГИ ==================
    print('Response status: ${res.statusCode}');
    print('Response body: ${res.body}');
    // ==========================================

    if (res.statusCode == 200) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      final list = data['achievements'] as List;
      print('Fetched ${list.length} achievements.');
      return list.map((e) => UserAchievement.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load achievements: ${res.statusCode}');
    }
  }
}
