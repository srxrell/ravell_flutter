// services/push_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> sendPushOnServer({
  required int userId,
  required String title,
  required String message,
}) async {
  final response = await http.post(
    Uri.parse('https://ravell-backend-1.onrender.com/send-ws-notification'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'user_id': userId, 'title': title, 'body': message}),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to send WS notification: ${response.body}');
  }
}
