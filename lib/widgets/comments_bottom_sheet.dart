// widgets/replies_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:readreels/models/story.dart';
import 'package:readreels/services/comment_service.dart';
import 'package:readreels/widgets/expandable_story_content.dart';

class RepliesBottomSheet extends StatefulWidget {
  final Story parentStory;

  const RepliesBottomSheet({super.key, required this.parentStory});

  @override
  State<RepliesBottomSheet> createState() => _RepliesBottomSheetState();
}

class _RepliesBottomSheetState extends State<RepliesBottomSheet> {
  final StoryReplyService _replyService = StoryReplyService();
  final TextEditingController _replyController = TextEditingController();
  List<Story> _replies = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadReplies();
  }

  Future<void> _loadReplies() async {
    try {
      final replies = await _replyService.getRepliesForStory(
        widget.parentStory.id,
      );
      setState(() {
        _replies = replies;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitReply() async {
    if (_replyController.text.trim().isEmpty) return;

    final content = _replyController.text.trim();
    final words =
        content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    if (words.length != 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Нужно ровно 100 слов. Сейчас: ${words.length}'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Используем заголовок по умолчанию или берем из родительской истории
      final title = "Ответ на: ${widget.parentStory.title}";

      await _replyService.addReplyToStory(
        parentStoryId: widget.parentStory.id,
        title: title,
        content: content,
        hashtagIds: [],
      );

      _replyController.clear();
      await _loadReplies();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ответ добавлен!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Заголовок
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Ответы на историю',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),

              // Поле для ответа
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Напишите ответ (ровно 100 слов)...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitReply,
                      child:
                          _isSubmitting
                              ? const CircularProgressIndicator()
                              : const Text('Ответить'),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // Список ответов
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _replies.isEmpty
                        ? const Center(child: Text('Ответов пока нет'))
                        : ListView.builder(
                          controller: scrollController,
                          itemCount: _replies.length,
                          itemBuilder: (context, index) {
                            final reply = _replies[index];
                            return _buildReplyItem(reply);
                          },
                        ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReplyItem(Story reply) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Автор - теперь используем геттер username
            ListTile(
              leading: CircleAvatar(
                backgroundImage:
                    reply.avatarUrl != null
                        ? NetworkImage(reply.avatarUrl!)
                        : null,
                child:
                    reply.avatarUrl == null ? const Icon(Icons.person) : null,
              ),
              title: Text(reply.resolvedUsername), // Используем геттер
              subtitle: Text(reply.replyInfo),
              trailing:
                  reply.isVerified
                      ? const Icon(Icons.verified, color: Colors.blue)
                      : null,
            ),

            // Контент ответа
            ExpandableStoryContent(content: reply.content),

            // Действия
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${reply.likesCount} лайков',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(width: 16),
                Text(
                  '${reply.wordCount} слов',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
