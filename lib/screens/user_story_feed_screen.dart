import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart'; // Оставляем, если нужен SVG
import 'package:readreels/models/story.dart';
// Предполагаемые импорты
import 'package:readreels/services/story_service.dart' as st;
import 'package:readreels/widgets/expandable_story_content.dart';
import 'package:readreels/widgets/heart_animation.dart';
import 'package:readreels/widgets/comments_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:readreels/screens/user_story_feed_screen.dart';
import 'package:readreels/widgets/bottom_nav_bar_liquid.dart' as p;

class UserStoryFeedScreen extends StatefulWidget {
  final List<Story> stories;
  final int initialIndex;

  const UserStoryFeedScreen({
    super.key,
    required this.stories,
    required this.initialIndex,
  });

  @override
  State<UserStoryFeedScreen> createState() => _UserStoryFeedScreenState();
}

class _UserStoryFeedScreenState extends State<UserStoryFeedScreen> {
  final PageController _pageController = PageController(initialPage: 0);
  bool isHeartAnimating = false;
  String? user_id;
  // Состояние лайков и счетчиков
  Map<dynamic, bool> likeStatuses = {};
  late Map<int, int> likeCounts;
  Offset tapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();

    likeCounts = {};
    for (var story in widget.stories) {
      // Инициализируем likeCounts из данных истории
      likeCounts[story.id] = story.likesCount ?? 0;
    }

    _getuser_id().then((_) {
      _fetchLikeStatuses();
    });
  }

  // Получение ID текущего пользователя
  Future<void> _getuser_id() async {
    final prefs = await SharedPreferences.getInstance();
    user_id = prefs.getInt('user_id')?.toString();
  }

  // Получение статусов лайков для всех историй в этой ленте
  Future<void> _fetchLikeStatuses() async {
    if (user_id == null) return;
    final int currentuser_id = int.tryParse(user_id!) ?? 0;

    // Используем Map.fromIterable для быстрой инициализации likeStatuses
    final initialStatuses = Map.fromIterable(
      widget.stories,
      key: (story) => story.id,
      value: (_) => false,
    );

    for (var story in widget.stories) {
      try {
        final isLiked = await st.StoryService().isStoryLiked(
          story.id,
          currentuser_id,
        );
        initialStatuses[story.id] = isLiked;
      } catch (e) {
        print('Error fetching like status for story ${story.id}: $e');
      }
    }

    if (mounted) {
      setState(() {
        likeStatuses = initialStatuses;
      });
    }
  }

  // Обработка лайка/отмены лайка
  Future<void> _handleLike(Story story) async {
    // Добавим проверку авторизации
    if (user_id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Для лайка требуется авторизация.')),
      );
      return;
    }

    if (story.id != null) {
      try {
        final newCount = await st.StoryService().likeStory(
          story.id,
          int.tryParse(user_id!) ?? 0,
        );

        // Мы могли бы просто переключить локальное состояние,
        // но для точности лучше перепроверить статус на сервере, как вы и делали.
        final isLiked = await st.StoryService().isStoryLiked(
          story.id,
          int.tryParse(user_id!) ?? 0,
        );

        setState(() {
          likeStatuses[story.id] = isLiked;
          likeCounts[story.id] = newCount;
        });
      } catch (e) {
        print('Error liking/unliking story ${story.id}: $e');
      }
    }
  }

  // ✅ ИСПРАВЛЕНИЕ: _buildActionButton теперь принимает Widget icon
  Widget _buildActionButton({
    required Widget icon, // Изменено с IconData на Widget
    required int count,
    required VoidCallback onPressed,
    bool isLiked = false,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPressed,
          child: icon,
        ), // Используем GestureDetector с Widget
        Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("Нет историй для отображения.")),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      bottomNavigationBar: const p.PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(),
      body: PageView.builder(
        controller: PageController(initialPage: widget.initialIndex),
        itemCount: widget.stories.length,
        scrollDirection: Axis.vertical,
        itemBuilder: (context, index) {
          final story = widget.stories[index];
          final isLiked = likeStatuses[story.id] == true;
          final currentLikeCount = likeCounts[story.id] ?? 0;

          return GestureDetector(
            onDoubleTapDown: (details) {
              if (user_id == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Для лайка требуется авторизация.'),
                  ),
                );
                return;
              }
              _handleLike(story);
              setState(() {
                isHeartAnimating = true;
                tapPosition = details.localPosition;
              });
            },
            child: Stack(
              children: [
                // 1. --- КОНТЕНТ ИСТОРИИ (С анимацией сердца) ---
                Positioned.fill(
                  child: HeartAnimation(
                    position: tapPosition,
                    isAnimating: isHeartAnimating,
                    duration: const Duration(milliseconds: 300),
                    onEnd: () {
                      setState(() {
                        isHeartAnimating = false;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 100, // Отступ сверху
                        left: 20,
                        right: 80, // Отступ справа, чтобы не перекрывать кнопки
                        bottom: 40,
                      ),
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.end, // ✅ Контент внизу
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Заголовок
                          Text(
                            story.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 30,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Контент: Используем Expanded + ListView
                          Expanded(
                            child: SingleChildScrollView(
                              child:
                              // ЗАМЕНА ЗДЕСЬ
                              ExpandableStoryContent(content: story.content),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. --- ИНФОРМАЦИЯ ОБ АВТОРЕ И КНОПКА ЗАКРЫТЬ (СЛОЙ ВЫШЕ) ---
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 10,
                  right: 10,
                  child: Row(
                    children: [
                      // Замена IconButton на Image.asset + GestureDetector
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Image.asset(
                          "icons/png/close_story.png", // <--- ИЗМЕНЕНИЕ: Новый ассет
                          width: 60, // Размер как у Icon
                          height: 60, // Поддерживаем черный цвет, как у Icon
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. --- КНОПКИ (ЛАЙК/КОММЕНТ) (СЛОЙ ВЫШЕ) ---
                Positioned(
                  right: 10,
                  bottom: 50, // Поднимаем выше, так как нет нижнего бара
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Кнопка Лайка
                      _buildActionButton(
                        icon: Image.asset(
                          isLiked
                              ? "icons/png/upvote_filled.png"
                              : "icons/png/upvote.png",
                          width: 50,
                          height: 50,
                        ),
                        count: currentLikeCount,
                        onPressed: () => _handleLike(story),
                        isLiked: isLiked,
                      ),
                      const SizedBox(height: 15),
                      // Кнопка Комментария
                      _buildActionButton(
                        icon: Image.asset(
                          "icons/png/comment.png",
                          width: 50,
                          height: 50,
                        ),
                        count: story.commentsCount,
                        onPressed: () async {
                          await showModalBottomSheet(
                            context: context,
                            builder: (context) {
                              return CommentsBottomSheet(story: story);
                            },
                          );
                          // Логика обновления счетчика комментариев
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
