import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';

import '../config/environment.dart';
import '../config/logger_config.dart';
import '../models/message_dto.dart';
import '../services/storage_service.dart';

class ChatService {
  final StorageService storageService;

  final List<MessageDTO> messages = [];

  bool isFetchingHistory = false;

  ChatService({required this.storageService});

  Future<void> fetchChatHistory({
    required String chatUserId,
    required VoidCallback onMessagesUpdated,
  }) async {
    isFetchingHistory = true;

    final accessToken = await storageService.getAccessToken();
    if (accessToken == null) {
      LoggerService.logError('Access token not found');
      isFetchingHistory = false;
      return;
    }

    final url =
        Uri.parse('${Environment.apiBaseUrl}/messages?recipientId=$chatUserId');
    try {
      final response = await http
          .get(url, headers: {'Authorization': 'Bearer $accessToken'});
      if (response.statusCode == 200) {
        final rawBody = utf8.decode(response.bodyBytes);
        final List<dynamic> history = jsonDecode(rawBody);

        messages.clear();
        for (var m in history) {
          messages.add(
            MessageDTO(
              id: m['id']?.toString() ?? const Uuid().v4(),
              sender: m['sender'] ?? '',
              recipient: m['recipient'] ?? '',
              content: m['content'] ?? '',
              timestamp: DateTime.parse(
                m['timestamp'] ?? DateTime.now().toIso8601String(),
              ),
              isRead: m['read'] ?? false,
              readTimestamp: m['readTimestamp'] != null
                  ? DateTime.parse(m['readTimestamp'])
                  : null,
            ),
          );
        }
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        // Mark unread messages as read
        await markMessagesAsRead();
        onMessagesUpdated();
      } else {
        LoggerService.logError(
            'Failed to fetch chat history. Code: ${response.statusCode}');
      }
    } catch (e) {
      LoggerService.logError('Error fetching chat history', e);
    } finally {
      isFetchingHistory = false;
    }
  }

