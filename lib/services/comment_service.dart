// services/comment_service.dart
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/comment.dart';

class CommentService {
  // 🟢 ИСПРАВЛЕННЫЙ URL
  final String baseUrl = 'https://ravell-backend-1.onrender.com';

  // --- 1. GET Comments for Story ---
  Future<List<Comment>> getCommentsForStory(int storyId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('access_token');

    final response = await http.get(
      Uri.parse('$baseUrl/stories/$storyId/comments'), // 🟢 ИСПРАВЛЕННЫЙ URL
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      try {
        final List<dynamic> body = jsonDecode(response.body);
        return body.map((dynamic item) => Comment.fromJson(item)).toList();
      } catch (e) {
        debugPrint('Error parsing comments: $e');
        return [];
      }
    } else {
      debugPrint(
        'Failed to get comments for story: ${response.statusCode} ${response.body}',
      );
      throw Exception('Failed to get comments for story');
    }
  }

  // --- 2. POST Add Comment ---
  Future<Comment> addCommentToStory(
    int storyId,
    int user_id, // 🟢 В Go API может понадобиться user_id
    String content,
  ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('access_token');

    if (accessToken == null || accessToken.isEmpty) {
      debugPrint('Error: access_token is null or empty.');
      throw Exception('User must be logged in to add a comment.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/comments'), // 🟢 ИСПРАВЛЕННЫЙ URL
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $accessToken',
      },
      // 🟢 ИСПРАВЛЕНО: Go API ожидает story_id и content
      body: jsonEncode(<String, dynamic>{
        'story_id': storyId,
        'content': content,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Comment.fromJson(jsonDecode(response.body));
    } else {
      debugPrint(
        'Error adding comment: ${response.statusCode} ${response.body}',
      );
      throw Exception('Failed to add comment to story ${response.statusCode}');
    }
  }

  // --- 3. PATCH Update Comment ---
  Future<Comment> updateComment(int commentId, String content) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('access_token');

    final response = await http.patch(
      // 🟢 ИСПРАВЛЕННЫЙ URL
      Uri.parse('$baseUrl/comments/$commentId'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(<String, dynamic>{'content': content}),
    );

    if (response.statusCode == 200) {
      return Comment.fromJson(jsonDecode(response.body));
    } else {
      debugPrint(
        'Error updating comment: ${response.statusCode} ${response.body}',
      );
      throw Exception('Failed to update comment ${response.statusCode}');
    }
  }

  // --- 4. DELETE Comment ---
  Future<void> deleteComment(int commentId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('access_token');

    final response = await http.delete(
      // 🟢 ИСПРАВЛЕННЫЙ URL
      Uri.parse('$baseUrl/comments/$commentId'),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      debugPrint(
        'Error deleting comment: ${response.statusCode} ${response.body}',
      );
      throw Exception('Failed to delete comment ${response.statusCode}');
    }
  }
}
