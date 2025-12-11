// activity_service.dart
import 'package:flutter/material.dart';
import '../models/activity_event.dart';

class ActivityService {
  ActivityService._();
  static final ActivityService instance = ActivityService._();

  // ValueNotifier для уведомления UI
  final ValueNotifier<List<ActivityEvent>> eventsNotifier =
      ValueNotifier<List<ActivityEvent>>([]);

  List<ActivityEvent> get events => eventsNotifier.value;

  void addEvent(ActivityEvent event) {
    final updated = [event, ...eventsNotifier.value]; // новые сверху
    eventsNotifier.value = updated;
  }

  void clearEvents() {
    eventsNotifier.value = [];
  }
}
