// services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'https://ravell-backend-1.onrender.com';

  // --- 1. Вспомогательные методы ---

  /// Сохраняет Access и Refresh токены, а также ID пользователя.
  Future<void> _saveAuthData(
    String accessToken,
    String refreshToken,
    int user_id,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
    await prefs.setInt('user_id', user_id);
    // Убираем pending_user_id так как OTP больше нет
    await prefs.remove('pending_user_id');
  }

  /// Читает токен доступа.
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// Читает Refresh токен.
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  /// Проверяет, аутентифицирован ли пользователь.
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('access_token') != null &&
        prefs.getString('refresh_token') != null &&
        prefs.getInt('user_id') != null &&
        prefs.getInt('user_id') != 0);
  }

  // --- 2. Регистрация (Sign Up) - БЕЗ OTP ---

  /// Регистрирует нового пользователя и сразу логинит
  Future<bool> register(String username, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'), // 🟢 ИСПРАВЛЕННЫЙ URL (без /api/auth/)
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 201) {
      final data = json.decode(utf8.decode(response.bodyBytes));

      // 🟢 ТЕПЕРЬ СРАЗУ ПОЛУЧАЕМ ТОКЕНЫ ПРИ РЕГИСТРАЦИИ
      final tokens = data['tokens'];
      final user_id = data['user_id'];

      if (tokens != null && user_id != null) {
        final accessToken = tokens['access_token'];
        final refreshToken = tokens['refresh_token'];

        await _saveAuthData(accessToken, refreshToken, user_id);
        return true;
      } else {
        throw Exception(
          'В ответе сервера отсутствуют токены или ID пользователя',
        );
      }
    } else if (response.statusCode == 400) {
      final errorData = json.decode(utf8.decode(response.bodyBytes));
      String error = _formatError(errorData);
      throw Exception(error);
    } else {
      throw Exception(
        'Неизвестная ошибка регистрации. Статус: ${response.statusCode}',
      );
    }
  }

  // --- 3. Вход (Log In) ---

  /// Осуществляет вход и получает токены.
  Future<bool> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'), // 🟢 ИСПРАВЛЕННЫЙ URL (без /api/auth/)
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final tokens = data['tokens'];
      final user_id = data['user_id'];

      final accessToken = tokens['access_token'];
      final refreshToken = tokens['refresh_token'];

      if (accessToken == null || refreshToken == null) {
        throw Exception('В ответе сервера отсутствуют токены.');
      }

      await _saveAuthData(accessToken, refreshToken, user_id);
      return true;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      final errorData = json.decode(utf8.decode(response.bodyBytes));
      String error = errorData['error'] ?? 'Ошибка входа.';
      throw Exception(error);
    } else {
      throw Exception(
        'Неизвестная ошибка входа. Статус: ${response.statusCode}',
      );
    }
  }

  // --- 4. Обновление токена ---

  Future<void> refreshToken() async {
    final refreshToken = await getRefreshToken();

    if (refreshToken == null) {
      await logout();
      throw Exception('REFRESH_TOKEN_MISSING');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/refresh-token'), // 🟢 ИСПРАВЛЕННЫЙ URL
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final prefs = await SharedPreferences.getInstance();

      final tokens = data['tokens'];
      await prefs.setString('access_token', tokens['access_token']);

      if (tokens.containsKey('refresh_token')) {
        await prefs.setString('refresh_token', tokens['refresh_token']);
      }
    } else {
      await logout();
      throw Exception('Failed to refresh token. Login required.');
    }
  }

  // --- 5. Выход (Log Out) ---

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_id');
    await prefs.remove('pending_user_id');
  }

  // --- 6. Парсинг ошибок ---

  String _formatError(Map<String, dynamic> errorData) {
    String error = '';
    errorData.forEach((key, value) {
      if (value is List) {
        error += '${key.toUpperCase()}: ${value.join(', ')}. ';
      } else {
        error += '$key: $value. ';
      }
    });
    return error.trim();
  }
}
