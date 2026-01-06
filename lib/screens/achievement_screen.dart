import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:readreels/models/achievement.dart';
import 'package:readreels/services/achievement_service.dart';
import 'package:readreels/managers/achievement_manager.dart'; // Добавь импорт менеджера
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  Set<String> _localUnlocked = {};
  List<UserAchievement> _achievements = [];
  String? _errorMessage;

  // Геттер для счетчика
  int get completedCount {
    return _achievements.where((ua) => _checkIfUnlocked(ua)).length;
  }

  int get totalCount => _achievements.length;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  // Объединяем загрузки в один метод
  Future<void> _initData() async {
    setState(() => _isLoading = true);
    await _loadLocalUnlocked();
    await _loadAchievements();
  }

  Future<void> _loadLocalUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _localUnlocked = prefs.getStringList('unlocked_achievements')?.toSet() ?? {};
    });
  }

  Future<void> _loadAchievements() async {
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

  // ВЫНОСИМ ЛОГИКУ ПРОВЕРКИ В ОТДЕЛЬНУЮ ФУНКЦИЮ (СИНХРОННУЮ)
  bool _checkIfUnlocked(UserAchievement ua) {
    final ach = ua.achievement;
    
    // 1. Прямой флаг из базы
    if (ua.unlocked) return true;
    
    // 2. Локальное хранилище (важно для the_intruder)
    if (ach.key != null && _localUnlocked.contains(ach.key)) return true;
    
    // 3. Спец-кейсы
    if (ach.title == "Первооткрыватель") return true;
    if (widget.userId == 9 && ach.key == "influential") return true;
    
    // 4. Прогресс
    if (ua.progress >= 1.0) return true;

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          // --- HEADER (без изменений) ---
          _buildHeader(),
          
          // --- GRID ---
          Expanded(
            child: _isLoading
                ? _buildLoadingGrid()
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : _buildAchievementGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        Container(height: 250, width: double.infinity, color: const Color(0xFFFD9C00)),
        Positioned(
          top: -20,
          right: 0,
          child: SvgPicture.asset("assets/icons/medal.svg", width: 180, height: 180),
        ),
        Positioned(
          top: kToolbarHeight + 40,
          left: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Моя гордость", style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: Text("Собрано $completedCount/$totalCount", style: GoogleFonts.poppins(fontSize: 18)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, childAspectRatio: 0.85, crossAxisSpacing: 16, mainAxisSpacing: 16),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildAchievementGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, childAspectRatio: 0.85, crossAxisSpacing: 16, mainAxisSpacing: 16),
      itemCount: _achievements.length,
      itemBuilder: (context, index) {
        final ua = _achievements[index];
        final ach = ua.achievement;
        
        // Используем нашу функцию проверки
        final isUnlocked = _checkIfUnlocked(ua);
        
        // Логика секретности (для "the_intruder")
        bool isHiddenSecret = ach.key == "the_intruder" && !isUnlocked;

        final cardColor = isUnlocked ? neoWhite : Colors.black.withOpacity(0.05);
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
                isHiddenSecret ? "????" : ach.title,
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 8),
              Opacity(
                opacity: iconOpacity,
                child: isHiddenSecret
                    ? const Icon(Icons.lock, size: 50, color: Colors.grey)
                    : (ach.iconUrl.endsWith('.svg')) 
                       ? SvgPicture.network(ach.iconUrl, width: 50, height: 50)
                       : Image.network(ach.iconUrl, width: 50, height: 50, 
                           errorBuilder: (_, __, ___) => const Icon(Icons.star)),
              ),
              const SizedBox(height: 4),
              Text(
                isHiddenSecret ? "Секретная ачивка" : ach.description,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: textColor),
              ),
              const SizedBox(height: 6),
              if (isUnlocked)
                Text(
                  "Completed",
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.green[700]),
                ),
            ],
          ),
        );
      },
    );
  }
}