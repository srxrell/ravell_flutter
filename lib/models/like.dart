class Like {
  final int userId;
  final int storyId;
  final bool isLike;

  Like({required this.userId, required this.storyId, required this.isLike});

  factory Like.fromJson(Map<String, dynamic> json) {
    return Like(
      userId: json['userId'],
      storyId: json['storyId'],
      isLike: json['isLike'],
    );
  }
}
