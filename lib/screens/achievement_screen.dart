import 'package:flutter/material.dart';
import 'package:readreels/models/achievement.dart';
import 'package:readreels/services/achievement_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    setState(() => _isLoading = true);

    try {
      final data = await _achievementService.fetchAchievements(
        userId: widget.userId,
      );
      if (!mounted) return;
      setState(() {
        _achievements = data;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Достижения'),
        backgroundColor: neoBackground,
        elevation: 0,
      ),
      body:
          _isLoading
              ? GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: 4,
                itemBuilder:
                    (_, __) => Container(
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
                  childAspectRatio: 1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _achievements.length,
                itemBuilder: (context, index) {
                  final ua = _achievements[index];
                  final ach = ua.achievement;

                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ua.unlocked ? Colors.green[100] : Colors.white,
                      border: Border.all(color: Colors.black, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.network(
                          ach.iconUrl,
                          width: 50,
                          height: 50,
                          errorBuilder: (_, __, ___) => const Icon(Icons.star),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ach.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ach.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        if (!ua.unlocked)
                          LinearProgressIndicator(
                            value: ua.progress.clamp(0, 1),
                            minHeight: 6,
                          ),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}
