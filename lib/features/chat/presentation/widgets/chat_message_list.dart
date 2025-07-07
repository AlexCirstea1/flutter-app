import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../domain/models/message_dto.dart';
import '../../../chat/data/services/file_download_service.dart';
import '../../../../core/data/services/service_locator.dart';
import 'message_buble.dart';
import 'file_message_widget.dart';

// Move this enum from ChatPage to make the widget independent
enum ChatItemType { dateHeader, message }

// Move this class from ChatPage to make the widget independent
class _ChatListItem {
  final ChatItemType type;
  final String? dateLabel; // used if type = dateHeader
  final MessageDTO? message; // used if type = message

  _ChatListItem.dateHeader(this.dateLabel)
      : type = ChatItemType.dateHeader,
        message = null;

  _ChatListItem.message(this.message)
      : type = ChatItemType.message,
        dateLabel = null;
}

class ChatMessagesList extends StatefulWidget {
  final List<MessageDTO> messages;
  final String? currentUserId;
  final bool isLoading;
  final ItemScrollController scrollController;
  final ItemPositionsListener positionsListener;

  const ChatMessagesList({
    super.key,
    required this.messages,
    required this.currentUserId,
    required this.isLoading,
    required this.scrollController,
    required this.positionsListener,
  });

  @override
  State<ChatMessagesList> createState() => _ChatMessagesListState();
}

class _ChatMessagesListState extends State<ChatMessagesList> {
  // Track download progress for each file
  final Map<String, double> _downloadProgress = {};
  // Track download errors
  final Map<String, String> _downloadErrors = {};

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.secondary,
        ),
      );
    }

    final chatItems = _buildChatItems();
    return ScrollablePositionedList.builder(
      itemScrollController: widget.scrollController,
      itemPositionsListener: widget.positionsListener,
      initialScrollIndex: chatItems.isEmpty ? 0 : chatItems.length - 1,
      itemCount: chatItems.length,
      itemBuilder: (ctx, i) {
        final item = chatItems[i];
        if (item.type == ChatItemType.dateHeader) {
          return _buildDateDivider(context, item.dateLabel ?? '');
        } else {
          final msg = item.message!;
          final isMine = (msg.sender == widget.currentUserId);

          // Check if this is a file message
          if (msg.plaintext != null && msg.plaintext!.startsWith('[File] ')) {
            return FileMessageWidget(
              message: msg,
              currentUserId: widget.currentUserId,
              isOwn: isMine,
              onDownload: _handleFileDownload,
            );
          }

          // Regular text message
          return MessageBubble(
            message: msg,
            isMine: isMine,
            colorScheme: Theme.of(context).colorScheme,
            textTheme: Theme.of(context).textTheme,
          );
        }
      },
    );
  }

  void _handleFileDownload(MessageDTO message) async {
    // Prevent multiple downloads of the same file
    if (_downloadProgress.containsKey(message.id) &&
        _downloadProgress[message.id]! > 0 &&
        _downloadProgress[message.id]! < 1) {
      return;
    }

    setState(() {
      _downloadProgress[message.id] = 0.05;
      _downloadErrors.remove(message.id);
    });

    // Get the FileDownloadService from service locator
    final downloadService = serviceLocator<FileDownloadService>();

    // Download and decrypt the file
    final file = await downloadService.downloadAndDecryptFile(
      message: message,
      onProgress: (p) {
        setState(() {
          _downloadProgress[message.id] = p;
        });
      },
      onError: (error) {
        setState(() {
          _downloadErrors[message.id] = error;
          _downloadProgress[message.id] = 0;
        });

        // Show error message as a snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to download file: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );

    if (file != null) {
      // Download completed successfully
      setState(() {
        _downloadProgress[message.id] = 1.0;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File downloaded successfully. Opening...'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Open the file
      await downloadService.openFile(file);
    }
  }

  String _formatDateHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff = msgDay.difference(today).inDays;

    if (diff == 0) {
      return 'Today';
    } else if (diff == -1) {
      return 'Yesterday';
    } else {
      return "${_monthName(dt.month)} ${dt.day}, ${dt.year}";
    }
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  List<_ChatListItem> _buildChatItems() {
    final items = <_ChatListItem>[];
    DateTime? lastDay; // we track the last day we inserted

    for (var i = 0; i < widget.messages.length; i++) {
      final m = widget.messages[i];
      // 'Day' is year-month-day only
      final msgDay =
          DateTime(m.timestamp.year, m.timestamp.month, m.timestamp.day);

      // If day changed (or first message), we insert a date-header item
      if (lastDay == null ||
          msgDay.year != lastDay.year ||
          msgDay.month != lastDay.month ||
          msgDay.day != lastDay.day) {
        items.add(_ChatListItem.dateHeader(_formatDateHeader(m.timestamp)));
        lastDay = msgDay;
      }

      // Then the message item
      items.add(_ChatListItem.message(m));
    }

    return items;
  }

  Widget _buildDateDivider(BuildContext context, String label) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Chip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: cs.onSurface.withOpacity(0.6),
          ),
        ),
        backgroundColor: cs.surface.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      ),
    );
  }
}
