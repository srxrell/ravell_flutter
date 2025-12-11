// services/subscription_service.dart
import 'dart:convert';
import 'dart:io' if (dart.library.html) 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:readreels/services/push_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'package:readreels/services/file_uploader_stub.dart'
    if (dart.library.io) 'package:readreels/services/file_uploader_io.dart'
    if (dart.library.html) 'package:readreels/services/file_uploader_web.dart';

class SubscriptionService {
  final String baseUrl = 'https://ravell-backend-1.onrender.com';
  final _fileUploader = getFileUploader();

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('user_id') ?? 0;
    return id > 0 ? id : null;
  }

  /// Обновляет профиль текущего пользователя (без изображения)
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
  Future<Map<String, dynamic>> updateProfileWithImage({
    String? firstName,
    String? lastName,
    String? bio,
    String? avatarFilePath,
    List<int>? avatarFileBytes,
    String? avatarFileName,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Пользователь не авторизован. Токен отсутствует.');
    }

    // ✅ ИСПРАВЛЕННЫЙ URL
    final url = Uri.parse('$baseUrl/profile/with-image');

    try {
      final request = http.MultipartRequest('PUT', url);
      request.headers['Authorization'] = 'Bearer $token';

      // ✅ ДОБАВЛЯЕМ ТЕКСТОВЫЕ ПОЛЯ КОРРЕКТНО
      if (firstName != null && firstName.isNotEmpty) {
        request.fields['first_name'] = firstName;
      }
      if (lastName != null && lastName.isNotEmpty) {
        request.fields['last_name'] = lastName;
      }
      if (bio != null) {
        request.fields['bio'] = bio;
      }

      // ✅ ЗАГРУЗКА АВАТАРА
      if (avatarFilePath != null || avatarFileBytes != null) {
        final multipartFile = await _fileUploader.createAvatarMultipartFile(
          'avatar', // ✅ ИМЯ ПОЛЯ ДОЛЖНО СОВПАДАТЬ С БЕКОМ
          filePath: avatarFilePath,
          fileBytes: avatarFileBytes,
          fileName: avatarFileName ?? 'avatar.jpg',
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
      debugPrint('❌ toggleFollow failed: token is null');
      throw Exception('Пользователь не авторизован');
    }

    final currentUserId = await getUserId();
    if (currentUserId == null) {
      debugPrint('❌ toggleFollow failed: currentUserId is null');
      throw Exception('Не удалось получить ID текущего пользователя');
    }

    List<Map<String, dynamic>> following = [];
    try {
      following = await fetchFollowing(currentUserId);
    } catch (e) {
      debugPrint('❌ toggleFollow failed fetching following: $e');
      throw Exception('Не удалось получить список подписок: $e');
    }

    final isFollowing = following.any((user) {
      final userMap = user['user'] as Map<String, dynamic>?;
      if (userMap == null) return false;
      final id = userMap['id'];
      if (id == null) return false;
      return id.toString() == userIdToFollow.toString();
    });

    final url = Uri.parse(
      isFollowing
          ? '$baseUrl/users/$userIdToFollow/unfollow'
          : '$baseUrl/users/$userIdToFollow/follow',
    );

    debugPrint('🔹 toggleFollow URL: $url');
    debugPrint('🔹 toggleFollow isFollowing: $isFollowing');
    debugPrint(
      '🔹 toggleFollow currentUserId: $currentUserId, targetUserId: $userIdToFollow',
    );

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('🔹 Response status: ${response.statusCode}');
      debugPrint('🔹 Response body: ${response.body}');

      final responseBody = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!isFollowing) {
          try {
            await sendPushOnServer(
              userId: userIdToFollow,
              title: 'Новый подписчик!',
              message:
                  '${responseBody['follower_name'] ?? 'Пользователь'} подписался на вас.',
            );
          } catch (e) {
            debugPrint('Ошибка при отправке push: $e');
          }
        }
        return responseBody['message'] ?? "Действие выполнено успешно.";
      } else {
        debugPrint(
          '❌ toggleFollow failed: ${responseBody['error'] ?? 'Unknown error'}',
        );
        throw Exception(
          responseBody['error'] ??
              'Не удалось выполнить действие: статус ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('❌ toggleFollow request failed: $e');
      throw Exception('Сетевая ошибка при подписке/отписке: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchUserProfile(int userId) async {
    final url = Uri.parse('$baseUrl/users/$userId/profile');
    final token = await _getToken();
    final currentUserId = await getUserId();

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

        // ✅ ПРОВЕРКА, ЭТО ЛИ ЭТО ПРОФИЛЬ ТЕКУЩЕГО ПОЛЬЗОВАТЕЛЯ
        final bool isMyProfile =
            currentUserId != null && currentUserId == userId;

        // ✅ АДАПТАЦИЯ К НОВОМУ ФОРМАТУ GO API
        final user = data['user'];
        final profile = data['profile'];
        final stats = data['stats'];

        if (user != null && profile != null && stats != null) {
          // ✅ ОБЪЕДИНЯЕМ ДАННЫЕ ПОЛЬЗОВАТЕЛЯ И ПРОФИЛЯ
          final userData = {
            ...user,
            'first_name': user['first_name'] ?? '',
            'last_name': user['last_name'] ?? '',
            'avatar': profile['avatar'] ?? '',
            'bio': profile['bio'] ?? '',
            'is_verified': profile['is_verified'] ?? false,
          };

          return {
            'user_data': userData,
            'stats': stats,
            'stories': data['stories'] ?? [],
            'is_following': data['is_following'] ?? false,
            'is_my_profile': isMyProfile, // ✅ ДОБАВЛЯЕМ ФЛАГ
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
}
