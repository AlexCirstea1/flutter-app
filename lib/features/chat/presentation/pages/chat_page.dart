import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:uuid/uuid.dart';

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
  final bool _isCurrentUserAdmin = false;
  final bool _isChatPartnerAdmin = false;
  bool _chatAuthorized = false;
  bool _chatRequestSent = false;

  final TextEditingController _messageController = TextEditingController();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

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
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _fetchBlockStatus() async {
    try {
      final storage = StorageService();
      final token = await storage.getAccessToken();
      if (token == null) return;

      final youBlockedResp = await http.get(
        Uri.parse(
            '${Environment.apiBaseUrl}/user/block/${widget.chatUserId}/status'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final theyBlockedResp = await http.get(
        Uri.parse(
            '${Environment.apiBaseUrl}/user/blockedBy/${widget.chatUserId}/status'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (mounted) {
        setState(() {
          _isBlocked = youBlockedResp.statusCode == 200 &&
              jsonDecode(youBlockedResp.body) == true;
          _amIBlocked = theyBlockedResp.statusCode == 200 &&
              jsonDecode(theyBlockedResp.body) == true;
        });
      }
    } catch (e) {
      LoggerService.logError('Block status check failed', e);
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
      await _fetchBlockStatus();
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
          case 'MESSAGE_DELETED':
            final messageId = message['messageId'] as String;
            setState(() {
              _messages.removeWhere((m) => m.id == messageId);
            });
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

  Future<void> _sendFileMessage(String path, String type,
      {required String filename}) async {
    if (_currentUserId == null) return;

    final tempId = const Uuid().v4(); // will become messageId
    final file = File(path);

    final ws = WebSocketService();
    await _chatService.sendFileMessage(
      currentUserId: _currentUserId!,
      chatUserId: widget.chatUserId,
      picked: file,
      fileName: filename.isEmpty ? file.uri.pathSegments.last : filename,
      clientTempId: tempId,
      onLocalEcho: (msg) {
        setState(() {
          _messages.add(msg);
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        });
      },
      onProgress: (p) {
        // TODO: show progress UI if you wish
      },
      stompSend: (Map<String, dynamic> payload) {
        ws.sendMessage('/app/sendPrivateMessage', payload);
      },
    );
  }

  Future<void> _refreshMessages() async {
    await _chatService.fetchChatHistory(
      chatUserId: widget.chatUserId,
      onMessagesUpdated: _onMessagesUpdated,
      forceRefresh: true,
    );
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
          _fetchBlockStatus();
        },
      ),
      body: ChatBackground(
        child: Column(
          children: [
            Expanded(
              child: _isInitializing || _isFetchingHistory
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: cs.secondary),
                          const SizedBox(height: 10),
                          Text(
                            "Securing",
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: cs.secondary),
                          ),
                        ],
                      ),
                    )
                  : _chatAuthorized
                      ? ChatMessagesList(
                          messages: _messages,
                          currentUserId: _currentUserId,
                          isLoading: false,
                          scrollController: _itemScrollController,
                          positionsListener: _itemPositionsListener,
                          onMessageDeleted: (MessageDTO msg) {
                            setState(() {
                              _messages.removeWhere((m) => m.id == msg.id);
                            });
                          },
                          onRefresh: _refreshMessages, // Add this parameter
                        )
                      : ChatRequestGate(
                          chatUserId: widget.chatUserId,
                          recipientUsername: widget.chatUsername,
                          chatRequestSent: _chatRequestSent,
                          chatService: _chatService,
                          onRequestSent: () {
                            if (mounted)
                              setState(() => _chatRequestSent = true);
                          },
                        ),
            ),
            Divider(height: 1, color: cs.onSurface.withOpacity(0.2)),
            if (!_isInitializing)
              _chatAuthorized
                  ? ChatInputWidget(
                      controller: _messageController,
                      isBlocked: _isBlocked,
                      amIBlocked: _amIBlocked,
                      isCurrentUserAdmin: _isCurrentUserAdmin,
                      isChatPartnerAdmin: _isChatPartnerAdmin,
                      onSendMessage: _sendMessage,
                      onSendFile: _sendFileMessage,
                      onEphemeralChanged: (bool value) {
                        setState(() => _isEphemeral = value);
                      },
                    )
                  : LockedChatInput(
                      chatUserId: widget.chatUserId,
                      onRequestTap: () {},
                      onBlockStatusChanged: () => _fetchBlockStatus(),
                    ),
          ],
        ),
      ),
    );
  }
}
