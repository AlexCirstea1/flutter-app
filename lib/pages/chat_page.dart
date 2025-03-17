import 'dart:async';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../config/logger_config.dart';
import '../models/message_dto.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart';
import '../services/chat_service.dart';

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
  final TextEditingController _messageController = TextEditingController();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  ChatService? _chatService;
  bool _isInitializing = true;

  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<bool>? _connectionStatusSubscription;

  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      final storageService = StorageService();
      _currentUserId = await storageService.getUserId();
      if (_currentUserId == null) {
        LoggerService.logError('Current user ID is null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Unable to retrieve user information')),
          );
          Navigator.pop(context);
        }
        return;
      }

      _chatService = ChatService(storageService: storageService);
      await _chatService!.fetchChatHistory(
        chatUserId: widget.chatUserId,
        onMessagesUpdated: _onMessagesUpdated,
      );

      final webSocketService = WebSocketService();
      if (!webSocketService.isConnected) {
        await webSocketService.connect();
      }

      _messageSubscription = webSocketService.messages.listen((message) {
        final type = message['type'] ?? '';
        switch (type) {
          case 'INCOMING_MESSAGE':
          case 'SENT_MESSAGE':
            _chatService?.handleIncomingOrSentMessage(
              message,
              _currentUserId!,
              _onMessagesUpdated,
            );
            break;
          case 'READ_RECEIPT':
            _chatService?.handleReadReceipt(
              message,
              widget.chatUserId,
              _onMessagesUpdated,
            );
            break;
          default:
            LoggerService.logInfo('Ignoring unknown message type: $type');
        }
      });

      _connectionStatusSubscription =
          webSocketService.connectionStatus.listen((connected) {
        if (!connected) {
          LoggerService.logInfo('WebSocket disconnected');
        } else {
          LoggerService.logInfo('WebSocket reconnected');
        }
      });
    } catch (e) {
      LoggerService.logError('Error initializing chat', e);
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  void _onMessagesUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  bool get _isFetchingHistory => _chatService?.isFetchingHistory ?? true;
  List<MessageDTO> get _messages => _chatService?.messages ?? [];

  void _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _chatService == null || _currentUserId == null)
      return;

    _messageController.clear();

    final webSocketService = WebSocketService();
    await _chatService!.sendMessage(
      currentUserId: _currentUserId!,
      chatUserId: widget.chatUserId,
      content: content,
      onEphemeralAdded: (MessageDTO ephemeral) {
        if (mounted) {
          setState(() {
            _chatService!.messages.add(ephemeral);
            _chatService!.messages
                .sort((a, b) => a.timestamp.compareTo(b.timestamp));
          });
        }
      },
      stompSend: (msgMap) {
        webSocketService.sendMessage('/app/sendPrivateMessage', msgMap);
      },
    );
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
            child: _isInitializing || _isFetchingHistory
                ? const Center(child: CircularProgressIndicator())
                : _buildMessageList(),
          ),
          SafeArea(
            child: _buildMessageInput(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ScrollablePositionedList.builder(
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      initialScrollIndex: _messages.isEmpty ? 0 : _messages.length - 1,
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isSender = (msg.sender == _currentUserId);
        return _buildMessageBubble(msg, isSender);
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
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
    );
  }

  Widget _buildMessageBubble(MessageDTO msg, bool isSender) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Align(
        alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
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
                bottomLeft: isSender ? const Radius.circular(12) : Radius.zero,
                bottomRight: isSender ? Radius.zero : const Radius.circular(12),
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
