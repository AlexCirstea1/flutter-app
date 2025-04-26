import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vaultx_app/services/websocket_service.dart';

import '../models/chat_request_dto.dart';
import '../services/avatar_service.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';
import '../widget/chat_request_card.dart';

class ChatRequestsPage extends StatefulWidget {
  const ChatRequestsPage({super.key});
  @override
  State<ChatRequestsPage> createState() => _ChatRequestsPageState();
}

class _ChatRequestsPageState extends State<ChatRequestsPage> {
  final ChatService _chatService =
  ChatService(storageService: StorageService());
  final AvatarService _avatarService = AvatarService(StorageService());
  final List<ChatRequestDTO> _pending = [];
  bool _isLoading = true;
  late final StreamSubscription<Map<String, dynamic>> _wsSub;

  @override
  void initState() {
    super.initState();
    _loadInitial();

    // realtime push – "chatRequests" queue
    final ws = WebSocketService();
    ws.ensureConnected();
    _wsSub = ws.chatRequests.listen((raw) {
      final dto = ChatRequestDTO.fromJson(raw);
      if (dto.status == ChatRequestStatus.PENDING) {
        setState(() {
          _pending.insert(0, dto);
        });
      }
    });
  }

  Future<void> _loadInitial() async {
    final list = await _chatService.fetchPendingChatRequests();
    if (mounted) {
      setState(() {
        _pending
          ..clear()
          ..addAll(list);
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _wsSub.cancel();
    super.dispose();
  }

  void _decide(ChatRequestDTO req, bool accept) async {
    setState(() {}); // just trigger rebuild before request
    if (accept) {
      await _chatService.acceptChatRequest(requestId: req.id);
    } else {
      await _chatService.rejectChatRequest(requestId: req.id);
    }
    if (mounted) {
      setState(() => _pending.removeWhere((r) => r.id == req.id));
    }
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
        title: Text(
          'SECURE CHAT REQUESTS',
          style: theme.appBarTheme.titleTextStyle,
        ),
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
                    Icon(Icons.shield, size: 14, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'INCOMING CONNECTION REQUESTS',
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
              Expanded(
                child: _isLoading
                    ? Center(
                  child: CircularProgressIndicator(
                    color: colorScheme.secondary,
                  ),
                )
                    : _pending.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.security,
                        size: 50,
                        color: theme.textTheme.bodyMedium?.color
                            ?.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'NO PENDING REQUESTS',
                        style: TextStyle(
                          fontSize: 14,
                          letterSpacing: 1.5,
                          color: theme.textTheme.bodyMedium?.color
                              ?.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'New connection requests will appear here',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodyMedium?.color
                              ?.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pending.length,
                  itemBuilder: (context, index) {
                    return _buildRequestCard(_pending[index]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(ChatRequestDTO dto) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ChatRequestCard(
        dto: dto,
        avatarService: _avatarService,
        onAccept: () async => _decide(dto, true),
        onReject: () async => _decide(dto, false),
      ),
    );
  }
}