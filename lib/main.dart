import 'dart:async';

import 'package:flutter/material.dart';
import 'readreels.dart';

void main() {
  // Оборачиваем в try-catch для отлова ошибок при запуске
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(const ReadReelsApp());
    },
    (error, stackTrace) {
      // Логируем ошибку
      print('🚨 CRASH: $error');
      print('Stack trace: $stackTrace');
      // Можно отправить в Crashlytics или сохранить в файл
    },
  );
}
