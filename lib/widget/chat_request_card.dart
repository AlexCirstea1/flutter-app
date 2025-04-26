import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/environment.dart';
import '../config/logger_config.dart';
import '../models/chat_request_dto.dart';
import '../services/avatar_service.dart';

class ChatRequestCard extends StatefulWidget {
  const ChatRequestCard({
    super.key,
    required this.dto,
    required this.avatarService,
    required this.onAccept,
    required this.onReject,
  });
  final ChatRequestDTO dto;
  final AvatarService avatarService;
  final Future<void> Function() onAccept;
  final Future<void> Function() onReject;

  @override
  State<ChatRequestCard> createState() => _ChatRequestCardState();
}

class _ChatRequestCardState extends State<ChatRequestCard> {
  bool _isProcessing = false;
  String _requesterUsername = '';
  String _message = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _decryptMessage();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _fetchUserData(widget.dto.requester);
      if (userData != null && mounted) {
        setState(() {
          _requesterUsername = userData['username'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      LoggerService.logError('Error loading requester data', e);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchUserData(String userId) async {
    try {
      final url = Uri.parse('${Environment.apiBaseUrl}/user/public/$userId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        LoggerService.logError(
            'Error fetching user data: ${response.statusCode}', null);
      }
    } catch (e) {
      LoggerService.logError('Error fetching user data by ID $userId', e);
    }
    return null;
  }

  Future<void> _decryptMessage() async {
    try {
      // For now, just handle the encrypted message by showing placeholder
      // In a real implementation, this would decrypt the message
      if (widget.dto.ciphertext.isNotEmpty) {
        setState(() {
          _message = "[ENCRYPTED MESSAGE]";
          // In production, you would decrypt:
          // _message = decryptMessageWithPrivateKey(widget.dto.ciphertext, ...);
        });
      }
    } catch (e) {
      LoggerService.logError('Error decrypting message', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: CircularProgressIndicator(color: colorScheme.secondary),
        ),
      );
    }

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.05),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: FutureBuilder<Uint8List?>(
                    future: widget.avatarService.getAvatar(widget.dto.requester),
                    builder: (_, snap) => CircleAvatar(
                      radius: 22,
                      backgroundColor: colorScheme.surface.withOpacity(0.8),
                      backgroundImage:
                      snap.hasData ? MemoryImage(snap.data!) : null,
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
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _requesterUsername.toUpperCase(),
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _ago(widget.dto.timestamp),
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    fontFamily: 'monospace',
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            if (_message.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.1),
                  ),
                ),
                child: Text(
                  _message,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.textTheme.bodyLarge?.color,
                      side: BorderSide(color: colorScheme.primary.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed:
                    _isProcessing ? null : () => _action(widget.onReject),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.close,
                          size: 16,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'DECLINE',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed:
                    _isProcessing ? null : () => _action(widget.onAccept),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check,
                          size: 16,
                          color: colorScheme.onPrimary,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'ACCEPT',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _action(Future<void> Function() task) async {
    setState(() => _isProcessing = true);
    await task();
    if (mounted) setState(() => _isProcessing = false);
  }

  String _ago(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}