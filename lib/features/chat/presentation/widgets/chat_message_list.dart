import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../domain/models/message_dto.dart';
import '../../../chat/data/services/file_download_service.dart';
import '../../../../core/data/services/service_locator.dart';
import 'message_buble.dart';
import 'file_message_widget.dart';

/* ────────────────────────────────────────────────────────── */
/*  Small helpers                                            */
enum ChatItemType { dateHeader, message }

class _ChatListItem {
  final ChatItemType type;
  final String? dateLabel;
  final MessageDTO? message;

  _ChatListItem.dateHeader(this.dateLabel)
      : type = ChatItemType.dateHeader,
        message = null;

  _ChatListItem.message(this.message)
      : type = ChatItemType.message,
        dateLabel = null;
}
/* ────────────────────────────────────────────────────────── */

class ChatMessagesList extends StatefulWidget {
  final List<MessageDTO> messages;
  final String? currentUserId;
  final bool isLoading;
  final ItemScrollController scrollController;
  final ItemPositionsListener positionsListener;
  final Function(MessageDTO)? onMessageDeleted;
  final Function() onRefresh;

  const ChatMessagesList({
    super.key,
    required this.messages,
    required this.currentUserId,
    required this.isLoading,
    required this.scrollController,
    required this.positionsListener,
    this.onMessageDeleted,
    required this.onRefresh,
  });

  @override
  State<ChatMessagesList> createState() => _ChatMessagesListState();
}

class _ChatMessagesListState extends State<ChatMessagesList> {
  /* ───────── file-download state ───────── */
  final Map<String, double> _downloadProgress = {};
  final Map<String, String> _downloadErrors = {};

  /* ───────── auto-scroll bookkeeping ───── */
  int _prevLen = 0;
  final double _tolerance = 20; // px

  @override
  void initState() {
    super.initState();
    _prevLen = widget.messages.length;
  }

  @override
  void didUpdateWidget(covariant ChatMessagesList old) {
    super.didUpdateWidget(old);

    if (widget.messages.length != _prevLen) {
      if (_isNearBottom()) _animateToLatest();
      _prevLen = widget.messages.length;
    }
  }

  /* ───────────────── auto-scroll helpers ───────────────── */
  bool _isNearBottom() {
    final positions = widget.positionsListener.itemPositions.value;
    if (positions.isEmpty) return false;

    // In a reversed list, the bottommost visible item has the *largest*
    // trailing edge (0 = top, 1 = bottom of viewport).
    final lastTrailing = positions
        .reduce((a, b) => a.itemTrailingEdge > b.itemTrailingEdge ? a : b)
        .itemTrailingEdge;

    final distancePx =
        (1.0 - lastTrailing) * MediaQuery.of(context).size.height;
    return distancePx < _tolerance;
  }

  void _animateToLatest() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!widget.scrollController.isAttached) return;
      widget.scrollController.scrollTo(
        index: 0, // newest == index 0
        alignment: 0.0, // stick to bottom
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }
  /* ─────────────────────────────────────────────────────── */

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.secondary,
        ),
      );
    }

    final chatItems = _buildChatItems(); // newest first
    return ScrollablePositionedList.builder(
      reverse: true, // ← key change
      itemScrollController: widget.scrollController,
      itemPositionsListener: widget.positionsListener,
      initialScrollIndex: chatItems.isNotEmpty ? 0 : 0,
      itemCount: chatItems.length,
      itemBuilder: (ctx, i) {
        final item = chatItems[i];

        if (item.type == ChatItemType.dateHeader) {
          return _buildDateDivider(context, item.dateLabel ?? '');
        }

        final msg = item.message!;
        final isMine = (msg.sender == widget.currentUserId);

        if (msg.ciphertext == '__FILE__' || msg.file != null) {
          return FileMessageWidget(
            message: msg,
            isOwn: isMine,
            onDownload: _handleFileDownload,
            downloadProgress: _downloadProgress[msg.id],
            downloadError: _downloadErrors[msg.id],
          );
        }

        return MessageBubble(
          message: msg,
          isMine: isMine,
          colorScheme: Theme.of(context).colorScheme,
          textTheme: Theme.of(context).textTheme,
          onDeleteMessage: widget.onMessageDeleted,
        );
      },
    );
  }

  /* ───────────────────────── file download ───────────────────── */
  void _handleFileDownload(MessageDTO message) async {
    if (_downloadProgress.containsKey(message.id) &&
        _downloadProgress[message.id]! > 0 &&
        _downloadProgress[message.id]! < 1) return;

    setState(() {
      _downloadProgress[message.id] = 0.05;
      _downloadErrors.remove(message.id);
    });

    final dlService = serviceLocator<FileDownloadService>();
    final file = await dlService.downloadAndDecryptFile(
      message: message,
      onProgress: (p) => setState(() => _downloadProgress[message.id] = p),
      onError: (err) => setState(() {
        _downloadErrors[message.id] = err;
        _downloadProgress[message.id] = 0;
      }),
    );

    if (file != null && mounted) {
      setState(() => _downloadProgress[message.id] = 1.0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File downloaded successfully. Opening…'),
          backgroundColor: Colors.green,
        ),
      );
      await dlService.openFile(file);
    } else if (file == null && mounted && _downloadErrors[message.id] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Failed to download file: ${_downloadErrors[message.id]}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  /* ───────────────────────── date chips ───────────────────── */

  /* ───────── FIXED date-chip builder ───────── */
  List<_ChatListItem> _buildChatItems() {
    final items = <_ChatListItem>[];

    DateTime? lastDay;                               // “current day” bucket
    for (int i = widget.messages.length - 1; i >= 0; i--) {
      final m = widget.messages[i];                  // newest → oldest
      final msgDay = DateTime(m.timestamp.year, m.timestamp.month, m.timestamp.day);

      // If we’ve just crossed into an OLDER calendar day, insert the chip
      if (lastDay != null &&
          (msgDay.year  != lastDay.year  ||
              msgDay.month != lastDay.month ||
              msgDay.day   != lastDay.day)) {
        items.add(_ChatListItem.dateHeader(_formatDateHeader(lastDay)));
      }

      // Add the message itself
      items.add(_ChatListItem.message(m));
      lastDay = msgDay;
    }

    // Add header for the oldest block (loop never catches it)
    if (lastDay != null) {
      items.add(_ChatListItem.dateHeader(_formatDateHeader(lastDay)));
    }

    return items;   // still newest-first for reverse:true
  }
  /* ─────────────────────────────────────────── */

  String _formatDateHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff = msgDay.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    return '${_monthName(dt.month)} ${dt.day}, ${dt.year}';
  }

  String _monthName(int m) => const [
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
      ][m - 1];

  Widget _buildDateDivider(BuildContext ctx, String label) {
    final cs = Theme.of(ctx).colorScheme;
    return Center(
      child: Chip(
        label: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: cs.onSurface.withOpacity(0.6),
            )),
        backgroundColor: cs.surface.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}
