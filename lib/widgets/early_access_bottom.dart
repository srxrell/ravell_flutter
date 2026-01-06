import 'package:flutter/material.dart';
import 'dart:math';
import 'package:readreels/managers/settings_manager.dart';
import 'package:provider/provider.dart';
import 'package:readreels/widgets/neowidgets.dart';
import 'package:readreels/theme.dart';

class EarlyAccessSheet {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        final settings = Provider.of<SettingsManager>(context);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: neoWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: StarInteractive()),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  settings.translate('early_access_info'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.workspace_premium),
                title: Text(settings.translate('pioneer_status')),
                subtitle: Text(
                  settings.translate('pioneer_subtitle'),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.diamond),
                title: Text(settings.translate('success_word')),
                subtitle: Text(
                  settings.translate('success_subtitle'),
                ),
              ),
              const SizedBox(height: 16),
              NeoButton(
                text: settings.translate('got_it'),
                onPressed: () => Navigator.pop(context),
                type: NeoButtonType.general,
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

// -------------------- Звезда и интерактив --------------------
class StarInteractive extends StatefulWidget {
  @override
  _StarInteractiveState createState() => _StarInteractiveState();
}

class _StarInteractiveState extends State<StarInteractive> {
  int counter = 0;
  double scale = 1.0;
  List<Widget> floatingTexts = [];
  double particleSpeed = 1.0;

  void _onTap(TapDownDetails details) {
    counter++;
    scale = 0.8;
    particleSpeed += 0.2;

    final newText = FloatingTextWidget(
      key: UniqueKey(),
      startOffset: details.localPosition,
      value: "+$counter",
      onComplete: (widgetKey) {
        setState(() {
          floatingTexts.removeWhere((w) => w.key == widgetKey);
        });
      },
    );

    setState(() {
      floatingTexts.add(newText);
    });

    Future.delayed(Duration(milliseconds: 100), () {
      setState(() => scale = 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (int i = 0; i < 20; i++) Particle(speedMultiplier: particleSpeed),
          ...floatingTexts,
          GestureDetector(
            onTapDown: _onTap,
            child: AnimatedScale(
              scale: scale,
              duration: Duration(milliseconds: 100),
              child: StarStatic(),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------- Всплывающий текст --------------------
class FloatingTextWidget extends StatefulWidget {
  final Offset startOffset;
  final String value;
  final Function(Key) onComplete;

  const FloatingTextWidget({
    required Key key,
    required this.startOffset,
    required this.value,
    required this.onComplete,
  }) : super(key: key);

  @override
  _FloatingTextWidgetState createState() => _FloatingTextWidgetState();
}

class _FloatingTextWidgetState extends State<FloatingTextWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _yOffset;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );

    _yOffset = Tween<double>(
      begin: 0,
      end: -40,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacity = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete(widget.key!);
      }
    });

    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (ctx, _) {
        return Positioned(
          left: widget.startOffset.dx,
          top: widget.startOffset.dy + _yOffset.value,
          child: Opacity(
            opacity: _opacity.value,
            child: Text(
              widget.value,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// -------------------- Частицы --------------------
class Particle extends StatefulWidget {
  final double speedMultiplier;
  Particle({this.speedMultiplier = 1.0});
  @override
  _ParticleState createState() => _ParticleState();
}

class _ParticleState extends State<Particle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late double startX, startY, endX, endY, size;
  late Color color;
  final Random random = Random();

  @override
  void initState() {
    super.initState();
    startX = random.nextDouble() * 80 - 40;
    startY = random.nextDouble() * 80 - 40;
    endX = startX + random.nextDouble() * 40 - 20;
    endY = startY + random.nextDouble() * 40 - 20;
    size = 3 + random.nextDouble() * 4;
    color = Colors.primaries[random.nextInt(Colors.primaries.length)]
        .withOpacity(0.8);

    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds:
            (1200 / widget.speedMultiplier).round() + random.nextInt(500),
      ),
    )..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        final x = startX + (endX - startX) * _controller.value;
        final y = startY + (endY - startY) * _controller.value;
        return Positioned(
          left: 50 + x,
          top: 50 + y,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// -------------------- Статичная звезда --------------------
class StarStatic extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(60, 60), painter: StarPainter());
  }
}

class StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.amber
          ..style = PaintingStyle.fill;

    double w = size.width;
    double h = size.height;
    final path = Path();

    for (int i = 0; i < 5; i++) {
      double angle = (i * 72 - 90) * pi / 180;
      double x = w / 2 + (w / 2) * cos(angle);
      double y = h / 2 + (h / 2) * sin(angle);
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);

      double innerAngle = ((i * 72 + 36) - 90) * pi / 180;
      double ix = w / 2 + (w / 4) * cos(innerAngle);
      double iy = h / 2 + (h / 4) * sin(innerAngle);
      path.lineTo(ix, iy);
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
