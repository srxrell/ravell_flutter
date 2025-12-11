import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:readreels/models/notification.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationManager extends ChangeNotifier {
  final List<NotificationItem> _notifications = [];

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  NotificationManager(this.flutterLocalNotificationsPlugin);

  UnmodifiableListView<NotificationItem> get notifications =>
      UnmodifiableListView(_notifications);

  void addNotification(NotificationItem item) {
    _notifications.insert(0, item); // новые сверху
    notifyListeners();

    // системное уведомление
    flutterLocalNotificationsPlugin.show(
      0,
      item.title,
      item.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'channel_id',
          'channel_name',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }
}
