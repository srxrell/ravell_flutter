import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
// import 'package:readreels/services/story_storage_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

// ИМПОРТ: Используем общую точку входа, которая сама выберет
// мобильную или веб-реализацию (StoryStorageIO или StoryStorageWeb).
import 'package:readreels/services/story_storage_service.dart';

import '../models/story.dart';
import '../models/comment.dart';
import '../models/hashtag.dart';
import 'auth_service.dart';

class StoryService {
  // ИНИЦИАЛИЗАЦИЯ: Используем общий интерфейс (StoryStorageInterface)
  final StoryStorageInterface _storageService = createStoryStorage();

  // 🟢 ИСПРАВЛЕНО: Используем единый инстанс AuthService
  final AuthService _authService = AuthService();

  // 🚨 ПРОВЕРЬТЕ IP: Убедитесь, что 192.168.1.104 доступен.
  // Для эмулятора Android часто нужно использовать 10.0.2.2.
  final String rootUrl = 'http://192.168.1.104:8080';
  final String storiesUrl = 'http://192.168.1.104:8080/stories';

  // --------------------------------------------------------------------------
  //                         МЕТОДЫ АВТОРИЗАЦИИ И ЗАГОЛОВКОВ
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
  //                             МЕТОДЫ ЛАЙКОВ И СТАТУСА
  // --------------------------------------------------------------------------

