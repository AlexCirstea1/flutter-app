import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/environment.dart';
import '../../../../core/config/logger_config.dart';
import '../../../../core/data/services/storage_service.dart';
import '../../domain/models/chat_history_dto.dart';
import '../../domain/models/file_info.dart';
import '../../domain/models/message_dto.dart';
import '../services/message_crypto_service.dart';

class MessageRepository {
  final StorageService storageService;
  final MessageCryptoService cryptoService;

  /// In-memory list of messages for a single conversation.
  final List<MessageDTO> messages = [];
  bool isFetchingHistory = false;

  MessageRepository({
    required this.storageService,
    required this.cryptoService,
  });

  Future<void> fetchChatHistory({
    required String chatUserId,
    required VoidCallback onMessagesUpdated,
  }) async {
    isFetchingHistory = true;
    final accessToken = await storageService.getAccessToken();
    if (accessToken == null) {
      LoggerService.logError('No access token. Stopping fetch.');
      isFetchingHistory = false;
      return;
    }

    final url =
        Uri.parse('${Environment.apiBaseUrl}/messages?recipientId=$chatUserId');
    try {
      final resp = await http.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (resp.statusCode == 200) {
        final rawBody = utf8.decode(resp.bodyBytes);
        final List<dynamic> rawList = jsonDecode(rawBody);
        messages.clear();
        final myUserId = await storageService.getUserId();

        for (var rawMsg in rawList) {
          final msg = parseMessageFromJson(
            Map<String, dynamic>.from(rawMsg),
          );
          await _tryDecryptMessage(msg, myUserId);
          messages.add(msg);
        }

        // Sort messages by timestamp
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        // Mark unread as read
        await markMessagesAsRead();
        onMessagesUpdated();
      } else {
        LoggerService.logError(
          'Fetch chat history error. Code=\${resp.statusCode}',
        );
      }
    } catch (e) {
      LoggerService.logError('Exception fetching chat history: \$e');
    } finally {
      isFetchingHistory = false;
    }
  }

  /// Parse JSON into MessageDTO, explicitly mapping 'read' & 'readTimestamp'.
  MessageDTO parseMessageFromJson(Map<String, dynamic> rawMsg) {
    final dto = MessageDTO.fromJson(rawMsg);

    if (rawMsg['file'] != null) {
      dto.file = FileInfo.fromJson(
        Map<String, dynamic>.from(rawMsg['file']),
      );
    }

    // Override fields from server
    if (rawMsg.containsKey('read')) {
      dto.isRead = rawMsg['read'] as bool? ?? false;
    }
    if (rawMsg['readTimestamp'] != null) {
      dto.readTimestamp = DateTime.tryParse(
        rawMsg['readTimestamp'].toString(),
      );
    }

    return dto;
  }

  Future<void> _tryDecryptMessage(
    MessageDTO msg,
    String? myUserId,
  ) async {
    if (myUserId == null || msg.ciphertext.isEmpty || msg.iv.isEmpty) {
      return;
    }

    final bool isRecipient = (msg.recipient == myUserId);
    final versionToUse =
        isRecipient ? msg.recipientKeyVersion : msg.senderKeyVersion;
    final myPrivateKey = await storageService.getPrivateKey(versionToUse);
    if (myPrivateKey == null) return;

    try {
      final ephemeralKeyEnc = isRecipient
          ? msg.encryptedKeyForRecipient
          : msg.encryptedKeyForSender;
      if (ephemeralKeyEnc.isEmpty) return;

      final plaintext = cryptoService.decryptMessage(
        ciphertext: msg.ciphertext,
        iv: msg.iv,
        encryptedKey: ephemeralKeyEnc,
        privateKey: myPrivateKey,
      );

      if (plaintext != null) {
        msg.plaintext = plaintext;
      }
    } catch (e) {
      LoggerService.logError('Decrypt fail for msg \${msg.id}: \$e');
    }
  }

