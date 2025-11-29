import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:readreels/models/story.dart';
import 'package:readreels/services/auth_service.dart';
import 'package:readreels/widgets/expandable_story_content.dart';
import 'package:readreels/widgets/heart_animation.dart';
import 'package:readreels/services/story_service.dart' as st;
import 'package:readreels/widgets/bottom_nav_bar_liquid.dart';
import 'package:readreels/widgets/comments_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:readreels/services/subscription_service.dart';

// 🚨 Предполагаемые константы из theme.dart и neowidgets.dart для работы
// В реальном проекте они будут импортированы.
const Color neoBlack = Colors.black;
const Color neoBackground = Colors.white;

// Этот виджет будет отображать только истории, переданные из поиска.
class SearchFeed extends StatefulWidget {
  final List<Story> stories;
  final int initialIndex; // Для начала прокрутки с выбранной истории

  const SearchFeed({
    super.key,
    required this.stories,
    required this.initialIndex,
  });

  @override
  State<SearchFeed> createState() => _SearchFeedState();
}

class _SearchFeedState extends State<SearchFeed> {
  final st.StoryService _storyService = st.StoryService();

  bool isHeartAnimating = false;
  List<Story> get stories => widget.stories;

  Map<int, bool> likeStatuses = {};
  Map<int, bool> followStatuses = {}; // Добавлено для логики подписки
  Map<int, int> likeCounts = {};
  Offset tapPosition = Offset.zero;

  int? currentUserId; // Тип изменен на int?

  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _getUserIdAndFetchInitialData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- МЕТОДЫ ИЗ FEED ---

  Future<void> _getUserIdAndFetchInitialData() async {
    final prefs = await SharedPreferences.getInstance();

    // Логика из Feed: получаем либо userId, либо GUEST_ID
    final storedUserId = prefs.getInt('userId');
    final guestId = prefs.getInt('GUEST_ID');

    // Присваиваем currentUserId
    if (storedUserId != null) {
      currentUserId = storedUserId;
    } else if (guestId != null) {
      currentUserId = guestId;
    }

    debugPrint('currentUserId: $currentUserId');
    await _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    // Обновляем счетчики из переданных данных
    if (mounted) {
      setState(() {
        for (var story in stories) {
          if (story.id != null) {
            likeCounts[story.id!] = story.likesCount;
          }
        }
      });
    }

    // Загружаем актуальные статусы лайков и подписок
    await _fetchLikeStatuses();
    // await _fetchFollowStatuses(); // Если нужна загрузка статусов подписки
  }

  // Скорректирован для соответствия Feed
  Future<void> _fetchLikeStatuses() async {
    if (currentUserId == null) return;
    final Map<int, bool> newLikeStatuses = {};

    for (var story in stories) {
      if (story.id == null) continue;
      try {
        final isLiked = await _storyService.isStoryLiked(
          story.id!,
          currentUserId!,
        );
        newLikeStatuses[story.id!] = isLiked;
      } catch (e) {
        debugPrint('Error fetching like status for story ${story.id}: $e');
      }
    }

    if (mounted) {
      setState(() {
        likeStatuses = newLikeStatuses;
      });
    }
  }

  // --- ИЗМЕНЕННЫЙ МЕТОД: Обработка лайка (с учетом анимации) ---
  Future<void> _handleLike(Story story, {bool isDoubleTap = false}) async {
    if (story.id != null && currentUserId != null) {
      try {
        final storyId = story.id!;
        final bool wasLiked = likeStatuses[storyId] ?? false;
        final int oldLikeCount = likeCounts[storyId] ?? 0;

        setState(() {
          likeStatuses[storyId] = !wasLiked;
          likeCounts[storyId] = wasLiked ? oldLikeCount - 1 : oldLikeCount + 1;

          // 🚨 Анимация только при двойном тапе И если это лайк
          if (isDoubleTap && !wasLiked) {
            isHeartAnimating = true;
          } else if (isDoubleTap && wasLiked) {
            isHeartAnimating = false;
          }
        });

        final newCount = await _storyService.likeStory(storyId, currentUserId!);

        if (mounted) {
          setState(() {
            likeCounts[storyId] = newCount;
          });
        }
      } catch (e) {
        debugPrint('Error liking/unliking story ${story.id}: $e');
        final storyId = story.id!;
        final bool wasLiked = likeStatuses[storyId] ?? false;
        final int oldLikeCount = likeCounts[storyId] ?? 0;
        if (mounted) {
          setState(() {
            // Откат локальных изменений в случае ошибки
            likeStatuses[storyId] = !wasLiked;
            likeCounts[storyId] =
                wasLiked ? oldLikeCount - 1 : oldLikeCount + 1;
            // Отключаем анимацию в случае ошибки
            isHeartAnimating = false;
          });
        }
      }
    }
  }

  // --- КОПИИ МЕТОДОВ ИЗ FEED ДЛЯ ПОЛНОЙ ИДЕНТИЧНОСТИ ---

