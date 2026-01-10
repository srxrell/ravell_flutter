import 'package:equatable/equatable.dart';
import '../../models/story.dart';

/// Base class for all story states
abstract class StoryState extends Equatable {
  const StoryState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class StoryInitial extends StoryState {
  const StoryInitial();
}

/// Loading state
class StoryLoading extends StoryState {
  const StoryLoading();
}

/// Stories loaded successfully
class StoryLoaded extends StoryState {
  final List<Story> stories;
  final bool isFromCache;

  const StoryLoaded({
    required this.stories,
    this.isFromCache = false,
  });

  @override
  List<Object?> get props => [stories, isFromCache];
}

/// Single story loaded
class StorySingleLoaded extends StoryState {
  final Story story;

  const StorySingleLoaded(this.story);

  @override
  List<Object?> get props => [story];
}

/// Replies loaded for a story
class StoryRepliesLoaded extends StoryState {
  final List<Story> replies;
  final int parentStoryId;

  const StoryRepliesLoaded({
    required this.replies,
    required this.parentStoryId,
  });

  @override
  List<Object?> get props => [replies, parentStoryId];
}

/// Story action (create/update/delete/share) successful
class StoryActionSuccess extends StoryState {
  final String message;
  final Story? story; // Optional story for create/update

  const StoryActionSuccess({
    required this.message,
    this.story,
  });

  @override
  List<Object?> get props => [message, story];
}

/// Error state
class StoryError extends StoryState {
  final String message;

  const StoryError(this.message);

  @override
  List<Object?> get props => [message];
}
