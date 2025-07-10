/// High-level façade used by the UI.
/// Heavy lifting is delegated to the injected helpers.
///
/// ──────────────────────────────────────────────────────────────
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:mime/mime.dart' show lookupMimeType;
import 'package:uuid/uuid.dart';

import '../../../../core/config/environment.dart';
import '../../../../core/config/logger_config.dart';
import '../../../../core/data/services/storage_service.dart';
import '../../../../core/data/services/websocket_service.dart';
import '../../domain/models/chat_history_dto.dart';
import '../../domain/models/chat_request_dto.dart';
import '../../domain/models/file_info.dart';
import '../../domain/models/message_dto.dart';
import '../repositories/chat_request_repository.dart';
import '../repositories/message_repository.dart';
import 'key_management_service.dart';
import 'message_crypto_service.dart';

/*───────────────────────────────────────────────────────────────
*  Pending‑upload cache
*------------------------------------------------------------------*/
class _PendingUpload {
  const _PendingUpload({
    required this.fileId,
    required this.encryptedBytes,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.onProgress,
  });

  final String fileId;
  final List<int> encryptedBytes;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final void Function(double) onProgress;
}

/*───────────────────────────────────────────────────────────────*/
class ChatService {
  /* ─────────────── dependencies ─────────────── */
  final StorageService _storage;
  final KeyManagementService _keyMgr;
  final MessageCryptoService _crypto;
  final MessageRepository _repo;
  final ChatRequestRepository _requestRepo;

  ChatService({
    required StorageService storageService,
    required KeyManagementService keyManagement,
    required MessageCryptoService cryptoService,
    required MessageRepository messageRepository,
    required ChatRequestRepository requestRepository,
  })  : _storage = storageService,
        _keyMgr = keyManagement,
        _crypto = cryptoService,
        _repo = messageRepository,
        _requestRepo = requestRepository;

  /*────────────  pending file uploads  ────────────*/
  final Map<String, _PendingUpload> _pendingUploads = {}; // key = clientTempId

  /* ───────────── public read‑only ───────────── */
  List<MessageDTO> get messages => _repo.messages;

  bool get isFetchingHistory => _repo.isFetchingHistory;

  /* ──────────── history / reading ───────────── */
  Future<void> fetchChatHistory({
    required String chatUserId,
    required VoidCallback onMessagesUpdated,
  }) =>
      _repo.fetchChatHistory(
        chatUserId: chatUserId,
        onMessagesUpdated: onMessagesUpdated,
      );

  Future<void> markSingleMessageAsRead(String id) =>
      _repo.markSingleMessageAsRead(id);

  /* ───────────────── sending ─────────────────── */
  Future<void> sendMessage({
    required String currentUserId,
    required String chatUserId,
    required String content,
    required bool oneTime,
    required void Function(MessageDTO) onEphemeralAdded,
    required void Function(Map<String, dynamic>) stompSend,
  }) async {
    /* 1️⃣ local echo */
    final now = DateTime.now();
    final tempId = const Uuid().v4();
    onEphemeralAdded(
      MessageDTO(
        id: tempId,
        sender: currentUserId,
        recipient: chatUserId,
        timestamp: now,
        clientTempId: tempId,
        type: 'SENT_MESSAGE',
        plaintext: content,
        oneTime: oneTime,
        // crypto placeholders
        ciphertext: '',
        iv: '',
        encryptedKeyForSender: '',
        encryptedKeyForRecipient: '',
        senderKeyVersion: '',
        recipientKeyVersion: '',
      ),
    );

    /* 2️⃣ keys */
    final senderKey =
        await _keyMgr.getOrFetchPublicKeyAndVersion(currentUserId);
    final recipientKey =
        await _keyMgr.getOrFetchPublicKeyAndVersion(chatUserId);
    if (senderKey == null || recipientKey == null) {
      LoggerService.logError('Missing public key(s) – aborting send');
      return;
    }

    /* 3️⃣ encrypt */
    final enc = await _crypto.encryptMessage(
      content: content,
      senderKey: senderKey,
      recipientKey: recipientKey,
    );

    /* 4️⃣ STOMP payload */
    final map = {
      'sender': currentUserId,
      'recipient': chatUserId,
      'clientTempId': tempId,
      'timestamp': now.toIso8601String(),
      'type': 'SENT_MESSAGE',
      'oneTime': oneTime,
      ...enc,
    };
    stompSend(map);
  }

