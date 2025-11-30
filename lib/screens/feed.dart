import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
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

// 🚨 Предполагаемая константа для neoBlack (для работы bottom sheet)
// Замените на вашу фактическую константу, если она отличается
const Color neoBlack = Colors.black;
const Color neoBackground = Colors.white;

class Feed extends StatefulWidget {
  const Feed({super.key});
  @override
  State<Feed> createState() => _FeedState();
}

class _FeedState extends State<Feed> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final st.StoryService _storyService = st.StoryService();
  int? currentuser_id;
  bool isHeartAnimating = false;
  List<Story> stories = [];
  Map<int, bool> likeStatuses = {};
  Map<int, bool> followStatuses = {};
  Offset tapPosition = Offset.zero;
  Map<int, int> likeCounts = {};
  bool _isLoading = true;
  bool _isOfflineMode = false;

  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkAuthStatusAndFetch();
    _startConnectivityMonitoring();
    _fetchStories(isManualRefresh: true);
  }

  void _startConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final hasConnection = !results.contains(ConnectivityResult.none);

      if (hasConnection && _isOfflineMode) {
        _isOfflineMode = false;
        _fetchStories(isManualRefresh: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Интернет восстановлен. Обновляем ленту.'),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  // Future<void> _getuser_id() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   currentuser_id = prefs.getInt('user_id');
  //   debugPrint('currentuser_id: $currentuser_id');
  // }

  // --- ПОЛНЫЙ МЕТОД: Обработка 'Не интересно' ---
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

  // --- ПОЛНЫЙ МЕТОД: Показать опции истории ---
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
                // ➕ Добавим кнопку Отмены для полноты
              ],
            ),
          ),
        );
      },
    );
  }

  // --- ИСПРАВЛЕННЫЙ МЕТОД: Загрузка с проверкой аутентификации ---
  Future<void> _checkAuthStatusAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    currentuser_id = prefs.getInt('user_id');
    final guestId = prefs.getInt('GUEST_ID');

    if (currentuser_id == null && guestId == null && mounted) {
      debugPrint('Neither User ID nor Guest ID found. Redirecting to /auth.');
      setState(() {
        _isLoading = false;
      });
      context.go('/auth');
      return;
    }

    await _fetchStories();
  }

  // --- ПОЛНЫЙ МЕТОД: Загрузка историй ---
  Future<void> _fetchStories({bool isManualRefresh = false}) async {
    if (_isLoading && !isManualRefresh) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    List<Story> fetchedStories = [];
    bool successfullyFetchedOnline = false;
    Map<int, bool> finalLikeStatuses = {};

    try {
      debugPrint(
        '--- 1. Начало проверки сети и загрузки. Time: ${DateTime.now()}',
      );

      final connectivityResult = await (Connectivity().checkConnectivity());
      final isConnected = !connectivityResult.contains(ConnectivityResult.none);

      // final isConnectedToWeb = _isOfflineMode ? false : isConnected;

      if (isConnected) {
        try {
          debugPrint(
            '--- 2. Пытаемся загрузить из сети. Time: ${DateTime.now()}',
          );
          debugPrint('--- 2.1. *** Вызываем StoryService.getStories() ***');

          fetchedStories = await _storyService.getStories().catchError((e) {
            debugPrint('КРИТИЧЕСКАЯ ОШИБКА ВНУТРИ getStories: $e');
            throw e;
          });

          debugPrint(
            '--- 3. Загрузка из сети успешна. Time: ${DateTime.now()}. Получено: ${fetchedStories.length} историй.',
          );
          successfullyFetchedOnline = true;

          await _storyService.clearLocalStories();
          await _storyService.saveStoriesLocally(fetchedStories);

          if (currentuser_id != null) {
            finalLikeStatuses = await _fetchLikeStatuses(fetchedStories);
          }
        } catch (e) {
          debugPrint('Ошибка онлайн-загрузки ($e). Переход к кэшу.');
          fetchedStories = await _storyService.getLocalStories();
        }
      } else {
        debugPrint('Сеть недоступна. Загрузка из кэша.');
        fetchedStories = await _storyService.getLocalStories();
      }

      if (mounted) {
        setState(() {
          stories = fetchedStories;

          for (var story in stories) {
            if (story.id != null) {
              likeCounts[story.id!] = story.likesCount;
            }
          }

          if (finalLikeStatuses.isNotEmpty) {
            likeStatuses = finalLikeStatuses;
          }

          _isOfflineMode = !isConnected || !successfullyFetchedOnline;
          _isLoading = false;

          debugPrint(
            '--- 6. Загрузка завершена. _isLoading = false. Time: ${DateTime.now()}',
          );
        });
      }
    } catch (e) {
      debugPrint('Критическая ошибка при загрузке историй: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось загрузить истории: $e')),
        );
        setState(() {
          _isLoading = false;
          _isOfflineMode = true;

          _storyService.getLocalStories().then((localStories) {
            if (mounted) {
              setState(() {
                stories = localStories;
              });
            }
          });
        });
      }
    }
  }

  // --- ПОЛНЫЙ МЕТОД: Загрузка статусов лайков ---
  Future<Map<int, bool>> _fetchLikeStatuses(List<Story> currentStories) async {
    if (currentuser_id == null) return {};
    final Map<int, bool> newLikeStatuses = {};

    for (var story in currentStories) {
      if (story.id == null) continue;
      try {
        final isLiked = await _storyService.isStoryLiked(
          story.id!,
          currentuser_id!,
        );
        newLikeStatuses[story.id!] = isLiked;
      } catch (e) {
        debugPrint('Error fetching like status for story ${story.id}: $e');
      }
    }
    return newLikeStatuses;
  }

  // --- ИЗМЕНЕННЫЙ МЕТОД: Обработка лайка ---
  // 🚨 ИЗМЕНЕНИЕ: Добавлен необязательный параметр isDoubleTap
  Future<void> _handleLike(Story story, {bool isDoubleTap = false}) async {
    if (story.id != null && currentuser_id != null) {
      try {
        final bool wasLiked = likeStatuses[story.id] ?? false;
        final int oldLikeCount = likeCounts[story.id] ?? 0;

        setState(() {
          likeStatuses[story.id!] = !wasLiked;
          likeCounts[story.id!] =
              wasLiked ? oldLikeCount - 1 : oldLikeCount + 1;

          // 🚨 ИЗМЕНЕНИЕ: Анимация только при двойном тапе и если это лайк (не дизлайк)
          if (isDoubleTap && !wasLiked) {
            isHeartAnimating = true;
          } else if (isDoubleTap && wasLiked) {
            // Если это двойной тап, и мы дизлайкаем, анимацию не показываем
            isHeartAnimating = false;
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
        debugPrint('Error liking/unliking story ${story.id}: $e');
        final bool wasLiked = likeStatuses[story.id] ?? false;
        final int oldLikeCount = likeCounts[story.id] ?? 0;
        setState(() {
          // Откатываем локальные изменения в случае ошибки
          likeStatuses[story.id!] = !wasLiked;
          likeCounts[story.id!] =
              wasLiked ? oldLikeCount - 1 : oldLikeCount + 1;
          // 🚨 Отключаем анимацию в случае ошибки
          isHeartAnimating = false;
        });
      }
    }
  }

  // --- ПОЛНЫЙ МЕТОД: Переключение подписки ---
  // Future<void> _handleFollowToggle(int user_id) async {
  //   if (currentuser_id == null || user_id == currentuser_id) return;

  //   try {
  //     await _subscriptionService.toggleFollow(user_id);

  //     final isCurrentlyFollowing = followStatuses[user_id] ?? false;
  //     setState(() {
  //       followStatuses[user_id] = !isCurrentlyFollowing;
  //     });
  //   } catch (e) {
  //     debugPrint('Error toggling follow status: $e');
  //   }
  // }

  // --- ПОЛНЫЙ МЕТОД: Кнопка настроек ---
  Widget _buildActionSettingsButton({
    required Widget icon,
    required VoidCallback onPressed,
  }) {
    return Column(children: [GestureDetector(onTap: onPressed, child: icon)]);
  }

  // --- ПОЛНЫЙ МЕТОД: Кнопка действия с счетчиком ---
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

  // --- ПОЛНЫЙ МЕТОД: Информация об авторе ---
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

  // --- МЕТОД build() ---
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
          Builder(
            builder: (innerContext) {
              return GestureDetector(
                onTap: () {
                  context.go("/search");
                },
                child: SvgPicture.asset(
                  "icons/search.svg",
                  width: 60,
                  height: 60,
                ),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: const PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : stories.isEmpty
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isOfflineMode
                            ? '⚠️ Оффлайн-режим. Историй в кэше нет.'
                            : 'В ленте пока пусто. 🚀',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => _fetchStories(isManualRefresh: true),
                        child: const Text('Повторить загрузку'),
                      ),
                    ],
                  ),
                ),
              )
              : PageView.builder(
                itemCount: stories.length,
                scrollDirection: Axis.vertical,
                itemBuilder: (context, index) {
                  final story = stories[index];
                  final isLiked = likeStatuses[story.id] == true;
                  final currentLikeCount = likeCounts[story.id] ?? 0;

                  return GestureDetector(
                    onDoubleTapDown: (details) {
                      // 🚨 ИЗМЕНЕНИЕ: Обработка лайка и анимация
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
                            onEnd: () {
                              setState(() {
                                isHeartAnimating = false;
                              });
                            },
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
                                      child:
                                      // ЗАМЕНА ЗДЕСЬ
                                      ExpandableStoryContent(
                                        content: story.content,
                                      ),
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
                                _buildActionButton(
                                  icon: Image.asset(
                                    "icons/png/upvote.png",
                                    width: 50,
                                    height: 50,
                                  ),
                                  count: currentLikeCount,
                                  // 🚨 ИЗМЕНЕНИЕ: Не передаем isDoubleTap, по умолчанию false.
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
                                        return CommentsBottomSheet(
                                          story: story,
                                        );
                                      },
                                    );
                                    await _fetchStories();
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
                                      () => _showStoryOptions(context, story),
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
