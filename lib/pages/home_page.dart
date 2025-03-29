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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _buildUserAvatar(),
        title: Text(
          'SECURE MESSAGING',
          style: TextStyle(
            fontSize: 14,
            letterSpacing: 2.0,
            fontWeight: FontWeight.w300,
            color: Colors.cyan.shade100,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.cyan.shade200),
            onPressed: _navigateToSelectUser,
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.cyan.shade200),
            onPressed: _logout,
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Color(0xFF101720)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.security, size: 14, color: Colors.cyan.shade400),
                    const SizedBox(width: 8),
                    Text(
                      'WELCOME, ${_username.toUpperCase()}',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(color: Colors.cyan.withOpacity(0.1), height: 1),
              ),
              Expanded(child: _buildChatList()),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildUserAvatar() {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.cyan.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.cyan.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: _userAvatar != null
            ? CircleAvatar(backgroundImage: MemoryImage(_userAvatar!))
            : const CircleAvatar(
            backgroundColor: Colors.black45,
            child: Icon(Icons.person, color: Colors.cyan)),
      ),
    );
  }

  Widget _buildChatList() {
    if (_isLoadingHistory) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent),
      );
    }

    if (_chatHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 50, color: Colors.grey.shade800),
            const SizedBox(height: 16),
            Text(
              'NO CONVERSATIONS YET',
              style: TextStyle(
                fontSize: 14,
                letterSpacing: 1.5,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a new secure conversation',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _chatHistory.length,
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
            timeString = '${timestamp.day}/${timestamp.month}/${timestamp.year}';
          } else {
            timeString = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
          }
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF121A24),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: chat.unreadCount > 0
                  ? Colors.cyan.withOpacity(0.3)
                  : Colors.transparent,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            leading: _buildChatAvatar(chat.participant),
            title: Row(
              children: [
                Text(
                  chat.participantUsername.isNotEmpty
                      ? chat.participantUsername.toUpperCase()
                      : 'USER-${chat.participant.substring(0, 6)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                if (chat.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${chat.unreadCount}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.cyanAccent,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (lastMsg?.plaintext?.isNotEmpty ?? false)
                            ? lastMsg!.plaintext!
                            : '[ENCRYPTED]',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                          fontFamily: lastMsg?.plaintext == null ? 'monospace' : null,
                        ),
                      ),
                    ),
                    if (timeString.isNotEmpty)
                      Text(
                        timeString,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                  ],
                ),
              ],
            ),
            onTap: () => _navigateToChat(chat),
          ),
        );
      },
    );
  }

  Widget _buildChatAvatar(String userId) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.cyan.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.05),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: FutureBuilder<Uint8List?>(
        future: _fetchAvatar(userId),
        builder: (_, snap) {
          return CircleAvatar(
            radius: 22,
            backgroundColor: Colors.black38,
            backgroundImage: snap.hasData ? MemoryImage(snap.data!) : null,
            child: snap.connectionState == ConnectionState.waiting
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.cyanAccent,
              ),
            )
                : snap.hasData
                ? null
                : const Icon(Icons.person, color: Colors.cyanAccent, size: 20),
          );
        },
      ),
    );
  }
}
