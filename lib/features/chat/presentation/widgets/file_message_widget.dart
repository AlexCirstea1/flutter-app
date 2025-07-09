import 'package:flutter/material.dart';
import 'dart:io';
import '../../../../core/config/logger_config.dart';
import '../../data/services/file_download_service.dart';
import '../../data/services/file_validation_service.dart';
import '../../domain/models/message_dto.dart';
import '../../../../core/data/services/service_locator.dart';

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

  void _showFileOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.verified),
              title: const Text('Validate File'),
              onTap: () {
                Navigator.pop(context);
                _validateFile(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _validateFile(BuildContext context) async {
    LoggerService.logInfo('[UI] validateFile — tapped');
    final status = ValueNotifier<String>('Preparing…');

    final fileValidationService = serviceLocator<FileValidationService>();
    final downloadService = serviceLocator<FileDownloadService>();

    final rootNavigator = Navigator.of(context, rootNavigator: true);

    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: status,
                builder: (_, value, __) => Text(value),
              ),
            ),
          ],
        ),
      ),
    );

    Future<void> closeSpinner() async {
      if (rootNavigator.canPop()) {
        rootNavigator.pop();
      }
    }

    try {
      status.value = 'Downloading file…';
      LoggerService.logInfo('[UI] start download');
      final file = await downloadService.downloadAndDecryptFile(
        message: message,
        onProgress: (p) => LoggerService.logInfo('[UI] download p=$p'),
        onError: (err) async {
          LoggerService.logError('[UI] download error: $err');
          await closeSpinner();
          if (context.mounted) {
            _showValidationResult(context, null, err);
          }
        },
      );
      LoggerService.logInfo('[UI] download done → ${file?.path}');

      if (file == null || message.file?.fileId == null) {
        throw 'Unable to download file for validation';
      }

      status.value = 'Validating file…';
      LoggerService.logInfo('[UI] call validateFile');
      final result = await fileValidationService.validateFile(
        fileId: message.file!.fileId,
        file: file,
      );
      LoggerService.logInfo('[UI] validateFile returned isValid=${result?.isValid}');

      await closeSpinner();
      if (context.mounted) {
        _showValidationResult(context, result, null);
      }
    } catch (e, st) {
      LoggerService.logError('[UI] validateFile exception: $e\n$st');
      await closeSpinner();
      if (context.mounted) {
        _showValidationResult(context, null, e.toString());
      }
    } finally {
      status.dispose();
    }
  }

  void _showValidationResult(
      BuildContext context,
      FileValidationResponse? result,
      String? error,
      ) {
    // Use root navigator and delay push until spinner is fully closed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => ValidationResultScreen(
            result: result,
            error: error,
          ),
          fullscreenDialog: true,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

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
      child: GestureDetector(
        onLongPress: () => _showFileOptions(context),
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
                    style:
                    const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ValidationResultScreen extends StatelessWidget {
  final FileValidationResponse? result;
  final String? error;

  const ValidationResultScreen({
    Key? key,
    this.result,
    this.error,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final title = error != null
        ? 'Validation Error'
        : (result?.isValid == true ? 'File is Valid' : 'File is Invalid');
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: error != null
            ? Center(
          child: Text(
            error!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result!.message, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            Text('Blockchain Hash:', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(result!.blockchainHash),
            const SizedBox(height: 8),
            Text('Current Hash:', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(result!.currentHash),
            const SizedBox(height: 12),
            Text('Uploaded:', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              DateTime.fromMillisecondsSinceEpoch(
                  result!.uploadTimestamp * 1000)
                  .toLocal()
                  .toString(),
            ),
            const SizedBox(height: 12),
            Text('Validity:', style: const TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Icon(
                  result!.isValid ? Icons.check_circle : Icons.error,
                  color: result!.isValid ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  result!.isValid ? 'Valid' : 'Invalid',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: result!.isValid ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
