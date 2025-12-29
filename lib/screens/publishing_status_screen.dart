import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:readreels/theme.dart';

class PublishingStatusScreen extends StatefulWidget {
  final Future<void> publishTask;
  final String successMessage;

  const PublishingStatusScreen({
    super.key,
    required this.publishTask,
    this.successMessage = 'Успешно опубликовано!',
  });

  @override
  State<PublishingStatusScreen> createState() => _PublishingStatusScreenState();
}

class _PublishingStatusScreenState extends State<PublishingStatusScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String? _errorMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();
    _startPublishing();
  }

  Future<void> _startPublishing() async {
    try {
      await widget.publishTask;
      if (mounted) {
        setState(() {
          _isSuccess = true;
        });
        _controller.stop();
        
        // Wait a bit to show success message then navigate home
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          context.go('/home'); // Or pop to root
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: neoBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_errorMessage != null) ...[
                const Icon(Icons.error_outline, size: 80, color: Colors.red),
                const SizedBox(height: 24),
                Text(
                  'Ошибка публикации',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Вернуться назад'),
                ),
              ] else if (_isSuccess) ...[
                const Icon(Icons.check_circle_outline, size: 100, color: Colors.green),
                const SizedBox(height: 24),
                Text(
                  widget.successMessage,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                 RotationTransition(
                  turns: _controller,
                  child: const Icon(Icons.change_circle_outlined, size: 80, color: Colors.black),
                ),
                const SizedBox(height: 32),
                Text(
                  'Публикация вашей истории...',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Пожалуйста, не закрывайте приложение',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
