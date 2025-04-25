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
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Chat requests')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : _pending.isEmpty
              ? Center(
                  child: Text('No pending requests',
                      style: theme.textTheme.bodyLarge))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (_, i) => ChatRequestCard(
                    dto: _pending[i],
                    avatarService: _avatarService,
                    onAccept: () async => _decide(_pending[i], true),
                    onReject: () async => _decide(_pending[i], false),
                  ),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: _pending.length,
                ),
    );
  }
}