  Future<void> markMessagesAsRead() async {
    final currentUserId = await storageService.getUserId();
    if (currentUserId == null) return;

    final accessToken = await storageService.getAccessToken();
    if (accessToken == null) return;

    final unread = messages
        .where((m) => m.recipient == currentUserId && !m.isRead)
        .toList();
    if (unread.isEmpty) return;

    final url = Uri.parse('${Environment.apiBaseUrl}/chats/mark-as-read');
    final body = {'messageIds': unread.map((m) => m.id).toList()};

    try {
      final resp = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final now = DateTime.now();
        for (var msg in unread) {
          msg.isRead = true;
          msg.readTimestamp = now;
        }
      } else {
        LoggerService.logError(
          'Failed to mark msgs read. Code=\${resp.statusCode}',
        );
      }
    } catch (e) {
      LoggerService.logError('Error marking msgs read: \$e');
    }
  }

  Future<void> markSingleMessageAsRead(String messageId) async {
    final accessToken = await storageService.getAccessToken();
    if (accessToken == null) return;

    final url = Uri.parse('${Environment.apiBaseUrl}/chats/mark-as-read');
    final body = {
      'messageIds': [messageId]
    };
    try {
      final resp = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final now = DateTime.now();
        final idx = messages.indexWhere(
          (m) => m.id == messageId,
        );
        if (idx >= 0) {
          messages[idx].isRead = true;
          messages[idx].readTimestamp = now;
        }
      } else {
        LoggerService.logError(
          'Failed to mark single msg read. Code=\${resp.statusCode}',
        );
      }
    } catch (e) {
      LoggerService.logError('Error marking single msg read: \$e');
    }
  }

  Future<List<ChatHistoryDTO>> fetchAllChats() async {
    final accessToken = await storageService.getAccessToken();
    if (accessToken == null) return [];

    final url = Uri.parse('${Environment.apiBaseUrl}/chats');
    try {
      final resp = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );
      if (resp.statusCode != 200) {
        LoggerService.logError(
          'fetchAllChats error. Code=\${resp.statusCode}',
        );
        return [];
      }

      final raw = jsonDecode(utf8.decode(resp.bodyBytes)) as List<dynamic>;
      final myId = await storageService.getUserId();
      final List<ChatHistoryDTO> chats =
          raw.map((e) => ChatHistoryDTO.fromJson(e)).toList();

      if (myId != null) {
        for (final chat in chats) {
          for (final m in chat.messages) {
            await _tryDecryptMessage(m, myId);
          }
          chat.messages.sort(
            (a, b) => a.timestamp.compareTo(b.timestamp),
          );
        }
      }
      chats.sort((a, b) {
        final aLast = a.messages.isNotEmpty
            ? a.messages.last.timestamp
            : DateTime.fromMillisecondsSinceEpoch(0);
        final bLast = b.messages.isNotEmpty
            ? b.messages.last.timestamp
            : DateTime.fromMillisecondsSinceEpoch(0);
        return bLast.compareTo(aLast);
      });
      return chats;
    } catch (e) {
      LoggerService.logError('fetchAllChats exception: \$e');
      return [];
    }
  }

  Future<bool> deleteMessage({required String messageId}) async {
    final accessToken = await storageService.getAccessToken();
    if (accessToken == null) {
      LoggerService.logError('[DEL] no access-token');
      return false;
    }

    final uri = Uri.parse('${Environment.apiBaseUrl}/messages/$messageId');
    try {
      LoggerService.logInfo('[DEL] sending DELETE request to → $uri');
      final response = await http.delete(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      LoggerService.logInfo('[DEL] response status=${response.statusCode}');
      if (response.statusCode == 200) {
        return true;
      } else {
        LoggerService.logError('[DEL] HTTP ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      LoggerService.logError('[DEL] exception: $e');
      return false;
    }
  }
}
