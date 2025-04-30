import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../../core/config/environment.dart';
import '../../../../core/config/logger_config.dart';
import '../../../../core/data/services/service_locator.dart';
import '../../../../core/data/services/storage_service.dart';
import '../../../../core/data/services/websocket_service.dart';
import '../../data/services/chat_service.dart';
import '../../domain/models/message_dto.dart';
import '../widgets/chat_app_bar.dart';
import '../widgets/chat_background.dart';
import '../widgets/chat_input.dart';
import '../widgets/chat_message_list.dart';
import '../widgets/chat_request_gate.dart';
import '../widgets/locked_chat_input.dart';

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
  bool _chatAuthorized = false;
  bool _chatRequestSent = false;

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
  final bool _isEphemeral = false;

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
      if (token == null) return;

      // Check if the current user has blocked the chat partner
      final youBlocked = Uri.parse(
          '${Environment.apiBaseUrl}/user/block/${widget.chatUserId}/status');
      final youBlockedResponse = await http.get(
        youBlocked,
        headers: {'Authorization': 'Bearer $token'},
      );

      // Check if the chat partner has blocked the current user
      final theyBlockedYou = Uri.parse(
          '${Environment.apiBaseUrl}/user/blockedBy/${widget.chatUserId}/status');
      final theyBlockedYouResponse = await http.get(
        theyBlockedYou,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (mounted) {
        setState(() {
          _isBlocked = youBlockedResponse.statusCode == 200 &&
              jsonDecode(youBlockedResponse.body) == true;
          _amIBlocked = theyBlockedYouResponse.statusCode == 200 &&
              jsonDecode(theyBlockedYouResponse.body) == true;
        });
      }
    } catch (e) {
      LoggerService.logError('Error checking block status', e);
    }
  }

  Future<void> _toggleBlock() async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final action = _isBlocked ? 'Unblock' : 'Block';
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('$action User'),
            content: Text(
                'Are you sure you want to ${_isBlocked ? 'unblock' : 'block'} this user?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('CANCEL')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(action.toUpperCase(),
                    style:
                        TextStyle(color: _isBlocked ? cs.primary : cs.error)),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    setState(() => _isInitializing = true);
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) throw Exception('Not authenticated');

      final uri = Uri.parse(
          '${Environment.apiBaseUrl}/user/block/${widget.chatUserId}');
      final resp = _isBlocked
          ? await http.delete(uri, headers: {'Authorization': 'Bearer $token'})
          : await http.post(uri, headers: {'Authorization': 'Bearer $token'});

      if (resp.statusCode == 200) {
        setState(() => _isBlocked = !_isBlocked);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('User ${_isBlocked ? 'blocked' : 'unblocked'}')));
      } else {
        throw Exception('Failed (${resp.statusCode})');
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() => _isInitializing = false);
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

      _chatAuthorized = _chatService.messages.isNotEmpty;

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
              setState(() => _chatAuthorized = true);
            }
            break;
          case 'CHAT_REQUEST':
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
      oneTime: _isEphemeral,
      onEphemeralAdded: (MessageDTO ephemeral) {
        setState(() {
          _messages.add(ephemeral);
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        });
      },
      stompSend: (map) => ws.sendMessage('/app/sendPrivateMessage', map),
    );
  }

  void _sendFileMessage(String path, String type, {required String filename}) {
    // Implement file sending functionality
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: ChatAppBar(
        chatUserId: widget.chatUserId,
        chatUsername: widget.chatUsername,
        cs: cs,
        theme: theme,
        onBlockStatusChanged: () {
          _checkBlockStatus();
        },
      ),
      body: ChatBackground(
        child: Column(
          children: [
            if (!_chatAuthorized)
              ChatRequestGate(
                chatUserId: widget.chatUserId,
                recipientUsername: widget.chatUsername,
                chatRequestSent: _chatRequestSent,
                chatService: _chatService,
                onRequestSent: () {
                  if (mounted) setState(() => _chatRequestSent = true);
                },
              ),
            Expanded(
              child: _isInitializing || _isFetchingHistory
                  ? Center(
                      child: CircularProgressIndicator(color: cs.secondary),
                    )
                  : _chatAuthorized
                      ? ChatMessagesList(
                          messages: _messages,
                          currentUserId: _currentUserId,
                          isLoading: false,
                          scrollController: _itemScrollController,
                          positionsListener: _itemPositionsListener,
                        )
                      : const SizedBox.shrink(),
            ),
            Divider(height: 1, color: cs.onSurface.withOpacity(0.2)),
            _chatAuthorized
                ? ChatInputWidget(
                    controller: _messageController,
                    isBlocked: _isBlocked,
                    amIBlocked: _amIBlocked,
                    isCurrentUserAdmin: _isCurrentUserAdmin,
                    isChatPartnerAdmin: _isChatPartnerAdmin,
                    onSendMessage: _sendMessage,
                    onSendFile: (path, type, {required filename}) {
                      _sendFileMessage(path, type, filename: filename);
                    },
                  )
                : LockedChatInput(
                    onTap: () {
                      // Optional: scroll to the request widget
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
