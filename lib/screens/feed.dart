import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:readreels/models/story.dart';
import 'package:readreels/screens/story_detail.dart';
import 'package:readreels/widgets/heart_animation.dart';
import 'package:readreels/services/story_service.dart' as st;
import 'package:readreels/widgets/bottom_nav_bar_liquid.dart';
import 'package:readreels/widgets/neowidgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:readreels/theme.dart';
import 'package:readreels/widgets/comments_bottom_sheet.dart';
import 'package:readreels/widgets/expandable_story_content.dart';

enum StoryType { seeds, branches, all }

class Feed extends StatefulWidget {
  const Feed({super.key});

  @override
  State<Feed> createState() => _FeedState();
}

class _FeedState extends State<Feed> with SingleTickerProviderStateMixin {
  final st.StoryService _storyService = st.StoryService();

  late TabController _tabController;
  StoryType _currentStoryType = StoryType.seeds;

  int? currentUserId;
  bool isHeartAnimating = false;
  List<Story> seeds = [];
  List<Story> branches = [];
  List<Story> allStories = [];
  Map<int, bool> likeStatuses = {};
  Offset tapPosition = Offset.zero;
  Map<int, int> likeCounts = {};
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  // Для карусели
  final PageController _pageController = PageController(
    viewportFraction: 0.8, // Видимая часть карточек (80%)
  );
  int _currentPage = 0;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _checkAuthStatusAndFetch();

    // Слушатель для обновления UI при скролле
    _pageController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;

