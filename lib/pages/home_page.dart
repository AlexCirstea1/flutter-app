import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/logger_config.dart';
import '../models/chat_history_dto.dart';
import '../pages/chat_page.dart';
import '../pages/select_user_page.dart';
import '../services/auth_service.dart';
import '../services/avatar_service.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart';
import '../widget/bottom_nav_bar.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  StreamSubscription? _messageSubscription;
  final StorageService _storageService = StorageService();
  final AuthService _authService = AuthService();
  final WebSocketService _webSocketService = WebSocketService();

  late AvatarService _avatarService;
  late ChatService _chatService;

  final String _usernamePlaceholder = 'User';
  String _username = '';
  int _selectedIndex = 0;

  List<ChatHistoryDTO> _chatHistory = [];
  bool _isLoadingHistory = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _avatarService = AvatarService(_storageService);
    _chatService   = ChatService(storageService: _storageService);

    _loadUsername();
    _initializeUserId().then((_) {
      _fetchChatHistory();
      _initializeWebSocket();
    });
  }

  Future<void> _loadUsername() async {
    String? stored = await _storageService.getUsername();
    setState(() {
      _username = stored ?? _usernamePlaceholder;
    });
  }

  Future<void> _initializeUserId() async {
    _currentUserId = await _storageService.getUserId();
  }

  Future<void> _initializeWebSocket() async {
    await _webSocketService.connect();

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
        // Not used on home
          break;
        default:
          LoggerService.logInfo('Unknown WS message type: $type');
      }
    });
  }

  void _handleNewOrUpdatedMessage(Map<String, dynamic> rawMsg) {
    if (_currentUserId == null || !mounted) return;
    _chatService.handleNewOrUpdatedMessage(
      msg: rawMsg,
      currentUserId: _currentUserId!,
      chatHistory: _chatHistory,
    );
    setState(() {});
  }

  void _handleReadReceipt(Map<String, dynamic> data) {
    if (!mounted) return;
    final readerId = data['readerId'] ?? '';
    final List<dynamic> msgIds = data['messageIds'] ?? [];
    final tsStr = data['readTimestamp'] ?? '';
    if (readerId.isEmpty || msgIds.isEmpty || tsStr.isEmpty) return;

    final readAt = DateTime.parse(tsStr);
    setState(() {
      for (var chat in _chatHistory) {
        if (chat.participant == readerId) {
          for (var m in chat.messages) {
            if (msgIds.contains(m.id)) {
              m.isRead = true;
              m.readTimestamp = readAt;
            }
          }
        }
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
      MaterialPageRoute(builder: (ctx) => const SelectUserPage()),
    );
  }

  void _navigateToChat(ChatHistoryDTO chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ChatPage(
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

  Widget _buildChatList() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_chatHistory.isEmpty) {
      return const Center(child: Text('No conversations found'));
    }
    return ListView.builder(
      itemCount: _chatHistory.length,
      itemBuilder: (ctx, i) {
        final chat = _chatHistory[i];
        final lastMsg = chat.messages.isNotEmpty
            ? chat.messages.last
            : null;

        return ListTile(
          leading: FutureBuilder<Uint8List?>(
            future: _fetchAvatar(chat.participant),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircleAvatar(child: CircularProgressIndicator());
              }
              final avatar = snapshot.data;
              if (avatar == null) return const CircleAvatar(child: Icon(Icons.person));
              return CircleAvatar(backgroundImage: MemoryImage(avatar));
            },
          ),
          title: Text(
            chat.participantUsername.isNotEmpty
                ? chat.participantUsername
                : 'User ${chat.participant}',
          ),
          subtitle: (lastMsg != null)
              ? Text(
            // If ephemeral decryption happened, it's in `plaintext`.
            // Fallback to ciphertext if no plaintext is set
            // In _buildChatList() function where the lastMsg's plaintext is displayed
            lastMsg.plaintext?.isNotEmpty ?? false
                ? lastMsg.plaintext ?? ''
                : '[Encrypted]',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
              : const Text('No messages yet'),
          trailing: (chat.unreadCount > 0)
              ? CircleAvatar(
            backgroundColor: Colors.red,
            radius: 10,
            child: Text(
              chat.unreadCount.toString(),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          )
              : null,
          onTap: () => _navigateToChat(chat),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hello, $_username'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _navigateToSelectUser,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _buildChatList(),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}
