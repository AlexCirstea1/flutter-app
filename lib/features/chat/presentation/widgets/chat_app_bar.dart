import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/environment.dart';
import '../../../../core/config/logger_config.dart';
import '../../../profile/presentation/pages/profile_view_page.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String chatUserId;
  final String chatUsername;
  final ColorScheme cs;
  final ThemeData theme;
  final VoidCallback onBlockStatusChanged;

  const ChatAppBar({
    super.key,
    required this.chatUserId,
    required this.chatUsername,
    required this.cs,
    required this.theme,
    required this.onBlockStatusChanged,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final String initial =
        chatUsername.isNotEmpty ? chatUsername[0].toUpperCase() : "?";

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: cs.primary.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: cs.primary,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: cs.primary.withOpacity(0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 12),
              _buildAvatar(initial),
              const SizedBox(width: 14),
              Expanded(
                child: _buildUserInfo(context),
              ),
              _buildProfileButton(context),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String initial) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withOpacity(0.2),
            cs.primary.withOpacity(0.1),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: cs.primary.withOpacity(0.15),
        child: Text(
          initial,
          style: TextStyle(
            color: cs.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                chatUsername.isNotEmpty ? chatUsername : "Unknown User",
                style: TextStyle(
                  color: theme.textTheme.titleLarge?.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        FutureBuilder<Map<String, dynamic>?>(
          future: _fetchUserData(chatUserId),
          builder: (context, snapshot) {
            bool isOnline = false;
            String statusText = "Offline";

            if (snapshot.hasData && snapshot.data != null) {
              isOnline = snapshot.data!['online'] ?? false;
              if (isOnline) {
                statusText = "Online";
              } else if (snapshot.data!['lastSeen'] != null) {
                final lastSeen = DateTime.parse(snapshot.data!['lastSeen']);
                final now = DateTime.now().toUtc();
                final difference = now.difference(lastSeen);

                if (difference.inMinutes < 1) {
                  statusText = "Just now";
                } else if (difference.inHours < 1) {
                  statusText = "${difference.inMinutes}m ago";
                } else if (difference.inDays < 1) {
                  statusText = "${difference.inHours}h ago";
                } else if (difference.inDays < 7) {
                  statusText = "${difference.inDays}d ago";
                } else {
                  statusText =
                      "${lastSeen.day}/${lastSeen.month}/${lastSeen.year}";
                }
              }
            }

            return Row(
              children: [
                Container(
                  height: 8,
                  width: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline ? Colors.green : cs.primary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: TextStyle(
                    color: isOnline
                        ? Colors.green.shade700
                        : cs.primary.withOpacity(0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildProfileButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.primary.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final r = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileViewPage(
                  userId: chatUserId,
                  username: chatUsername,
                ),
              ),
            );
            if (r == 'blocked' || r == 'unblocked') onBlockStatusChanged();
            if (r == 'deleted' || r == 'reported') Navigator.pop(context);
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              Icons.account_circle_outlined,
              color: cs.primary,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchUserData(String userId) async {
    try {
      final url = Uri.parse('${Environment.apiBaseUrl}/user/public/$userId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      LoggerService.logError('Error fetching user data by ID $userId', e);
    }
    return null;
  }
}
