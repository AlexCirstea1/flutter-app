import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/certificate_info.dart';
import '../services/auth_service.dart';
import '../services/avatar_service.dart';
import '../services/service_locator.dart';
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

  final AuthService _authService = serviceLocator<AuthService>();
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
            _blockchainConsent =
                userData['blockchainConsent'] as bool? ?? false;
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
          'PROFILE',
          style: theme.appBarTheme.titleTextStyle,
        ),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.secondary))
          : Container(
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
            children: [
              const SizedBox(height: 20),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.secondary, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.secondary.withOpacity(0.15),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: colorScheme.surface.withOpacity(0.5),
                    backgroundImage: _avatarBytes != null
                        ? MemoryImage(_avatarBytes!)
                        : null,
                    child: _avatarBytes == null
                        ? Icon(Icons.person, size: 50, color: colorScheme.secondary)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                _username,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1.5,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              UserRoleChip(userId: _userId),
              const SizedBox(height: 8),
              Text(
                _email,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
              _buildBlockchainConsentIndicator(),
              const SizedBox(height: 30),
              _buildCertificateSection(),
              const SizedBox(height: 60),
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/about');
                },
                child: Text(
                  '// ABOUT THIS APP',
                  style: TextStyle(
                    color: colorScheme.primary.withOpacity(0.7),
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 40),
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

  Widget _buildBlockchainConsentIndicator() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final consentColor = _blockchainConsent
        ? colorScheme.secondary
        : theme.textTheme.bodyMedium?.color?.withOpacity(0.5);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _blockchainConsent
            ? colorScheme.secondary.withOpacity(0.15)
            : theme.textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _blockchainConsent
              ? colorScheme.secondary.withOpacity(0.3)
              : theme.textTheme.bodyMedium?.color?.withOpacity(0.1) ?? Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _blockchainConsent ? Icons.link : Icons.link_off,
            size: 16,
            color: consentColor,
          ),
          const SizedBox(width: 8),
          Text(
            _blockchainConsent ? 'BLOCKCHAIN ENABLED' : 'NO BLOCKCHAIN',
            style: TextStyle(
              color: consentColor,
              fontWeight: FontWeight.w400,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateSection() {
    if (_certificateInfo == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dn = _certificateInfo!.distinguishedName;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
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
                'SECURITY CERTIFICATE',
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
                ? colorScheme.error
                : _certificateInfo!.daysRemaining < 90
                ? Colors.orange
                : colorScheme.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildCertInfoRow(String label, String value, {Color? textColor}) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.5,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              fontFamily: 'monospace',
              color: textColor ?? theme.textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }
}
