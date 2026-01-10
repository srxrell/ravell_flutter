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
import 'package:readreels/managers/settings_manager.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:readreels/screens/settings_screen.dart';
import 'package:readreels/theme.dart';
import 'package:readreels/widgets/neowidgets.dart';
import 'package:http/http.dart' as http;
import 'package:readreels/widgets/early_access_bottom.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

// 🟢 ИСПРАВЛЕННЫЙ StoryCard с логикой выбора источника данных
class StoryCard extends StatelessWidget {
  final Story story;
  final bool isReplyCard;
  final void Function()? onStoryUpdated;
  final bool useLocalData; // 🟢 НОВЫЙ ПАРАМЕТР

  const StoryCard({
    super.key,
    required this.story,
    required this.isReplyCard,
    this.onStoryUpdated,
    this.useLocalData = false, // По умолчанию используем онлайн данные
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
    final settings = context.watch<SettingsManager>();
    final isDarkBg = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([_getAvatarUrl(), _getUsername()]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
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
                    fontSize: 32 * settings.titleFontScale,
                    color: isDarkBg ? Colors.white : Colors.black,
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
                  fontSize: isReplyCard ? 20 * settings.titleFontScale : 32 * settings.titleFontScale,
                  color: isDarkBg ? Colors.white : Colors.black,
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
                          _buildAvatar(avatarUrl, username),
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
                          onTap: () => _navigateToUserProfile(context, story.userId),
                          child: Text(
                            username,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: isDarkBg ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              _formatDate(story.createdAt),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.visibility_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              '${story.views}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.share_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              '${story.shares}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
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
                child: MarkdownBody(
                  data: story.content,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      fontSize: 16 * settings.fontScale,
                      height: settings.lineHeight,
                      color: isDarkBg ? Colors.white70 : Colors.black87,
                    ),
                    h1: TextStyle(fontSize: 32 * settings.titleFontScale, color: isDarkBg ? Colors.white : Colors.black),
                    h2: TextStyle(fontSize: 28 * settings.titleFontScale, color: isDarkBg ? Colors.white : Colors.black),
                    h3: TextStyle(fontSize: 24 * settings.titleFontScale, color: isDarkBg ? Colors.white : Colors.black),
                  ),
                  onTapLink: (text, href, title) {
                    if (href != null) {
                      launchUrl(Uri.parse(href));
                    }
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Хештеги
              if (story.hashtags.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: story.hashtags.map((hashtag) {
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
        color: Colors.blue, // Placeholder color, adjust as needed
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
  late Story _currentStory; // 🟢 Локальная копия истории для обновлений
  List<Story> _replies = [];
  bool _isLoading = true;
  bool _hasError = false;
  int _totalWords = 0;
  int _totalRepliesWords = 0;



  Future<void> _shareStory() async {
    final String shareUrl = 'https://ravell.wasmer.app/story/${_currentStory.id}';
    
    // 1. Сначала открываем нативный диалог шаринга (не блокируем UI)
    Share.share(
      '${_currentStory.title}\n\nЧитай продолжение в ReadReels: $shareUrl',
      subject: _currentStory.title,
    );

    // 2. В фоне уведомляем бэкенд
    try {
      debugPrint('📡 Notifying backend about share for story ${_currentStory.id}...');
      await _storyService.shareStory(_currentStory.id);
      debugPrint('✅ Backend notified about share.');
      _fetchReplies(); // Обновляем данные (включая счетчик репостов)
    } catch (e) {
      debugPrint('⚠️ Error updating share count on backend: $e');
    }
  }

  void _openReadingSettings() {

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Consumer<SettingsManager>(
        builder: (context, settings, child) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Настройки чтения", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // Размер заголовка
                _buildSettingSlider(
                  label: "Размер заголовка",
                  value: settings.titleFontScale,
                  min: 0.8, max: 2.0,
                  onChanged: (v) => settings.setTitleFontScale(v),
                ),
                
                // Размер текста
                _buildSettingSlider(
                  label: "Размер текста",
                  value: settings.fontScale,
                  min: 0.8, max: 2.0,
                  onChanged: (v) => settings.setFontScale(v),
                ),

                // Межстрочный интервал
                _buildSettingSlider(
                  label: "Интервал строк",
                  value: settings.lineHeight,
                  min: 1.0, max: 2.5,
                  onChanged: (v) => settings.setLineHeight(v),
                ),

                const SizedBox(height: 10),
                const Text("Цвет фона", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                
                // Выбор цвета фона
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _colorOption(settings, const Color(0xFFF5F5F5), "Light"),
                    _colorOption(settings, const Color(0xFFF5E6D3), "Sepia"),
                    _colorOption(settings, const Color(0xFF1A1A1A), "Dark"),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _buildSettingSlider({required String label, required double value, required double min, required double max, required Function(double) onChanged}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      Slider(
        value: value,
        min: min,
        max: max,
        activeColor: Colors.black,
        onChanged: onChanged,
      ),
    ],
  );
}

Widget _colorOption(SettingsManager settings, Color color, String name) {
  bool isSelected = settings.readerBackground == color;
  return GestureDetector(
    onTap: () {
      setState(() {
        settings.setReaderBackground(color);
      });
    },
    child: Column(
      children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: isSelected ? Colors.blue : Colors.grey, width: isSelected ? 3 : 1),
          ),
        ),
        Text(name, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))
      ],
    ),
  );
}

  @override
  void initState() {
    super.initState();
    _currentStory = widget.story; // Инициализируем из виджета
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
    ).catchError((e) => print('Streak update error: $e'));

    // 2. грузим актуальные данные истории (включая просмотры)
    try {
      final updatedStory = await _storyService.getStory(widget.story.id);
      if (mounted) {
        setState(() {
          _currentStory = updatedStory;
          _calculateWordCounts(); // Пересчитываем слова, если нужно
        });
      }
    } catch (e) {
      debugPrint('Error fetching updated story: $e');
    }
  }

  void _calculateWordCounts() {
    _totalWords = _currentStory.content.split(RegExp(r'\s+')).length;
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

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // Загружаем также актуальные данные самой истории (просмотры, лайки)
      // Оборачиваем в отдельный try-catch, чтобы ошибка здесь не сломала всю страницу
      try {
        final updatedStory = await _storyService.getStory(widget.story.id);
        if (mounted) {
          setState(() {
            _currentStory = updatedStory;
            _calculateWordCounts();
          });
        }
      } catch (e) {
        debugPrint('⚠️ Ошибка при обновлении данных истории: $e');
        // Не ставим _hasError = true, так как ответы и текущая история у нас уже есть
      }
    } catch (e) {
      debugPrint('❌ Ошибка загрузки ответов: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsManager>(context);
    final bool isDark = ThemeData.estimateBrightnessForColor(Color(settings.backgroundColor)) == Brightness.dark;
    return Scaffold(
     backgroundColor: Color(settings.backgroundColor),
      appBar: AppBar(
        backgroundColor: Color(settings.backgroundColor),
        automaticallyImplyLeading: false,
        toolbarHeight: 100,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
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
            onTap: _shareStory,
            child: SvgPicture.asset("assets/icons/share.svg", width: 60, height: 60),
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
    final settings = Provider.of<SettingsManager>(context);
    final isDarkBg = false;
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
                    story: _currentStory,
                    isReplyCard: false,
                    onStoryUpdated: _fetchReplies,
                    useLocalData: widget.fromProfile,
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
                  '${settings.translate('replies')} (${_replies.length})',
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
                    Text(settings.translate('error_loading_replies')),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _fetchReplies,
                      child: Text(settings.translate('retry')),
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
                    Text(settings.translate('no_replies')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReplyButton() {
    final settings = Provider.of<SettingsManager>(context);
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
              SnackBar(
                content: Text(settings.translate('only_for_registered')),
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
        child: Text(settings.translate('reply')),
      ),
    );
  }


}
