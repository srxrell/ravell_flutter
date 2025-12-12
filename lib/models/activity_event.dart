class ActivityEvent {
  final String type; // 'follow', 'reply' и т.п.
  final String username;
  final DateTime timestamp;

  ActivityEvent({
    required this.type,
    required this.username,
    required this.timestamp,
  });

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    return ActivityEvent(
      type: json['type'] ?? 'unknown',
      username: json['username'] ?? 'Система',
      timestamp:
          json['timestamp'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] * 1000)
              : DateTime.now(),
    );
  }
}
