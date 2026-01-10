import 'package:flutter_bloc/flutter_bloc.dart';
import 'achievement_event.dart';
import 'achievement_state.dart';
import '../../data/repositories/achievement_repository.dart';

class AchievementBloc extends Bloc<AchievementEvent, AchievementState> {
  final AchievementRepository achievementRepository;

  AchievementBloc({required this.achievementRepository})
      : super(const AchievementInitial()) {
    on<AchievementFetchRequested>(_onAchievementFetchRequested);
  }

  Future<void> _onAchievementFetchRequested(
    AchievementFetchRequested event,
    Emitter<AchievementState> emit,
  ) async {
    try {
      emit(const AchievementLoading());
      final achievements =
          await achievementRepository.getUserAchievements(event.userId);
      emit(AchievementLoaded(achievements));
    } catch (e) {
      emit(AchievementError(e.toString()));
    }
  }
}
