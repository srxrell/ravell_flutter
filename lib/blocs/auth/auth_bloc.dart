import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../../data/repositories/auth_repository.dart';

/// Authentication BLoC with state persistence
class AuthBloc extends HydratedBloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(const AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthRegisterRequested>(_onAuthRegisterRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthTokenRefreshRequested>(_onAuthTokenRefreshRequested);
  }

  /// Check if user is already logged in
  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading());

      final isLoggedIn = await authRepository.isLoggedIn();

      if (isLoggedIn) {
        final userId = await authRepository.getCurrentUserId();
        if (userId != null) {
          emit(AuthAuthenticated(userId: userId));
          print('✅ User is authenticated: $userId');
        } else {
          emit(const AuthUnauthenticated());
        }
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      print('❌ Auth check failed: $e');
      emit(const AuthUnauthenticated());
    }
  }

  /// Handle login request
  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading());

      final result = await authRepository.login(
        username: event.username,
        password: event.password,
      );

      final userId = result['user_id'] as int;

      emit(AuthAuthenticated(userId: userId, username: event.username));
      print('✅ Login successful: $userId');
    } catch (e) {
      print('❌ Login failed: $e');
      emit(AuthError(e.toString()));
      // Return to unauthenticated after showing error
      await Future.delayed(const Duration(milliseconds: 100));
      emit(const AuthUnauthenticated());
    }
  }

  /// Handle registration request
  Future<void> _onAuthRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading());

      final result = await authRepository.register(
        username: event.username,
        email: event.email,
        password: event.password,
      );

      final userId = result['user_id'] as int;

      emit(AuthAuthenticated(userId: userId, username: event.username));
      print('✅ Registration successful: $userId');
    } catch (e) {
      print('❌ Registration failed: $e');
      emit(AuthError(e.toString()));
      // Return to unauthenticated after showing error
      await Future.delayed(const Duration(milliseconds: 100));
      emit(const AuthUnauthenticated());
    }
  }

  /// Handle logout request
  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await authRepository.logout();
      emit(const AuthUnauthenticated());
      print('✅ Logout successful');
    } catch (e) {
      print('❌ Logout failed: $e');
      emit(AuthError(e.toString()));
    }
  }

  /// Handle token refresh request
  Future<void> _onAuthTokenRefreshRequested(
    AuthTokenRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await authRepository.refreshToken();
      print('✅ Token refreshed');
    } catch (e) {
      print('❌ Token refresh failed: $e');
      // If refresh fails, logout
      add(const AuthLogoutRequested());
    }
  }

  /// Persist state to storage
  @override
  AuthState? fromJson(Map<String, dynamic> json) {
    try {
      final type = json['type'] as String?;

      switch (type) {
        case 'authenticated':
          return AuthAuthenticated(
            userId: json['userId'] as int,
            username: json['username'] as String?,
          );
        case 'unauthenticated':
          return const AuthUnauthenticated();
        default:
          return const AuthInitial();
      }
    } catch (e) {
      print('⚠️ Failed to restore auth state: $e');
      return const AuthInitial();
    }
  }

  /// Convert state to JSON for persistence
  @override
  Map<String, dynamic>? toJson(AuthState state) {
    if (state is AuthAuthenticated) {
      return {
        'type': 'authenticated',
        'userId': state.userId,
        'username': state.username,
      };
    } else if (state is AuthUnauthenticated) {
      return {'type': 'unauthenticated'};
    }
    return null;
  }
}
