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
    // ... existing implementation unchanged
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
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ValidationPage(message: message),
                    fullscreenDialog: true,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    String fileName = message.file?.fileName ??
        message.plaintext?.replaceFirst('[File] ', '') ??
        'File';
    String displayText = _getFileTypeLabel(fileName, message.file?.mimeType);

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
                  offset: const Offset(0, 2))
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
                    child: Text(displayText,
                        style: tt.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: isOwn ? cs.onPrimary : tt.bodyLarge?.color),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                      icon: Icon(Icons.download,
                          size: 20,
                          color: isOwn
                              ? cs.onPrimary
                              : tt.bodyLarge?.color?.withOpacity(0.7)),
                      padding: EdgeInsets.zero,
                      onPressed: () => onDownload(message),
                      tooltip: 'Download'),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(_formatTime(message.timestamp),
                      style: tt.bodyMedium?.copyWith(
                          color: isOwn
                              ? cs.onPrimary.withOpacity(0.7)
                              : tt.bodyMedium?.color?.withOpacity(0.6),
                          fontSize: 11)),
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
                        color: isOwn ? cs.onPrimary : cs.primary),
                  ),
                ),
              if (downloadError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(downloadError!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ValidationPage extends StatefulWidget {
  final MessageDTO message;
  const ValidationPage({super.key, required this.message});

  @override
  _ValidationPageState createState() => _ValidationPageState();
}

class _ValidationPageState extends State<ValidationPage>
    with TickerProviderStateMixin {
  String status = 'Preparing…';
  FileValidationResponse? result;
  String? error;
  bool loading = true;
  late AnimationController _fadeController;
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _startValidation();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _startValidation() async {
    LoggerService.logInfo('[UI] ValidationPage: start');
    final fileValidationService = serviceLocator<FileValidationService>();

    try {
      setState(() => status = 'Downloading file…');

      setState(() => status = 'Validating file…');
      final res = await fileValidationService.validateFile(
        fileId: widget.message.file!.fileId,
      );

      if (res == null) throw 'Validation service error';

      setState(() {
        result = res;
        loading = false;
      });
      _fadeController.forward();
      _scaleController.forward();
    } catch (e, st) {
      LoggerService.logError('[UI] ValidationPage exception: $e\n$st');
      setState(() {
        error = e.toString();
        loading = false;
      });
      _fadeController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text('File Validation', style: tt.titleLarge),
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child:
              loading ? _buildLoadingState(cs, tt) : _buildResultState(cs, tt),
        ),
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme cs, TextTheme tt) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            status,
            style: tt.titleMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we verify your file',
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultState(ColorScheme cs, TextTheme tt) {
    return FadeTransition(
      opacity: _fadeController,
      child:
          error != null ? _buildErrorState(cs, tt) : _buildSuccessState(cs, tt),
    );
  }

  Widget _buildErrorState(ColorScheme cs, TextTheme tt) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.errorContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.error_outline,
              size: 48,
              color: cs.error,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Validation Failed',
            style: tt.headlineSmall?.copyWith(
              color: cs.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.errorContainer.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.error.withOpacity(0.2)),
            ),
            child: Text(
              error!,
              style: tt.bodyMedium?.copyWith(color: cs.error),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState(ColorScheme cs, TextTheme tt) {
    final isValid = result!.isValid;
    final statusColor = isValid ? Colors.green : cs.error;
    final containerColor = isValid
        ? Colors.green.withOpacity(0.1)
        : cs.errorContainer.withOpacity(0.1);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Header
          ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(
                parent: _scaleController,
                curve: Curves.elasticOut,
              ),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(
                    isValid ? Icons.verified : Icons.error_outline,
                    color: statusColor,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isValid ? 'File Verified' : 'Verification Failed',
                    style: tt.headlineSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result!.message,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Details Section - Only show if data is available
          if (result!.blockchainHash != null) ...[
            _buildDetailCard(
              'Blockchain Hash',
              result!.blockchainHash!,
              Icons.link,
              cs,
              tt,
            ),
            const SizedBox(height: 16),
          ],

          if (result!.currentHash != null) ...[
            _buildDetailCard(
              'Current Hash',
              result!.currentHash!,
              Icons.fingerprint,
              cs,
              tt,
            ),
            const SizedBox(height: 16),
          ],

          if (result!.uploadTimestamp != null) ...[
            _buildDetailCard(
              'Upload Date',
              DateTime.fromMillisecondsSinceEpoch(result!.uploadTimestamp!)
                  .toLocal()
                  .toString()
                  .split('.')[0],
              Icons.schedule,
              cs,
              tt,
            ),
          ],

          // Show message when no blockchain record exists
          if (result!.blockchainHash == null &&
              result!.currentHash == null &&
              result!.uploadTimestamp == null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: cs.onSurfaceVariant,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No Blockchain Record',
                    style: tt.titleMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This file has not been recorded on the blockchain yet.',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailCard(
    String title,
    String content,
    IconData icon,
    ColorScheme cs,
    TextTheme tt,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              content,
              style: tt.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
