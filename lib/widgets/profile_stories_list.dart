import 'package:flutter/material.dart';
import 'package:readreels/models/story.dart';
import 'package:readreels/services/subscription_service.dart'; // Для получения профиля
import 'package:readreels/screens/search_feed.dart'; // Ваш существующий Feed для прокрутки

class UserStoryFeedLoaderScreen extends StatefulWidget {
  final int initialStoryId;
  final int authorId; // <<< ID АВТОРА ИСТОРИИ

  const UserStoryFeedLoaderScreen({
    super.key,
    required this.initialStoryId,
    required this.authorId,
  });

  @override
  State<UserStoryFeedLoaderScreen> createState() =>
      _UserStoryFeedLoaderScreenState();
}

class _UserStoryFeedLoaderScreenState extends State<UserStoryFeedLoaderScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  List<Story> _stories = [];
  bool _isLoading = true;
  int _initialIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAuthorStories();
  }

  Future<void> _loadAuthorStories() async {
    try {
      // 1. Загружаем данные профиля автора (которые содержат список его историй)
      final profileData = await _subscriptionService.fetchUserProfile(
        widget.authorId,
      );

      if (profileData == null || !profileData.containsKey('stories')) {
        throw Exception("Failed to load profile or stories data.");
      }

      // 2. Получаем список историй автора
      final storiesData = profileData['stories'] as List;
      final authorStories =
          storiesData.map((json) => Story.fromJson(json)).toList();

      // 3. Находим индекс выбранной истории
      int index = authorStories.indexWhere(
        (s) => s.id == widget.initialStoryId,
      );

      if (index == -1) {
        // На случай, если история была удалена, но ID все еще где-то остался
        index = 0;
      }

      if (mounted) {
        setState(() {
          _stories = authorStories;
          _initialIndex = index;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Вывод ошибки в консоль
        debugPrint("Error loading author stories for feed: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_stories.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("Нет историй для этого пользователя.")),
      );
    }

    // Передаем весь список историй автора и начальный индекс в SearchFeed
    return SearchFeed(stories: _stories, initialIndex: _initialIndex);
  }
}
