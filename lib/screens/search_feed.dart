import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:readreels/models/story.dart';
import 'package:readreels/services/auth_service.dart';
import 'package:readreels/widgets/comments_bottom_sheet.dart';
import 'package:readreels/widgets/expandable_story_content.dart';
import 'package:readreels/widgets/heart_animation.dart';
import 'package:readreels/services/story_service.dart' as st;
import 'package:readreels/widgets/bottom_nav_bar_liquid.dart'; // ЗАМЕНА: CommentsBottomSheet на RepliesBottomSheet
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:readreels/services/subscription_service.dart';
import 'package:readreels/theme.dart'; // Добавляем импорт темы

class SearchFeed extends StatefulWidget {
  final List<Story> stories;
  final int initialIndex;

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
  Map<int, int> likeCounts = {};
  Offset tapPosition = Offset.zero;
  int? currentUserId;
  late PageController _pageController;
  int _currentPage = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _currentPage = widget.initialIndex;
    _getUserIdAndFetchInitialData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _getUserIdAndFetchInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUserId = prefs.getInt('user_id');
    final guestId = prefs.getInt('GUEST_ID');

    if (storedUserId != null) {
      currentUserId = storedUserId;
    } else if (guestId != null) {
      currentUserId = guestId;
    }

    debugPrint('currentUserId: $currentUserId');
    await _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    if (mounted) {
      setState(() => _isLoading = true);

      // Инициализируем счетчики лайков
      for (var story in stories) {
        likeCounts[story.id] = story.likesCount;
      }

      // Загружаем статусы лайков
      await _fetchLikeStatuses();

      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchLikeStatuses() async {
    if (currentUserId == null) return;

    final Map<int, bool> newLikeStatuses = {};
    for (var story in stories) {
      try {
        final isLiked = await _storyService.isStoryLiked(
          story.id,
          currentUserId!,
        );
        newLikeStatuses[story.id] = isLiked;
      } catch (e) {
        debugPrint('Error fetching like status for story ${story.id}: $e');
        newLikeStatuses[story.id] = false;
      }
    }

    if (mounted) {
      setState(() => likeStatuses = newLikeStatuses);
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

  Future<void> _handleNotInterested(Story story) async {
    try {
      await _storyService.markStoryAsNotInterested(story.id);
      setState(() {
        stories.removeWhere((s) => s.id == story.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('История "${story.title}" скрыта'),
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
    bool isLiked = false,
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

  Widget _buildStoryContent(Story story, int index) {
    final isLiked = likeStatuses[story.id] ?? false;
    final currentLikeCount = likeCounts[story.id] ?? 0;

    return GestureDetector(
      onDoubleTapDown: (details) {
        _handleLike(story, isDoubleTap: true);
        setState(() {
          tapPosition = details.localPosition;
        });
      },
      child: Container(
        color: Colors.white,
        child: Stack(
          children: [
            // Контент истории
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
                    top: 60,
                    left: 20,
                    right: 80,
                    bottom: 120,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Информация об авторе и заголовок
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: neoBlack, width: 2),
                              color: Colors.grey[200],
                            ),
                            child:
                                story.avatarUrl != null &&
                                        story.avatarUrl!.isNotEmpty
                                    ? ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: story.avatarUrl!,
                                        fit: BoxFit.cover,
                                        placeholder:
                                            (context, url) =>
                                                const CircularProgressIndicator(),
                                        errorWidget:
                                            (context, url, error) =>
                                                const Icon(Icons.person),
                                      ),
                                    )
                                    : const Icon(Icons.person, size: 20),
                          ),
                          const SizedBox(width: 12),
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
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
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

                      Text(
                        story.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          child: ExpandableStoryContent(content: story.content),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Боковые кнопки действий
            Positioned(
              right: 10,
              bottom: 150,
              child: SizedBox(
                width: 70,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildAuthorInfo(story),
                    const SizedBox(height: 20),
                    _buildActionButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : Colors.black,
                        size: 30,
                      ),
                      count: currentLikeCount,
                      onPressed: () => _handleLike(story),
                      isLiked: isLiked,
                    ),
                    const SizedBox(height: 20),
                    _buildActionButton(
                      icon: const Icon(
                        Icons.reply,
                        size: 30,
                        color: Colors.black,
                      ),
                      count: story.replyCount,
                      onPressed: () async {
                        await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder:
                              (context) =>
                                  RepliesBottomSheet(parentStory: story),
                        );
                        await _fetchInitialData();
                      },
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => _showStoryOptions(context, story),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: neoBlack, width: 2),
                        ),
                        child: const Icon(Icons.more_vert, size: 24),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Бейдж типа истории
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      ? '🌱'
                      : story.isBranch
                      ? '🌿'
                      : '↪️',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text(
            'По вашему запросу\nничего не найдено',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.go('/search'),
            style: ElevatedButton.styleFrom(
              backgroundColor: neoBlack,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Вернуться к поиску',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            'Загружаем результаты поиска...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (stories.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Индикатор текущей позиции
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_currentPage + 1} из ${stories.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),

        // Карусель историй (вертикальная прокрутка)
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: stories.length,
            scrollDirection: Axis.vertical,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              return _buildStoryContent(stories[index], index);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Найдено: ${stories.length}',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: const PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(),
      body: _isLoading ? _buildLoadingState() : _buildContent(),
    );
  }
}
