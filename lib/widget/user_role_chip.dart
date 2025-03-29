import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/environment.dart';
import '../config/logger_config.dart';
import '../services/storage_service.dart';

class UserRoleChip extends StatefulWidget {
  final List<String>? roles;
  final String? userId;
  final bool isCompact;

  const UserRoleChip({
    super.key,
    this.roles,
    this.userId,
    this.isCompact = false,
  }) : assert(roles != null || userId != null,
            'Either roles or userId must be provided');

  @override
  State<UserRoleChip> createState() => _UserRoleChipState();
}

class _UserRoleChipState extends State<UserRoleChip> {
  final StorageService _storageService = StorageService();
  List<String> _userRoles = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.roles != null) {
      _userRoles = widget.roles!;
    } else if (widget.userId != null) {
      _fetchUserRoles();
    }
  }

  Future<void> _fetchUserRoles() async {
    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(
          '${Environment.apiBaseUrl}/user/public/${widget.userId}/roles');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> rolesJson = jsonDecode(response.body);
        setState(() {
          _userRoles = rolesJson.cast<String>();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to fetch roles: ${response.statusCode}');
      }
    } catch (e) {
      LoggerService.logError('Error fetching user roles', e);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        height: widget.isCompact ? 20 : 32,
        width: widget.isCompact ? 20 : 32,
        child: CircularProgressIndicator(
          strokeWidth: widget.isCompact ? 1.5 : 2,
          color: Colors.cyan.shade200,
          backgroundColor: Colors.cyan.withOpacity(0.1),
        ),
      );
    }

    if (_userRoles.isEmpty) {
      return const SizedBox.shrink();
    }

    // Determine the primary role based on priority
    String primaryRole = _getPrimaryRole(_userRoles);

    // Role display configurations - using cybersecurity colors
    Color backgroundColor;
    Color borderColor;
    Color textColor = Colors.white;
    String label;
    IconData? icon;

    final roleUpper = primaryRole.toUpperCase();

    if (roleUpper.contains("VERIFIED")) {
      backgroundColor = Colors.green.shade900.withOpacity(0.7);
      borderColor = Colors.green.shade400.withOpacity(0.5);
      label = "VERIFIED";
      icon = Icons.verified_user;
    } else if (roleUpper.contains("ANONYMOUS")) {
      backgroundColor = Colors.grey.shade900.withOpacity(0.7);
      borderColor = Colors.grey.shade500.withOpacity(0.5);
      label = "ANONYMOUS";
      icon = Icons.person_outline;
    } else if (roleUpper.contains("ADMIN")) {
      backgroundColor = Colors.deepPurple.shade900.withOpacity(0.7);
      borderColor = Colors.deepPurple.shade400.withOpacity(0.5);
      label = "ADMIN";
      icon = Icons.admin_panel_settings;
    } else if (roleUpper.contains("USER")) {
      backgroundColor = Colors.blue.shade900.withOpacity(0.7);
      borderColor = Colors.blue.shade400.withOpacity(0.5);
      label = "USER";
      icon = Icons.person;
    } else {
      backgroundColor = Colors.blueGrey.shade900.withOpacity(0.7);
      borderColor = Colors.blueGrey.shade400.withOpacity(0.5);
      textColor = Colors.white70;
      label = "UNKNOWN";
      icon = Icons.help_outline;
    }

    // For compact mode, only show the icon with cybersecurity styling
    if (widget.isCompact) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: borderColor.withOpacity(0.5),
              blurRadius: 4,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 14,
          color: textColor,
        ),
      );
    }

    // Regular mode: Cybersecurity-styled chip
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to determine primary role based on priority
  String _getPrimaryRole(List<String> roles) {
    // Priority: ADMIN > VERIFIED > USER > ANONYMOUS
    if (roles.any((role) => role.toUpperCase().contains("ADMIN"))) {
      return "ADMIN";
    } else if (roles.any((role) => role.toUpperCase().contains("VERIFIED"))) {
      return "VERIFIED";
    } else if (roles.any((role) => role.toUpperCase().contains("ANONYMOUS"))) {
      return "ANONYMOUS";
    } else if (roles.any((role) => role.toUpperCase().contains("USER"))) {
      return "USER";
    } else {
      return "UNKNOWN";
    }
  }
}
