import 'package:flutter_bloc/flutter_bloc.dart';
import 'story_event.dart';
import 'story_state.dart';
import '../../data/repositories/story_repository.dart';

/// Story BLoC for managing story operations with caching
class StoryBloc extends Bloc<StoryEvent, StoryState> {
  final StoryRepository storyRepository;

  StoryBloc({required this.storyRepository}) : super(const StoryInitial()) {
    on<StoryFetchRequested>(_onStoryFetchRequested);
    on<StorySeedsFetchRequested>(_onStorySeedsFetchRequested);
    on<StoryBranchesFetchRequested>(_onStoryBranchesFetchRequested);
    on<StorySingleFetchRequested>(_onStorySingleFetchRequested);
    on<StoryRepliesFetchRequested>(_onStoryRepliesFetchRequested);
    on<StoryCreateRequested>(_onStoryCreateRequested);
    on<StoryUpdateRequested>(_onStoryUpdateRequested);
    on<StoryDeleteRequested>(_onStoryDeleteRequested);
    on<StoryShareRequested>(_onStoryShareRequested);
    on<StorySearchRequested>(_onStorySearchRequested);
    on<StoryHashtagFetchRequested>(_onStoryHashtagFetchRequested);
    on<StoryUserFetchRequested>(_onStoryUserFetchRequested);
    on<StoryMarkNotInterestedRequested>(_onStoryMarkNotInterestedRequested);
  }

  /// Fetch all stories
  Future<void> _onStoryFetchRequested(
    StoryFetchRequested event,
    Emitter<StoryState> emit,
  ) async {
    try {
      emit(const StoryLoading());

      final stories = await storyRepository.getStories(
        forceRefresh: event.forceRefresh,
      );

      emit(StoryLoaded(stories: stories));
      print('✅ Loaded ${stories.length} stories');
    } catch (e) {
      print('❌ Failed to load stories: $e');
      emit(StoryError(e.toString()));
    }
  }

  /// Fetch seeds
  Future<void> _onStorySeedsFetchRequested(
    StorySeedsFetchRequested event,
    Emitter<StoryState> emit,
  ) async {
    try {
      emit(const StoryLoading());

      final stories = await storyRepository.getSeeds();

      emit(StoryLoaded(stories: stories));
      print('✅ Loaded ${stories.length} seed stories');
    } catch (e) {
      print('❌ Failed to load seeds: $e');
      emit(StoryError(e.toString()));
    }
  }

  /// Fetch branches
  Future<void> _onStoryBranchesFetchRequested(
    StoryBranchesFetchRequested event,
    Emitter<StoryState> emit,
  ) async {
    try {
      emit(const StoryLoading());

      final stories = await storyRepository.getBranches();

      emit(StoryLoaded(stories: stories));
      print('✅ Loaded ${stories.length} branch stories');
    } catch (e) {
      print('❌ Failed to load branches: $e');
      emit(StoryError(e.toString()));
    }
  }

  /// Fetch single story
  Future<void> _onStorySingleFetchRequested(
    StorySingleFetchRequested event,
    Emitter<StoryState> emit,
  ) async {
    try {
      emit(const StoryLoading());

      final story = await storyRepository.getStory(event.storyId);

      emit(StorySingleLoaded(story));
      print('✅ Loaded story ${event.storyId}');
    } catch (e) {
      print('❌ Failed to load story: $e');
      emit(StoryError(e.toString()));
    }
  }

  /// Fetch replies for a story
  Future<void> _onStoryRepliesFetchRequested(
    StoryRepliesFetchRequested event,
    Emitter<StoryState> emit,
  ) async {
    try {
      emit(const StoryLoading());

      final replies = await storyRepository.getRepliesForStory(event.storyId);

      emit(StoryRepliesLoaded(
        replies: replies,
        parentStoryId: event.storyId,
      ));
      print('✅ Loaded ${replies.length} replies for story ${event.storyId}');
    } catch (e) {
      print('❌ Failed to load replies: $e');
      emit(StoryError(e.toString()));
    }
  }

