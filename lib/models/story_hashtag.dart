class StoryHashtag {
  final int storyId;
  final int hashtagId;

  StoryHashtag({required this.storyId, required this.hashtagId});

  factory StoryHashtag.fromJson(Map<String, dynamic> json) {
    return StoryHashtag(
      storyId: json['storyId'] ?? json['story_id'] ?? 0,
      hashtagId: json['hashtagId'] ?? json['hashtag_id'] ?? 0,
    );
  }

  // Метод для преобразования в JSON
  Map<String, dynamic> toJson() {
    return {'story_id': storyId, 'hashtag_id': hashtagId};
  }

  // Альтернативный метод с другим именованием полей (если нужно)
  Map<String, dynamic> toHson() {
    return {'storyId': storyId, 'hashtagId': hashtagId};
  }

  // Можно добавить вспомогательные методы
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryHashtag &&
          runtimeType == other.runtimeType &&
          storyId == other.storyId &&
          hashtagId == other.hashtagId;

  @override
  int get hashCode => storyId.hashCode ^ hashtagId.hashCode;

  @override
  String toString() {
    return 'StoryHashtag{storyId: $storyId, hashtagId: $hashtagId}';
  }

  // Метод для копирования с изменением значений
  StoryHashtag copyWith({int? storyId, int? hashtagId}) {
    return StoryHashtag(
      storyId: storyId ?? this.storyId,
      hashtagId: hashtagId ?? this.hashtagId,
    );
  }
}
