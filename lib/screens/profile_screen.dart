import 'dart:convert';
import 'dart:io' if (dart.library.html) 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:readreels/screens/achievement_screen.dart';
import 'package:readreels/screens/story_detail.dart';
import 'package:readreels/services/draft_service.dart';
import 'package:readreels/screens/influencers_board.dart';
import 'package:readreels/screens/settings_screen.dart';
import 'package:readreels/screens/add_story.dart';
import 'package:readreels/screens/streak_screen.dart';
import 'package:readreels/screens/subscribers_list.dart';
import 'package:readreels/screens/user_story_feed_screen.dart';
import 'package:readreels/screens/logs_screen.dart';
import 'package:readreels/services/auth_service.dart';
import 'package:readreels/services/story_service.dart';
import 'package:readreels/theme.dart';
import 'package:readreels/widgets/early_access_bottom.dart';
import 'package:readreels/widgets/neowidgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:readreels/services/subscription_service.dart';
import 'edit_profile.dart';
import 'package:readreels/models/story.dart';
import 'package:readreels/widgets/bottom_nav_bar_liquid.dart' as p;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:readreels/models/draft_story.dart';
import 'package:readreels/screens/add_story.dart' as add;
import 'package:readreels/screens/create_draft_screeen.dart' as draftScreen;

class UserProfileScreen extends StatefulWidget {
  final int profileUserId;

