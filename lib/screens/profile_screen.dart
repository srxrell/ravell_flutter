import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:readreels/screens/add_story.dart';
import 'package:readreels/screens/subscribers_list.dart';
import 'package:readreels/screens/user_story_feed_screen.dart';
import 'package:readreels/services/story_service.dart';
import 'package:readreels/theme.dart';
import 'package:readreels/widgets/neowidgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:readreels/services/subscription_service.dart';
import 'edit_profile.dart';
import 'package:readreels/models/story.dart';
import 'package:readreels/widgets/bottom_nav_bar_liquid.dart' as p;

// Предполагается, что в 'package:readreels/theme.dart' определена neoBackground
// Предполагается, что в 'package:readreels/theme.dart' определена primaryColor (для иконок в диалоге)

class UserProfileScreen extends StatefulWidget {
  final int profileUserId;

  const UserProfileScreen({super.key, required this.profileUserId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final StoryService _storyService = StoryService(); // ✅ StoryService

  int? currentUserId;
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  // --- МЕТОДЫ УПРАВЛЕНИЯ ИСТОРИЯМИ (РЕДАКТИРОВАНИЕ/УДАЛЕНИЕ) ---

  Future<void> _deleteStory(int storyId) async {
    // Закрываем диалог подтверждения
    Navigator.of(context).pop();

    setState(() {
      _isLoading = true; // Показываем индикатор загрузки
    });

    try {
      await _storyService.deleteStory(storyId);
      _showSnackbar('История успешно удалена.');

      // ВАЖНО: Перезагружаем данные профиля, чтобы обновить список историй
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
      // 🔑 Настройки для нео-стиля: прозрачный фон и кастомный барьер
      barrierColor: const Color.fromARGB(153, 0, 0, 0),
      elevation: 0,
      context: context,
      isScrollControlled: true,
      // 🔑 Цвет фона модального окна должен быть прозрачным,
      // чтобы контейнер внутри управлял стилем
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        // 🔑 Оборачиваем содержимое в Container с кастомным декорированием
        return Container(
          // margin добавляет отступы от краев экрана, чтобы видеть барьер
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            // Используйте ваш цвет фона, например, Colors.white или neoWhite
            color: Colors.white,
            // Создаем "квадратную" неоморфическую рамку
            border: const Border(
              top: BorderSide(color: neoBlack, width: 4),
              left: BorderSide(color: neoBlack, width: 4),
              right: BorderSide(color: neoBlack, width: 8),
              bottom: BorderSide(color: neoBlack, width: 8),
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: SafeArea(
            // ⬅️ Оставляем SafeArea внутри контейнера, чтобы защитить ListTiles
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.black),
                  title: const Text('Редактировать статью'),
                  onTap: () {
                    Navigator.of(context).pop(); // Закрываем bottom sheet

                    // ✅ ИНТЕГРАЦИЯ: Навигация на EditStoryScreen
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (context) => EditStoryScreen(
                              story: story,
                              // Передаем коллбэк для обновления профиля после редактирования
                              onStoryUpdated: _loadProfileData,
                            ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Удалить статью',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.of(
                      context,
                    ).pop(); // ⬅️ Важно закрыть bottom sheet перед диалогом
                    // Показываем диалог подтверждения перед удалением
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
    // Закрываем предыдущий bottom sheet
    Navigator.of(context).pop();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Подтвердить удаление'),
            content: const Text('Вы уверены, что хотите удалить эту статью?'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Закрываем диалог
                },
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

  void _navigateToEditProfile() async {
    if (_profileData == null) return;

    // 1. Передаем текущие данные и функцию обновления
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => EditProfileScreen(
              initialUserData:
                  _profileData!['user_data'] as Map<String, dynamic>,
              // Обновляем состояние профиля напрямую
              onProfileUpdated: (newUserData) {
                if (mounted) {
                  setState(() {
                    _profileData!['user_data'] = newUserData;
                  });
                }
              },
            ),
      ),
    );

    // ✅ Перезагружаем все данные профиля после возвращения.
    await _loadProfileData();
  }

  void _navigateToSubscriptionList(String initialTab) {
    if (_profileData == null) return;

    // Получаем ID пользователя, чей профиль мы смотрим
    final userId = _profileData!['user_data']['id'] as int;
    final username = _profileData!['user_data']['username'] as String;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => SubscriptionsSubscriberListScreen(
              profileUserId: userId,
              profileUsername: username,
              initialTab: initialTab,
              // Передаем колбэк для обновления статистики
              onUpdate: _loadProfileData,
            ),
      ),
    );
  }

  Future<void> _loadProfileData() async {
    final sp = await SharedPreferences.getInstance();
    currentUserId = sp.getInt('userId');

    print(
      'DEBUG: [UserProfileScreen] Current User ID (key: userId): $currentUserId',
    );

    setState(() {
      _isLoading = true;
    });

    final data = await _subscriptionService.fetchUserProfile(
      widget.profileUserId,
    );

    if (data != null && mounted) {
      setState(() {
        _profileData = data;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleFollowToggle() async {
    if (_profileData == null) return;

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
      setState(() {
        _isLoading = false;
      });
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

  Widget _buildStatColumn(String label, int count) {
    // Для "Статей" не делаем кликабельным
    if (label == "Статей") {
      return NeoContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              count.toString(),
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

    // Для "Подписчиков" и "Подписок" делаем кликабельным
    String tabName = label == "Подписчиков" ? 'followers' : 'following';

    return GestureDetector(
      onTap: () => _navigateToSubscriptionList(tabName),
      child: NeoContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              count.toString(),
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

  // Список историй с обработкой долгого нажатия
  Widget _buildExpandableStoryList(List<Story> stories, bool isMyProfile) {
    return Column(
      children:
          stories.map((story) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              // ✅ GESTUREDETECTOR для обработки onTap (открыть) и onLongPress (опции)
              child: GestureDetector(
                onTap: () {
                  // Здесь ваша навигация на экран истории
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (context) => UserStoryFeedScreen(
                            stories: stories,
                            initialIndex: 0,
                          ),
                    ),
                  );
                },
                // ✅ Логика для долгого нажатия: показываем опции, только если это свой профиль
                onLongPress:
                    isMyProfile ? () => _showStoryOptionsDialog(story) : null,

                child: ListTile(
                  title: Text(
                    story.title,
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
        bottomNavigationBar: p.PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(),
      );
    }

    if (_profileData == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Не удалось загрузить профиль. Повторить?"),
              ElevatedButton(
                onPressed: _loadProfileData,
                child: const Text("Обновить"),
              ),
            ],
          ),
        ),
        bottomNavigationBar: p.PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(),
      );
    }

    final userData = _profileData!['user_data'];
    final stats = _profileData!['stats'];
    final storiesData = _profileData!['stories'] as List;

    final profileId = userData['id'] as int?;

    // ✅ Определение, является ли это профиль текущего пользователя
    final isMyProfile =
        (currentUserId != null &&
            profileId != null &&
            currentUserId == profileId);
    final isFollowing = _profileData!['is_following'] as bool? ?? false;

    final userStories =
        storiesData.map((json) => Story.fromJson(json)).toList();

    // Вычисляем полное имя, никнейм и URL аватара
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
                    _buildStatColumn("Статей", stats['stories_count'] ?? 0),
                    _buildStatColumn(
                      "Подписчиков",
                      stats['followers_count'] ?? 0,
                    ),
                    _buildStatColumn("Подписок", stats['following_count'] ?? 0),
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
                // ...
              },
            ),
            // ...
          ],
        ),
      ),
    );
  }
}
