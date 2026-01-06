import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:readreels/models/story.dart';
import 'package:readreels/screens/add_story_screen.dart';
import 'package:readreels/services/auth_service.dart';
import 'package:readreels/managers/achievement_manager.dart';
import 'package:readreels/services/comment_service.dart';
import 'package:readreels/services/story_service.dart' as st;
import 'package:readreels/theme.dart';
import 'package:readreels/widgets/neowidgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:readreels/widgets/early_access_bottom.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

// 🟢 ИСПРАВЛЕННЫЙ StoryCard с логикой выбора источника данных
class StoryCard extends StatelessWidget {
  final Story story;
  final bool isReplyCard;
  final void Function()? onStoryUpdated;
  final bool useLocalData; // 🟢 НОВЫЙ ПАРАМЕТР
  final double titleFontScale; // New parameter
  final double fontScale;
  final double titleScale;
  final double lineHeight;
  final bool isDarkBackground;

  const StoryCard({
    super.key,
    required this.story,
    required this.isReplyCard,
    this.onStoryUpdated,
    this.useLocalData = false, // По умолчанию используем онлайн данные
    this.titleFontScale = 1.0, // Default value
    this.fontScale = 1.0,
  this.titleScale = 1.0,
  this.lineHeight = 1.5,
  this.isDarkBackground = false,
  });

  // 🟢 УНИВЕРСАЛЬНЫЙ МЕТОД ДЛЯ ПОЛУЧЕНИЯ АВАТАРА
  Future<String?> _getAvatarUrl() async {
     // Вспомогательная функция для очистки
    String? clean(String? s) {
      if (s == null) return null;
      final trimmed = s.replaceAll(RegExp(r'\s+'), '');
      if (trimmed.isEmpty || trimmed.contains('Useragent')) return null;
      if (s.contains('User agent')) return null;
      return trimmed;
    }

    String resolve(String path) {
      if (path.startsWith('http')) return path;
      final String cleanPath = path.startsWith('/') ? path : '/$path';
      return 'https://ravell-backend-1.onrender.com$cleanPath';
    }

    if (useLocalData) {
      // 🟢 ИСПОЛЬЗУЕМ ДАННЫЕ ИЗ SHAREDPREFERENCES
      try {
        final prefs = await SharedPreferences.getInstance();
        final avatarUrl = clean(prefs.getString('avatar_url'));

        if (avatarUrl != null) {
          return resolve(avatarUrl);
        }
      } catch (e) {
        print('Error getting avatar from SharedPreferences: $e');
      }
    }

    // 🟢 ИНАЧЕ ИСПОЛЬЗУЕМ ОНЛАЙН ДАННЫЕ ИЗ STORY
    // 1. Пробуем новый формат: user -> profile -> avatar
    if (story.user != null && story.user is Map) {
      final userMap = story.user as Map;
      if (userMap['profile'] != null &&
          userMap['profile'] is Map) {
        final profile = userMap['profile'] as Map;
        final avatar = clean(profile['avatar'] as String?);
        if (avatar != null) {
          return resolve(avatar);
        }
      }

      if (userMap['avatar'] != null) {
        final avatar = clean(userMap['avatar'] as String?);
        if (avatar != null) {
          return resolve(avatar);
        }
      }
    }

    // 2. Пробуем поле avatarUrl
    final cleanAvatarUrl = clean(story.avatarUrl);
    if (cleanAvatarUrl != null) {
      return resolve(cleanAvatarUrl);
    }

    // 3. Пробуем authorAvatar
    final cleanAuthorAvatar = clean(story.authorAvatar);
    if (cleanAuthorAvatar != null) {
      return resolve(cleanAuthorAvatar);
    }

    return null;
  }

