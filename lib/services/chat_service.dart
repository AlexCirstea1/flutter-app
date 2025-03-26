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

  /// (Optional) In-memory list of messages for a single chat session.
  final List<MessageDTO> messages = [];

  bool isFetchingHistory = false;

  ChatService({required this.storageService});

  // ---------------------------------------------------------------------------
  // (A) Fetch Single Conversation
  // ---------------------------------------------------------------------------
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
              rawMsg['timestamp'] ?? DateTime.now().toIso8601String(),
            ),
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
                  final plain = encrypter.decrypt(
                    encrypt.Encrypted(cipherBytes),
                    iv: ivObj,
                  );
                  msg.plaintext = plain;
                }
              } catch (e) {
                LoggerService.logError('Decrypt fail for msg ${msg.id}: $e');
              }
            }
          }
          messages.add(msg);
        }

        // Sort by ascending timestamp
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        // Mark all unread as read
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

  // ---------------------------------------------------------------------------
  // (B) Mark All or Single Message as Read
  // ---------------------------------------------------------------------------
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
      final resp = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
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

  // ---------------------------------------------------------------------------
  // (C) Handle Real-Time "Incoming" or "Sent" Message
  // ---------------------------------------------------------------------------
  /// If you keep an in-memory [messages] list for the current chat, use this method
  /// to handle a newly arrived or updated message from your WebSocket/stomp subscription.
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

    // If the message doesn't involve me at all, skip
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

    LoggerService.logInfo(
        "Message processing - isRecipient=$isRecipient, isSender=$isSender, hasClientTempId=${newMsg.clientTempId != null}");

    // For sender messages with a temp ID, try to find the ephemeral message first
    if (isSender && newMsg.clientTempId != null) {
      final idx = messages.indexWhere((m) => m.id == newMsg.clientTempId);
      if (idx >= 0) {
        LoggerService.logInfo(
            "Found ephemeral message at index $idx with plaintext: ${messages[idx].plaintext}");
        // Preserve the plaintext from our ephemeral message
        final existingPlaintext = messages[idx].plaintext;
        messages[idx] = newMsg;
        messages[idx].plaintext = existingPlaintext; // Keep ephemeral plaintext
        LoggerService.logInfo(
            "Updated ephemeral message with plaintext: ${messages[idx].plaintext}");
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        onMessagesUpdated();
        return;
      }
    }

    // Decrypt the message if needed
    final versionToUse =
        isRecipient ? newMsg.recipientKeyVersion : newMsg.senderKeyVersion;
    final myPrivateKey = await storageService.getPrivateKey(versionToUse);

    LoggerService.logInfo(
        "Attempting decryption with keyVersion=$versionToUse, hasPrivateKey=${myPrivateKey != null}, hasCiphertext=${newMsg.ciphertext.isNotEmpty}, hasIV=${newMsg.iv.isNotEmpty}");

    if (myPrivateKey != null &&
        newMsg.ciphertext.isNotEmpty &&
        newMsg.iv.isNotEmpty) {
      try {
        final ephemeralKeyEnc = isRecipient
            ? newMsg.encryptedKeyForRecipient
            : newMsg.encryptedKeyForSender;
        LoggerService.logInfo(
            "Decrypting ephemeralKeyEnc => $ephemeralKeyEnc, version=$versionToUse, length=${ephemeralKeyEnc.length}");

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
          final plain = encrypter.decrypt(
            encrypt.Encrypted(cipherBytes),
            iv: ivObj,
          );
          newMsg.plaintext = plain;

          LoggerService.logInfo(
              "After decryption attempt, plaintext=${newMsg.plaintext}");
        } else {
          LoggerService.logError("Empty ephemeralKeyEnc, cannot decrypt");
        }
      } catch (e) {
        LoggerService.logError('Decrypt fail for newMsg ${newMsg.id}: $e');
      }
    } else {
      LoggerService.logInfo("Skipping decryption due to missing prerequisites");
    }

    // Normal add/update logic
    final existIdx = messages.indexWhere((m) => m.id == newMsg.id);
    if (existIdx >= 0) {
      LoggerService.logInfo(
          "Updating existing message at index $existIdx, existing plaintext=${messages[existIdx].plaintext}");
      // Don't overwrite plaintext if we already have it
      final existingPlaintext = messages[existIdx].plaintext;
      if (existingPlaintext != null && existingPlaintext.isNotEmpty) {
        newMsg.plaintext = existingPlaintext;
      }
      messages[existIdx] = newMsg;
      LoggerService.logInfo(
          "After update, message plaintext=${messages[existIdx].plaintext}");
    } else {
      LoggerService.logInfo(
          "Adding new message with plaintext=${newMsg.plaintext}");
      messages.add(newMsg);
    }

    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    onMessagesUpdated();

    // Auto-mark as read if I'm the recipient
    if (isRecipient && !newMsg.isRead) {
      markSingleMessageAsRead(newMsg.id);
    }
  }

  // ---------------------------------------------------------------------------
  // (D) handleNewOrUpdatedMessage - FOR chat listing (ChatHistoryDTO)
  // ---------------------------------------------------------------------------
  /// If you maintain a user-level chat listing (List<ChatHistoryDTO>),
  /// call this method to update the correct ChatHistoryDTO.
  /// This is separate from the in-memory [messages] used for a single conversation.
  ///
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

    // If the message doesn't involve me, skip
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

    // Decrypt
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
        LoggerService.logInfo(
            "Decrypting ephemeralKeyEnc => $ephemeralKeyEnc, version=$versionToUse");
        if (ephemeralKeyEnc.isNotEmpty) {
          final aesKeyB64 =
              CryptoHelper.rsaDecrypt(ephemeralKeyEnc, myPrivateKey);
          final aesKeyBytes = base64.decode(aesKeyB64);

          final ivBytes = base64.decode(newMsg.iv);
          final cipherBytes = base64.decode(newMsg.ciphertext);

          final aesKey = encrypt.Key(aesKeyBytes);
          final ivObj = encrypt.IV(ivBytes);
          final encr =
              encrypt.Encrypter(encrypt.AES(aesKey, mode: encrypt.AESMode.cbc));
          final plain = encr.decrypt(encrypt.Encrypted(cipherBytes), iv: ivObj);
          newMsg.plaintext = plain;
          LoggerService.logInfo("Decrypted plaintext: '${newMsg.plaintext}'");
        }
      } catch (e) {
        LoggerService.logError('Decrypt fail for newMsg ${newMsg.id}: $e');
      }
    }

    // Insert/update in chatHistory
    final otherUserId = (sender == currentUserId) ? recipient : sender;
    final chatIndex =
        chatHistory.indexWhere((c) => c.participant == otherUserId);
    if (chatIndex == -1) {
      // brand new conversation
      chatHistory.add(
        ChatHistoryDTO(
          participant: otherUserId,
          participantUsername: '',
          messages: [newMsg],
          unreadCount: (isRecipient && !newMsg.isRead) ? 1 : 0,
        ),
      );
    } else {
      // Check ephemeral replacement if I'm sender
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
        // Normal insertion or update
        final existingIdx = chatHistory[chatIndex]
            .messages
            .indexWhere((m) => m.id == newMsg.id);
        if (existingIdx >= 0) {
          chatHistory[chatIndex].messages[existingIdx] = newMsg;
        } else {
          chatHistory[chatIndex].messages.add(newMsg);
          // If I'm the recipient, increment unread
          if (isRecipient && !newMsg.isRead) {
            chatHistory[chatIndex].unreadCount++;
          }
        }
      }
    }

    // Sort messages & chats
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

  // ---------------------------------------------------------------------------
  // (E) Sending an ephemeral-encrypted message
  // ---------------------------------------------------------------------------
  Future<void> sendMessage({
    required String currentUserId,
    required String chatUserId,
    required String content,
    required Function(MessageDTO ephemeral) onEphemeralAdded,
    required void Function(Map<String, dynamic> msgMap) stompSend,
  }) async {
    final now = DateTime.now();
    final tempId = const Uuid().v4();

    // Locally show ephemeral message
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
      clientTempId: tempId,
      type: 'SENT_MESSAGE',
      plaintext: content,
    );
    onEphemeralAdded(ephemeralMsg);

    // Fetch both public keys & versions
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

    // Generate ephemeral AES key (256 bits) + IV (16 bytes)
    final aesKeyBytes = _makeFortunaRandom().nextBytes(32);
    final aesKey = encrypt.Key(aesKeyBytes);
    final ivBytes = _makeFortunaRandom().nextBytes(16);
    final ivObj = encrypt.IV(ivBytes);

    // AES encrypt content
    final encr =
        encrypt.Encrypter(encrypt.AES(aesKey, mode: encrypt.AESMode.cbc));
    final cipher = encr.encrypt(content, iv: ivObj);
    final ciphertextB64 = base64.encode(cipher.bytes);
    final ivB64 = base64.encode(ivBytes);

    // RSA-encrypt ephemeral AES key for both
    final aesKeyB64 = base64.encode(aesKeyBytes);
    final encForSender =
        CryptoHelper.rsaEncrypt(aesKeyB64, senderData.publicKey);
    final encForRecipient =
        CryptoHelper.rsaEncrypt(aesKeyB64, recipientData.publicKey);

    // Build STOMP/WebSocket message
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
    };

    stompSend(msgMap);
  }

  // ---------------------------------------------------------------------------
  // (F) Fetch entire chat listing
  // ---------------------------------------------------------------------------
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
          // Attempt decryption for each message in each chat
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
                    final encr = encrypt.Encrypter(
                        encrypt.AES(aesKey, mode: encrypt.AESMode.cbc));
                    final plain =
                        encr.decrypt(encrypt.Encrypted(cipherBytes), iv: ivObj);
                    msg.plaintext = plain;
                  }
                } catch (e) {
                  LoggerService.logError(
                      'Decrypt fail in fetchAllChats msg ${msg.id}: $e');
                }
              }
            }
            // sort each chat's messages ascending by time
            chat.messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          }
          // then sort chats by last message desc
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

  // ---------------------------------------------------------------------------
  // (G) Public Key + Version from /user/publicKey/{id}
  // ---------------------------------------------------------------------------
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
        // parse JSON: { "publicKey":"...", "version":"..." }
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

  // ---------------------------------------------------------------------------
  // (H) Additional: read receipts for the in-memory messages
  // ---------------------------------------------------------------------------
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
