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
  final String? blockchainHash; // Make nullable
  final String? currentHash; // Make nullable
  final int? uploadTimestamp; // Make nullable
  final bool isValid;

  FileValidationResponse({
    required this.fileId,
    required this.message,
    this.blockchainHash, // Remove required
    this.currentHash, // Remove required
    this.uploadTimestamp, // Remove required
    required this.isValid,
  });

  factory FileValidationResponse.fromJson(Map<String, dynamic> json) {
    return FileValidationResponse(
      fileId: json['fileId'] as String,
      message: json['message'] as String,
      blockchainHash: json['blockchainHash'] as String?, // Cast to nullable
      currentHash: json['currentHash'] as String?, // Cast to nullable
      uploadTimestamp: json['uploadTimestamp'] as int?, // Cast to nullable
      isValid: json['valid'] as bool,
    );
  }
}

class FileValidationService {
  final StorageService storageService;

  FileValidationService({required this.storageService});

  Future<FileValidationResponse?> validateFile({
    required String fileId,
  }) async {
    final accessToken = await storageService.getAccessToken();
    if (accessToken == null) {
      LoggerService.logError('[VAL] no access-token');
      return null;
    }

    final uri = Uri.parse('${Environment.apiBaseUrl}/files/$fileId/validate');
    final client = http.Client();
    try {
      LoggerService.logInfo('[VAL] sending POST request to → $uri');

      final response = await client.post(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(const Duration(seconds: 30), onTimeout: () {
        LoggerService.logError('[VAL] TIMEOUT after 30 s');
        throw TimeoutException('validation request timed-out');
      });

      LoggerService.logInfo('[VAL] response status=${response.statusCode}');
      LoggerService.logInfo('[VAL] response body: ${response.body}');

      if (response.statusCode == 200) {
        return FileValidationResponse.fromJson(jsonDecode(response.body));
      } else {
        LoggerService.logError('[VAL] HTTP ${response.statusCode}');
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