  // 🟢 УНИВЕРСАЛЬНЫЙ МЕТОД ДЛЯ ПОЛУЧЕНИЯ ИМЕНИ ПОЛЬЗОВАТЕЛЯ
  Future<String> _getUsername() async {
    if (useLocalData) {
      // 🟢 ИСПОЛЬЗУЕМ ДАННЫЕ ИЗ SHAREDPREFERENCES
      try {
        final prefs = await SharedPreferences.getInstance();
        final username = prefs.getString('username');
        if (username != null && username.isNotEmpty) {
          return username;
        }
      } catch (e) {
        print('Error getting username from SharedPreferences: $e');
      }
    }

    // 🟢 ИНАЧЕ ИСПОЛЬЗУЕМ ОНЛАЙН ДАННЫЕ
    // 1. Пробуем получить из user -> username
    if (story.user != null && story.user is Map<String, dynamic>) {
      final userMap = story.user as Map<String, dynamic>;
      final username = userMap['username'] as String?;
      if (username != null && username.isNotEmpty) {
        return username;
      }
    }

    // 2. Пробуем поле username
    if (story.resolvedUsername.isNotEmpty) {
      return story.resolvedUsername;
    }

    // 3. Fallback
    return 'Пользователь #${story.userId}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([_getAvatarUrl(), _getUsername()]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: isReplyCard ? const EdgeInsets.all(16.0) : EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Заголовок истории
                Text(
                  story.title,
                  style: GoogleFonts.russoOne(
                    fontSize: 32,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                _buildLoadingUserInfo(),
                const SizedBox(height: 16),
                _buildLoadingContent(),
              ],
            ),
          );
        }

        final avatarUrl = snapshot.data?[0] as String?;
        final username = snapshot.data?[1] as String? ?? 'Пользователь';

        return Container(
          decoration:
              isReplyCard
                  ? BoxDecoration(
                    border: Border.all(color: Colors.black, width: 2.0),
                    borderRadius: BorderRadius.circular(16.0),
                  )
                  : null,
          padding: isReplyCard ? const EdgeInsets.all(16.0) : EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок истории
              Text(
                story.title,
                style: GoogleFonts.russoOne(
  fontSize: isReplyCard ? 20 * titleScale : 32 * titleScale ,
  color: isDarkBackground ? Colors.white : Colors.black,
),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  // 🟢 КЛИКАБЕЛЬНЫЙ АВАТАР
                  GestureDetector(
                    onTap: () => _navigateToUserProfile(context, story.userId),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                        color: Colors.grey[200],
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _buildAvatar(avatarUrl, username!),
                          if (story.isEarly)
                            Positioned(
                              top: -8,
                              right: -8,
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
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🟢 КЛИКАБЕЛЬНЫЙ ЮЗЕРНЕЙМ
                        GestureDetector(
                          onTap:
                              () =>
                                  _navigateToUserProfile(context, story.userId),
                          child: Text(
                            username,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: isDarkBackground ? Colors.white : Colors.black,

                            ),
                          ),
                        ),
                        Text(
                          _formatDate(story.createdAt),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 🟢 ПОЛНЫЙ ТЕКСТ ИСТОРИИ
              Container(
                width: double.infinity,
                child: Container(
  width: double.infinity,
  child: MarkdownBody(
    data: story.content,
    styleSheet: MarkdownStyleSheet(
  p: TextStyle(
    fontSize: 16 * fontScale,
    height: lineHeight,
    color: isDarkBackground ? Colors.white70 : Colors.black87,
  ),
  h1: TextStyle(fontSize: 32 * titleScale),
  h2: TextStyle(fontSize: 28 * titleScale),
  h3: TextStyle(fontSize: 24 * titleScale),
),
    onTapLink: (text, href, title) {
      if (href != null) {
        // открытие ссылок
        launchUrl(Uri.parse(href));
      }
    },
  ),
)
              ),

              const SizedBox(height: 12),

              // Хештеги
              if (story.hashtags.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children:
                      story.hashtags.map((hashtag) {
                        return Chip(
                          label: Text('#${hashtag.name}'),
                        );
                      }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  // 🟢 МЕТОД ДЛЯ АВАТАРА
  Widget _buildAvatar(String? avatarUrl, String username) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          httpHeaders: const {
            'User-Agent': 'FlutterApp/1.0',
          },
          placeholder:
              (context, url) => Container(
                color: Colors.grey[200],
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                ),
              ),
          errorWidget:
              (context, url, error) => _buildAvatarPlaceholder(username),
        ),
      );
    }

    return _buildAvatarPlaceholder(username);
  }

  Widget _buildAvatarPlaceholder(String username) {
    final placeholderText =
        username.isNotEmpty ? username[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: neoAccent,
      ),
      child: Center(
        child: Text(
          placeholderText,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  // 🟢 ЗАГРУЗОЧНЫЙ ИНТЕРФЕЙС
  Widget _buildLoadingUserInfo() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[200],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 100, height: 16, color: Colors.grey[200]),
              const SizedBox(height: 4),
              Container(width: 80, height: 12, color: Colors.grey[200]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: double.infinity, height: 12, color: Colors.grey[200]),
        const SizedBox(height: 8),
        Container(width: double.infinity, height: 12, color: Colors.grey[200]),
        const SizedBox(height: 8),
        Container(width: 200, height: 12, color: Colors.grey[200]),
      ],
    );
  }

  // 🟢 МЕТОД ДЛЯ ПЕРЕХОДА НА ПРОФИЛЬ
  void _navigateToUserProfile(BuildContext context, int userId) {
    if (userId == 0) return;
    try {
      context.push('/profile/$userId');
    } catch (e) {
      print('Navigation error: $e');
    }
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
  final bool fromProfile; // 🟢 НОВЫЙ ПАРАМЕТР

  const StoryDetailPage({
    super.key,
    required this.story,
    this.fromProfile = false, // По умолчанию не из профиля
  });

  @override
  State<StoryDetailPage> createState() => _StoryDetailPageState();
}

