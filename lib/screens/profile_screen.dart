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
import 'package:readreels/managers/settings_manager.dart';
import 'package:provider/provider.dart';
import 'package:readreels/services/subscription_service.dart';
import 'package:readreels/services/story_service.dart';
import 'package:readreels/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'edit_profile.dart';
import 'package:readreels/models/story.dart';
import 'package:readreels/widgets/neowidgets.dart';
import 'package:readreels/widgets/early_access_bottom.dart';
import 'package:readreels/theme.dart';
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
  final _subscriptionService = SubscriptionService();
  final _storyService = StoryService();
  final _authService = AuthService();

  SettingsManager get settings => Provider.of<SettingsManager>(context, listen: false);

  // Helper getters to fix "Method not found" errors if they are used as methods
  SubscriptionService get SubscriptionServiceInstance => _subscriptionService;
  StoryService get StoryServiceInstance => _storyService;
  AuthService get AuthServiceInstance => _authService;
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

      final settings = Provider.of<SettingsManager>(context, listen: false);
      _showSnackbar(settings.translate('story_published')); // Reusing or need a 'story_deleted'
      await _loadProfileData();
    } catch (e) {
      print('🔴 UI ERROR WHILE DELETING STORY: $e');
      final settings = Provider.of<SettingsManager>(context, listen: false);
      _showSnackbar('${settings.translate('error')}: $e');
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
                  title: Text(settings.translate('edit')),
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
                  title: Text(
                    settings.translate('delete'),
                    style: const TextStyle(color: Colors.red),
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

    final settings = Provider.of<SettingsManager>(context, listen: false);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(settings.translate('delete')),
            content: Text(settings.translate('draft')), // Need 'confirm_delete' really
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(settings.translate('cancel')),
              ),
              TextButton(
                onPressed: () => _deleteStory(storyId),
                child: Text(
                  settings.translate('delete'),
                  style: const TextStyle(color: Colors.red),
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
          final settings = Provider.of<SettingsManager>(context, listen: false);
          setState(() {
            _profileData = null;
            _isLoading = false;
            _errorMessage = settings.translate('error');
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
    final settings = Provider.of<SettingsManager>(context);

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
              settings.translate('stories'),
              style: Theme.of(
                context,
              ).textTheme.headlineMedium!.copyWith(fontSize: 14),
            ),
          ],
        ),
      );
    }

    String tabName = label == "Подписчиков" ? 'followers' : 'following';
    String translatedLabel = label == "Подписчиков" ? settings.translate('followers') : settings.translate('following');

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
              translatedLabel,
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

  Widget _buildSliverExpandableStoryList(List<Story> stories, bool isMyProfile, double titleFontScale) {
    if (stories.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.view_agenda),
              Text(
                settings.translate('author'), // Using 'author' or need 'empty_stories'
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                settings.translate('no_replies'),
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 100, top: 10),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final story = stories[index];
            return GestureDetector(
              onTap: () {
                if (mounted) {
                  final userData = _getSafeUserData();
                  final profileUsername = userData['username'] as String?;
                  final profileAvatar = userData['avatar'] as String?;
                  final enhancedStory = story.copyWith(
                    username: profileUsername ?? story.username,
                    avatarUrl: profileAvatar ?? story.avatarUrl,
                  );
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => StoryDetailPage(story: enhancedStory),
                    ),
                  );
                }
              },
              onLongPress: isMyProfile ? () => _showStoryOptionsDialog(story) : null,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          story.title.length > 30 ? '${story.title.substring(0, 30)}...' : story.title,
                          style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                                fontSize: 20 * titleFontScale,
                              ),
                        ),
                      ),
                      if (isMyProfile)
                        GestureDetector(
                          onTap: () => _showStoryOptionsDialog(story),
                          child: const Icon(Icons.more_vert),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text(
                        story.content.length > 150
                            ? '${story.content.substring(0, 150)}...'
                            : story.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (story.hashtags.isNotEmpty)
                            Expanded(
                              child: Wrap(
                                children: story.hashtags.map((x) => Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Text(
                                    x.name.isEmpty ? "Text" : "#${x.name}",
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                )).toList(),
                              ),
                            ),
                          Text(
                            story.createdAt.toString().substring(0, 10),
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          childCount: stories.length,
        ),
      ),
    );
  }

  Widget _buildSliverDraftList(List<DraftStory> drafts, double titleFontScale) {
    if (drafts.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.edit_note),
              Text(
                settings.translate('draft'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                settings.translate('write_reply'), // Need 'no_drafts_hint' really
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 100, top: 10),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final draft = drafts[index];
            return GestureDetector(
              onTap: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => draftScreen.CreateStoryFromDraftScreen(
                      draft: draft,
                    ),
                  ),
                );
                if (result == true) {
                  _loadDrafts();
                }
              },
              onLongPress: () => _showDraftOptionsDialog(draft),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    draft.title.isNotEmpty ? draft.title : 'Без названия',
                    style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                          fontSize: 20 * titleFontScale,
                        ),
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
                        '${settings.translate('version')}: ${draft.updatedAt.toString().split(' ')[0]}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          childCount: drafts.length,
        ),
      ),
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
                  title: Text(settings.translate('edit')),
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
                  title: Text(
                    settings.translate('delete'),
                    style: const TextStyle(color: Colors.red),
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

    final settings = Provider.of<SettingsManager>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settings.translate('delete')),
        content: Text(settings.translate('draft')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(settings.translate('cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _draftService.deleteDraft(draftId);
              _showSnackbar(settings.translate('profile_updated'));
              _loadDrafts();
            },
            child: Text(
              settings.translate('delete'),
              style: const TextStyle(color: Colors.red),
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

  final userData = _getSafeUserData(); 
  final userAvatar = userData['avatar'] as String?;
  final username = userData['username'] as String?;

  try {
    return storiesData.map((json) {
      try {
        final storyJson = Map<String, dynamic>.from(json);

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

        if (!storyJson.containsKey('username') && username != null) {
          storyJson['username'] = username;
        }

        if (!storyJson.containsKey('avatar') && userAvatar != null) {
          storyJson['avatar'] = userAvatar;
        }

        return Story.fromJson(storyJson);
      } catch (e) {
        print('❌ Ошибка парсинга отдельной истории: $e');
        return null;
      }
    })
    .whereType<Story>() // Убираем null, если парсинг не удался
    // 👇 ВОТ ЭТА СТРОЧКА ФИЛЬТРУЕТ КОММЕНТАРИИ
    .where((story) => story.title != "Комментарий") 
    .toList();
  } catch (e) {
    print('❌ Ошибка в _getSafeStories: $e');
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
    final settings = Provider.of<SettingsManager>(context);

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
                Text(_errorMessage ?? settings.translate('error')),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loadProfileData,
                  child: Text(settings.translate('retry')),
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
          NestedScrollView(
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- АВАТАР ---
                      Center(
                        child: ClipOval(
                          child: Container(
                            width: 80,
                            height: 80,
                            color: Colors.blueGrey,
                            child: isAvatarSet
                                ? CachedNetworkImage(
                                    imageUrl: avatarUrl!,
                                    fit: BoxFit.cover,
                                    httpHeaders: const {
                                      'User-Agent': 'FlutterApp/1.0',
                                      'Accept': 'image/*',
                                    },
                                    placeholder: (_, __) => const Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => const Icon(
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
                      ),
                      const SizedBox(height: 8),

                      // --- ИМЯ ---
                      if (fullName.isNotEmpty)
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                fullName,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineLarge
                                    ?.copyWith(fontSize: 25),
                              ),
                              if (userData['is_early'] == true ||
                                  userData['profile']?['is_early'] == true) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => EarlyAccessSheet.show(context),
                                  child: const Icon(Icons.star, color: Colors.amber),
                                ),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 4),

                      // --- USERNAME ---
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '@$username',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(fontSize: 16),
                            ),
                            if (fullName.isEmpty &&
                                (userData['is_early'] == true ||
                                    userData['profile']?['is_early'] == true)) ...[
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
                      ),
                      const SizedBox(height: 10),

                      // --- СТРИК + ДОСТИЖЕНИЯ ---
                      if(isMyProfile)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (streakCount != null)
                            Chip(
                              side: const BorderSide(width: 2),
                              label: GestureDetector(
                                onTap: isMyProfile
                                    ? () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => const StreakScreen(),
                                          ),
                                        )
                                    : null,
                                child: Row(
                                  children: [
                                    const Icon(Icons.whatshot, color: Colors.orange),
                                    Text(
                                      streakCount.toString(),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AchievementScreen(
                                    userId: _safeParseInt(userData['id']) ?? 0,
                                  ),
                                ),
                              );
                            },
                            child: Chip(
                              side: const BorderSide(width: 2),
                              label: Row(
                                children: [
                                  Icon(Icons.military_tech, color: Colors.red),
                                  Text(settings.translate('achievements'))
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // --- СТАТИСТИКА ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatColumn(settings.translate('stories'), stats['stories_count']),
                          _buildStatColumn(settings.translate('followers'), stats['followers_count']),
                          _buildStatColumn(settings.translate('following'), stats['following_count']),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // --- КНОПКА ---
                      if (isMyProfile)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          child: NeoButton(
                            onPressed: _navigateToEditProfile,
                            text: settings.translate('edit_profile'),
                          ),
                        )
                      else if (currentUserId != null)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          child: NeoButton(
                            onPressed: _handleFollowToggle,
                            text: isFollowing ? settings.translate('unsubscribe') : settings.translate('subscribe'),
                          ),
                        )
                      else
                          Center(child: Text(settings.translate('auth_required'))),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                if (isMyProfile)
                  SliverOverlapAbsorber(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                    sliver: SliverPersistentHeader(
                      pinned: true,
                      delegate: _TabBarDelegate(
                        TabBar(
                          controller: _tabController,
                          labelColor: Colors.black,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: Colors.black,
                            tabs: [
                              Tab(text: settings.translate('stories')),
                              Tab(text: settings.translate('drafts')),
                            ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverOverlapAbsorber(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                    sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
                  ),
              ];
            },
            body: isMyProfile
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      Builder(builder: (context) {
                        return CustomScrollView(
                          slivers: [
                            SliverOverlapInjector(
                              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                            ),
                            _buildSliverExpandableStoryList(
                                userStories, isMyProfile, _currentTitleFontScale),
                          ],
                        );
                      }),
                      Builder(builder: (context) {
                        return CustomScrollView(
                          slivers: [
                            SliverOverlapInjector(
                              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                            ),
                            _buildSliverDraftList(_drafts, _currentTitleFontScale),
                          ],
                        );
                      }),
                    ],
                  )
                : Builder(
                  builder: (context) {
                    return CustomScrollView(
                    slivers: [
                      SliverOverlapInjector(
                        handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                      ),
                      _buildSliverExpandableStoryList(
                          userStories, isMyProfile, _currentTitleFontScale),
                    ],
                  );
                  }
                ),
          ),

          // ===== BOTTOM NAV =====
          Positioned(
            bottom: 0,
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              child: p.PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(
                currentRoute: GoRouterState.of(context).uri.toString(),
              ),
            ),
          ),
        ],
      ),

      endDrawer: Drawer(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          children: <Widget>[
            ListTile(
              title: Text(settings.translate('influence_list')),
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
              title: Text(settings.translate('settings')),
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
              title: Text(
                settings.translate('about_app'),
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
              title: Text(
                settings.translate('logout'),
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

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(context, shrinkOffset, overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_) => false;
}
