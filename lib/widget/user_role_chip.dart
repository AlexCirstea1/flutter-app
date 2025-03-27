import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/environment.dart';
import '../config/logger_config.dart';
import '../services/storage_service.dart';

class UserRoleChip extends StatefulWidget {
  final List<String>? roles;
  final String? userId;

  const UserRoleChip({
    super.key,
    this.roles,
    this.userId,
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
      final token = await _storageService.getAccessToken();
      if (token == null) throw Exception('Authentication required');

      final url =
          Uri.parse('${Environment.apiBaseUrl}/user/${widget.userId}/roles');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

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
      return const SizedBox(
        height: 32,
        width: 32,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_userRoles.isEmpty) {
      return const SizedBox.shrink();
    }

    // Determine the primary role based on priority
    String primaryRole = _getPrimaryRole(_userRoles);

    // Role display configurations
    Color backgroundColor;
    Color textColor = Colors.white;
    String label;
    IconData? icon;

    final roleUpper = primaryRole.toUpperCase();

    if (roleUpper.contains("VERIFIED")) {
      backgroundColor = Colors.green.shade600;
      label = "Verified";
      icon = Icons.verified_user;
    } else if (roleUpper.contains("ANONYMOUS")) {
      backgroundColor = Colors.grey.shade700;
      label = "Anonymous";
      icon = Icons.person_outline;
    } else if (roleUpper.contains("ADMIN")) {
      backgroundColor = Colors.deepPurple;
      label = "Admin";
      icon = Icons.admin_panel_settings;
    } else if (roleUpper.contains("USER")) {
      backgroundColor = Colors.blue.shade700;
      label = "User";
      icon = Icons.person;
    } else {
      backgroundColor = Colors.blueGrey;
      textColor = Colors.white70;
      label = "Unknown";
      icon = Icons.help_outline;
    }

    return Chip(
      avatar: icon != null ? Icon(icon, size: 16, color: textColor) : null,
      label: Text(
        label,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
      backgroundColor: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
