import 'package:flutter/material.dart';

class ChatRequestWidget extends StatefulWidget {
  final String recipientUsername;
  final bool requestSent;
  final Future<void> Function(String message) onSendRequest;

  const ChatRequestWidget({
    super.key,
    required this.recipientUsername,
    required this.requestSent,
    required this.onSendRequest,
  });

  @override
  State<ChatRequestWidget> createState() => _ChatRequestWidgetState();
}

class _ChatRequestWidgetState extends State<ChatRequestWidget> {
  final TextEditingController _requestController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _requestController.dispose();
    super.dispose();
  }

  Future<void> _sendRequest() async {
    final message = _requestController.text.trim();
    if (message.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await widget.onSendRequest(message);
      _requestController.clear();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.primary.withOpacity(0.1),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: widget.requestSent
          ? _buildPendingRequest(colorScheme)
          : _buildRequestForm(colorScheme),
    );
  }

  Widget _buildPendingRequest(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.timer_outlined,
            size: 20,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shield,
                      size: 12,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'REQUEST PENDING',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.0,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'The chat will unlock once ${widget.recipientUsername} accepts your request.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestForm(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_outline,
                size: 14,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'SECURE CONNECTION',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Start a secure chat with ${widget.recipientUsername}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.2),
              ),
            ),
            child: TextField(
              controller: _requestController,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              decoration: InputDecoration(
                hintText: 'Say hello...',
                hintStyle: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: _isLoading ? null : _sendRequest,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_open,
                    size: 16,
                    color: colorScheme.onPrimary,
                  ),
                  const SizedBox(width: 8),
                  _isLoading
                      ? SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Text(
                          'SEND REQUEST',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}