import 'package:equatable/equatable.dart';
import '../../models/achievement.dart';

abstract class AchievementEvent extends Equatable {
  const AchievementEvent();
  @override
  List<Object?> get props => [];
}

class AchievementFetchRequested extends AchievementEvent {
  final int userId;
  const AchievementFetchRequested(this.userId);
  @override
  List<Object?> get props => [userId];
}
