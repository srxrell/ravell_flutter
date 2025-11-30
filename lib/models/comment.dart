class Comment {
  final int id;
  final int userId; // 🟢 ИСПРАВЛЕНО: userId вместо user_id
  final int storyId;
  final String? username; // 🟢 ИСПРАВЛЕНО: username вместо userUsername
  final String? avatarUrl; // 🟢 ИСПРАВЛЕНО: avatarUrl вместо userAvatarUrl
  final String content;
  final DateTime createdAt;
  final bool isEdited;

  Comment({
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
      userId: json['user_id'] as int, // 🟢 ИСПРАВЛЕНО: user_id
      storyId: json['story_id'] as int, // 🟢 ИСПРАВЛЕНО: story_id
      username: json['username'] as String?, // 🟢 ИСПРАВЛЕНО: username
      avatarUrl: json['avatar_url'] as String?, // 🟢 ИСПРАВЛЕНО: avatar_url
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isEdited: json['is_edited'] ?? false,
    );
  }
}
