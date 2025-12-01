// services/story_service.dart
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

  final String baseUrl = 'https://ravell-backend-1.onrender.com';

  // --------------------------------------------------------------------------
  // УЛУЧШЕННЫЕ МЕТОДЫ ДЛЯ РАБОТЫ С JSON И КОДИРОВКОЙ
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

  // 🟢 УЛУЧШЕННЫЙ МЕТОД ДЛЯ БЕЗОПАСНОГО ДЕКОДИРОВАНИЯ JSON
  dynamic _safeJsonDecode(http.Response response) {
    try {
      // Сначала пытаемся декодировать как UTF-8
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      print('UTF-8 decoding failed: $e');

      // Если UTF-8 не работает, пробуем latin1 как запасной вариант
      try {
        return jsonDecode(latin1.decode(response.bodyBytes));
      } catch (e2) {
        print('Latin1 decoding also failed: $e2');

        // В крайнем случае, пытаемся обработать сырые байты
        try {
          return jsonDecode(response.body);
        } catch (e3) {
          print('Raw body decoding failed: $e3');
          throw FormatException('Invalid JSON encoding: $e3');
        }
      }
    }
  }

  // 🟢 МЕТОД ДЛЯ ОЧИСТКИ НЕВАЛИДНЫХ UTF-8 СИМВОЛОВ
  String _cleanInvalidUtf8(String input) {
    try {
      // Пытаемся преобразовать и обратно - это отфильтрует невалидные символы
      return utf8.decode(utf8.encode(input), allowMalformed: true);
    } catch (e) {
      // Если всё совсем плохо, возвращаем пустую строку
      return '';
    }
  }

  // 🟢 БЕЗОПАСНЫЙ ПАРСИНГ JSON СТРОКИ
  Map<String, dynamic> _safeParseJson(String responseBody) {
    try {
      // Очищаем строку от невалидных UTF-8 символов
      final cleanedBody = _cleanInvalidUtf8(responseBody);
      final decoded = jsonDecode(cleanedBody);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (e) {
      print('Error parsing JSON: $e');
      return {};
    }
  }

  // 🟢 БЕЗОПАСНОЕ ИЗВЛЕЧЕНИЕ СПИСКА ИЗ ДАННЫХ
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

  // --------------------------------------------------------------------------
  // МЕТОДЫ ЛАЙКОВ И СТАТУСА
  // --------------------------------------------------------------------------

  Future<Map<String, dynamic>> _executeLikeRequest(int storyId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/like'),
      headers: await _getHeaders(includeAuth: true),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _safeJsonDecode(response);
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
      return responseData['likes_count'] as int;
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
        Uri.parse('$baseUrl/stories/$storyId'),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response);
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
  // МЕТОДЫ ХЕШТЕГОВ
  // --------------------------------------------------------------------------

  Future<Hashtag> createHashtag(String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/hashtags/'),
      headers: await _getHeaders(includeAuth: true),
      body: jsonEncode(<String, String>{'name': name}),
    );

    if (response.statusCode == 201) {
      return Hashtag.fromJson(_safeJsonDecode(response));
    } else {
      final errorBody = _safeJsonDecode(response);
      throw Exception('Failed to create hashtag: ${errorBody.toString()}');
    }
  }

  Future<List<Hashtag>> getHashtags() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/hashtags/'),
        headers: await _getHeaders(includeAuth: false),
      );

      print('Hashtags response status: ${response.statusCode}');
      print('Hashtags response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response);
        final body = _safeParseList(data, 'hashtags');

        return body.map((dynamic item) {
          try {
            return Hashtag.fromJson(item);
          } catch (e) {
            print('Error parsing hashtag: $e');
            return Hashtag(id: 0, name: 'Error');
          }
        }).toList();
      } else {
        throw Exception('Failed to load hashtags: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getHashtags: $e');
      return [];
    }
  }

  // --------------------------------------------------------------------------
  // МЕТОДЫ СТОРИС
  // --------------------------------------------------------------------------

  Future<Story> createStory({
    required String title,
    required String content,
    required List<int> hashtagIds,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/stories'),
      headers: await _getHeaders(includeAuth: true),
      body: jsonEncode(<String, dynamic>{
        'title': title,
        'content': content,
        'hashtags': hashtagIds,
      }),
    );

    if (response.statusCode == 201) {
      return Story.fromJson(_safeJsonDecode(response));
    } else {
      final errorBody = _safeJsonDecode(response);
      throw Exception('Failed to create story: ${errorBody.toString()}');
    }
  }

  Future<List<Story>> _executeGetStoriesRequest() async {
    final headers = await _getHeaders(includeAuth: true);

    // ✅ ИСПРАВЛЯЕМ URL - убираем лишний слеш если есть
    final url = '$baseUrl/stories'.replaceAll('//', '/');

    print('Fetching stories from: $url');

    final response = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw TimeoutException(
              'Network request timed out after 15 seconds.',
            );
          },
        );

    print('Stories response status: ${response.statusCode}');
    print('Stories response headers: ${response.headers}');

    if (response.statusCode == 200) {
      final data = _safeJsonDecode(response);
      final List<dynamic>? body = data['stories'];

      if (body != null && body is List) {
        return body.map((dynamic item) => Story.fromJson(item)).toList();
      } else {
        print('Warning: stories field is not a list or is null');
        return [];
      }
    } else if (response.statusCode == 301 || response.statusCode == 302) {
      // Обработка редиректа
      final redirectUrl = response.headers['location'];
      if (redirectUrl != null) {
        print('Following redirect to: $redirectUrl');
        final redirectResponse = await http.get(
          Uri.parse(redirectUrl),
          headers: headers,
        );

        if (redirectResponse.statusCode == 200) {
          final data = _safeJsonDecode(redirectResponse);
          final List<dynamic>? body = data['stories'];

          if (body != null && body is List) {
            return body.map((dynamic item) => Story.fromJson(item)).toList();
          }
        }
      }
      throw Exception('Redirect failed');
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized');
    } else {
      print('Response body: ${response.body}');
      throw Exception('Failed to load stories: ${response.statusCode}');
    }
  }

  // 🟢 ОБНОВЛЕННЫЙ МЕТОД ДЛЯ ПРОВЕРКИ СОЕДИНЕНИЯ
  Future<bool> checkServerConnection() async {
    try {
      final url = '$baseUrl/health'.replaceAll('//', '/');
      print('Checking connection to: $url');

      final response = await http
          .get(Uri.parse(url), headers: await _getHeaders(includeAuth: false))
          .timeout(const Duration(seconds: 5));

      print('Health check status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response);
        return data['status'] == 'ok';
      }
      return false;
    } catch (e) {
      print('Server connection check failed: $e');

      // ✅ Пробуем сделать простой GET запрос на основной эндпоинт как fallback
      try {
        final url = '$baseUrl/'.replaceAll('//', '/');
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 3));
        print('Fallback check status: ${response.statusCode}');
        return response.statusCode <
            500; // Любой ответ кроме 5xx считаем успехом
      } catch (e2) {
        print('Fallback connection check also failed: $e2');
        return false;
      }
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
      Uri.parse('$baseUrl/stories/$id'),
      headers: await _getHeaders(includeAuth: true),
    );

    if (response.statusCode == 200) {
      return Story.fromJson(_safeJsonDecode(response));
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
      Uri.parse('$baseUrl/stories/$storyId'),
      headers: await _getHeaders(includeAuth: true),
      body: jsonEncode(<String, dynamic>{
        'title': title,
        'content': content,
        'hashtags': hashtagIds,
      }),
    );

    if (response.statusCode == 200) {
      return Story.fromJson(_safeJsonDecode(response));
    } else {
      final errorBody = _safeJsonDecode(response);
      throw Exception(
        'Failed to update story. Status: ${response.statusCode}, Body: ${errorBody.toString()}',
      );
    }
  }

  Future<void> deleteStory(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/stories/$id'),
      headers: await _getHeaders(includeAuth: true),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete story: ${response.statusCode}');
    }
  }

  // --------------------------------------------------------------------------
  // МЕТОДЫ КОММЕНТАРИЕВ
  // --------------------------------------------------------------------------

  Future<List<Comment>> getCommentsForStory(int storyId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stories/$storyId/comments'),
        headers: await _getHeaders(includeAuth: true),
      );

      print('Comments response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic decodedBody = _safeJsonDecode(response);

        List<dynamic> body;

        if (decodedBody is List) {
          body = decodedBody;
        } else if (decodedBody is Map<String, dynamic>) {
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
      Uri.parse('$baseUrl/comments'),
      headers: await _getHeaders(includeAuth: true),
      body: jsonEncode(<String, dynamic>{
        'story_id': storyId,
        'content': content,
        'parent_comment_id': parentCommentId,
      }),
    );

    if (response.statusCode == 201) {
      return Comment.fromJson(_safeJsonDecode(response));
    } else {
      throw Exception('Failed to comment on story: ${response.body}');
    }
  }

  // --------------------------------------------------------------------------
  // МЕТОДЫ ПОИСКА И ВЗАИМОДЕЙСТВИЯ
  // --------------------------------------------------------------------------

  Future<void> markStoryAsNotInterested(int storyId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/not-interested'),
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

      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response);
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

  Future<List<Story>> getStoriesByHashtag(int hashtagId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/hashtags/$hashtagId/stories'),
        headers: await _getHeaders(includeAuth: true),
      );

      print('Hashtag stories response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response);
        final List<dynamic>? body = data['stories'];

        if (body != null && body is List) {
          return body.map((dynamic item) => Story.fromJson(item)).toList();
        } else {
          print('Warning: hashtag stories field is not a list or is null');
          return [];
        }
      } else {
        throw Exception(
          'Failed to get hashtag stories: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error in getStoriesByHashtag: $e');
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // МЕТОДЫ ЛОКАЛЬНОГО ХРАНЕНИЯ
  // --------------------------------------------------------------------------

  Future<void> saveStoriesLocally(List<Story> stories) async {
    await _storageService.saveStories(stories);
  }

  Future<List<Story>> getLocalStories() async {
    return _storageService.readStories();
  }

  Future<void> clearLocalStories() async {
    await _storageService.clearCache();
  }

  // --------------------------------------------------------------------------
  // ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
  // --------------------------------------------------------------------------

  Future<List<Story>> getUserStories(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/stories'),
        headers: await _getHeaders(includeAuth: true),
      );

      print('User stories response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response);
        final List<dynamic>? body = data['stories'];

        if (body != null && body is List) {
          return body.map((dynamic item) => Story.fromJson(item)).toList();
        } else {
          print('Warning: user stories field is not a list or is null');
          return [];
        }
      } else {
        throw Exception('Failed to get user stories: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getUserStories: $e');
      rethrow;
    }
  }

  Future<List<Story>> getFeedStories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/feed'),
        headers: await _getHeaders(includeAuth: true),
      );

      print('Feed stories response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response);
        final List<dynamic>? body = data['stories'];

        if (body != null && body is List) {
          return body.map((dynamic item) => Story.fromJson(item)).toList();
        } else {
          print('Warning: feed stories field is not a list or is null');
          return [];
        }
      } else {
        throw Exception('Failed to get feed stories: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getFeedStories: $e');
      rethrow;
    }
  }

  // 🟢 МЕТОД ДЛЯ ПОВТОРНОЙ ПОПЫТКИ ЗАПРОСА
  Future<T> retryRequest<T>(
    Future<T> Function() request, {
    int maxRetries = 3,
  }) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        return await request();
      } catch (e) {
        if (i == maxRetries - 1) rethrow;
        await Future.delayed(Duration(seconds: 1 * (i + 1)));
        print('Retrying request (attempt ${i + 2}/$maxRetries)');
      }
    }
    throw Exception('Max retries exceeded');
  }
}
