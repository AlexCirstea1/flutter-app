import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/environment.dart';
import '../config/logger_config.dart';
import '../models/certificate_info.dart';
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
  CertificateInfo? _certificateInfo;
  int _selectedIndex = 1;
  bool _isLoading = true;
  String _username = '';
  String _email = '';
  bool _hasPin = false;
  bool _blockchainConsent = false;
  Uint8List? _avatarBytes;
  String? _userId;

  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _loadCertificateInfo();
  }

  Future<void> _loadCertificateInfo() async {
    final certificate = await _storageService.getCertificate();
    final certInfo = KeyCertHelper.parseCertificate(certificate!);

    if (mounted) {
      setState(() {
        _certificateInfo = certInfo;
      });
    }
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
            _blockchainConsent = userData['blockchainConsent'] as bool? ?? false;
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

  Widget _buildCertificateInfo() {
    if (_certificateInfo == null) {
      return const SizedBox.shrink();
    }

    final dn = _certificateInfo!.distinguishedName;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Security Certificate',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const Divider(),
            _buildCertInfoRow('Common Name', dn.commonName),
            _buildCertInfoRow('Organization', dn.organization ?? 'N/A'),
            _buildCertInfoRow('Department', dn.organizationalUnit ?? 'N/A'),
            _buildCertInfoRow('State', dn.state ?? 'N/A'),
            _buildCertInfoRow('RSA Key Size', '${_certificateInfo!.keySize} bits'),
            _buildCertInfoRow(
              'Expires In',
              _certificateInfo!.isExpired
                  ? 'Expired'
                  : '${_certificateInfo!.daysRemaining} days',
              textColor: _certificateInfo!.daysRemaining < 30
                  ? Colors.red
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertInfoRow(String label, String value, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textColor ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
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
          : Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top section with profile info
            Column(
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
                _buildBlockchainConsentIndicator(),
                const SizedBox(height: 8),
                Text(
                  _email,
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 20),
                _buildCertificateInfo(),
                const SizedBox(height: 40),
              ],
            ),

            // Bottom section with "About this app"
            GestureDetector(
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
