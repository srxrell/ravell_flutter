import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:readreels/services/ws_service.dart';
import 'readreels.dart';

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
  // Локальные уведомления
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await initNotifications(flutterLocalNotificationsPlugin);

  // WebSocket
  final wsService = WSService();
  try {
    await wsService.connect();
    print('✅ WebSocket connected');
  } catch (e, st) {
    print('⚠️ WebSocket connection failed: $e');
    print(st);
  }
}

Future<void> initNotifications(FlutterLocalNotificationsPlugin plugin) async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await plugin.initialize(initializationSettings);
}
