import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  final List<MessageDTO> _messages = [];
  String? _currentUserId;

  final ScrollController _scrollController = ScrollController();

  bool _isFetchingHistory = false;

  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<bool>? _connectionStatusSubscription;

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

    LoggerService.logInfo("Current User ID: $_currentUserId");

    await _fetchChatHistory();
    _initializeWebSocket();
  }

  Future<void> _initializeWebSocket() async {
    if (!_webSocketService.isConnected) {
      await _webSocketService.connect();
    }

    _messageSubscription = _webSocketService.messages.listen((message) {
      final String type = message['type'] ?? '';
      switch (type) {
        case 'PRIVATE_MESSAGE':
          _handleIncomingPrivateMessage(message);
          break;
        case 'READ_RECEIPT':
          _handleReadReceipt(message);
          break;
      // Handle other message types if needed
        default:
          LoggerService.logInfo('Unknown message type: $type');
      }
    });

    _connectionStatusSubscription =
        _webSocketService.connectionStatus.listen((isConnected) {
          if (!isConnected) {
            LoggerService.logInfo('WebSocket disconnected');
          } else {
            LoggerService.logInfo('WebSocket connected/reconnected');
          }
        });
  }

  void _handleIncomingPrivateMessage(Map<String, dynamic> message) {
    final String senderId = message['sender']?.toString() ?? '';
    final String recipientId = message['recipient']?.toString() ?? '';
    final String content = message['content']?.toString() ?? '';
    final String timestampStr = message['timestamp']?.toString() ?? DateTime.now().toIso8601String();

    // Check if the message is relevant to this chat
    if ((senderId == widget.chatUserId && recipientId == _currentUserId) ||
        (senderId == _currentUserId && recipientId == widget.chatUserId)) {
      final DateTime timestamp = DateTime.parse(timestampStr);
      final MessageDTO incomingMessage = MessageDTO(
        id: message['id']?.toString() ?? const Uuid().v4().toString(),
        sender: senderId,
        recipient: recipientId,
        content: content,
        timestamp: timestamp,
        isRead: message['isRead'] ?? false,
        readTimestamp: message['readTimestamp'] != null
            ? DateTime.parse(message['readTimestamp'])
            : null,
      );

      setState(() {
        _messages.add(incomingMessage);
      });

      _scrollToBottom();
    }
  }

  void _handleReadReceipt(Map<String, dynamic> message) {
    final String readerId = message['readerId'] ?? '';
    final List<dynamic> messageIds = message['messageIds'] ?? [];
    final String readTimestampStr = message['readTimestamp'] ?? '';
    final DateTime readTimestamp =
    readTimestampStr.isNotEmpty ? DateTime.parse(readTimestampStr) : DateTime.now();

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

  Future<void> _fetchChatHistory() async {
    setState(() {
      _isFetchingHistory = true;
    });

    final accessToken = await _storageService.getAccessToken();
    if (accessToken == null) {
      LoggerService.logError('Access token not found');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Access token not found')));
      setState(() {
        _isFetchingHistory = false;
      });
      return;
    }

    LoggerService.logInfo("Fetching chat history for User ID: $_currentUserId");

    final url = Uri.parse('${Environment.apiBaseUrl}/messages?recipientId=${widget.chatUserId}');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> history = jsonDecode(response.body);
        LoggerService.logInfo("Fetched ${history.length} messages from history.");

        setState(() {
          _messages.clear();
          _messages.addAll(history.map((message) => MessageDTO(
            id: message['id']?.toString() ?? const Uuid().v4().toString(),
            sender: message['sender']?.toString() ?? '',
            recipient: message['recipient']?.toString() ?? '',
            content: message['content']?.toString() ?? '',
            timestamp: DateTime.parse(message['timestamp']?.toString() ?? DateTime.now().toIso8601String()),
            isRead: message['isRead'] ?? false,
            readTimestamp: message['readTimestamp'] != null
                ? DateTime.parse(message['readTimestamp'])
                : null,
          )));
        });

        _scrollToBottom();

        // After fetching messages, mark unread messages as read
        await _markMessagesAsRead();
      } else {
        LoggerService.logError(
            'Failed to fetch chat history. Status code: ${response.statusCode}');
      }
    } catch (e) {
      LoggerService.logError('Failed to fetch chat history', e);
    } finally {
      setState(() {
        _isFetchingHistory = false;
      });
    }
  }

  Future<void> _markMessagesAsRead() async {
    final accessToken = await _storageService.getAccessToken();
    if (accessToken == null || _currentUserId == null) return;

    // Identify unread messages sent by chatUserId to currentUserId
    List<String> unreadMessageIds = _messages
        .where((msg) => msg.sender == widget.chatUserId && !msg.isRead)
        .map((msg) => msg.id)
        .toList();

    if (unreadMessageIds.isEmpty) return; // Nothing to mark as read

    final url = Uri.parse('${Environment.apiBaseUrl}/chats/mark-as-read');
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'messageIds': unreadMessageIds,
        }),
      );

      if (response.statusCode == 200) {
        LoggerService.logInfo('Messages marked as read.');

        // Update local messages
        setState(() {
          final now = DateTime.now();
          for (var msg in _messages) {
            if (unreadMessageIds.contains(msg.id)) {
              msg.isRead = true;
              msg.readTimestamp = now;
            }
          }
        });
      } else {
        LoggerService.logError(
            'Failed to mark messages as read. Status code: ${response.statusCode}');
      }
    } catch (e) {
      LoggerService.logError('Error marking messages as read', e);
    }
  }

  void _sendMessage() async {
    final messageContent = _messageController.text.trim();
    if (messageContent.isEmpty) return;

    final accessToken = await _storageService.getAccessToken();
    if (accessToken == null) {
      LoggerService.logError('Access token not found');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Access token not found')));
      return;
    }

    try {
      final now = DateTime.now();
      final tempMessageId = const Uuid().v4().toString(); // Temporary ID

      // Add message locally first
      setState(() {
        _messages.add(MessageDTO(
          id: tempMessageId,
          sender: _currentUserId!,
          recipient: widget.chatUserId,
          content: messageContent,
          timestamp: now,
          isRead: false,
        ));
      });

      // Send the message via WebSocket
      Map<String, dynamic> chatMessage = {
        'sender': _currentUserId,
        'recipient': widget.chatUserId,
        'content': messageContent,
      };

      _webSocketService.sendMessage('/app/sendPrivateMessage', chatMessage);
      LoggerService.logInfo("Message sent: $chatMessage");

      _messageController.clear();

      _scrollToBottom();
    } catch (error) {
      LoggerService.logError('Error sending message: $error');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to send message')));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    _webSocketService.disconnect();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatTimestamp(String timestamp) {
    DateTime dateTime = DateTime.parse(timestamp);
    // Format as HH:MM
    return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.chatUsername}'),
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: _isFetchingHistory
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              controller: _scrollController,
              padding:
              const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isSender = msg.sender.toLowerCase() == _currentUserId!.toLowerCase();

                return Padding(
                  padding:
                  const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                  child: Align(
                    alignment:
                    isSender ? Alignment.centerRight : Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                        decoration: BoxDecoration(
                          color: isSender ? Colors.blue : Colors.grey[300],
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: isSender
                                ? const Radius.circular(12)
                                : Radius.zero,
                            bottomRight: isSender
                                ? Radius.zero
                                : const Radius.circular(12),
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
                                  _formatTimestamp(msg.timestamp.toIso8601String()),
                                  style: TextStyle(
                                    color:
                                    isSender ? Colors.white70 : Colors.black54,
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
                            if (isSender && msg.readTimestamp != null)
                              Text(
                                "Read at ${_formatTimestamp(msg.readTimestamp!.toIso8601String())}",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
}
