import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:readreels/models/story.dart';
import 'package:readreels/screens/story_detail.dart';
import 'package:readreels/widgets/heart_animation.dart';
import 'package:readreels/services/story_service.dart' as st;
import 'package:readreels/widgets/bottom_nav_bar_liquid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:readreels/theme.dart';

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
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _checkAuthStatusAndFetch();
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

    // **FIX: Обернули в LayoutBuilder, чтобы передать ограниченную высоту в Container**
    return LayoutBuilder(
      builder: (context, constraints) {
        // constraints.maxHeight - (2 * 16 margin) - 20 (SizedBox height)
        // Вычитаем вертикальный margin (16 сверху + 16 снизу) и 20px отступа снизу
        final double containerHeight = constraints.maxHeight - 52;

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
              Container(
                // **ПРИМЕНЯЕМ ОГРАНИЧЕННУЮ ВЫСОТУ для Column с Expanded внутри**
                height:
                    containerHeight.isFinite && containerHeight > 0
                        ? containerHeight
                        : null,

                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: neoBlack, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: neoBlack.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
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
                          // Заголовок и информация об авторе
                          Row(
                            children: [
                              _buildAuthorInfo(story),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Имя пользователя и заголовок
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            story.username,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
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
                                              color: Colors.blue,
                                              size: 16,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      story.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      story.replyInfo,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Контент истории
                          Expanded(
                            child: SingleChildScrollView(
                              child: ExpandableStoryContent(
                                content: story.content,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Хештеги (если есть)
                          if (story.hashtags.isNotEmpty)
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

                          // Действия
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Лайки и ответы
                              Row(
                                children: [
                                  // Лайк
                                  GestureDetector(
                                    onTap: () => _handleLike(story),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isLiked
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color:
                                              isLiked
                                                  ? Colors.red
                                                  : Colors.grey[600],
                                          size: 24,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          currentLikeCount.toString(),
                                          style: TextStyle(
                                            color:
                                                isLiked
                                                    ? Colors.red
                                                    : Colors.grey[600],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 20),

                                  // Ответы
                                  GestureDetector(
                                    onTap: () async {
                                      if (currentUserId == null) {
                                        if (mounted) {
                                          context.go('/auth');
                                        }
                                        return;
                                      }

                                      // ЗАМЕНИЛИ RepliesBottomSheet на CommentsBottomSheet в этом месте
                                      await showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder:
                                            (context) => RepliesBottomSheet(
                                              parentStory:
                                                  story, // Предполагаем, что аргумент называется 'story'
                                            ),
                                      );
                                      // Обновляем данные после закрытия bottom sheet
                                      await _fetchCurrentTabStories();
                                    },
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.reply,
                                          color: Colors.grey,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          story.replyCount.toString(),
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              // Кнопка ответить (если это не ответ)
                              if (!story.isReply)
                                OutlinedButton.icon(
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
                                        'parentTitle': story.title,
                                      },
                                    );
                                  },
                                  icon: const Icon(Icons.reply, size: 16),
                                  label: const Text('Ответить'),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: neoBlack),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Бейдж типа истории
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              story.isSeed
                                  ? Colors.green[100]
                                  : story.isBranch
                                  ? Colors.blue[100]
                                  : Colors.orange[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Text(
                          story.isSeed
                              ? '🌱 Семя'
                              : story.isBranch
                              ? '🌿 Ветка'
                              : '↪️ Ответ',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 20,
              ), // Место снизу, как запрашивал пользователь
            ],
          ),
        );
      },
    );
  }

  Widget _buildAuthorInfo(Story story) {
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
                    borderRadius: BorderRadius.circular(20),
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

    return Column(
      children: [
        // Индикатор страницы
        if (_currentStories.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _currentStories.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index ? neoBlack : Colors.grey[300],
                  ),
                ),
              ),
            ),
          ),

        // Карусель историй
        Expanded(
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
        ),

        // Кнопки навигации
        if (_currentStories.length > 1)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Кнопка "Назад"
                ElevatedButton.icon(
                  onPressed:
                      _currentPage > 0
                          ? () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                          : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Назад'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _currentPage > 0 ? neoBlack : Colors.grey[300],
                    foregroundColor:
                        _currentPage > 0 ? Colors.white : Colors.grey,
                  ),
                ),

                // Индикатор страницы
                Text(
                  '${_currentPage + 1} / ${_currentStories.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                // Кнопка "Вперед"
                ElevatedButton.icon(
                  onPressed:
                      _currentPage < _currentStories.length - 1
                          ? () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                          : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Вперед'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _currentPage < _currentStories.length - 1
                            ? neoBlack
                            : Colors.grey[300],
                    foregroundColor:
                        _currentPage < _currentStories.length - 1
                            ? Colors.white
                            : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
      ],
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              indicatorColor: neoBlack,
              indicatorWeight: 3,
              indicatorPadding: const EdgeInsets.symmetric(horizontal: 16),
              tabs: const [Tab(text: '🌱 Семена'), Tab(text: '🌿 Ветки')],
            ),
          ),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: const PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () => context.go('/addStory'),
      //   backgroundColor: neoBlack,
      //   foregroundColor: Colors.white,
      //   child: const Icon(Icons.add, size: 28),
      // ),
      body: _isLoading ? _buildLoadingState() : _buildContent(),
    );
  }
}
