import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel { info, warning, error }

enum LogCategory { api, network, ui, system }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final LogCategory category;
  final String message;
  final Map<String, dynamic>? data;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.data,
  });

  String get levelLabel {
    switch (level) {
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  String get categoryLabel {
    switch (category) {
      case LogCategory.api:
        return 'API';
      case LogCategory.network:
        return 'NET';
      case LogCategory.ui:
        return 'UI';
      case LogCategory.system:
        return 'SYS';
    }
  }

  String toLine() {
    final ts =
        '${timestamp.toIso8601String().replaceFirst('T', ' ').split('.').first}';
    final base = '[$ts] [$levelLabel] [$categoryLabel] $message';
    if (data == null || data!.isEmpty) return base;
    return '$base ${jsonEncode(data)}';
  }
}

class AppLogger {
  AppLogger._();

  static void _debugPrint(LogEntry entry) {
    if (!kDebugMode) return;

    final levelIcon = switch (entry.level) {
      LogLevel.info => '✅',
      LogLevel.warning => '⚠️',
      LogLevel.error => '❗',
    };
    final color = switch (entry.level) {
      LogLevel.info => '\x1B[32m',   // Green
      LogLevel.warning => '\x1B[33m',// Yellow
      LogLevel.error => '\x1B[31m',  // Red
    };
    final reset = '\x1B[0m';

    final ts = '[${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}]';
    final lines = [
      color,
      '┌───────────────────────────────────────────────────────────────────────────',
      '│ $levelIcon $ts [${entry.levelLabel}][${entry.categoryLabel}]',
      '├── $reset${entry.message}',
      if (entry.data != null && entry.data!.isNotEmpty) '├── DATA: [36m${entry.data}$reset',
      '└───────────────────────────────────────────────────────────────────────────$reset',
    ];
    // Используй debugPrint на каждой строке чтобы сохранить цвет
    for (final line in lines) {
      debugPrint(line);
    }
  }

  /// Живой список логов для экранов внутри приложения
  static final ValueNotifier<List<LogEntry>> logs =
      ValueNotifier<List<LogEntry>>([]);

  static const int _maxEntries = 1000;

  static void log({
    required String message,
    LogLevel level = LogLevel.info,
    LogCategory category = LogCategory.system,
    Map<String, dynamic>? data,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      category: category,
      message: message,
      data: data,
    );

    // В консоль — только в debug
    if (kDebugMode) {
      _debugPrint(entry);
    }

    // Внутренний стор
    final current = List<LogEntry>.from(logs.value)..add(entry);
    if (current.length > _maxEntries) {
      current.removeRange(0, current.length - _maxEntries);
    }
    logs.value = current;
  }

  // Удобные шорткаты
  static void api(String message, {Map<String, dynamic>? data}) {
    log(message: message, category: LogCategory.api, data: data);
  }

  static void network(String message, {Map<String, dynamic>? data}) {
    log(message: message, category: LogCategory.network, data: data);
  }

  static void ui(String message, {Map<String, dynamic>? data}) {
    log(message: message, category: LogCategory.ui, data: data);
  }

  static void warning(String message, {Map<String, dynamic>? data}) {
    log(
      message: message,
      level: LogLevel.warning,
      category: LogCategory.system,
      data: data,
    );
  }

  static void error(String message, {Map<String, dynamic>? data}) {
    log(
      message: message,
      level: LogLevel.error,
      category: LogCategory.system,
      data: data,
    );
  }

  static String exportToString() {
    return logs.value.map((e) => e.toLine()).join('\n');
  }

  static void clear() {
    logs.value = [];
  }

  /// Сохраняет логи в txt-файл и возвращает объект файла (или null при ошибке)
  static Future<File?> saveToFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/ravell_logs_${DateTime.now().millisecondsSinceEpoch}.txt',
      );
      await file.writeAsString(exportToString());
      return file;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to save logs: $e');
      }
      return null;
    }
  }
}


