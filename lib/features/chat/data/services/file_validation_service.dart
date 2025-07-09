// lib/features/chat/data/services/file_validation_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:path/path.dart' as p;
import '../../../../core/config/environment.dart';
import '../../../../core/config/logger_config.dart';
import '../../../../core/data/services/storage_service.dart';

class FileValidationResponse {
  final String fileId;
  final String message;
  final String blockchainHash;
  final String currentHash;
  final int uploadTimestamp; // Change from String? to int
  final bool isValid;

  FileValidationResponse({
    required this.fileId,
    required this.message,
    required this.blockchainHash,
    required this.currentHash,
    required this.uploadTimestamp,
    required this.isValid,
  });

  factory FileValidationResponse.fromJson(Map<String, dynamic> json) {
    return FileValidationResponse(
      fileId: json['fileId'] as String,
      message: json['message'] as String,
      blockchainHash: json['blockchainHash'] as String,
      currentHash: json['currentHash'] as String,
      uploadTimestamp: json['uploadTimestamp'] as int, // Parse as int
      isValid: json['valid'] as bool,
    );
  }
}
class FileValidationService {
  final StorageService storageService;

  FileValidationService({required this.storageService});

  Future<FileValidationResponse?> validateFile({
    required String fileId,
    required File file,
  }) async {
    final accessToken = await storageService.getAccessToken();
    if (accessToken == null) {
      LoggerService.logError('[VAL] no access-token');
      return null;
    }

    final uri = Uri.parse('${Environment.apiBaseUrl}/files/$fileId/validate');
    final client = http.Client();
    try {
      LoggerService.logInfo('[VAL] preparing multipart → $uri');

      /* 1️⃣ read file & meta */
      final bytes     = await file.readAsBytes();
      final fileName  = p.basename(file.path);
      final sizeBytes = bytes.length;
      LoggerService.logInfo('[VAL] file $fileName  size=$sizeBytes B');

      final metaJson = jsonEncode({
        'fileId'    : fileId,
        'fileName'  : fileName,
        'sizeBytes' : sizeBytes,
        'mimeType'  : 'application/octet-stream',
      });

      /* 2️⃣ build request (same pattern as upload) */
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $accessToken'
        ..files.add(http.MultipartFile.fromBytes(
          'meta',
          utf8.encode(metaJson),
          contentType: MediaType('application', 'json'),
        ))
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename : fileName,
          contentType: MediaType('application', 'octet-stream'),
        ));

      LoggerService.logInfo('[VAL] sending request, headers=${request.headers}');

      /* 3️⃣ send & await */
      final streamed = await client
          .send(request)
          .timeout(const Duration(seconds: 60), onTimeout: () {
        LoggerService.logError('[VAL] TIMEOUT after 60 s');
        throw TimeoutException('validation request timed-out');
      });

      LoggerService
          .logInfo('[VAL] response status=${streamed.statusCode}   '
          'contentLength=${streamed.contentLength}');

      final body = await streamed.stream.bytesToString();
      LoggerService.logInfo('[VAL] response body: $body');

      if (streamed.statusCode == 200) {
        return FileValidationResponse.fromJson(jsonDecode(body));
      } else {
        LoggerService.logError('[VAL] HTTP ${streamed.statusCode}');
        return null;
      }
    } catch (e) {
      LoggerService.logError('[VAL] exception: $e');
      return null;
    } finally {
      client.close();
    }
  }

}
