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
    final bool isFile = message.ciphertext == '__FILE__';
    final bool isEncrypted = message.plaintext == null || message.plaintext!.isEmpty;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: isEncrypted
              ? (isMine
              ? colorScheme.primary.withOpacity(0.5)
              : colorScheme.tertiary.withOpacity(0.3))
              : (isMine
              ? colorScheme.primary.withOpacity(0.85)
              : colorScheme.tertiary.withOpacity(0.5)),
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
          border: isEncrypted
              ? Border.all(
            color: isMine
                ? colorScheme.primary.withOpacity(0.4)
                : colorScheme.tertiary.withOpacity(0.4),
            width: 1,
          )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isEncrypted)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.lock_outline,
                      size: 14,
                      color: isMine
                          ? colorScheme.onPrimary.withOpacity(0.6)
                          : textTheme.bodyMedium?.color?.withOpacity(0.5),
                    ),
                  ),
                Flexible(
                  child: Text(
                    isFile
                        ? message.plaintext ?? '[File]'
                        : (isEncrypted ? '[Encrypted]' : message.plaintext!),
                    style: TextStyle(
                      color: isEncrypted
                          ? (isMine
                          ? colorScheme.onPrimary.withOpacity(0.6)
                          : textTheme.bodyLarge?.color?.withOpacity(0.5))
                          : (isMine
                          ? colorScheme.onPrimary
                          : textTheme.bodyLarge?.color),
                      fontSize: 15,
                      fontStyle: isEncrypted ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
              ],
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