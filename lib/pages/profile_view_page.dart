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
  State<ProfileViewPage> createState() => _ProfileViewPageState();
}

class _ProfileViewPageState extends State<ProfileViewPage> {
  Uint8List? _userAvatar;
  bool _isLoading = true;
  bool _blockchainConsent = false;

  // Additional state variables for actions.
  bool _isBlocked = false;
  bool _amIBlocked = false;
  bool _isAdmin = false;

  late final StorageService _storageService;
  late final AvatarService _avatarService;

  @override
  void initState() {
    super.initState();
    _storageService = StorageService();
    _avatarService = AvatarService(_storageService);
    _loadProfileData();
    _checkBlockStatus();
    _checkIfUserIsAdmin();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      // Load user avatar
      final avatar = await _avatarService.getAvatar(widget.userId);

      // Load user data from the API
      final userData = await _fetchUserData(widget.userId);
      bool consent = false;
      if (userData != null) {
        consent = userData['blockchainConsent'] as bool? ?? false;
      }

      if (mounted) {
        setState(() {
          _userAvatar = avatar;
          _blockchainConsent = consent;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
          '${Environment.apiBaseUrl}/user/blockedBy/${await _storageService.getUserId()}/status');
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

  Future<void> _checkIfUserIsAdmin() async {
    try {
      final url = Uri.parse(
          '${Environment.apiBaseUrl}/user/public/${widget.userId}/roles');
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
            _isAdmin =
                roles.any((role) => role.toUpperCase().contains('ADMIN'));
          });
        }
      }
    } catch (e) {
      LoggerService.logError('Error checking if user is admin', e);
    }
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
        Navigator.pop(context, _isBlocked ? 'blocked' : 'unblocked');
      } else {
        throw Exception(
            'Failed to ${_isBlocked ? 'unblock' : 'block'} user: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteConversation() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Conversation'),
            content: const Text(
                'Are you sure you want to delete this conversation? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child:
                    const Text('CANCEL', style: TextStyle(color: Colors.white)),
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
      if (token == null) throw Exception('Authentication required');

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'PROFILE DETAILS',
          style: theme.appBarTheme.titleTextStyle,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.surface,
            ],
          ),
        ),
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: colorScheme.secondary,
                ),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 30),
                    _buildUserInfoSection(),
                    const SizedBox(height: 24),
                    _buildSecuritySection(),
                    const SizedBox(height: 24),
                    _buildActionsSection(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Container(
          height: 120,
          width: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: colorScheme.primary.withOpacity(0.4), width: 2),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
          ),
          child: _userAvatar != null
              ? CircleAvatar(backgroundImage: MemoryImage(_userAvatar!))
              : CircleAvatar(
                  backgroundColor: colorScheme.surface.withOpacity(0.7),
                  child:
                      Icon(Icons.person, color: colorScheme.primary, size: 50),
                ),
        ),
        const SizedBox(height: 20),
        Text(
          widget.username.toUpperCase(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 16),
        Theme(
          data: Theme.of(context).copyWith(
            chipTheme: ChipThemeData(
              backgroundColor: colorScheme.primary.withOpacity(0.15),
              disabledColor: colorScheme.primary.withOpacity(0.05),
              selectedColor: colorScheme.primary.withOpacity(0.3),
              secondarySelectedColor: colorScheme.primary.withOpacity(0.3),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              labelStyle: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
              ),
              secondaryLabelStyle: TextStyle(color: colorScheme.primary),
              brightness: theme.brightness,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: colorScheme.primary.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: UserRoleChip(userId: widget.userId),
        ),
      ],
    );
  }

  Widget _buildUserInfoSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_circle, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'ACCOUNT INFORMATION',
                style: TextStyle(
                  fontSize: 14,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          Divider(color: colorScheme.primary.withOpacity(0.1), height: 30),
          _buildInfoRow('USERNAME', widget.username),
          _buildInfoRow('ACCOUNT TYPE', 'SECURE MESSAGING USER'),
          _buildInfoRow('STATUS', 'ACTIVE'),
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'SECURITY DETAILS',
                style: TextStyle(
                  fontSize: 14,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          Divider(color: colorScheme.primary.withOpacity(0.1), height: 30),
          _buildInfoRow('ENCRYPTION', 'ENABLED'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'BLOCKCHAIN SERVICES',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.5,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _blockchainConsent
                      ? colorScheme.primary.withOpacity(0.1)
                      : colorScheme.onSurface.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _blockchainConsent
                        ? colorScheme.primary.withOpacity(0.3)
                        : colorScheme.onSurface.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _blockchainConsent ? Icons.check_circle : Icons.cancel,
                      size: 14,
                      color: _blockchainConsent
                          ? colorScheme.primary
                          : theme.textTheme.bodyMedium?.color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _blockchainConsent ? 'ENABLED' : 'DISABLED',
                      style: TextStyle(
                        color: _blockchainConsent
                            ? colorScheme.primary
                            : theme.textTheme.bodyMedium?.color,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'ACTIONS',
                style: TextStyle(
                  fontSize: 14,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          Divider(color: colorScheme.primary.withOpacity(0.1), height: 30),
          ListTile(
            leading: Icon(Icons.report, color: colorScheme.error),
            title: Text('Report',
                style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
            enabled: !_isAdmin,
            onTap: _isAdmin ? null : _reportUser,
          ),
          ListTile(
            leading: Icon(
              _isBlocked ? Icons.person_add : Icons.block,
              color: _isBlocked ? colorScheme.primary : colorScheme.error,
            ),
            title: Text(_isBlocked ? 'Unblock' : 'Block',
                style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
            enabled: !_isAdmin,
            onTap: _isAdmin ? null : _blockUser,
          ),
          ListTile(
            leading: Icon(Icons.delete, color: colorScheme.error),
            title: Text('Delete Conversation',
                style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
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

  Widget _buildInfoRow(String label, String value) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.5,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: theme.textTheme.bodyLarge?.color,
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
