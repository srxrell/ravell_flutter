class Achievement {
  final String title;
  final String description;
  final String iconUrl;
  final bool unlocked;

  Achievement({
    required this.title,
    required this.description,
    required this.iconUrl,
    required this.unlocked,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      iconUrl: json['icon_url'] ?? '',
      unlocked: json['unlocked'] ?? false,
    );
  }
}

class UserAchievement {
  final double progress;
  final bool unlocked;
  final Achievement achievement;

  UserAchievement({
    required this.progress,
    required this.unlocked,
    required this.achievement,
  });

  factory UserAchievement.fromJson(Map<String, dynamic> json) {
    return UserAchievement(
      progress: (json['progress'] as num).toDouble(),
      unlocked: json['unlocked'] ?? false,
      achievement: Achievement.fromJson(json['achievement']),
    );
  }
}