  Future<void> markMessagesAsRead() async {
    final userId = await storageService.getUserId();
    if (userId == null) return;
    final accessToken = await storageService.getAccessToken();
    if (accessToken == null) return;

    final unreadMessages =
        messages.where((m) => m.recipient == userId && !m.isRead).toList();
    if (unreadMessages.isEmpty) return;

    final url = Uri.parse('${Environment.apiBaseUrl}/chats/mark-as-read');
    final body = {
      'messageIds': unreadMessages.map((m) => m.id).toList(),
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        LoggerService.logInfo('Marked messages as read on server.');
        final now = DateTime.now();
        for (var msg in unreadMessages) {
          msg.isRead = true;
          msg.readTimestamp = now;
        }
      } else {
        LoggerService.logError(
            'Failed to mark messages as read (status=${response.statusCode}).');
      }
    } catch (e) {
      LoggerService.logError('Error marking messages as read', e);
    }
  }

  Future<void> markSingleMessageAsRead(String messageId) async {
    final accessToken = await storageService.getAccessToken();
    if (accessToken == null) return;

    final url = Uri.parse('${Environment.apiBaseUrl}/chats/mark-as-read');
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'messageIds': [messageId]
        }),
      );
      if (response.statusCode == 200) {
        LoggerService.logInfo("Message $messageId marked as read via REST.");
        final now = DateTime.now();
        final msgIndex = messages.indexWhere((m) => m.id == messageId);
        if (msgIndex >= 0) {
          messages[msgIndex].isRead = true;
          messages[msgIndex].readTimestamp = now;
        }
      } else {
        LoggerService.logError(
            'Failed to mark msg as read. Code ${response.statusCode}');
      }
    } catch (e) {
      LoggerService.logError('Error marking single msg as read', e);
    }
  }

  /// The crucial method: handle "SENT_MESSAGE" vs "INCOMING_MESSAGE"
  void handleIncomingOrSentMessage(Map<String, dynamic> msg,
      String currentUserId, VoidCallback onMessagesUpdated) {
    final type = msg['type'] ?? ''; // "INCOMING_MESSAGE" or "SENT_MESSAGE"
    final sender = msg['sender'] ?? '';
    final recipient = msg['recipient'] ?? '';

    // If I'm the sender, ignore "INCOMING_MESSAGE"
    if (type == "INCOMING_MESSAGE" && sender == currentUserId) {
      // Skip it
      return;
    }
    // If I'm not the sender, ignore "SENT_MESSAGE"
    if (type == "SENT_MESSAGE" && sender != currentUserId) {
      // Skip it
      return;
    }

    final newMsg = MessageDTO(
      id: msg['id']?.toString() ?? const Uuid().v4(),
      sender: msg['sender'] ?? '',
      recipient: msg['recipient'] ?? '',
      content: msg['content'] ?? '',
      timestamp: DateTime.parse(
        msg['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      isRead: msg['read'] ?? false,
      readTimestamp: msg['readTimestamp'] != null
          ? DateTime.parse(msg['readTimestamp'])
          : null,
      clientTempId: msg['clientTempId']?.toString(),
    );

    // Only do ephemeral replacement if:
    //   1) type == "SENT_MESSAGE"
    //   2) newMsg.sender == currentUserId
    //   3) clientTempId is not empty
    if (type == 'SENT_MESSAGE' &&
        newMsg.sender == currentUserId &&
        newMsg.clientTempId != null &&
        newMsg.clientTempId!.isNotEmpty) {
      final ephemeralIndex =
          messages.indexWhere((m) => m.id == newMsg.clientTempId);
      if (ephemeralIndex >= 0) {
        messages[ephemeralIndex] = newMsg;
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        onMessagesUpdated();
        return;
      }
    }

    // Otherwise do normal insert/update
    final existingIndex = messages.indexWhere((m) => m.id == newMsg.id);
    if (existingIndex >= 0) {
      messages[existingIndex] = newMsg;
    } else {
      messages.add(newMsg);
    }
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    onMessagesUpdated();

    // If I'm the recipient, mark it read
    if (newMsg.recipient == currentUserId && !newMsg.isRead) {
      markSingleMessageAsRead(newMsg.id);
    }
  }

  void handleReadReceipt(Map<String, dynamic> message, String chatUserId,
      VoidCallback onMessagesUpdated) {
    final readerId = message['readerId'] ?? '';
    final List<dynamic> messageIds = message['messageIds'] ?? [];
    final String readTimestampStr = message['readTimestamp'] ?? '';
    final DateTime readTimestamp = readTimestampStr.isNotEmpty
        ? DateTime.parse(readTimestampStr)
        : DateTime.now();

    // If the "reader" is the other user, update local state
    if (readerId == chatUserId) {
      for (var msg in messages) {
        if (messageIds.contains(msg.id)) {
          msg.isRead = true;
          msg.readTimestamp = readTimestamp;
        }
      }
      onMessagesUpdated();
    }
  }

  /// Send a new message
  Future<void> sendMessage({
    required String currentUserId,
    required String chatUserId,
    required String content,
    required Function(MessageDTO ephemeral) onEphemeralAdded,
    required void Function(Map<String, dynamic> msgMap) stompSend,
  }) async {
    final now = DateTime.now();
    final tempId = const Uuid().v4();

    // Create ephemeral message
    final ephemeralMessage = MessageDTO(
      id: tempId,
      sender: currentUserId,
      recipient: chatUserId,
      content: content,
      timestamp: now,
      isRead: false,
      clientTempId: null,
    );
    onEphemeralAdded(ephemeralMessage);

    // Build STOMP message
    final msgMap = {
      'sender': currentUserId,
      'recipient': chatUserId,
      'content': content,
      'clientTempId': tempId,
    };
    stompSend(msgMap);
  }
}
