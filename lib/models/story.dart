import 'package:readreels/models/hashtag.dart';

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
  final Map<String, dynamic>? user; // ✅ ДОБАВЛЕНО для нового API

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
    this.user,
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? hashtagList = json['hashtags'] as List<dynamic>?;
    final parsedHashtags =
        hashtagList != null
            ? hashtagList
                .map((h) => Hashtag.fromJson(h as Map<String, dynamic>))
                .toList()
            : <Hashtag>[];

    // ✅ ОБРАБОТКА НОВОГО ФОРМАТА С USER OBJECT
    String? avatarUrl;
    if (json['user'] != null && json['user'] is Map<String, dynamic>) {
      final userData = json['user'] as Map<String, dynamic>;
      if (userData['profile'] != null &&
          userData['profile'] is Map<String, dynamic>) {
        final profile = userData['profile'] as Map<String, dynamic>;
        avatarUrl = profile['avatar'] as String?;
      }
    }

    return Story(
      id: json['id'],
      userId: json['user_id'] as int,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      authorAvatar: avatarUrl ?? json['author_avatar'] as String?,
      userLiked: json['user_liked'] ?? false,
      hashtags: parsedHashtags,
      user: json['user'] as Map<String, dynamic>?,
    );
  }

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
    Map<String, dynamic>? user,
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
      user: user ?? this.user,
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
      'user': user,
    };
  }

  // ✅ ДОБАВЛЕН МЕТОД ДЛЯ ПОЛУЧЕНИЯ АВАТАРА ИЗ НОВОГО ФОРМАТА
  String? get avatarUrl {
    if (authorAvatar != null && authorAvatar!.isNotEmpty) {
      return 'https://ravell-backend-1.onrender.com$authorAvatar';
    }

    if (user != null && user!['profile'] != null) {
      final avatar = user!['profile']['avatar'] as String?;
      if (avatar != null && avatar.isNotEmpty) {
        return 'https://ravell-backend-1.onrender.com$avatar';
      }
    }

    return null;
  }

  // ✅ ДОБАВЛЕН МЕТОД ДЛЯ ПОЛУЧЕНИЯ ИМЕНИ ПОЛЬЗОВАТЕЛЯ
  String get username {
    if (user != null && user!['username'] != null) {
      return user!['username'] as String;
    }
    return 'Unknown User';
  }
}
