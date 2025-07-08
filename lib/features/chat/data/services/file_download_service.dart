import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/config/environment.dart';
import '../../../../core/config/logger_config.dart';
import '../../../../core/data/services/storage_service.dart';
import '../../domain/models/message_dto.dart';
import 'message_crypto_service.dart';

class FileDownloadService {
  final StorageService storageService;
  final MessageCryptoService cryptoService;

  FileDownloadService({
    required this.storageService,
    required this.cryptoService,
  });

  Future<File?> downloadAndDecryptFile({
    required MessageDTO message,
    required Function(double) onProgress,
    required Function(String) onError,
  }) async {
    try {
      onProgress(0.1);

      // Get file ID from message file info
      final fileId = message.file?.fileId ?? message.id;

      // Get access token
      final accessToken = await storageService.getAccessToken();
      if (accessToken == null) {
        onError('Authentication error');
        return null;
      }

      // Download encrypted file
      final url = Uri.parse('${Environment.apiBaseUrl}/files/$fileId');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      onProgress(0.5);

      if (response.statusCode != 200) {
        onError('Download failed: ${response.statusCode}');
        return null;
      }

      // Get the encrypted data
      final encryptedBytes = response.bodyBytes;

      // Determine current user and key selection
      final currentUserId = await storageService.getUserId();
      final isRecipient = message.recipient == currentUserId;

      // Get appropriate key version and encrypted key
      final version = isRecipient ? message.recipientKeyVersion : message.senderKeyVersion;
      final privateKey = await storageService.getPrivateKey(version);
      if (privateKey == null) {
        onError('Decryption key not available');
        return null;
      }

      final encryptedKey = isRecipient
          ? message.encryptedKeyForRecipient
          : message.encryptedKeyForSender;

      onProgress(0.7);

      // Decrypt the file data
      final decryptedBytes = await cryptoService.decryptData(
        cipherBytes: encryptedBytes,
        iv: message.iv,
        encryptedKey: encryptedKey,
        privateKey: privateKey,
      );

      onProgress(0.9);

      // Use original filename from file info, or extract from plaintext with proper extension
      String fileName;
      if (message.file?.fileName != null) {
        fileName = message.file!.fileName;
      } else {
        // Extract filename from plaintext and ensure it has an extension
        final extractedName = message.plaintext?.replaceFirst('[File] ', '') ?? 'download';
        fileName = extractedName.contains('.') ? extractedName : '$extractedName.bin';
      }

      // Save to temporary file with proper filename
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(decryptedBytes);

      onProgress(1.0);
      LoggerService.logInfo('File decrypted and saved: ${file.path}');
      return file;
    } catch (e) {
      LoggerService.logError('File download/decrypt error: $e');
      onError('Error: $e');
      return null;
    }
  }

  Future<void> openFile(File file) async {
    try {
      await OpenFilex.open(file.path);
    } catch (e) {
      LoggerService.logError('Error opening file: $e');
    }
  }
}