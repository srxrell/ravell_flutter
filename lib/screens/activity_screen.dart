import 'package:flutter/material.dart';
import 'package:readreels/services/globals.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        itemCount: notificationManager.notifications.length,
        itemBuilder: (context, index) {
          final notification = notificationManager.notifications[index];
          return ListTile(
            title: Text(notification.title),
            subtitle: Text(notification.body),
            trailing: Text(
              "${notification.timestamp.hour}:${notification.timestamp.minute}",
              style: const TextStyle(fontSize: 12),
            ),
          );
        },
      ),
    );
  }
}
