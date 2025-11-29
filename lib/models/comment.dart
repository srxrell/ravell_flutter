class Comment {
  final int id;
  final int userId;
  final int storyId;
  final String? userUsername;
  // >>> НОВОЕ ПОЛЕ: URL аватара
  final String? userAvatarUrl;
  final String content;
  final DateTime createdAt;
  final bool isEdited;

  Comment({
    required this.id,
    required this.userId,
    required this.storyId,
    this.userUsername,
    // >>> Инициализация нового поля
    this.userAvatarUrl,
    required this.content,
    required this.createdAt,
    this.isEdited = false,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as int,
      userId: json['user'] as int? ?? 0,
      storyId: json['story'] as int? ?? 0,
      userUsername: json['user_username'] as String?,
      // >>> Парсинг нового поля из JSON
      userAvatarUrl: json['user_avatar_url'] as String?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isEdited: json['is_edited'] ?? false,
    );
  }
}
