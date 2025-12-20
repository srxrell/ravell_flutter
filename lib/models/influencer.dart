class Influencer {
  final int id;
  final String username;
  final String? avatar;
  final int storyCount;
  final bool isFollowing;
  final bool isEarly;

  Influencer({
    required this.id,
    required this.username,
    required this.avatar,
    required this.storyCount,
    required this.isFollowing,
    required this.isEarly,
  });

  factory Influencer.fromJson(Map<String, dynamic> json) {
    return Influencer(
      id: json['id'],
      username: json['username'],
      avatar: json['avatar'],
      storyCount: json['story_count'] ?? 0,
      isFollowing: json['is_following'] ?? false,
      isEarly: json['is_early'] ?? false,
    );
  }
}
