import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:uuid/uuid.dart';

import '../config/environment.dart';
import '../config/logger_config.dart';
import '../models/message_dto.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart';

class ChatPage extends StatefulWidget {
  final String chatUserId;
  final String chatUsername;

  const ChatPage({
    super.key,
    required this.chatUserId,
    required this.chatUsername,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final StorageService _storageService = StorageService();
  final WebSocketService _webSocketService = WebSocketService();
  final TextEditingController _messageController = TextEditingController();

  // Controller and listener for ScrollablePositionedList
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
  ItemPositionsListener.create();

  final List<MessageDTO> _messages = [];
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<bool>? _connectionStatusSubscription;

  String? _currentUserId;
  bool _isFetchingHistory = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    _currentUserId = await _storageService.getUserId();
    if (_currentUserId == null) {
      LoggerService.logError('Current user ID is null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to retrieve user information')),
      );
      Navigator.pop(context);
      return;
    }

    LoggerService.logInfo("ChatPage for $_currentUserId -> ${widget.chatUserId}");

    // 1) Fetch existing conversation
    await _fetchChatHistory();

    // 2) Ensure WebSocket is connected
    if (!_webSocketService.isConnected) {
      await _webSocketService.connect();
    }

    // 3) Listen to WebSocket messages
    _messageSubscription = _webSocketService.messages.listen((message) {
      final type = message['type'] ?? '';
      switch (type) {
        case 'INCOMING_MESSAGE':
        case 'SENT_MESSAGE':
          _handleIncomingOrSentMessage(message);
          break;
        case 'READ_RECEIPT':
          _handleReadReceipt(message);
          break;
        default:
          LoggerService.logInfo('Ignoring unknown message type: $type');
      }
    });

