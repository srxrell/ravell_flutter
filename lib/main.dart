import 'dart:async';
// import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:readreels/screens/activity_screen.dart';
import 'package:readreels/screens/add_story.dart';
import 'package:readreels/screens/create_draft_screeen.dart';
import 'package:readreels/screens/authentication.dart';
import 'package:readreels/screens/credits_screen.dart';
import 'package:readreels/screens/dart_auth_check.dart';
import 'package:readreels/screens/feed.dart';
import 'package:readreels/screens/influencers_board.dart';
import 'package:readreels/screens/onboarding_screen.dart';
import 'package:readreels/screens/profile_screen.dart';
import 'package:readreels/screens/search.dart';
import 'package:readreels/screens/splash_screen.dart';
import 'package:readreels/screens/streak_screen.dart';
import 'package:readreels/services/influencer_service.dart';
// import 'package:readreels/services/push_service.dart';
import 'package:readreels/theme.dart';
import 'package:readreels/widgets/profile_stories_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'services/ws_service.dart' as p;
import "package:dart_openai/dart_openai.dart";
// import 'services/subscription_service.dart';
import 'package:readreels/managers/settings_manager.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // await Firebase.initializeApp();

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      OpenAI.showLogs = true;
      const String apiKey = String.fromEnvironment(
        'OPENAI_KEY', 
        defaultValue: '',
      );
      OpenAI.apikey = apiKey;
      
      final settingsManager = SettingsManager();
      
      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settingsManager),
          ],
          child: const ReadReelsApp(),
        ),
      ); 
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
  // PushService.init();
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
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      navigatorKey: navigatorKey,
      routes: [
        GoRoute(
          path: "/",
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: "/onboarding",
          builder: (context, state) => const OnBoardingScreen(),
        ),
        GoRoute(
          path: '/auth-check',
          builder: (context, state) => const AuthCheckerScreen(),
        ),
        GoRoute(
          path: "/credits",
          builder: (context, state) => const CreditsScreen(),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const ActivityScreen(),
        ),
        GoRoute(
          path: "/login",
          builder: (context, state) => const AuthenticationScreen(),
        ),
        GoRoute(path: '/home', builder: (context, state) => const Feed()),
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchStory(),
        ),
        GoRoute(
          path: '/profile/:user_id',
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
          path: '/addStoryDraft',
          builder: (context, state) {
            return CreateStoryFromDraftScreen();
          },
        ),
        GoRoute(
          path: '/streak',
          builder: (context, state) => const StreakScreen(),
        ),
        GoRoute(
          path: '/story/:storyId',
          builder: (context, state) {
            final storyId = int.parse(state.pathParameters['storyId']!);
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
            return UserStoryFeedLoaderScreen(
              initialStoryId: storyId,
              authorId: authorId,
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: (context) => MaterialApp.router(
        title: "ReadReels App",
        routerConfig: _router,
        theme: fullNeoBrutalismTheme,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
