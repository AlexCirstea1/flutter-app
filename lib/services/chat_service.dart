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

class ChatService {
  final StorageService storageService;
  final List<MessageDTO> messages = [];
  bool isFetchingHistory = false;

  ChatService({required this.storageService});

  // ---------------------------------------------------------------------------
  // (1) Fetch conversation from the server
  // ---------------------------------------------------------------------------
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
        final List<dynamic> jsonList = jsonDecode(rawBody);

        messages.clear();

        final myUserId = await storageService.getUserId();
        final myPrivateKey = await storageService.getPrivateKey();

        for (var raw in jsonList) {
          final msg = MessageDTO(
            id: raw['id']?.toString() ?? const Uuid().v4(),
            sender: raw['sender'] ?? '',
            recipient: raw['recipient'] ?? '',
            ciphertext: raw['ciphertext'] ?? '',
            iv: raw['iv'] ?? '',
            encryptedKeyForSender: raw['encryptedKeyForSender'] ?? '',
            encryptedKeyForRecipient: raw['encryptedKeyForRecipient'] ?? '',
            timestamp: DateTime.parse(
                raw['timestamp'] ?? DateTime.now().toIso8601String()),
            isRead: raw['read'] ?? false,
            readTimestamp: (raw['readTimestamp'] != null)
                ? DateTime.parse(raw['readTimestamp'])
                : null,
            clientTempId: raw['clientTempId'],
            type: raw['type'],
          );

          // Attempt ephemeral AES decryption if I'm either the sender or recipient
          if (myUserId != null && myPrivateKey != null) {
            final isRecipient = (msg.recipient == myUserId);
            final isSender = (msg.sender == myUserId);

            final rsaEncryptedKey = isRecipient
                ? msg.encryptedKeyForRecipient
                : (isSender ? msg.encryptedKeyForSender : '');

            if (rsaEncryptedKey.isNotEmpty &&
                msg.ciphertext.isNotEmpty &&
                msg.iv.isNotEmpty) {
              try {
                // RSA-decrypt ephemeral key
                final aesKeyB64 =
                    CryptoHelper.rsaDecrypt(rsaEncryptedKey, myPrivateKey);
                final aesKeyBytes = base64.decode(aesKeyB64);

                // AES-decrypt
                final ivBytes = base64.decode(msg.iv);
                final cipherBytes = base64.decode(msg.ciphertext);

                final keyObj = encrypt.Key(aesKeyBytes);
                final ivObj = encrypt.IV(ivBytes);

                final encr = encrypt.Encrypter(
                  encrypt.AES(keyObj, mode: encrypt.AESMode.cbc),
                );
                final plain =
                    encr.decrypt(encrypt.Encrypted(cipherBytes), iv: ivObj);

                msg.plaintext = plain;
              } catch (e) {
                LoggerService.logError('Failed ephemeral decrypt: $e');
              }
            }
          }

          messages.add(msg);
        }

        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        await markMessagesAsRead();
        onMessagesUpdated();
      } else {
        LoggerService.logError(
          'Failed to fetch chat history. Code: ${response.statusCode}',
        );
      }
    } catch (e) {
      LoggerService.logError('Error fetching chat history', e);
    } finally {
      isFetchingHistory = false;
    }
  }

  // ---------------------------------------------------------------------------
  // (2) Mark conversation as read
  // ---------------------------------------------------------------------------
  Future<void> markMessagesAsRead() async {
    final userId = await storageService.getUserId();
    if (userId == null) return;

    final accessToken = await storageService.getAccessToken();
    if (accessToken == null) return;

    final unread =
        messages.where((m) => m.recipient == userId && !m.isRead).toList();
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
        for (var m in unread) {
          m.isRead = true;
          m.readTimestamp = now;
        }
      } else {
        LoggerService.logError(
            'Failed to mark messages. status=${resp.statusCode}');
      }
    } catch (e) {
      LoggerService.logError('Error marking messages as read', e);
    }
  }

  // Mark single message read
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
        LoggerService.logInfo("Message $messageId read on server.");
        final now = DateTime.now();
        final idx = messages.indexWhere((m) => m.id == messageId);
        if (idx >= 0) {
          messages[idx].isRead = true;
          messages[idx].readTimestamp = now;
        }
      } else {
        LoggerService.logError(
            'Failed to mark msg read. code=${resp.statusCode}');
      }
    } catch (e) {
      LoggerService.logError('Error marking single msg as read', e);
    }
  }

  // ---------------------------------------------------------------------------
  // (3) Handle real-time new/updated messages
  // ---------------------------------------------------------------------------
  void handleIncomingOrSentMessage(
    Map<String, dynamic> rawMsg,
    String currentUserId,
    VoidCallback onMessagesUpdated,
  ) async {
    final type = rawMsg['type'] ?? '';
    final sender = rawMsg['sender'] ?? '';
    final recipient = rawMsg['recipient'] ?? '';

    if (type == 'INCOMING_MESSAGE' && sender == currentUserId) return;
    if (type == 'SENT_MESSAGE' && sender != currentUserId) return;

    final newMsg = MessageDTO(
      id: rawMsg['id']?.toString() ?? const Uuid().v4(),
      sender: sender,
      recipient: recipient,
      ciphertext: rawMsg['ciphertext'] ?? '',
      iv: rawMsg['iv'] ?? '',
      encryptedKeyForSender: rawMsg['encryptedKeyForSender'] ?? '',
      encryptedKeyForRecipient: rawMsg['encryptedKeyForRecipient'] ?? '',
      timestamp: DateTime.parse(
          rawMsg['timestamp'] ?? DateTime.now().toIso8601String()),
      isRead: rawMsg['read'] ?? false,
      readTimestamp: (rawMsg['readTimestamp'] != null)
          ? DateTime.parse(rawMsg['readTimestamp'])
          : null,
      clientTempId: rawMsg['clientTempId'],
      type: rawMsg['type'],
    );

    final myUserId = await storageService.getUserId();
    final myPrivateKey = await storageService.getPrivateKey();
    if (myUserId != null && myPrivateKey != null) {
      final isRecipient = (newMsg.recipient == myUserId);
      final isSender = (newMsg.sender == myUserId);

      // pick correct RSA-encrypted ephemeral key
      final ephemeralKeyEnc = isRecipient
          ? newMsg.encryptedKeyForRecipient
          : (isSender ? newMsg.encryptedKeyForSender : '');

      if (ephemeralKeyEnc.isNotEmpty &&
          newMsg.ciphertext.isNotEmpty &&
          newMsg.iv.isNotEmpty) {
        try {
          final aesKeyB64 =
              CryptoHelper.rsaDecrypt(ephemeralKeyEnc, myPrivateKey);
          final aesKeyBytes = base64.decode(aesKeyB64);

          final ivBytes = base64.decode(newMsg.iv);
          final ciph = base64.decode(newMsg.ciphertext);

          final aesKey = encrypt.Key(aesKeyBytes);
          final ivObj = encrypt.IV(ivBytes);
          final encr =
              encrypt.Encrypter(encrypt.AES(aesKey, mode: encrypt.AESMode.cbc));
          final plain = encr.decrypt(encrypt.Encrypted(ciph), iv: ivObj);

          newMsg.plaintext = plain;
        } catch (e) {
          LoggerService.logError('Ephemeral decrypt fail: $e');
        }
      }
    }

    // If I'm the sender, check ephemeral replacement
    if (type == 'SENT_MESSAGE' && sender == currentUserId) {
      final ctemp = newMsg.clientTempId ?? '';
      if (ctemp.isNotEmpty) {
        final idx = messages.indexWhere((m) => m.id == ctemp);
        if (idx >= 0) {
          messages[idx] = newMsg;
          messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          onMessagesUpdated();
          return;
        }
      }
    }

    // Insert/update
    final existIdx = messages.indexWhere((m) => m.id == newMsg.id);
    if (existIdx >= 0) {
      messages[existIdx] = newMsg;
    } else {
      messages.add(newMsg);
    }
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    onMessagesUpdated();

    // If I'm recipient, auto-mark read
    if (newMsg.recipient == currentUserId && !newMsg.isRead) {
      markSingleMessageAsRead(newMsg.id);
    }
  }

  // ---------------------------------------------------------------------------
  // (4) Send ephemeral-encrypted message
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

    // Create ephemeral message for UI (plaintext)
    final ephemeralMsg = MessageDTO(
      id: tempId,
      sender: currentUserId,
      recipient: chatUserId,
      ciphertext: '',
      iv: '',
      encryptedKeyForSender: '',
      encryptedKeyForRecipient: '',
      timestamp: now,
      isRead: false,
      clientTempId: tempId,
      type: 'SENT_MESSAGE',
      plaintext: content, // local only
    );
    onEphemeralAdded(ephemeralMsg);

    // Retrieve participant public keys
    final recipPubKey = await _getOrFetchPublicKey(chatUserId);
    final sendrPubKey = await _getOrFetchPublicKey(currentUserId);
    if (recipPubKey == null || sendrPubKey == null) {
      LoggerService.logError("Cannot encrypt: missing pubkey(s).");
      return;
    }

    // Generate ephemeral AES key (256 bits)
    final aesKeyBytes = _makeFortunaRandom().nextBytes(32);
    final aesKey = encrypt.Key(aesKeyBytes);

    // Generate random IV (16 bytes)
    final ivBytes = _makeFortunaRandom().nextBytes(16);
    final ivObj = encrypt.IV(ivBytes);

    // AES encrypt the content
    final encr =
        encrypt.Encrypter(encrypt.AES(aesKey, mode: encrypt.AESMode.cbc));
    final cipher = encr.encrypt(content, iv: ivObj);

    final ciphertextB64 = base64.encode(cipher.bytes);
    final ivB64 = base64.encode(ivBytes);

    // RSA-encrypt ephemeral AES for both sender & recipient
    final aesKeyB64 = base64.encode(aesKeyBytes);
    final encKeyForRecipient = CryptoHelper.rsaEncrypt(aesKeyB64, recipPubKey);
    final encKeyForSender = CryptoHelper.rsaEncrypt(aesKeyB64, sendrPubKey);

    final msgMap = {
      'sender': currentUserId,
      'recipient': chatUserId,
      'ciphertext': ciphertextB64,
      'iv': ivB64,
      'encryptedKeyForRecipient': encKeyForRecipient,
      'encryptedKeyForSender': encKeyForSender,
      'clientTempId': tempId,
      'timestamp': now.toIso8601String(),
      'type': 'SENT_MESSAGE',
    };

    stompSend(msgMap);
  }

  SecureRandom _makeFortunaRandom() {
    final fr = FortunaRandom();
    final rng = Random.secure();
    final seeds = List<int>.generate(32, (_) => rng.nextInt(256));
    fr.seed(KeyParameter(Uint8List.fromList(seeds)));
    return fr;
  }

  // Helper to fetch a user’s public key, or load from cache
  Future<String?> _getOrFetchPublicKey(String userId) async {
    final cached = await storageService.getFromStorage('publicKey_$userId');
    if (cached != null && cached.isNotEmpty) return cached;

    final accessToken = await storageService.getAccessToken();
    if (accessToken == null) return null;

    final url = Uri.parse('${Environment.apiBaseUrl}/user/publicKey/$userId');
    try {
      final resp = await http
          .get(url, headers: {'Authorization': 'Bearer $accessToken'});
      if (resp.statusCode == 200) {
        final pubKeyPem = resp.body.trim();
        if (pubKeyPem.isNotEmpty) {
          await storageService.saveInStorage('publicKey_$userId', pubKeyPem);
          return pubKeyPem;
        }
      } else {
        LoggerService.logError(
            "Failed fetching pubkey for $userId. status=${resp.statusCode}");
      }
    } catch (e) {
      LoggerService.logError("Exception fetching pubkey: $e");
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // (5) Fetch entire chat listing
  // ---------------------------------------------------------------------------
  Future<List<ChatHistoryDTO>> fetchAllChats() async {
    final accessToken = await storageService.getAccessToken();
    if (accessToken == null) {
      LoggerService.logError('Access token not found');
      return [];
    }

    final url = Uri.parse('${Environment.apiBaseUrl}/chats');
    final resp = await http.get(url, headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    });
    if (resp.statusCode == 200) {
      final rawBody = utf8.decode(resp.bodyBytes);
      final List<dynamic> jsonList = jsonDecode(rawBody);

      final myUserId = await storageService.getUserId();
      final myPrivKey = await storageService.getPrivateKey();

      final List<ChatHistoryDTO> fetched =
          jsonList.map((c) => ChatHistoryDTO.fromJson(c)).toList();

      if (myUserId != null && myPrivKey != null) {
        for (var chat in fetched) {
          for (var msg in chat.messages) {
            final isRecipient = (msg.recipient == myUserId);
            final isSender = (msg.sender == myUserId);

            final ephemeralKeyEnc = isRecipient
                ? msg.encryptedKeyForRecipient
                : (isSender ? msg.encryptedKeyForSender : '');

            if (ephemeralKeyEnc.isNotEmpty &&
                msg.ciphertext.isNotEmpty &&
                msg.iv.isNotEmpty) {
              try {
                final aesKeyB64 =
                    CryptoHelper.rsaDecrypt(ephemeralKeyEnc, myPrivKey);
                final aesKeyBytes = base64.decode(aesKeyB64);

                final ivBytes = base64.decode(msg.iv);
                final cipherData = base64.decode(msg.ciphertext);

                final aesKey = encrypt.Key(aesKeyBytes);
                final ivObj = encrypt.IV(ivBytes);
                final encr = encrypt.Encrypter(
                    encrypt.AES(aesKey, mode: encrypt.AESMode.cbc));
                final plain =
                    encr.decrypt(encrypt.Encrypted(cipherData), iv: ivObj);

                msg.plaintext = plain;
              } catch (e) {
                LoggerService.logError(
                    'Failed ephemeral decrypt in chat listing: $e');
              }
            }
          }
        }
      }

      // Sort by last message desc
      fetched.sort((a, b) {
        final aLast = a.messages.isNotEmpty
            ? a.messages.last.timestamp
            : DateTime.fromMillisecondsSinceEpoch(0);
        final bLast = b.messages.isNotEmpty
            ? b.messages.last.timestamp
            : DateTime.fromMillisecondsSinceEpoch(0);
        return bLast.compareTo(aLast);
      });
      return fetched;
    } else {
      LoggerService.logError(
          'Failed to fetch chat listing. status=${resp.statusCode}');
      return [];
    }
  }

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

  Future<void> debugPrivateKey() async {
    final pk = await storageService.getPrivateKey();
    if (pk == null) {
      LoggerService.logInfo("No private key found");
      return;
    }
    LoggerService.logInfo("Private key length: ${pk.length}");
    LoggerService.logInfo(
        "Private key starts with: ${pk.substring(0, min(20, pk.length))}");

    if (!pk.contains("-----BEGIN PRIVATE KEY-----") ||
        !pk.contains("-----END PRIVATE KEY-----")) {
      LoggerService.logError("Private key missing PEM headers");
    }
  }

  void handleNewOrUpdatedMessage({
    required Map<String, dynamic> msg,
    required String currentUserId,
    required List<ChatHistoryDTO> chatHistory,
  }) async {
    final type = msg['type'] ?? '';
    final sender = msg['sender'] ?? '';
    final recipient = msg['recipient'] ?? '';

    // Only process messages relevant to current user
    if ((type == 'INCOMING_MESSAGE' && recipient != currentUserId) ||
        (type == 'SENT_MESSAGE' && sender != currentUserId)) {
      return;
    }

    final newMsg = MessageDTO(
      id: msg['id']?.toString() ?? const Uuid().v4(),
      sender: sender,
      recipient: recipient,
      ciphertext: msg['ciphertext'] ?? '',
      iv: msg['iv'] ?? '',
      encryptedKeyForSender: msg['encryptedKeyForSender'] ?? '',
      encryptedKeyForRecipient: msg['encryptedKeyForRecipient'] ?? '',
      timestamp: DateTime.parse(msg['timestamp'] ?? DateTime.now().toIso8601String()),
      isRead: msg['read'] ?? false,
      readTimestamp: (msg['readTimestamp'] != null) ? DateTime.parse(msg['readTimestamp']) : null,
      clientTempId: msg['clientTempId'],
      type: msg['type'],
    );

    // Determine the other participant's ID
    final otherUserId = (sender == currentUserId) ? recipient : sender;

    // Try to decrypt the message
    final myPrivateKey = await storageService.getPrivateKey();
    if (myPrivateKey != null) {
      final isRecipient = (newMsg.recipient == currentUserId);
      final isSender = (newMsg.sender == currentUserId);

      final ephemeralKeyEnc = isRecipient
          ? newMsg.encryptedKeyForRecipient
          : (isSender ? newMsg.encryptedKeyForSender : '');

      if (ephemeralKeyEnc.isNotEmpty && newMsg.ciphertext.isNotEmpty && newMsg.iv.isNotEmpty) {
        try {
          final aesKeyB64 = CryptoHelper.rsaDecrypt(ephemeralKeyEnc, myPrivateKey);
          final aesKeyBytes = base64.decode(aesKeyB64);

          final ivBytes = base64.decode(newMsg.iv);
          final ciph = base64.decode(newMsg.ciphertext);

          final aesKey = encrypt.Key(aesKeyBytes);
          final ivObj = encrypt.IV(ivBytes);
          final encr = encrypt.Encrypter(encrypt.AES(aesKey, mode: encrypt.AESMode.cbc));
          final plain = encr.decrypt(encrypt.Encrypted(ciph), iv: ivObj);

          newMsg.plaintext = plain;
          LoggerService.logInfo('Successfully decrypted message: ${plain.substring(0, min(30, plain.length))}');
        } catch (e) {
          LoggerService.logError('Ephemeral decrypt fail: $e');
        }
      }
    }

    // Find or create chat history for this participant
    var chatIndex = chatHistory.indexWhere((c) => c.participant == otherUserId);

    // If this is a message from a new chat
    if (chatIndex == -1) {
      chatHistory.add(ChatHistoryDTO(
        participant: otherUserId,
        participantUsername: '', // Will need a separate call to get username
        messages: [newMsg],
        unreadCount: newMsg.recipient == currentUserId && !newMsg.isRead ? 1 : 0,
      ));
    } else {
      // Check for temp ID replacement
      if (type == 'SENT_MESSAGE' && newMsg.clientTempId != null) {
        final tempId = newMsg.clientTempId!;
        final msgIndex = chatHistory[chatIndex].messages.indexWhere((m) => m.id == tempId || m.id == newMsg.id);
        if (msgIndex >= 0) {
          chatHistory[chatIndex].messages[msgIndex] = newMsg;
        } else {
          chatHistory[chatIndex].messages.add(newMsg);
        }
      } else {
        // Add message to existing chat
        final existingIndex = chatHistory[chatIndex].messages.indexWhere((m) => m.id == newMsg.id);
        if (existingIndex >= 0) {
          chatHistory[chatIndex].messages[existingIndex] = newMsg;
        } else {
          chatHistory[chatIndex].messages.add(newMsg);

          // Update unread count if I'm the recipient and message isn't read
          if (newMsg.recipient == currentUserId && !newMsg.isRead) {
            chatHistory[chatIndex].unreadCount++;
          }
        }
      }
    }

    // Sort messages by timestamp
    for (var chat in chatHistory) {
      chat.messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    // Sort chats by most recent message
    chatHistory.sort((a, b) {
      final aLast = a.messages.isNotEmpty ? a.messages.last.timestamp : DateTime.fromMillisecondsSinceEpoch(0);
      final bLast = b.messages.isNotEmpty ? b.messages.last.timestamp : DateTime.fromMillisecondsSinceEpoch(0);
      return bLast.compareTo(aLast);
    });
  }
}
