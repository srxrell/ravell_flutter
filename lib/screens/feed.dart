import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:readreels/models/story.dart';
import 'package:readreels/screens/story_detail.dart';
import 'package:readreels/widgets/heart_animation.dart';
import 'package:readreels/services/story_service.dart' as st;
import 'package:readreels/widgets/bottom_nav_bar_liquid.dart';
import 'package:readreels/widgets/neowidgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:readreels/widgets/early_access_bottom.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:readreels/theme.dart';
import 'package:readreels/widgets/comments_bottom_sheet.dart';
import 'package:readreels/widgets/expandable_story_content.dart';
import 'package:showcaseview/showcaseview.dart';

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
  bool _isRefreshing = false;

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

  // Showcase keys
  final GlobalKey _homeKey = GlobalKey();
  final GlobalKey _addKey = GlobalKey();
  final GlobalKey _profileKey = GlobalKey();
  final GlobalKey _replyKey = GlobalKey();
  final GlobalKey _avatarKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _seedsKey = GlobalKey();
  final GlobalKey _branchesKey = GlobalKey();

  double _getFontScale() {
    return _fontScale;
  }

  double _getTitleFontScale() {
    return _titleFontScale;
  }

  Future<void> _loadFontSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _fontScale = prefs.getDouble('story_font_scale') ?? 1.0;
        _titleFontScale = prefs.getDouble('title_font_scale') ?? 1.0;
      });
    }
  }

  // Сортировка
  String _sortOption = 'random'; // 'random', 'newest', 'oldest', 'popular'

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

  double _fontScale = 1.0;
  double _titleFontScale = 1.0;

  Future<void> _saveStoriesLocally(List<Story> stories, StoryType type) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = stories.map((s) => s.toJson()).toList(); // Story должен иметь toJson()
    prefs.setString(type.toString(), json.encode(jsonList));
  }

  Future<List<Story>> _loadStoriesFromLocal(StoryType type) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(type.toString());
    if (data == null) return [];
    final List decoded = json.decode(data);
    return decoded.map((e) => Story.fromJson(e)).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadFontSettings();
    _checkAuthStatusAndFetch();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showCaseIfNeeded();
    });
  }

  Future<void> _showCaseIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final bool showcased = prefs.getBool('feed_showcased') ?? false;
    if (!showcased) {
      if (mounted) {
        ShowCaseWidget.of(context).startShowCase([
          _searchKey,
          _seedsKey,
          _branchesKey,
          _avatarKey,
          _replyKey,
          _addKey,
          _profileKey,
        ]);
        await prefs.setBool('feed_showcased', true);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        Future.delayed(Duration.zero, () => context.go('/auth-check'));
      }
      return;
    }

    await _fetchCurrentTabStories();
  }

  Future<void> _fetchCurrentTabStories() async {
  setState(() {
    _isLoading = true;
    _hasError = false;
    _errorMessage = '';
  });

  try {
    // сначала пробуем загрузить из локального хранилища
    List<Story> localStories = await _loadStoriesFromLocal(_currentStoryType);

    if (localStories.isNotEmpty) {
      setState(() {
        switch (_currentStoryType) {
          case StoryType.seeds:
            seeds = localStories;
            break;
          case StoryType.branches:
            branches = localStories;
            break;
          case StoryType.all:
            allStories = localStories;
            break;
        }
        _isLoading = false;
      });
    }

    // потом обновляем с сервера
    List<Story> fetched;
    switch (_currentStoryType) {
      case StoryType.seeds:
        fetched = await _storyService.getSeeds();
        seeds = fetched;
        break;
      case StoryType.branches:
        fetched = await _storyService.getBranches();
        branches = fetched;
        break;
      case StoryType.all:
        fetched = await _storyService.getStories();
        allStories = fetched;
        break;
    }

    // сохраняем в локальное хранилище
    await _saveStoriesLocally(fetched, _currentStoryType);

    // лайки и сортировка
    likeCounts.clear();
    likeStatuses.clear();
    for (var story in _currentStories) {
      likeCounts[story.id] = story.likesCount;
      if (currentUserId != null) {
        likeStatuses[story.id] =
            await _storyService.isStoryLiked(story.id, currentUserId!);
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  } catch (e) {
    if (!mounted) return;
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

  void _applySorting() {
    switch (_sortOption) {
      case 'newest':
        _currentStories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'oldest':
        _currentStories.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'popular':
        _currentStories.sort((a, b) => b.likesCount.compareTo(a.likesCount));
        break;
      case 'random':
      default:
        _currentStories.shuffle(Random());
        break;
    }
  }

  Future<void> _refreshFeed() async {
    if (_isRefreshing) return;

    _isRefreshing = true;

    setState(() {
      _isLoading = true;
    });

    await _fetchCurrentTabStories();

    _isRefreshing = false;
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

  Widget _buildStoryCard(Story story, int index) {
    final isLiked = likeStatuses[story.id] ?? false;
    final currentLikeCount = likeCounts[story.id] ?? 0;

    return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (context) => StoryDetailPage(
                          story: story,
                          fromProfile:
                              false, // 🟢 Не из профиля - онлайн данные
                        ),
                  ),
                );
              },
              onDoubleTapDown: (details) {
                _handleLike(story, isDoubleTap: true);
                setState(() {
                  tapPosition = details.localPosition;
                });
              },
              child: Container(
                margin: const EdgeInsets.only(top: 15, bottom: 20),
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
                              fontSize: 26 * _getTitleFontScale(),
                              color: Colors.black,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 16),

                          // РЯД: Аватар + Имя пользователя
                          Row(
                            children: [
                              _wrapWithShowcase(
                                showcaseKey: index == 0 ? _avatarKey : null,
                                description:
                                    'Нажмите на аватар, чтобы перейти в профиль автора',
                                child: _buildAuthorAvatar(story),
                              ),

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
                                            story.resolvedUsername,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 18 * _getFontScale(),
                                              color: Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 4),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Контент истории
                          ExpandableStoryContent(
                            content: story.content,
                          ),

                          const SizedBox(height: 20),

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
                                          style: TextStyle(
                                            fontSize: 12 * _getFontScale(),
                                          ),
                                        ),
                                        backgroundColor: Colors.blue[50],
                                        visualDensity: VisualDensity.compact,
                                      );
                                    }).toList(),
                              ),
                            ),

                          // Действия (кнопки лайка и ответа)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Кнопка ответить
                                if (!story.isReply)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                    ), // отступы слева и справа
                                    child: _wrapWithShowcase(
                                      showcaseKey:
                                          index == 0 ? _replyKey : null,
                                      description:
                                          'Отвечай на историю своим развитием сюжета!',
                                      child: SizedBox(
                                        height: 70,
                                        child: NeoIconButton(
                                          onPressed: () {
                                            if (currentUserId == null) {
                                              if (mounted) {
                                                context.go('/auth-check');
                                              }
                                              return;
                                            }
                                            context.push(
                                              '/addStory',
                                              extra: {
                                                'replyTo': story.id,
                                                'parentTitle': story.title,
                                              },
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.reply,
                                            size: 18,
                                          ),
                                          child: Text(
                                            ' Ответить | ${_getReplyText(story.repliesCount)}',
                                            style: TextStyle(
                                              fontSize: 14 * _getFontScale(),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
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
            );
  }

  // Вынес аватар в отдельный виджет для чистоты кода
  Widget _buildAuthorAvatar(Story story) {
    print('🔵 FEED Avatar URL: ${story.resolvedAvatarUrl}');
    print('🔵 FEED Username: ${story.username}');
    print('🔵 FEED Story ID: ${story.id}');
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
            if (story.resolvedAvatarUrl != null &&
                story.resolvedAvatarUrl!.isNotEmpty)
              ClipOval(
                child: CachedNetworkImage(
                  imageUrl: story.resolvedAvatarUrl!,
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                  httpHeaders: const {'User-Agent': 'FlutterApp/1.0'},
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

            // Звездочка раннего доступа
            if (story.isEarly)
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => EarlyAccessSheet.show(context),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 14,
                    ),
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,

        toolbarHeight: 100,
        elevation: 0,
        surfaceTintColor: neoBackground,
        centerTitle: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: SvgPicture.asset("assets/icons/logo.svg", width: 60, height: 60),
        actions: [
          Showcase(
            key: _searchKey,
            description: 'Поиск интересных историй',
            child: GestureDetector(
              onTap: () => context.push("/search"),
              child: SvgPicture.asset(
                "assets/icons/search.svg",
                width: 60,
                height: 60,
              ),
            ),
          ),
          // SizedBox(width: 4),
          // GestureDetector(
          //   onTap: () => context.push("/notifications"),
          //   child: SvgPicture.asset(
          //     "assets/icons/notification.svg",
          //     width: 60,
          //     height: 60,
          //   ),
          // ),
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
                    child: Showcase(
                      key: _seedsKey,
                      description: 'Основные истории сообщества',
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
                  ),

                  // Правая кнопка - скругление справа, нет слева
                  Expanded(
                    child: Showcase(
                      key: _branchesKey,
                      description: 'Разветвления историй от других авторов',
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(
        currentRoute: GoRouterState.of(context).uri.toString(),
        homeKey: _homeKey,
        addKey: _addKey,
        profileKey: _profileKey,
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : _currentStories.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _refreshFeed,
                    child: Column(
                      children: [
                        // Кнопка сортировки
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  setState(() {
                                    _sortOption = value;
                                    _applySorting();
                                  });
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'random',
                                    child: Text('Случайно'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'newest',
                                    child: Text('Сначала новые'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'oldest',
                                    child: Text('Сначала старые'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'popular',
                                    child: Text('Популярные'),
                                  ),
                                ],
                                child: Row(
                                  children: [
                                    const Icon(Icons.sort),
                                    const SizedBox(width: 4),
                                    Text(
                                      _sortOption == 'random' ? 'Случайно' :
                                      _sortOption == 'newest' ? 'Сначала новые' :
                                      _sortOption == 'oldest' ? 'Сначала старые' :
                                      'Популярные',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Список историй
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _currentStories.length,
                            itemBuilder: (context, index) {
                              return _buildStoryCard(_currentStories[index], index);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }


  Widget _wrapWithShowcase({
    required GlobalKey? showcaseKey,
    required String description,
    required Widget child,
  }) {
    if (showcaseKey == null) return child;
    return Showcase(
      key: showcaseKey,
      description: description,
      child: child,
    );
  }
}
