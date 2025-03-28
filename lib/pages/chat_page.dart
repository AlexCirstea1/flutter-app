import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:vaultx_app/pages/profile_view_page.dart';

import '../config/environment.dart';
import '../config/logger_config.dart';
import '../models/message_dto.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart';

/// We'll define an internal enum to label whether an item is a date header or a normal message.
enum ChatItemType { dateHeader, message }

/// We'll define a small data class so our list can hold either a date or a message.
class _ChatListItem {
  final ChatItemType type;
  final String? dateLabel; // used if type = dateHeader
  final MessageDTO? message; // used if type = message

  _ChatListItem.dateHeader(this.dateLabel)
      : type = ChatItemType.dateHeader,
        message = null;

  _ChatListItem.message(this.message)
      : type = ChatItemType.message,
        dateLabel = null;
}

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
  bool _isBlocked = false;
  bool _amIBlocked = false;
  bool _isCurrentUserAdmin = false;
  bool _isChatPartnerAdmin = false;
  final TextEditingController _messageController = TextEditingController();

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final StorageService _storageService = StorageService();

  ChatService? _chatService;
  bool _isInitializing = true;

  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<bool>? _connectionStatusSubscription;

  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _checkBlockStatus();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) throw Exception('Authentication required');

      // Check current user roles
      if (_currentUserId != null) {
        final currentUserUrl = Uri.parse(
            '${Environment.apiBaseUrl}/user/public/$_currentUserId/roles');
        final currentUserResponse = await http.get(currentUserUrl);

        if (currentUserResponse.statusCode == 200) {
          final List<dynamic> roles = jsonDecode(currentUserResponse.body);
          _isCurrentUserAdmin =
              roles.any((r) => r.toString().toUpperCase().contains("ADMIN"));
        }
      }

      // Check chat partner roles
      final chatPartnerUrl = Uri.parse(
          '${Environment.apiBaseUrl}/user/public/${widget.chatUserId}/roles');
      final chatPartnerResponse = await http.get(chatPartnerUrl);

      if (chatPartnerResponse.statusCode == 200) {
        final List<dynamic> roles = jsonDecode(chatPartnerResponse.body);
        _isChatPartnerAdmin =
            roles.any((r) => r.toString().toUpperCase().contains("ADMIN"));
      }

      if (mounted) setState(() {});
    } catch (e) {
      LoggerService.logError('Error checking admin status', e);
    }
  }

  Future<void> _checkBlockStatus() async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) throw Exception('Authentication required');

      // Check if the current user has blocked the chat partner.
      final iBlockedUrl = Uri.parse(
          '${Environment.apiBaseUrl}/user/block/${widget.chatUserId}/status');
      final iBlockedResponse = await http.get(
        iBlockedUrl,
        headers: {'Authorization': 'Bearer $token'},
      );

      // Check if the chat partner has blocked the current user.
      final blockedMeUrl = Uri.parse(
          '${Environment.apiBaseUrl}/user/blockedBy/$_currentUserId/status');
      final blockedMeResponse = await http.get(
        blockedMeUrl,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (mounted) {
        setState(() {
          _isBlocked = iBlockedResponse.statusCode == 200 &&
              jsonDecode(iBlockedResponse.body) == true;
          _amIBlocked = blockedMeResponse.statusCode == 200 &&
              jsonDecode(blockedMeResponse.body) == true;
        });
      }
    } catch (e) {
      LoggerService.logError('Error checking block status', e);
    }
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
          _messages.add(ephemeral);
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        });
      },
      stompSend: (map) {
        ws.sendMessage('/app/sendPrivateMessage', map);
      },
    );
  }

  /// A helper to decide how to label a date header
  String _formatDateHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff = msgDay.difference(today).inDays;

    if (diff == 0) {
      return 'Today';
    } else if (diff == -1) {
      return 'Yesterday';
    } else {
      // fallback to a more general format, e.g. "Oct 5, 2025"
      // Or your own style
      return "${_monthName(dt.month)} ${dt.day}, ${dt.year}";
    }
  }

  String _monthName(int month) {
    switch (month) {
      case 1:
        return "Jan";
      case 2:
        return "Feb";
      case 3:
        return "Mar";
      case 4:
        return "Apr";
      case 5:
        return "May";
      case 6:
        return "Jun";
      case 7:
        return "Jul";
      case 8:
        return "Aug";
      case 9:
        return "Sep";
      case 10:
        return "Oct";
      case 11:
        return "Nov";
      case 12:
        return "Dec";
      default:
        return "$month";
    }
  }

  /// Build a combined list of items: day separator (header) + messages
  List<_ChatListItem> _buildChatItems() {
    final items = <_ChatListItem>[];
    DateTime? lastDay; // we track the last day we inserted

    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      // 'Day' is year-month-day only
      final msgDay =
          DateTime(m.timestamp.year, m.timestamp.month, m.timestamp.day);

      // If day changed (or first message), we insert a date-header item
      if (lastDay == null ||
          msgDay.year != lastDay.year ||
          msgDay.month != lastDay.month ||
          msgDay.day != lastDay.day) {
        items.add(_ChatListItem.dateHeader(_formatDateHeader(m.timestamp)));
        lastDay = msgDay;
      }

      // Then the message item
      items.add(_ChatListItem.message(m));
    }

    return items;
  }

  Widget _buildMessagesList() {
    final chatItems = _buildChatItems();

    return ScrollablePositionedList.builder(
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      // Jump to last item
      initialScrollIndex: chatItems.isEmpty ? 0 : chatItems.length - 1,
      itemCount: chatItems.length,
      itemBuilder: (ctx, i) {
        final item = chatItems[i];
        if (item.type == ChatItemType.dateHeader) {
          // Return a 'date divider' row
          return _buildDateDivider(item.dateLabel ?? '');
        } else {
          // Return the actual message bubble
          final msg = item.message!;
          final isMine = (msg.sender == _currentUserId);
          return _buildBubble(msg, isMine);
        }
      },
    );
  }

  Widget _buildDateDivider(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Horizontal line on left
            Expanded(
              child: Container(
                height: 1,
                color: Colors.white24,
                margin: const EdgeInsets.only(right: 8),
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Horizontal line on right
            Expanded(
              child: Container(
                height: 1,
                color: Colors.white24,
                margin: const EdgeInsets.only(left: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Utility to format hours/minutes
  String _formatTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: theme.surface,
      appBar: AppBar(
        backgroundColor: theme.secondary,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white10,
              child: Text(
                widget.chatUsername[0].toUpperCase(),
                style: TextStyle(
                  color: theme.onSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              widget.chatUsername,
              style: TextStyle(color: theme.onSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileViewPage(
                    userId: widget.chatUserId,
                    username: widget.chatUsername,
                  ),
                ),
              );

              if (result == 'deleted' || result == 'reported') {
                Navigator.pop(context);
              }

              if (result == 'blocked' || result == 'unblocked') {
                _checkBlockStatus();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isInitializing || _isFetchingHistory
                ? const Center(child: CircularProgressIndicator())
                : _buildMessagesList(),
          ),
          Divider(height: 1, color: Colors.white24),
          _buildTextInput(),
        ],
      ),
    );
  }

  Widget _buildTextInput() {
    if (_isBlocked ||
        _amIBlocked ||
        _isCurrentUserAdmin ||
        _isChatPartnerAdmin) {
      final message = _isCurrentUserAdmin || _isChatPartnerAdmin
          ? 'Messaging disabled for admin accounts.'
          : (_isBlocked
              ? 'Unblock to send messages.'
              : 'You cannot send messages.');

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 14),
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Message...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white12,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(MessageDTO msg, bool isMine) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: isMine ? Colors.blueAccent.withOpacity(0.8) : Colors.white12,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 0),
            bottomRight: Radius.circular(isMine ? 0 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              msg.plaintext ?? '[Encrypted]',
              style: TextStyle(
                color: isMine ? Colors.white : Colors.white70,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(msg.timestamp),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                if (isMine)
                  Icon(
                    msg.isRead ? Icons.done_all : Icons.done,
                    size: 16,
                    color: Colors.white38,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
