// lib/services/auth_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // ⚠️ Убедитесь, что эта константа верна для вашего бэкенда.
  static const String baseUrl =
      'https://ravell-backend.onrender.com'; // Для Android Emulator

  // --- 1. Вспомогательные методы (Добавлены getRefreshToken, isLoggedIn) ---

  /// Сохраняет Access и Refresh токены, а также ID пользователя.
  Future<void> _saveAuthData(
    String accessToken,
    String refreshToken,
    int userId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refreshToken', refreshToken);
    await prefs.setInt('userId', userId);
    // Очищаем временное имя пользователя
    await prefs.remove('pendingUsername');
  }

  /// Читает токен доступа.
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// Читает Refresh токен.
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refreshToken');
  }

  // 🟢 ДОБАВЛЕНО: Проверяет, аутентифицирован ли пользователь.
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    // Считаем пользователя залогиненным, если есть токены и ID.
    return (prefs.getString('access_token') != null &&
        prefs.getString('refreshToken') != null &&
        prefs.getInt('userId') != null &&
        prefs.getInt('userId') != 0);
  }

  // --- 2. Регистрация (Sign Up) ---

  /// Регистрирует нового пользователя и отправляет OTP.
  Future<void> register(String username, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 201) {
      final prefs = await SharedPreferences.getInstance();
      // Сохраняем имя пользователя для верификации
      await prefs.setString('pendingUsername', username);
      return;
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

  // --- 3. Верификация OTP (Получение первых токенов) ---

  /// Верифицирует OTP-код, получает токены и завершает аутентификацию.
  Future<String?> verifyOtp(String otpCode) async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('pendingUsername');

    if (username == null) {
      throw Exception(
        'Имя пользователя для верификации не найдено. Начните регистрацию заново.',
      );
    }

    final response = await http.post(
      Uri.parse('$baseUrl/verify-otp/'), // URL верификации
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'otp': otpCode, 'username': username}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      // 🔑 АУТЕНТИФИКАЦИЯ: Сохраняем токены и ID
      await _saveAuthData(data['access'], data['refresh'], data['user_id']);
      return data['detail'] ?? 'Аккаунт успешно верифицирован!';
    } else if (response.statusCode == 400 || response.statusCode == 404) {
      final errorData = json.decode(utf8.decode(response.bodyBytes));
      String error =
          errorData['error'] ?? errorData['detail'] ?? 'Ошибка верификации.';
      throw Exception(error);
    } else {
      throw Exception(
        'Неизвестная ошибка верификации. Статус: ${response.statusCode}',
      );
    }
  }

  // --- 4. Вход (Log In) ---

  /// Осуществляет вход и получает токены (если верифицирован).
  Future<bool> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login/'), // URL входа
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      int userId =
          data['user_id'] ??
          100; // ⚠️ ВАЖНО: Вашему бэкенду нужно возвращать user_id
      final accessToken = data['access'];
      final refreshToken = data['refresh'];

      if (accessToken == null || refreshToken == null) {
        throw Exception(
          'В ответе сервера отсутствуют токены (access/refresh).',
        );
      }

      // Если токены есть, сохраняем их
      await _saveAuthData(accessToken, refreshToken, userId);
      return true;
    } else if (response.statusCode == 401) {
      final errorData = json.decode(utf8.decode(response.bodyBytes));
      String error = errorData['detail'] ?? 'Ошибка входа.';

      // 🛑 Обнаружение неверифицированного аккаунта
      if (error.contains('Account is not verified') ||
          error.contains('не верифицирован')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pendingUsername', username);
        throw Exception('UNVERIFIED_ACCOUNT');
      }

      throw Exception(error);
    } else {
      throw Exception(
        'Неизвестная ошибка входа. Статус: ${response.statusCode}',
      );
    }
  }

  // 🔁 ДОБАВЛЕНО: Обновление токена доступа с помощью Refresh токена.
  Future<void> refreshToken() async {
    final refreshToken = await getRefreshToken();

    if (refreshToken == null) {
      // Если нет refresh токена, пользователь должен залогиниться снова
      await logout();
      throw Exception('REFRESH_TOKEN_MISSING');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/token/refresh/'), // URL Simple JWT refresh
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refreshToken}),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      final prefs = await SharedPreferences.getInstance();

      // Сохраняем новый Access токен
      await prefs.setString('access_token', responseData['access']);

      // (Опционально) Simple JWT может вернуть и новый refresh токен, сохраняем его
      if (responseData.containsKey('refresh')) {
        await prefs.setString('refreshToken', responseData['refresh']);
      }
    } else {
      // Если refresh токен недействителен, заставляем пользователя перелогиниться
      await logout();
      throw Exception('Failed to refresh token. Login required.');
    }
  }

  // --- 5. Выход (Log Out) ---

  /// Удаляет все данные аутентификации.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refreshToken');
    await prefs.remove('userId');
    await prefs.remove('pendingUsername');
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
