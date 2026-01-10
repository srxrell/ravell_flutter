import 'package:equatable/equatable.dart';

/// Base class for all story events
abstract class StoryEvent extends Equatable {
  const StoryEvent();

  @override
  List<Object?> get props => [];
}

/// Event to fetch all stories
class StoryFetchRequested extends StoryEvent {
  final bool forceRefresh;

  const StoryFetchRequested({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

/// Event to fetch seeds (stories without replies)
class StorySeedsFetchRequested extends StoryEvent {
  const StorySeedsFetchRequested();
}

/// Event to fetch branches (stories with replies)
class StoryBranchesFetchRequested extends StoryEvent {
  const StoryBranchesFetchRequested();
}

/// Event to fetch a single story
class StorySingleFetchRequested extends StoryEvent {
  final int storyId;

  const StorySingleFetchRequested(this.storyId);

  @override
  List<Object?> get props => [storyId];
}

/// Event to fetch replies for a story
class StoryRepliesFetchRequested extends StoryEvent {
  final int storyId;

  const StoryRepliesFetchRequested(this.storyId);

  @override
  List<Object?> get props => [storyId];
}

/// Event to create a new story
class StoryCreateRequested extends StoryEvent {
  final String title;
  final String content;
  final List<int> hashtagIds;
  final int? replyTo;

  const StoryCreateRequested({
    required this.title,
    required this.content,
    required this.hashtagIds,
    this.replyTo,
  });

  @override
  List<Object?> get props => [title, content, hashtagIds, replyTo];
}

/// Event to update a story
class StoryUpdateRequested extends StoryEvent {
  final int storyId;
  final String title;
  final String content;
  final List<int> hashtagIds;

  const StoryUpdateRequested({
    required this.storyId,
    required this.title,
    required this.content,
    required this.hashtagIds,
  });

  @override
  List<Object?> get props => [storyId, title, content, hashtagIds];
}

/// Event to delete a story
class StoryDeleteRequested extends StoryEvent {
  final int storyId;

  const StoryDeleteRequested(this.storyId);

  @override
  List<Object?> get props => [storyId];
}

/// Event to share a story
class StoryShareRequested extends StoryEvent {
  final int storyId;

  const StoryShareRequested(this.storyId);

  @override
  List<Object?> get props => [storyId];
}

/// Event to search stories
class StorySearchRequested extends StoryEvent {
  final String searchTerm;

  const StorySearchRequested(this.searchTerm);

  @override
  List<Object?> get props => [searchTerm];
}

/// Event to get stories by hashtag
class StoryHashtagFetchRequested extends StoryEvent {
  final int hashtagId;

  const StoryHashtagFetchRequested(this.hashtagId);

  @override
  List<Object?> get props => [hashtagId];
}

/// Event to get user stories
class StoryUserFetchRequested extends StoryEvent {
  final int userId;

  const StoryUserFetchRequested(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Event to mark story as not interested
class StoryMarkNotInterestedRequested extends StoryEvent {
  final int storyId;

  const StoryMarkNotInterestedRequested(this.storyId);

  @override
  List<Object?> get props => [storyId];
}
