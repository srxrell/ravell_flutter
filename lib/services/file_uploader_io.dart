// file_uploader_io.dart (Для dart:io)

import 'package:http/http.dart' as http;
import 'package:readreels/services/file_uploader_stub.dart';

// Реализация для Mobile/Desktop (dart:io)
class IoFileUploader implements FileUploader {
  @override
  Future<http.MultipartFile> createAvatarMultipartFile(
    String fieldName, {
    String? filePath,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    if (filePath == null) {
      throw Exception('FilePath must be provided for dart:io implementation.');
    }
    // Используем fromPath, который работает с dart:io.File
    return http.MultipartFile.fromPath(fieldName, filePath);
  }
}

// Возвращаем реализацию для Mobile/Desktop
FileUploader getFileUploader() => IoFileUploader();
