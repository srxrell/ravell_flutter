import 'package:equatable/equatable.dart';

class Comment extends Equatable {
  final int id;
  final int userId;
  final int storyId;
  final String? username;
  final String? avatarUrl;
  final String content;
  final DateTime createdAt;
  final bool isEdited;

  const Comment({
    required this.id,
    required this.userId,
    required this.storyId,
    this.username,
    this.avatarUrl,
    required this.content,
    required this.createdAt,
    this.isEdited = false,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      storyId: json['story_id'] as int,
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isEdited: json['is_edited'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'story_id': storyId,
        'username': username,
        'avatar_url': avatarUrl,
        'content': content,
        'created_at': createdAt.toIso8601String(),
        'is_edited': isEdited,
      };

  @override
  List<Object?> get props => [
        id,
        userId,
        storyId,
        username,
        avatarUrl,
        content,
        createdAt,
        isEdited,
      ];
}
