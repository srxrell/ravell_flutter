import 'hashtag.dart'; // Предполагаем, что Comment существует

class Story {
  final int id;
  final int userId;
  final String title;
  final String content;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
  final String? authorAvatar;
  final bool userLiked;
  final List<Hashtag> hashtags;

  Story({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.likesCount,
    required this.commentsCount,
    this.authorAvatar,
    required this.userLiked,
    required this.hashtags,
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? hashtagList = json['hashtags'] as List<dynamic>?;
    final parsedHashtags =
        hashtagList != null
            ? hashtagList
                .map((h) => Hashtag.fromJson(h as Map<String, dynamic>))
                .toList()
            : <Hashtag>[];

    return Story(
      id: json['id'],
      userId: json['user'] as int? ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      authorAvatar: json['author_avatar'] as String?,
      userLiked: json['user_liked'] ?? false,
      hashtags: parsedHashtags,
    );
  }

  // Методы copyWith и toJson (оставлены без изменений)
  Story copyWith({
    int? id,
    int? userId,
    String? title,
    String? content,
    DateTime? createdAt,
    int? likesCount,
    int? commentsCount,
    String? authorAvatar,
    bool? userLiked,
    List<Hashtag>? hashtags,
  }) {
    return Story(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      userLiked: userLiked ?? this.userLiked,
      hashtags: hashtags ?? this.hashtags,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'author_avatar': authorAvatar,
      'user_liked': userLiked,
      'hashtags': hashtags.map((h) => h.toJson()).toList(),
    };
  }
}
