import 'package:flutter/material.dart';
import 'package:readreels/services/subscription_service.dart';
import 'package:readreels/widgets/bottom_nav_bar_liquid.dart' as p;

class SubscriptionsSubscriberListScreen extends StatefulWidget {
  final int profileuser_id;
  final String profileUsername;
  final String initialTab; // 'followers' или 'following'
  final VoidCallback onUpdate; // Колбэк для обновления статистики в профиле

  const SubscriptionsSubscriberListScreen({
    super.key,
    required this.profileuser_id,
    required this.profileUsername,
    required this.initialTab,
    required this.onUpdate,
  });

  @override
  State<SubscriptionsSubscriberListScreen> createState() =>
      _SubscriptionsSubscriberListScreenState();
}

class _SubscriptionsSubscriberListScreenState
    extends State<SubscriptionsSubscriberListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SubscriptionService _subscriptionService = SubscriptionService();

  @override
  void initState() {
    super.initState();
    // Определяем начальный индекс для TabBar
    final initialIndex = widget.initialTab == 'following' ? 1 : 0;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ВАЖНО: Мы загружаем ID текущего пользователя здесь,
    // чтобы не делать это в каждом ListTile
    return FutureBuilder<int?>(
      future: _subscriptionService.getUserId(),
      builder: (context, currentuser_idSnapshot) {
        final currentuser_id = currentuser_idSnapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.profileUsername),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [Tab(text: 'Подписчики'), Tab(text: 'Подписки')],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Вкладка 1: Подписчики
              _UserListWidget(
                fetchList:
                    () => _subscriptionService.fetchFollowers(
                      widget.profileuser_id,
                    ),
                subscriptionService: _subscriptionService,
                onActionComplete: widget.onUpdate,
                currentuser_id: currentuser_id, // ✅ ПЕРЕДАЕМ ID
              ),
              // Вкладка 2: Подписки
              _UserListWidget(
                fetchList:
                    () => _subscriptionService.fetchFollowing(
                      widget.profileuser_id,
                    ),
                subscriptionService: _subscriptionService,
                onActionComplete: widget.onUpdate,
                currentuser_id: currentuser_id, // ✅ ПЕРЕДАЕМ ID
              ),
            ],
          ),
          bottomNavigationBar: const p.PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(),
        );
      },
    );
  }
}

// --- Вспомогательный виджет для отображения списка пользователей ---
class _UserListWidget extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function() fetchList;
  final SubscriptionService subscriptionService;
  final VoidCallback onActionComplete;
  final int? currentuser_id; // ID текущего авторизованного пользователя

  const _UserListWidget({
    required this.fetchList,
    required this.subscriptionService,
    required this.onActionComplete,
    required this.currentuser_id, // ✅ ИСПОЛЬЗУЕМ ПЕРЕДАННЫЙ ID
  });

  @override
  State<_UserListWidget> createState() => _UserListWidgetState();
}

class _UserListWidgetState extends State<_UserListWidget> {
  late Future<List<Map<String, dynamic>>> _listFuture;

  @override
  void initState() {
    super.initState();
    _listFuture = widget.fetchList();
  }

  // ✅ ПЕРЕЗАПУСК Future при необходимости (например, после обновления профиля)
  void _refreshList() {
    setState(() {
      _listFuture = widget.fetchList();
    });
  }

  // --- Обработчик подписки/отписки в списке ---
  Future<void> _handleFollowToggle(int user_idToToggle) async {
    if (widget.currentuser_id == null) {
      // Это должно быть проверено раньше, но на всякий случай
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Для подписки требуется авторизация.')),
      );
      return;
    }

    try {
      final result = await widget.subscriptionService.toggleFollow(
        user_idToToggle,
      );

      // Перезагружаем список и обновляем статистику в профиле
      if (mounted) {
        _refreshList(); // Перезапуск загрузки списка
        widget.onActionComplete(); // Уведомляем экран профиля об изменении
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _listFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Ошибка загрузки: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("Список пуст."));
        }

        final users = snapshot.data!;

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userEntry = users[index];
            final userData = userEntry['user'] as Map<String, dynamic>;
            final user_id = userData['id'] as int;
            final username = userData['username'] as String;
            final isFollowing = userEntry['is_following'] as bool;

            // Определяем полное имя
            final firstName = userData['first_name'] as String? ?? '';
            final lastName = userData['last_name'] as String? ?? '';
            final fullName = '${firstName} ${lastName}'.trim();
            final displayTitle = fullName.isNotEmpty ? fullName : username;

            // Проверка, является ли этот пользователь текущим авторизованным пользователем
            final isCurrentUser =
                (widget.currentuser_id != null &&
                    widget.currentuser_id == user_id);

            return ListTile(
              // Навигация на профиль при тапе на ListTile (опционально)
              // onTap: () => context.go('/profile/$user_id'),
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(displayTitle),
              subtitle: Text('@$username'),
              trailing:
                  isCurrentUser
                      ? const SizedBox.shrink() // Не показываем кнопку, если это наш профиль
                      : ElevatedButton(
                        onPressed: () => _handleFollowToggle(user_id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isFollowing ? Colors.grey : Colors.blue,
                          minimumSize: const Size(100, 35),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: Text(
                          isFollowing ? 'Отписаться' : 'Подписаться',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
            );
          },
        );
      },
    );
  }
}
