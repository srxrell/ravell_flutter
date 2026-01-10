import 'package:equatable/equatable.dart';
import '../../models/comment.dart';

abstract class CommentEvent extends Equatable {
  const CommentEvent();
  @override
  List<Object?> get props => [];
}

class CommentFetchRequested extends CommentEvent {
  final int storyId;
  const CommentFetchRequested(this.storyId);
  @override
  List<Object?> get props => [storyId];
}

class CommentCreateRequested extends CommentEvent {
  final int storyId;
  final String content;
  final int? parentCommentId;
  const CommentCreateRequested(this.storyId, this.content, [this.parentCommentId]);
  @override
  List<Object?> get props => [storyId, content, parentCommentId];
}