  const UserProfileScreen({super.key, required this.profileUserId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final StoryService _storyService = StoryService();
  final AuthService _authService = AuthService();
  final DraftService _draftService = DraftService();
  late TabController _tabController;
  int? streakCount;

  int? currentUserId;
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  String? _errorMessage;
  List<DraftStory> _drafts = [];
  double _currentTitleFontScale = 1.0; // New variable
  String _sortOption = 'newest'; // 'newest', 'oldest', 'popular'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initProfile() async {
    setState(() {
      _isLoading = true;
      _profileData = null;
      _errorMessage = null;
    });

    final sp = await SharedPreferences.getInstance();
    currentUserId = sp.getInt('user_id');
    _currentTitleFontScale = sp.getDouble('title_font_scale') ?? 1.0; // Load title font scale
    
    // Only load cached avatar if it's potentially our own profile
    if (widget.profileUserId == currentUserId) {
      await _loadCachedAvatar();
    }
    
    _loadProfileData();
    _loadUserStreak(widget.profileUserId);
    await _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    try {
      final fetchedDrafts = await _draftService.getDrafts();
      if (mounted) {
        setState(() {
          _drafts = fetchedDrafts;
        });
      }
    } catch (e) {
      print('Error loading drafts: $e');
      // Optionally show a snackbar or error message
    }
  }

  String? _cleanUrl(dynamic value) {
  if (value == null) return null;

  final s = value
      .toString()
      .replaceAll(RegExp(r'\s+'), ''); // 💀 вырезаем \n \r пробелы табы

  if (s.isEmpty) return null;
  if (s.contains('User agent')) return null;

  return s;
}

  Future<void> _loadUserStreak(int userId) async {
    try {
      int? streak;
      final sp = await SharedPreferences.getInstance();
      final currentUserId = sp.getInt('user_id');

      if (userId == currentUserId) {
        // Своё — используем эндпоинт с токеном
        final token = await AuthService().getAccessToken();
        final res = await http.get(
          Uri.parse('https://ravell-backend-1.onrender.com/streak'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          print('🟢 DEBUG: StreakScreen data: $data');
          print("TOKEN: ${token}");
          streak = data['streak_count'] ?? 0;
        }
      } else {
        // Чужое — используем эндпоинт без токена
        final res = await http.get(
          Uri.parse(
            'https://ravell-backend-1.onrender.com/users/$userId/streak',
          ),
        );
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          print('🟢 DEBUG: StreakScreen data: $data');
          streak = data['streak_count'] ?? 0;
        }
      }

      if (mounted) {
        setState(() {
          streakCount = streak ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCachedAvatar() async {
    final cachedAvatar = await _authService.getCachedAvatar();

    if (cachedAvatar != null && mounted) {
      setState(() {
        _profileData ??= {'user_data': {}};
        _profileData!['user_data']['avatar'] = cachedAvatar;
      });
    }
  }

  Future<void> _deleteStory(int storyId) async {
    if (!mounted) return;

    print('======================================');
    print('🟡 UI DELETE REQUEST');
    print('🟨 storyId: $storyId');
    print('🟨 currentUserId: $currentUserId');
    print('======================================');

    Navigator.of(context).pop();

    setState(() {
      _isLoading = true;
    });

    try {
      print('🟦 Calling StoryService.deleteStory($storyId) ...');
      await _storyService.deleteStory(storyId);
      print('🟢 deleteStory() finished successfully');

      _showSnackbar('История успешно удалена.');
      await _loadProfileData();
    } catch (e) {
      print('🔴 UI ERROR WHILE DELETING STORY: $e');
      _showSnackbar('Ошибка при удалении истории: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showStoryOptionsDialog(Story story) {
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
                  leading: const Icon(Icons.edit, color: Colors.black),
                  title: const Text('Редактировать статью'),
                  onTap: () {
                    Navigator.of(context).pop();
                    if (mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (context) => EditStoryScreen(
                                story: story,
                                onStoryUpdated: _loadProfileData,
                              ),
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Удалить статью',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showDeleteConfirmationDialog(story.id);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(int storyId) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Подтвердить удаление'),
            content: const Text('Вы уверены, что хотите удалить эту статью?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => _deleteStory(storyId),
                child: const Text(
                  'Удалить',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _navigateToEditProfile() async {
    if (_profileData == null || !mounted) return;

    final userData = _getSafeUserData();
    if (userData.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => EditProfileScreen(
              initialUserData: userData,
              onProfileUpdated: (newUserData) {
                if (mounted && _profileData != null) {
                  setState(() {
                    _profileData = {..._profileData!, 'user_data': newUserData};
                  });
                }
              },
            ),
      ),
    );

    await _loadProfileData();
  }

  void _navigateToSubscriptionList(String initialTab) {
    if (_profileData == null || !mounted) return;

    final userData = _getSafeUserData();
    if (userData.isEmpty) return;

    final userId = userData['id'];
    final username = userData['username'];

    if (userId is! int || username is! String) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => SubscriptionsSubscriberListScreen(
              profileuser_id: userId,
              profileUsername: username,
              initialTab: initialTab,
              onUpdate: _loadProfileData,
            ),
      ),
    );
  }

  Future<void> _loadProfileData() async {
    if (!mounted) return;

    try {
      // ✅ НЕ сбрасываем _isLoading здесь, так как это может перекрывать кешированный аватар
      // Но сбрасываем ошибку
      setState(() {
        _errorMessage = null;
      });

      final data = await _subscriptionService.fetchUserProfile(
        widget.profileUserId,
      );

      print('🟢 DEBUG: API Response TYPE: ${data.runtimeType}');
      print('🟢 DEBUG: API Response KEYS: ${data?.keys}');
      print('🟢 DEBUG: Has user_data: ${data?.containsKey('user_data')}');
      print('🟢 DEBUG: Has user: ${data?.containsKey('user')}');
      print('🟢 DEBUG: Has stats: ${data?.containsKey('stats')}');
      print(
        '🟢 DEBUG: Has is_my_profile: ${data?.containsKey('is_my_profile')}',
      );

      if (mounted) {
        if (data != null && data is Map<String, dynamic>) {
          setState(() {
            _profileData = data;
            _isLoading = false;
          });
        } else {
          setState(() {
            _profileData = null;
            _isLoading = false;
            _errorMessage = 'Не удалось загрузить данные профиля';
          });
        }
      }
    } catch (e) {
      print('❌ DEBUG: Error loading profile: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Ошибка загрузки: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _handleFollowToggle() async {
    if (_profileData == null || !mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _subscriptionService.toggleFollow(
        widget.profileUserId,
      );
      _showSnackbar(result);
      await _loadProfileData();
    } catch (e) {
      _showSnackbar(e.toString());
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Widget _buildStatColumn(String label, dynamic count) {
    final int countValue = _safeParseInt(count) ?? 0;

    if (label == "Статей") {
      return NeoContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              countValue.toString(),
              style: Theme.of(
                context,
              ).textTheme.headlineLarge!.copyWith(fontSize: 20),
            ),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium!.copyWith(fontSize: 14),
            ),
          ],
        ),
      );
    }

    String tabName = label == "Подписчиков" ? 'followers' : 'following';

    return GestureDetector(
      onTap: () => _navigateToSubscriptionList(tabName),
      child: NeoContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              countValue.toString(),
              style: Theme.of(
                context,
              ).textTheme.headlineLarge!.copyWith(fontSize: 20),
            ),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium!.copyWith(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  int? _safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is bool) return value ? 1 : 0;

    // Пытаемся преобразовать строку
    try {
      return int.tryParse(value.toString());
    } catch (e) {
      print('❌ DEBUG: Failed to parse int from $value: $e');
      return 0;
    }
  }

  Widget _buildExpandableStoryList(List<Story> stories, bool isMyProfile, double titleFontScale) {
    if (stories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.view_agenda),
              Text(
                "Оставь свой след в приложении",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                "Возможно твоя первая история будет самой обсуждаемой",
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(child: ListView(
      children:
          stories.map((story) {
            return GestureDetector(
              onTap: () {
                if (mounted) {
                  // Получаем данные пользователя из профиля
                  final userData = _getSafeUserData();
                  final profileUsername = userData['username'] as String?;
                  final profileAvatar = userData['avatar'] as String?;

                  // Создаем копию истории с добавленными данными пользователя
                  final enhancedStory = story.copyWith(
                    username: profileUsername ?? story.username,
                    avatarUrl: profileAvatar ?? story.avatarUrl,
                  );

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (context) => StoryDetailPage(story: enhancedStory),
                    ),
                  );
                }
              },
              onLongPress:
                  isMyProfile ? () => _showStoryOptionsDialog(story) : null,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                child: ListTile(
                  title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(
                    // show shorten title with "..."
                    story.title.length > 30 ? '${story.title.substring(0, 30)}...' : story.title,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineLarge!.copyWith(fontSize: 20 * titleFontScale),
                  ),GestureDetector(onTap: isMyProfile ? () => _showStoryOptionsDialog(story) : null, child:Icon(Icons.more_vert))]),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 5),
                      Text(
                        story.content.length > 150
                            ? '${story.content.substring(0, 150)}...'
                            : story.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              if (story.hashtags.isNotEmpty)
                                for (var x in story.hashtags)
                                  Text(
                                    x.name == "" ? "Text" : x.name,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                            ],
                          ),
                          Text(
                            // display date in dd/mm/yyyy format
                            story.createdAt.toString().substring(0, 10),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
    ));
  }

  Widget _buildDraftList(List<DraftStory> drafts, double titleFontScale) {
    if (drafts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.edit_note),
              Text(
                "У вас пока нет черновиков",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                "Начните писать новую историю!",
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: drafts.map((draft) {
        return GestureDetector(
          onTap: () async {
            // Navigate to AddStoryScreen for editing the draft
            final result = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => draftScreen.CreateStoryFromDraftScreen(
                  draft: draft,
                ),
              ),
            );
            if (result == true) {
              _loadDrafts(); // Refresh drafts if something was saved/deleted
            }
          },
          onLongPress: () => _showDraftOptionsDialog(draft),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12, top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 2),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            child: ListTile(
              title: Text(
                draft.title.isNotEmpty ? draft.title : 'Без названия',
                style: Theme.of(context).textTheme.headlineLarge!.copyWith(fontSize: 20 * titleFontScale), // Apply titleFontScale
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  Text(
                    draft.content.length > 150
                        ? '${draft.content.substring(0, 150)}...'
                        : draft.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Создан: ${draft.updatedAt.toString().split(' ')[0]}', // Display only date
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showDraftOptionsDialog(DraftStory draft) {
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
                  leading: const Icon(Icons.edit, color: Colors.black),
                  title: const Text('Редактировать черновик'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => draftScreen.CreateStoryFromDraftScreen(
                          draft: draft,
                        ),
                      ),
                    );
                    _loadDrafts(); // Refresh drafts after potential edit
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Удалить черновик',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showDeleteDraftConfirmationDialog(draft.id);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteDraftConfirmationDialog(String draftId) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтвердить удаление черновика'),
        content: const Text('Вы уверены, что хотите удалить этот черновик?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog
              await _draftService.deleteDraft(draftId);
              _showSnackbar('Черновик успешно удален.');
              _loadDrafts(); // Refresh drafts
            },
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }


  Map<String, dynamic> _getSafeUserData() {
    if (_profileData == null) return {};

    print('🟠 DEBUG: Full profile data: $_profileData');

    try {
      final userData = _profileData!['user_data'];

      if (userData == null) {
        print('❌ user_data is null');
        return {};
      }

      Map<String, dynamic> result = {};

      // Приводим к Map любым способом
      if (userData is Map<String, dynamic>) {
        print('✅ user_data is already Map<String, dynamic>');
        result = Map<String, dynamic>.from(userData);
      } else if (userData is Map) {
        print('✅ user_data is Map, converting to Map<String, dynamic>');
        result = Map<String, dynamic>.from(userData);
      } else {
        print('❌ user_data is not a Map, type: ${userData.runtimeType}');
        return {};
      }

      // 🚨 КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ: Обрабатываем путь к аватару
      if (result.containsKey('avatar') && result['avatar'] != null) {
        final avatarPath = _cleanUrl(result['avatar']) ?? '';



        // Проверяем, начинается ли путь с http или https
        if (avatarPath.contains('User agent')) {
          result['avatar'] = null;
          print('⚠️ DEBUG: Ignored invalid avatar path: $avatarPath');
        } else if (avatarPath.isNotEmpty && !avatarPath.startsWith('http')) {
          // Если это относительный путь, добавляем базовый URL
          final String baseUrl = 'https://ravell-backend-1.onrender.com';

          // Убедимся, что путь начинается с /
          final String fullPath =
              avatarPath.startsWith('/') ? avatarPath : '/$avatarPath';

          result['avatar'] = '$baseUrl$fullPath';
          print('🔄 DEBUG: Fixed avatar path to: ${result['avatar']}');
        }
      }

      // Также проверяем profile.avatar, если есть
      if (result.containsKey('profile') && result['profile'] is Map) {
        final profile = Map<String, dynamic>.from(result['profile']);
        if (profile.containsKey('avatar') && profile['avatar'] != null) {
          final avatarPath = profile['avatar'].toString().trim();

          if (avatarPath.contains('User agent')) {
            profile['avatar'] = null;
          } else if (avatarPath.isNotEmpty && !avatarPath.startsWith('http')) {
            final String baseUrl = 'https://ravell-backend-1.onrender.com';
            final String fullPath =
                avatarPath.startsWith('/') ? avatarPath : '/$avatarPath';

            profile['avatar'] = '$baseUrl$fullPath';
            result['profile'] = profile;
            print(
              '🔄 DEBUG: Fixed profile.avatar path to: ${profile['avatar']}',
            );
          }
          
          // Fallback: Если в корне 'avatar' пусто, берем из профиля
          if (result['avatar'] == null || result['avatar'].toString().trim().isEmpty || result['avatar'].toString().contains('User agent')) {
            result['avatar'] = profile['avatar'];
          }
        }
      }

      return result;
    } catch (e) {
      print('❌ Error getting user_data: $e');
      return {};
    }
  }

  Map<String, dynamic> _getSafeStats() {
    if (_profileData == null) return {};

    final stats = _profileData!['stats'];
    if (stats == null || stats is! Map<String, dynamic>) return {};

    return stats;
  }

  List<Story> _getSafeStories() {
    if (_profileData == null) return [];

    final storiesData = _profileData!['stories'] ?? [];
    if (storiesData is! List) return [];

    final userData = _getSafeUserData(); // Получаем данные пользователя
    final userAvatar = userData['avatar'] as String?;
    final username = userData['username'] as String?;

    try {
      final stories = storiesData.map((json) {
        try {
          // ДОБАВЛЯЕМ недостающие поля из user_data
          final storyJson = Map<String, dynamic>.from(json);

          // 🟢 КЛЮЧЕВОЕ ИЗМЕНЕНИЕ: Добавляем полный объект user
          if (!storyJson.containsKey('user')) {
            storyJson['user'] = {
              'id': userData['id'],
              'username': username,
              'first_name': userData['first_name'],
              'last_name': userData['last_name'],
              'profile': {
                'avatar': userAvatar,
                'is_verified': userData['is_verified'] ?? false,
              },
            };
          }

          // Если в story нет username, добавляем из user_data
          if (!storyJson.containsKey('username') && username != null) {
            storyJson['username'] = username;
          }

          // Если в story нет avatar, добавляем из user_data
          if (!storyJson.containsKey('avatar') && userAvatar != null) {
            storyJson['avatar'] = userAvatar;
          }

          return Story.fromJson(storyJson);
        } catch (e) {
          print('Error parsing story: $e');
          return Story(
            id: 0,
            title: 'Ошибка загрузки',
            content: 'Не удалось загрузить историю',
            userId: 0,
            createdAt: DateTime.now(),
            likesCount: 0,
            commentsCount: 0,
            userLiked: false,
            hashtags: [],
            authorAvatar: userAvatar,
            avatarUrl: userAvatar,
          );
        }
      }).toList();
      
      // Применяем сортировку
      switch (_sortOption) {
        case 'newest':
          stories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
        case 'oldest':
          stories.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          break;
        case 'popular':
          stories.sort((a, b) => b.likesCount.compareTo(a.likesCount));
          break;
      }
      
      return stories;
    } catch (e) {
      print('Error converting stories: $e');
      return [];
    }
  }

  bool _getSafeIsFollowing() {
    if (_profileData == null) return false;

    final isFollowing = _profileData!['is_following'];
    return isFollowing == true;
  }

  bool _getIsMyProfile() {
    // ✅ ПЕРВЫЙ ПРИОРИТЕТ: сравниваем ID пользователей
    final userData = _getSafeUserData();
    final profileId = userData['id'];

    if (currentUserId != null && profileId != null) {
      final bool isMatch = currentUserId == int.tryParse(profileId.toString());
      print('🔍 DEBUG: IDs comparison (Current: $currentUserId, Profile: $profileId) -> Match: $isMatch');
      return isMatch;
    }

    // ✅ ВТОРОЙ ПРИОРИТЕТ: проверяем флаг из API
    if (_profileData != null && _profileData!.containsKey('is_my_profile')) {
      print('✅ DEBUG: Using API flag is_my_profile: ${_profileData!['is_my_profile']}');
      return _profileData!['is_my_profile'] == true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
        bottomNavigationBar: p.PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(currentRoute: GoRouterState.of(context).uri.toString()),
      );
    }

    if (_errorMessage != null || _profileData == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage ?? "Не удалось загрузить профиль"),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadProfileData,
                child: const Text("Повторить"),
              ),
            ],
          ),
        ),
        bottomNavigationBar: p.PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(currentRoute: GoRouterState.of(context).uri.toString()),
      );
    }

    final userData = _getSafeUserData();
    final stats = _getSafeStats();
    final userStories = _getSafeStories();
    final isFollowing = _getSafeIsFollowing();
    final isMyProfile = _getIsMyProfile();
    final avatarUrl = _cleanUrl(userData['avatar']);

    final isAvatarSet = avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        avatarUrl != 'null' &&
        !avatarUrl.contains('User agent');
    ImageProvider? avatarImageProvider;

    print('🟣 DEBUG: Is my profile: $isMyProfile');
    print('🟣 DEBUG: Current user ID: $currentUserId');
    print('🟣 DEBUG: Profile user ID: ${userData['id']}');

    final firstName = userData['first_name'] as String? ?? '';
    final lastName = userData['last_name'] as String? ?? '';
    final username = userData['username'] as String? ?? 'User';
    print(userData['is_early']);
    final fullName = '${firstName} ${lastName}'.trim();
    if (isAvatarSet) {
      // ✅ ДОБАВЛЯЕМ БАЗОВЫЙ URL ДЛЯ АВАТАРОВ
      final fullAvatarUrl =
          avatarUrl.startsWith('http')
              ? avatarUrl
              : '$avatarUrl';
      avatarImageProvider = NetworkImage(fullAvatarUrl);
    }

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
          Builder(
            builder: (innerContext) {
              return GestureDetector(
                onTap: () {
                  Scaffold.of(innerContext).openEndDrawer();
                },
                child: SvgPicture.asset(
                  "assets/icons/settings.svg",
                  width: 60,
                  height: 60,
                ),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              bottom: 16.0,
              top: 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- СЕКЦИЯ 1: АВАТАР, ИМЯ И СТАТИСТИКА ---
                Column(
                  children: [
                    Stack(
                      children: [
                        ClipOval(
                          child: Container(
                            width: 80,
                            height: 80,
                            color: Colors.blueGrey,
                            child: isAvatarSet
                                ? CachedNetworkImage(
                                    imageUrl: avatarUrl!,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    httpHeaders: const {
                                      'User-Agent': 'FlutterApp/1.0',
                                      'Accept': 'image/*',
                                    },
                                    placeholder: (context, url) => const Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => const Icon(
                                      Icons.person,
                                      size: 40,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ],
                    ),
                    if (fullName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              fullName,
                              style: Theme.of(
                                context,
                              ).textTheme.headlineLarge?.copyWith(fontSize: 25),
                            ),
                            if (userData['is_early'] == true ||
                                (userData['profile'] != null &&
                                    userData['profile']['is_early'] == true)) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => EarlyAccessSheet.show(context),
                                child: const Icon(Icons.star, color: Colors.amber),
                              ),
                            ],
                          ],
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '@$username',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineLarge!.copyWith(fontSize: 16),
                        ),
                        if (fullName.isEmpty &&
                            (userData['is_early'] == true ||
                                (userData['profile'] != null &&
                                    userData['profile']['is_early'] == true))) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => EarlyAccessSheet.show(context),
                            child: const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 18,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(width: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Chip(
                          side: const BorderSide(
                            color: Colors.black,
                            width: 2,
                            strokeAlign: BorderSide.strokeAlignOutside,
                          ),
                          label:
                              streakCount != null
                                  ? GestureDetector(
                                    onTap: () {
                                      if (isMyProfile) {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder:
                                                (_) => const StreakScreen(),
                                          ),
                                        );
                                      }
                                    },
                                    child: Row(
                                      children: [
                                        const Text(
                                          '🔥',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                        Text(
                                          streakCount.toString(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  : SizedBox.shrink(),
                        ),
                        SizedBox(width: 10),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => AchievementScreen(
                                      userId: _safeParseInt(userData['id']) ?? 0,
                                    ),
                              ),
                            );
                          },
                          child: const Chip(
                            side: BorderSide(
                              color: Colors.black,
                              width: 2,
                              strokeAlign: BorderSide.strokeAlignOutside,
                            ),
                            label: Text("🎯 Ваши достижения"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn("Статей", stats['stories_count']),
                        _buildStatColumn(
                          "Подписчиков",
                          stats['followers_count'],
                        ),
                        _buildStatColumn("Подписок", stats['following_count']),
                      ],
                    ),
                  ],
                ),

                // --- СЕКЦИЯ 2: КНОПКА ПОДПИСКИ/РЕДАКТИРОВАНИЯ ---
                const SizedBox(height: 10),

                if (isMyProfile)
                  SizedBox(
                    height: 75,
                    width: double.infinity,
                    child: NeoButton(
                      onPressed: _navigateToEditProfile,
                      text: 'Редактировать профиль',
                    ),
                  )
                else if (currentUserId != null)
                  SizedBox(
                    width: double.infinity,
                    child: NeoButton(
                      onPressed: _handleFollowToggle,
                      text: isFollowing ? 'Вы подписаны' : 'Подписаться',
                    ),
                  )
                else
                  const Center(
                    child: Text('Авторизуйтесь, чтобы подписаться.'),
                  ),
                const SizedBox(height: 10),

                // --- СЕКЦИЯ 3: ТАБЫ ИСТОРИЙ И ЧЕРНОВИКОВ ---
                if (isMyProfile) // Only show tabs if it's my own profile
                  Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(text: 'Статьи'),
                          Tab(text: 'Черновики'),
                        ],
                        labelColor: Colors.black, // Active tab color
                        unselectedLabelColor: Colors.grey, // Inactive tab color
                        indicatorColor: Colors.black, // Indicator color
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5, // Adjust height as needed
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Tab 1: Published Stories
                            Column(
                              children: [
                                // Кнопка сортировки
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          setState(() {
                                            _sortOption = value;
                                          });
                                        },
                                        itemBuilder: (context) => [
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
                                _buildExpandableStoryList(userStories, isMyProfile, _currentTitleFontScale),
                                
                              ],
                            ),
                            // Tab 2: Drafts
                            _buildDraftList(_drafts, _currentTitleFontScale),
                          ],
                        ),
                      ),
                    ],
                  )
                else // If not my profile, just show stories
                  Column(
                    children: [
                      // Кнопка сортировки
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                setState(() {
                                  _sortOption = value;
                                });
                              },
                              itemBuilder: (context) => [
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
                      _buildExpandableStoryList(userStories, isMyProfile, _currentTitleFontScale)
                    ],
                  ),
                const SizedBox(height: 100),


        ]),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              width: MediaQuery.of(context).size.width,
              child: p.PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(currentRoute: GoRouterState.of(context).uri.toString()),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          children: <Widget>[
            ListTile(
              title: const Text("Доска почета"),
              leading: const Icon(Icons.people),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const InfluencersBoard(),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text("Настройки"),
              leading: const Icon(Icons.settings),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(),
                  ),
                );
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.info, color: Colors.black),
              title: const Text(
                'О приложении',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              onTap: () {
                context.push('/credits');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout_outlined, color: Colors.red),
              title: const Text(
                'Log out',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Colors.red,
                ),
              ),
              onTap: () async {
                // 1️⃣ Выход из аккаунта
                await _authService.logout();

                // 2️⃣ Закрываем Drawer
                if (mounted) {
                  Navigator.pop(context);
                }

                // 3️⃣ Перенаправляем на экран логина
                if (mounted) {
                  // Используем GoRouter для навигации
                  // Очистка истории навигации
                  context.go('/login');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsButton(
    List<String> achievementIcons,
    VoidCallback onTap,
  ) {
    final double size = 50;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: size,
        width: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (int i = 0; i < achievementIcons.length && i < 3; i++)
              Positioned(
                left: i * 15.0, // смещение для перекрытия
                child: NeoContainer(
                  width: size,
                  height: size,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(size / 2),
                    child: SvgPicture.asset(
                      achievementIcons[i],
                      width: size,
                      height: size,
                    ),
                  ),
                ),
              ),
            if (achievementIcons.length > 3)
              Positioned(
                left: 3 * 15.0,
                child: NeoContainer(
                  width: size,
                  height: size,
                  color: Colors.grey[300]!,
                  child: Center(
                    child: Text(
                      '+${achievementIcons.length - 3}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
