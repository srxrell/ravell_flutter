import 'package:equatable/equatable.dart';

class Hashtag extends Equatable {
  final int id;
  final String name;

  const Hashtag({required this.id, required this.name});

  factory Hashtag.fromJson(Map<String, dynamic> json) {
    return Hashtag(id: json['id'], name: json['name']);
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  List<Object?> get props => [id, name];
}
