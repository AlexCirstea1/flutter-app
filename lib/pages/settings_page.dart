import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/environment.dart';
import '../config/logger_config.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../utils/key_cert_helper.dart';
import '../widget/bottom_nav_bar.dart';

// Example "SettingsPage" to contain account & security actions.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _selectedIndex = 2; // Suppose "Settings" is index 3
  bool _isLoading = false;
  bool _hasPin = false;
  String? _userId;

  // Example toggles for new features
  bool _darkMode = false;
  bool _notificationsEnabled = true;

  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final accessToken = await _storageService.getAccessToken();
      if (accessToken != null) {
        final userData = await _authService.getUserData(accessToken);
        if (userData != null) {
          // Get the userId and store it
          final userId = await _storageService.getUserId();

          setState(() {
            _hasPin = userData['hasPin'] ?? false;
            _userId = userId;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _rotateKeys() async {
    setState(() => _isLoading = true);
    try {
      // Suppose you have the username. If needed, fetch from secure storage or pass in from profile
      final username = (await _storageService.getUsername()) ?? 'User';

      final (privatePem, _, publicPem) =
          await KeyCertHelper.generateSelfSignedCert(
        dn: {'CN': username},
        keySize: 2048,
        daysValid: 365,
      );

      final token = await _storageService.getAccessToken();
      if (token != null) {
        final response = await http.post(
          Uri.parse('${Environment.apiBaseUrl}/user/publicKey'),
          headers: {
            'Content-Type': 'text/plain',
            'Authorization': 'Bearer $token'
          },
          body: publicPem,
        );

        if (response.statusCode == 200) {
          final keyVersion = response.body;
          await _storageService.savePrivateKey(keyVersion, privatePem);
          _showSnackBar('Encryption keys rotated successfully');
        } else {
          _showSnackBar('Failed to upload new public key');
        }
      }
    } catch (e) {
      LoggerService.logError('Key rotation error', e);
      _showSnackBar('Failed to rotate encryption keys');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final token = await _storageService.getAccessToken();
    if (token != null && await _authService.logout(token)) {
      await _storageService.clearLoginDetails();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } else {
      _showSnackBar('Logout failed');
    }
  }

  Future<void> _deleteAccount() async {
    final token = await _storageService.getAccessToken();
    if (token != null && await _authService.deleteAccount(token)) {
      await _storageService.clearLoginDetails();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } else {
      _showSnackBar('Account deletion failed');
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text('This action is irreversible. Proceed?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
          ),
        ],
      ),
    );
  }

  //endregion

  //region: Example new toggles (Dark Mode, Notifications)
  Future<void> _toggleDarkMode(bool value) async {
    setState(() {
      _darkMode = value;
    });
    // If you want to store this preference:
    // await _storageService.saveInStorage('darkMode', value.toString());
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });
    // If you want to store this preference:
    // await _storageService.saveInStorage('notifications', value.toString());
  }
  //endregion

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    // If index == 2, go to Profile, etc.
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: theme.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.primary,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  //region: Existing security actions
                  ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/set-pin'),
                    icon: Icon(_hasPin ? Icons.refresh : Icons.pin),
                    label: Text(_hasPin ? 'Reset PIN' : 'Set PIN'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.secondary,
                      foregroundColor: theme.onSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: _rotateKeys,
                    icon: const Icon(Icons.key),
                    label: const Text('Rotate Encryption Keys'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.secondary,
                      foregroundColor: theme.onSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: _confirmDelete,
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete Account'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  //endregion

                  const SizedBox(height: 40),

                  //region: Example new toggles or settings
                  Text(
                    'App Preferences',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),

                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    value: _darkMode,
                    onChanged: _toggleDarkMode,
                  ),
                  SwitchListTile(
                    title: const Text('Notifications'),
                    value: _notificationsEnabled,
                    onChanged: _toggleNotifications,
                  ),
                  //endregion

                  // Additional placeholders for future features...
                ],
              ),
            ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
