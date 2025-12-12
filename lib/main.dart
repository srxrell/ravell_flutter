import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:readreels/screens/activity_screen.dart';
import 'package:readreels/screens/add_story.dart';
import 'package:readreels/screens/authentication.dart';
import 'package:readreels/screens/dart_auth_check.dart';
import 'package:readreels/screens/feed.dart';
import 'package:readreels/screens/profile_screen.dart';
import 'package:readreels/screens/search.dart';
import 'package:readreels/services/push_service.dart';
import 'package:readreels/theme.dart';
import 'package:readreels/widgets/profile_stories_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/ws_service.dart' as p;
import 'services/subscription_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runZonedGuarded(
    () {
      runApp(const ReadReelsApp()); // UI стартует сразу
      initServices(); // Асинхронная инициализация фоново
    },
    (error, stackTrace) {
      print('🚨 CRASH: $error');
      print('Stack trace: $stackTrace');
    },
  );
}

/// Асинхронная инициализация сервисов
Future<void> initServices() async {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await initNotifications(flutterLocalNotificationsPlugin);
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('access_token');
  final userId = prefs.getInt('user_id');
  await WebSocketPushService.instance.init(userId: userId!, token: token!);
}

Future<void> initNotifications(FlutterLocalNotificationsPlugin plugin) async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await plugin.initialize(initializationSettings);
}

class ReadReelsApp extends StatefulWidget {
  const ReadReelsApp({super.key});

  @override
  State<ReadReelsApp> createState() => _ReadReelsAppState();
}

class _ReadReelsAppState extends State<ReadReelsApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: "ReadReels App",
      key: navigatorKey,
      theme: fullNeoBrutalismTheme,
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: "/",
            builder: (context, state) => const AuthCheckerScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const ActivityScreen(),
          ),
          GoRoute(
            path: "/login",
            builder: (context, state) => AuthenticationScreen(),
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
              return UserProfileScreen(profileUserId: user_id);
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
