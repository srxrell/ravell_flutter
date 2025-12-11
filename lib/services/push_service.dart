import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketPushService {
  static final WebSocketPushService instance = WebSocketPushService._();
  WebSocketPushService._();

  late WebSocketChannel channel;
  final _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init({required int userId, required String token}) async {
    // notifications
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _notifications.initialize(settings);

    // websocket с токеном и userId
    final uri = Uri.parse(
      "wss://ravell-backend-1.onrender.com/ws?user_id=$userId&token=$token",
    );

    channel = IOWebSocketChannel.connect(uri);

    channel.stream.listen((msg) {
      final data = jsonDecode(msg);
      if (data['type'] == 'follow') {
        showNotification(
          "Новый подписчик!",
          "${data['from_username']} подписался на вас",
        );
      }
      if (data['type'] == 'reply') {
        showNotification(
          "Новый ответ",
          "${data['from_username']} ответил на вашу историю",
        );
      }
    });
  }

  void sendToUser(int targetUserId, String message) {
    final payload = jsonEncode({
      "type": "follow",
      "target_id": targetUserId,
      "from_username": message,
    });
    channel.sink.add(payload);
  }

  Future<void> showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'main_channel',
      'Main Channel',
      importance: Importance.high,
      priority: Priority.high,
    );

    const platformDetails = NotificationDetails(android: androidDetails);
    await _notifications.show(0, title, body, platformDetails);
  }
}
