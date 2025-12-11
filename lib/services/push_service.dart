import 'dart:convert';
import 'package:delightful_toast/toast/components/toast_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:readreels/models/activity_event.dart';
import 'package:readreels/services/activity_service.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:delightful_toast/delight_toast.dart';
import '../main.dart'; // чтобы видеть navigatorKey

// ws_service.dart
class WebSocketPushService {
  static final WebSocketPushService instance = WebSocketPushService._();
  WebSocketPushService._();

  late WebSocketChannel channel;
  final _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init({required int userId, required String token}) async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _notifications.initialize(settings);

    final uri = Uri.parse(
      "wss://ravell-backend-1.onrender.com/ws?user_id=$userId&token=$token",
    );
    channel = IOWebSocketChannel.connect(uri);

    channel.stream.listen((msg) {
      final data = jsonDecode(msg);

      String text;
      if (data['type'] == 'follow') {
        text = "${data['from_username']} подписался на вас";
        final event = ActivityEvent(
          type: data['type'],
          username: data['from_username'],
          timestamp: DateTime.now(),
        );
        ActivityService.instance.addEvent(event);
      } else if (data['type'] == 'reply') {
        text = "${data['from_username']} ответил на вашу историю";
        final event = ActivityEvent(
          type: data['type'],
          username: data['from_username'],
          timestamp: DateTime.now(),
        );
        ActivityService.instance.addEvent(event);
      } else {
        return;
      }

      final context = navigatorKey.currentContext;
      if (context != null) {
        DelightToastBar(
          builder:
              (ctx) => ToastCard(
                leading: const Icon(Icons.flutter_dash, size: 28),
                title: Text(
                  text,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
        ).show(context);
      }
    });
  }

  /// ✅ Отправка пуша через WS конкретному пользователю
  void sendToUser(int userId, String message) {
    final payload = jsonEncode({
      'action': 'send_to_user',
      'user_id': userId,
      'message': message,
    });

    try {
      channel.sink.add(payload);
      debugPrint('🔹 Push отправлен пользователю $userId: $message');
    } catch (e) {
      debugPrint('❌ Ошибка при отправке push: $e');
    }
  }
}