    // 4) Watch connection status
    _connectionStatusSubscription =
        _webSocketService.connectionStatus.listen((connected) {
          if (!connected) {
            LoggerService.logInfo('WebSocket disconnected');
          } else {
            LoggerService.logInfo('WebSocket reconnected');
          }
        });
  }

  /// Fetch conversation via GET /api/messages?recipientId=...
  Future<void> _fetchChatHistory() async {
    setState(() => _isFetchingHistory = true);

    final accessToken = await _storageService.getAccessToken();
    if (accessToken == null) {
      LoggerService.logError('Access token not found');
      return;
    }

    final url = Uri.parse(
      '${Environment.apiBaseUrl}/messages?recipientId=${widget.chatUserId}',
    );

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (response.statusCode == 200) {
        final rawBody = utf8.decode(response.bodyBytes);
        final List<dynamic> history = jsonDecode(rawBody);

        setState(() {
          _messages.clear();
          for (var m in history) {
            _messages.add(
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
          // Sort messages ascending
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        });

        // Mark any unread messages as read
        await _markMessagesAsRead();
      } else {
        LoggerService.logError(
          'Failed to fetch chat history. Code: ${response.statusCode}',
        );
      }
    } catch (e) {
      LoggerService.logError('Error fetching chat history', e);
    } finally {
      setState(() => _isFetchingHistory = false);
    }
  }

  /// POST /api/chats/mark-as-read
  Future<void> _markMessagesAsRead() async {
    if (_currentUserId == null) return;
    final accessToken = await _storageService.getAccessToken();
    if (accessToken == null) return;

    final unreadMessages = _messages
        .where((msg) => msg.recipient == _currentUserId && !msg.isRead)
        .toList();
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
        setState(() {
          for (var msg in unreadMessages) {
            msg.isRead = true;
            msg.readTimestamp = now;
          }
        });
      } else {
        LoggerService.logError(
          'Failed to mark messages as read (status=${response.statusCode}).',
        );
      }
    } catch (e) {
      LoggerService.logError('Error marking messages as read', e);
    }
  }

  /// Handles a newly arrived or sent message from the WebSocket stream
  void _handleIncomingOrSentMessage(Map<String, dynamic> msg) {
    final String sender = msg['sender'] ?? '';
    final String recipient = msg['recipient'] ?? '';

    // Create a new MessageDTO from the server payload
    final newMsg = MessageDTO(
      id: msg['id']?.toString() ?? const Uuid().v4(),
      sender: sender,
      recipient: recipient,
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

    final clientTempId = newMsg.clientTempId;

    setState(() {
      // 1) If we previously added an ephemeral message with clientTempId, replace it
      if (clientTempId != null && clientTempId.isNotEmpty) {
        final ephemeralIndex = _messages.indexWhere((m) => m.id == clientTempId);
        if (ephemeralIndex >= 0) {
          final ephemeralMsg = _messages[ephemeralIndex];
          LoggerService.logInfo('Ephemeral message: sender=${ephemeralMsg.sender}, recipient=${ephemeralMsg.recipient}');
          LoggerService.logInfo('Replacing with: sender=${newMsg.sender}, recipient=${newMsg.recipient}');

          _messages[ephemeralIndex] = newMsg;
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          return;
        }
      }

      // 2) Otherwise, either insert new or update existing
      final existingIndex = _messages.indexWhere((m) => m.id == newMsg.id);
      if (existingIndex >= 0) {
        // Update the existing message
        _messages[existingIndex] = newMsg;
      } else {
        // Insert new
        _messages.add(newMsg);
      }
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });

    // 3) If I'm the recipient of this message and it's not read, mark it read
    if (recipient == _currentUserId && !newMsg.isRead) {
      _markMessageAsReadViaREST(newMsg.id);
    }
  }

  /// Handles an incoming read-receipt notification
  void _handleReadReceipt(Map<String, dynamic> message) {
    final String readerId = message['readerId'] ?? '';
    final List<dynamic> messageIds = message['messageIds'] ?? [];
    final String readTimestampStr = message['readTimestamp'] ?? '';
    final DateTime readTimestamp = readTimestampStr.isNotEmpty
        ? DateTime.parse(readTimestampStr)
        : DateTime.now();

    // If the "reader" is the other user, update the local state
    if (readerId == widget.chatUserId) {
      setState(() {
        for (var msg in _messages) {
          if (messageIds.contains(msg.id)) {
            msg.isRead = true;
            msg.readTimestamp = readTimestamp;
          }
        }
      });
    }
  }

  /// Mark a single message as read via POST /api/chats/mark-as-read
  Future<void> _markMessageAsReadViaREST(String messageId) async {
    final accessToken = await _storageService.getAccessToken();
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
        setState(() {
          final msg = _messages.firstWhere(
                (m) => m.id == messageId,
            orElse: () => MessageDTO(
              id: '',
              sender: '',
              recipient: '',
              content: '',
              timestamp: DateTime.now(),
            ),
          );
          if (msg.id.isNotEmpty) {
            msg.isRead = true;
            msg.readTimestamp = now;
          }
        });
      } else {
        LoggerService.logError(
          'Failed to mark msg as read. Code ${response.statusCode}',
        );
      }
    } catch (e) {
      LoggerService.logError('Error marking single msg as read', e);
    }
  }

  /// Sends a new message over STOMP to /app/sendPrivateMessage
  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final now = DateTime.now();
    final tempId = const Uuid().v4();

    setState(() {
      _messages.add(
        MessageDTO(
          id: tempId,
          sender: _currentUserId!,
          recipient: widget.chatUserId,
          content: content,
          timestamp: now,
          isRead: false,
          clientTempId: null,
        ),
      );
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });
    _messageController.clear();

    // STOMP message
    final msgMap = {
      'sender': _currentUserId,
      'recipient': widget.chatUserId,
      'content': content,
      'clientTempId': tempId,
    };
    _webSocketService.sendMessage('/app/sendPrivateMessage', msgMap);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return "$hh:$mm";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.chatUsername}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isFetchingHistory
                ? const Center(child: CircularProgressIndicator())
                : ScrollablePositionedList.builder(
              itemScrollController: _itemScrollController,
              itemPositionsListener: _itemPositionsListener,
              // If you want the view to start at the bottom:
              initialScrollIndex:
              _messages.isEmpty ? 0 : _messages.length - 1,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final bool isSender = (msg.sender == _currentUserId);
                return _buildMessageBubble(msg, isSender);
              },
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 5.0,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type your message here...',
                          border: InputBorder.none,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(12.0),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageDTO msg, bool isSender) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 4.0,
        horizontal: 8.0,
      ),
      child: Align(
        alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: 10,
              horizontal: 15,
            ),
            decoration: BoxDecoration(
              color: isSender ? Colors.blue : Colors.grey[300],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: isSender ? const Radius.circular(12) : Radius.zero,
                bottomRight:
                isSender ? Radius.zero : const Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment:
              isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  msg.content,
                  style: TextStyle(
                    color: isSender ? Colors.white : Colors.black,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(msg.timestamp),
                      style: TextStyle(
                        color: isSender ? Colors.white70 : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 5),
                    if (isSender)
                      Icon(
                        msg.isRead ? Icons.done_all : Icons.done,
                        size: 16,
                        color: msg.isRead ? Colors.white70 : Colors.white70,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
