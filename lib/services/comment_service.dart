// services/story_reply_service.dart
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/story.dart';

class StoryReplyService {
  final String baseUrl = 'https://ravell-backend-1.onrender.com';

  // --- 1. GET Replies for Story (Вместо комментариев) ---
  // --- 1. GET Replies for Story ---
Future<List<Story>> getRepliesForStory(int parentStoryId) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? accessToken = prefs.getString('access_token');

  print('🔄 Fetching replies for story ID: $parentStoryId');
  print('🌐 URL: $baseUrl/stories/?reply_to=$parentStoryId');

  try {
    final response = await http.get(
      Uri.parse('$baseUrl/stories/?reply_to=$parentStoryId'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
    );

    print('📊 Response status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final bodyString = utf8.decode(response.bodyBytes);
      print('📄 Response received, parsing...');
      
      final data = jsonDecode(bodyString);
      
      // ✅ КЛЮЧЕВОЕ ИСПРАВЛЕНИЕ: Правильно фильтруем ответы
      List<dynamic> allStories = [];
      
      if (data is Map<String, dynamic> && data.containsKey('stories')) {
        allStories = data['stories'];
        print('📊 Total stories from API: ${allStories.length}');
      } else {
        print('⚠️ Response does not contain "stories" key or is not a Map');
        return [];
      }
      
      // ✅ ФИЛЬТРУЕМ: берем только те истории, где reply_to == parentStoryId
      final replies = allStories.where((story) {
        final replyTo = story['reply_to'];
        return replyTo != null && replyTo == parentStoryId;
      }).toList();
      
      print('✅ Found ${replies.length} actual replies (filtered by reply_to == $parentStoryId)');
      
      // Парсим только отфильтрованные ответы
      final List<Story> parsedReplies = [];
      for (var item in replies) {
        try {
          final story = Story.fromJson(item);
          parsedReplies.add(story);
          print('   ➤ Reply: ${story.title} (ID: ${story.id}, reply_to: ${story.replyTo})');
        } catch (e) {
          print('❌ Error parsing story: $e');
        }
      }
      
      return parsedReplies;
      
    } else {
      print('❌ API Error: ${response.statusCode} - ${response.body}');
      return [];
    }
  } catch (e) {
    print('❌ Network/parsing error: $e');
    return [];
  }
}

  // --- 2. POST Add Reply as Story (Вместо комментария) ---
  Future<Story> addReplyToStory({
    required int parentStoryId,
    required String title,
    required String content,
    required List<int> hashtagIds,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('access_token');

    if (accessToken == null || accessToken.isEmpty) {
      debugPrint('Error: access_token is null or empty.');
      throw Exception('User must be logged in to add a reply.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/stories/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(<String, dynamic>{
        'title': title,
        'content': content,
        'reply_to': parentStoryId,
        'hashtag_ids': hashtagIds,
      }),
    );

    if (response.statusCode == 201) {
      return Story.fromJson(jsonDecode(response.body));
    } else {
      final errorBody = jsonDecode(response.body);
      debugPrint(
        'Error adding reply: ${response.statusCode} ${errorBody['error'] ?? response.body}',
      );
      throw Exception(
        'Failed to add reply: ${errorBody['error'] ?? 'Unknown error'}',
      );
    }
  }

  // --- 3. GET Full Thread (История с ответами) ---
  Future<List<Story>> getStoryThread(int storyId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('access_token');

    final response = await http.get(
      Uri.parse('$baseUrl/stories/$storyId/thread'), // Предполагаемый эндпоинт
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final List<dynamic> body = data['replies'] ?? data['thread'] ?? [];
          return body.map((dynamic item) => Story.fromJson(item)).toList();
        }
        return [];
      } catch (e) {
        debugPrint('Error parsing thread: $e');
        return [];
      }
    } else {
      // Если эндпоинта /thread нет, возвращаем только родительскую историю
      final parentStory = await _getStory(storyId);
      final replies = await getRepliesForStory(storyId);
      return [parentStory, ...replies];
    }
  }

  // --- 4. Вспомогательный метод: Получить историю по ID ---
  Future<Story> _getStory(int storyId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('access_token');

    final response = await http.get(
      Uri.parse('$baseUrl/stories/$storyId'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      return Story.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to get story: ${response.statusCode}');
    }
  }

  // --- 5. Обновить ответ (если нужно) ---
  Future<Story> updateReply({
    required int replyId,
    required String title,
    required String content,
    required List<int> hashtagIds,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('access_token');

    final response = await http.put(
      Uri.parse('$baseUrl/stories/$replyId'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(<String, dynamic>{
        'title': title,
        'content': content,
        'hashtag_ids': hashtagIds,
      }),
    );

    if (response.statusCode == 200) {
      return Story.fromJson(jsonDecode(response.body));
    } else {
      final errorBody = jsonDecode(response.body);
      debugPrint(
        'Error updating reply: ${response.statusCode} ${errorBody['error'] ?? response.body}',
      );
      throw Exception(
        'Failed to update reply: ${errorBody['error'] ?? 'Unknown error'}',
      );
    }
  }

  // --- 6. Удалить ответ ---
  Future<void> deleteReply(int replyId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('access_token');

    final response = await http.delete(
      Uri.parse('$baseUrl/stories/$replyId'),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorBody = jsonDecode(response.body);
      debugPrint(
        'Error deleting reply: ${response.statusCode} ${errorBody['error'] ?? response.body}',
      );
      throw Exception(
        'Failed to delete reply: ${errorBody['error'] ?? 'Unknown error'}',
      );
    }
  }

  // --- 7. Проверить слово ответа (должно быть 100 слов) ---
  bool validateReplyWordCount(String content) {
    final words =
        content
            .trim()
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .toList();
    return words.length == 100;
  }

  // --- 8. Получить статистику ответов ---
  Future<Map<String, dynamic>> getReplyStats(int storyId) async {
    final replies = await getRepliesForStory(storyId);
    final parentStory = await _getStory(storyId);

    return {
      'parent_story': parentStory.title,
      'total_replies': replies.length,
      'latest_reply': replies.isNotEmpty ? replies.first.createdAt : null,
      'most_active_user': _findMostActiveUser(replies),
    };
  }

  // --- 9. Вспомогательный метод: Найти самого активного пользователя ---
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
      'username': mostActiveStory.username,
      'avatar_url': mostActiveStory.avatarUrl,
      'reply_count': userCounts[maxUserId],
    };
  }

  Future<Story> getStoryById(int storyId) async {
  return _getStory(storyId);
}
}
