import 'package:flutter/material.dart';
import '../services/activity_service.dart';
import '../models/activity_event.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,

        title: const Text('Активность'),
      ),
      body: ValueListenableBuilder<List<ActivityEvent>>(
        valueListenable: ActivityService.instance.eventsNotifier,
        builder: (context, events, _) {
          if (events.isEmpty) {
            return const Center(child: Text('Нет активности'));
          }
          return ListView.builder(
            itemCount: events.length,
            itemBuilder: (context, index) {
              final e = events[index];
              return ListTile(
                leading: Icon(
                  e.type == 'follow' ? Icons.person_add : Icons.reply,
                ),
                title: Text(
                  e.type == 'follow'
                      ? "${e.username} подписался на вас"
                      : "${e.username} ответил на вашу историю",
                ),
                subtitle: Text(
                  "${e.timestamp.hour}:${e.timestamp.minute.toString().padLeft(2, '0')}",
                ),
              );
            },
          );
        },
      ),
    );
  }
}
