import 'dart:convert';
import 'package:readreels/models/notification.dart';
import 'package:readreels/services/globals.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class WSService {
  late IOWebSocketChannel channel;

  Future<void> initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> connect() async {
    await initNotifications();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return;

    final socket = await WebSocket.connect(
      'wss://ravell-backend-1.onrender.com/ws',
      headers: {'Authorization': 'Bearer $token'},
    );

    channel = IOWebSocketChannel(socket);

    channel.stream.listen(
      (message) {
        final data = jsonDecode(message);

        final notification = NotificationItem(
          title: data['title'],
          body: data['body'],
          timestamp: DateTime.now(),
        );

        // ✅ Добавляем в экран активности
        notificationManager.addNotification(notification);

        // ✅ Локальное уведомление
        flutterLocalNotificationsPlugin.show(
          0,
          data['title'],
          data['body'],
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'channel_id',
              'channel_name',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      },
      onDone: () {
        print("WS connection closed");
      },
      onError: (error) {
        print("WS error: $error");
      },
    );
  }

  void disconnect() {
    channel.sink.close();
  }
}
