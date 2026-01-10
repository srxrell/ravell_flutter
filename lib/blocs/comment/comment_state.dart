import 'package:equatable/equatable.dart';
import '../../models/comment.dart';

abstract class CommentState extends Equatable {
  const CommentState();
  @override
  List<Object?> get props => [];
}

class CommentInitial extends CommentState {
  const CommentInitial();
}

class CommentLoading extends CommentState {
  const CommentLoading();
}

class CommentLoaded extends CommentState {
  final List<Comment> comments;
  const CommentLoaded(this.comments);
  @override
  List<Object?> get props => [comments];
}

class CommentActionSuccess extends CommentState {
  final String message;
  final Comment? comment;
  const CommentActionSuccess(this.message, [this.comment]);
  @override
  List<Object?> get props => [message, comment];
}

class CommentError extends CommentState {
  final String message;
  const CommentError(this.message);
  @override
  List<Object?> get props => [message];
}
