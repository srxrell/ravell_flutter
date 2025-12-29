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
            tooltip: 'Очистить логи',
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
                    final msg = e.message.toLowerCase();
                    final data = (e.data ?? '').toString().toLowerCase();
                    if (!msg.contains(needle) &&
                        !data.contains(needle)) {
                      return false;
                    }
                  }
                  return true;
                }).toList().reversed.toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'Логи отсутствуют',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _buildLogTile(filtered[index]);
                    },
                  ),
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
          TextField(
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
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Все уровни', _levelFilter == null,
                    () => setState(() => _levelFilter = null)),
                _chip('INFO', _levelFilter == LogLevel.info,
                    () => setState(() => _levelFilter = LogLevel.info)),
                _chip('WARN', _levelFilter == LogLevel.warning,
                    () => setState(() => _levelFilter = LogLevel.warning)),
                _chip('ERROR', _levelFilter == LogLevel.error,
                    () => setState(() => _levelFilter = LogLevel.error)),
                const SizedBox(width: 12),
                _chip('Все типы', _categoryFilter == null,
                    () => setState(() => _categoryFilter = null)),
                _chip('API', _categoryFilter == LogCategory.api,
                    () => setState(() => _categoryFilter = LogCategory.api)),
                _chip('NET', _categoryFilter == LogCategory.network,
                    () => setState(() => _categoryFilter = LogCategory.network)),
                _chip('UI', _categoryFilter == LogCategory.ui,
                    () => setState(() => _categoryFilter = LogCategory.ui)),
                _chip('SYS', _categoryFilter == LogCategory.system,
                    () => setState(() => _categoryFilter = LogCategory.system)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
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
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
        '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
        '${entry.timestamp.second.toString().padLeft(2, '0')}';

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openLogDetails(entry),
      child: Container(
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
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openLogDetails(LogEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.categoryLabel} • ${entry.levelLabel}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(entry.message),
                  if (entry.data != null &&
                      entry.data.toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Данные:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(entry.data.toString()),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _copyLogs,
                icon: const Icon(Icons.copy),
                label: const Text('Копировать'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saveToFile,
                icon: const Icon(Icons.download),
                label: const Text('TXT'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _sendToTelegram,
                icon: const Icon(Icons.send),
                label: const Text('Telegram'),
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
      _toast('Нет логов');
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    _toast('Скопировано');
  }

  Future<void> _saveToFile() async {
    final file = await AppLogger.saveToFile();
    if (!mounted) return;
    if (file == null) {
      _toast('Ошибка сохранения');
      return;
    }
    _toast('Файл: ${file.path}');
  }

  Future<void> _sendToTelegram() async {
    final text = AppLogger.exportToString();
    if (text.isEmpty) {
      _toast('Нет логов');
      return;
    }

    final trimmed =
        text.length > 3500 ? text.substring(0, 3500) : text;
    final uri = Uri.parse(
      'https://t.me/share/url?text=${Uri.encodeComponent(trimmed)}',
    );

    try {
      await launchUrl(uri);
    } catch (_) {
      _toast('Telegram не открылся');
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}
