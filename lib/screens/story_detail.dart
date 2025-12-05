import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:readreels/models/story.dart';
import 'package:readreels/screens/add_story_screen.dart';
import 'package:readreels/services/comment_service.dart';
import 'package:readreels/widgets/expandable_story_content.dart';
import 'package:readreels/services/story_service.dart' as st;

// ⚠️ ЗАГЛУШКИ ДЛЯ ОТСУТСТВУЮЩИХ КЛАССОВ И ПЕРЕМЕННЫХ
// Вам нужно определить эти классы/переменные в соответствующих файлах
// (например, StoryCard, RepliesBottomSheet, ExpandableStoryContent)
// и убедиться, что 'package:readreels/theme.dart' содержит neoBlack.
class StoryCard extends StatelessWidget {
  final Story story;
  final bool isReplyCard;
  final void Function()? onStoryUpdated;

  const StoryCard({
    super.key,
    required this.story,
    required this.isReplyCard,
    this.onStoryUpdated,
  });

  @override
  Widget build(BuildContext context) {
    // В реальном приложении здесь будет логика отображения карточки истории,
    // включая кнопки лайка, ответа, анимации и т.д.
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isReplyCard ? Colors.grey[50] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey, width: isReplyCard ? 1 : 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            story.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            story.content.substring(
                  0,
                  story.content.length > 100 ? 100 : story.content.length,
                ) +
                (story.content.length > 100 ? '...' : ''),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          Text(
            'Автор: ${story.username} | Лайков: ${story.likesCount}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          // Здесь должна быть логика кнопок/действий
        ],
      ),
    );
  }
}

// Конец заглушек
// ------------------------------------------------------------------

class StoryDetailPage extends StatefulWidget {
  final Story story;

  const StoryDetailPage({super.key, required this.story});

  @override
  State<StoryDetailPage> createState() => _StoryDetailPageState();
}

class _StoryDetailPageState extends State<StoryDetailPage> {
  final st.StoryService _storyService = st.StoryService();
  final StoryReplyService stt = StoryReplyService();
  List<Story> _replies = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchReplies();
  }

  Future<void> _fetchReplies() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Предполагаем, что StoryService имеет метод для получения ответов по ID родительской истории.
      // В вашем коде этого метода нет, поэтому я создаю его с предположительным названием.
      _replies = await stt.getRepliesForStory(widget.story.id);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки ответов: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  // ❌ УДАЛЕН НЕПОЛНЫЙ МЕТОД _buildStoryCard, ТАК КАК ОН ВЫНЕСЕН ВО ВНЕШНИЙ StoryCard

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ветка ответов'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _fetchReplies,
        child: Column(
          children: [
            // 1. Основная (родительская) история
            Padding(
              padding: const EdgeInsets.all(16.0),
              // ✅ ИСПРАВЛЕНО: используем внешний StoryCard и передаем в него widget.story
              child: StoryCard(
                story: widget.story,
                isReplyCard: false, // Основная карточка
                onStoryUpdated:
                    _fetchReplies, // Обновляем список ответов после действия в StoryCard
              ),
            ),

            // 2. Разделитель и заголовок ответов
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Text(
                _replies.isEmpty
                    ? 'Нет ответов'
                    : 'Ответы (${_replies.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // 3. Список ответов
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _hasError
                      ? const Center(child: Text('Не удалось загрузить ответы'))
                      : ListView.builder(
                        itemCount: _replies.length,
                        itemBuilder: (context, index) {
                          final replyStory = _replies[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            // ✅ ИСПОЛЬЗУЕМ ВНЕШНИЙ StoryCard для ответов
                            child: StoryCard(
                              story: replyStory,
                              isReplyCard: true, // Флаг для стилизации ответа
                              onStoryUpdated:
                                  _fetchReplies, // Обновляем список ответов
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
      // Кнопка для создания нового ответа
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Вы должны проверить аутентификацию здесь, если это критично.
          // if (currentUserId == null) { context.go('/auth'); return; }

          // Навигация на экран создания истории с указанием replyTo
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (context) => AddStoryScreen(
                    parentTitle: widget.story.title,
                    replyToId: widget.story.id,
                  ),
            ),
          );
        },
        label: const Text('Ответить'),
        icon: const Icon(Icons.reply),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
