class Hashtag {
  final int id;
  final String name;

  Hashtag({required this.id, required this.name});

  factory Hashtag.fromJson(Map<String, dynamic> json) {
    return Hashtag(id: json['id'], name: json['name']);
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
