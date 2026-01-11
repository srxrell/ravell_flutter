import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:readreels/widgets/neowidgets.dart'; // Твои виджеты
import 'package:url_launcher/url_launcher.dart';
import 'package:readreels/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color premiumColor = neoAccent; // Золотой
    final Color bgColor = const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Основной контент
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 60),
                
                // 1. Анимированная Звезда (Оставляем кастомной, т.к. там градиент и круг)
                const Center(child: AnimatedPremiumBadge()),
                
                const SizedBox(height: 24),

                // 2. Заголовок
                Text(
                  "RAVELL PREMIUM",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.russoOne(
                    fontSize: 32,
                    color: Colors.black,
                    shadows: [
                      const Shadow(offset: Offset(2, 2), color: Colors.black12),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),
                
                const Text(
                  "Стань легендой и ломай лимиты",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 40),

                // 3. Список фич (На NeoContainer)
                _buildFeatureTile(
                  icon: Icons.history_edu,
                  title: "20 Историй в день",
                  subtitle: "Вместо 3. Пиши сколько влезет.",
                  color: Colors.blueAccent,
                ),
                const SizedBox(height: 16),
                _buildFeatureTile(
                  icon: Icons.rocket_launch,
                  title: "Буст Алгоритмов",
                  subtitle: "Твои посты взлетают выше (x1.3 к рейтингу).",
                  color: Colors.orangeAccent,
                ),
                const SizedBox(height: 16),
                _buildFeatureTile(
                  icon: Icons.visibility,
                  title: "Режим Сталкера",
                  subtitle: "Просматривай, кто именно читал твои истории.",
                  color: Colors.purpleAccent,
                ),
                const SizedBox(height: 16),
                _buildFeatureTile(
                  icon: Icons.gif_box,
                  title: "Живая Аватарка",
                  subtitle: "Загружай GIF на профиль. Выделяйся.",
                  color: Colors.pinkAccent,
                ),
                
                const SizedBox(height: 120), // Место под кнопку
              ],
            ),
          ),

          // 4. Кнопка Купить (NeoContainer для кастомного цвета и контента)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildBuyButton(context, premiumColor),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    // Используем NeoContainer для карточки
    return NeoContainer(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Иконка тоже в NeoContainer (маленьком)
          NeoContainer(
            width: 54, // Фиксированный размер для квадрата
            height: 54,
            padding: const EdgeInsets.all(0), // Убираем дефолтный паддинг
            color: color.withOpacity(0.2),
            child: Icon(icon, color: Colors.black, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyButton(BuildContext context, Color color) {
    // Используем NeoContainer вместо NeoButton, так как нам нужен 
    // кастомный цвет (Gold) и сложная верстка внутри (Column)
    return NeoContainer(
      color: color,
      onTap: () => _buyPremium(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Кружок со звездой
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star_outlined, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "АКТИВИРОВАТЬ ПРЕМИУМ",
                style: GoogleFonts.russoOne(
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.telegram, size: 14, color: Colors.black),
                  SizedBox(width: 4),
                  Text(
                    "100 Stars / месяц",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _buyPremium(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Сначала войдите в аккаунт!")),
        );
      }
      return;
    }

    const String botUsername = "ravell_fcm_bot";
    final String startParameter = "sub_pro_$userId";
    final Uri url = Uri.parse("https://t.me/$botUsername?start=$startParameter");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Не удалось открыть Telegram")),
        );
      }
    }
  }
}

// --- АНИМИРОВАННАЯ ЗВЕЗДА (Оставляем без изменений, т.к. это уникальный арт) ---
class AnimatedPremiumBadge extends StatefulWidget {
  const AnimatedPremiumBadge({super.key});

  @override
  State<AnimatedPremiumBadge> createState() => _AnimatedPremiumBadgeState();
}

class _AnimatedPremiumBadgeState extends State<AnimatedPremiumBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + (_controller.value * 0.1);
        final rotation = math.sin(_controller.value * 2 * math.pi) * 0.1;
        
        return Transform.scale(
          scale: scale,
          child: Transform.rotate(
            angle: rotation,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(width: 4, color: Colors.black),
                
              ),
              child: const Icon(
                Icons.star_rounded,
                size: 80,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}
