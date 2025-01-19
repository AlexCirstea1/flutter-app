import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/environment.dart';
import '../config/logger_config.dart';
import '../models/chat_history_dto.dart';
import '../pages/chat_page.dart';
import '../pages/select_user_page.dart';
import '../services/auth_service.dart';
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
  final String _usernamePlaceholder = 'User';
  String _username = '';
  int _selectedIndex = 0;

  List<ChatHistoryDTO> _chatHistory = [];
  bool _isLoadingHistory = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _initializeUserId();
    _fetchChatHistory();
    _initializeWebSocket();
  }

  Future<void> _initializeUserId() async {
    _currentUserId = await _storageService.getUserId();
  }

  Future<void> _loadUsername() async {
    String? storedUsername = await _storageService.getUsername();
    setState(() {
      _username = storedUsername ?? _usernamePlaceholder;
    });
  }

  Future<void> _logout() async {
    String? accessToken = await _storageService.getAccessToken();
    if (accessToken != null) {
      bool success = await _authService.logout(accessToken);
      if (success) {
        await _storageService.clearLoginDetails();
        _webSocketService
            .disconnect(); // Ensure WebSocket is disconnected on logout
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _initializeWebSocket() async {
    await _webSocketService.connect();

    _webSocketService.messages.listen((message) {
      final String type = message['type'] ?? '';
      switch (type) {
        case 'NEW_CHAT_MESSAGE':
          _fetchChatHistory();
          break;
        case 'READ_RECEIPT':
          _handleReadReceipt(message);
          break;
        // Handle other message types if needed
        default:
          LoggerService.logInfo('Unknown message type received: $type');
      }
    });

    _webSocketService.connectionStatus.listen((isConnected) {
      if (!isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WebSocket disconnected')));
      } else {
        LoggerService.logInfo('WebSocket reconnected');
      }
    });
  }

  void _handleReadReceipt(Map<String, dynamic> message) {
    if (_currentUserId == null) return;
    // Parse the read receipt notification
    // Expected structure: { "type": "READ_RECEIPT", "readerId": "...", "messageIds": [...], "readTimestamp": "..." }

    final String readerId = message['readerId'] ?? '';
    final List<dynamic> messageIds = message['messageIds'] ?? [];
    final String readTimestampStr = message['readTimestamp'] ?? '';
    final DateTime readTimestamp = readTimestampStr.isNotEmpty
        ? DateTime.parse(readTimestampStr)
        : DateTime.now();

    setState(() {
      for (var chat in _chatHistory) {
        if (chat.participant == readerId) {
          // Update messages in this chat
          for (var msg in chat.messages) {
            if (messageIds.contains(msg.id)) {
              msg.isRead = true;
              msg.readTimestamp = readTimestamp;
            }
          }

          // Recalculate unreadCount
          chat.unreadCount = chat.messages
              .where((m) =>
                  m.recipient == _currentUserId &&
                  m.sender == readerId &&
                  !m.isRead)
              .length;
        }
      }
    });
  }

  Future<void> _fetchChatHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });

    final accessToken = await _storageService.getAccessToken();
    if (accessToken == null) {
      LoggerService.logError('Access token not found');
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access token not found')));
      setState(() {
        _isLoadingHistory = false;
      });
      return;
    }

    LoggerService.logInfo("Fetching chat history for User ID");

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
        final List<dynamic> historyJson = jsonDecode(response.body);
        List<ChatHistoryDTO> fetchedChatHistory = historyJson
            .map((chatJson) => ChatHistoryDTO.fromJson(chatJson))
            .toList();

        // Sort the fetchedChatHistory based on last message timestamp descending
        fetchedChatHistory.sort((a, b) {
          DateTime aLast = a.messages.isNotEmpty
              ? a.messages.last.timestamp
              : DateTime.fromMillisecondsSinceEpoch(0);
          DateTime bLast = b.messages.isNotEmpty
              ? b.messages.last.timestamp
              : DateTime.fromMillisecondsSinceEpoch(0);
          return bLast.compareTo(aLast);
        });

        LoggerService.logInfo(
            "Fetched and sorted ${fetchedChatHistory.length} chats from history.");

        setState(() {
          _chatHistory = fetchedChatHistory;
        });
      } else {
        LoggerService.logError(
            'Failed to fetch chat history. Status code: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to fetch chat history.')));
      }
    } catch (e) {
      LoggerService.logError('Failed to fetch chat history', e);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('An error occurred while fetching chat history.')));
    } finally {
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  void _navigateToSelectUser() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SelectUserPage()),
    ).then((value) {
      _fetchChatHistory();
    });
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
    ).then((value) {
      _fetchChatHistory();
    });
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
        final latestMessage =
            chat.messages.isNotEmpty ? chat.messages.last : null;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                chat.participantUsername.isNotEmpty
                    ? chat.participantUsername[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            title: Text(
              chat.participantUsername,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: latestMessage != null
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
                    _formatTimestamp(latestMessage.timestamp.toIso8601String()),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                if (chat.unreadCount > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 4.0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 2.0),
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

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    DateTime dateTime = DateTime.parse(timestamp).toLocal();
    return "${_getMonthAbbreviation(dateTime.month)} ${dateTime.day}, ${dateTime.year} ${_formatTwoDigits(dateTime.hour)}:${_formatTwoDigits(dateTime.minute)}";
  }

  String _getMonthAbbreviation(int month) {
    const List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  String _formatTwoDigits(int n) {
    return n.toString().padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, $_username'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.chat),
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
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.background,
              Theme.of(context).colorScheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _fetchChatHistory,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Expanded(
                  child: _buildChatList(),
                ),
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
