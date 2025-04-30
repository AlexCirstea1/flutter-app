import 'package:flutter/material.dart';

import '../../domain/models/message_dto.dart';

class MessageBubble extends StatelessWidget {
  final MessageDTO message;
  final bool isMine;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.colorScheme,
    required this.textTheme,
  });

  String _formatTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: isMine
              ? colorScheme.primary.withOpacity(0.85)
              : colorScheme.tertiary.withOpacity(0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 0),
            bottomRight: Radius.circular(isMine ? 0 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.plaintext ?? '[Encrypted]',
              style: TextStyle(
                color: isMine
                    ? colorScheme.onPrimary
                    : textTheme.bodyLarge?.color,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.oneTime)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.timer,
                      size: 12,
                      color: isMine
                          ? colorScheme.onPrimary.withOpacity(0.7)
                          : textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    color: isMine
                        ? colorScheme.onPrimary.withOpacity(0.7)
                        : textTheme.bodyMedium?.color?.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
                if (isMine)
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 16,
                    color: isMine
                        ? colorScheme.onPrimary.withOpacity(0.7)
                        : textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}