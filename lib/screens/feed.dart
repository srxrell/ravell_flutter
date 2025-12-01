import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:readreels/models/story.dart';
import 'package:readreels/widgets/expandable_story_content.dart';
import 'package:readreels/widgets/heart_animation.dart';
import 'package:readreels/services/story_service.dart' as st;
import 'package:readreels/widgets/bottom_nav_bar_liquid.dart';
import 'package:readreels/widgets/comments_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:readreels/theme.dart';

class Feed extends StatefulWidget {
  const Feed({super.key});
  @override
  State<Feed> createState() => _FeedState();
}

class _FeedState extends State<Feed> {
  final st.StoryService _storyService = st.StoryService();

  int? currentuser_id;
  bool isHeartAnimating = false;
  List<Story> stories = [];
  Map<int, bool> likeStatuses = {};
  Offset tapPosition = Offset.zero;
  Map<int, int> likeCounts = {};
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _noStories = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatusAndFetch();
  }

  Future<void> _checkAuthStatusAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    currentuser_id = prefs.getInt('user_id');
    final guestId = prefs.getInt('GUEST_ID');

    if (currentuser_id == null && guestId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Требуется авторизация';
        });
        context.go('/auth');
      }
      return;
    }

    await _fetchStories();
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final hasConnection = await _storyService.checkServerConnection();
      return hasConnection;
    } catch (e) {
      debugPrint('Ошибка проверки соединения: $e');
      return false;
    }
  }

  Future<void> _fetchStories() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _noStories = false;
      _errorMessage = '';
    });

    // ✅ СНАЧАЛА ПРОБУЕМ ЗАГРУЗИТЬ ИЗ КЭША (даже если есть интернет)
    try {
      final localStories = await _storyService.getLocalStories();
      if (localStories.isNotEmpty) {
        setState(() {
          stories = localStories;
          _noStories = false;
          _isLoading = false;

          // Загружаем likeCounts для кэшированных историй
          for (var story in stories) {
            if (story.id != null) {
              likeCounts[story.id!] = story.likesCount;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки из кэша: $e');
    }

    // ✅ ПРОВЕРЯЕМ ИНТЕРНЕТ
    bool hasInternet = false;
    try {
      hasInternet = await _checkInternetConnection();
    } catch (e) {
      debugPrint('Ошибка проверки интернета: $e');
    }

    if (!hasInternet) {
      // Если нет интернета и в кэше нет историй
      if (stories.isEmpty) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Нет подключения к интернету 😔';
        });
      } else {
        // Есть кэшированные истории, но нет интернета
        setState(() {
          _isLoading = false;
          _hasError = false;
        });
      }
      return;
    }

    // ✅ ЕСТЬ ИНТЕРНЕТ - ЗАГРУЖАЕМ С СЕРВЕРА
    try {
      final fetchedStories = await _storyService.getStories();

      setState(() {
        stories = fetchedStories;
        _noStories = stories.isEmpty;
        _isLoading = false;
        _hasError = false;

        // Сбрасываем likeCounts для новых историй
        likeCounts.clear();
        for (var story in stories) {
          if (story.id != null) {
            likeCounts[story.id!] = story.likesCount;
          }
        }
      });

      // ✅ СОХРАНЯЕМ В КЭШ (даже если список пустой)
      try {
        await _storyService.saveStoriesLocally(stories);
      } catch (e) {
        debugPrint('Ошибка сохранения в кэш: $e');
      }
    } catch (e) {
      debugPrint('Ошибка загрузки историй: $e');

      // Если при загрузке с сервера произошла ошибка, но есть кэшированные истории
      if (stories.isEmpty) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Ошибка загрузки историй 😕';
        });
      } else {
        // Есть кэшированные истории - показываем их с предупреждением
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Показаны сохраненные истории (нет соединения)';
        });
      }
    }
  }

  Future<void> _handleLike(Story story, {bool isDoubleTap = false}) async {
    if (story.id != null && currentuser_id != null) {
      try {
        final bool wasLiked = likeStatuses[story.id] ?? false;
        final int oldLikeCount = likeCounts[story.id] ?? 0;

        setState(() {
          likeStatuses[story.id!] = !wasLiked;
          likeCounts[story.id!] =
              wasLiked ? oldLikeCount - 1 : oldLikeCount + 1;
          if (isDoubleTap && !wasLiked) {
            isHeartAnimating = true;
          }
        });

        final newCount = await _storyService.likeStory(
          story.id!,
          currentuser_id!,
        );
        setState(() {
          likeCounts[story.id!] = newCount;
        });
      } catch (e) {
        debugPrint('Error liking story: $e');
        // Откат изменений
        final bool wasLiked = likeStatuses[story.id] ?? false;
        final int oldLikeCount = likeCounts[story.id] ?? 0;
        setState(() {
          likeStatuses[story.id!] = !wasLiked;
          likeCounts[story.id!] =
              wasLiked ? oldLikeCount - 1 : oldLikeCount + 1;
          isHeartAnimating = false;
        });
      }
    }
  }

  Future<void> _handleNotInterested(Story story) async {
    if (story.id == null) return;

    try {
      await _storyService.markStoryAsNotInterested(story.id!);
      setState(() {
        stories.removeWhere((s) => s.id == story.id);
        _noStories = stories.isEmpty;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('История "${story.title}" скрыта.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error marking story as not interested: $e');
    }
  }

  void _showStoryOptions(BuildContext context, Story story) {
    showModalBottomSheet(
      barrierColor: const Color.fromARGB(153, 0, 0, 0),
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
                ListTile(
                  leading: const Icon(Icons.cancel, color: Colors.black),
                  title: const Text(
                    'Отмена',
                    style: TextStyle(color: Colors.black),
                  ),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required Widget icon,
    required int count,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        GestureDetector(onTap: onPressed, child: icon),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthorInfo(Story story) {
    final avatarUrl = story.authorAvatar;
    final isAvatarSet = avatarUrl != null && avatarUrl.isNotEmpty;

    if (story.userId == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => context.go('/profile/${story.userId}'),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_noStories)
              Column(
                children: [
                  Icon(
                    Icons.library_books_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'В ленте пока пусто 📚',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Будьте первым, кто опубликует историю!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              )
            else if (_hasError)
              Column(
                children: [
                  Icon(
                    _errorMessage.contains('интернет') ||
                            _errorMessage.contains('соединения')
                        ? Icons.wifi_off
                        : Icons.error_outline,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_errorMessage.contains('интернет') ||
                      _errorMessage.contains('соединения'))
                    const Text(
                      'Проверьте подключение и повторите попытку',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                ],
              ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _fetchStories,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Повторить загрузку',
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
            if (stories.isNotEmpty)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Показать кэшированные истории',
                  style: TextStyle(fontSize: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 100,
        elevation: 0,
        surfaceTintColor: neoBackground,
        centerTitle: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: SvgPicture.asset("icons/logo.svg", width: 60, height: 60),
        actions: [
          GestureDetector(
            onTap: () => context.go("/search"),
            child: SvgPicture.asset("icons/search.svg", width: 60, height: 60),
          ),
          const SizedBox(width: 10),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: const PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(),
      body:
          _isLoading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text(
                      'Загружаем истории...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
              : (_hasError && stories.isEmpty) || _noStories
              ? _buildEmptyState()
              : PageView.builder(
                itemCount: stories.length,
                scrollDirection: Axis.vertical,
                itemBuilder: (context, index) {
                  final story = stories[index];
                  final isLiked = likeStatuses[story.id] == true;
                  final currentLikeCount = likeCounts[story.id] ?? 0;

                  return GestureDetector(
                    onDoubleTapDown: (details) {
                      _handleLike(story, isDoubleTap: true);
                      setState(() {
                        tapPosition = details.localPosition;
                      });
                    },
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: HeartAnimation(
                            position: tapPosition,
                            isAnimating: isHeartAnimating,
                            duration: const Duration(milliseconds: 300),
                            onEnd:
                                () => setState(() {
                                  isHeartAnimating = false;
                                }),
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: 20,
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
                                      child: ExpandableStoryContent(
                                        content: story.content,
                                      ),
                                    ),
                                  ),
                                  // ✅ Показываем предупреждение, если есть ошибка но истории загружены из кэша
                                  if (_hasError && stories.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(top: 10),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.amber[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.amber),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.wifi_off,
                                            size: 16,
                                            color: Colors.amber,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _errorMessage,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54,
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
                        ),
                        Positioned(
                          right: 10,
                          bottom: 150,
                          child: SizedBox(
                            width: 70,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _buildAuthorInfo(story),
                                const SizedBox(height: 10),
                                _buildActionButton(
                                  icon: Image.asset(
                                    "icons/png/upvote.png",
                                    width: 50,
                                    height: 50,
                                  ),
                                  count: currentLikeCount,
                                  onPressed: () => _handleLike(story),
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
                                      builder:
                                          (context) =>
                                              CommentsBottomSheet(story: story),
                                    );
                                    await _fetchStories();
                                  },
                                ),
                                const SizedBox(height: 10),
                                GestureDetector(
                                  onTap:
                                      () => _showStoryOptions(context, story),
                                  child: SvgPicture.asset(
                                    "icons/settings.svg",
                                    width: 50,
                                    height: 50,
                                  ),
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
