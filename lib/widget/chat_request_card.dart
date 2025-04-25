import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/chat_request_dto.dart';
import '../services/avatar_service.dart';

class ChatRequestCard extends StatefulWidget {
  const ChatRequestCard({
    Key? key,
    required this.dto,
    required this.avatarService,
    required this.onAccept,
    required this.onReject,
  }) : super(key: key);
  final ChatRequestDTO dto;
  final AvatarService avatarService;
  final Future<void> Function() onAccept;
  final Future<void> Function() onReject;
  @override
  State<ChatRequestCard> createState() => _ChatRequestCardState();
}

class _ChatRequestCardState extends State<ChatRequestCard> {
  bool _isProcessing = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FutureBuilder<Uint8List?>(
                  future: widget.avatarService.getAvatar(widget.dto.requester),
                  builder: (_, snap) => CircleAvatar(
                    backgroundColor: cs.primary.withOpacity(0.2),
                    backgroundImage:
                        snap.hasData ? MemoryImage(snap.data!) : null,
                    child: snap.connectionState == ConnectionState.waiting
                        ? CircularProgressIndicator(
                            strokeWidth: 2, color: cs.primary)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Incoming request',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  _ago(widget.dto.timestamp),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isProcessing ? null : () => _action(widget.onReject),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _isProcessing ? null : () => _action(widget.onAccept),
                    child: const Text('Accept'),
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