  /* ───────────── real‑time events ───────────── */
  Future<void> handleIncomingOrSentMessage(
    Map<String, dynamic> raw,
    String currentUserId,
    VoidCallback onMessagesUpdated, {
    bool markReadOnReceive = true,
  }) async {
    final msg = _repo.parseMessageFromJson(raw);

    // not my chat ➜ ignore
    if (msg.sender != currentUserId && msg.recipient != currentUserId) return;

    // ── A. merge the server copy with the local echo ───────────────────
    if (msg.sender == currentUserId && msg.clientTempId != null) {
      final idx = messages.indexWhere((m) => m.id == msg.clientTempId);
      if (idx >= 0) {
        msg.plaintext = messages[idx].plaintext; // keep the clear‑text
        messages[idx] = msg; // replace echo with final
      } else {
        _upsert(msg); // fallback (shouldn’t happen)
      }
    } else {
      // ── B. decrypt incoming copy when I’m the recipient ───────────────
      final isRecpt = msg.recipient == currentUserId;
      final version = isRecpt ? msg.recipientKeyVersion : msg.senderKeyVersion;
      final privKey = await _storage.getPrivateKey(version);
      final encKey =
          isRecpt ? msg.encryptedKeyForRecipient : msg.encryptedKeyForSender;
      if (privKey != null && encKey.isNotEmpty) {
        msg.plaintext = _crypto.decryptMessage(
          ciphertext: msg.ciphertext,
          iv: msg.iv,
          encryptedKey: encKey,
          privateKey: privKey,
        );
      }
      _upsert(msg);
    }

    /* ── C. kick‑off deferred HTTP upload if this finalises a file ─── */
    if (msg.clientTempId != null &&
        _pendingUploads.containsKey(msg.clientTempId)) {
      final u = _pendingUploads.remove(msg.clientTempId)!;
      try {
        await _uploadEncryptedFile(
          fileId: u.fileId,
          messageId: msg.id, // definitive server ID
          fileName: u.fileName,
          mimeType: u.mimeType,
          sizeBytes: u.sizeBytes,
          encryptedBytes: u.encryptedBytes,
          onProgress: u.onProgress,
        );
      } catch (e) {
        LoggerService.logError('Deferred file upload failed: $e');
      }
    }

    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    onMessagesUpdated();

    if (markReadOnReceive && msg.recipient == currentUserId && !msg.isRead) {
      _repo.markSingleMessageAsRead(msg.id);
    }
  }

  /// Re‑insert or update by **server id** (avoids multi‑dupes)
  void _upsert(MessageDTO incoming) {
    final i = messages.indexWhere((e) => e.id == incoming.id);
    if (i >= 0) {
      final existing = messages[i];

      /* keep the decrypted/plain-text if the newcomer is still encrypted */
      if ((existing.plaintext?.isNotEmpty ?? false) &&
          (incoming.plaintext == null || incoming.plaintext!.isEmpty)) {
        incoming.plaintext = existing.plaintext;
      }

      /* ⬇️  NEW — keep file info we already cached */
      if (existing.file != null && incoming.file == null) {
        incoming.file = existing.file;
      }

      messages[i] = incoming;
    } else {
      messages.add(incoming);
    }
  }

  /* ───────────── chat listing ───────────── */
  Future<List<ChatHistoryDTO>> fetchAllChats() => _repo.fetchAllChats();

