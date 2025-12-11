import 'package:flutter/material.dart';
import 'package:readreels/screens/profile_screen.dart';
import 'package:readreels/services/subscription_service.dart';
import 'package:readreels/widgets/bottom_nav_bar_liquid.dart' as p;

class SubscriptionsSubscriberListScreen extends StatefulWidget {
  final int profileuser_id;
  final String profileUsername;
  final String initialTab; // 'followers' или 'following'
  final VoidCallback onUpdate;

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
              _UserListWidget(
                fetchList:
                    () => _subscriptionService.fetchFollowers(
                      widget.profileuser_id,
                    ),
                subscriptionService: _subscriptionService,
                onActionComplete: widget.onUpdate,
                currentuser_id: currentuser_id,
                isFollowersList: true,
              ),
              _UserListWidget(
                fetchList:
                    () => _subscriptionService.fetchFollowing(
                      widget.profileuser_id,
                    ),
                subscriptionService: _subscriptionService,
                onActionComplete: widget.onUpdate,
                currentuser_id: currentuser_id,
                isFollowersList: false,
              ),
            ],
          ),
          bottomNavigationBar: const p.PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(),
        );
      },
    );
  }
}

class _UserListWidget extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function() fetchList;
  final SubscriptionService subscriptionService;
  final VoidCallback onActionComplete;
  final int? currentuser_id;
  final bool isFollowersList; // <-- добавили

  const _UserListWidget({
    required this.fetchList,
    required this.subscriptionService,
    required this.onActionComplete,
    required this.currentuser_id,
    required this.isFollowersList,
  });

  @override
  State<_UserListWidget> createState() => _UserListWidgetState();
}

class _UserListWidgetState extends State<_UserListWidget> {
  late Future<List<Map<String, dynamic>>> _listFuture;
  List<int> _followingIds = [];

  @override
  void initState() {
    super.initState();
    _initFollowingIds();
    _listFuture = _fetchSafeList();
  }

  Future<void> _initFollowingIds() async {
    if (widget.currentuser_id != null) {
      try {
        final following = await widget.subscriptionService.fetchFollowing(
          widget.currentuser_id!,
        );
        _followingIds =
            following
                .map((e) => int.tryParse(e['user']['id'].toString()) ?? 0)
                .toList();
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint('Ошибка fetchFollowing для определения isFollowing: $e');
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSafeList() async {
    try {
      final result = await widget.fetchList();
      if (!mounted) return [];
      return result ?? [];
    } catch (e) {
      debugPrint('Ошибка fetchList: $e');
      return [];
    }
  }

  void _refreshList() {
    if (!mounted) return;
    setState(() {
      _listFuture = _fetchSafeList();
    });
  }

  Future<void> _handleFollowToggle(int userIdToToggle) async {
    if (widget.currentuser_id == null || widget.currentuser_id == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Для подписки требуется авторизация.')),
      );
      return;
    }

    try {
      final result = await widget.subscriptionService.toggleFollow(
        userIdToToggle,
      );
      if (!mounted) return;
      // Обновляем список подписок после действия
      await _initFollowingIds();
      _refreshList();
      widget.onActionComplete();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    } catch (e) {
      if (!mounted) return;
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

        final users = snapshot.data ?? [];

        if (users.isEmpty) {
          return const Center(child: Text("Список пуст."));
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userEntry = users[index];
            final userData = (userEntry['user'] as Map<String, dynamic>?) ?? {};

            final userId = int.tryParse(userData['id']?.toString() ?? '') ?? 0;
            final username = userData['username']?.toString() ?? '';
            // Проверяем по списку подписок
            final isFollowing =
                widget.isFollowersList ? _followingIds.contains(userId) : true;

            final firstName = userData['first_name']?.toString() ?? '';
            final lastName = userData['last_name']?.toString() ?? '';
            final displayTitle =
                (firstName + ' ' + lastName).trim().isNotEmpty
                    ? (firstName + ' ' + lastName).trim()
                    : username;

            final isCurrentUser =
                widget.currentuser_id != null &&
                widget.currentuser_id == userId;

            return ListTile(
              leading: CircleAvatar(
                backgroundImage:
                    userData['avatar'] != null && userData['avatar'].isNotEmpty
                        ? NetworkImage(userData['avatar'])
                        : null,
                child:
                    userData['avatar'] == null || userData['avatar'].isEmpty
                        ? const Icon(Icons.person)
                        : null,
              ),
              title: Text(displayTitle),
              subtitle: Text('@$username'),
              trailing:
                  isCurrentUser
                      ? const SizedBox.shrink()
                      : ElevatedButton(
                        onPressed: () => _handleFollowToggle(userId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isFollowing ? Colors.grey : Colors.black,
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
              onTap: () {
                // Переход на профиль выбранного пользователя
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (context) => UserProfileScreen(profileUserId: userId),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
