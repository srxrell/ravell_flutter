// file_uploader_web.dart (Для Web)

import 'package:http/http.dart' as http;
import 'package:readreels/services/file_uploader_stub.dart';

// Реализация для Web (без dart:io)
class WebFileUploader implements FileUploader {
  @override
  Future<http.MultipartFile> createAvatarMultipartFile(
      String fieldName, {
        String? filePath,
        List<int>? fileBytes,
        String? fileName,
      }) async {
    if (fileBytes == null || fileName == null) {
      throw Exception('File bytes and name must be provided for Web implementation.');
    }
    // Используем fromBytes, который работает везде и идеален для Web
    return http.MultipartFile.fromBytes(
      fieldName,
      fileBytes,
      filename: fileName,
    );
  }
}

// Возвращаем реализацию для Web
FileUploader getFileUploader() => WebFileUploader();