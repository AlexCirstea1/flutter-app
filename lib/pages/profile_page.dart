import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/environment.dart';
import '../config/logger_config.dart';
import '../services/auth_service.dart';
import '../services/avatar_service.dart';
import '../services/storage_service.dart';
import '../utils/key_cert_helper.dart';
import '../widget/bottom_nav_bar.dart';
import '../widget/user_role_chip.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _selectedIndex = 2;
  bool _isLoading = true;
  String _username = '';
  String _email = '';
  bool _hasPin = false;
  Uint8List? _avatarBytes;
  String? _userId;

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
            _username = userData['username'] ?? 'N/A';
            _email = userData['email'] ?? 'N/A';
            _hasPin = userData['hasPin'] ?? false;
            _userId = userId; // Store the userId
            _isLoading = false;
          });

          if (userData['id'] != null) {
            await _fetchAvatar(userData['id']);
          }
        }
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAvatar(String userId) async {
    final avatarService = AvatarService(_storageService);
    final bytes = await avatarService.getAvatar(userId);
    setState(() => _avatarBytes = bytes);
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _logout() async {
    final token = await _storageService.getAccessToken();
    if (token != null && await _authService.logout(token)) {
      await _storageService.clearLoginDetails();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logout failed')),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final token = await _storageService.getAccessToken();
    if (token != null && await _authService.deleteAccount(token)) {
      await _storageService.clearLoginDetails();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deletion failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.primary,
        foregroundColor: theme.onPrimary,
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundColor: theme.primary,
                    backgroundImage: _avatarBytes != null
                        ? MemoryImage(_avatarBytes!)
                        : null,
                    child: _avatarBytes == null
                        ? const Icon(Icons.person,
                            size: 55, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _username,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: theme.onSurface,
                    ),
                  ),
                  UserRoleChip(userId: _userId),
                  const SizedBox(height: 8),
                  Text(
                    _email,
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                        onPressed: () => _confirmDelete(context),
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
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 52),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/about');
                      },
                      child: const Text(
                        'About this app',
                        style: TextStyle(
                          color: Color(0xB5D8FFFF),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  // Confirmation dialog before account deletion
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account?'),
        content:
            const Text('This action is irreversible. Do you wish to proceed?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _rotateKeys() async {
    setState(() => _isLoading = true);
    try {
      final (privatePem, _, publicPem) =
          await KeyCertHelper.generateSelfSignedCert(
        dn: {'CN': _username},
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
          // Extract the key version from the response
          final keyVersion = response.body;

          // Save private key with version
          await _storageService.savePrivateKey(keyVersion, privatePem);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Encryption keys rotated successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload new public key')),
          );
        }
      }
    } catch (e) {
      LoggerService.logError('Key rotation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to rotate encryption keys')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
