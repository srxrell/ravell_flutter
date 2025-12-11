class ActivityEvent {
  final String type; // 'follow', 'reply'
  final String username;
  final DateTime timestamp;

  ActivityEvent({
    required this.type,
    required this.username,
    required this.timestamp,
  });
}
