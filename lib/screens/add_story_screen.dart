import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:readreels/services/comment_service.dart';
import 'package:readreels/services/story_service.dart' as st;
import "package:readreels/managers/achievement_manager.dart";
import "package:google_fonts/google_fonts.dart";
import 'package:readreels/widgets/markdown_toolbar.dart';
import 'package:readreels/theme.dart';
import "package:shared_preferences/shared_preferences.dart";

class AddStoryScreen extends StatefulWidget {
  final int? replyToId;
  final String? parentTitle;

  const AddStoryScreen({super.key, this.replyToId, this.parentTitle});

  @override
  State<AddStoryScreen> createState() => _AddStoryScreenState();
}

class _AddStoryScreenState extends State<AddStoryScreen> {
  final st.StoryService _storyService = st.StoryService();
  final StoryReplyService _replyService = StoryReplyService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  
  bool _isLoading = false;
  // По умолчанию, если это ответ, предлагаем формат "Комментарий"
  bool _isStoryReply = false; 

  @override
  void initState() {
    super.initState();
    if (widget.replyToId != null) {
      _titleController.text = "Ответ на: ${widget.parentTitle}";
    }
  }

  // Вспомогательный метод для подсчета слов
  int _getWordCount(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return 0;
    return cleaned.split(RegExp(r'\s+')).length;
  }

  Future<void> _submitStory() async {
    final content = _contentController.text.trim();
    // Для комментария заголовок не обязателен, для истории - нужен
    if (content.isEmpty || (_isStoryReply && _titleController.text.isEmpty)) {
      _showError('Заполните все необходимые поля!');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final sp = await SharedPreferences.getInstance();
      final currentUserId = sp.getInt("user_id");

      if (widget.replyToId != null) {
        if (_isStoryReply) {
          // --- ВАРИАНТ А: Полноценное продолжение (История) ---
          await _replyService.addReplyToStory(
            parentStoryId: widget.replyToId!,
            title: _titleController.text,
            content: content,
            hashtagIds: [],
          );
          await _handleAchievements(currentUserId);
        } else {
          // --- ВАРИАНТ Б: Просто комментарий ---
          await _replyService.addComment(
            storyId: widget.replyToId!,
            content: content,
          );
        }
        _showSuccess('Опубликовано!');
      } else {
        // --- НОВАЯ САМОСТОЯТЕЛЬНАЯ ИСТОРИЯ ---
        await _storyService.createStory(
          title: _titleController.text,
          content: content,
          hashtagIds: [],
        );
        _showSuccess('История создана!');
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) _showError('Ошибка: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAchievements(int? currentUserId) async {
    if (currentUserId == null) return;
    
    final replies = await _replyService.getRepliesForStory(widget.replyToId!);
    if (replies.length == 5 && replies.last.userId == currentUserId) {
      await AchievementManager.unlock('chain');
    }

    final story = await _replyService.getStoryById(widget.replyToId!);
    if (story.userId == currentUserId) {
      final authoredReplies = replies.where((r) => r.userId == currentUserId);
      if (authoredReplies.length == 1) await AchievementManager.unlock('wait_for_me');
    }
  }

  InputDecoration _minimalInputDecoration(String hint, {bool showUnderline = true}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w400),
      filled: true,
      fillColor: Colors.transparent,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(
          color: showUnderline ? Colors.black12 : Colors.transparent, 
          width: 1.0,
        ),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(
          color: showUnderline ? Colors.black : Colors.transparent, 
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isReplyMode = widget.replyToId != null;

    return Scaffold(
      backgroundColor: neoBackground,
      appBar: AppBar(
        backgroundColor: neoBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          isReplyMode ? 'Ваш ответ' : 'Новая история',
          style: const TextStyle(color: Colors.black),
        ),
        actions: [
          _isLoading 
            ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)))
            : IconButton(
                icon: const Icon(Icons.check, size: 28, color: Colors.black), 
                onPressed: _submitStory
              ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                 
                  
                  const SizedBox(height: 16),

                  // СЕЛЕКТОР ТИПА (Только в режиме ответа)
                  if (isReplyMode) 
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text("Комментарий"),
                            selected: !_isStoryReply,
                            onSelected: (val) => setState(() => _isStoryReply = !val),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text("История-ответ"),
                            selected: _isStoryReply,
                            onSelected: (val) => setState(() => _isStoryReply = val),
                          ),
                        ],
                      ),
                    ),

                  // ПОЛЕ ЗАГОЛОВКА
                  if (!isReplyMode || _isStoryReply)
                    TextField(
                      controller: _titleController,
                      strutStyle: StrutStyle(
    forceStrutHeight: true,
    height: 1.5, // Совпадает с высотой в TextStyle
    fontSize: theme.textTheme.headlineMedium?.fontSize,
  ),
  style: theme.textTheme.headlineMedium?.copyWith(
    height: 1.5, // Межстрочный интервал
  ),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _minimalInputDecoration('Заголовок истории'),
                    ),
                  
                  const SizedBox(height: 16),

                  // ПОЛЕ КОНТЕНТА
                  TextField(
                    controller: _contentController,
                    minLines: 10,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    strutStyle: StrutStyle(
    forceStrutHeight: true,
    height: 1.5, // Совпадает с высотой в TextStyle
    fontSize: theme.textTheme.headlineMedium?.fontSize,
  ),
  style: theme.textTheme.headlineMedium?.copyWith(
    height: 1.5, // Межстрочный интервал
  ),
                    decoration: _minimalInputDecoration(
                      _isStoryReply || !isReplyMode ? 'Начните писать...' : 'Ваш комментарий...',
                      showUnderline: false,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ),
          
          // ТУЛБАР МАРКДАУНА
          SafeArea(
            child: Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: MarkdownToolbar(controller: _contentController),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating)
  );
  
  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating)
  );
}