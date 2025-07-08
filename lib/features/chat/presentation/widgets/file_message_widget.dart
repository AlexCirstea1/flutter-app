import 'package:flutter/material.dart';
import '../../domain/models/message_dto.dart';

class FileMessageWidget extends StatelessWidget {
  final MessageDTO message;
  final bool isOwn;
  final Function(MessageDTO) onDownload;
  final double? downloadProgress;
  final String? downloadError;

  const FileMessageWidget({
    super.key,
    required this.message,
    required this.isOwn,
    required this.onDownload,
    this.downloadProgress,
    this.downloadError,
  });

  String _formatTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _getFileTypeLabel(String fileName, String? mimeType) {
    // Check MIME type first if available
    if (mimeType != null) {
      if (mimeType.startsWith('image/')) return 'Image';
      if (mimeType.startsWith('video/')) return 'Video';
      if (mimeType.startsWith('audio/')) return 'Audio';
      if (mimeType.startsWith('text/')) return 'Document';
      if (mimeType.contains('pdf')) return 'PDF';
      if (mimeType.contains('zip') ||
          mimeType.contains('rar') ||
          mimeType.contains('7z')) {
        return 'Archive';
      }
    }

    // Fall back to file extension
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return 'Image';
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
      case 'webm':
        return 'Video';
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
      case 'm4a':
        return 'Audio';
      case 'pdf':
        return 'PDF';
      case 'doc':
      case 'docx':
      case 'txt':
      case 'rtf':
        return 'Document';
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return 'Archive';
      default:
        return 'File';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Get filename and determine display text
    String fileName;
    String displayText;

    if (message.file?.fileName != null) {
      fileName = message.file!.fileName;
      final fileType = _getFileTypeLabel(fileName, message.file?.mimeType);
      displayText = fileType;
    } else {
      fileName = message.plaintext?.replaceFirst('[File] ', '') ?? 'File';
      final fileType = _getFileTypeLabel(fileName, null);
      displayText = fileType;
    }

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: isOwn
              ? cs.primary.withOpacity(0.85)
              : cs.tertiary.withOpacity(0.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 4,
                offset: const Offset(0, 2)),
          ],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isOwn ? 18 : 0),
            bottomRight: Radius.circular(isOwn ? 0 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insert_drive_file,
                    size: 20,
                    color: isOwn
                        ? cs.onPrimary
                        : tt.bodyLarge?.color?.withOpacity(0.7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayText,
                    style: tt.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isOwn ? cs.onPrimary : tt.bodyLarge?.color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.download,
                      size: 20,
                      color: isOwn
                          ? cs.onPrimary
                          : tt.bodyLarge?.color?.withOpacity(0.7)),
                  padding: EdgeInsets.zero,
                  onPressed: () => onDownload(message),
                  tooltip: 'Download',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: tt.bodyMedium?.copyWith(
                    color: isOwn
                        ? cs.onPrimary.withOpacity(0.7)
                        : tt.bodyMedium?.color?.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
                if (isOwn) ...[
                  const SizedBox(width: 4),
                  Icon(message.isRead ? Icons.done_all : Icons.done,
                      size: 14, color: cs.onPrimary.withOpacity(0.7)),
                ],
              ],
            ),
            if (downloadProgress != null &&
                downloadProgress! > 0 &&
                downloadProgress! < 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    value: downloadProgress,
                    backgroundColor: Colors.grey.shade300,
                    color: isOwn ? cs.onPrimary : cs.primary,
                  ),
                ),
              ),
            if (downloadError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  downloadError!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
