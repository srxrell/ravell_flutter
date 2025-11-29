import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:readreels/widgets/neowidgets.dart'; // Убедитесь, что путь верный
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'dart:math' as math;

class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({super.key});

  @override
  _AuthenticationScreenState createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  bool isLogin = true;
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final emailController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;

  void _showSnackBar(String message, {bool isError = false}) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : null,
        ),
      );
    }
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(minHeight: screenHeight - 50),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // --- Блок с текстом ---
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLogin ? "С возвращением!" : "Станьте популярным",
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isLogin
                            ? "Войдите, чтобы делиться своими историями"
                            : "Поделитесь своими историями с другими",
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),

                  const SizedBox(height: 35),

                  // --- Форма и Кнопки ---
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      TextField(
                        controller: usernameController,
                        decoration: const InputDecoration(
                          hintText: "Введите ваше имя пользователя",
                          border: InputBorder.none,
                        ),
                      ),

                      if (!isLogin)
                        Column(
                          children: [
                            const SizedBox(height: 10),
                            TextField(
                              controller: emailController,
                              decoration: const InputDecoration(
                                hintText: "Введите ваш email",
                                border: InputBorder.none,
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 10),

                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: "Введите ваш пароль",
                          border: InputBorder.none,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // --- Кнопка Log In / Sign Up ---
                      SizedBox(
                        width: double.infinity,
                        child: NeoButton(
                          type:
                              isLogin
                                  ? NeoButtonType.login
                                  : NeoButtonType.signup,
                          onPressed: () {
                            if (_isLoading) return;
                            _submitAuthForm();
                          },
                          text:
                              _isLoading
                                  ? 'Загрузка...'
                                  : isLogin
                                  ? "Войти"
                                  : "Зарегистрироваться",
                        ),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              thickness: 1.0,
                              color:
                                  Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              "ИЛИ",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              thickness: 1.0,
                              color:
                                  Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // --- Кнопка Toggle ---
                      SizedBox(
                        width: double.infinity,
                        child: NeoButton(
                          type: NeoButtonType.general,
                          onPressed: () {
                            if (_isLoading) return;
                            setState(() {
                              usernameController.clear();
                              passwordController.clear();
                              emailController.clear();
                              isLogin = !isLogin;
                            });
                          },
                          text: isLogin ? "Создать аккаунт" : "Назад ко входу",
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitAuthForm() async {
    final password = passwordController.text.trim();
    final username = usernameController.text.trim();
    final email = emailController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showSnackBar(
        'Пожалуйста, введите имя пользователя и пароль',
        isError: true,
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      if (isLogin) {
        // Попытка входа
        bool success = await _authService.login(username, password);

        if (success && context.mounted) {
          // Успешный вход и верификация
          SharedPreferences prefs = await SharedPreferences.getInstance();
          int? userId = prefs.getInt('userId');
          if (userId != null && userId != 0) {
            context.go('/home');
            return;
          } else {
            _showSnackBar(
              'Ошибка: отсутствует ID пользователя.',
              isError: true,
            );
            await _authService.logout();
          }
        }
      } else {
        // --- Логика регистрации ---
        if (email.isEmpty) {
          _showSnackBar('Пожалуйста, введите email.', isError: true);
          return;
        }
        await _authService.register(username, email, password);
        _showSnackBar(
          'Регистрация прошла успешно. Пожалуйста, подтвердите ваш email.',
        );

        // 🎯 Перенаправление на экран подтверждения OTP после регистрации
        if (context.mounted) {
          context.go('/verify-otp'); // 👈 Вот ваше перенаправление
          return;
        }
      }
    } catch (e) {
      final errorString = e.toString();

      // Обработка ошибки неверифицированного аккаунта при входе
      if (errorString.contains('UNVERIFIED_ACCOUNT')) {
        _showSnackBar(
          'Аккаунт требует верификации. Пожалуйста, введите OTP.',
          isError: true,
        );
        if (context.mounted) {
          // Перенаправление на экран OTP
          context.go('/verify-otp');
          return;
        }
      }

      // Общая обработка ошибок
      _showSnackBar(
        'Ошибка аутентификации: ${errorString.replaceFirst('Exception: ', '')}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> logInAsGuest() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      var code = math.Random().nextInt(999999);
      final sp = await SharedPreferences.getInstance();
      sp.setInt("GUEST_ID", code);
      if (context.mounted) context.go('/home');
    } catch (e) {
      _showSnackBar('Ошибка гостевого входа: ${e.toString()}', isError: true);
    } finally {
      if (context.mounted) setState(() => _isLoading = false);
    }
  }
}
