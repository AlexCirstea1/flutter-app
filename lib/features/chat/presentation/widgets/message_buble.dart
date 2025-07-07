import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/message_dto.dart';

class MessageBubble extends StatelessWidget {
  final MessageDTO message;
  final bool isMine;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final Function(MessageDTO)? onDeleteMessage;
  final Function(MessageDTO)? onEditMessage;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.colorScheme,
    required this.textTheme,
    this.onDeleteMessage,
    this.onEditMessage,
  });

  String _formatTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  void _showMessageOptions(BuildContext context) {
    final bool isFile = message.ciphertext == '__FILE__';
    final bool isEncrypted =
        message.plaintext == null || message.plaintext!.isEmpty;
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final List<PopupMenuEntry<String>> menuItems = [];

    // Copy option is available for any decrypted message
    if (!isEncrypted) {
      menuItems.add(
        const PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy, size: 20),
              SizedBox(width: 8),
              Text('Copy'),
            ],
          ),
        ),
      );
    }

    // Edit option only for my text messages that are not encrypted or files
    if (isMine && !isEncrypted && !isFile) {
      menuItems.add(
        const PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 20),
              SizedBox(width: 8),
              Text('Edit'),
            ],
          ),
        ),
      );
    }

    // Delete option available for my messages
    if (isMine) {
      menuItems.add(
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.redAccent, size: 20),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      );
    }

    if (menuItems.isEmpty) return;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + size.width,
        position.dy + size.height,
      ),
      items: menuItems,
    ).then((value) {
      if (value == null) return;

      switch (value) {
        case 'copy':
          if (message.plaintext != null) {
            Clipboard.setData(ClipboardData(text: message.plaintext!));
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Message copied to clipboard')));
          }
          break;
        case 'edit':
          if (onEditMessage != null) {
            onEditMessage!(message);
          }
          break;
        case 'delete':
          if (onDeleteMessage != null) {
            onDeleteMessage!(message);
          }
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isFile =
        message.ciphertext == '__FILE__' || message.file != null;
    final bool isEncrypted =
        message.plaintext == null || message.plaintext!.isEmpty;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(context),
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
                  if (isFile && message.file != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.attach_file,
                        size: 14,
                        color: isMine
                            ? colorScheme.onPrimary.withOpacity(0.8)
                            : textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                  Flexible(
                    child: Text(
                      _getDisplayText(isFile, isEncrypted),
                      style: TextStyle(
                        color: isEncrypted
                            ? (isMine
                                ? colorScheme.onPrimary.withOpacity(0.6)
                                : textTheme.bodyLarge?.color?.withOpacity(0.5))
                            : (isMine
                                ? colorScheme.onPrimary
                                : textTheme.bodyLarge?.color),
                        fontSize: 15,
                        fontStyle:
                            isEncrypted ? FontStyle.italic : FontStyle.normal,
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
      ),
    );
  }

  String _getDisplayText(bool isFile, bool isEncrypted) {
    if (isFile) {
      if (message.file != null) {
        return message.plaintext ?? '[File] ${message.file!.fileName}';
      }
      return message.plaintext ?? '[File]';
    }
    return isEncrypted ? '[Encrypted]' : message.plaintext!;
  }
}
