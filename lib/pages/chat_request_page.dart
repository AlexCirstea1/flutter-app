import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/chat_request_dto.dart';
import '../services/avatar_service.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';
import '../config/logger_config.dart';

class ChatRequestsPage extends StatefulWidget {
  const ChatRequestsPage({super.key});

  @override
  State<ChatRequestsPage> createState() => _ChatRequestsPageState();
}

class _ChatRequestsPageState extends State<ChatRequestsPage> {
  final ChatService _chatService =
      ChatService(storageService: StorageService());
  final AvatarService _avatarService = AvatarService(StorageService());

  List<ChatRequestDTO> _requests = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchRequests();

    // Refresh requests every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchRequests();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests = await _chatService.fetchChatRequests();
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      LoggerService.logError('Error fetching chat requests', e);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptRequest(ChatRequestDTO request) async {
    try {
      await _chatService.acceptChatRequest(
        requestId: request.id,
        onAccepted: () {
          setState(() {
            _requests.removeWhere((r) => r.id == request.id);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat request accepted')),
          );
        },
      );
    } catch (e) {
      LoggerService.logError('Error accepting chat request', e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to accept request')),
      );
    }
  }

  Future<void> _rejectRequest(ChatRequestDTO request) async {
    try {
      await _chatService.rejectChatRequest(
        requestId: request.id,
        onRejected: () {
          setState(() {
            _requests.removeWhere((r) => r.id == request.id);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat request rejected')),
          );
        },
      );
    } catch (e) {
      LoggerService.logError('Error rejecting chat request', e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to reject request')),
      );
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
          'SECURE ACCESS REQUESTS',
          style: theme.appBarTheme.titleTextStyle,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: colorScheme.primary),
            onPressed: _fetchRequests,
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
                    Icon(Icons.security,
                        size: 14, color: colorScheme.secondary),
                    const SizedBox(width: 8),
                    Text(
                      'PENDING AUTHORIZATION REQUESTS',
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
              Expanded(child: _buildRequestsList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestsList() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: colorScheme.secondary),
      );
    }

    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock,
                size: 50,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'NO PENDING REQUESTS',
              style: TextStyle(
                fontSize: 14,
                letterSpacing: 1.5,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your secure communications network is clear',
              style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _requests.length,
      itemBuilder: (ctx, i) {
        final request = _requests[i];
        return _buildRequestCard(request);
      },
    );
  }

  Widget _buildRequestCard(ChatRequestDTO request) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: _buildRequestAvatar(request.requester),
            title: Text(
              'INCOMING CONNECTION REQUEST',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.0,
                color: colorScheme.secondary,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'User ID: ${request.requester.substring(0, 8)}...',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Received: ${_formatDate(request.timestamp)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child:
                Divider(color: colorScheme.primary.withOpacity(0.1), height: 1),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _rejectRequest(request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'DENY',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptRequest(request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'ACCEPT',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestAvatar(String userId) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
        future: _avatarService.getAvatar(userId),
        builder: (_, snap) {
          return CircleAvatar(
            radius: 25,
            backgroundColor: colorScheme.surface.withOpacity(0.5),
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
                    : Icon(Icons.person,
                        color: colorScheme.secondary, size: 20),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}
