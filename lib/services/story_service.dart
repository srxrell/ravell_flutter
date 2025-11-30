import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'package:readreels/services/story_storage_service.dart';
import '../models/story.dart';
import '../models/comment.dart';
import '../models/hashtag.dart';
import 'auth_service.dart';

class StoryService {
  final StoryStorageInterface _storageService = createStoryStorage();
  final AuthService _authService = AuthService();

  // 🟢 ИСПРАВЛЕННЫЕ URLS ДЛЯ GO API
  final String baseUrl = 'https://ravell-backend-1.onrender.com';

  // --------------------------------------------------------------------------
  // МЕТОДЫ АВТОРИЗАЦИИ И ЗАГОЛОВКОВ
  // --------------------------------------------------------------------------

  Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final Map<String, String> headers = {
      'Content-Type': 'application/json; charset=UTF-8',
    };
    if (includeAuth) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? accessToken = prefs.getString('access_token');
      if (accessToken != null) {
        headers['Authorization'] = 'Bearer $accessToken';
      }
    }
    return headers;
  }

  // --------------------------------------------------------------------------
  // МЕТОДЫ ЛАЙКОВ И СТАТУСА
  // --------------------------------------------------------------------------

  Future<Map<String, dynamic>> _executeLikeRequest(int storyId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/like'), // 🟢 ИСПРАВЛЕННЫЙ URL
      headers: await _getHeaders(includeAuth: true),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized');
    } else {
      throw Exception(
        'Failed to like story. Status code: ${response.statusCode}, body: ${response.body}',
      );
    }
  }

  Future<int> likeStory(int storyId, int user_id) async {
    try {
      final responseData = await _executeLikeRequest(storyId);
      return responseData['likes_count'] as int; // 🟢 ИСПРАВЛЕНО: likes_count
    } on Exception catch (e) {
      if (e.toString().contains('Unauthorized')) {
        await _authService.refreshToken();
        final responseData = await _executeLikeRequest(storyId);
        return responseData['likes_count'] as int;
      } else {
        rethrow;
      }
    }
  }

  Future<bool> isStoryLiked(int storyId, int user_id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stories/$storyId'), // 🟢 Получаем историю
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // 🟢 ПРЕДПОЛОЖЕНИЕ: В ответе есть поле is_liked
        return data['is_liked'] ?? false;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('Error checking like status: $e');
      return false;
    }
  }

  // --------------------------------------------------------------------------
  // МЕТОДЫ ХЕШТЕГОВ И СТОРИС
  // --------------------------------------------------------------------------

  Future<Hashtag> createHashtag(String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/hashtags/'), // 🟢 ИСПРАВЛЕННЫЙ URL
      headers: await _getHeaders(includeAuth: true),
      body: jsonEncode(<String, String>{'name': name}),
    );

    if (response.statusCode == 201) {
      return Hashtag.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception('Failed to create hashtag: ${errorBody.toString()}');
    }
  }

  // Обновленная версия getHashtags с безопасным парсингом
  Future<List<Hashtag>> getHashtags() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/hashtags/'),
        headers: await _getHeaders(includeAuth: false),
      );

      print('Hashtags response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = _safeParseJson(response.body);
        final body = _safeParseList(data, 'hashtags');

        return body.map((dynamic item) {
          try {
            return Hashtag.fromJson(item);
          } catch (e) {
            print('Error parsing hashtag: $e');
            // Возвращаем заглушку вместо ошибки
            return Hashtag(id: 0, name: 'Error');
          }
        }).toList();
      } else {
        throw Exception('Failed to load hashtags: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getHashtags: $e');
      return []; // Возвращаем пустой список вместо ошибки
    }
  }

  Future<Story> createStory({
    required String title,
    required String content,
    required List<int> hashtagIds,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/stories'), // 🟢 ИСПРАВЛЕННЫЙ URL
      headers: await _getHeaders(includeAuth: true),
      body: jsonEncode(<String, dynamic>{
        'title': title,
        'content': content,
        'hashtags': hashtagIds, // 🟢 ИСПРАВЛЕНО: hashtags вместо hashtag_ids
      }),
    );

    if (response.statusCode == 201) {
      return Story.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception('Failed to create story: ${errorBody.toString()}');
    }
  }

  Future<List<Story>> _executeGetStoriesRequest() async {
    final headers = await _getHeaders(includeAuth: true);
    final response = await http
        .get(Uri.parse('$baseUrl/stories'), headers: headers)
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw TimeoutException(
              'Network request timed out after 15 seconds.',
            );
          },
        );

    print('Stories response status: ${response.statusCode}');
    print('Stories response body: ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      // 🟢 БЕЗОПАСНОЕ ИЗВЛЕЧЕНИЕ СПИСКА
      final List<dynamic>? body = data['stories'];

      if (body != null && body is List) {
        return body.map((dynamic item) => Story.fromJson(item)).toList();
      } else {
        print('Warning: stories field is not a list or is null');
        return [];
      }
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized');
    } else {
      throw Exception('Failed to load stories: ${response.statusCode}');
    }
  }

  Future<List<Story>> getStories() async {
    try {
      return await _executeGetStoriesRequest();
    } on Exception catch (e) {
      if (e.toString().contains('Unauthorized')) {
        debugPrint('Token expired on getStories. Attempting refresh...');
        try {
          await _authService.refreshToken();
          return await _executeGetStoriesRequest();
        } on Exception {
          await _authService.logout();
          throw Exception('AUTH_EXPIRED_LOGIN_REQUIRED');
        }
      } else if (e is TimeoutException) {
        rethrow;
      } else {
        rethrow;
      }
    }
  }

  Future<Story> getStory(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/stories/$id'), // 🟢 ИСПРАВЛЕННЫЙ URL
      headers: await _getHeaders(includeAuth: true),
    );

    if (response.statusCode == 200) {
      return Story.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to get story: ${response.statusCode}');
    }
  }

  Future<Story> updateStory({
    required int storyId,
    required String title,
    required String content,
    required List<int> hashtagIds,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/stories/$storyId'), // 🟢 ИСПРАВЛЕННЫЙ URL
      headers: await _getHeaders(includeAuth: true),
      body: jsonEncode(<String, dynamic>{
        'title': title,
        'content': content,
        'hashtags': hashtagIds, // 🟢 ИСПРАВЛЕНО
      }),
    );

    if (response.statusCode == 200) {
      return Story.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(
        'Failed to update story. Status: ${response.statusCode}, Body: ${errorBody.toString()}',
      );
    }
  }

  Future<void> deleteStory(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/stories/$id'), // 🟢 ИСПРАВЛЕННЫЙ URL
      headers: await _getHeaders(includeAuth: true),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete story: ${response.statusCode}');
    }
  }

  // --------------------------------------------------------------------------
  // МЕТОДЫ ДОПОЛНИТЕЛЬНОГО КОНТЕНТА
  // --------------------------------------------------------------------------

  Future<List<Comment>> getCommentsForStory(int storyId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stories/$storyId/comments'),
        headers: await _getHeaders(includeAuth: true),
      );

      print('Comments response status: ${response.statusCode}');
      print('Comments response body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic decodedBody = jsonDecode(utf8.decode(response.bodyBytes));

        // 🟢 ОБРАБОТКА РАЗНЫХ ФОРМАТОВ ОТВЕТА
        List<dynamic> body;

        if (decodedBody is List) {
          // Если ответ - сразу список
          body = decodedBody;
        } else if (decodedBody is Map<String, dynamic>) {
          // Если ответ - объект с полем comments
          body = decodedBody['comments'] ?? [];
        } else {
          body = [];
        }

        if (body is List) {
          return body.map((dynamic item) => Comment.fromJson(item)).toList();
        } else {
          print('Warning: comments field is not a list');
          return [];
        }
      } else {
        throw Exception(
          'Failed to get comments for story: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error in getCommentsForStory: $e');
      rethrow;
    }
  }

  Future<Comment> commentStory(
    int storyId,
    int user_id,
    String content,
    int? parentCommentId,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/comments'), // 🟢 ИСПРАВЛЕННЫЙ URL
      headers: await _getHeaders(includeAuth: true),
      body: jsonEncode(<String, dynamic>{
        'story_id': storyId,
        'content': content,
        'parent_comment_id': parentCommentId,
      }),
    );

    if (response.statusCode == 201) {
      return Comment.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to comment on story: ${response.body}');
    }
  }

  Future<void> markStoryAsNotInterested(int storyId) async {
    final response = await http.post(
      Uri.parse(
        '$baseUrl/stories/$storyId/not-interested',
      ), // 🟢 ИСПРАВЛЕННЫЙ URL
      headers: await _getHeaders(includeAuth: true),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Failed to mark story as not interested: ${response.statusCode}',
      );
    }
  }

  Future<List<Story>> searchStories(String searchTerm) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stories?search=$searchTerm'),
        headers: await _getHeaders(includeAuth: true),
      );

      print('Search stories response status: ${response.statusCode}');
      print('Search stories response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(
          utf8.decode(response.bodyBytes),
        );

        // 🟢 БЕЗОПАСНОЕ ИЗВЛЕЧЕНИЕ СПИСКА
        final List<dynamic>? body = data['stories'];

        if (body != null && body is List) {
          return body.map((dynamic item) => Story.fromJson(item)).toList();
        } else {
          print('Warning: search stories field is not a list or is null');
          return [];
        }
      } else {
        throw Exception('Failed to search stories: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in searchStories: $e');
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // МЕТОДЫ ЛОКАЛЬНОГО ХРАНЕНИЯ
  // --------------------------------------------------------------------------
  // 🟢 БЕЗОПАСНЫЕ МЕТОДЫ ДЛЯ ОБРАБОТКИ JSON
  List<dynamic> _safeParseList(dynamic data, String fieldName) {
    try {
      if (data is Map<String, dynamic>) {
        final field = data[fieldName];
        if (field != null && field is List) {
          return field;
        }
      } else if (data is List) {
        return data;
      }
      print('Warning: $fieldName field is not a list or is null');
      return [];
    } catch (e) {
      print('Error parsing $fieldName: $e');
      return [];
    }
  }

  // 🟢 БЕЗОПАСНЫЙ ПАРСИНГ ОТВЕТА
  Map<String, dynamic> _safeParseJson(String responseBody) {
    try {
      final decoded = jsonDecode(utf8.decode(responseBody.codeUnits));
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (e) {
      print('Error parsing JSON: $e');
      return {};
    }
  }

  Future<void> saveStoriesLocally(List<Story> stories) async {
    await _storageService.saveStories(stories);
  }

  Future<List<Story>> getLocalStories() async {
    return _storageService.readStories();
  }

  Future<void> clearLocalStories() async {
    await _storageService.clearCache();
  }
}
