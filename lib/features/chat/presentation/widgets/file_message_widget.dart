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

    final filename = message.plaintext?.replaceFirst('[File] ', '') ?? 'File';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isOwn ? cs.primary : cs.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: IntrinsicWidth(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file,
              color: isOwn ? cs.onPrimary : cs.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
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
            const SizedBox(width: 8),
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                icon: Icon(
                  Icons.download,
                  color: isOwn ? cs.onPrimary : cs.primary,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                onPressed: () => onDownload(message),
                tooltip: 'Download',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
