import 'package:equatable/equatable.dart';
import '../../models/achievement.dart';

abstract class AchievementState extends Equatable {
  const AchievementState();
  @override
  List<Object?> get props => [];
}

class AchievementInitial extends AchievementState {
  const AchievementInitial();
}

class AchievementLoading extends AchievementState {
  const AchievementLoading();
}

class AchievementLoaded extends AchievementState {
  final List<UserAchievement> achievements;
  const AchievementLoaded(this.achievements);
  @override
  List<Object?> get props => [achievements];
}

class AchievementError extends AchievementState {
  final String message;
  const AchievementError(this.message);
  @override
  List<Object?> get props => [message];
}
