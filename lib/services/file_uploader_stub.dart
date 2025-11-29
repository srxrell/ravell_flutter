// file_uploader_stub.dart
// Этот файл определяет интерфейс FileUploader.

import 'package:http/http.dart' as http;

/// Определяет интерфейс для загрузки файла, который будет реализован
/// отдельно для dart:io (Mobile/Desktop) и dart:html (Web).
abstract class FileUploader {
  Future<http.MultipartFile> createAvatarMultipartFile(
      String fieldName, {
        String? filePath,
        List<int>? fileBytes, // Для Web
        String? fileName,     // Для Web
      });
}

// Функцию, которая будет возвращать экземпляр Uploader,
// мы реализуем в двух других файлах.
FileUploader getFileUploader() => throw UnsupportedError('Cannot create a FileUploader without dart:io or dart:html');