import 'package:flutter/material.dart';

import '../../domain/models/message_dto.dart';

class FileMessageWidget extends StatelessWidget {
  final MessageDTO message;
  final String? currentUserId;
  final bool isOwn;
  final Function(MessageDTO) onDownload;

  const FileMessageWidget({
    super.key,
    required this.message,
    this.currentUserId,
    required this.isOwn,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Extract filename from plaintext (which starts with '[File] ')
    final filename = message.plaintext?.replaceFirst('[File] ', '') ?? 'File';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isOwn ? cs.primary : cs.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insert_drive_file,
            color: isOwn ? cs.onPrimary : cs.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              filename,
              style: TextStyle(
                color: isOwn ? cs.onPrimary : cs.onSurface,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(
              Icons.download,
              color: isOwn ? cs.onPrimary : cs.primary,
              size: 20,
            ),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
            onPressed: () => onDownload(message),
            tooltip: 'Download',
          ),
        ],
      ),
    );
  }
}
