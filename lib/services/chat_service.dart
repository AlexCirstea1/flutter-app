import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/api.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'package:uuid/uuid.dart';

import '../config/environment.dart';
import '../config/logger_config.dart';
import '../models/chat_history_dto.dart';
import '../models/chat_request_dto.dart';
import '../models/message_dto.dart';
import '../services/storage_service.dart';
import '../utils/crypto_helper.dart';

/// Model that holds a user's publicKey and keyVersion.
class PublicKeyData {
  final String publicKey;
  final String keyVersion;

  PublicKeyData({required this.publicKey, required this.keyVersion});
}

class ChatService {
  final StorageService storageService;

  /// In-memory list of messages for a single conversation.
  final List<MessageDTO> messages = [];

  bool isFetchingHistory = false;

  ChatService({required this.storageService});

  // ---------------------------
  // (A) Fetch Single Conversation
  // ---------------------------
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
      final resp = await http
          .get(url, headers: {'Authorization': 'Bearer $accessToken'});
      if (resp.statusCode == 200) {
        final rawBody = utf8.decode(resp.bodyBytes);
        final List<dynamic> rawList = jsonDecode(rawBody);
        messages.clear();
        final myUserId = await storageService.getUserId();
        for (var rawMsg in rawList) {
          final msg = MessageDTO(
            id: rawMsg['id']?.toString() ?? const Uuid().v4(),
            sender: rawMsg['sender'] ?? '',
            recipient: rawMsg['recipient'] ?? '',
            senderKeyVersion: rawMsg['senderKeyVersion'] ?? '',
            recipientKeyVersion: rawMsg['recipientKeyVersion'] ?? '',
            ciphertext: rawMsg['ciphertext'] ?? '',
            iv: rawMsg['iv'] ?? '',
            encryptedKeyForSender: rawMsg['encryptedKeyForSender'] ?? '',
            encryptedKeyForRecipient: rawMsg['encryptedKeyForRecipient'] ?? '',
            timestamp: DateTime.parse(
                rawMsg['timestamp'] ?? DateTime.now().toIso8601String()),
            isRead: rawMsg['read'] ?? false,
            readTimestamp: rawMsg['readTimestamp'] != null
                ? DateTime.parse(rawMsg['readTimestamp'])
                : null,
            clientTempId: rawMsg['clientTempId'],
            type: rawMsg['type'],
            isDelivered: rawMsg['isDelivered'] ?? false,
            deliveredTimestamp: rawMsg['deliveredTimestamp'] != null
                ? DateTime.parse(rawMsg['deliveredTimestamp'])
                : null,
          );

          // Decrypt if I'm involved
          if (myUserId != null &&
              msg.ciphertext.isNotEmpty &&
              msg.iv.isNotEmpty) {
            final bool isRecipient = (msg.recipient == myUserId);
            final versionToUse =
                isRecipient ? msg.recipientKeyVersion : msg.senderKeyVersion;
            final myPrivateKey =
                await storageService.getPrivateKey(versionToUse);
            if (myPrivateKey != null) {
              try {
                final ephemeralKeyEnc = isRecipient
                    ? msg.encryptedKeyForRecipient
                    : msg.encryptedKeyForSender;
                if (ephemeralKeyEnc.isNotEmpty) {
                  final aesKeyB64 =
                      CryptoHelper.rsaDecrypt(ephemeralKeyEnc, myPrivateKey);
                  final aesKeyBytes = base64.decode(aesKeyB64);
                  final ivBytes = base64.decode(msg.iv);
                  final cipherBytes = base64.decode(msg.ciphertext);
                  final keyObj = encrypt.Key(aesKeyBytes);
                  final ivObj = encrypt.IV(ivBytes);
                  final encrypter = encrypt.Encrypter(
                      encrypt.AES(keyObj, mode: encrypt.AESMode.cbc));
                  final plain = encrypter
                      .decrypt(encrypt.Encrypted(cipherBytes), iv: ivObj);
                  msg.plaintext = plain;
                }
              } catch (e) {
                LoggerService.logError('Decrypt fail for msg ${msg.id}: $e');
              }
            }
          }
          messages.add(msg);
        }
        // Sort messages by timestamp
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        await markMessagesAsRead();
        onMessagesUpdated();
      } else {
        LoggerService.logError(
            'Fetch chat history error. Code=${resp.statusCode}');
      }
    } catch (e) {
      LoggerService.logError('Exception fetching chat history: $e');
    } finally {
      isFetchingHistory = false;
    }
  }

  // ---------------------------
  // (B) Mark Messages as Read
  // ---------------------------
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
      final resp = await http.post(url,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body));
      if (resp.statusCode == 200) {
        LoggerService.logInfo('Marked messages as read on server.');
        final now = DateTime.now();
        for (var msg in unread) {
          msg.isRead = true;
          msg.readTimestamp = now;
        }
      } else {
        LoggerService.logError(
            'Failed to mark msgs read. Code=${resp.statusCode}');
      }
    } catch (e) {
      LoggerService.logError('Error marking msgs read: $e');
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
      final resp = await http.post(url,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body));
      if (resp.statusCode == 200) {
        LoggerService.logInfo('Marked msg $messageId read on server');
        final now = DateTime.now();
        final idx = messages.indexWhere((m) => m.id == messageId);
        if (idx >= 0) {
          messages[idx].isRead = true;
          messages[idx].readTimestamp = now;
        }
      } else {
        LoggerService.logError(
            'Failed to mark single msg read. code=${resp.statusCode}');
      }
    } catch (e) {
      LoggerService.logError('Error marking single msg read: $e');
    }
  }

  // ---------------------------
  // (C) Handle Incoming or Sent Message (Real-Time)
  // ---------------------------
  void handleIncomingOrSentMessage(
    Map<String, dynamic> rawMsg,
    String currentUserId,
    VoidCallback onMessagesUpdated,
  ) async {
    final type = rawMsg['type'] ?? '';
    final sender = rawMsg['sender'] ?? '';
    final recipient = rawMsg['recipient'] ?? '';

    LoggerService.logInfo(
        "Processing message type=$type, sender=$sender, recipient=$recipient");

    // Skip if not involving current user
    if (![sender, recipient].contains(currentUserId)) {
      LoggerService.logInfo("Skipping: not my message.");
      return;
    }

    final newMsg = MessageDTO(
      id: rawMsg['id']?.toString() ?? const Uuid().v4(),
      sender: sender,
      recipient: recipient,
      senderKeyVersion: rawMsg['senderKeyVersion'] ?? '',
      recipientKeyVersion: rawMsg['recipientKeyVersion'] ?? '',
      ciphertext: rawMsg['ciphertext'] ?? '',
      iv: rawMsg['iv'] ?? '',
      encryptedKeyForSender: rawMsg['encryptedKeyForSender'] ?? '',
      encryptedKeyForRecipient: rawMsg['encryptedKeyForRecipient'] ?? '',
      timestamp: DateTime.parse(
          rawMsg['timestamp'] ?? DateTime.now().toIso8601String()),
      isRead: rawMsg['read'] ?? false,
      readTimestamp: rawMsg['readTimestamp'] != null
          ? DateTime.parse(rawMsg['readTimestamp'])
          : null,
      clientTempId: rawMsg['clientTempId'],
      type: rawMsg['type'],
      isDelivered: rawMsg['isDelivered'] ?? false,
      deliveredTimestamp: rawMsg['deliveredTimestamp'] != null
          ? DateTime.parse(rawMsg['deliveredTimestamp'])
          : null,
    );

    final bool isRecipient = (newMsg.recipient == currentUserId);
    final bool isSender = (newMsg.sender == currentUserId);

    // For messages sent by the local user, bypass decryption and use the plain text already set
    if (isSender) {
      // We assume that the ephemeral message created when sending already contains the plaintext.
      final idx = messages.indexWhere((m) => m.id == newMsg.clientTempId);
      if (idx >= 0) {
        LoggerService.logInfo(
            "Replacing ephemeral message with final message (SENT).");
        // Preserve the local plaintext
        newMsg.plaintext = messages[idx].plaintext;
        messages[idx] = newMsg;
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        onMessagesUpdated();
        return;
      }
    } else {
      // For incoming messages, perform decryption
      final versionToUse =
          isRecipient ? newMsg.recipientKeyVersion : newMsg.senderKeyVersion;
      final myPrivateKey = await storageService.getPrivateKey(versionToUse);
      LoggerService.logInfo(
          "Attempting decryption with keyVersion=$versionToUse, hasPrivateKey=${myPrivateKey != null}");
      if (myPrivateKey != null &&
          newMsg.ciphertext.isNotEmpty &&
          newMsg.iv.isNotEmpty) {
        try {
          final ephemeralKeyEnc = isRecipient
              ? newMsg.encryptedKeyForRecipient
              : newMsg.encryptedKeyForSender;
          if (ephemeralKeyEnc.isNotEmpty) {
            final aesKeyB64 =
                CryptoHelper.rsaDecrypt(ephemeralKeyEnc, myPrivateKey);
            final aesKeyBytes = base64.decode(aesKeyB64);
            final ivBytes = base64.decode(newMsg.iv);
            final cipherBytes = base64.decode(newMsg.ciphertext);
            final keyObj = encrypt.Key(aesKeyBytes);
            final ivObj = encrypt.IV(ivBytes);
            final encrypter = encrypt.Encrypter(
                encrypt.AES(keyObj, mode: encrypt.AESMode.cbc));
            final plain =
                encrypter.decrypt(encrypt.Encrypted(cipherBytes), iv: ivObj);
            newMsg.plaintext = plain;
            LoggerService.logInfo("Decrypted plaintext: '${newMsg.plaintext}'");
          }
        } catch (e) {
          LoggerService.logError('Decrypt fail for newMsg ${newMsg.id}: $e');
        }
      } else {
        LoggerService.logInfo(
            "Skipping decryption due to missing prerequisites");
      }
    }

    // Update in-memory message list
    final existIdx = messages.indexWhere((m) => m.id == newMsg.id);
    if (existIdx >= 0) {
      // For already existing message, do not overwrite local plaintext if available
      final existingPlaintext = messages[existIdx].plaintext;
      if (existingPlaintext != null && existingPlaintext.isNotEmpty) {
        newMsg.plaintext = existingPlaintext;
      }
      messages[existIdx] = newMsg;
    } else {
      messages.add(newMsg);
    }
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    onMessagesUpdated();

    if (isRecipient && !newMsg.isRead) {
      markSingleMessageAsRead(newMsg.id);
    }
  }

  // ---------------------------
  // (D) Handle New/Updated Message for Chat Listing
  // ---------------------------
  void handleNewOrUpdatedMessage({
    required Map<String, dynamic> msg,
    required String currentUserId,
    required List<ChatHistoryDTO> chatHistory,
  }) async {
    final type = msg['type'] ?? '';
    final sender = msg['sender'] ?? '';
    final recipient = msg['recipient'] ?? '';

    LoggerService.logInfo(
        "handleNewOrUpdatedMessage => type=$type, sender=$sender, recipient=$recipient");

    if (![sender, recipient].contains(currentUserId)) {
      LoggerService.logInfo("Skipping chatHistory update: not my message.");
      return;
    }

    final newMsg = MessageDTO(
      id: msg['id']?.toString() ?? const Uuid().v4(),
      sender: sender,
      recipient: recipient,
      senderKeyVersion: msg['senderKeyVersion'] ?? '',
      recipientKeyVersion: msg['recipientKeyVersion'] ?? '',
      ciphertext: msg['ciphertext'] ?? '',
      iv: msg['iv'] ?? '',
      encryptedKeyForSender: msg['encryptedKeyForSender'] ?? '',
      encryptedKeyForRecipient: msg['encryptedKeyForRecipient'] ?? '',
      timestamp:
          DateTime.parse(msg['timestamp'] ?? DateTime.now().toIso8601String()),
      isRead: msg['read'] ?? false,
      readTimestamp: msg['readTimestamp'] != null
          ? DateTime.parse(msg['readTimestamp'])
          : null,
      clientTempId: msg['clientTempId'],
      type: msg['type'],
      isDelivered: msg['isDelivered'] ?? false,
      deliveredTimestamp: msg['deliveredTimestamp'] != null
          ? DateTime.parse(msg['deliveredTimestamp'])
          : null,
    );

    final bool isRecipient = (newMsg.recipient == currentUserId);
    final versionToUse =
        isRecipient ? newMsg.recipientKeyVersion : newMsg.senderKeyVersion;
    final myPrivateKey = await storageService.getPrivateKey(versionToUse);
    if (myPrivateKey != null &&
        newMsg.ciphertext.isNotEmpty &&
        newMsg.iv.isNotEmpty) {
      try {
        final ephemeralKeyEnc = isRecipient
            ? newMsg.encryptedKeyForRecipient
            : newMsg.encryptedKeyForSender;
        if (ephemeralKeyEnc.isNotEmpty) {
          final aesKeyB64 =
              CryptoHelper.rsaDecrypt(ephemeralKeyEnc, myPrivateKey);
          final aesKeyBytes = base64.decode(aesKeyB64);
          final ivBytes = base64.decode(newMsg.iv);
          final cipherBytes = base64.decode(newMsg.ciphertext);
          final keyObj = encrypt.Key(aesKeyBytes);
          final ivObj = encrypt.IV(ivBytes);
          final encrypter =
              encrypt.Encrypter(encrypt.AES(keyObj, mode: encrypt.AESMode.cbc));
          final plain =
              encrypter.decrypt(encrypt.Encrypted(cipherBytes), iv: ivObj);
          newMsg.plaintext = plain;
          LoggerService.logInfo("Decrypted plaintext: '${newMsg.plaintext}'");
        }
      } catch (e) {
        LoggerService.logError('Decrypt fail for newMsg ${newMsg.id}: $e');
      }
    }

    final otherUserId = (sender == currentUserId) ? recipient : sender;
    final chatIndex =
        chatHistory.indexWhere((c) => c.participant == otherUserId);
    if (chatIndex == -1) {
      chatHistory.add(ChatHistoryDTO(
        participant: otherUserId,
        participantUsername: '',
        messages: [newMsg],
        unreadCount: (isRecipient && !newMsg.isRead) ? 1 : 0,
      ));
    } else {
      if (type == 'SENT_MESSAGE' && newMsg.clientTempId != null) {
        final tempId = newMsg.clientTempId!;
        final existingIdx = chatHistory[chatIndex]
            .messages
            .indexWhere((m) => m.id == tempId || m.id == newMsg.id);
        if (existingIdx >= 0) {
          chatHistory[chatIndex].messages[existingIdx] = newMsg;
        } else {
          chatHistory[chatIndex].messages.add(newMsg);
        }
      } else {
        final existingIdx = chatHistory[chatIndex]
            .messages
            .indexWhere((m) => m.id == newMsg.id);
        if (existingIdx >= 0) {
          chatHistory[chatIndex].messages[existingIdx] = newMsg;
        } else {
          chatHistory[chatIndex].messages.add(newMsg);
          if (isRecipient && !newMsg.isRead) {
            chatHistory[chatIndex].unreadCount++;
          }
        }
      }
    }

    for (var c in chatHistory) {
      c.messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
    chatHistory.sort((a, b) {
      final aLast = a.messages.isNotEmpty
          ? a.messages.last.timestamp
          : DateTime.fromMillisecondsSinceEpoch(0);
      final bLast = b.messages.isNotEmpty
          ? b.messages.last.timestamp
          : DateTime.fromMillisecondsSinceEpoch(0);
      return bLast.compareTo(aLast);
    });
  }

  // ---------------------------
  // (E) Sending an Ephemeral-Encrypted Message
  // ---------------------------
  Future<void> sendMessage({
    required String currentUserId,
    required String chatUserId,
    required String content,
    required bool oneTime,
    required Function(MessageDTO ephemeral) onEphemeralAdded,
    required void Function(Map<String, dynamic> msgMap) stompSend,
  }) async {
    final now = DateTime.now();
    final tempId = const Uuid().v4();

    // For sender messages, display the message immediately in plain text.
    final ephemeralMsg = MessageDTO(
      id: tempId,
      sender: currentUserId,
      recipient: chatUserId,
      ciphertext: '',
      iv: '',
      encryptedKeyForSender: '',
      encryptedKeyForRecipient: '',
      senderKeyVersion: '',
      recipientKeyVersion: '',
      timestamp: now,
      isRead: false,
      oneTime: oneTime,
      clientTempId: tempId,
      type: 'SENT_MESSAGE',
      plaintext: content,
    );
    onEphemeralAdded(ephemeralMsg);

    final senderData = await _getOrFetchPublicKeyAndVersion(currentUserId);
    if (senderData == null || senderData.keyVersion.isEmpty) {
      LoggerService.logError("No sender public key or version found.");
      return;
    }
    final recipientData = await _getOrFetchPublicKeyAndVersion(chatUserId);
    if (recipientData == null || recipientData.keyVersion.isEmpty) {
      LoggerService.logError("No recipient public key or version found.");
      return;
    }

    final aesKeyBytes = _makeFortunaRandom().nextBytes(32);
    final aesKey = encrypt.Key(aesKeyBytes);
    final ivBytes = _makeFortunaRandom().nextBytes(16);
    final ivObj = encrypt.IV(ivBytes);
    final encr =
        encrypt.Encrypter(encrypt.AES(aesKey, mode: encrypt.AESMode.cbc));
    final cipher = encr.encrypt(content, iv: ivObj);
    final ciphertextB64 = base64.encode(cipher.bytes);
    final ivB64 = base64.encode(ivBytes);
    final aesKeyB64 = base64.encode(aesKeyBytes);
    final encForSender =
        CryptoHelper.rsaEncrypt(aesKeyB64, senderData.publicKey);
    final encForRecipient =
        CryptoHelper.rsaEncrypt(aesKeyB64, recipientData.publicKey);

    final msgMap = {
      'sender': currentUserId,
      'recipient': chatUserId,
      'ciphertext': ciphertextB64,
      'iv': ivB64,
      'encryptedKeyForSender': encForSender,
      'encryptedKeyForRecipient': encForRecipient,
      'senderKeyVersion': senderData.keyVersion,
      'recipientKeyVersion': recipientData.keyVersion,
      'clientTempId': tempId,
      'timestamp': now.toIso8601String(),
      'type': 'SENT_MESSAGE',
      'oneTime': oneTime,
    };
    stompSend(msgMap);
  }

  // ---------------------------
  // (F) Fetch Entire Chat Listing (Chat Summaries)
  // ---------------------------
  Future<List<ChatHistoryDTO>> fetchAllChats() async {
    final accessToken = await storageService.getAccessToken();
    if (accessToken == null) {
      LoggerService.logError('No access token for fetchAllChats');
      return [];
    }
    final url = Uri.parse('${Environment.apiBaseUrl}/chats');
    try {
      final resp = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      });
      if (resp.statusCode == 200) {
        final rawBody = utf8.decode(resp.bodyBytes);
        final List<dynamic> rawList = jsonDecode(rawBody);
        final myUserId = await storageService.getUserId();
        final chats = rawList.map((c) => ChatHistoryDTO.fromJson(c)).toList();
        if (myUserId != null) {
          for (var chat in chats) {
            for (var msg in chat.messages) {
              final bool isRecipient = (msg.recipient == myUserId);
              final versionToUse =
                  isRecipient ? msg.recipientKeyVersion : msg.senderKeyVersion;
              final myPrivateKey =
                  await storageService.getPrivateKey(versionToUse);
              if (myPrivateKey != null &&
                  msg.ciphertext.isNotEmpty &&
                  msg.iv.isNotEmpty) {
                try {
                  final ephemeralKeyEnc = isRecipient
                      ? msg.encryptedKeyForRecipient
                      : msg.encryptedKeyForSender;
                  if (ephemeralKeyEnc.isNotEmpty) {
                    final aesKeyB64 =
                        CryptoHelper.rsaDecrypt(ephemeralKeyEnc, myPrivateKey);
                    final aesKeyBytes = base64.decode(aesKeyB64);
                    final ivBytes = base64.decode(msg.iv);
                    final cipherBytes = base64.decode(msg.ciphertext);
                    final aesKey = encrypt.Key(aesKeyBytes);
                    final ivObj = encrypt.IV(ivBytes);
                    final encrypter = encrypt.Encrypter(
                        encrypt.AES(aesKey, mode: encrypt.AESMode.cbc));
                    final plain = encrypter
                        .decrypt(encrypt.Encrypted(cipherBytes), iv: ivObj);
                    msg.plaintext = plain;
                  }
                } catch (e) {
                  LoggerService.logError(
                      'Decrypt fail in fetchAllChats msg ${msg.id}: $e');
                }
              }
            }
            chat.messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
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
        }
        return chats;
      } else {
        LoggerService.logError('fetchAllChats error. Code=${resp.statusCode}');
        return [];
      }
    } catch (e) {
      LoggerService.logError('fetchAllChats exception: $e');
      return [];
    }
  }

  // ---------------------------
  // (G) Public Key + Version from /user/publicKey/{id}
  // ---------------------------
  Future<PublicKeyData?> _getOrFetchPublicKeyAndVersion(String userId) async {
    final cachedKey = await storageService.getFromStorage('publicKey_$userId');
    final cachedVersion =
        await storageService.getFromStorage('publicKeyVersion_$userId');
    if (cachedKey != null &&
        cachedKey.isNotEmpty &&
        cachedVersion != null &&
        cachedVersion.isNotEmpty) {
      return PublicKeyData(publicKey: cachedKey, keyVersion: cachedVersion);
    }
    final accessToken = await storageService.getAccessToken();
    if (accessToken == null) return null;
    final url = Uri.parse('${Environment.apiBaseUrl}/user/publicKey/$userId');
    try {
      final resp = await http
          .get(url, headers: {'Authorization': 'Bearer $accessToken'});
      if (resp.statusCode == 200) {
        final jsonResp = jsonDecode(resp.body);
        final pubKey = jsonResp['publicKey'] as String? ?? '';
        final keyVer = jsonResp['version'] as String? ?? '';
        if (pubKey.isNotEmpty && keyVer.isNotEmpty) {
          await storageService.saveInStorage('publicKey_$userId', pubKey);
          await storageService.saveInStorage(
              'publicKeyVersion_$userId', keyVer);
          return PublicKeyData(publicKey: pubKey, keyVersion: keyVer);
        }
      } else {
        LoggerService.logError(
            "Failed to fetch pubkey for $userId. code=${resp.statusCode}");
      }
    } catch (e) {
      LoggerService.logError("Exception fetching pubkey for $userId: $e");
    }
    return null;
  }

  SecureRandom _makeFortunaRandom() {
    final fr = FortunaRandom();
    final rng = Random.secure();
    final seeds = List<int>.generate(32, (_) => rng.nextInt(256));
    fr.seed(KeyParameter(Uint8List.fromList(seeds)));
    return fr;
  }

  // ---------------------------
  // (H) Read Receipts for In-Memory Messages
  // ---------------------------
  void handleReadReceipt(
    Map<String, dynamic> data,
    String chatUserId,
    VoidCallback onMessagesUpdated,
  ) {
    final readerId = data['readerId'] ?? '';
    final msgIds = data['messageIds'] ?? <dynamic>[];
    final tsStr = data['readTimestamp'] ?? '';
    if (readerId.isEmpty || msgIds.isEmpty || tsStr.isEmpty) return;
    final readAt = DateTime.parse(tsStr);
    if (readerId == chatUserId) {
      for (var m in messages) {
        if (msgIds.contains(m.id)) {
          m.isRead = true;
          m.readTimestamp = readAt;
        }
      }
      onMessagesUpdated();
    }
  }
}

