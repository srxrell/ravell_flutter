class Subscription {
  final int followerId;
  final int followingId;

  Subscription({required this.followerId, required this.followingId});

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      followerId: json['followerId'],
      followingId: json['followingId'],
    );
  }
}