  List<ChatHistoryDTO> buildChatHistorySnapshot(String currentUserId) {
    final Map<String, ChatHistoryDTO> map = {};

    for (final m in messages) {
      final other = m.sender == currentUserId ? m.recipient : m.sender;

      map.putIfAbsent(
          other,
          () => ChatHistoryDTO(
                participant: other,
                participantUsername: '',
                messages: [],
                unreadCount: 0,
              ));

      map[other]!.messages.add(m);

      if (m.recipient == currentUserId && !m.isRead) {
        map[other]!.unreadCount += 1;
      }
    }

    // sort messages inside each chat
    for (final c in map.values) {
      c.messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    // sort chats by “last activity desc”
    final list = map.values.toList()
      ..sort((a, b) =>
          b.messages.last.timestamp.compareTo(a.messages.last.timestamp));

    return list;
  }

  /* ─────────── chat‑request API ─────────── */
  Future<List<ChatRequestDTO>> fetchPendingChatRequests() =>
      _requestRepo.fetchPendingChatRequests();

  Future<void> acceptChatRequest(String id) =>
      _requestRepo.acceptChatRequest(requestId: id);

  Future<void> rejectChatRequest(String id) =>
      _requestRepo.rejectChatRequest(requestId: id);

  Future<ChatRequestDTO?> sendChatRequest({
    required String chatUserId,
    required String content,
  }) =>
      _requestRepo.sendChatRequest(
        chatUserId: chatUserId,
        content: content,
      );

  /* ───────────── read‑receipt frames (client‑side only) ───────────── */
  void handleReadReceipt(
    Map<String, dynamic> data,
    String chatUserId,
    VoidCallback onMessagesUpdated,
  ) {
    final readerId = data['readerId'] as String? ?? '';
    final msgIds = data['messageIds'] as List? ?? const [];
    final tsStr = data['readTimestamp'] as String? ?? '';

    if (readerId.isEmpty || msgIds.isEmpty || tsStr.isEmpty) return;

    // We only care if the *other* user read *my* messages in this chat
    if (readerId != chatUserId) return;

    final readAt = DateTime.parse(tsStr);

    for (final m in messages) {
      if (msgIds.contains(m.id)) {
        m.isRead = true;
        m.readTimestamp = readAt;
      }
    }

    // Let the screen rebuild
    onMessagesUpdated();
  }

  /*──────────────── FILE transfer ────────────────*/
  Future<void> sendFileMessage({
    required String currentUserId,
    required String chatUserId,
    required File picked,
    required String fileName,
    required String clientTempId,
    required void Function(MessageDTO) onLocalEcho,
    required void Function(double) onProgress,
    required void Function(Map<String, dynamic>) stompSend,
  }) async {
    try {
      /* 1️⃣ Keys */
      final senderKey =
          await _keyMgr.getOrFetchPublicKeyAndVersion(currentUserId);
      final recipientKey =
          await _keyMgr.getOrFetchPublicKeyAndVersion(chatUserId);
      if (senderKey == null || recipientKey == null) {
        LoggerService.logError('Missing pub‑key(s) – abort file send');
        return;
      }

      /* 2️⃣ Read and encrypt file */
      final bytes = await picked.readAsBytes();
      final enc = await _crypto.encryptData(
        plaintextBytes: bytes,
        senderKey: senderKey,
        recipientKey: recipientKey,
      );

      /* 3️⃣ Generate IDs */
      final fileId = const Uuid().v4();
      final msgId = clientTempId;

      /* 4️⃣ Create FileInfo */
      final fileInfo = FileInfo(
        fileId: fileId,
        fileName: fileName,
        mimeType: lookupMimeType(fileName) ?? 'application/octet-stream',
        sizeBytes: bytes.length,
      );

      /* 5️⃣ Send WebSocket message with file info */
      final wsPayload = {
        'sender': currentUserId,
        'recipient': chatUserId,
        'clientTempId': msgId,
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'SENT_MESSAGE',
        'ciphertext': '__FILE__',
        'iv': enc.iv,
        'encryptedKeyForSender': enc.keySender,
        'encryptedKeyForRecipient': enc.keyRecipient,
        'senderKeyVersion': enc.senderVer,
        'recipientKeyVersion': enc.recipientVer,
        'oneTime': false,
        'file': fileInfo.toJson(),
      };
      stompSend(wsPayload);

      /* 6️⃣ Local echo */
      onLocalEcho(MessageDTO(
        id: msgId,
        sender: currentUserId,
        recipient: chatUserId,
        timestamp: DateTime.now(),
        plaintext: '[File] $fileName',
        ciphertext: '__FILE__',
        iv: enc.iv,
        encryptedKeyForSender: enc.keySender,
        encryptedKeyForRecipient: enc.keyRecipient,
        senderKeyVersion: enc.senderVer,
        recipientKeyVersion: enc.recipientVer,
        oneTime: false,
        isRead: true,
        file: fileInfo,
      ));

      /* 7️⃣ Cache upload until server echoes definitive message ID */
      _pendingUploads[msgId] = _PendingUpload(
        fileId: fileId,
        encryptedBytes: enc.cipherBytes,
        fileName: fileName,
        mimeType: fileInfo.mimeType,
        sizeBytes: bytes.length,
        onProgress: onProgress,
      );
      onProgress(0.0); // signal start
    } catch (e) {
      LoggerService.logError('File send exception: $e');
    }
  }

  Future<void> _uploadEncryptedFile({
    required String fileId,
    required String messageId,
    required String fileName,
    required String mimeType,
    required int sizeBytes,
    required List<int> encryptedBytes,
    required void Function(double) onProgress,
  }) async {
    try {
      final uri = Uri.parse('${Environment.apiBaseUrl}/files');
      final request = http.MultipartRequest('POST', uri);

      // Add authorization header
      request.headers['Authorization'] =
          'Bearer ${await _storage.getAccessToken()}';

      // Add metadata
      final meta = {
        'messageId': messageId,
        'fileId': fileId,
        'fileName': fileName,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
      };

      request.files.add(http.MultipartFile.fromBytes(
        'meta',
        utf8.encode(jsonEncode(meta)),
        contentType: MediaType('application', 'json'),
      ));

      // Add encrypted file
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        encryptedBytes,
        filename: fileName,
        contentType: MediaType('application', 'octet-stream'),
      ));

      final responseStream = await request.send();
      final response = await http.Response.fromStream(responseStream);
      onProgress(1.0);

      if (response.statusCode >= 400) {
        LoggerService.logError(
            'File upload failed – HTTP ${response.statusCode}: ${response.body}');
      } else {
        LoggerService.logInfo('File uploaded successfully');
      }
    } catch (e) {
      LoggerService.logError('File upload exception: $e');
    }
  }
}
