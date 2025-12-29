class Influencer {
  final int id;
  final String username;
  final String? avatar;
  final int storyCount;
  final bool isFollowing;
  final bool isEarly;
  final String? featureTitle;
  final String? featureDescription;

  Influencer({
    required this.id,
    required this.username,
    required this.avatar,
    required this.storyCount,
    required this.isFollowing,
    required this.isEarly,
    this.featureTitle,
    this.featureDescription,
  });

  factory Influencer.fromJson(Map<String, dynamic> json) {
    return Influencer(
      id: json['id'],
      username: json['username'],
      avatar: json['avatar'],
      storyCount: json['story_count'] ?? 0,
      isFollowing: json['is_following'] ?? false,
      isEarly: json['is_early'] ?? false,
      featureTitle: json['feature']?['title'],
      featureDescription: json['description'],
    );
  }

  String? get resolvedAvatar {
    if (avatar == null || avatar!.isEmpty) return null;
    final cleanUrl = avatar!.replaceAll(RegExp(r'\s+'), '');
    if (cleanUrl.contains('Useragent') || cleanUrl.contains('User agent')) return null;
    if (cleanUrl.toLowerCase() == 'null') return null;

    return cleanUrl.startsWith('http')
        ? cleanUrl
        : 'https://ravell-backend-1.onrender.com$cleanUrl';
  }
}
