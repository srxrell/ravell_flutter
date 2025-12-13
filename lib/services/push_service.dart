// import 'dart:convert';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';

// class PushService {
//   static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

//   static Future<void> init() async {
//     // 1. Разрешения (Android сам разрешает, но пусть будет)
//     await _messaging.requestPermission();

//     // 2. Получаем токен
//     final token = await _messaging.getToken();
//     print("FCM TOKEN: $token");

//     if (token != null) {
//       await _saveTokenToBackend(token);
//     }
//   }

//   static Future<void> _saveTokenToBackend(String token) async {
//     final prefs = await SharedPreferences.getInstance();
//     final access = prefs.getString('access_token');
//     if (access == null) return;

//     final url = Uri.parse(
//       'https://ravell-backend-1.onrender.com/users/save-player',
//     );

//     final res = await http.post(
//       url,
//       headers: {
//         'Authorization': 'Bearer $access',
//         'Content-Type': 'application/json',
//       },
//       body: jsonEncode({'player_id': token}),
//     );

//     print("SAVE TOKEN STATUS: ${res.statusCode}");
//     print("SAVE TOKEN BODY: ${res.body}");
//   }
// }
