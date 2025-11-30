import 'package:readreels/screens/add_story.dart';
import 'package:readreels/screens/feed.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:readreels/screens/authentication.dart';
import 'package:readreels/screens/profile_screen.dart';
import 'package:readreels/screens/search.dart';
import 'package:readreels/theme.dart';
import 'package:readreels/widgets/profile_stories_list.dart';

class ReadReelsApp extends StatefulWidget {
  const ReadReelsApp({super.key});

  @override
  State<ReadReelsApp> createState() => _ReadReelsAppState();
}

class _ReadReelsAppState extends State<ReadReelsApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: "ReadReels App",
      theme: fullNeoBrutalismTheme,
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: "/",
            builder: (context, state) => const AuthenticationScreen(),
          ),
          GoRoute(path: '/home', builder: (context, state) => const Feed()),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchStory(),
          ),
          GoRoute(
            path: '/profile/:user_id', // Маршрут с обязательным параметром ID
            builder: (context, state) {
              final user_id = int.parse(state.pathParameters['user_id']!);
              return UserProfileScreen(profileuser_id: user_id);
            },
          ),
          GoRoute(
            path: '/addStory',
            builder: (context, state) {
              return const CreateStoryScreen();
            },
          ),
          GoRoute(
            path: '/story/:storyId',
            builder: (context, state) {
              final storyId = int.parse(state.pathParameters['storyId']!);

              // Извлекаем authorId из query parameters: /story/123?authorId=45
              final authorIdStr = state.uri.queryParameters['authorId'];
              final authorId =
                  authorIdStr != null ? int.tryParse(authorIdStr) : null;

              if (authorId == null) {
                return const Scaffold(
                  body: Center(
                    child: Text('Ошибка: Не удалось найти ID автора.'),
                  ),
                );
              }
              // NOTE: Замените 'StoryDetailScreen' на ваш фактический виджет
              return UserStoryFeedLoaderScreen(
                initialStoryId: storyId,
                authorId: authorId,
              );
            },
          ),
        ],
      ),
    );
  }
}