  // 1. Обработка 'Не интересно'
  Future<void> _handleNotInterested(Story story) async {
    if (story.id == null) return;

    try {
      await _storyService.markStoryAsNotInterested(story.id!);

      setState(() {
        stories.removeWhere((s) => s.id == story.id);
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'История "${story.title}" скрыта. Мы покажем меньше подобного контента.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error marking story as not interested: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при скрытии истории: ${e.toString()}'),
          ),
        );
      }
    }
  }

  // 2. Показать опции истории
  void _showStoryOptions(BuildContext context, Story story) {
    showModalBottomSheet(
      barrierColor: const Color.fromARGB(153, 0, 0, 0),
      elevation: 0,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(
              top: BorderSide(color: neoBlack, width: 4),
              left: BorderSide(color: neoBlack, width: 4),
              right: BorderSide(color: neoBlack, width: 8),
              bottom: BorderSide(color: neoBlack, width: 8),
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: const Icon(
                    Icons.sentiment_dissatisfied,
                    color: Colors.black,
                  ),
                  title: const Text(
                    'Не интересно',
                    style: TextStyle(color: Colors.black),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _handleNotInterested(story);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 3. Информация об авторе (с заглушками)
  Widget _buildAuthorInfo(Story story) {
    final avatarUrl = story.authorAvatar;
    final isAvatarSet = avatarUrl != null && avatarUrl.isNotEmpty;

    if (story.userId == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        context.go('/profile/${story.userId}');
      },
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              const CircleAvatar(radius: 25, backgroundColor: Colors.blueGrey),
              if (isAvatarSet)
                ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: avatarUrl!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) => const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                    errorWidget:
                        (context, url, error) => const Icon(
                          Icons.person,
                          size: 25,
                          color: Colors.white,
                        ),
                  ),
                )
              else
                const Icon(Icons.person, size: 25, color: Colors.white),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // 4. Кнопка настроек
  Widget _buildActionSettingsButton({
    required Widget icon,
    required VoidCallback onPressed,
  }) {
    return Column(children: [GestureDetector(onTap: onPressed, child: icon)]);
  }

  // 5. Кнопка действия с счетчиком (лайки/комментарии)
  Widget _buildActionButton({
    required Widget icon,
    required int count,
    required VoidCallback onPressed,
    bool isLiked = false,
  }) {
    return Column(
      children: [
        GestureDetector(onTap: onPressed, child: icon),
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

  // --- МЕТОД build() ---
  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("Нет результатов для отображения.")),
        bottomNavigationBar: PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(),
      );
    }

    // Проверяем, загружен ли currentUserId
    if (currentUserId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
        bottomNavigationBar: PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(),
      );
    }

    return Scaffold(
      extendBody: true,
      bottomNavigationBar: const PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(),
      body: PageView.builder(
        controller: _pageController,
        itemCount: stories.length,
        scrollDirection: Axis.vertical,
        itemBuilder: (context, index) {
          final story = stories[index];
          final isLiked = likeStatuses[story.id] == true;
          final currentLikeCount = likeCounts[story.id] ?? 0;

          return GestureDetector(
            onDoubleTapDown: (details) {
              // 🚨 ВЫЗОВ: передаем isDoubleTap: true
              _handleLike(story, isDoubleTap: true);
              if (mounted) {
                setState(() {
                  tapPosition = details.localPosition;
                });
              }
            },
            child: Stack(
              children: [
                // --- КОНТЕНТ ИСТОРИИ ---
                Positioned.fill(
                  child: HeartAnimation(
                    position: tapPosition,
                    isAnimating: isHeartAnimating,
                    duration: const Duration(milliseconds: 300),
                    onEnd: () {
                      if (mounted) {
                        setState(() {
                          isHeartAnimating = false;
                        });
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 60,
                        left: 20,
                        right: 80,
                        bottom: 120,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            story.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 30,
                            ),
                          ),
                          const SizedBox(height: 10),
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
                // --- КНОПКИ ---
                Positioned(
                  right: 10,
                  bottom: 150,
                  child: SizedBox(
                    width: 70,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildAuthorInfo(story), // Добавлено
                        _buildActionButton(
                          icon: Image.asset(
                            "icons/png/upvote.png",
                            width: 50,
                            height: 50,
                          ),
                          count: currentLikeCount,
                          // 🚨 ВЫЗОВ: isDoubleTap по умолчанию false (нет анимации)
                          onPressed: () => _handleLike(story),
                          isLiked: isLiked,
                        ),
                        const SizedBox(height: 10),
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
                            await _fetchInitialData();
                          },
                        ),
                        const SizedBox(height: 10),
                        _buildActionSettingsButton(
                          icon: SvgPicture.asset(
                            "icons/settings.svg",
                            width: 50,
                            height: 50,
                          ),
                          onPressed:
                              () => _showStoryOptions(
                                context,
                                story,
                              ), // Добавлено
                        ),
                      ],
                    ),
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
