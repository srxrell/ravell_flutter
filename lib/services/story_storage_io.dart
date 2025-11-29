// Этот файл использует специфичные для мобильных устройств пакеты.
import 'dart:io';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:readreels/models/story.dart';
import 'package:readreels/services/story_storage_interface.dart';

class StoryStorageIO implements StoryStorageInterface {
  static const _fileName = 'offline_stories.json';

  Future<File> get _localFile async {
    // getApplicationDocumentsDirectory() работает только там, где есть dart:io
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  @override
  Future<void> saveStories(List<Story> stories) async {
    final file = await _localFile;
    final List<Map<String, dynamic>> jsonList =
        stories.map((s) => s.toJson()).toList();
    await file.writeAsString(json.encode(jsonList));
  }

  @override
  Future<List<Story>> readStories() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) return [];
      final contents = await file.readAsString();
      final List<dynamic> jsonList = json.decode(contents);
      return jsonList.map((json) => Story.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Ошибка при чтении кэша Mobile/Desktop: $e');
      return [];
    }
  }

  @override
  Future<void> clearCache() async {
    try {
      final file = await _localFile;
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

StoryStorageInterface createStoryStorage() => StoryStorageIO();
