// screens/add_story_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:readreels/services/comment_service.dart'; // Ваш сервис для ответов
import 'package:readreels/services/story_service.dart'
    as st; // Ваш основной сервис

class AddStoryScreen extends StatefulWidget {
  // 🔑 Опциональные параметры
  final int? replyToId;
  final String? parentTitle;

  const AddStoryScreen({super.key, this.replyToId, this.parentTitle});

  @override
  State<AddStoryScreen> createState() => _AddStoryScreenState();
}

class _AddStoryScreenState extends State<AddStoryScreen> {
  final st.StoryService _storyService =
      st.StoryService(); // Предполагаем, что он существует
  final StoryReplyService _replyService =
      StoryReplyService(); // Ваш сервис для ответов

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _isLoading = false;

  // 🔑 КЛЮЧЕВАЯ ЛОГИКА: Выбор сервиса на основе replyToId
  Future<void> _submitStory() async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заполните все поля!')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.replyToId != null) {
        // --- СЛУЧАЙ 1: ЭТО ОТВЕТ (Вызван из Detail Page) ---
        await _replyService.addReplyToStory(
          parentStoryId: widget.replyToId!,
          title: _titleController.text,
          content: _contentController.text,
          hashtagIds: [], // Добавьте логику хештегов
        );
        _showSuccess('Ответ успешно опубликован!');
      } else {
        // --- СЛУЧАЙ 2: ЭТО НОВАЯ ИСТОРИЯ (Вызван из главной) ---
        // ⚠️ ЭТО ГИПОТЕТИЧЕСКИЙ МЕТОД, ВЫ ДОЛЖНЫ РЕАЛИЗОВАТЬ ЕГО В st.StoryService
        await _storyService.createStory(
          title: _titleController.text,
          content: _contentController.text,
          hashtagIds: [], // Добавьте логику хештегов
        );
        _showSuccess('История успешно опубликована!');
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) _showError('Ошибка публикации: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReply = widget.replyToId != null;
    final titleText = isReply ? 'Написать ответ' : 'Создать новую историю';

    return Scaffold(
      appBar: AppBar(title: Text(titleText)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isReply) // Визуальное подтверждение, что это ответ
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Вы отвечаете на историю: "${widget.parentTitle ?? 'Неизвестная история'}"',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ),

            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Заголовок'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Контент (мин. 100 слов)',
              ),
              maxLines: 8,
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitStory,
                icon:
                    _isLoading
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Icon(isReply ? Icons.reply_all : Icons.send),
                label: Text(
                  _isLoading
                      ? 'Отправка...'
                      : isReply
                      ? 'Опубликовать ответ'
                      : 'Опубликовать историю',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
