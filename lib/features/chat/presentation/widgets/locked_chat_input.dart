import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/environment.dart';
import '../../../../core/config/logger_config.dart';
import '../../../../core/data/services/storage_service.dart';

class LockedChatInput extends StatefulWidget {
  final String chatUserId;
  final VoidCallback? onRequestTap;
  final VoidCallback? onBlockStatusChanged;

  const LockedChatInput({
    super.key,
    required this.chatUserId,
    this.onRequestTap,
    this.onBlockStatusChanged,
  });

  @override
  State<LockedChatInput> createState() => _LockedChatInputState();
}

class _LockedChatInputState extends State<LockedChatInput> {
  bool _isBlocked = false;
  bool _amIBlocked = false;
  bool _isCurrentUserAdmin = false;
  bool _isChatPartnerAdmin = false;
  bool _isLoading = false;

  final StorageService _storage = StorageService();
  String? _me;

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    _me = await _storage.getUserId();
    await _fetchAdminStatus();
    await _fetchBlockStatus();
  }

  Future<void> _fetchAdminStatus() async {
    try {
      final token = await _storage.getAccessToken();
      if (token == null) return;

      // me
      if (_me != null) {
        final resp = await http.get(
          Uri.parse('${Environment.apiBaseUrl}/user/public/$_me/roles'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (resp.statusCode == 200) {
          final roles = List<String>.from(jsonDecode(resp.body));
          _isCurrentUserAdmin =
              roles.any((r) => r.toUpperCase().contains('ADMIN'));
        }
      }
      // them
      final resp2 = await http.get(
        Uri.parse(
            '${Environment.apiBaseUrl}/user/public/${widget.chatUserId}/roles'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp2.statusCode == 200) {
        final roles2 = List<String>.from(jsonDecode(resp2.body));
        _isChatPartnerAdmin =
            roles2.any((r) => r.toUpperCase().contains('ADMIN'));
      }
    } catch (e) {
      LoggerService.logError('Admin status failed', e);
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _fetchBlockStatus() async {
    try {
      final token = await _storage.getAccessToken();
      if (token == null) return;

      final youBlockedResp = await http.get(
        Uri.parse(
            '${Environment.apiBaseUrl}/user/block/${widget.chatUserId}/status'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final theyBlockedResp = await http.get(
        Uri.parse(
            '${Environment.apiBaseUrl}/user/blockedBy/${widget.chatUserId}/status'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (mounted) {
        setState(() {
          _isBlocked = youBlockedResp.statusCode == 200 &&
              jsonDecode(youBlockedResp.body) == true;
          _amIBlocked = theyBlockedResp.statusCode == 200 &&
              jsonDecode(theyBlockedResp.body) == true;
        });
        widget.onBlockStatusChanged?.call();
      }
    } catch (e) {
      LoggerService.logError('Block status failed', e);
    }
  }

  Future<void> _toggleBlock() async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final action = _isBlocked ? 'Unblock' : 'Block';

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('$action User'),
            content: Text('Are you sure you want to ${action.toLowerCase()}?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('CANCEL')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(action.toUpperCase(),
                    style: TextStyle(
                        color: action == 'Block' ? cs.error : cs.primary)),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    setState(() => _isLoading = true);
    try {
      final token = await _storage.getAccessToken();
      if (token == null) throw 'Auth required';
      final uri = Uri.parse(
          '${Environment.apiBaseUrl}/user/block/${widget.chatUserId}');
      final resp = _isBlocked
          ? await http.delete(uri, headers: {'Authorization': 'Bearer $token'})
          : await http.post(uri, headers: {'Authorization': 'Bearer $token'});
      if (resp.statusCode == 200) {
        setState(() => _isBlocked = !_isBlocked);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('User ${_isBlocked ? 'blocked' : 'unblocked'}')),
        );
        widget.onBlockStatusChanged?.call();
      } else {
        throw 'HTTP ${resp.statusCode}';
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // choose message
    String title, subtitle = '';
    if (_isCurrentUserAdmin || _isChatPartnerAdmin) {
      title = 'Messaging disabled for admin accounts.';
    } else if (_amIBlocked) {
      title = 'You have been blocked by this user.';
    } else if (_isBlocked) {
      title = 'You have blocked this user.';
      subtitle = 'Unblock to send messages.';
    } else {
      title = 'Secure connection required';
      subtitle = 'Send a request to start messaging';
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, -3))
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? cs.surface.withOpacity(0.8)
                  : cs.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.primary.withOpacity(0.2)),
            ),
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: cs.secondary))
                : Row(
                    children: [
                      Icon(Icons.lock_outline, color: cs.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: cs.primary)),
                            if (subtitle.isNotEmpty)
                              Text(subtitle,
                                  style: TextStyle(
                                      color:
                                          theme.textTheme.bodyMedium?.color)),
                          ],
                        ),
                      ),

                      // choose action button
                      if (!_amIBlocked &&
                          !_isCurrentUserAdmin &&
                          !_isChatPartnerAdmin)
                        _isBlocked
                            ? TextButton(
                                onPressed: _toggleBlock,
                                child: const Text('UNBLOCK'))
                            : IconButton(
                                icon: Icon(Icons.arrow_upward_rounded,
                                    color: cs.primary),
                                onPressed: widget.onRequestTap,
                              ),
                      if (_isBlocked)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: TextButton(
                            onPressed: _toggleBlock,
                            child: const Text('BLOCK/UNBLOCK'),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
