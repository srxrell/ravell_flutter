import 'package:equatable/equatable.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();
  @override
  List<Object?> get props => [];
}

class ProfileFetchRequested extends ProfileEvent {
  final int userId;
  const ProfileFetchRequested(this.userId);
  @override
  List<Object?> get props => [userId];
}

class ProfileUpdateRequested extends ProfileEvent {
  final int userId;
  final Map<String, dynamic> updates;
  const ProfileUpdateRequested(this.userId, this.updates);
  @override
  List<Object?> get props => [userId, updates];
}
