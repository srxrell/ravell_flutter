import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:readreels/models/achievement.dart';
import 'package:readreels/services/achievement_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:readreels/theme.dart';

class AchievementScreen extends StatefulWidget {
  final int userId;
  const AchievementScreen({super.key, required this.userId});

  @override
  State<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends State<AchievementScreen> {
  final AchievementService _achievementService = AchievementService();
  bool _isLoading = true;
  List<UserAchievement> _achievements = [];
  String? _errorMessage;

  int get completedCount => _achievements.where((ua) {
  final isInstant = ua.achievement.title == "Первооткрыватель"; // или проверка key
  return ua.unlocked || isInstant || ua.progress >= 1;
}).length;
  int get totalCount => _achievements.length;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    setState(() => _isLoading = true);
    try {
      final data = await _achievementService.fetchAchievements(userId: widget.userId);
      if (!mounted) return;
      setState(() {
        _achievements = data;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // прозрачный статус-бар
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          // --- HEADER ---
          Stack(
            children: [
              Container(
                height: 250,
                width: double.infinity,
                color: const Color(0xFFFD9C00),
              ),
              // Медалька справа
              Positioned(
                top: -20,
                right: 0,
                child: SvgPicture.asset(
                  "assets/icons/medal.svg",
                  width: 180, // Увеличиваем размер
                  height: 180,
                ),
              ),
              // Текст и счетчик слева
              Positioned(
                top: kToolbarHeight + 40, // Отступ сверху для текста
                left: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "My honor",
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        "You have $completedCount/$totalCount",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // --- GRID ---
          Expanded(
  child: _isLoading
      ? GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.85,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: 4,
          itemBuilder: (_, __) => Container(
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        )
      : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _achievements.length,
              itemBuilder: (context, index) {
                final ua = _achievements[index];
                final ach = ua.achievement;
                final progress = ua.progress.clamp(0.0, 1.0);

                // --- Логика доступности ---
                final isInstant = ach.title == "Первооткрыватель";
                final isUser9 = widget.userId == 9;

                // Проверяем только реально разблокированные ачивки
                bool isUnlocked = ua.unlocked || isInstant;

                // Спец-кейс для ачивки influential у юзера 9
                if (!isUnlocked && ach.key == "influential" && isUser9) {
                  isUnlocked = true;
                }


                final showProgress = !isInstant && progress < 1;

                // --- Прозрачность / цвет для недоступной ---
                final cardColor = isUnlocked ? neoWhite : Colors.black.withOpacity(0.1);
                final iconOpacity = isUnlocked ? 1.0 : 0.3;
                final textColor = isUnlocked ? Colors.black : Colors.grey[600];

                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cardColor,
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        ach.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: iconOpacity,
                        child: Image.network(
                          ach.iconUrl,
                          width: 50,
                          height: 50,
                          errorBuilder: (_, __, ___) => const Icon(Icons.star),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ach.description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      showProgress
                          ? LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              color: neoAccent,
                              backgroundColor: neoAccent.withOpacity(0.3),
                            )
                          : Text(
                              "Completed",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                    ],
                  ),
                );
              },
            ),
)

        ],
      ),
    );
  }
}
