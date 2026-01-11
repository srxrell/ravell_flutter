import 'package:equatable/equatable.dart';

class User extends Equatable {
  final int id;
  final String username;
  final int? tgChatId; // Добавляем опциональное поле (может быть null)

  const User({
    required this.id, 
    required this.username, 
    this.tgChatId, // Сюда прилетит ID из Go
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'], 
      username: json['username'],
      // В Go ты назвал его tg_chat_id, поэтому тут берем именно этот ключ
      tgChatId: json['tg_chat_id'], 
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'tg_chat_id': tgChatId,
      };

  @override
  List<Object?> get props => [id, username, tgChatId]; // Обнови props для Equatable
}