  Future<Map<String, dynamic>> _executeLikeRequest(
    int storyId,
    String? accessToken,
  ) async {
    final response = await http.post(
      Uri.parse('$storiesUrl/$storyId/like/'),
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

  Future<int> likeStory(int storyId, int userId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('access_token');

    try {
      final responseData = await _executeLikeRequest(storyId, accessToken);
      return responseData['new_likes_count'] as int;
    } on Exception catch (e) {
      if (e.toString().contains('Unauthorized')) {
        // 🟢 ИСПРАВЛЕНО: Используем _authService
        await _authService.refreshToken();
        accessToken = prefs.getString('access_token');
        if (accessToken == null) {
          throw Exception('Session expired. Please log in again.');
        }
        try {
          final responseData = await _executeLikeRequest(storyId, accessToken);
          return responseData['new_likes_count'] as int;
        } catch (e) {
          throw Exception('Failed to like story even after token refresh: $e');
        }
      } else {
        rethrow;
      }
    }
  }

  Future<bool> isStoryLiked(int storyId, int userId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('access_token');

    Future<Map<String, dynamic>> executeStatusRequest(
      String? currentAccessToken,
    ) async {
      final response = await http.get(
        Uri.parse('$storiesUrl/$storyId/like/'),
        headers: await _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized');
      } else {
        throw Exception(
          'Failed to check like status. Status code: ${response.statusCode}',
        );
      }
    }

    try {
      final responseData = await executeStatusRequest(accessToken);
      return responseData['is_like'] ?? false;
    } on Exception catch (e) {
      if (e.toString().contains('Unauthorized')) {
        // 🟢 ИСПРАВЛЕНО: Используем _authService
        await _authService.refreshToken();
        accessToken = prefs.getString('access_token');

        if (accessToken == null) return false;

        try {
          final responseData = await executeStatusRequest(accessToken);
          return responseData['is_like'] ?? false;
        } catch (e) {
          debugPrint('Failed to check status even after token refresh.');
          return false;
        }
      } else {
        debugPrint('Error fetching like status: $e');
        return false;
      }
    }
  }

  // --------------------------------------------------------------------------
  //                             МЕТОДЫ ХЕШТЕГОВ И СТОРИС
  // --------------------------------------------------------------------------

  Future<Hashtag> createHashtag(String name) async {
    final response = await http.post(
      Uri.parse('$rootUrl/hashtags/'),
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

  Future<List<Hashtag>> getHashtags() async {
    final response = await http.get(
      Uri.parse('$rootUrl/hashtags/'),
      headers: await _getHeaders(includeAuth: false),
    );

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((dynamic item) => Hashtag.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load hashtags: ${response.statusCode}');
    }
  }

  Future<Story> createStory({
    required String title,
    required String content,
    required List<int> hashtagIds,
  }) async {
    final response = await http.post(
      Uri.parse('$storiesUrl/'),
      headers: await _getHeaders(includeAuth: true),
      body: jsonEncode(<String, dynamic>{
        'title': title,
        'content': content,
        'hashtag_ids': hashtagIds,
      }),
    );

    if (response.statusCode == 201) {
      return Story.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception('Failed to create story: ${errorBody.toString()}');
    }
  }

  // 🟢 НОВЫЙ ВСПОМОГАТЕЛЬНЫЙ МЕТОД: для выполнения запроса историй
  Future<List<Story>> _executeGetStoriesRequest() async {
    final headers = await _getHeaders(includeAuth: true);
    final response = await http
        .get(Uri.parse('$storiesUrl/'), headers: headers)
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw TimeoutException(
              'Network request timed out after 15 seconds.',
            );
          },
        );

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((dynamic item) => Story.fromJson(item)).toList();
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized'); // Явно выбрасываем ошибку для обработки
    } else {
      throw Exception('Failed to load stories: ${response.statusCode}');
    }
  }

  // 🟢 ИСПРАВЛЕННЫЙ МЕТОД: Включает логику обновления токена
  Future<List<Story>> getStories() async {
    try {
      return await _executeGetStoriesRequest(); // 1. Первая попытка
    } on Exception catch (e) {
      if (e.toString().contains('Unauthorized')) {
        debugPrint('Token expired on getStories. Attempting refresh...');
        try {
          await _authService.refreshToken(); // 2. Обновление токена
          // 3. Повторный вызов после обновления
          return await _executeGetStoriesRequest();
        } on Exception {
          // Если обновление токена не удалось
          debugPrint('Token refresh failed. Redirecting to login.');

          // Опционально: Очистка данных
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
      Uri.parse('$storiesUrl?id=$id'),
      headers: await _getHeaders(includeAuth: true),
    );

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(response.body);
      if (body.isNotEmpty) {
        return Story.fromJson(body.first);
      } else {
        throw Exception('Story not found');
      }
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
      Uri.parse('$storiesUrl/$storyId/'),
      headers: await _getHeaders(includeAuth: true),
      body: jsonEncode(<String, dynamic>{
        'title': title,
        'content': content,
        'hashtag_ids': hashtagIds,
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
      Uri.parse('$storiesUrl/$id/'),
      headers: await _getHeaders(includeAuth: true),
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete story: ${response.statusCode}');
    }
  }

  // --------------------------------------------------------------------------
  //                             МЕТОДЫ ДОПОЛНИТЕЛЬНОГО КОНТЕНТА
  // --------------------------------------------------------------------------

  Future<List<Comment>> getCommentsForStory(int storyId) async {
    final response = await http.get(
      Uri.parse('$rootUrl/comments/$storyId/'),
      headers: await _getHeaders(includeAuth: true),
    );

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((dynamic item) => Comment.fromJson(item)).toList();
    } else {
      throw Exception(
        'Failed to get comments for story: ${response.statusCode}',
      );
    }
  }

  Future<Comment> commentStory(
    int storyId,
    int userId,
    String content,
    int? parentCommentId,
  ) async {
    final response = await http.post(
      Uri.parse('$rootUrl/comments/create/'),
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
    final url = Uri.parse('$storiesUrl/not-interested/');

    Future<void> executeNotInterestedRequest() async {
      final response = await http.post(
        url,
        headers: await _getHeaders(includeAuth: true),
        body: jsonEncode(<String, int>{'story': storyId}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return;
      }

      if (response.statusCode == 401) {
        throw Exception('Unauthorized');
      }

      throw Exception(
        'Failed to mark story as not interested. Status code: ${response.statusCode}, body: ${response.body}',
      );
    }

    try {
      await executeNotInterestedRequest();
    } on Exception catch (e) {
      if (e.toString().contains('Unauthorized')) {
        // 🟢 ИСПРАВЛЕНО: Используем _authService
        final prefs = await SharedPreferences.getInstance();

        try {
          await _authService.refreshToken();
          final accessToken = prefs.getString('access_token');

          if (accessToken == null) {
            throw Exception('Session expired. Please log in again.');
          }
          await executeNotInterestedRequest();
        } catch (e) {
          throw Exception(
            'Failed to mark story as not interested even after token refresh: $e',
          );
        }
      } else {
        rethrow;
      }
    }
  }

  Future<List<Story>> searchStories(String searchTerm) async {
    final response = await http.get(
      Uri.parse('$storiesUrl/?searchTerm=$searchTerm'),
      headers: await _getHeaders(includeAuth: true),
    );

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((dynamic item) => Story.fromJson(item)).toList();
    } else {
      throw Exception('Failed to search stories: ${response.statusCode}');
    }
  }

  // --------------------------------------------------------------------------
  //                         МЕТОДЫ ЛОКАЛЬНОГО ХРАНЕНИЯ (КРОССПЛАТФОРМА)
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
}
