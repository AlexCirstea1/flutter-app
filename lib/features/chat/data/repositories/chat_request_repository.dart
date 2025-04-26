import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config/environment.dart';
import '../../../../core/config/logger_config.dart';
import '../../../../core/data/services/storage_service.dart';
import '../../domain/models/chat_request_dto.dart';
import '../services/key_management_service.dart';
import '../services/message_crypto_service.dart';

class ChatRequestRepository {
  final StorageService storageService;
  final KeyManagementService keyManagementService;
  final MessageCryptoService cryptoService;

  ChatRequestRepository({
    required this.storageService,
    required this.keyManagementService,
    required this.cryptoService,
  });

  Future<List<ChatRequestDTO>> fetchPendingChatRequests() async {
    final accessToken = await storageService.getAccessToken();
    if (accessToken == null) return [];

    final url = Uri.parse('${Environment.apiBaseUrl}/chat-requests');
    try {
      final resp = await http.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (resp.statusCode == 200) {
        final body = utf8.decode(resp.bodyBytes);
        final List<dynamic> raw = jsonDecode(body);
        return raw.map((e) => ChatRequestDTO.fromJson(e)).toList();
      }
    } catch (e) {
      LoggerService.logError('fetchPendingChatRequests failed', e);
    }
    return [];
  }

  Future<void> acceptChatRequest({required String requestId}) async {
    final accessToken = await storageService.getAccessToken();
    if (accessToken == null) return;

    final url =
        Uri.parse('${Environment.apiBaseUrl}/chat-requests/$requestId/accept');
    await http.post(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
  }

  Future<void> rejectChatRequest({required String requestId}) async {
    final accessToken = await storageService.getAccessToken();
    if (accessToken == null) return;

    final url =
        Uri.parse('${Environment.apiBaseUrl}/chat-requests/$requestId/reject');
    await http.post(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
  }

  Future<ChatRequestDTO?> sendChatRequest({
    required String chatUserId,
    required String content,
  }) async {
    final accessToken = await storageService.getAccessToken();
    final currentUserId = await storageService.getUserId();

    if (accessToken == null || currentUserId == null) {
      LoggerService.logError('Auth missing – cannot send chat request');
      return null;
    }

    // Get public keys for both users
    final meKey =
        await keyManagementService.getOrFetchPublicKeyAndVersion(currentUserId);
    final themKey =
        await keyManagementService.getOrFetchPublicKeyAndVersion(chatUserId);

    if (meKey == null || themKey == null) {
      LoggerService.logError('Public key lookup failed');
      return null;
    }

    // Encrypt the message
    final encryptedData = await cryptoService.encryptMessage(
      content: content,
      senderKey: meKey,
      recipientKey: themKey,
    );

    // Build request body
    final body = {
      'sender': currentUserId,
      'recipient': chatUserId,
      ...encryptedData,
      'type': 'CHAT_REQUEST',
    };

    // Send the request
    final url = Uri.parse('${Environment.apiBaseUrl}/chat-requests');
    final resp = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode == 200) {
      LoggerService.logInfo('Chat request sent successfully');
      return ChatRequestDTO.fromJson(jsonDecode(resp.body));
    } else {
      LoggerService.logError(
          'sendChatRequest failed (code ${resp.statusCode}) body=${resp.body}');
      return null;
    }
  }
}
