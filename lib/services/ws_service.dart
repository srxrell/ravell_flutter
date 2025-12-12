import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/activity_event.dart';
import 'activity_service.dart';
import '../main.dart'; // для navigatorKey

class WebSocketPushService {
  WebSocketPushService._internal();
  static final WebSocketPushService instance = WebSocketPushService._internal();

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  int? _userId;
  String? _token;
  bool _isReconnecting = false;

  final StreamController<Map<String, dynamic>> _messageStreamController =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get messageStream =>
      _messageStreamController.stream;

  void init({required int userId, required String token}) {
    _userId = userId;
    _token = token;
    _connect();
  }

  void _connect() {
    if (_userId == null || _token == null) return;

    final uri = Uri.parse(
      'wss://ravell-backend-1.onrender.com/ws?user_id=$_userId&token=$_token',
    );
    _channel =
        kIsWeb
            ? WebSocketChannel.connect(uri)
            : IOWebSocketChannel.connect(uri);

    _channel?.stream.listen(
      (msg) {
        _isConnected = true;
        _reconnectTimer?.cancel();
        _isReconnecting = false;

        try {
          final data = jsonDecode(msg) as Map<String, dynamic>;
          _messageStreamController.add(data);

          _handleIncomingMessage(data);
        } catch (e) {
          debugPrint('WS decode error: $e');
        }
      },
      onError: (error) {
        _isConnected = false;
        debugPrint('WebSocket error: $error');
        _reconnect();
      },
      onDone: () {
        _isConnected = false;
        debugPrint('WebSocket closed.');
        _reconnect();
      },
    );

    _channel?.sink.add(jsonEncode({'type': 'connection_established'}));
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    final type = data['type'] ?? 'unknown';
    final username = data['username'] ?? 'Система';
    final timestamp =
        data['timestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] * 1000)
            : DateTime.now();

    // Добавляем в ActivityService
    ActivityService.instance.addEvent(
      ActivityEvent(type: type, username: username, timestamp: timestamp),
    );

    // Показываем тост
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            type == 'follow'
                ? '$username подписался на вас'
                : '$username ответил на вашу историю',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _reconnect() {
    if (!_isReconnecting) {
      _isReconnecting = true;
      _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (_isConnected) {
          timer.cancel();
          return;
        }
        debugPrint('Attempting WS reconnect...');
        _connect();
      });
    }
  }

  void sendToUser(int userId, String message) {
    if (_channel?.sink == null || !_isConnected) {
      debugPrint('WS not connected. Cannot send message.');
      return;
    }
    _channel?.sink.add(
      jsonEncode({
        'action': 'send_to_user',
        'user_id': userId,
        'message': message,
      }),
    );
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _messageStreamController.close();
    _isConnected = false;
    _isReconnecting = false;
  }
}
