import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/logger_config.dart';

class ChatInputWidget extends StatefulWidget {
  final TextEditingController controller;
  final bool isBlocked;
  final bool amIBlocked;
  final bool isCurrentUserAdmin;
  final bool isChatPartnerAdmin;
  final Function() onSendMessage;
  final Function(String path, String type, {required String filename}) onSendFile;

  const ChatInputWidget({
    super.key,
    required this.controller,
    required this.isBlocked,
    required this.amIBlocked,
    required this.isCurrentUserAdmin,
    required this.isChatPartnerAdmin,
    required this.onSendMessage,
    required this.onSendFile,
  });

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  bool _isEphemeral = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (widget.isBlocked || widget.amIBlocked || widget.isCurrentUserAdmin || widget.isChatPartnerAdmin) {
      final message = widget.isCurrentUserAdmin || widget.isChatPartnerAdmin
          ? 'Messaging disabled for admin accounts.'
          : (widget.isBlocked
          ? 'Unblock to send messages.'
          : widget.amIBlocked
          ? 'You have been blocked by this user.'
          : 'You cannot send messages.');

      return Container(
        color: cs.surface,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Attachment button
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.surface,
                  border: Border.all(
                    color: cs.onSurface.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.attach_file,
                    size: 22,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                  ),
                  tooltip: 'Attach file',
                  onPressed: _showAttachmentOptions,
                ),
              ),
              const SizedBox(width: 8),
              // Ephemeral message toggle with animation
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isEphemeral
                      ? cs.primary.withOpacity(0.2)
                      : cs.surface,
                  border: Border.all(
                    color: _isEphemeral
                        ? cs.primary
                        : cs.onSurface.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.whatshot,
                    size: 22,
                    color: _isEphemeral
                        ? cs.primary
                        : theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                  ),
                  tooltip: 'One-time message',
                  onPressed: () {
                    setState(() => _isEphemeral = !_isEphemeral);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: theme.brightness == Brightness.dark
                        ? cs.surface.withOpacity(0.8)
                        : cs.onPrimary.withOpacity(0.9),
                    border: Border.all(
                      color: cs.primary.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withOpacity(0.1),
                        blurRadius: 4,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: widget.controller,
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: TextStyle(
                        color: theme.textTheme.bodyLarge?.color?.withOpacity(0.5),
                        fontSize: 15,
                      ),
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      prefixIcon: _isEphemeral
                          ? Icon(
                        Icons.whatshot,
                        size: 16,
                        color: cs.primary.withOpacity(0.7),
                      )
                          : null,
                    ),
                    onSubmitted: (_) => widget.onSendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primary,
                      cs.primary.withBlue(min(cs.primary.blue + 30, 255)),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: widget.onSendMessage,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.send_rounded,
                        size: 20,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Attach',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachmentOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromGallery();
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      _takePhoto();
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.insert_drive_file,
                    label: 'Document',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      _pickDocument();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final result = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (result != null) {
        widget.onSendFile(result.path, 'image', filename: '');
      }
    } catch (e) {
      LoggerService.logError('Error picking image', e);
      _showErrorSnackbar('Could not select image');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final result = await ImagePicker().pickImage(source: ImageSource.camera);
      if (result != null) {
        widget.onSendFile(result.path, 'image', filename: '');
      }
    } catch (e) {
      LoggerService.logError('Error taking photo', e);
      _showErrorSnackbar('Could not capture image');
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        widget.onSendFile(result.files.single.path!, 'file',
            filename: result.files.single.name);
      }
    } catch (e) {
      LoggerService.logError('Error picking document', e);
      _showErrorSnackbar('Could not select document');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}