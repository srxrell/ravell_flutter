import 'dart:convert';
import 'dart:io' if (dart.library.html) 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'package:readreels/services/file_uploader_stub.dart'
    if (dart.library.io) 'package:readreels/services/file_uploader_io.dart'
    if (dart.library.html) 'package:readreels/services/file_uploader_web.dart';

class SubscriptionService {
  // 🟢 ИСПРАВЛЕННЫЙ URL
  final String baseUrl = 'https://ravell-backend-1.onrender.com';
  final _fileUploader = getFileUploader();

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<int?> getuser_id() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id'); // 🟢 ИСПРАВЛЕНО: user_id
  }

  /// Обновляет профиль текущего пользователя
  Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> profileData,
  ) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Пользователь не авторизован. Токен отсутствует.');
    }

    final url = Uri.parse('$baseUrl/profile'); // 🟢 ИСПРАВЛЕННЫЙ URL

    try {
      final response = await http.put(
        // 🟢 ИСПРАВЛЕНО: PUT вместо PATCH
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

    final url = Uri.parse('$baseUrl/profile'); // 🟢 ИСПРАВЛЕННЫЙ URL

    try {
      final request = http.MultipartRequest('PUT', url); // 🟢 ИСПРАВЛЕНО: PUT
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

  /// Получает профиль пользователя по ID
  Future<Map<String, dynamic>?> fetchUserProfile(int user_id) async {
    final url = Uri.parse(
      '$baseUrl/users/$user_id/profile',
    ); // 🟢 ИСПРАВЛЕННЫЙ URL
    final token = await _getToken();

    try {
      final response = await http.get(
        url,
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
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
  Future<List<Map<String, dynamic>>> fetchFollowers(int user_id) async {
    final url = Uri.parse(
      '$baseUrl/users/$user_id/followers',
    ); // 🟢 ИСПРАВЛЕННЫЙ URL
    final token = await _getToken();

    try {
      final response = await http.get(
        url,
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> jsonList =
            data['followers']; // 🟢 ИСПРАВЛЕНО: followers
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
  Future<List<Map<String, dynamic>>> fetchFollowing(int user_id) async {
    final url = Uri.parse(
      '$baseUrl/users/$user_id/following',
    ); // 🟢 ИСПРАВЛЕННЫЙ URL
    final token = await _getToken();

    try {
      final response = await http.get(
        url,
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> jsonList =
            data['following']; // 🟢 ИСПРАВЛЕНО: following
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
  Future<String> toggleFollow(int user_idToFollow) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Пользователь не авторизован. Токен отсутствует.');
    }

    // 🟢 ИСПРАВЛЕНО: Сначала проверяем текущий статус подписки
    try {
      final currentuser_id = await getuser_id();
      final following = await fetchFollowing(currentuser_id!);
      final isFollowing = following.any(
        (user) => user['id'] == user_idToFollow,
      );

      final url = Uri.parse(
        isFollowing
            ? '$baseUrl/users/$user_idToFollow/unfollow' // 🟢 Отписка
            : '$baseUrl/users/$user_idToFollow/follow', // 🟢 Подписка
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

  /// 🟢 НОВЫЙ МЕТОД: Получает свой профиль
  Future<Map<String, dynamic>> getMyProfile() async {
    final url = Uri.parse('$baseUrl/profile'); // 🟢 ИСПРАВЛЕННЫЙ URL
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
