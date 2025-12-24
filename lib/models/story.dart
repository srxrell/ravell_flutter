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

  // ✅ ДОБАВЬТЕ ЭТИ ПОЛЯ
  final String? username; // Имя пользователя
  final String? avatarUrl; // URL аватара
  final bool isEarly; // Флаг раннего доступа

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

    // ✅ ДОБАВЬТЕ ЭТИ ПАРАМЕТРЫ
    this.username,
    this.avatarUrl,
    this.isEarly = false,
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
    String? username;
    bool? isEarly;

    if (json['user'] != null && json['user'] is Map<String, dynamic>) {
      userData = json['user'] as Map<String, dynamic>;
      username = userData['username'] as String?;

      if (userData['profile'] != null &&
          userData['profile'] is Map<String, dynamic>) {
        final profile = userData['profile'] as Map<String, dynamic>;
        avatarUrl = profile['avatar'] as String?;
      }
      
      // Проверяем is_early в user или profile
      isEarly = userData['is_early'] == true || 
                (userData['profile'] != null && userData['profile']['is_early'] == true);
    }

    // ✅ ТАКЖЕ ПРОВЕРЯЕМ ПРЯМЫЕ ПОЛЯ В КОРНЕ JSON
    if (avatarUrl == null && json['avatar'] != null) {
      avatarUrl = json['avatar'] as String;
    }

    if (username == null && json['username'] != null) {
      username = json['username'] as String;
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
      authorAvatar: json['author_avatar'] as String?,
      userLiked: json['user_liked'] ?? false,
      hashtags: parsedHashtags,
      user: userData,

      // Новые поля
      wordCount: json['word_count'] ?? 0,
      replyTo: replyTo != null ? int.tryParse(replyTo.toString()) : null,
      replyCount: json['reply_count'] ?? 0,
      lastReplyAt: lastReplyAt != null ? DateTime.parse(lastReplyAt) : null,

      // ✅ ИНИЦИАЛИЗИРУЕМ ДОБАВЛЕННЫЕ ПОЛЯ
      username: username,
      avatarUrl: avatarUrl,
      isEarly: isEarly ?? json['is_early'] == true,
    );
  }

  // Исправленный метод copyWith
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
    String? username, // ✅ ДОБАВЬТЕ
    String? avatarUrl, // ✅ ДОБАВЬТЕ
    bool? isEarly, // ✅ ДОБАВЬТЕ
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
      username: username ?? this.username, // ✅ ДОБАВЬТЕ
      avatarUrl: avatarUrl ?? this.avatarUrl, // ✅ ДОБАВЬТЕ
      isEarly: isEarly ?? this.isEarly, // ✅ ДОБАВЬТЕ
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
      'username': username, // ✅ ДОБАВЬТЕ
      'avatar': avatarUrl, // ✅ ДОБАВЬТЕ
      'is_early': isEarly, // ✅ ДОБАВЬТЕ
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

  // ✅ ИСПРАВЛЕННЫЙ ГЕТТЕР ДЛЯ ПОЛУЧЕНИЯ АВАТАРА
    String? get resolvedAvatarUrl {
    // Вспомогательная функция для очистки
    String? clean(String? s) {
      if (s == null) return null;
      final trimmed = s.replaceAll(RegExp(r'\s+'), '');
      if (trimmed.isEmpty || trimmed.contains('Useragent')) return null;
       // Также проверяем исходную строку на пробелы, если это сообщение об ошибке
      if (s.contains('User agent')) return null;
      return trimmed;
    }

    String resolve(String path) {
      if (path.startsWith('http')) return path;
      final String cleanPath = path.startsWith('/') ? path : '/$path';
      return 'https://ravell-backend-1.onrender.com$cleanPath';
    }

    // 1. Проверяем поле avatarUrl (прямое)
    final cleanAvatarUrl = clean(avatarUrl);
    if (cleanAvatarUrl != null) {
      return resolve(cleanAvatarUrl);
    }

    // 2. Проверяем authorAvatar (старый формат)
    final cleanAuthorAvatar = clean(authorAvatar);
    if (cleanAuthorAvatar != null) {
      return resolve(cleanAuthorAvatar);
    }

    // 3. Проверяем user -> profile -> avatar (новый формат)
    if (user != null &&
        user!['profile'] != null &&
        user!['profile'] is Map) {
      final profile = user!['profile'] as Map;
      final avatar = clean(profile['avatar'] as String?);
      if (avatar != null) {
        return resolve(avatar);
      }
    }
    
    // 4. Проверяем user -> avatar
     if (user != null && user!['avatar'] != null) {
      final avatar = clean(user!['avatar'] as String?);
      if (avatar != null) {
        return resolve(avatar);
      }
    }

    return null;
  }

  // ✅ ИСПРАВЛЕННЫЙ ГЕТТЕР ДЛЯ ПОЛУЧЕНИЯ ИМЕНИ ПОЛЬЗОВАТЕЛЯ
  String get resolvedUsername {
    // 1. Проверяем поле username (прямое)
    if (username != null && username!.isNotEmpty) {
      return username!;
    }

    // 2. Проверяем user -> username
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
