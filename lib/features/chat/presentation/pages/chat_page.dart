import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:vaultx_app/features/profile/presentation/pages/profile_view_page.dart';

import '../../../../core/config/environment.dart';
import '../../../../core/config/logger_config.dart';
import '../../../../core/data/services/service_locator.dart';
import '../../../../core/data/services/storage_service.dart';
import '../../../../core/data/services/websocket_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/services/chat_service.dart';
import '../../domain/models/message_dto.dart';
import '../widgets/chat_request_widget.dart';

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
    super.key,
    required this.chatUserId,
    required this.chatUsername,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  bool _isBlocked = false;
  bool _amIBlocked = false;
  bool _isCurrentUserAdmin = false;
  bool _isChatPartnerAdmin = false;
  bool _chatAuthorized = false; // once a message exists
  bool _chatRequestSent = false; // optimistic after send

  final TextEditingController _requestController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final StorageService _storageService = StorageService();

  late final ChatService _chatService = serviceLocator<ChatService>();
  bool _isInitializing = true;

  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<bool>? _connectionStatusSubscription;
  bool get _isFetchingHistory => _chatService.isFetchingHistory;
  List<MessageDTO> get _messages => _chatService.messages;

  String? _currentUserId;
  bool _isEphemeral = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _checkBlockStatus();
    _checkAdminStatus();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    _messageController.dispose();
    super.dispose();
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
      await _chatService.fetchChatHistory(
        chatUserId: widget.chatUserId,
        onMessagesUpdated: _onMessagesUpdated,
      );

      _chatAuthorized = _chatService.messages.isNotEmpty; // NEW

      final ws = WebSocketService();
      if (!ws.isConnected) await ws.connect();

      _messageSubscription = ws.messages.listen((message) {
        final type = message['type'] ?? '';
        switch (type) {
          case 'INCOMING_MESSAGE':
          case 'SENT_MESSAGE':
            _chatService.handleIncomingOrSentMessage(
              message,
              _currentUserId!,
              _onMessagesUpdated,
            );
            if (!_chatAuthorized) {
              setState(() => _chatAuthorized = true); // unlock
            }
            break;
          case 'CHAT_REQUEST': // incoming notification (optional usage)
            // If I just sent it, we already flipped flag. If I am recipient,
            // show banner in Requests screen; nothing done here.
            break;
          case 'READ_RECEIPT':
            _chatService.handleReadReceipt(
                message, widget.chatUserId, _onMessagesUpdated);
            break;
          default:
            LoggerService.logInfo('Ignoring unknown msg type: $type');
        }
      });

      _connectionStatusSubscription = ws.connectionStatus.listen((ok) {
        LoggerService.logInfo(
            ok ? 'WebSocket reconnected' : 'WebSocket disconnected');
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUserId == null) return;

    _messageController.clear();

    final ws = WebSocketService();
    await _chatService.sendMessage(
      currentUserId: _currentUserId!,
      chatUserId: widget.chatUserId,
      content: text,
      oneTime: _isEphemeral, // pass ephemeral setting
      onEphemeralAdded: (MessageDTO ephemeral) {
        setState(() {
          _messages.add(ephemeral);
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        });
      },
      stompSend: (map) => ws.sendMessage('/app/sendPrivateMessage', map),
    );
  }

  Future<void> _sendChatRequest() async {
    final text = _requestController.text.trim();
    if (text.isEmpty || _currentUserId == null) return;
    _requestController.clear();

    final result = await _chatService.sendChatRequest(
      chatUserId: widget.chatUserId,
      content: text,
    );

    if (mounted) setState(() => _chatRequestSent = true);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent – waiting for approval')));
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

  String _formatTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Determine which background image to use based on the current theme
    String backgroundImage;
    if (cs == AppTheme.lightTheme.colorScheme) {
      backgroundImage = 'assets/images/chat_bg.png';
    } else if (cs == AppTheme.darkTheme.colorScheme) {
      backgroundImage = 'assets/images/chat_bg_dark.png';
    } else {
      backgroundImage = 'assets/images/chat_bg_cyber.png';
    }

    return Scaffold(
      appBar: _buildAppBar(theme, cs),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(backgroundImage),
            repeat: ImageRepeat.repeat,
            fit: BoxFit.contain,
            opacity: 0.2,
            colorFilter: ColorFilter.mode(
              cs.surface, // Uses the current theme's surface color
              BlendMode.color, // This blend mode applies the color while preserving texture
            ),
          ),
        ),
        child: Column(
          children: [
            if (!_chatAuthorized) _buildRequestGate(),
            Expanded(
              child: _isInitializing || _isFetchingHistory
                  ? Center(
                child: CircularProgressIndicator(color: cs.secondary),
              )
                  : _chatAuthorized
                  ? _buildMessagesList()
                  : const SizedBox.shrink(),
            ),
            Divider(height: 1, color: cs.onSurface.withOpacity(0.2)),
            _chatAuthorized ? _buildTextInput() : _buildLockedInput(),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(ThemeData theme, ColorScheme cs) {
    // Get a safe initial character for the avatar
    final String initial = widget.chatUsername.isNotEmpty
        ? widget.chatUsername[0].toUpperCase()
        : "?";

    return AppBar(
      backgroundColor: cs.surface,
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: cs.primary.withOpacity(0.2),
            child: Text(initial,
                style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Text(widget.chatUsername.isNotEmpty ? widget.chatUsername : "Unknown User",
              style: TextStyle(color: theme.textTheme.titleLarge?.color)),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.info_outline, color: cs.primary),
          onPressed: () async {
            final r = await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ProfileViewPage(
                        userId: widget.chatUserId,
                        username: widget.chatUsername)));
            if (r == 'blocked' || r == 'unblocked') _checkBlockStatus();
            if (r == 'deleted' || r == 'reported') Navigator.pop(context);
          },
        ),
      ],
    );
  }

  Widget _buildLockedInput() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: colorScheme.primary.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Chat locked – send a request first',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateDivider(String label) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.2),
                margin: const EdgeInsets.only(right: 8),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Horizontal line on right
            Expanded(
              child: Container(
                height: 1,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.2),
                margin: const EdgeInsets.only(left: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextInput() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isBlocked ||
        _amIBlocked ||
        _isCurrentUserAdmin ||
        _isChatPartnerAdmin) {
      final message = _isCurrentUserAdmin || _isChatPartnerAdmin
          ? 'Messaging disabled for admin accounts.'
          : (_isBlocked
          ? 'Unblock to send messages.'
          : 'You cannot send messages.');

      return Container(
        color: colorScheme.surface,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  fontSize: 14),
            ),
          ),
        ),
      );
    }

    return Container(
      color: colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.whatshot,
                  color: _isEphemeral
                      ? colorScheme.primary
                      : theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                ),
                tooltip: 'One-time message',
                onPressed: () {
                  setState(() {
                    _isEphemeral = !_isEphemeral;
                  });
                },
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    hintText: 'Message...',
                    hintStyle: TextStyle(
                        color:
                        theme.textTheme.bodyMedium?.color?.withOpacity(0.5)),
                    filled: true,
                    fillColor: colorScheme.surface,
                    contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide:
                      BorderSide(color: colorScheme.primary.withOpacity(0.1)),
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.primary,
                child: IconButton(
                  icon: Icon(Icons.send, color: colorScheme.onPrimary),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(MessageDTO msg, bool isMine) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: isMine
              ? colorScheme.primary.withOpacity(0.8)
              : colorScheme.tertiary.withOpacity(0.7),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
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
                color: isMine
                    ? colorScheme.onPrimary
                    : theme.textTheme.bodyLarge?.color,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Add one-time indicator if needed
                if (msg.oneTime)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.timer,
                      size: 12,
                      color: isMine
                          ? colorScheme.onPrimary.withOpacity(0.7)
                          : theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                Text(
                  _formatTime(msg.timestamp),
                  style: TextStyle(
                      color: isMine
                          ? colorScheme.onPrimary.withOpacity(0.7)
                          : theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                      fontSize: 11),
                ),
                if (isMine)
                  Icon(
                    msg.isRead ? Icons.done_all : Icons.done,
                    size: 16,
                    color: isMine
                        ? colorScheme.onPrimary.withOpacity(0.7)
                        : theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestGate() {
    return ChatRequestWidget(
      recipientUsername: widget.chatUsername,
      requestSent: _chatRequestSent,
      onSendRequest: (String message) async {
        final result = await _chatService.sendChatRequest(
          chatUserId: widget.chatUserId,
          content: message,
        );

        if (mounted) setState(() => _chatRequestSent = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Request sent – waiting for approval')));
      },
    );
  }
}
