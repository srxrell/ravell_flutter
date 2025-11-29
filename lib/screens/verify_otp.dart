import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import '../widgets/neowidgets.dart';

class OTPVerificationScreen extends StatefulWidget {
  const OTPVerificationScreen({super.key});

  @override
  _OTPVerificationScreenState createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final otpController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  // --- PINPUT THEMES (NEOBRUTALISM STYLE) ---

  PinTheme get _basePinTheme => PinTheme(
    width: 65,
    height: 65,
    textStyle: neoTextStyle(22, weight: FontWeight.w700),
    decoration: BoxDecoration(
      color: neoWhite,
      borderRadius: BorderRadius.circular(20),
      border: const Border(
        top: BorderSide(color: neoBlack, width: 4),
        left: BorderSide(color: neoBlack, width: 4),
        right: BorderSide(color: neoBlack, width: 8),
        bottom: BorderSide(color: neoBlack, width: 8),
      ),
    ),
  );

  PinTheme get _defaultPinTheme => _basePinTheme;

  PinTheme get _focusedPinTheme => _basePinTheme.copyDecorationWith(
    border: Border.all(color: neoAccent, width: 3),
    borderRadius: BorderRadius.circular(20),
  );

  PinTheme get _errorPinTheme => _basePinTheme.copyDecorationWith(
    border: Border.all(color: Colors.redAccent, width: 3),
    borderRadius: BorderRadius.circular(20),
  );

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }
  }

  Future<void> _verifyOtp() async {
    final otpCode = otpController.text.trim();

    if (otpCode.isEmpty || otpCode.length != 4) {
      _showSnackBar('Пожалуйста, введите 4-значный код.', isError: true);
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final message = await _authService.verifyOtp(otpCode);
      _showSnackBar(message ?? 'Верификация прошла успешно!', isError: false);

      if (context.mounted) {
        context.go('/');
      }
    } catch (e) {
      _showSnackBar(
        'Ошибка верификации: ${e.toString().replaceFirst('Exception: ', '')}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Подтверждение Email',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 50),
              Text(
                'Введите 4-значный код',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Код подтверждения был отправлен на ваш адрес электронной почты.',
                textAlign: TextAlign.center,
                style: neoTextStyle(
                  16,
                  color: Colors.grey,
                  weight: FontWeight.normal,
                ),
              ),
              const SizedBox(height: 40),

              // Pinput
              Center(
                child: Pinput(
                  controller: otpController,
                  length: 4,
                  defaultPinTheme: _defaultPinTheme,
                  focusedPinTheme: _focusedPinTheme,
                  errorPinTheme: _errorPinTheme,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  showCursor: true,
                  onCompleted: (pin) => _verifyOtp(),
                  validator: (s) {
                    if (s == null || s.isEmpty) return null;
                    return s.length != 4 ? 'Неправильный код' : null;
                  },
                ),
              ),

              const SizedBox(height: 40),

              // Button
              SizedBox(
                height: 70,
                child: NeoButton(
                  type: NeoButtonType.login,
                  onPressed: _isLoading ? () {} : _verifyOtp,
                  text: _isLoading ? 'Проверка...' : 'Подтвердить код',
                ),
              ),

              const SizedBox(height: 20),

              // Resend button
              TextButton(
                onPressed: _isLoading ? null : () {},
                child: Text(
                  'Отправить код повторно',
                  style: neoTextStyle(
                    16,
                    weight: FontWeight.w600,
                    color: _isLoading ? Colors.grey : neoBlack,
                  ),
                ),
              ),

              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}
