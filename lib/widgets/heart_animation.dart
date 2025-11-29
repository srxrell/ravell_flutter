import 'package:flutter/material.dart';

class HeartAnimation extends StatefulWidget {
  final Widget child; // Основной контент страницы
  final bool isAnimating; // Флаг запуска анимации
  final Duration duration;
  final VoidCallback? onEnd;
  final Offset position; // Позиция двойного тапа

  const HeartAnimation({
    super.key,
    required this.child,
    required this.position,
    required this.isAnimating,
    this.duration = const Duration(milliseconds: 700), // Увеличим длительность
    this.onEnd,
  });

  @override
  State<HeartAnimation> createState() => _HeartAnimationState();
}

class _HeartAnimationState extends State<HeartAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    // Анимация масштаба (от маленького к большому с отскоком)
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const ElasticOutCurve(0.75), // Эффект отскока
      ),
    );

    // Анимация прозрачности (плавное исчезновение в конце)
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        // Интервал (0.6, 1.0) означает, что иконка начинает исчезать после 60% времени анимации
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Убедимся, что вызывается onEnd, и сбросим контроллер
        widget.onEnd?.call();
      }
    });
  }

  @override
  void didUpdateWidget(covariant HeartAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !oldWidget.isAnimating) {
      // Сброс контроллера перед запуском для повторной анимации
      _controller.duration = widget.duration;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Основной контент (всегда возвращаем child)
    final content = widget.child;

    // Анимированное сердечко, если запущена анимация
    final animatedHeart =
        widget.isAnimating
            ? Positioned(
              // Центрируем иконку (100/2 = 50) относительно места тапа
              left: widget.position.dx - 50,
              top: widget.position.dy - 50,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacityAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.red,
                        size: 100, // Большая иконка
                        shadows: [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 10.0,
                            spreadRadius: 2.0,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
            : const SizedBox.shrink(); // Если анимация не активна

    // Оборачиваем child и heart в Stack, чтобы сердце было поверх
    return Stack(children: [content, animatedHeart]);
  }
}
