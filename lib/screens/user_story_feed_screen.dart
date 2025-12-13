import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:readreels/models/story.dart';
import 'package:readreels/services/story_service.dart' as st;
import 'package:readreels/widgets/heart_animation.dart';
import 'package:readreels/widgets/comments_bottom_sheet.dart';
import 'package:readreels/widgets/expandable_story_content.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:readreels/theme.dart';
import 'package:readreels/widgets/bottom_nav_bar_liquid.dart' as p;
import 'package:go_router/go_router.dart';
import 'package:readreels/widgets/neowidgets.dart';

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
  final st.StoryService _storyService = st.StoryService();
  final PageController _pageController = PageController(
    viewportFraction: 0.8, // Видимая часть карточек (80%)
  );

  int? currentUserId;
  bool isHeartAnimating = false;
  Map<int, bool> likeStatuses = {};
  Offset tapPosition = Offset.zero;
  Map<int, int> likeCounts = {};
  int _currentPage = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {});
    });

    // Устанавливаем начальную страницу
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _pageController.jumpToPage(widget.initialIndex);
      }
    });

    _checkAuthStatusAndFetch();
  }

  Future<void> _checkAuthStatusAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    currentUserId = prefs.getInt('user_id');

    // Инициализируем likeCounts из данных историй
    likeCounts.clear();
    for (var story in widget.stories) {
      likeCounts[story.id] = story.likesCount;
      // Проверяем лайк пользователя
      if (currentUserId != null) {
        final isLiked = await _storyService.isStoryLiked(
          story.id,
          currentUserId!,
        );
        likeStatuses[story.id] = isLiked;
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleLike(Story story, {bool isDoubleTap = false}) async {
    if (currentUserId == null) {
      if (mounted) {
        context.go('/auth-check');
      }
      return;
    }

    try {
      final bool wasLiked = likeStatuses[story.id] ?? false;
      final int oldLikeCount = likeCounts[story.id] ?? 0;

      // Оптимистичное обновление UI
      setState(() {
        likeStatuses[story.id] = !wasLiked;
        likeCounts[story.id] = wasLiked ? oldLikeCount - 1 : oldLikeCount + 1;
        if (isDoubleTap && !wasLiked) {
          isHeartAnimating = true;
        }
      });

      // Вызов API
      final newCount = await _storyService.likeStory(story.id, currentUserId!);

      // Синхронизация с серверным ответом
      setState(() {
        likeCounts[story.id] = newCount;
      });
    } catch (e) {
      debugPrint('Error liking story: $e');
      // Откат при ошибке
      final bool wasLiked = likeStatuses[story.id] ?? false;
      final int oldLikeCount = likeCounts[story.id] ?? 0;
      setState(() {
        likeStatuses[story.id] = !wasLiked;
        likeCounts[story.id] = wasLiked ? oldLikeCount - 1 : oldLikeCount + 1;
        isHeartAnimating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Функция для склонения слова "ответ"
  String _getReplyText(int count) {
    if (count == 0) return '0 ответов';

    // Исключения для чисел 11-14
    if (count % 100 >= 11 && count % 100 <= 14) {
      return '$count ответов';
    }

    switch (count % 10) {
      case 1:
        return '$count ответ';
      case 2:
      case 3:
      case 4:
        return '$count ответа';
      default:
        return '$count ответов';
    }
  }

  Widget _buildStoryCard(Story story, int index) {
    final isLiked = likeStatuses[story.id] ?? false;
    final currentLikeCount = likeCounts[story.id] ?? 0;
    final double currentPage = _pageController.page ?? _currentPage.toDouble();
    final double diff = (index - currentPage).abs();
    final double scale =
        1 - (diff * 0.1).clamp(0.0, 0.2); // Масштаб для боковых карточек
    final double opacity =
        1 - (diff * 0.5).clamp(0.0, 0.7); // Прозрачность для боковых карточек
    final bool isCurrent = index == _currentPage;

    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              margin: const EdgeInsets.only(top: 15),
              width: MediaQuery.of(context).size.width,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: neoBlack, width: 2),
              ),
              child: Stack(
                children: [
                  HeartAnimation(
                    position: tapPosition,
                    isAnimating: isHeartAnimating,
                    duration: const Duration(milliseconds: 300),
                    onEnd:
                        () => setState(() {
                          isHeartAnimating = false;
                        }),
                    child: SizedBox(
                      height:
                          MediaQuery.of(context).size.height *
                          0.7, // Фиксированная высота
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ЗАГОЛОВОК (жирный и большой) - ТОЧЬ В ТОЧЬ КАК В FEED
                          Text(
                            story.title,
                            style: GoogleFonts.russoOne(
                              fontSize: 26,
                              color: Colors.black,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 16),

                          // РЯД: Аватар + Имя пользователя - ТОЧЬ В ТОЧЬ КАК В FEED
                          Row(
                            children: [
                              // Аватар
                              _buildAuthorAvatar(story),

                              const SizedBox(width: 12),

                              // Имя пользователя и информация
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            story.resolvedUsername,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 18,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (story.isVerified)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 4),
                                            child: Icon(
                                              Icons.verified,
                                              color: Color.fromARGB(
                                                255,
                                                0,
                                                0,
                                                0,
                                              ),
                                              size: 18,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Контент истории - ТОЧЬ В ТОЧЬ КАК В FEED
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: ExpandableStoryContent(
                                content: story.content,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Хештеги (если есть) - ТОЧЬ В ТОЧЬ КАК В FEED
                          if (story.hashtags.isNotEmpty && isCurrent)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children:
                                    story.hashtags.map((hashtag) {
                                      return Chip(
                                        label: Text(
                                          '#${hashtag.name}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        backgroundColor: Colors.blue[50],
                                        visualDensity: VisualDensity.compact,
                                      );
                                    }).toList(),
                              ),
                            ),

                          // Действия (кнопки лайка и ответа) - ТОЧЬ В ТОЧЬ КАК В FEED
                          if (isCurrent)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Кнопка ответить - ТОЧЬ В ТОЧЬ КАК В FEED
                                  Container(
                                    width: 400,
                                    height: 80,
                                    child: NeoIconButton(
                                      onPressed: () {
                                        if (currentUserId == null) {
                                          if (mounted) {
                                            context.go('/auth-check');
                                          }
                                          return;
                                        }

                                        context.go(
                                          '/addStory',
                                          extra: {
                                            'replyTo': story.id,
                                            'parentTitle': story.title,
                                          },
                                        );
                                      },
                                      icon: const Icon(Icons.reply, size: 18),
                                      child: Text(
                                        'Ответить | ${_getReplyText(story.commentsCount)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Аватар автора - ТОЧЬ В ТОЧЬ КАК В FEED
  Widget _buildAuthorAvatar(Story story) {
    print('🟣 USER STORY FEED Avatar URL: ${story.avatarUrl}');
    print('🟣 USER STORY FEED Username: ${story.username}');
    print('🟣 USER STORY FEED Story ID: ${story.id}');
    return GestureDetector(
      onTap: () => context.go('/profile/${story.userId}'),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: neoBlack, width: 2),
          color: Colors.grey[200],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Аватар
            if (story.avatarUrl != null && story.avatarUrl!.isNotEmpty)
              ClipOval(
                child: CachedNetworkImage(
                  imageUrl: story.avatarUrl!,
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                  placeholder:
                      (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(neoBlack),
                          ),
                        ),
                      ),
                  errorWidget:
                      (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.person,
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                ),
              )
            else
              Container(
                color: Colors.grey[300],
                child: const Icon(Icons.person, size: 24, color: Colors.white),
              ),

            // Индикатор верификации
            if (story.isVerified)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified,
                    color: Colors.blue,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'только что';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} мин назад';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ч назад';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} д назад';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.library_books_outlined,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 20),
            const Text(
              'Нет историй для отображения',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: neoBlack,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                'Вернуться в профиль',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
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
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 100,
          automaticallyImplyLeading: false,
          elevation: 0,
          surfaceTintColor: neoBackground,
          centerTitle: false,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: SvgPicture.asset(
            "assets/icons/logo.svg",
            width: 60,
            height: 60,
          ),
          actions: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: SvgPicture.asset(
                "assets/icons/close_submit_form.svg",
                width: 60,
                height: 60,
              ),
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: _buildEmptyState(),
        bottomNavigationBar: const p.PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 100,
        automaticallyImplyLeading: false,
        elevation: 0,
        surfaceTintColor: neoBackground,
        centerTitle: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: SvgPicture.asset("assets/icons/logo.svg", width: 60, height: 60),
        actions: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: SvgPicture.asset(
              "assets/icons/close_story.svg",
              width: 60,
              height: 60,
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: const p.PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(),
      body: SafeArea(
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.stories.length,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            return GestureDetector(
              onDoubleTapDown: (details) {
                if (currentUserId == null) {
                  if (mounted) {
                    context.go('/auth-check');
                  }
                  return;
                }
                _handleLike(widget.stories[index], isDoubleTap: true);
                setState(() {
                  tapPosition = details.localPosition;
                });
              },
              child: _buildStoryCard(widget.stories[index], index),
            );
          },
        ),
      ),
    );
  }
}
