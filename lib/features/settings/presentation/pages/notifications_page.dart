import 'package:flutter/material.dart';

import '../../../../core/widget/bottom_nav_bar.dart';


class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final int _selectedIndex = 4; // Settings tab
  bool _chatNotifications = true;
  bool _requestNotifications = true;
  bool _systemNotifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  void _onItemTapped(int index) {
    if (index != _selectedIndex) {
      Navigator.pop(context);
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
          'NOTIFICATIONS',
          style: theme.appBarTheme.titleTextStyle,
        ),
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back, color: theme.appBarTheme.iconTheme?.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24),
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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Alert preferences
              _buildSectionHeader(
                  'ALERT PREFERENCES', Icons.notifications_active),
              const SizedBox(height: 16),
              _buildSettingsCard(
                children: [
                  _buildSwitchItem(
                    title: 'CHAT MESSAGES',
                    subtitle: 'Get notified when you receive messages',
                    icon: Icons.chat,
                    value: _chatNotifications,
                    onChanged: (value) {
                      setState(() => _chatNotifications = value);
                    },
                  ),
                  Divider(
                      height: 1, color: colorScheme.onSurface.withOpacity(0.1)),
                  _buildSwitchItem(
                    title: 'CONNECTION REQUESTS',
                    subtitle: 'Get notified about new connection requests',
                    icon: Icons.people,
                    value: _requestNotifications,
                    onChanged: (value) {
                      setState(() => _requestNotifications = value);
                    },
                  ),
                  Divider(
                      height: 1, color: colorScheme.onSurface.withOpacity(0.1)),
                  _buildSwitchItem(
                    title: 'SYSTEM NOTIFICATIONS',
                    subtitle: 'Security alerts and important updates',
                    icon: Icons.warning_amber,
                    value: _systemNotifications,
                    onChanged: (value) {
                      setState(() => _systemNotifications = value);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Notification behavior
              _buildSectionHeader(
                  'NOTIFICATION BEHAVIOR', Icons.settings_suggest),
              const SizedBox(height: 16),
              _buildSettingsCard(
                children: [
                  _buildSwitchItem(
                    title: 'SOUND',
                    subtitle: 'Play sound when notifications arrive',
                    icon: Icons.volume_up,
                    value: _soundEnabled,
                    onChanged: (value) {
                      setState(() => _soundEnabled = value);
                    },
                  ),
                  Divider(
                      height: 1, color: colorScheme.onSurface.withOpacity(0.1)),
                  _buildSwitchItem(
                    title: 'VIBRATION',
                    subtitle: 'Vibrate when notifications arrive',
                    icon: Icons.vibration,
                    value: _vibrationEnabled,
                    onChanged: (value) {
                      setState(() => _vibrationEnabled = value);
                    },
                  ),
                  Divider(
                      height: 1, color: colorScheme.onSurface.withOpacity(0.1)),
                  _buildSettingItem(
                    title: 'QUIET HOURS',
                    subtitle: 'Set times when notifications are silenced',
                    icon: Icons.nights_stay,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('This feature is coming soon'),
                          backgroundColor: colorScheme.primary.withOpacity(0.8),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Privacy options
              _buildSectionHeader('PRIVACY', Icons.security),
              const SizedBox(height: 16),
              _buildSettingsCard(
                children: [
                  _buildSettingItem(
                    title: 'NOTIFICATION CONTENT',
                    subtitle: 'Show or hide message content in notifications',
                    icon: Icons.visibility,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('This feature is coming soon'),
                          backgroundColor: colorScheme.primary.withOpacity(0.8),
                        ),
                      );
                    },
                  ),
                  Divider(
                      height: 1, color: colorScheme.onSurface.withOpacity(0.1)),
                  _buildSettingItem(
                    title: 'NOTIFICATION HISTORY',
                    subtitle: 'View and manage past notifications',
                    icon: Icons.history,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('This feature is coming soon'),
                          backgroundColor: colorScheme.primary.withOpacity(0.8),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Reset button
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 40),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: -5,
                      ),
                    ],
                  ),
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _chatNotifications = true;
                        _requestNotifications = true;
                        _systemNotifications = true;
                        _soundEnabled = true;
                        _vibrationEnabled = true;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                              'Notification settings reset to defaults'),
                          backgroundColor: colorScheme.primary.withOpacity(0.8),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: BorderSide(
                            color: colorScheme.primary.withOpacity(0.3)),
                      ),
                    ),
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text(
                      'RESET TO DEFAULTS',
                      style: TextStyle(
                        letterSpacing: 1.5,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w400,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.03),
            blurRadius: 15,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.surface.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: colorScheme.primary.withOpacity(0.2), width: 1),
        ),
        child: Icon(
          icon,
          size: 18,
          color: colorScheme.primary,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w500,
          color: theme.textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
      ),
      trailing: trailing ??
          (onTap == null
              ? null
              : Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                )),
      onTap: onTap,
    );
  }

  Widget _buildSwitchItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.surface.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: colorScheme.primary.withOpacity(0.2), width: 1),
        ),
        child: Icon(
          icon,
          size: 18,
          color: colorScheme.primary,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w500,
          color: theme.textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: colorScheme.secondary,
        activeTrackColor: colorScheme.secondary.withOpacity(0.3),
      ),
    );
  }
}
