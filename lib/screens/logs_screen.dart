import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:readreels/services/app_logger.dart';
import 'package:url_launcher/url_launcher.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  LogLevel? _levelFilter;
  LogCategory? _categoryFilter;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backstage логи'),
        actions: [
          IconButton(
            tooltip: 'Очистить',
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              AppLogger.clear();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Логи очищены')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildControls(),
          const Divider(height: 1),
          Expanded(
            child: ValueListenableBuilder<List<LogEntry>>(
              valueListenable: AppLogger.logs,
              builder: (context, logs, _) {
                final filtered = logs.where((e) {
                  if (_levelFilter != null && e.level != _levelFilter) {
                    return false;
                  }
                  if (_categoryFilter != null &&
                      e.category != _categoryFilter) {
                    return false;
                  }
                  if (_search.isNotEmpty) {
                    final needle = _search.toLowerCase();
                    if (!e.message.toLowerCase().contains(needle) &&
                        !(e.data != null &&
                            (e.data.toString().toLowerCase().contains(needle)))) {
                      return false;
                    }
                  }
                  return true;
                }).toList().reversed.toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'Логи пока пусты',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    return _buildLogTile(entry);
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Поиск по логам',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    setState(() => _search = value.trim());
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Все уровни'),
                selected: _levelFilter == null,
                onSelected: (_) => setState(() => _levelFilter = null),
              ),
              ChoiceChip(
                label: const Text('INFO'),
                selected: _levelFilter == LogLevel.info,
                onSelected: (_) =>
                    setState(() => _levelFilter = LogLevel.info),
              ),
              ChoiceChip(
                label: const Text('WARN'),
                selected: _levelFilter == LogLevel.warning,
                onSelected: (_) =>
                    setState(() => _levelFilter = LogLevel.warning),
              ),
              ChoiceChip(
                label: const Text('ERROR'),
                selected: _levelFilter == LogLevel.error,
                onSelected: (_) =>
                    setState(() => _levelFilter = LogLevel.error),
              ),
              const SizedBox(width: 16),
              ChoiceChip(
                label: const Text('Все типы'),
                selected: _categoryFilter == null,
                onSelected: (_) => setState(() => _categoryFilter = null),
              ),
              ChoiceChip(
                label: const Text('API'),
                selected: _categoryFilter == LogCategory.api,
                onSelected: (_) =>
                    setState(() => _categoryFilter = LogCategory.api),
              ),
              ChoiceChip(
                label: const Text('NET'),
                selected: _categoryFilter == LogCategory.network,
                onSelected: (_) =>
                    setState(() => _categoryFilter = LogCategory.network),
              ),
              ChoiceChip(
                label: const Text('UI'),
                selected: _categoryFilter == LogCategory.ui,
                onSelected: (_) =>
                    setState(() => _categoryFilter = LogCategory.ui),
              ),
              ChoiceChip(
                label: const Text('SYS'),
                selected: _categoryFilter == LogCategory.system,
                onSelected: (_) =>
                    setState(() => _categoryFilter = LogCategory.system),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _levelColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return Colors.green;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
    }
  }

  Widget _buildLogTile(LogEntry entry) {
    final ts =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: _levelColor(entry.level),
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(8),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '• ${entry.categoryLabel} • ${entry.levelLabel}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        ts,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.message,
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (entry.data != null && entry.data!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      entry.data.toString(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _copyLogs,
                icon: const Icon(Icons.copy),
                label: const Text('Скопировать'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saveToFile,
                icon: const Icon(Icons.download),
                label: const Text('Скачать .txt'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _sendToTelegram,
                icon: const Icon(Icons.send),
                label: const Text('Телеграм'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyLogs() async {
    final text = AppLogger.exportToString();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет логов для копирования')),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Логи скопированы в буфер обмена')),
    );
  }

  Future<void> _saveToFile() async {
    final file = await AppLogger.saveToFile();
    if (!mounted) return;
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить файл логов')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Файл сохранён: ${file.path}'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _sendToTelegram() async {
    final text = AppLogger.exportToString();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет логов для отправки')),
      );
      return;
    }

    // Ограничим размер, чтобы не взорвать URL
    final String trimmed =
        text.length > 3500 ? text.substring(0, 3500) : text;
    final encoded = Uri.encodeComponent(trimmed);

    final uri = Uri.parse('https://t.me/share/url?text=$encoded');

    try {
      final launched = await launchUrl(uri);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось открыть Telegram, но логи в буфере'),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Telegram launch error: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Ошибка открытия Telegram. Скопируйте логи вручную.'),
        ),
      );
    }
  }
}


