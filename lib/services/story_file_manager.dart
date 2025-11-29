import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:readreels/models/story.dart';

class StoryFileManager {
  // Имя файла, в котором хранится кэш
  static const _fileName = 'offline_stories.json';

  // 1. Вспомогательный метод для получения объекта File
  Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    final path = directory.path;
    return File('$path/$_fileName');
  }

  // 2. ЗАПИСЬ: Сериализует List<Story> и сохраняет его в файл
  Future<void> saveStories(List<Story> stories) async {
    final file = await _localFile;

    // Преобразуем List<Story> в List<Map>
    final List<Map<String, dynamic>> jsonList =
        stories.map((s) => s.toJson()).toList();

    // Кодируем List<Map> в одну JSON-строку и записываем ее
    await file.writeAsString(json.encode(jsonList));
  }

  // 3. ЧТЕНИЕ: Считывает файл, парсит JSON и возвращает List<Story>
  Future<List<Story>> readStories() async {
    try {
      final file = await _localFile;

      if (!await file.exists()) {
        return [];
      }

      // Считываем JSON-строку
      final contents = await file.readAsString();

      // Декодируем строку обратно в List<Map>
      final List<dynamic> jsonList = json.decode(contents);

      // Преобразуем List<Map> в List<Story>
      return jsonList.map((json) => Story.fromJson(json)).toList();
    } catch (e) {
      // Ошибка при чтении файла, возвращаем пустой список
      debugPrint('Ошибка при чтении кэша: $e');
      return [];
    }
  }

  // 4. ОЧИСТКА КЭША: Удаляет файл
  Future<void> clearCache() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        await file.delete(); // ⬅️ Удаление старой стопки!
      }
    } catch (_) {
      // Игнорируем ошибки
    }
  }
}
