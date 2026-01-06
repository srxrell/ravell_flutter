// screens/add_story_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:readreels/services/comment_service.dart'; // Ваш сервис для ответов
import 'package:readreels/services/story_service.dart'
    as st; // Ваш основной сервис
import "package:readreels/managers/achievement_manager.dart";
import 'package:readreels/widgets/markdown_toolbar.dart'; // Import the MarkdownToolbar
import "package:readreels/services/auth_service.dart";
import "package:shared_preferences/shared_preferences.dart";

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
        final sp = await SharedPreferences.getInstance();
final currentUserId = sp.getInt("user_id");

if (currentUserId != null) {
  final replies = await _replyService.getRepliesForStory(widget.replyToId!);

  // всего ответов стало ровно 5
  if (replies.length == 5) {
    // сортируем по дате на всякий случай
    replies.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final lastReply = replies.last;

    // если пятый — твой
    if (lastReply.userId == currentUserId) {
      await AchievementManager.unlock('chain');
    }
  }
}
        _showSuccess('Ответ успешно опубликован!');

        final story = await _replyService.getStoryById(widget.replyToId!);

      if (story.userId == currentUserId) {
        // ищем, есть ли уже ответ автора к этой истории
        final replies = await _replyService.getRepliesForStory(widget.replyToId!);
        final authoredReplies = replies.where((r) => r.userId == currentUserId);
        if (authoredReplies.length == 1) {
          // это первый ответ автора — даём ачивку
          await AchievementManager.unlock('wait_for_me');
        }
      }
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(titleText),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.check, color: Colors.black, size: 28),
              onPressed: _submitStory,
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
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
            // inputs are still shown
            // Заголовок
            TextField(
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.5,
              ),
              strutStyle: const StrutStyle(
                height: 1.4,
                forceStrutHeight: true,
              ),
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Заголовок',
                fillColor: Colors.transparent,
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Контент
TextField(
  controller: _contentController,
  minLines: 1,
  maxLines: null,
  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
    height: 1.0, // ЖЕСТКО 1.0, чтобы рамка выделения не прыгала
    // ЭТО ГЛАВНЫЙ ФИКС: распределяет высоту шрифта равномерно
    leadingDistribution: TextLeadingDistribution.even, 
  ),
  decoration: const InputDecoration(
    hintText: 'Контент',
    fillColor: Colors.transparent,
    // Делаем отступы здесь, а не через высоту строки
    contentPadding: EdgeInsets.symmetric(vertical: 12), 
    border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
  ),
),

          ],
        ),
      ),
      bottomNavigationBar: MarkdownToolbar(controller: _contentController), // Toolbar at the bottom navigation bar
    );
  }
}
