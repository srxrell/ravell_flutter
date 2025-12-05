// models/story.dart - ИСПРАВЛЕННАЯ ВЕРСИЯ

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
  final Map<String, dynamic>? user; // Может содержать данные пользователя

  // ✅ НОВЫЕ ПОЛЯ ДЛЯ RAVELL
  final int wordCount; // Всегда 100
  final int? replyTo; // ID родительской истории
  final int replyCount; // Количество ответов
  final DateTime? lastReplyAt; // Время последнего ответа

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

    // Инициализация новых полей
    this.wordCount = 0,
    this.replyTo,
    this.replyCount = 0,
    this.lastReplyAt,
  });

  int get repliesCount => replyCount; // Алиас для replyCount
  
  // 🟢 ГЕТТЕР ДЛЯ ID ХЕШТЕГОВ (если нужно)
  List<int> get hashtagIds {
    return hashtags.map((hashtag) => hashtag.id).toList();
  }

  factory Story.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? hashtagList = json['hashtags'] as List<dynamic>?;
    final parsedHashtags =
        hashtagList != null
            ? hashtagList
                .map((h) => Hashtag.fromJson(h as Map<String, dynamic>))
                .toList()
            : <Hashtag>[];

    // Обработка пользователя
    String? avatarUrl;
    Map<String, dynamic>? userData;

    if (json['user'] != null && json['user'] is Map<String, dynamic>) {
      userData = json['user'] as Map<String, dynamic>;
      if (userData['profile'] != null &&
          userData['profile'] is Map<String, dynamic>) {
        final profile = userData['profile'] as Map<String, dynamic>;
        avatarUrl = profile['avatar'] as String?;
      }
    }

    // Обработка новых полей
    final replyTo = json['reply_to'];
    final lastReplyAt = json['last_reply_at'];

    return Story(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
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
      user: userData,

      // Новые поля
      wordCount: json['word_count'] ?? 0,
      replyTo: replyTo != null ? int.tryParse(replyTo.toString()) : null,
      replyCount: json['reply_count'] ?? 0,
      lastReplyAt: lastReplyAt != null ? DateTime.parse(lastReplyAt) : null,
    );
  }

  // Добавить в методы copyWith и toJson
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
    int? wordCount,
    int? replyTo,
    int? replyCount,
    DateTime? lastReplyAt,
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
      wordCount: wordCount ?? this.wordCount,
      replyTo: replyTo ?? this.replyTo,
      replyCount: replyCount ?? this.replyCount,
      lastReplyAt: lastReplyAt ?? this.lastReplyAt,
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
      'word_count': wordCount,
      'reply_to': replyTo,
      'reply_count': replyCount,
      'last_reply_at': lastReplyAt?.toIso8601String(),
    };
  }

  // ✅ Проверка типа истории
  bool get isSeed => replyTo == null && replyCount == 0;
  bool get isBranch => replyTo == null && replyCount > 0;
  bool get isReply => replyTo != null;

  // ✅ Геттеры для отображения
  String get replyInfo {
    if (isSeed) return 'Семя';
    if (isBranch) return 'Ветка ($replyCount ответов)';
    return 'Ответ на историю';
  }

  // ✅ ДОБАВЛЕН МЕТОД ДЛЯ ПОЛУЧЕНИЯ АВАТАРА ИЗ НОВОГО ФОРМАТА
  String? get avatarUrl {
    // 1. Проверяем authorAvatar (старый формат)
    if (authorAvatar != null && authorAvatar!.isNotEmpty) {
      return 'https://ravell-backend-1.onrender.com$authorAvatar';
    }

    // 2. Проверяем user -> profile -> avatar (новый формат)
    if (user != null &&
        user!['profile'] != null &&
        user!['profile'] is Map<String, dynamic>) {
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
    return 'Пользователь #$userId';
  }

  // ✅ ДОБАВЛЕН МЕТОД ДЛЯ ПОЛУЧЕНИЯ ПОЛНОГО ИМЕНИ
  String? get fullName {
    if (user != null) {
      final firstName = user!['first_name'] as String?;
      final lastName = user!['last_name'] as String?;

      if (firstName != null && lastName != null) {
        return '$firstName $lastName';
      } else if (firstName != null) {
        return firstName;
      } else if (lastName != null) {
        return lastName;
      }
    }
    return null;
  }

  // ✅ ДОБАВЛЕН МЕТОД ДЛЯ ПОЛУЧЕНИЯ EMAIL
  String? get email {
    if (user != null && user!['email'] != null) {
      return user!['email'] as String;
    }
    return null;
  }

  // ✅ ДОБАВЛЕН МЕТОД ДЛЯ ПРОВЕРКИ ВЕРИФИКАЦИИ
  bool get isVerified {
    if (user != null &&
        user!['profile'] != null &&
        user!['profile'] is Map<String, dynamic>) {
      return user!['profile']['is_verified'] == true;
    }
    return false;
  }
}