  /// Create a new story
  Future<void> _onStoryCreateRequested(
    StoryCreateRequested event,
    Emitter<StoryState> emit,
  ) async {
    try {
      emit(const StoryLoading());

      final story = await storyRepository.createStory(
        title: event.title,
        content: event.content,
        hashtagIds: event.hashtagIds,
        replyTo: event.replyTo,
      );

      emit(StoryActionSuccess(
        message: event.replyTo != null
            ? 'Reply created successfully'
            : 'Story created successfully',
        story: story,
      ));
      print('✅ Story created: ${story.id}');
    } catch (e) {
      print('❌ Failed to create story: $e');
      emit(StoryError(e.toString()));
    }
  }

  /// Update a story
  Future<void> _onStoryUpdateRequested(
    StoryUpdateRequested event,
    Emitter<StoryState> emit,
  ) async {
    try {
      emit(const StoryLoading());

      final story = await storyRepository.updateStory(
        storyId: event.storyId,
        title: event.title,
        content: event.content,
        hashtagIds: event.hashtagIds,
      );

      emit(StoryActionSuccess(
        message: 'Story updated successfully',
        story: story,
      ));
      print('✅ Story updated: ${story.id}');
    } catch (e) {
      print('❌ Failed to update story: $e');
      emit(StoryError(e.toString()));
    }
  }

  /// Delete a story
  Future<void> _onStoryDeleteRequested(
    StoryDeleteRequested event,
    Emitter<StoryState> emit,
  ) async {
    try {
      emit(const StoryLoading());

      await storyRepository.deleteStory(event.storyId);

      emit(const StoryActionSuccess(message: 'Story deleted successfully'));
      print('✅ Story deleted: ${event.storyId}');
    } catch (e) {
      print('❌ Failed to delete story: $e');
      emit(StoryError(e.toString()));
    }
  }

  /// Share a story
  Future<void> _onStoryShareRequested(
    StoryShareRequested event,
    Emitter<StoryState> emit,
  ) async {
    try {
      await storyRepository.shareStory(event.storyId);

      emit(const StoryActionSuccess(message: 'Story shared successfully'));
      print('✅ Story shared: ${event.storyId}');
    } catch (e) {
      print('❌ Failed to share story: $e');
      emit(StoryError(e.toString()));
    }
  }

  /// Search stories
  Future<void> _onStorySearchRequested(
    StorySearchRequested event,
    Emitter<StoryState> emit,
  ) async {
    try {
      emit(const StoryLoading());

      final stories = await storyRepository.searchStories(event.searchTerm);

      emit(StoryLoaded(stories: stories));
      print('✅ Found ${stories.length} stories for "${event.searchTerm}"');
    } catch (e) {
      print('❌ Failed to search stories: $e');
      emit(StoryError(e.toString()));
    }
  }

  /// Get stories by hashtag
  Future<void> _onStoryHashtagFetchRequested(
    StoryHashtagFetchRequested event,
    Emitter<StoryState> emit,
  ) async {
    try {
      emit(const StoryLoading());

      final stories = await storyRepository.getStoriesByHashtag(event.hashtagId);

      emit(StoryLoaded(stories: stories));
      print('✅ Loaded ${stories.length} stories for hashtag ${event.hashtagId}');
    } catch (e) {
      print('❌ Failed to load hashtag stories: $e');
      emit(StoryError(e.toString()));
    }
  }

  /// Get user stories
  Future<void> _onStoryUserFetchRequested(
    StoryUserFetchRequested event,
    Emitter<StoryState> emit,
  ) async {
    try {
      emit(const StoryLoading());

      final stories = await storyRepository.getUserStories(event.userId);

      emit(StoryLoaded(stories: stories));
      print('✅ Loaded ${stories.length} stories for user ${event.userId}');
    } catch (e) {
      print('❌ Failed to load user stories: $e');
      emit(StoryError(e.toString()));
    }
  }

  /// Mark story as not interested
  Future<void> _onStoryMarkNotInterestedRequested(
    StoryMarkNotInterestedRequested event,
    Emitter<StoryState> emit,
  ) async {
    try {
      await storyRepository.markStoryAsNotInterested(event.storyId);

      emit(const StoryActionSuccess(message: 'Story marked as not interested'));
      print('✅ Story marked as not interested: ${event.storyId}');
    } catch (e) {
      print('❌ Failed to mark story: $e');
      emit(StoryError(e.toString()));
    }
  }
}
