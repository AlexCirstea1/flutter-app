import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/environment.dart';
import '../config/logger_config.dart';
import '../services/avatar_service.dart';
import '../services/storage_service.dart';
import '../widget/user_role_chip.dart';

class ProfileViewPage extends StatefulWidget {
  final String userId;
  final String username;

  const ProfileViewPage({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<ProfileViewPage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfileViewPage> {
  bool _isLoading = false;
  bool _isBlocked = false;
  bool _amIBlocked = false;
  bool _blockchainConsent = false;
  bool _isAdmin = false;
  final StorageService _storageService = StorageService();
  late AvatarService _avatarService;

  @override
  void initState() {
    super.initState();
    _avatarService = AvatarService(_storageService);
    _fetchUserProfile();
    _checkBlockStatus();
    _checkIfUserIsAdmin();
  }

  Future<void> _fetchUserProfile() async {
    setState(() => _isLoading = true);

    try {
      final userData = await _fetchUserData(widget.userId);
      if (userData != null && mounted) {
        setState(() {
          _blockchainConsent = userData['blockchainConsent'] as bool? ?? false;
        });
      }
    } catch (e) {
      LoggerService.logError('Error fetching user profile', e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkIfUserIsAdmin() async {
    try {
      final url = Uri.parse('${Environment.apiBaseUrl}/user/public/${widget.userId}/roles');
      final token = await _storageService.getAccessToken();
      if (token == null) throw Exception('Authentication required');

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final roles = List<String>.from(jsonDecode(response.body));
        if (mounted) {
          setState(() {
            _isAdmin = roles.any((role) => role.toUpperCase().contains('ADMIN'));
          });
        }
      }
    } catch (e) {
      LoggerService.logError('Error checking if user is admin', e);
    }
  }

  Future<Map<String, dynamic>?> _fetchUserData(String userId) async {
    try {
      final url = Uri.parse('${Environment.apiBaseUrl}/user/public/$userId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        LoggerService.logError(
            'Error fetching user data: ${response.statusCode}', null);
      }
    } catch (e) {
      LoggerService.logError('Error fetching user data by ID $userId', e);
    }
    return null;
  }

  Future<void> _reportUser() async {
    final TextEditingController reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Report User'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Please provide a reason for reporting this user:'),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    hintText: 'Enter reason',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child:
                    const Text('CANCEL', style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: () {
                  if (reasonController.text.trim().isNotEmpty) {
                    Navigator.pop(context, true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content:
                            Text('Please provide a reason for reporting')));
                  }
                },
                child:
                    const Text('REPORT', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || reasonController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final token = await _storageService.getAccessToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final request = UserReportRequest(
        userId: widget.userId,
        reason: reasonController.text.trim(),
      );

      final url = Uri.parse('${Environment.apiBaseUrl}/user/report');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User reported successfully')));
          Navigator.pop(context, 'reported');
        }
      } else {
        String errorMessage;
        switch (response.statusCode) {
          case 400:
            errorMessage = 'Invalid report data';
            break;
          case 404:
            errorMessage = 'User not found';
            break;
          case 429:
            errorMessage = 'Too many reports submitted recently';
            break;
          default:
            errorMessage = 'Failed to report user (${response.statusCode})';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkBlockStatus() async {
    try {
      final token = await _storageService.getAccessToken();
      if (token == null) throw Exception('Authentication required');

      // Check if the current user has blocked the chat partner.
      final iBlockedUrl = Uri.parse(
          '${Environment.apiBaseUrl}/user/block/${widget.userId}/status');
      final iBlockedResponse = await http.get(
        iBlockedUrl,
        headers: {'Authorization': 'Bearer $token'},
      );

      // Check if the chat partner has blocked the current user.
      final blockedMeUrl = Uri.parse(
          '${Environment.apiBaseUrl}/user/blockedBy/${_storageService.getUserId()}/status');
      final blockedMeResponse = await http.get(
        blockedMeUrl,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (mounted) {
        setState(() {
          _isBlocked = iBlockedResponse.statusCode == 200 &&
              jsonDecode(iBlockedResponse.body) == true;
          _amIBlocked = blockedMeResponse.statusCode == 200 &&
              jsonDecode(blockedMeResponse.body) == true;
        });
      }
    } catch (e) {
      LoggerService.logError('Error checking block status', e);
    }
  }

  Future<void> _blockUser() async {
    final String actionText = _isBlocked ? 'Unblock' : 'Block';

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('$actionText User'),
            content: Text(
                'Are you sure you want to ${_isBlocked ? 'unblock' : 'block'} this user?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child:
                    const Text('CANCEL', style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(actionText.toUpperCase(),
                    style: TextStyle(
                        color: _isBlocked ? Colors.blue : Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      final token = await _storageService.getAccessToken();
      if (token == null) throw Exception('Authentication required');

      final url =
          Uri.parse('${Environment.apiBaseUrl}/user/block/${widget.userId}');
      final response = _isBlocked
          ? await http.delete(url, headers: {'Authorization': 'Bearer $token'})
          : await http.post(url, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        setState(() => _isBlocked = !_isBlocked);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'User ${_isBlocked ? 'blocked' : 'unblocked'} successfully')),
        );
        // Optionally, you might pop back or refresh UI.
        Navigator.pop(context, _isBlocked ? 'blocked' : 'unblocked');
      } else {
        throw Exception(
            'Failed to ${_isBlocked ? 'unblock' : 'block'} user: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteConversation() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Conversation'),
            content: const Text(
                'Are you sure you want to delete this conversation? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child:
                    const Text('DELETE', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      final token = await _storageService.getAccessToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final url = Uri.parse(
          '${Environment.apiBaseUrl}/messages?participantId=${widget.userId}');
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 404) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Conversation deleted successfully')));
          // Return 'deleted' to indicate the conversation was deleted
          Navigator.pop(context, 'deleted');
        }
      } else {
        throw Exception(
            'Failed to delete conversation: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Uint8List?> _fetchAvatar(String userId) async {
    return _avatarService.getAvatar(userId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: theme.surface,
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildProfileContent(),
    );
  }

  Widget _buildProfileContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Display avatar with FutureBuilder
          FutureBuilder<Uint8List?>(
            future: _fetchAvatar(widget.userId),
            builder: (_, snapshot) {
              return CircleAvatar(
                radius: 50,
                backgroundImage:
                    snapshot.hasData ? MemoryImage(snapshot.data!) : null,
                child: snapshot.hasData
                    ? null
                    : const Icon(Icons.person, size: 50, color: Colors.white70),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            widget.username,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          _buildBlockchainConsentIndicator(),
          UserRoleChip(userId: widget.userId),
          const SizedBox(height: 8),
          const Divider(height: 32),

          // Action buttons: Report, Block, Delete
          ListTile(
            leading: const Icon(Icons.report),
            title: const Text('Report'),
            enabled: !_isAdmin,
            onTap: _isAdmin ? null : _reportUser,
          ),
          ListTile(
            leading: Icon(_isBlocked ? Icons.person_add : Icons.block),
            title: Text(_isBlocked ? 'Unblock' : 'Block'),
            enabled: !_isAdmin,
            onTap: _isAdmin ? null : _blockUser,
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete Conversation'),
            enabled: !_isAdmin,
            onTap: _isAdmin ? null : _deleteConversation,
          ),
          if (_isAdmin) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Actions are disabled for admin users",
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBlockchainConsentIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _blockchainConsent ? Icons.link : Icons.link_off,
            size: 20,
            color: _blockchainConsent ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            _blockchainConsent ? 'Blockchain Enabled' : 'No Blockchain',
            style: TextStyle(
              color: _blockchainConsent ? Colors.green : Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class UserReportRequest {
  final String userId;
  final String reason;

  UserReportRequest({
    required this.userId,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'reason': reason,
      };
}
