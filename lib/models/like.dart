class Like {
  final int user_id;
  final int storyId;
  final bool isLike;

  Like({required this.user_id, required this.storyId, required this.isLike});

  factory Like.fromJson(Map<String, dynamic> json) {
    return Like(
      user_id: json['user_id'],
      storyId: json['storyId'],
      isLike: json['isLike'],
    );
  }
}
