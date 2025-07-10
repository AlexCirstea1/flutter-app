import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/config/logger_config.dart';
import '../../../../core/data/services/data_preload_service.dart';
import '../../../../core/data/services/service_locator.dart';
import '../../../../core/data/services/storage_service.dart';
import '../../../../core/data/services/websocket_service.dart';
import '../../../../core/widget/bottom_nav_bar.dart';
import '../../../../main.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../chat/data/services/chat_service.dart';
import '../../../chat/domain/models/chat_history_dto.dart';
import '../../../chat/presentation/pages/chat_page.dart';
import '../../../chat/presentation/pages/chat_request_page.dart';
import '../../../chat/presentation/pages/select_user_page.dart';
import '../../../profile/data/services/avatar_service.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with RouteAware {
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  final StorageService _storageService = StorageService();
  final AuthService _authService = serviceLocator<AuthService>();
  final WebSocketService _webSocketService = WebSocketService();
  final DataPreloadService _preloadService = serviceLocator<DataPreloadService>();

  late final AvatarService _avatarService =
      AvatarService(serviceLocator<StorageService>());
  late final ChatService _chatService = serviceLocator<ChatService>();

  final String _usernamePlaceholder = 'User';
  String _username = '';
  Uint8List? _userAvatar;
  int _selectedIndex = 0;
  int _pendingRequestsCount = 0;
  bool _isLoadingRequests = false;

  List<ChatHistoryDTO> _chatHistory = [];
  bool _isLoadingHistory = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _initializeUserId().then((_) {
      // Check if data is already preloaded
      if (_preloadService.isPreloadComplete) {
        // Just load from cache
        _fetchChatHistory(useCache: true);
        _fetchPendingRequestsCount(useCache: true);
      } else {
        // Fall back to regular loading
        _fetchChatHistory();
        _fetchPendingRequestsCount();
      }

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

  @override
  void didPopNext() {
    // When the user navigates back to the home page, refresh the chat history.
    _fetchChatHistory();
    _fetchPendingRequestsCount();
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

  Future<void> _handleNewOrUpdatedMessage(Map<String, dynamic> rawMsg) async {
    if (_currentUserId == null || !mounted) return;

    await _chatService.handleIncomingOrSentMessage(
      rawMsg,
      _currentUserId!,
      () => setState(() {}),
      markReadOnReceive: false,
    );

    await _fetchChatHistory();
  }

  void _markAllAsReadStomp() {
    final unread = _chatService.messages
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

  Future<void> _fetchChatHistory({bool useCache = false}) async {
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

  Future<void> _fetchPendingRequestsCount({bool useCache = false}) async {
    if (_isLoadingRequests) return;

    setState(() => _isLoadingRequests = true);
    try {
      final requests = await _chatService.fetchPendingChatRequests();
      setState(() {
        _pendingRequestsCount = requests.length;
      });
    } catch (e) {
      LoggerService.logError('Error fetching chat requests', e);
    } finally {
      setState(() => _isLoadingRequests = false);
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

  void _navigateToChatRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatRequestsPage()),
    ).then((_) {
      _fetchPendingRequestsCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _buildUserAvatar(),
        title: Text(
          'SECURE MESSAGING',
          style: theme.appBarTheme.titleTextStyle,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: colorScheme.primary),
            onPressed: _navigateToSelectUser,
          ),
          IconButton(
            icon: Icon(Icons.logout, color: colorScheme.primary),
            onPressed: _logout,
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.surface,
            ],
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
                    Icon(Icons.security, size: 14, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'WELCOME, ${_username.toUpperCase()}',
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
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
                child: Divider(
                    color: colorScheme.primary.withOpacity(0.1), height: 1),
              ),
              // Chat requests section
              InkWell(
                onTap: _navigateToChatRequests,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _pendingRequestsCount > 0
                          ? colorScheme.primary.withOpacity(0.5)
                          : colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.connect_without_contact,
                            color: _pendingRequestsCount > 0
                                ? colorScheme.primary
                                : theme.textTheme.bodyMedium?.color,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'CONNECTION REQUESTS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.0,
                              color: _pendingRequestsCount > 0
                                  ? colorScheme.primary
                                  : theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                      if (_isLoadingRequests)
                        SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.secondary,
                          ),
                        )
                      else if (_pendingRequestsCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: colorScheme.primary.withOpacity(0.3)),
                          ),
                          child: Text(
                            '$_pendingRequestsCount',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.secondary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(child: _buildChatList(theme, colorScheme)),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border:
              Border.all(color: colorScheme.primary.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: _userAvatar != null
            ? CircleAvatar(backgroundImage: MemoryImage(_userAvatar!))
            : CircleAvatar(
                backgroundColor: colorScheme.surface,
                child: Icon(Icons.person, color: colorScheme.primary)),
      ),
    );
  }

  Widget _buildChatList(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoadingHistory) {
      return Center(
        child: CircularProgressIndicator(color: colorScheme.secondary),
      );
    }

    if (_chatHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock,
                size: 50,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'NO CONVERSATIONS YET',
              style: TextStyle(
                fontSize: 14,
                letterSpacing: 1.5,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a new secure conversation',
              style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
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
          final timestamp = lastMsg!.timestamp;
          final difference = now.difference(timestamp);

          if (difference.inDays > 0) {
            timeString =
                '${timestamp.day}/${timestamp.month}/${timestamp.year}';
          } else {
            timeString =
                '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
          }
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: colorScheme.surface,
          elevation: 4, // stronger shadow for better separation
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: _buildChatAvatar(chat.participant, theme, colorScheme),
            title: Row(
              children: [
                Text(
                  chat.participantUsername.isNotEmpty
                      ? chat.participantUsername.toUpperCase()
                      : 'USER-${chat.participant.substring(0, 6)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(width: 8),
                if (chat.unreadCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      '${chat.unreadCount}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.secondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (lastMsg?.ciphertext == '__FILE__' ||
                          lastMsg?.file != null) ...[
                        Icon(Icons.insert_drive_file,
                            size: 16,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.7)),
                        const SizedBox(width: 4),
                        Text(
                          'File',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color,
                            fontSize: 12,
                          ),
                        ),
                      ] else ...[
                        Text(
                          (lastMsg?.plaintext?.isNotEmpty ?? false)
                              ? lastMsg!.plaintext!
                              : '[ENCRYPTED]',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color,
                            fontSize: 12,
                            fontFamily:
                                lastMsg?.plaintext == null ? 'monospace' : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (timeString.isNotEmpty)
                  Text(
                    timeString,
                    style: TextStyle(
                      color:
                          theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                      fontSize: 10,
                      fontFamily: 'monospace',
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

  Widget _buildChatAvatar(
      String userId, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border:
            Border.all(color: colorScheme.primary.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.05),
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
            backgroundColor: colorScheme.surface.withOpacity(0.8),
            backgroundImage: snap.hasData ? MemoryImage(snap.data!) : null,
            child: snap.connectionState == ConnectionState.waiting
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.secondary,
                    ),
                  )
                : snap.hasData
                    ? null
                    : Icon(Icons.person, color: colorScheme.primary, size: 20),
          );
        },
      ),
    );
  }
}
