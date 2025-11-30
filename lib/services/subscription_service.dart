// services/subscription_service.dart
import 'dart:convert';
import 'dart:io' if (dart.library.html) 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'package:readreels/services/file_uploader_stub.dart'
    if (dart.library.io) 'package:readreels/services/file_uploader_io.dart'
    if (dart.library.html) 'package:readreels/services/file_uploader_web.dart';
import 'auth_service.dart';

class SubscriptionService {
  final String baseUrl = 'https://ravell-backend-1.onrender.com';
  final _fileUploader = getFileUploader();
  final AuthService _authService = AuthService();

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');
  }

  /// Обновляет профиль текущего пользователя
  Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> profileData,
  ) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Пользователь не авторизован. Токен отсутствует.');
    }

    final url = Uri.parse('$baseUrl/profile');

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(profileData),
      );

      final responseBody = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return responseBody;
      } else {
        throw Exception(
          'Ошибка при обновлении профиля: ${response.statusCode} - ${responseBody['error'] ?? 'Неизвестная ошибка'}',
        );
      }
    } catch (e) {
      throw Exception('Сетевая ошибка при обновлении профиля: $e');
    }
  }

  /// Обновляет профиль с изображением
  Future<Map<String, dynamic>> updateProfileWithImage(
    Map<String, String> fields, {
    String? avatarFilePath,
    List<int>? avatarFileBytes,
    String? avatarFileName,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Пользователь не авторизован. Токен отсутствует.');
    }

    final url = Uri.parse('$baseUrl/profile');

    try {
      final request = http.MultipartRequest('PUT', url);
      request.headers['Authorization'] = 'Bearer $token';

      // Добавляем текстовые поля
      request.fields.addAll(fields);

      // Загрузка аватара
      if (avatarFilePath != null || avatarFileBytes != null) {
        final multipartFile = await _fileUploader.createAvatarMultipartFile(
          'avatar',
          filePath: avatarFilePath,
          fileBytes: avatarFileBytes,
          fileName: avatarFileName,
        );
        request.files.add(multipartFile);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final responseBody = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return responseBody;
      } else {
        throw Exception(
          'Ошибка при обновлении профиля: ${response.statusCode} - ${responseBody['error'] ?? 'Неизвестная ошибка'}',
        );
      }
    } catch (e) {
      throw Exception('Сетевая ошибка при обновлении профиля: $e');
    }
  }

  /// Получает профиль пользователя по ID с адаптацией к формату Go API
  Future<Map<String, dynamic>?> fetchUserProfile(int userId) async {
    final url = Uri.parse('$baseUrl/users/$userId/profile');
    final token = await _getToken();

    try {
      final response = await http.get(
        url,
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );

      print('🔵 SubscriptionService - Status: ${response.statusCode}');
      print('🔵 SubscriptionService - Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(
          utf8.decode(response.bodyBytes),
        );

        // 🟢 АДАПТАЦИЯ К ФОРМАТУ GO API
        final user = data['user'];
        final stats = data['stats'];

        if (user != null && stats != null) {
          // Преобразуем в формат, который ожидает Flutter
          return {
            'user_data': user, // 🟢 ИЗМЕНЕНИЕ: user -> user_data
            'stats': stats,
            'stories': data['stories'] ?? [],
            'is_following': data['is_following'] ?? false,
          };
        } else {
          print('❌ Invalid API response format');
          return null;
        }
      } else if (response.statusCode == 404) {
        debugPrint("Профиль пользователя не найден (404)");
        return null;
      } else {
        debugPrint(
          "Не удалось загрузить профиль пользователя: ${response.statusCode}",
        );
        return null;
      }
    } catch (e) {
      debugPrint("Ошибка при получении профиля: $e");
      return null;
    }
  }

  /// Получает подписчиков пользователя
  Future<List<Map<String, dynamic>>> fetchFollowers(int userId) async {
    final url = Uri.parse('$baseUrl/users/$userId/followers');
    final token = await _getToken();

    try {
      final response = await http.get(
        url,
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> jsonList = data['followers'] ?? [];
        return jsonList.cast<Map<String, dynamic>>();
      } else {
        debugPrint("Не удалось загрузить подписчиков: ${response.statusCode}");
        throw Exception("Ошибка загрузки подписчиков");
      }
    } catch (e) {
      throw Exception('Сетевая ошибка при получении списка подписчиков: $e');
    }
  }

  /// Получает подписки пользователя
  Future<List<Map<String, dynamic>>> fetchFollowing(int userId) async {
    final url = Uri.parse('$baseUrl/users/$userId/following');
    final token = await _getToken();

    try {
      final response = await http.get(
        url,
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> jsonList = data['following'] ?? [];
        return jsonList.cast<Map<String, dynamic>>();
      } else {
        debugPrint("Не удалось загрузить подписки: ${response.statusCode}");
        throw Exception("Ошибка загрузки подписок");
      }
    } catch (e) {
      throw Exception('Сетевая ошибка при получении списка подписок: $e');
    }
  }

  /// Подписка/отписка от пользователя
  Future<String> toggleFollow(int userIdToFollow) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Пользователь не авторизован. Токен отсутствует.');
    }

    try {
      final currentUserId = await getUserId();
      if (currentUserId == null) {
        throw Exception('Не удалось получить ID текущего пользователя');
      }

      final following = await fetchFollowing(currentUserId);
      final isFollowing = following.any((user) => user['id'] == userIdToFollow);

      final url = Uri.parse(
        isFollowing
            ? '$baseUrl/users/$userIdToFollow/unfollow'
            : '$baseUrl/users/$userIdToFollow/follow',
      );

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final responseBody = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return responseBody['message'] ?? "Действие выполнено успешно.";
      } else {
        throw Exception(
          responseBody['error'] ??
              'Не удалось выполнить действие: статус ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Сетевая ошибка при переключении подписки: $e');
    }
  }

  /// Получает свой профиль
  Future<Map<String, dynamic>> getMyProfile() async {
    final url = Uri.parse('$baseUrl/profile');
    final token = await _getToken();

    if (token == null) {
      throw Exception('Пользователь не авторизован. Токен отсутствует.');
    }

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
      } else {
        throw Exception('Ошибка при получении профиля: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Сетевая ошибка при получении профиля: $e');
    }
  }
}