class _StoryDetailPageState extends State<StoryDetailPage> {
  final st.StoryService _storyService = st.StoryService();
  final StoryReplyService _replyService = StoryReplyService();
  List<Story> _replies = [];
  bool _isLoading = true;
  bool _hasError = false;
  int _totalWords = 0;
  int _totalRepliesWords = 0;
  double _currentTitleFontScale = 1.0; // New variable
   double _fontScale = 1.0;
  double _titleScale = 1.0;
  double _lineHeight = 1.5;
  int _backgroundIndex = 0;

  final List<Color> _backgrounds = [
    const Color(0xFFFFFFFF), // светлый
    const Color(0xFFF4ECD8), // сепия
    const Color(0xFF121212), // тёмный
  ];


  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontScale = prefs.getDouble('story_font_scale') ?? 1.0;
      _titleScale = prefs.getDouble('title_font_scale') ?? 1.0;
      _lineHeight = prefs.getDouble('story_line_height') ?? 1.5;
      _backgroundIndex = prefs.getInt('story_background') ?? 0;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is double) await prefs.setDouble(key, value);
    if (value is int) await prefs.setInt(key, value);
    setState(() {});
  }

  void _openReadingSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Настройки чтения',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  const Text('Размер текста'),
                  Slider(
                    value: _fontScale,
                    min: 0.8,
                    max: 1.6,
                    divisions: 8,
                    onChanged: (v) async {
                      await _saveSetting('story_font_scale', v);
                      setModal(() => _fontScale = v);
                    },
                  ),

                  const Text('Размер заголовков'),
                  Slider(
                    value: _titleScale,
                    min: 0.8,
                    max: 1.6,
                    divisions: 8,
                    onChanged: (v) async {
                      await _saveSetting('title_font_scale', v);
                      setModal(() => _titleScale = v);
                    },
                  ),

                  const Text('Межстрочный интервал'),
                  Slider(
                    value: _lineHeight,
                    min: 1.2,
                    max: 2.0,
                    divisions: 8,
                    onChanged: (v) async {
                      await _saveSetting('story_line_height', v);
                      setModal(() => _lineHeight = v);
                    },
                  ),

                  const SizedBox(height: 12),
                  const Text('Фон'),

                  Row(
                    children: List.generate(_backgrounds.length, (i) {
                      return GestureDetector(
                        onTap: () async {
                          await _saveSetting('story_background', i);
                          setModal(() => _backgroundIndex = i);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 12, top: 8),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _backgrounds[i],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: i == _backgroundIndex
                                  ? Colors.black
                                  : Colors.grey,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadSettings(); // Call a new method to load settings
    _fetchReplies();
    _incrementReadCounter();
    
    _calculateWordCounts();
    _makeUpdateStreak();
    
  }

  void _incrementReadCounter() async {
  // Пользователь просто открыл сториз, без ответов и своих постов
  await AchievementManager.incrementReadStories();
}

  Future<void> _makeUpdateStreak() async {
    final token = await AuthService().getAccessToken();

    // 1. обновляем стрейк
    await http.post(
      Uri.parse('https://ravell-backend-1.onrender.com/streak/update'),
      headers: {'Authorization': 'Bearer $token'},
    );

    // 2. грузим историю
    final res = await http.get(
      Uri.parse(
        'https://ravell-backend-1.onrender.com/stories/${widget.story.id}',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  void _calculateWordCounts() {
    _totalWords = widget.story.content.split(RegExp(r'\s+')).length;
    _totalRepliesWords = _replies.fold(
      0,
      (sum, reply) => sum + reply.content.split(RegExp(r'\s+')).length,
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

      _totalRepliesWords = _replies.fold(
        0,
        (sum, reply) => sum + reply.content.split(RegExp(r'\s+')).length,
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
    final theme = Theme.of(context);
    final bgColor = _backgrounds[_backgroundIndex];
    final isDarkBg = bgColor.computeLuminance() < 0.3;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,

        toolbarHeight: 100,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        backgroundColor: bgColor,
        title: SvgPicture.asset("assets/icons/logo.svg", width: 60, height: 60),
        actions: [
          GestureDetector(
            onTap: () => context.push("/search"),
            child: SvgPicture.asset(
              "assets/icons/search.svg",
              width: 60,
              height: 60,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _openReadingSettings,
            child: SvgPicture.asset(
                  "assets/icons/settings.svg",
                  width: 60,
                  height: 60,
                ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final bgColor = _backgrounds[_backgroundIndex];
final isDarkBg = bgColor.computeLuminance() < 0.3;
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
                  // 🟢 КЛЮЧЕВОЕ ИЗМЕНЕНИЕ: Передаем fromProfile в StoryCard
                  StoryCard(
  story: widget.story,
  isReplyCard: false,
  onStoryUpdated: _fetchReplies,
  useLocalData: widget.fromProfile,
  fontScale: _fontScale,
  titleScale: _titleScale,
  lineHeight: _lineHeight,
  isDarkBackground: isDarkBg,
),
                  const SizedBox(height: 20),
                  _buildReplyButton(),
                ],
              ),
            ),
          ),

          // Заголовок ответов
          if (_replies.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Text(
                  'Ответы (${_replies.length})',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Список ответов
          if (_replies.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final reply = _replies[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: StoryCard(
                    story: reply,
                    isReplyCard: true,
                    onStoryUpdated: _fetchReplies,
                    useLocalData: false, // Ответы всегда загружаем онлайн
                  ),
                );
              }, childCount: _replies.length),
            ),

          // Состояния загрузки/ошибки
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_hasError)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Не удалось загрузить ответы'),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _fetchReplies,
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            ),
          if (!_isLoading && !_hasError && _replies.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.forum_outlined,
                      size: 64,
                      color: isDarkBg ? Colors.white : Colors.black,
                    ),
                    const SizedBox(height: 16),
                    Text('Пока нет ответов', style: TextStyle(color: isDarkBg ? Colors.white : Colors.black,)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReplyButton() {
  return Container(
    height: 75,
    width: MediaQuery.of(context).size.width,
    margin: const EdgeInsets.symmetric(horizontal: 16),
    child: NeoIconButton(
      onPressed: () async {
        final prefs = await SharedPreferences.getInstance();
        final isGuest = prefs.getInt('guest_id') != null;

        if (isGuest) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Только для зарегистрированных пользователей'),
            ),
          );
          return;
        }

        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (context) => AddStoryScreen(
                  parentTitle: widget.story.title,
                  replyToId: widget.story.id,
                ),
              ),
            )
            .then((_) => _fetchReplies());
      },
      icon: const Icon(Icons.reply),
      child: const Text('Ответить'),
    ),
  );
}


}
