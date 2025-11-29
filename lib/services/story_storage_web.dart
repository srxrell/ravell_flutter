// Этот файл использует специфичный для Web пакет shared_preferences.
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:readreels/models/story.dart';
import 'package:readreels/services/story_storage_interface.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Web-хранилище

class StoryStorageWeb implements StoryStorageInterface {
  static const _storageKey = 'offline_stories_json_key';

  @override
  Future<void> saveStories(List<Story> stories) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList =
        stories.map((s) => s.toJson()).toList();
    final jsonString = json.encode(jsonList);
    await prefs.setString(_storageKey, jsonString);
  }

  @override
  Future<List<Story>> readStories() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);

    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((json) => Story.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Ошибка при чтении кэша Web: $e');
      return [];
    }
  }

  @override
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}

StoryStorageInterface createStoryStorage() => StoryStorageWeb();
