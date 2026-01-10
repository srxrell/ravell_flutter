import 'package:equatable/equatable.dart';

/// Base class for all authentication events
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Event to check if user is already logged in
class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

/// Event to login with username and password
class AuthLoginRequested extends AuthEvent {
  final String username;
  final String password;

  const AuthLoginRequested({
    required this.username,
    required this.password,
  });

  @override
  List<Object?> get props => [username, password];
}

/// Event to register a new user
class AuthRegisterRequested extends AuthEvent {
  final String username;
  final String email;
  final String password;

  const AuthRegisterRequested({
    required this.username,
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [username, email, password];
}

/// Event to logout
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Event to refresh token
class AuthTokenRefreshRequested extends AuthEvent {
  const AuthTokenRefreshRequested();
}
