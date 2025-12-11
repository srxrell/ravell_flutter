import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_manager.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final NotificationManager notificationManager = NotificationManager(
  flutterLocalNotificationsPlugin,
);
