// widgets/replies_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:readreels/models/story.dart';
import 'package:readreels/services/comment_service.dart';
import 'package:readreels/widgets/expandable_story_content.dart';
import 'package:readreels/widgets/neowidgets.dart';
import 'package:readreels/managers/settings_manager.dart';
import 'package:provider/provider.dart';
import 'package:readreels/theme.dart';

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

    // разрешаем истории меньше 100 слов (минимум 20 слов максимум 100 слов)
    if (words.length < 20 || words.length > 100) {
      final settings = Provider.of<SettingsManager>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${settings.translate('story_published')} (20-100). ${settings.translate('version')}: ${words.length}'), // Need 'words_limit_error'
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

      final settings = Provider.of<SettingsManager>(context, listen: false);
      _replyController.clear();
      await _loadReplies();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(settings.translate('story_published')))); // Need 'reply_added'
    } catch (e) {
      final settings = Provider.of<SettingsManager>(context, listen: false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${settings.translate('error')}: $e')));
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
        final settings = Provider.of<SettingsManager>(context);
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Сама форма ответа
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          settings.translate('write_reply'),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: 24,
                          ),
                        ),
                        if (_isSubmitting)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.check, color: neoBlack, size: 28),
                            onPressed: _submitReply,
                          ),
                      ],
                    ),
                    Divider(color: Theme.of(context).colorScheme.onBackground.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _replyController,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.5,
                        fontSize: 18,
                      ),
                      decoration: InputDecoration(
                        hintText: settings.translate('write_reply'), // Need 'reply_hint'
                        hintStyle: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.5),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${settings.translate('version')}: ${_replyController.text.trim().isEmpty ? 0 : _replyController.text.trim().split(RegExp(r"\s+")).length}', // Need 'words'
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 32),

              // Список ответов
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _replies.isEmpty
                        ? Center(child: Text(settings.translate('no_replies')))
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
                  '${reply.likesCount} ${Provider.of<SettingsManager>(context).translate('popular')}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(width: 16),
                Text(
                  '${reply.wordCount} ${Provider.of<SettingsManager>(context).translate('version')}',
 // Need 'words'
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
