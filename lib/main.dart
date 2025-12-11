import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:readreels/services/push_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/ws_service.dart';
import 'readreels.dart';
import 'services/subscription_service.dart';

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
