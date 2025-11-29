import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/comment.dart';

class CommentService {
  // Убедитесь, что этот URL соответствует вашему API
  final String baseUrl = 'http://192.168.1.104:8080/comments';

  // --- 1. GET Comments for Story ---
  Future<List<Comment>> getCommentsForStory(int storyId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('access_token');

    final response = await http.get(
      Uri.parse('$baseUrl/$storyId/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      try {
        final List<dynamic> body = jsonDecode(response.body);
        // Предполагаем, что Comment.fromJson существует и корректно парсит данные
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
    int userId, // userId используется для логики, но не отправляется в теле DRF
    String content,
  ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('access_token');

    if (accessToken == null || accessToken.isEmpty) {
      debugPrint(
        'Error: access_token is null or empty. User must be logged in.',
      );
      throw Exception('User must be logged in to add a comment.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/$storyId/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $accessToken',
      },
      // API ожидает только 'content' в теле для добавления
      body: jsonEncode(<String, dynamic>{'content': content}),
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

  // --- 3. PATCH Update Comment (НОВЫЙ МЕТОД) ---
  Future<Comment> updateComment(int commentId, String content) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('access_token');

    final response = await http.patch(
      // Используем PATCH для частичного обновления
      // Предполагаем, что URL для редактирования — /comments/detail/{commentId}/
      Uri.parse('$baseUrl/detail/$commentId/'),
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

  // --- 4. DELETE Comment (НОВЫЙ МЕТОД) ---
  Future<void> deleteComment(int commentId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('access_token');

    final response = await http.delete(
      // Предполагаем, что URL для удаления — /comments/detail/{commentId}/
      Uri.parse('$baseUrl/detail/$commentId/'),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 204) {
      // 204 No Content - стандартный ответ для успешного DELETE
      debugPrint(
        'Error deleting comment: ${response.statusCode} ${response.body}',
      );
      throw Exception('Failed to delete comment ${response.statusCode}');
    }
  }
}
