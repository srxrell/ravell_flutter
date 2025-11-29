import 'dart:convert';
import 'dart:io'
    if (dart.library.html) 'dart:typed_data'; // Условный импорт для File или Uint8List
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
// ✅ ИСПРАВЛЕННЫЙ КРОСС-ПЛАТФОРМЕННЫЙ ИМПОРТ
// Убедитесь, что пути пакета (package:readreels/services/...) верны.
import 'package:readreels/services/file_uploader_stub.dart'
    if (dart.library.io) 'package:readreels/services/file_uploader_io.dart'
    if (dart.library.html) 'package:readreels/services/file_uploader_web.dart';

// Класс для взаимодействия с API подписок и профилей
class SubscriptionService {
  // Базовый URL вашего бэкенда.
  final String baseUrl = 'http://192.168.1.104:8080';
  // Инициализируем Uploader, который будет специфичен для платформы
  final _fileUploader =
      getFileUploader(); // Тип FileUploader теперь будет найден из file_uploader_stub.dart

  // Вспомогательный метод для получения токена из SharedPreferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // Вспомогательный метод для получения ID текущего пользователя
  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('userId');
  }

  /// Обновляет текстовые данные профиля текущего пользователя (JSON PATCH).
  Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> profileData,
  ) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Пользователь не авторизован. Токен отсутствует.');
    }

    final url = Uri.parse('$baseUrl/profile/update/');

    try {
      final response = await http.patch(
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
      } else if (response.statusCode == 400) {
        return responseBody;
      } else {
        throw Exception(
          'Ошибка при обновлении профиля: ${response.statusCode} - ${responseBody['detail'] ?? 'Неизвестная ошибка'}',
        );
      }
    } catch (e) {
      throw Exception('Сетевая ошибка при обновлении профиля: $e');
    }
  }

  /// Обновляет профиль, включая файл аватара (MultiPart).
  /// Поддерживает Mobile/Desktop (через path) и Web (через bytes).
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

    final url = Uri.parse('$baseUrl/profile/update/');

    try {
      final request = http.MultipartRequest('PATCH', url);
      request.headers['Authorization'] = 'Bearer $token';

      // Добавляем текстовые поля
      request.fields.addAll(fields);

      // Используем FileUploader для кросс-платформенной загрузки
      if (avatarFilePath != null || avatarFileBytes != null) {
        final multipartFile = await _fileUploader.createAvatarMultipartFile(
          'avatar',
          filePath: avatarFilePath,
          fileBytes: avatarFileBytes,
          fileName: avatarFileName,
        );
        request.files.add(multipartFile);
      }

      // Отправляем запрос
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final responseBody = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return responseBody;
      } else if (response.statusCode == 400) {
        return responseBody;
      } else {
        throw Exception(
          'Ошибка при обновлении профиля: ${response.statusCode} - ${responseBody['detail'] ?? 'Неизвестная ошибка'}',
        );
      }
    } catch (e) {
      throw Exception('Сетевая ошибка при обновлении профиля: $e');
    }
  }

  /// Загружает данные профиля конкретного пользователя по его ID.
  Future<Map<String, dynamic>?> fetchUserProfile(int userId) async {
    // Предполагаемый URL для получения профиля
    final url = Uri.parse('$baseUrl/profile/$userId/');
    final token = await _getToken();

    try {
      final response = await http.get(
        url,
        // Передаем токен (если есть)
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );

      if (response.statusCode == 200) {
        // Декодируем с поддержкой кириллицы
        return jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        // Пользователь не найден
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

  /// Загружает список пользователей, подписанных на профиль (Followers).
  Future<List<Map<String, dynamic>>> fetchFollowers(int userId) async {
    final url = Uri.parse('$baseUrl/profile/$userId/followers/');
    final token = await _getToken();

    try {
      final response = await http.get(
        url,
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        return jsonList.cast<Map<String, dynamic>>();
      } else {
        debugPrint("Не удалось загрузить подписчиков: ${response.statusCode}");
        throw Exception("Ошибка загрузки подписчиков");
      }
    } catch (e) {
      throw Exception('Сетевая ошибка при получении списка подписчиков: $e');
    }
  }

  /// Загружает список пользователей, на которых подписан профиль (Following).
  Future<List<Map<String, dynamic>>> fetchFollowing(int userId) async {
    final url = Uri.parse('$baseUrl/profile/$userId/following/');
    final token = await _getToken();

    try {
      final response = await http.get(
        url,
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        return jsonList.cast<Map<String, dynamic>>();
      } else {
        debugPrint("Не удалось загрузить подписки: ${response.statusCode}");
        throw Exception("Ошибка загрузки подписок");
      }
    } catch (e) {
      throw Exception('Сетевая ошибка при получении списка подписок: $e');
    }
  }

  /// Отправляет запрос на подписку или отписку от пользователя.
  Future<String> toggleFollow(int userIdToFollow) async {
    final url = Uri.parse('$baseUrl/follow/$userIdToFollow/');
    final token = await _getToken();

    if (token == null) {
      throw Exception('Пользователь не авторизован. Токен отсутствует.');
    }

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final responseBody = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return responseBody['detail'] ?? "Действие выполнено успешно.";
      } else {
        throw Exception(
          responseBody['detail'] ??
              'Не удалось выполнить действие: статус ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Сетевая ошибка при переключении подписки: $e');
    }
  }
}
