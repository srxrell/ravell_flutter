// services/subscription_service.dart
import 'dart:convert';
import 'dart:io' if (dart.library.html) 'dart:typed_data';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:readreels/services/file_uploader_stub.dart'
    if (dart.library.io) 'package:readreels/services/file_uploader_io.dart'
    if (dart.library.html) 'package:readreels/services/file_uploader_web.dart';

class SubscriptionService {
  final String baseUrl = 'https://ravell-backend-1.onrender.com';
  final _fileUploader = getFileUploader();

  /* ===================== AUTH ===================== */

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<String?> getToken() => _getToken();

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('user_id') ?? 0;
    return id > 0 ? id : null;
  }

  /* ===================== PROFILE ===================== */

  Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> profileData,
  ) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Пользователь не авторизован');
    }

    final url = Uri.parse('$baseUrl/profile');

    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(profileData),
    );

    final body = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) {
      return body;
    }

    throw Exception(
      'Ошибка обновления профиля: ${response.statusCode} - ${body['error'] ?? 'unknown'}',
    );
  }

  Future<Map<String, dynamic>> updateProfileWithImage({
    required String firstName,
    required String lastName,
    required String bio,
    String? avatarFilePath,
    Uint8List? avatarFileBytes,
    String? avatarFileName,
    required String accessToken,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/profile/with-image');

      late http.MultipartRequest request;

      request = http.MultipartRequest('PUT', uri);

      if (kIsWeb) {
        if (avatarFileBytes != null && avatarFileName != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'avatar',
              avatarFileBytes,
              filename: avatarFileName,
            ),
          );
        }
      } else {
        if (avatarFilePath != null) {
          request.files.add(
            await http.MultipartFile.fromPath('avatar', avatarFilePath),
          );
        }
      }

      request.fields['first_name'] = firstName;
      request.fields['last_name'] = lastName;
      request.fields['bio'] = bio;

      request.headers['Authorization'] = 'Bearer $accessToken';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Map<String, dynamic>.from(body);
      } else {
        return {'error': body['detail'] ?? 'Ошибка обновления профиля'};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getMyProfile() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Пользователь не авторизован');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/profile'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }

    throw Exception('Ошибка загрузки профиля: ${response.statusCode}');
  }

  /* ===================== FOLLOW ===================== */

  Future<List<Map<String, dynamic>>> fetchFollowers(int userId) async {
    final token = await _getToken();

    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/followers'),
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return (data['followers'] ?? []).cast<Map<String, dynamic>>();
    }

    throw Exception('Ошибка загрузки подписчиков');
  }

  Future<List<Map<String, dynamic>>> fetchFollowing(int userId) async {
    final token = await _getToken();

    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/following'),
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return (data['following'] ?? []).cast<Map<String, dynamic>>();
    }

    throw Exception('Ошибка загрузки подписок');
  }

  Future<String> toggleFollow(int targetUserId) async {
    final token = await _getToken();
    final currentUserId = await getUserId();

    if (token == null || currentUserId == null) {
      throw Exception('Пользователь не авторизован');
    }

    final following = await fetchFollowing(currentUserId);
    final isFollowing = following.any(
      (u) => u['user']?['id'].toString() == targetUserId.toString(),
    );

    final url = Uri.parse(
      isFollowing
          ? '$baseUrl/users/$targetUserId/unfollow'
          : '$baseUrl/users/$targetUserId/follow',
    );

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final body = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return body['message'] ?? 'OK';
    }

    throw Exception(body['error'] ?? 'Ошибка подписки');
  }

  /* ===================== USER PROFILE ===================== */

  Future<Map<String, dynamic>?> fetchUserProfile(int userId) async {
    final token = await _getToken();
    final currentUserId = await getUserId();

    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/profile'),
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    );

    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));

    return {
      'user_data': {
        ...data['user'],
        'avatar': data['profile']['avatar'],
        'bio': data['profile']['bio'],
        'is_verified': data['profile']['is_verified'] ?? false,
        'is_early': data['is_early'],
      },
      'stats': data['stats'],
      'stories': data['stories'] ?? [],
      'is_following': data['is_following'] ?? false,
      'is_my_profile': currentUserId == userId,
    };
  }
}
