import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/environment.dart';
import '../services/api_service.dart';
import '../services/service_locator.dart';
import '../services/storage_service.dart';
import '../widget/bottom_nav_bar.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  int _selectedIndex = 3; // Position in navbar
  bool _isLoading = true;
  List<ActivityLog> _activities = [];
  String? _selectedFilter;

  final ApiService _apiService = serviceLocator<ApiService>();

  @override
  void initState() {
    super.initState();
    _fetchActivities();
  }

  Future<void> _fetchActivities({String? filterType}) async {
    setState(() => _isLoading = true);

    try {
      String endpoint = '/user/activities';
      if (filterType != null) {
        endpoint += '?type=$filterType';
      }

      final data = await _apiService.get(endpoint);
      final List<ActivityLog> activities =
      (data as List).map((item) => ActivityLog.fromJson(item)).toList();

      setState(() {
        _activities = activities;
        _isLoading = false;
        _selectedFilter = filterType;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() => _isLoading = false);
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: theme.surface,
      appBar: AppBar(
        backgroundColor: theme.primary,
        foregroundColor: theme.onPrimary,
        title: const Text('Activity Log'),
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              if (value == 'All') {
                _fetchActivities();
              } else {
                _fetchActivities(filterType: value.toLowerCase());
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All Activities')),
              const PopupMenuItem(value: 'Login', child: Text('Logins')),
              const PopupMenuItem(value: 'Key', child: Text('Key Rotations')),
              const PopupMenuItem(value: 'Pin', child: Text('PIN Changes')),
              const PopupMenuItem(value: 'Consent', child: Text('Consent Changes')),
              const PopupMenuItem(value: 'Blockchain', child: Text('Blockchain Transactions')),
              const PopupMenuItem(value: 'User_action', child: Text('User Actions')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history,
                          size: 64, color: theme.onSurface.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      Text(
                        'No activities found',
                        style: TextStyle(
                          fontSize: 18,
                          color: theme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      if (_selectedFilter != null) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _fetchActivities(),
                          child: const Text('Show all activities'),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _activities.length,
                  itemBuilder: (context, index) {
                    final activity = _activities[index];
                    return ActivityTile(activity: activity);
                  },
                ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class ActivityLog {
  final String id;
  final String type;
  final String description;
  final DateTime timestamp;
  final bool isUnusual;
  final String? details;

  ActivityLog({
    required this.id,
    required this.type,
    required this.description,
    required this.timestamp,
    this.isUnusual = false,
    this.details,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'],
      type: json['type'],
      description: json['description'],
      timestamp: DateTime.parse(json['timestamp']), // Backend uses Instant which parses fine
      isUnusual: json['isUnusual'] ?? json['unusual'] ?? false,
      details: json['details'],
    );
  }

  IconData get icon {
    switch (type.toLowerCase()) {
      case 'login':
        return Icons.login;
      case 'key':
        return Icons.key;
      case 'pin':
        return Icons.pin;
      case 'consent':
        return Icons.handshake;
      case 'blockchain':
        return Icons.link;
      case 'user_action':
        return Icons.person_outline;
      default:
        return Icons.history;
    }
  }

  Color getColor(BuildContext context) {
    if (isUnusual) return Theme.of(context).colorScheme.error;

    switch (type.toLowerCase()) {
      case 'login':
        return Colors.blue;
      case 'key':
        return Colors.amber;
      case 'pin':
        return Colors.purple;
      case 'consent':
        return Colors.green;
      case 'blockchain':
        return Colors.teal;
      case 'user_action':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }
}

class ActivityTile extends StatelessWidget {
  final ActivityLog activity;

  const ActivityTile({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: activity.isUnusual ? theme.error.withOpacity(0.1) : theme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: activity.isUnusual
            ? BorderSide(color: theme.error, width: 1)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: activity.getColor(context).withOpacity(0.2),
          child: Icon(activity.icon, color: activity.getColor(context)),
        ),
        title: Text(
          activity.description,
          style: TextStyle(
            fontWeight:
                activity.isUnusual ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _formatDate(activity.timestamp),
              style: TextStyle(
                fontSize: 12,
                color: theme.onSurface.withOpacity(0.7),
              ),
            ),
            if (activity.details != null) ...[
              const SizedBox(height: 4),
              Text(
                activity.details!,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
        trailing: activity.isUnusual
            ? Icon(Icons.warning_amber, color: theme.error)
            : null,
        onTap: () => _showActivityDetails(context, activity),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  void _showActivityDetails(BuildContext context, ActivityLog activity) {
    final theme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(activity.icon, color: activity.getColor(context)),
            const SizedBox(width: 8),
            const Text('Activity Details'),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Type: ${activity.type}'),
            const SizedBox(height: 8),
            Text('Description: ${activity.description}'),
            const SizedBox(height: 8),
            Text('Time: ${activity.timestamp.toString()}'),
            if (activity.details != null) ...[
              const SizedBox(height: 8),
              Text('Details: ${activity.details}'),
            ],
            if (activity.isUnusual) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This activity is unusual. If you don\'t recognize it, please change your password.',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
