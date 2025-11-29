import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:readreels/models/story.dart';

class UserStoryList extends StatelessWidget {
  final List<Story> stories;

  const UserStoryList({super.key, required this.stories});

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 30.0),
          child: Text(
            "Пользователь еще не опубликовал ни одной истории.",
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        ),
      );
    }

    // Используем Column с ListView.builder, чтобы избежать проблем со скроллингом,
    // так как родитель - SingleChildScrollView.
    return Column(
      // Устанавливаем минимальный размер, чтобы ListView корректно отображался
      // внутри Column/SingleChildScrollView
      mainAxisSize: MainAxisSize.min,
      children: stories.map((story) {
        // Создаем виджет карточки для каждой истории
        return _buildStoryCard(context, story);
      }).toList(),
    );
  }

  Widget _buildStoryCard(BuildContext context, Story story) {
    // Получаем ID автора из истории для навигации
    final authorId = story.userId;

    return Card(
      margin: const EdgeInsets.only(bottom: 15.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          // Навигация к ленте историй пользователя, начиная с этой истории
          if (story.id != null && authorId != null) {
            // Маршрут: /story/:storyId?authorId=:authorId
            context.push('/story/${story.id}?authorId=$authorId');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Ошибка: Недостаточно данных для навигации.")),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок
              Text(
                story.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Краткое содержание
              Text(
                story.content.length > 100
                    ? '${story.content.substring(0, 100)}...'
                    : story.content,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Статистика
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '❤️ ${story.likesCount ?? 0} | 💬 ${story.commentsCount ?? 0}',
                    style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
                  ),
                  Text(
                    story.createdAt != null ? 'Дата: ${story.createdAt!}' : 'Неизвестно',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}