    setState(() {
      _currentStoryType = StoryType.values[_tabController.index];
      _fetchCurrentTabStories();
    });
  }

  Future<void> _checkAuthStatusAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    currentUserId = prefs.getInt('user_id');
    final guestId = prefs.getInt('GUEST_ID');

    if (currentUserId == null && guestId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Требуется авторизация';
        });
        Future.delayed(Duration.zero, () => context.go('/auth'));
      }
      return;
    }

    await _fetchCurrentTabStories();
  }

  Future<void> _fetchCurrentTabStories() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      switch (_currentStoryType) {
        case StoryType.seeds:
          seeds = await _storyService.getSeeds();
          break;
        case StoryType.branches:
          branches = await _storyService.getBranches();
          break;
        case StoryType.all:
          allStories = await _storyService.getStories();
          break;
      }

      // Инициализируем likeCounts из данных историй
      likeCounts.clear();
      for (var story in _currentStories) {
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

      setState(() {
        _isLoading = false;
        _currentPage = 0;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки историй: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Ошибка загрузки историй';
      });
    }
  }

  List<Story> get _currentStories {
    switch (_currentStoryType) {
      case StoryType.seeds:
        return seeds;
      case StoryType.branches:
        return branches;
      case StoryType.all:
        return allStories;
    }
  }

  Future<void> _handleLike(Story story, {bool isDoubleTap = false}) async {
    if (currentUserId == null) {
      if (mounted) {
        context.go('/auth');
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => StoryDetailPage(story: story),
                      ),
                    );
                  },
                  onDoubleTapDown: (details) {
                    _handleLike(story, isDoubleTap: true);
                    setState(() {
                      tapPosition = details.localPosition;
                    });
                  },
                  child: Column(
                    children: [
                      Expanded(
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ЗАГОЛОВОК (жирный и большой)
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

                                    // РЯД: Аватар + Имя пользователя
                                    Row(
                                      children: [
                                        // Аватар
                                        _buildAuthorAvatar(story),

                                        const SizedBox(width: 12),

                                        // Имя пользователя и информация
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      story.username,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 18,
                                                        color: Colors.black87,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (story.isVerified)
                                                    const Padding(
                                                      padding: EdgeInsets.only(
                                                        left: 4,
                                                      ),
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

                                              const SizedBox(height: 4),

                                              // Информация о ветке/ответе
                                              // Text(
                                              //   story.replyInfo,
                                              //   style: TextStyle(
                                              //     color: Colors.grey[600],
                                              //     fontSize: 14,
                                              //   ),
                                              // ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 20),

                                    // Контент истории
                                    Expanded(
                                      child: SingleChildScrollView(
                                        physics: const BouncingScrollPhysics(),
                                        child: ExpandableStoryContent(
                                          content: story.content,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 20),

                                    // Хештеги (если есть)
                                    if (story.hashtags.isNotEmpty && isCurrent)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          children:
                                              story.hashtags.map((hashtag) {
                                                return Chip(
                                                  label: Text(
                                                    '#${hashtag.name}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  backgroundColor:
                                                      Colors.blue[50],
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                );
                                              }).toList(),
                                        ),
                                      ),

                                    // Действия (кнопки лайка и ответа)
                                    if (isCurrent)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            // Лайк
                                            // GestureDetector(
                                            //   onTap: () => _handleLike(story),
                                            //   child: Row(
                                            //     children: [
                                            //       Icon(
                                            //         isLiked
                                            //             ? Icons.favorite
                                            //             : Icons.favorite_border,
                                            //         color:
                                            //             isLiked
                                            //                 ? Colors.red
                                            //                 : Colors.grey[600],
                                            //         size: 28,
                                            //       ),
                                            //       const SizedBox(width: 6),
                                            //       Text(
                                            //         currentLikeCount.toString(),
                                            //         style: TextStyle(
                                            //           color:
                                            //               isLiked
                                            //                   ? Colors.red
                                            //                   : Colors
                                            //                       .grey[600],
                                            //           fontWeight:
                                            //               FontWeight.bold,
                                            //           fontSize: 16,
                                            //         ),
                                            //       ),
                                            //     ],
                                            //   ),
                                            // ),

                                            // Кнопка ответить
                                            if (!story.isReply)
                                              Container(
                                                width: 400,
                                                height: 80,
                                                child: NeoIconButton(
                                                  onPressed: () {
                                                    if (currentUserId == null) {
                                                      if (mounted) {
                                                        context.go('/auth');
                                                      }
                                                      return;
                                                    }

                                                    context.go(
                                                      '/addStory',
                                                      extra: {
                                                        'replyTo': story.id,
                                                        'parentTitle':
                                                            story.title,
                                                      },
                                                    );
                                                  },
                                                  icon: const Icon(
                                                    Icons.reply,
                                                    size: 18,
                                                  ),
                                                  child: Text(
                                                    'Ответить | ${_getReplyText(story.replyCount)}',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w500,
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
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // Вынес аватар в отдельный виджет для чистоты кода
  Widget _buildAuthorAvatar(Story story) {
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

  Widget _buildEmptyState() {
    String message = '';
    IconData icon = Icons.library_books_outlined;

    switch (_currentStoryType) {
      case StoryType.seeds:
        message = 'Пока нет семян\nБудьте первым, кто создаст!';
        icon = Icons.spa_outlined;
        break;
      case StoryType.branches:
        message = 'Пока нет веток\nОтветьте на историю, чтобы создать ветку!';
        icon = Icons.account_tree_outlined;
        break;
      case StoryType.all:
        message = 'Историй пока нет\nСоздайте первую!';
        icon = Icons.library_books_outlined;
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            if (_hasError)
              ElevatedButton(
                onPressed: _fetchCurrentTabStories,
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
                  'Повторить загрузку',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(neoBlack),
          ),
          const SizedBox(height: 20),
          Text(
            _currentStoryType == StoryType.seeds
                ? 'Загружаем семена...'
                : _currentStoryType == StoryType.branches
                ? 'Загружаем ветки...'
                : 'Загружаем истории...',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_currentStories.isEmpty && !_isLoading) {
      return _buildEmptyState();
    }

    return Expanded(
      child: PageView.builder(
        controller: _pageController,
        itemCount: _currentStories.length,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          return _buildStoryCard(_currentStories[index], index);
        },
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
        title: SvgPicture.asset("assets/icons/logo.svg", width: 60, height: 60),
        actions: [
          GestureDetector(
            onTap: () => context.go("/search"),
            child: SvgPicture.asset(
              "assets/icons/search.svg",
              width: 60,
              height: 60,
            ),
          ),
          const SizedBox(width: 10),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(90),
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Container(
              height: 70,
              child: Row(
                children: [
                  // Левая кнопка - скругление слева, нет справа
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_tabController.index != 0) {
                          _tabController.animateTo(0);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              _tabController.index == 0
                                  ? neoBlack
                                  : Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(15),
                            bottomLeft: Radius.circular(15),
                            topRight: Radius.circular(0),
                            bottomRight: Radius.circular(0),
                          ),
                          border: Border.all(color: neoBlack, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            'Семена',
                            style: TextStyle(
                              color:
                                  _tabController.index == 0
                                      ? Colors.white
                                      : Colors.grey[700],
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Правая кнопка - скругление справа, нет слева
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_tabController.index != 1) {
                          _tabController.animateTo(1);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              _tabController.index == 1
                                  ? neoBlack
                                  : Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(0),
                            bottomLeft: Radius.circular(0),
                            topRight: Radius.circular(15),
                            bottomRight: Radius.circular(15),
                          ),
                          border: Border.all(color: neoBlack, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: neoBlack.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'Ветки',
                            style: TextStyle(
                              color:
                                  _tabController.index == 1
                                      ? Colors.white
                                      : Colors.grey[700],
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: const PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(),
      body: SafeArea(
        child: _isLoading ? _buildLoadingState() : _buildContent(),
      ),
    );
  }
}
