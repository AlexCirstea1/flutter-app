import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/logger_config.dart';
import '../main.dart';
import '../models/chat_history_dto.dart';
import '../pages/chat_page.dart';
import '../pages/select_user_page.dart';
import '../services/auth_service.dart';
import '../services/avatar_service.dart';
import '../services/chat_service.dart';
import '../services/service_locator.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart';
import '../widget/bottom_nav_bar.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with RouteAware {
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  final StorageService _storageService = StorageService();
  final AuthService _authService = serviceLocator<AuthService>();
  final WebSocketService _webSocketService = WebSocketService();

  late AvatarService _avatarService;
  late ChatService _chatService;

  final String _usernamePlaceholder = 'User';
  String _username = '';
  Uint8List? _userAvatar;
  int _selectedIndex = 0;

  List<ChatHistoryDTO> _chatHistory = [];
  bool _isLoadingHistory = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _avatarService = AvatarService(_storageService);
    _chatService = ChatService(storageService: _storageService);

    _loadUsername();
    _initializeUserId().then((_) {
      _fetchChatHistory();
      _initializeWebSocket();
      _loadUserAvatar();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _messageSubscription?.cancel();
    super.dispose();
  }

  // Called when coming back to this page
  @override
  void didPopNext() {
    // When the user navigates back to the home page, refresh the chat history.
    _fetchChatHistory();
  }

  Future<void> _loadUsername() async {
    final stored = await _storageService.getUsername();
    setState(() {
      _username = stored ?? _usernamePlaceholder;
    });
  }

  Future<void> _initializeUserId() async {
    _currentUserId = await _storageService.getUserId();
  }

  Future<void> _initializeWebSocket() async {
    await _webSocketService.connect();

    // Listen for all incoming WebSocket messages
    _messageSubscription = _webSocketService.messages.listen((message) {
      final type = message['type'] ?? '';
      switch (type) {
        case 'INCOMING_MESSAGE':
        case 'SENT_MESSAGE':
          _handleNewOrUpdatedMessage(message);
          break;
        case 'READ_RECEIPT':
          _handleReadReceipt(message);
          break;
        case 'USER_SEARCH_RESULTS':
          // Not used on home screen
          break;
        default:
          LoggerService.logInfo('Unknown WS message type: $type');
      }
    });
  }

  void _handleNewOrUpdatedMessage(Map<String, dynamic> rawMsg) {
    // If user ID is not loaded or widget is gone, skip
    if (_currentUserId == null || !mounted) return;

    // Let ChatService handle ephemeral decryption and updating the chat list
    _chatService.handleNewOrUpdatedMessage(
      msg: rawMsg,
      currentUserId: _currentUserId!,
      chatHistory: _chatHistory,
    );

    // Rebuild UI
    setState(() {});
  }

  void _markAllAsReadStomp() {
    final unread = _chatService!.messages
        .where((m) => m.recipient == _currentUserId && !m.isRead)
        .toList();
    if (unread.isEmpty) return;

    final messageIds = unread.map((m) => m.id).toList();

    final payload = {
      'messageIds': messageIds,
    };

    // Use your WebSocketService or STOMP client to send to /app/markAsRead
    final webSocketService = WebSocketService();
    webSocketService.sendMessage('/app/markAsRead', payload);
  }

  void _handleReadReceipt(Map<String, dynamic> data) {
    if (!mounted) return;

    final readerId = data['readerId'] ?? '';
    final List<dynamic> msgIds = data['messageIds'] ?? [];
    final tsStr = data['readTimestamp'] ?? '';
    if (readerId.isEmpty || msgIds.isEmpty || tsStr.isEmpty) return;

    final readAt = DateTime.parse(tsStr);
    setState(() {
      // Mark the relevant messages as read
      for (var chat in _chatHistory) {
        if (chat.participant == readerId) {
          for (var m in chat.messages) {
            if (msgIds.contains(m.id)) {
              m.isRead = true;
              m.readTimestamp = readAt;
            }
          }
        }
        // Recalculate unread
        chat.unreadCount = chat.messages
            .where((m) =>
                m.recipient == _currentUserId &&
                m.sender == chat.participant &&
                !m.isRead)
            .length;
      }
    });
  }

  Future<void> _fetchChatHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final newChats = await _chatService.fetchAllChats();
      setState(() {
        _chatHistory = newChats;
      });
    } catch (e) {
      LoggerService.logError('Error fetching chat listing', e);
    } finally {
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _logout() async {
    final token = await _storageService.getAccessToken();
    if (token != null) {
      final success = await _authService.logout(token);
      if (success && mounted) {
        await _storageService.clearLoginDetails();
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    }
  }

  void _navigateToSelectUser() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SelectUserPage()),
    );
  }

  void _navigateToChat(ChatHistoryDTO chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          chatUserId: chat.participant,
          chatUsername: chat.participantUsername,
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<Uint8List?> _fetchAvatar(String userId) async {
    return _avatarService.getAvatar(userId);
  }

  Future<void> _loadUserAvatar() async {
    if (_currentUserId == null) return;
    final avatar = await _avatarService.getAvatar(_currentUserId!);
    setState(() {
      _userAvatar = avatar;
    });
  }

  Widget _buildUserAvatar() {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: _userAvatar != null
          ? CircleAvatar(backgroundImage: MemoryImage(_userAvatar!))
          : const CircleAvatar(
              child: Icon(Icons.person, color: Colors.white70)),
    );
  }

  Widget _buildChatList() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_chatHistory.isEmpty) {
      return const Center(
        child: Text(
          'No conversations yet.',
          style: TextStyle(fontSize: 16, color: Colors.white54),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _chatHistory.length,
      separatorBuilder: (_, __) =>
          const Divider(color: Colors.white12, indent: 72, height: 1),
      itemBuilder: (ctx, i) {
        final chat = _chatHistory[i];
        final lastMsg = chat.messages.isNotEmpty ? chat.messages.last : null;

        // Format timestamp
        String timeString = '';
        if (lastMsg?.timestamp != null) {
          final now = DateTime.now();
          final timestamp = lastMsg!.timestamp!;
          final difference = now.difference(timestamp);

          if (difference.inDays > 0) {
            // Show date for older messages
            timeString =
                '${timestamp.day}/${timestamp.month}/${timestamp.year}';
          } else {
            // Show time for today's messages
            timeString =
                '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
          }
        }

        return ListTile(
          leading: FutureBuilder<Uint8List?>(
            future: _fetchAvatar(chat.participant),
            builder: (_, snap) {
              return snap.connectionState == ConnectionState.waiting
                  ? const CircleAvatar(
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : CircleAvatar(
                      backgroundImage:
                          snap.hasData ? MemoryImage(snap.data!) : null,
                      child: snap.hasData
                          ? null
                          : const Icon(Icons.person, color: Colors.white70),
                    );
            },
          ),
          title: Text(
            chat.participantUsername.isNotEmpty
                ? chat.participantUsername
                : 'User ${chat.participant}',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white),
          ),
          subtitle: Row(
            children: [
              Expanded(
                child: Text(
                  (lastMsg?.plaintext?.isNotEmpty ?? false)
                      ? lastMsg!.plaintext!
                      : '[Encrypted message]',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60),
                ),
              ),
              if (timeString.isNotEmpty)
                Text(
                  timeString,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          trailing: chat.unreadCount > 0
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${chat.unreadCount}',
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                )
              : const SizedBox.shrink(),
          onTap: () => _navigateToChat(chat),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 2,
        leading: _buildUserAvatar(),
        title: Text('Hello, $_username',
            style: const TextStyle(fontWeight: FontWeight.w400)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _navigateToSelectUser,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(child: _buildChatList()),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
