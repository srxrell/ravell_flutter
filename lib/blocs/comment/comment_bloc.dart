import 'package:flutter_bloc/flutter_bloc.dart';
import 'comment_event.dart';
import 'comment_state.dart';
import '../../data/repositories/story_repository.dart';

class CommentBloc extends Bloc<CommentEvent, CommentState> {
  final StoryRepository storyRepository;

  CommentBloc({required this.storyRepository}) : super(const CommentInitial()) {
    on<CommentFetchRequested>(_onCommentFetchRequested);
    on<CommentCreateRequested>(_onCommentCreateRequested);
  }

  Future<void> _onCommentFetchRequested(
    CommentFetchRequested event,
    Emitter<CommentState> emit,
  ) async {
    try {
      emit(const CommentLoading());
      final comments = await storyRepository.getCommentsForStory(event.storyId);
      emit(CommentLoaded(comments));
    } catch (e) {
      emit(CommentError(e.toString()));
    }
  }

  Future<void> _onCommentCreateRequested(
    CommentCreateRequested event,
    Emitter<CommentState> emit,
  ) async {
    try {
      final comment = await storyRepository.createComment(
        storyId: event.storyId,
        content: event.content,
        parentCommentId: event.parentCommentId,
      );
      emit(CommentActionSuccess('Comment created successfully', comment));
    } catch (e) {
      emit(CommentError(e.toString()));
    }
  }
}
