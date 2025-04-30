import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

import '../../../../core/config/logger_config.dart';

class ChatInputWidget extends StatefulWidget {
  final TextEditingController controller;
  final bool isBlocked;
  final bool amIBlocked;
  final bool isCurrentUserAdmin;
  final bool isChatPartnerAdmin;
  final Function() onSendMessage;
  final Function(String path, String type, {required String filename})
      onSendFile;

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
  bool _hasText = false;
  final ValueNotifier<bool> _isDialOpen = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    // Add listener to track text changes
    widget.controller.addListener(_updateTextStatus);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateTextStatus);
    _isDialOpen.dispose();
    super.dispose();
  }

  void _updateTextStatus() {
    final hasText = widget.controller.text.isNotEmpty;
    if (_hasText != hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (widget.isBlocked ||
        widget.amIBlocked ||
        widget.isCurrentUserAdmin ||
        widget.isChatPartnerAdmin) {
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
              // SpeedDial for attachments and ephemeral toggle
              _buildSpeedDial(cs, theme),
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
                      // Add clear button as suffix icon when there's text
                      suffixIcon: _hasText
                          ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          widget.controller.clear();
                        },
                        splashRadius: 16,
                        tooltip: 'Clear message',
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

  Widget _buildSpeedDial(ColorScheme cs, ThemeData theme) {
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      spacing: 3,
      openCloseDial: _isDialOpen,
      elevation: 2,
      renderOverlay: false,
      buttonSize: const Size(46, 46),
      childrenButtonSize: const Size(56, 56),
      backgroundColor: cs.tertiary,
      foregroundColor: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
      overlayColor: Colors.black,
      overlayOpacity: 0.5,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.photo_library, color: Colors.white),
          backgroundColor: Colors.purple,
          labelWidget: _buildLabel('Gallery'),
          onTap: _pickImageFromGallery,
        ),
        SpeedDialChild(
          child: const Icon(Icons.camera_alt, color: Colors.white),
          backgroundColor: Colors.blue,
          labelWidget: _buildLabel('Camera'),
          onTap: _takePhoto,
        ),
        SpeedDialChild(
          child: const Icon(Icons.insert_drive_file, color: Colors.white),
          backgroundColor: Colors.orange,
          labelWidget: _buildLabel('Document'),
          onTap: _pickDocument,
        ),
        SpeedDialChild(
          child: const Icon(Icons.whatshot, color: Colors.white),
          backgroundColor: _isEphemeral ? cs.primary : Colors.grey,
          labelWidget:
              _buildLabel(_isEphemeral ? 'One-time: ON' : 'One-time: OFF'),
          onTap: () {
            setState(() => _isEphemeral = !_isEphemeral);
          },
        ),
      ],
    );
  }

  Widget _buildLabel(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
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
