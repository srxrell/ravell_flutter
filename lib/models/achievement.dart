import 'package:equatable/equatable.dart';

class Achievement extends Equatable {
  final String? key;
  final String title;
  final String description;
  final String iconUrl;
  final bool unlocked;

  const Achievement({
    required this.key,
    required this.title,
    required this.description,
    required this.iconUrl,
    required this.unlocked,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      key: json['key'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      iconUrl: json['icon_url'] ?? '',
      unlocked: json['unlocked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'title': title,
        'description': description,
        'icon_url': iconUrl,
        'unlocked': unlocked,
      };

  @override
  List<Object?> get props => [key, title, description, iconUrl, unlocked];
}

class UserAchievement extends Equatable {
  final double progress;
  final bool unlocked;
  final Achievement achievement;

  const UserAchievement({
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

  Map<String, dynamic> toJson() => {
        'progress': progress,
        'unlocked': unlocked,
        'achievement': achievement.toJson(),
      };

  @override
  List<Object?> get props => [progress, unlocked, achievement];
}
