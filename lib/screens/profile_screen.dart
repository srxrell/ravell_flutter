import 'dart:convert';
import 'dart:io' if (dart.library.html) 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:readreels/screens/achievement_screen.dart';
import 'package:readreels/screens/story_detail.dart';
import 'package:readreels/screens/influencers_board.dart';

import 'package:readreels/screens/add_story.dart';
import 'package:readreels/screens/streak_screen.dart';
import 'package:readreels/screens/subscribers_list.dart';
import 'package:readreels/screens/user_story_feed_screen.dart';
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

class UserProfileScreen extends StatefulWidget {
  final int profileUserId;

  const UserProfileScreen({super.key, required this.profileUserId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final StoryService _storyService = StoryService();
  final AuthService _authService = AuthService();
  int? streakCount;

  int? currentUserId;
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCachedAvatar();
    _loadProfileData();
    _loadUserStreak(widget.profileUserId);
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
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final sp = await SharedPreferences.getInstance();
      currentUserId = sp.getInt('user_id');

      print('🟡 DEBUG: Current User ID: $currentUserId');
      print('🟡 DEBUG: Profile User ID: ${widget.profileUserId}');

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

  Widget _buildExpandableStoryList(List<Story> stories, bool isMyProfile) {
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

    return Column(
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
                  title: Text(
                    story.title.isNotEmpty ? story.title : 'Без названия',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineLarge!.copyWith(fontSize: 20),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        story.content.length > 150
                            ? '${story.content.substring(0, 150)}...'
                            : story.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
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
                            story.createdAt.toString(),
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
        final avatarPath = result['avatar'].toString();

        // Проверяем, начинается ли путь с http или https
        if (avatarPath.isNotEmpty && !avatarPath.startsWith('http')) {
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
          final avatarPath = profile['avatar'].toString();

          if (avatarPath.isNotEmpty && !avatarPath.startsWith('http')) {
            final String baseUrl = 'https://ravell-backend-1.onrender.com';
            final String fullPath =
                avatarPath.startsWith('/') ? avatarPath : '/$avatarPath';

            profile['avatar'] = '$baseUrl$fullPath';
            result['profile'] = profile;
            print(
              '🔄 DEBUG: Fixed profile.avatar path to: ${profile['avatar']}',
            );
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
      return storiesData.map((json) {
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
          );
        }
      }).toList();
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
    // ✅ ПЕРВЫЙ ПРИОРИТЕТ: проверяем флаг из API
    if (_profileData != null && _profileData!.containsKey('is_my_profile')) {
      print(
        '✅ DEBUG: Using API flag is_my_profile: ${_profileData!['is_my_profile']}',
      );
      return _profileData!['is_my_profile'] == true;
    }

    // ✅ ВТОРОЙ ПРИОРИТЕТ: сравниваем ID пользователей
    final userData = _getSafeUserData();
    final profileId = userData['id'];

    print('🔍 DEBUG: Profile ID from user data: $profileId');
    print('🔍 DEBUG: Current user ID: $currentUserId');
    print('🔍 DEBUG: User data type: ${profileId.runtimeType}');
    print('🔍 DEBUG: Current user ID type: ${currentUserId.runtimeType}');

    final bool isMyProfile =
        currentUserId != null &&
        profileId != null &&
        currentUserId == int.tryParse(profileId.toString());

    print('✅ DEBUG: Calculated is_my_profile: $isMyProfile');

    return isMyProfile;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
        bottomNavigationBar: p.PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(),
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
        bottomNavigationBar: p.PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(),
      );
    }

    final userData = _getSafeUserData();
    final stats = _getSafeStats();
    final userStories = _getSafeStories();
    final isFollowing = _getSafeIsFollowing();
    final isMyProfile = _getIsMyProfile();
    final avatarUrl = userData['avatar'] as String?;
    final isAvatarSet = avatarUrl != null && avatarUrl.isNotEmpty;
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
              : 'https://ravell-backend-1.onrender.com$avatarUrl';
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
                    CircleAvatar(
                      radius: 40,
                      backgroundColor:
                          isAvatarSet ? Colors.transparent : Colors.blueGrey,
                      backgroundImage: avatarImageProvider,
                      child:
                          isAvatarSet
                              ? null
                              : const Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.white,
                              ),
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
                            SizedBox(width: 10),
                            if (userData['is_early'] == true)
                              GestureDetector(
                                onTap: () => EarlyAccessSheet.show(context),
                                child: Icon(Icons.star, color: Colors.amber),
                              ),
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
                        SizedBox(width: 5),
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
                            label: Text("🎯 Your achievements"),
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

                // ✅ Передаем флаг isMyProfile в список историй
                _buildExpandableStoryList(userStories, isMyProfile),
                const SizedBox(height: 50),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              width: MediaQuery.of(context).size.width,
              child: p.PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(),
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