extension ChatRequestsApi on ChatService {
  // GET /chat-requests  (pending only)
  Future<List<ChatRequestDTO>> fetchPendingChatRequests() async {
    final accessToken = await storageService.getAccessToken();
    if (accessToken == null) return [];

    final url = Uri.parse('${Environment.apiBaseUrl}/chat-requests');
    try {
      final resp = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
      });
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
    await http.post(url, headers: {
      'Authorization': 'Bearer $accessToken',
    });
  }

  Future<void> rejectChatRequest({required String requestId}) async {
    final accessToken = await storageService.getAccessToken();
    if (accessToken == null) return;
    final url =
        Uri.parse('${Environment.apiBaseUrl}/chat-requests/$requestId/reject');
    await http.post(url, headers: {
      'Authorization': 'Bearer $accessToken',
    });
  }

  /// Creates a **chat request** (POST /chat-requests).
  ///
  /// The `content` is encrypted with a fresh AES-256 key that is
  /// RSA-encrypted for both sender and recipient, mirroring `sendMessage`.
  ///
  /// Returns the created `ChatRequestDTO` on success, or `null` on error.
  Future<ChatRequestDTO?> sendChatRequest({
    required String chatUserId,
    required String content,
  }) async {
    final accessToken   = await storageService.getAccessToken();
    final currentUserId = await storageService.getUserId();
    if (accessToken == null || currentUserId == null) {
      LoggerService.logError('Auth missing – cannot send chat request');
      return null;
    }

    // ── 1.  Fetch RSA public keys & key versions for both users ─────────
    final meKey   = await _getOrFetchPublicKeyAndVersion(currentUserId);
    final themKey = await _getOrFetchPublicKeyAndVersion(chatUserId);
    if (meKey == null || themKey == null) {
      LoggerService.logError('Public key lookup failed');
      return null;
    }

    // ── 2.  Symmetric key + IV  ─────────────────────────────────────────
    final aesKeyBytes = _makeFortunaRandom().nextBytes(32);   // 256-bit
    final ivBytes     = _makeFortunaRandom().nextBytes(16);   // 128-bit IV

    final encrypter = encrypt.Encrypter(
      encrypt.AES(encrypt.Key(aesKeyBytes), mode: encrypt.AESMode.cbc),
    );
    final cipher = encrypter.encrypt(content, iv: encrypt.IV(ivBytes));

    // ── 3.  RSA-encrypt AES key for both parties ────────────────────────
    final aesKeyB64      = base64.encode(aesKeyBytes);
    final encForSender   = CryptoHelper.rsaEncrypt(aesKeyB64, meKey.publicKey);
    final encForRecipient= CryptoHelper.rsaEncrypt(aesKeyB64, themKey.publicKey);

    // ── 4.  Build request body (ChatMessageDTO shape) ───────────────────
    final body = {
      'sender'                 : currentUserId,         // optional but harmless
      'recipient'              : chatUserId,
      'ciphertext'             : base64.encode(cipher.bytes),
      'iv'                     : base64.encode(ivBytes),
      'encryptedKeyForSender'  : encForSender,
      'encryptedKeyForRecipient': encForRecipient,
      'senderKeyVersion'       : meKey.keyVersion,
      'recipientKeyVersion'    : themKey.keyVersion,
      'type'                   : 'CHAT_REQUEST',
    };

    // ── 5.  POST /chat-requests  ────────────────────────────────────────
    final url  = Uri.parse('${Environment.apiBaseUrl}/chat-requests');
    final resp = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type' : 'application/json',
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode == 200) {
      LoggerService.logInfo('Chat request sent successfully');
      return ChatRequestDTO.fromJson(jsonDecode(resp.body));
    } else {
      LoggerService.logError(
          'sendChatRequest failed (code ${resp.statusCode})  body=${resp.body}');
      return null;
    }
  }
}
