import 'dart:convert';

class DraftStory {
  final String id;
  final String title;
  final String content;
  final List<int> hashtagIds;
  final DateTime updatedAt;

  DraftStory({
    required this.id,
    required this.title,
    required this.content,
    required this.hashtagIds,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'hashtagIds': hashtagIds,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory DraftStory.fromJson(Map<String, dynamic> json) {
    return DraftStory(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      hashtagIds: List<int>.from(json['hashtagIds']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  static String encode(List<DraftStory> drafts) =>
      jsonEncode(drafts.map((d) => d.toJson()).toList());

  static List<DraftStory> decode(String raw) =>
      (jsonDecode(raw) as List)
          .map((e) => DraftStory.fromJson(e))
          .toList();
}
