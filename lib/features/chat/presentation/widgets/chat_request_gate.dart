import 'package:flutter/material.dart';

import '../../data/services/chat_service.dart';
import '../widgets/chat_request_widget.dart';

class ChatRequestGate extends StatelessWidget {
  final String chatUserId;
  final String recipientUsername;
  final bool chatRequestSent;
  final ChatService chatService;
  final Function() onRequestSent;

  const ChatRequestGate({
    super.key,
    required this.chatUserId,
    required this.recipientUsername,
    required this.chatRequestSent,
    required this.chatService,
    required this.onRequestSent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? cs.surface.withOpacity(0.9)
            : cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.primary.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(cs),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ChatRequestWidget(
              recipientUsername: recipientUsername,
              requestSent: chatRequestSent,
              onSendRequest: (String message) async {
                await chatService.sendChatRequest(
                  chatUserId: chatUserId,
                  content: message,
                );

                onRequestSent();
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Request sent – waiting for approval'))
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.08),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.enhanced_encryption,
            color: cs.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            'SECURE CONNECTION REQUEST',
            style: TextStyle(
              color: cs.primary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
            ),
          ),
          const Spacer(),
          if (chatRequestSent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: cs.primary,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'SENT',
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}