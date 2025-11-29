// Новый файл: lib/screens/auth_checker_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart'; // Убедитесь, что путь правильный

class AuthCheckerScreen extends StatefulWidget {
  const AuthCheckerScreen({super.key});

  @override
  State<AuthCheckerScreen> createState() => _AuthCheckerScreenState();
}

class _AuthCheckerScreenState extends State<AuthCheckerScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  void _checkLoginStatus() async {
    final authService = AuthService(); // Создайте экземпляр сервиса
    final isLoggedIn = await authService.isLoggedIn();

    // Задержка на один кадр, чтобы избежать ошибок навигации
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isLoggedIn) {
        // Если авторизован, переходим на /home
        context.go('/home');
      } else {
        // Если не авторизован, переходим на экран аутентификации
        context.go('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Временно показываем индикатор загрузки, пока идет проверка
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}