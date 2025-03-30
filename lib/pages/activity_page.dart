import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/service_locator.dart';
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
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red.shade900,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'ACTIVITY LOG',
          style: TextStyle(
            fontSize: 16,
            letterSpacing: 2.0,
            fontWeight: FontWeight.w300,
            color: Colors.cyan.shade100,
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.cyan.withOpacity(0.3), width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: PopupMenuButton<String>(
              icon: Icon(Icons.filter_list, color: Colors.cyan.shade200),
              onSelected: (value) {
                if (value == 'All') {
                  _fetchActivities();
                } else {
                  _fetchActivities(filterType: value.toLowerCase());
                }
              },
              color: const Color(0xFF121A24),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.cyan.withOpacity(0.3)),
              ),
              itemBuilder: (context) => [
                _buildPopupMenuItem('All', 'ALL ACTIVITIES', Icons.list_alt),
                _buildPopupMenuItem('Login', 'LOGINS', Icons.login),
                _buildPopupMenuItem('Key', 'KEY ROTATIONS', Icons.key),
                _buildPopupMenuItem('Pin', 'PIN CHANGES', Icons.pin),
                _buildPopupMenuItem('Consent', 'CONSENT CHANGES', Icons.handshake),
                _buildPopupMenuItem('Blockchain', 'BLOCKCHAIN TRANSACTIONS', Icons.link),
                _buildPopupMenuItem('User_action', 'USER ACTIONS', Icons.person_outline),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Color(0xFF101720)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent))
              : _activities.isEmpty
              ? _buildEmptyState()
              : _buildActivityList(),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(String value, String label, IconData icon) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.cyan.shade300),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.cyan.shade100,
              fontSize: 12,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.cyan.withOpacity(0.05),
              border: Border.all(color: Colors.cyan.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              Icons.history,
              size: 64,
              color: Colors.cyan.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'NO ACTIVITIES FOUND',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade400,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w300,
            ),
          ),
          if (_selectedFilter != null) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _fetchActivities(),
              style: TextButton.styleFrom(
                backgroundColor: Colors.cyan.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.cyan.withOpacity(0.3)),
                ),
              ),
              child: Text(
                'SHOW ALL ACTIVITIES',
                style: TextStyle(
                  color: Colors.cyan.shade200,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activities.length,
      itemBuilder: (context, index) {
        final activity = _activities[index];
        return CyberActivityTile(activity: activity);
      },
    );
  }
}

class CyberActivityTile extends StatelessWidget {
  final ActivityLog activity;

  const CyberActivityTile({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = activity.getColor(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121A24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: activity.isUnusual
                ? Colors.red.withOpacity(0.5)
                : primaryColor.withOpacity(0.2)
        ),
        boxShadow: [
          BoxShadow(
            color: activity.isUnusual
                ? Colors.red.withOpacity(0.1)
                : Colors.cyan.withOpacity(0.05),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showActivityDetails(context, activity),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Activity Icon with cyberpunk styling
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: primaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.1),
                        blurRadius: 5,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    activity.icon,
                    color: primaryColor.withOpacity(0.9),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),

                // Activity content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: primaryColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              activity.type.toUpperCase(),
                              style: TextStyle(
                                color: primaryColor.withOpacity(0.9),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (activity.isUnusual)
                            Icon(
                              Icons.warning_amber,
                              color: Colors.red.shade400,
                              size: 16,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        activity.description,
                        style: TextStyle(
                          color: Colors.grey.shade200,
                          fontSize: 14,
                          fontWeight: activity.isUnusual
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatDate(activity.timestamp),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          fontFamily: 'monospace',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow indicator
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
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
    final Color primaryColor = activity.getColor(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121A24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: activity.isUnusual
                ? Colors.red.withOpacity(0.5)
                : Colors.cyan.withOpacity(0.3),
            width: 1,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: primaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    activity.icon,
                    color: primaryColor.withOpacity(0.9),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'ACTIVITY DETAILS',
                  style: TextStyle(
                    color: Colors.cyan.shade100,
                    fontSize: 16,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: Colors.cyan.withOpacity(0.2),
            ),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('TYPE', activity.type.toUpperCase()),
            const SizedBox(height: 12),
            _buildDetailRow('DESCRIPTION', activity.description),
            const SizedBox(height: 12),
            _buildDetailRow(
                'TIMESTAMP',
                activity.timestamp.toString(),
                isMonospace: true
            ),
            if (activity.details != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow('DETAILS', activity.details!),
            ],
            if (activity.isUnusual) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: Colors.red.shade400,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'UNUSUAL ACTIVITY DETECTED\nCHANGE YOUR PASSWORD IMMEDIATELY IF UNAUTHORIZED',
                        style: TextStyle(
                          color: Colors.red.shade300,
                          fontSize: 12,
                          height: 1.5,
                          letterSpacing: 0.8,
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: Colors.cyan.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.cyan.withOpacity(0.3)),
              ),
            ),
            child: Text(
              'CLOSE',
              style: TextStyle(
                color: Colors.cyan.shade200,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isMonospace = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.cyan.shade300,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.grey.shade300,
            fontSize: 14,
            fontFamily: isMonospace ? 'monospace' : null,
            height: 1.4,
          ),
        ),
      ],
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
      timestamp: DateTime.parse(
          json['timestamp']), // Backend uses Instant which parses fine
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
      case 'security':
        return Icons.security;
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
