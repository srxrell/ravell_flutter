import 'package:flutter_bloc/flutter_bloc.dart';
import 'profile_event.dart';
import 'profile_state.dart';
import '../../data/repositories/user_repository.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final UserRepository userRepository;

  ProfileBloc({required this.userRepository}) : super(const ProfileInitial()) {
    on<ProfileFetchRequested>(_onProfileFetchRequested);
    on<ProfileUpdateRequested>(_onProfileUpdateRequested);
  }

  Future<void> _onProfileFetchRequested(
    ProfileFetchRequested event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      emit(const ProfileLoading());
      final profile = await userRepository.getUserProfile(event.userId);
      emit(ProfileLoaded(profile));
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }

  Future<void> _onProfileUpdateRequested(
    ProfileUpdateRequested event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      emit(const ProfileLoading());
      final profile = await userRepository.updateProfile(
        userId: event.userId,
        username: event.updates['username'],
        email: event.updates['email'],
        firstName: event.updates['first_name'],
        lastName: event.updates['last_name'],
        bio: event.updates['bio'],
        avatarUrl: event.updates['avatar_url'],
      );
      emit(ProfileLoaded(profile));
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }
}
