import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/environment.dart';
import '../config/logger_config.dart';
import '../models/chat_history_dto.dart';
import '../models/message_dto.dart';
import '../pages/chat_page.dart';
import '../pages/select_user_page.dart';
import '../services/auth_service.dart';
import '../services/avatar_service.dart';  // <--- import your AvatarService
import '../services/storage_service.dart';
import '../services/websocket_service.dart';
import '../widget/bottom_nav_bar.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final StorageService _storageService = StorageService();
  final AuthService _authService = AuthService();
  final WebSocketService _webSocketService = WebSocketService();

  // Create an AvatarService to fetch & cache avatars
  late AvatarService _avatarService;

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

    _loadUsername();
    _initializeUserId();
    _fetchChatHistory();
    _initializeWebSocket();
  }

  Future<void> _loadUsername() async {
    String? storedUsername = await _storageService.getUsername();
    setState(() {
      _username = storedUsername ?? _usernamePlaceholder;
    });
  }

  Future<void> _initializeUserId() async {
    _currentUserId = await _storageService.getUserId();
  }

  Future<void> _initializeWebSocket() async {
    await _webSocketService.connect();

    // Listen to all incoming WS messages
    _webSocketService.messages.listen((message) {
      final String type = message['type'] ?? '';
      switch (type) {
        case 'INCOMING_MESSAGE':
        case 'SENT_MESSAGE':
          _handleNewOrUpdatedMessage(message);
          break;
        case 'READ_RECEIPT':
          _handleReadReceipt(message);
          break;
        case 'USER_SEARCH_RESULTS':
        // Not handled here on home screen
          break;
        default:
          LoggerService.logInfo('Unknown message type received: $type');
      }
    });

    // Watch connection status
    _webSocketService.connectionStatus.listen((isConnected) {
      if (!isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WebSocket disconnected')),
        );
      } else {
        LoggerService.logInfo('WebSocket connected/reconnected');
      }
    });
  }

  /// Handle new or updated message from WS
  void _handleNewOrUpdatedMessage(Map<String, dynamic> msg) {
    final String sender = msg['sender'] ?? '';
    final String recipient = msg['recipient'] ?? '';
    if (sender.isEmpty || recipient.isEmpty) return;

    String? userId = _currentUserId;
    if (userId == null) return;

    // "otherParticipant" is who I'm chatting with
    final otherParticipant = (userId == sender) ? recipient : sender;

    setState(() {
      // 1) Find existing chat
      final existingIndex = _chatHistory.indexWhere(
            (c) => c.participant == otherParticipant,
      );

      // 2) Construct new message
      final newMessage = MessageDTO(
        id: msg['id']?.toString() ?? '',
        sender: sender,
        recipient: recipient,
        content: msg['content']?.toString() ?? '',
        timestamp: DateTime.parse(
          msg['timestamp'] ?? DateTime.now().toIso8601String(),
        ),
        isRead: msg['read'] ?? false,
        readTimestamp: msg['readTimestamp'] != null
            ? DateTime.parse(msg['readTimestamp'])
            : null,
      );

      // 3) If no chat, create one
      if (existingIndex < 0) {
        final newChat = ChatHistoryDTO(
          participant: otherParticipant,
          participantUsername: otherParticipant,
          messages: [newMessage],
          unreadCount: (newMessage.sender != userId && !newMessage.isRead)
              ? 1
              : 0,
        );
        _chatHistory.insert(0, newChat);
      } else {
        // 4) Update existing chat
        final chat = _chatHistory[existingIndex];

        // Insert or update the message
        final oldIndex = chat.messages.indexWhere((m) => m.id == newMessage.id);
        if (oldIndex >= 0) {
          chat.messages[oldIndex] = newMessage;
        } else {
          chat.messages.add(newMessage);
        }

        // Recalc unread if I'm the recipient
        if (newMessage.recipient == userId && !newMessage.isRead) {
          chat.unreadCount++;
        }

        chat.messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        // Move this chat to top
        _chatHistory.removeAt(existingIndex);
        _chatHistory.insert(0, chat);
      }
    });
  }

  /// Handle read receipts from server
  void _handleReadReceipt(Map<String, dynamic> data) {
    final String readerId = data['readerId'] ?? '';
    final List<dynamic> msgIds = data['messageIds'] ?? [];
    final String tsStr = data['readTimestamp'] ?? '';
    if (readerId.isEmpty || msgIds.isEmpty || tsStr.isEmpty) return;

    final DateTime readAt = DateTime.parse(tsStr);
    setState(() {
      for (var chat in _chatHistory) {
        if (chat.participant == readerId) {
          for (var msg in chat.messages) {
            if (msgIds.contains(msg.id)) {
              msg.isRead = true;
              msg.readTimestamp = readAt;
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

  /// Fetch entire chat history from /api/chats
  Future<void> _fetchChatHistory() async {
    if (!mounted) return;
    setState(() => _isLoadingHistory = true);

    final accessToken = await _storageService.getAccessToken();
    if (accessToken == null) {
      LoggerService.logError('Access token not found');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access token not found')),
      );
      setState(() => _isLoadingHistory = false);
      return;
    }

    LoggerService.logInfo("Fetching chat history...");
    final url = Uri.parse('${Environment.apiBaseUrl}/chats');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Force UTF-8 decode, then parse
        final rawBody = utf8.decode(response.bodyBytes);
        final List<dynamic> historyJson = jsonDecode(rawBody);

        List<ChatHistoryDTO> fetchedChatHistory = historyJson
            .map((chatJson) => ChatHistoryDTO.fromJson(chatJson))
            .toList();

        // Sort by last message timestamp desc
        fetchedChatHistory.sort((a, b) {
          DateTime aLast = a.messages.isNotEmpty
              ? a.messages.last.timestamp
              : DateTime.fromMillisecondsSinceEpoch(0);
          DateTime bLast = b.messages.isNotEmpty
              ? b.messages.last.timestamp
              : DateTime.fromMillisecondsSinceEpoch(0);
          return bLast.compareTo(aLast);
        });

        if (mounted) {
          setState(() {
            _chatHistory = fetchedChatHistory;
          });
        }

        setState(() {
          _chatHistory = fetchedChatHistory;
        });

      } else {
        LoggerService.logError(
          'Failed to fetch chat history. Status code: ${response.statusCode}',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to fetch chat history.')),
        );
      }
    } catch (e) {
      LoggerService.logError('Failed to fetch chat history', e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred while fetching chat history.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  Future<void> _logout() async {
    String? accessToken = await _storageService.getAccessToken();
    if (accessToken != null) {
      bool success = await _authService.logout(accessToken);
      if (success) {
        await _storageService.clearLoginDetails();
        _webSocketService.disconnect();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    }
  }

  void _navigateToSelectUser() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SelectUserPage()),
    ).then((value) => _fetchChatHistory());
  }

  void _navigateToChat(ChatHistoryDTO chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          chatUserId: chat.participant,
          chatUsername: chat.participantUsername,
        ),
      ),
    ).then((value) => _fetchChatHistory());
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // ----------------------------
  // AVATAR-RELATED LOGIC
  // ----------------------------
  // We can store a local map if you prefer, or rely solely on AvatarService's internal cache.

  Future<Uint8List?> _fetchAvatar(String userId) async {
    return await _avatarService.getAvatar(userId);
  }

  Widget _buildChatList() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_chatHistory.isEmpty) {
      return const Center(child: Text('No previous chats.'));
    }

    return ListView.builder(
      itemCount: _chatHistory.length,
      itemBuilder: (context, index) {
        final chat = _chatHistory[index];
        final latestMessage = chat.messages.isNotEmpty ? chat.messages.last : null;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 16.0,
            ),
            leading: FutureBuilder<Uint8List?>(
              future: _fetchAvatar(chat.participant),
              builder: (context, snapshot) {
                final avatarBytes = snapshot.data;
                if (snapshot.connectionState == ConnectionState.waiting) {
                  // We can show a placeholder while loading
                  return const CircleAvatar(
                    radius: 24,
                    child: Icon(Icons.person),
                  );
                } else if (avatarBytes != null) {
                  // We have the avatar
                  return CircleAvatar(
                    radius: 24,
                    backgroundImage: MemoryImage(avatarBytes),
                  );
                } else {
                  // If no avatar, show fallback
                  return CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      chat.participantUsername.isNotEmpty
                          ? chat.participantUsername[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  );
                }
              },
            ),
            title: Text(
              chat.participantUsername,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: (latestMessage != null)
                ? Text(
              latestMessage.content.length > 50
                  ? "${latestMessage.content.substring(0, 50)}..."
                  : latestMessage.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            )
                : const Text(
              'No messages yet.',
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (latestMessage != null)
                  Text(
                    _formatTimestamp(latestMessage.timestamp),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                if (chat.unreadCount > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 4.0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 2.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Text(
                      chat.unreadCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
            onTap: () => _navigateToChat(chat),
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    // e.g. "Jan 19, 2025 14:05"
    return "${_getMonthAbbreviation(dateTime.month)} ${dateTime.day}, ${dateTime.year} "
        "${_formatTwoDigits(dateTime.hour)}:${_formatTwoDigits(dateTime.minute)}";
  }

  String _getMonthAbbreviation(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  String _formatTwoDigits(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, $_username'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.search),
          onPressed: _navigateToSelectUser,
          tooltip: 'Start a New Chat',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchChatHistory,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Expanded(child: _buildChatList()),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
