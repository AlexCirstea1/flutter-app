import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../config/logger_config.dart';
import '../models/message_dto.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart';

class ChatPage extends StatefulWidget {
  final String chatUserId;
  final String chatUsername;

  const ChatPage({
    Key? key,
    required this.chatUserId,
    required this.chatUsername,
  }) : super(key: key);

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
      final storage = StorageService();
      _currentUserId = await storage.getUserId();
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

      _chatService = ChatService(storageService: storage);
      await _chatService!.fetchChatHistory(
        chatUserId: widget.chatUserId,
        onMessagesUpdated: _onMessagesUpdated,
      );

      final ws = WebSocketService();
      if (!ws.isConnected) {
        await ws.connect();
      }

      // Listen for real-time message updates
      _messageSubscription = ws.messages.listen((message) {
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
            LoggerService.logInfo('Ignoring unknown msg type: $type');
        }
      });

      // Listen for connection changes
      _connectionStatusSubscription = ws.connectionStatus.listen((ok) {
        if (!ok) {
          LoggerService.logInfo('WebSocket disconnected');
        } else {
          LoggerService.logInfo('WebSocket reconnected');
        }
      });
    } catch (err) {
      LoggerService.logError('Error initializing chat', err);
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  void _onMessagesUpdated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  bool get _isFetchingHistory => _chatService?.isFetchingHistory ?? false;
  List<MessageDTO> get _messages => _chatService?.messages ?? [];

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _chatService == null || _currentUserId == null) return;

    _messageController.clear();

    final ws = WebSocketService();
    await _chatService!.sendMessage(
      currentUserId: _currentUserId!,
      chatUserId: widget.chatUserId,
      content: text,
      onEphemeralAdded: (MessageDTO ephemeral) {
        if (!mounted) return;
        setState(() {
          // ephemeral plaintext message
          _messages.add(ephemeral);
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        });
      },
      stompSend: (map) {
        ws.sendMessage('/app/sendPrivateMessage', map);
      },
    );
  }

  String _formatTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Widget _buildMessagesList() {
    return ScrollablePositionedList.builder(
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      initialScrollIndex: _messages.isEmpty ? 0 : _messages.length - 1,
      itemCount: _messages.length,
      itemBuilder: (ctx, i) {
        final msg = _messages[i];
        final isMine = (msg.sender == _currentUserId);
        return _buildBubble(msg, isMine);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        title: Text('Chat with ${widget.chatUsername}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isInitializing || _isFetchingHistory
                ? const Center(child: CircularProgressIndicator())
                : _buildMessagesList(),
          ),
          _buildTextInput(),
        ],
      ),
    );
  }

  Widget _buildTextInput() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white12,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.blueAccent,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(MessageDTO msg, bool isMine) {
    final displayText = msg.plaintext ?? '[Encrypted]';
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: isMine ? Colors.blueAccent : Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(displayText, style: TextStyle(color: isMine ? Colors.white : Colors.white70, fontSize: 16)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_formatTime(msg.timestamp), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(msg.isRead ? Icons.done_all : Icons.done, size: 16, color: Colors.white38),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }

}
