// screens/user_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:readreels/screens/add_story.dart';
import 'package:readreels/screens/subscribers_list.dart';
import 'package:readreels/screens/user_story_feed_screen.dart';
import 'package:readreels/services/auth_service.dart';
import 'package:readreels/services/story_service.dart';
import 'package:readreels/theme.dart';
import 'package:readreels/widgets/neowidgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:readreels/services/subscription_service.dart';
import 'edit_profile.dart';
import 'package:readreels/models/story.dart';
import 'package:readreels/widgets/bottom_nav_bar_liquid.dart' as p;

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

  int? currentUserId;
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  // --- МЕТОДЫ УПРАВЛЕНИЯ ИСТОРИЯМИ ---

  Future<void> _deleteStory(int storyId) async {
    if (!mounted) return;

    Navigator.of(context).pop();

    setState(() {
      _isLoading = true;
    });

    try {
      await _storyService.deleteStory(storyId);
      _showSnackbar('История успешно удалена.');
      await _loadProfileData();
    } catch (e) {
      _showSnackbar('Ошибка при удалении истории: ${e.toString()}');
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

  // --- ФУНКЦИИ ПРОФИЛЯ ---

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
                    // Обновляем данные в профиле
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

  // --- ВИДЖЕТЫ ---

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
    return 0;
  }

  // Список историй с обработкой долгого нажатия
  Widget _buildExpandableStoryList(List<Story> stories, bool isMyProfile) {
    if (stories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Center(
          child: Text('Пока нет историй', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Column(
      children:
          stories.map((story) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  if (mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (context) => UserStoryFeedScreen(
                              stories: stories,
                              initialIndex: stories.indexOf(story),
                            ),
                      ),
                    );
                  }
                },
                onLongPress:
                    isMyProfile ? () => _showStoryOptionsDialog(story) : null,
                child: ListTile(
                  title: Text(
                    story.title.isNotEmpty ? story.title : 'Без названия',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineLarge!.copyWith(fontSize: 20),
                  ),
                  subtitle: Text(
                    story.content.length > 150
                        ? '${story.content.substring(0, 150)}...'
                        : story.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  // 🟢 ОБНОВЛЕННЫЕ МЕТОДЫ ДЛЯ РАБОТЫ С ФОРМАТОМ GO API
  Map<String, dynamic> _getSafeUserData() {
    if (_profileData == null) return {};

    // 🟢 ПРОБУЕМ ОБА ВАРИАНТА - и user_data и user
    final userData = _profileData!['user_data'] ?? _profileData!['user'];
    if (userData == null || userData is! Map<String, dynamic>) return {};

    return userData;
  }

  Map<String, dynamic> _getSafeStats() {
    if (_profileData == null) return {};

    final stats = _profileData!['stats'];
    if (stats == null || stats is! Map<String, dynamic>) return {};

    return stats;
  }

  List<Story> _getSafeStories() {
    if (_profileData == null) return [];

    // 🟢 ПРОБУЕМ ОБА ВАРИАНТА
    final storiesData = _profileData!['stories'] ?? [];
    if (storiesData is! List) return [];

    try {
      return storiesData.map((json) {
        try {
          return Story.fromJson(json);
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
    final userData = _getSafeUserData();
    final profileId = userData['id'];

    return currentUserId != null &&
        profileId != null &&
        profileId is int &&
        currentUserId == profileId;
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

    // Безопасное извлечение данных пользователя
    final firstName = userData['first_name'] as String? ?? '';
    final lastName = userData['last_name'] as String? ?? '';
    final username = userData['username'] as String? ?? 'User';
    final avatarUrl = userData['avatar'] as String?;
    final fullName = '${firstName} ${lastName}'.trim();

    // Определяем, какой аватар использовать
    final isAvatarSet = avatarUrl != null && avatarUrl.isNotEmpty;
    ImageProvider? avatarImageProvider;
    if (isAvatarSet) {
      avatarImageProvider = NetworkImage(avatarUrl);
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 100,
        automaticallyImplyLeading: false,
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
                  Scaffold.of(innerContext).openEndDrawer();
                },
                child: SvgPicture.asset(
                  "icons/settings.svg",
                  width: 60,
                  height: 60,
                ),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
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
                    child: Text(
                      fullName,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineLarge?.copyWith(fontSize: 25),
                    ),
                  ),
                Text(
                  '@$username',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineLarge!.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn("Статей", stats['stories_count']),
                    _buildStatColumn("Подписчиков", stats['followers_count']),
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
                  text: isFollowing ? 'Отписаться' : 'Подписаться',
                ),
              )
            else
              const Center(child: Text('Авторизуйтесь, чтобы подписаться.')),
            const SizedBox(height: 10),

            // ✅ Передаем флаг isMyProfile в список историй
            _buildExpandableStoryList(userStories, isMyProfile),
          ],
        ),
      ),
      bottomNavigationBar: p.PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(),
      endDrawer: Drawer(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          children: <Widget>[
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
              onTap: () {
                _authService.logout();
                if (mounted) {
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
