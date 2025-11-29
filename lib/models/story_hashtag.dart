class StoryHashtag {
  final int storyId;
  final int hashtagId;

  StoryHashtag({required this.storyId, required this.hashtagId});

  factory StoryHashtag.fromJson(Map<String, dynamic> json) {
    return StoryHashtag(storyId: json['storyId'], hashtagId: json['hashtagId']);
  }
}
