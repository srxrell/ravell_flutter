import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:readreels/services/quote_service.dart';

import 'package:readreels/theme.dart';
import 'package:readreels/services/auth_service.dart';
import 'package:readreels/widgets/neowidgets.dart';

class StreakScreen extends StatefulWidget {
  const StreakScreen({super.key});

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen> {
  int streak = 0;
  bool loading = true;
  String? error;

  final List<int> milestones = [7, 14, 21, 28];

  @override
  void initState() {
    super.initState();
    fetchStreak();
  }

  Future<void> fetchStreak() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final token = await AuthService().getAccessToken();
      if (token == null) throw Exception('Нет токена');

      final res = await http.get(
        Uri.parse('https://ravell-backend-1.onrender.com/streak'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode != 200) {
        throw Exception('Ошибка сервера');
      }

      final data = json.decode(res.body);

      if (!mounted) return;
      setState(() {
        streak = data['streak_count'] ?? 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Не удалось загрузить серию';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        loading = false;
      });
    }
  }

  String nextGoalText() {
    for (final m in milestones) {
      if (streak < m) {
        return '${m - streak} days to next streak';
      }
    }
    return 'All streaks completed';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child:
            loading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),

                      SvgPicture.asset('assets/icons/jacky.svg', height: 140),

                      const SizedBox(height: 24),

                      Text(
                        'Your reading streak',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        nextGoalText(),
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                      ),

                      const SizedBox(height: 40),

                      Container(
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          bottom: 10,
                          top: 20,
                        ),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 255, 225, 207),
                          borderRadius: BorderRadius.all(
                            Radius.circular(200000),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children:
                              milestones.map((day) {
                                return _StreakStep(
                                  day: day,
                                  streak: streak,
                                  milestones: milestones,
                                );
                              }).toList(),
                        ),
                      ),

                      SizedBox(height: 25),

                      FutureBuilder<String>(
                        future: QuoteService.getQuoteOfTheDay(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            'Quote of the day: "${snapshot.data}"',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.happyMonkey(),
                          );
                        },
                      ),

                      const Spacer(),

                      SizedBox(
                        width: double.infinity,
                        child: NeoButton(
                          text: 'Understood',
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// SINGLE STEP
/// ------------------------------------------------------------

class _StreakStep extends StatefulWidget {
  final int day;
  final int streak;
  final List<int> milestones;

  const _StreakStep({
    required this.day,
    required this.streak,
    required this.milestones,
  });

  @override
  State<_StreakStep> createState() => _StreakStepState();
}

class _StreakStepState extends State<_StreakStep>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  double get progress {
    final index = widget.milestones.indexOf(widget.day);
    final prev = index == 0 ? 0 : widget.milestones[index - 1];

    if (widget.streak <= prev) return 0;
    if (widget.streak >= widget.day) return 1;

    return (widget.streak - prev) / (widget.day - prev);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // для волнистой анимации
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 78,
          height: 78,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(22222),
                child: CustomPaint(
                  painter: _LiquidPainter(
                    progress: progress,
                    animation: _controller,
                  ),
                  child: Container(),
                ),
              ),
              Center(
                child: Text(
                  '${widget.day}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: progress > 0.55 ? Colors.black : neoAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'days',
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: Colors.black),
        ),
      ],
    );
  }
}

class _LiquidPainter extends CustomPainter {
  final double progress;
  final Animation<double> animation;

  _LiquidPainter({required this.progress, required this.animation})
    : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = neoAccent;

    final waveHeight = 6.0;
    final waveSpeed = animation.value * 2 * pi;
    final waveLength = size.width / 1.5;

    final path = Path();
    final yOffset = size.height * (1 - progress);

    path.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x++) {
      final y =
          yOffset + sin((x / waveLength * 2 * pi) + waveSpeed) * waveHeight;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Обводка кружка
    final borderPaint =
        Paint()
          ..color = neoAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LiquidPainter oldDelegate) => true;
}
