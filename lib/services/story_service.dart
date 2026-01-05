import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'package:readreels/services/story_storage_service.dart';
import 'package:readreels/services/app_logger.dart';
import '../models/story.dart';
import '../models/comment.dart';
import '../models/hashtag.dart';
import 'ai_service.dart';
import 'auth_service.dart';

class StoryService {
  final StoryStorageInterface _storageService = createStoryStorage();
  final AuthService _authService = AuthService();

  // 🛑 FIX: Используем 10.0.2.2 для Android эмулятора, если это не реальное устройство
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

  Future<List<Story>> getSeeds() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stories/seeds'),
        headers: await _getHeaders(includeAuth: false),
      );

      // LOG
      AppLogger.api('GET /stories/seeds', data: {'code': response.statusCode});

      print('Seeds response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response);
        final List<dynamic> body = _safeParseList(data, 'stories');

        return body.map((dynamic item) => Story.fromJson(item)).toList();
      } else {
        throw Exception('Failed to fetch seeds: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getSeeds: $e');
      rethrow;
    }
  }

  // Получить ветки (Branches)
  Future<List<Story>> getBranches() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stories/branches'),
        headers: await _getHeaders(includeAuth: false),
      );

      // LOG
      AppLogger.api('GET /stories/branches', data: {'code': response.statusCode});

      print('Branches response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response);
        final List<dynamic> body = _safeParseList(data, 'stories');

        return body.map((dynamic item) => Story.fromJson(item)).toList();
      } else {
        throw Exception('Failed to fetch branches: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getBranches: $e');
      rethrow;
    }
  }

  // Создать историю с ответом (reply)
  Future<Story> createStoryWithReply({
    required String title,
    required String content,
    required List<int> hashtagIds,
    required int? replyTo, // ID родительской истории
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/stories/'),
      headers: await _getHeaders(includeAuth: true),
      body: jsonEncode(<String, dynamic>{
        'title': title,
        'content': content,
        'hashtag_ids': hashtagIds,
        'reply_to': replyTo,
      }),
    );

    if (response.statusCode == 201) {
      final data = _safeJsonDecode(response);
      if (data is Map<String, dynamic>) {
        return Story.fromJson(data);
      }
      throw const FormatException('Invalid response format for story creation');
    } else {
      final errorBody = _safeJsonDecode(response);
      throw Exception(
        'Failed to create story: ${errorBody['error'] ?? errorBody.toString()}',
      );
    }
  }

  Map<String, dynamic>? _findMostActiveUser(List<Story> replies) {
    if (replies.isEmpty) return null;

    final userCounts = <int, int>{};
    for (final reply in replies) {
      userCounts[reply.userId] = (userCounts[reply.userId] ?? 0) + 1;
    }

    final maxUserId =
        userCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    final mostActiveStory = replies.firstWhere(
      (story) => story.userId == maxUserId,
    );

    return {
      'user_id': maxUserId,
      'username': mostActiveStory.username, // Теперь используем геттер
      'avatar_url': mostActiveStory.avatarUrl,
      'reply_count': userCounts[maxUserId],
    };
  }

  // 🟢 БЕЗОПАСНЫЙ МЕТОД ДЛЯ ДЕКОДИРОВАНИЯ JSON
  dynamic _safeJsonDecode(http.Response response) {
    String bodyString = utf8.decode(response.bodyBytes);
    print('[LOG: JSON] Decoding JSON for status ${response.statusCode}');
    print(
      '[LOG: JSON] Raw body preview: ${bodyString.substring(0, bodyString.length > 200 ? 200 : bodyString.length)}',
    );

    try {
      // Пытаемся декодировать как UTF-8, используя bodyBytes
      final decodedData = jsonDecode(bodyString);
      print(
        '[LOG: JSON] Decode successful. Data type: ${decodedData.runtimeType}',
      );
      return decodedData;
    } catch (e) {
      print('[LOG: JSON] ERROR: Decoding failed: $e');

      try {
        // В крайнем случае, пытаемся обработать сырую строку
        final decodedDataFallback = jsonDecode(response.body);
        print(
          '[LOG: JSON] Fallback decode successful. Data type: ${decodedDataFallback.runtimeType}',
        );
        return decodedDataFallback;
      } catch (e2) {
        print('[LOG: JSON] ERROR: Fallback decode also failed: $e2');
        // Возвращаем пустую Map, если декодирование полностью провалилось.
        return {};
      }
    }
  }

  // 🟢 БЕЗОПАСНОЕ ИЗВЛЕЧЕНИЕ СПИСКА ИЗ ДАННЫХ
  // Используется для получения списков историй, комментариев и т.д.
  List<dynamic> _safeParseList(dynamic data, String fieldName) {
    print(
      '[LOG: PARSE] Attempting to parse list for field: "$fieldName". Received type: ${data.runtimeType}',
    );

    if (data is Map<String, dynamic>) {
      print('[LOG: PARSE] Data is Map. Checking for key: "$fieldName"');
      final field = data[fieldName];

      if (field != null && field is List) {
        print(
          '[LOG: PARSE] Success! Extracted List from Map key "$fieldName". List length: ${field.length}',
        );
        return field;
      }

      print(
        '[LOG: PARSE] WARNING: Key "$fieldName" not found or is not a List. Received field type: ${field.runtimeType}',
      );
    } else if (data is List) {
      // Если сам decoded data оказался List (например, если Go вернул прямой список)
      print(
        '[LOG: PARSE] Data is already a List. Using it directly. List length: ${data.length}',
      );
      return data;
    }

    print(
      '[LOG: PARSE] WARNING: Failed to extract list. Returning empty list.',
    );
    return [];
  }

  // --------------------------------------------------------------------------
  // МЕТОДЫ ЛАЙКОВ И СТАТУСА
  // --------------------------------------------------------------------------

  Future<Map<String, dynamic>> _executeLikeRequest(int storyId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/stories/$storyId/like'),
      headers: await _getHeaders(includeAuth: true),
    );

    final responseData = _safeJsonDecode(response);

    if (response.statusCode == 200 || response.statusCode == 201) {
      if (responseData is Map<String, dynamic>) {
        return responseData;
      }
      throw const FormatException('Invalid JSON format for like response');
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized');
    } else {
      throw Exception(
        'Failed to like story. Status code: ${response.statusCode}, body: ${responseData['error'] ?? response.body}',
      );
    }
  }

  Future<int> likeStory(int storyId, int user_id) async {
    try {
      final responseData = await _executeLikeRequest(storyId);
      final likesCount = responseData['likes_count'];
      if (likesCount is int) {
        return likesCount;
      } else if (likesCount is num) {
        return likesCount.toInt();
      }
      throw const FormatException(
        'Missing or invalid likes_count in response.',
      );
    } on Exception catch (e) {
      if (e.toString().contains('Unauthorized')) {
        await _authService.refreshToken();
        final responseData = await _executeLikeRequest(storyId);
        final likesCount = responseData['likes_count'];
        if (likesCount is int) {
          return likesCount;
        } else if (likesCount is num) {
          return likesCount.toInt();
        }
        throw const FormatException(
          'Missing or invalid likes_count after refresh.',
        );
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
        // 🛑 FIX: Проверяем, что data является Map
        if (data is Map<String, dynamic>) {
          // Заметка: Ваш Go Backend должен возвращать 'is_liked' в GetStory
          return data['is_liked'] ?? false;
        }
        return false;
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
    return _executeWithRefresh(() async {
      await aiService.moderateTag(name);
      final response = await http.post(
        Uri.parse('$baseUrl/hashtags/'),
        headers: await _getHeaders(includeAuth: true),
        body: jsonEncode(<String, String>{'name': name}),
      );

      if (response.statusCode == 201) {
        final data = _safeJsonDecode(response);
        if (data is Map<String, dynamic>) {
          return Hashtag.fromJson(data);
        }
        throw const FormatException(
          'Invalid response format for hashtag creation',
        );
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized');
      } else {
        final errorBody = _safeJsonDecode(response);
        throw Exception(
          'Failed to create hashtag: ${errorBody['error'] ?? errorBody.toString()}',
        );
      }
    });
  }

  Future<List<Hashtag>> getHashtags() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/hashtags/'),
        headers: await _getHeaders(includeAuth: false),
      );

      AppLogger.api('GET /hashtags/', data: {'code': response.statusCode});
      print('Hashtags response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response);
        // 🟢 Используем _safeParseList для безопасного извлечения списка по ключу 'hashtags'
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
        final errorBody = _safeJsonDecode(response);
        throw Exception(
          'Failed to load hashtags: ${response.statusCode}. Error: ${errorBody['error'] ?? response.body}',
        );
      }
    } catch (e) {
      print('Error in getHashtags: $e');
      return [];
    }
  }

  final aiService = AIService();

  // --------------------------------------------------------------------------
  // МЕТОДЫ СТОРИС
  // --------------------------------------------------------------------------

  Future<Story> createStory({
    required String title,
    required String content,
    required List<int> hashtagIds,
    BuildContext? context
  }) async {
      await aiService.moderateContent(title, content, context: context);
    return _executeWithRefresh(() async {
      final response = await http.post(
        Uri.parse('$baseUrl/stories/'),
        headers: await _getHeaders(includeAuth: true),
        body: jsonEncode(<String, dynamic>{
          'title': title,
          'content': content,
          'hashtag_ids': hashtagIds,
        }),
      );

      if (response.statusCode == 201) {
        
        final data = _safeJsonDecode(response);
        if (data is Map<String, dynamic>) {
          return Story.fromJson(data);
        }
        throw const FormatException('Invalid response format for story creation');
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized');
      } else {
        final errorBody = _safeJsonDecode(response);
        throw Exception(
          'Failed to create story: ${errorBody['error'] ?? errorBody.toString()}',
        );
      }
    });
  }

  // 🟢 Helper for executing requests with token refresh logic
  Future<T> _executeWithRefresh<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      if (e.toString().contains('Unauthorized') || e.toString().contains('token is expired')) {
        print('🔄 Token expired during request. Refreshing...');
        try {
          await _authService.refreshToken();
          print('✅ Token refreshed. Retrying request...');
          return await action();
        } catch (refreshError) {
          print('❌ Token refresh failed: $refreshError');
          await _authService.logout();
           throw Exception('AUTH_EXPIRED_LOGIN_REQUIRED');
        }
      }
      rethrow;
    }
  }

  Future<List<Story>> _executeGetStoriesRequest({String? search}) async {
    final headers = await _getHeaders(includeAuth: true);
    // Добавляем параметр поиска, если он есть
    String url = '$baseUrl/stories';
    if (search != null && search.isNotEmpty) {
      url = '$url?search=$search';
    }

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

    if (response.statusCode == 200) {
      final data = _safeJsonDecode(response);

      if (data is! Map<String, dynamic>) {
        // Это маловероятно, если бэкенд возвращает {"stories": [...]}.
        // Если это сработает, значит бэкенд сломан или вернул не JSON.
        throw const FormatException(
          'Expected a Map response, but received a List or null.',
        );
      }

      // 🟢 ЭТО КЛЮЧЕВОЕ ИСПРАВЛЕНИЕ: Безопасно извлекаем список по ключу 'stories'
      final List<dynamic> body = _safeParseList(data, 'stories');

      return body.map((dynamic item) => Story.fromJson(item)).toList();
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized');
    } else {
      final errorBody = _safeJsonDecode(response);
      throw Exception(
        'Failed to load stories: ${response.statusCode}. Error: ${errorBody['error'] ?? response.body}',
      );
    }
  }

  Future<List<Story>> getStories() async {
    try {
      // 🟢 УСИЛЕНИЕ: Используем retryRequest для повышения надежности
      return await retryRequest(() => _executeGetStoriesRequest());
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

  /// ✅ НОВЫЙ МЕТОД: Получает все истории, которые являются ответами на указанную storyId.
  /// Предполагаемый URL: /stories/{storyId}/replies
  Future<List<Story>> getRepliesForStory(int storyId) async {
    try {
      final response = await http.get(
        // Предполагаемый эндпоинт для ответов
        Uri.parse('$baseUrl/stories/$storyId/replies'),
        headers: await _getHeaders(includeAuth: true),
      );

      print(
        'Replies response status for Story $storyId: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response);
        // 🟢 Безопасно извлекаем список по ключу 'replies' или 'stories'
        // В данном случае, я предполагаю ключ 'stories', как и в других методах,
        // но вы можете изменить его на 'replies', если ваш бэкенд использует его.
        final List<dynamic> body = _safeParseList(data, 'stories');

        return body.map((dynamic item) => Story.fromJson(item)).toList();
      } else {
        final errorBody = _safeJsonDecode(response);
        throw Exception(
          'Failed to fetch replies for story $storyId: ${response.statusCode}. Error: ${errorBody['error'] ?? response.body}',
        );
      }
    } catch (e) {
      print('Error in getRepliesForStory: $e');
      rethrow;
    }
  }

  Future<Story> getStory(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/stories/$id'),
      headers: await _getHeaders(includeAuth: true),
    );

    if (response.statusCode == 200) {
      final data = _safeJsonDecode(response);
      if (data is Map<String, dynamic>) {
        return Story.fromJson(data);
      }
      throw const FormatException('Invalid response format for single story');
    } else {
      final errorBody = _safeJsonDecode(response);
      throw Exception(
        'Failed to get story: ${response.statusCode}. Error: ${errorBody['error'] ?? response.body}',
      );
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
        'hashtag_ids': hashtagIds,
      }),
    );

    if (response.statusCode == 200) {
      final data = _safeJsonDecode(response);
      if (data is Map<String, dynamic>) {
        return Story.fromJson(data);
      }
      throw const FormatException('Invalid response format for update story');
    } else {
      final errorBody = _safeJsonDecode(response);
      throw Exception(
        'Failed to update story. Status: ${response.statusCode}, Body: ${errorBody['error'] ?? errorBody.toString()}',
      );
    }
  }

  Future<void> deleteStory(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/stories/$id'),
      headers: await _getHeaders(includeAuth: true),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorBody = _safeJsonDecode(response);
      throw Exception(
        'Failed to delete story: ${response.statusCode}. Error: ${errorBody['error'] ?? response.body}',
      );
    }
  }

  // --------------------------------------------------------------------------
  // МЕТОДЫ КОММЕНТАРИЕВ
  // --------------------------------------------------------------------------

  Future<List<Comment>> getCommentsForStory(int storyId) async {
    try {
      final response = await http.get(
        // URL: $baseUrl/stories/$storyId/comments (Соответствует Go Backend)
        Uri.parse('$baseUrl/stories/$storyId/comments'),
        headers: await _getHeaders(includeAuth: true),
      );

      print('Comments response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic decodedBody = _safeJsonDecode(response);
        // 🟢 FIX: Используем _safeParseList с ключом 'comments'
        final List<dynamic> body = _safeParseList(decodedBody, 'comments');

        return body.map((dynamic item) => Comment.fromJson(item)).toList();
      } else {
        final errorBody = _safeJsonDecode(response);
        throw Exception(
          'Failed to get comments for story: ${response.statusCode}. Error: ${errorBody['error'] ?? response.body}',
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
      final data = _safeJsonDecode(response);
      if (data is Map<String, dynamic>) {
        return Comment.fromJson(data);
      }
      throw const FormatException(
        'Invalid response format for comment creation',
      );
    } else {
      final errorBody = _safeJsonDecode(response);
      throw Exception(
        'Failed to comment on story: ${errorBody['error'] ?? response.body}',
      );
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
      final errorBody = _safeJsonDecode(response);
      throw Exception(
        'Failed to mark story as not interested: ${response.statusCode}. Error: ${errorBody['error'] ?? response.body}',
      );
    }
  }

  // 🟢 МЕТОД ПОИСКА ИСТОРИЙ
  Future<List<Story>> searchStories(String searchTerm) async {
    try {
      // 🟢 УСИЛЕНИЕ: Используем retryRequest для повышения надежности
      return await retryRequest(
        () => _executeGetStoriesRequest(search: searchTerm),
      );
    } on Exception catch (e) {
      if (e.toString().contains('Unauthorized')) {
        debugPrint('Token expired on searchStories. Attempting refresh...');
        try {
          await _authService.refreshToken();
          return await _executeGetStoriesRequest(search: searchTerm);
        } on Exception {
          await _authService.logout();
          throw Exception('AUTH_EXPIRED_LOGIN_REQUIRED');
        }
      } else {
        print('Error in searchStories: $e');
        rethrow;
      }
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
        // 🟢 Используем _safeParseList с ключом 'stories'
        final List<dynamic> body = _safeParseList(data, 'stories');

        return body.map((dynamic item) => Story.fromJson(item)).toList();
      } else {
        final errorBody = _safeJsonDecode(response);
        throw Exception(
          'Failed to get hashtag stories: ${response.statusCode}. Error: ${errorBody['error'] ?? response.body}',
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

      print('🟢 User stories response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response);
        final List<dynamic> body = _safeParseList(data, 'stories');

        // 🟢 КЛЮЧЕВОЕ ИЗМЕНЕНИЕ: Загружаем информацию о пользователе отдельно
        // и добавляем ее в каждую историю
        final userResponse = await http.get(
          Uri.parse('$baseUrl/users/$userId'),
          headers: await _getHeaders(includeAuth: true),
        );

        Map<String, dynamic>? userData;
        if (userResponse.statusCode == 200) {
          final userJson = _safeJsonDecode(userResponse);
          if (userJson is Map<String, dynamic>) {
            userData = userJson;
          }
        }

        return body.map((dynamic item) {
          try {
            // Создаем копию JSON с добавленными данными пользователя
            final storyJson = Map<String, dynamic>.from(item);

            if (userData != null) {
              // Добавляем данные пользователя в историю
              storyJson['user'] = userData;
            }

            return Story.fromJson(storyJson);
          } catch (e) {
            print('Error parsing user story: $e');
            return Story(
              id: item['id'] ?? 0,
              title: item['title'] ?? 'Ошибка загрузки',
              content: item['content'] ?? 'Не удалось загрузить историю',
              userId: item['user_id'] ?? 0,
              createdAt: DateTime.now(),
              likesCount: item['likes_count'] ?? 0,
              commentsCount: item['comments_count'] ?? 0,
              userLiked: false,
              hashtags: [],
            );
          }
        }).toList();
      } else {
        final errorBody = _safeJsonDecode(response);
        throw Exception(
          'Failed to get user stories: ${response.statusCode}. Error: ${errorBody['error'] ?? response.body}',
        );
      }
    } catch (e) {
      print('Error in getUserStories: $e');
      rethrow;
    }
  }

  Future<List<Story>> getFeedStories() async {
    try {
      final response = await http.get(
        // 🛑 Заметка: предполагается, что на Go Backend есть маршрут /feed
        Uri.parse('$baseUrl/feed'),
        headers: await _getHeaders(includeAuth: true),
      );

      AppLogger.api('GET /feed', data: {'code': response.statusCode});
      print('Feed stories response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response);
        // 🟢 Используем _safeParseList с ключом 'stories'
        final List<dynamic> body = _safeParseList(data, 'stories');

        return body.map((dynamic item) => Story.fromJson(item)).toList();
      } else {
        final errorBody = _safeJsonDecode(response);
        throw Exception(
          'Failed to get feed stories: ${response.statusCode}. Error: ${errorBody['error'] ?? response.body}',
        );
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
        // Не пытаемся повторить, если это ошибка авторизации или формата
        if (e.toString().contains('Unauthorized') || e is FormatException) {
          rethrow;
        }

        if (i == maxRetries - 1) rethrow;
        await Future.delayed(Duration(seconds: 1 * (i + 1)));
        print('Retrying request (attempt ${i + 2}/$maxRetries)');
      }
    }
    throw Exception('Max retries exceeded');
  }

  Future<bool> checkServerConnection() async {
    try {
      final url = '$baseUrl/health';
      print('Checking connection to: $url');

      final response = await http
          .get(Uri.parse(url), headers: await _getHeaders(includeAuth: false))
          .timeout(const Duration(seconds: 5));

      print('Health check status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response);
        // ✅ FIX: Проверяем, что data является Map и содержит статус 'ok'
        if (data is Map<String, dynamic>) {
          // Ваш Go Backend возвращает {"status": "ok"}
          return data['status'] == 'ok';
        }
        return true; // Сервер ответил 200, считаем успехом даже без идеального JSON
      }
      return false;
    } catch (e) {
      print('Server connection check failed: $e');

      // ✅ Пробуем сделать простой GET запрос на основной эндпоинт как fallback
      try {
        final url = '$baseUrl/';
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 3));
        print('Fallback check status: ${response.statusCode}');
        return response.statusCode < 500;
      } catch (e2) {
        print('Fallback connection check also failed: $e2');
        return false;
      }
    }
  }
}
