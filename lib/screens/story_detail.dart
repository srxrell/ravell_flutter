import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:readreels/models/story.dart';
import 'package:readreels/screens/add_story_screen.dart';
import 'package:readreels/services/comment_service.dart';
import 'package:readreels/services/story_service.dart' as st;

// 🟢 ИСПРАВЛЕННЫЙ StoryCard с полным текстом
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
    return Card(
      elevation: isReplyCard ? 1 : 2,
      margin: EdgeInsets.all(isReplyCard ? 8 : 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isReplyCard ? Colors.grey[300]! : Colors.blueGrey[100]!,
          width: isReplyCard ? 1 : 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок истории
            Text(
              story.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isReplyCard ? 18 : 22,
                color: Colors.black87,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 🟢 ПОЛНЫЙ ТЕКСТ ИСТОРИИ (без обрезания)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: SelectableText(
                story.content, // 🟢 ПОЛНЫЙ текст
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Информация об авторе и статистика
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[300],
                  child: story.avatarUrl.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            'https://ravell-backend-1.onrender.com${story.avatarUrl}',
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Text(
                          story.username.isNotEmpty 
                              ? story.username[0].toUpperCase() 
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                
                const SizedBox(width: 12),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        story.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${_formatDate(story.createdAt)}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Статистика
                Row(
                  children: [
                    _buildStatIcon(Icons.favorite, story.likesCount),
                    const SizedBox(width: 8),
                    _buildStatIcon(Icons.reply, story.repliesCount),
                    const SizedBox(width: 8),
                    if (story.replyTo != null)
                      _buildStatIcon(Icons.subdirectory_arrow_right, null),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Хештеги
            if (story.hashtagIds.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: story.hashtags.map((hashtag) {
      return Chip(
        label: Text('#${hashtag.name}'), // Используем name из объекта Hashtag
        backgroundColor: Colors.blue[50],
        visualDensity: VisualDensity.compact,
      );
    }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatIcon(IconData icon, int? count) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.grey[600],
        ),
        if (count != null) ...[
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}г назад';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}мес назад';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}д назад';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}ч назад';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}мин назад';
    } else {
      return 'только что';
    }
  }
}

// 🟢 ИСПРАВЛЕННЫЙ StoryDetailPage
class StoryDetailPage extends StatefulWidget {
  final Story story;

  const StoryDetailPage({super.key, required this.story});

  @override
  State<StoryDetailPage> createState() => _StoryDetailPageState();
}

class _StoryDetailPageState extends State<StoryDetailPage> {
  final StoryReplyService _replyService = StoryReplyService();
  List<Story> _replies = [];
  bool _isLoading = true;
  bool _hasError = false;
  int _totalWords = 0;
  int _totalRepliesWords = 0;

  @override
  void initState() {
    super.initState();
    _fetchReplies();
    _calculateWordCounts();
  }

  void _calculateWordCounts() {
    // Считаем слова в основной истории
    _totalWords = widget.story.content.split(RegExp(r'\s+')).length;
    
    // Предварительный расчет слов в ответах
    _totalRepliesWords = _replies.fold(
      0, 
      (sum, reply) => sum + reply.content.split(RegExp(r'\s+')).length
    );
  }

  Future<void> _fetchReplies() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      print('🔄 Загружаем ответы для истории ID: ${widget.story.id}');
      _replies = await _replyService.getRepliesForStory(widget.story.id);
      
      print('✅ Загружено ответов: ${_replies.length}');
      
      // Обновляем подсчет слов после загрузки ответов
      _totalRepliesWords = _replies.fold(
        0, 
        (sum, reply) => sum + reply.content.split(RegExp(r'\s+')).length
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Ошибка загрузки ответов: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ветка ответов'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReplies,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _fetchReplies,
      child: CustomScrollView(
        slivers: [
          // Основная история
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Статистика чтения
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatItem(
                          '${_totalWords} слов',
                          Icons.text_fields,
                        ),
                        _buildStatItem(
                          '${_replies.length} ответов',
                          Icons.reply,
                        ),
                        _buildStatItem(
                          '${_totalRepliesWords} слов в ответах',
                          Icons.comment,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Основная карточка истории
                  StoryCard(
                    story: widget.story,
                    isReplyCard: false,
                    onStoryUpdated: _fetchReplies,
                  ),
                ],
              ),
            ),
          ),

          // Заголовок ответов
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.reply,
                    color: Colors.blue,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _replies.isEmpty
                        ? 'Нет ответов'
                        : 'Ответы (${_replies.length})',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_replies.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Chip(
                      label: Text('${_totalRepliesWords} слов'),
                      backgroundColor: Colors.green[50],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Список ответов или состояние загрузки
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Загружаем ответы...'),
                  ],
                ),
              ),
            )
          else if (_hasError)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Не удалось загрузить ответы',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _fetchReplies,
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            )
          else if (_replies.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.forum_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Пока нет ответов',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Будьте первым, кто ответит!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final reply = _replies[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: 16,
                      top: index == 0 ? 0 : 0,
                    ),
                    child: Column(
                      children: [
                        // Номер ответа
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Ответ #${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${reply.content.split(RegExp(r'\s+')).length} слов',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // Карточка ответа
                        StoryCard(
                          story: reply,
                          isReplyCard: true,
                          onStoryUpdated: _fetchReplies,
                        ),
                      ],
                    ),
                  );
                },
                childCount: _replies.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String text, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(height: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AddStoryScreen(
              parentTitle: widget.story.title,
              replyToId: widget.story.id,
            ),
          ),
        ).then((_) {
          // Обновляем список ответов после возвращения
          _fetchReplies();
        });
      },
      icon: const Icon(Icons.reply),
      label: const Text('Ответить'),
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}