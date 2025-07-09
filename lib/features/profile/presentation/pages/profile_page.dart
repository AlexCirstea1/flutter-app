import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/data/services/service_locator.dart';
import '../../../../core/data/services/storage_service.dart';
import '../../../../core/domain/models/certificate_info.dart';
import '../../../../core/utils/key_cert_helper.dart';
import '../../../../core/widget/bottom_nav_bar.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../chat/presentation/widgets/user_role_chip.dart';
import '../../data/services/avatar_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const cacheDuration = Duration(hours: 2);
  DateTime? _lastProfileFetch;
  DateTime? _lastCertFetch;

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
    _loadProfileData(useCache: true);
  }

  Future<void> _loadProfileData({bool useCache = true}) async {
    setState(() => _isLoading = true);

    await Future.wait([
      _fetchUserData(useCache: useCache),
      _loadCertificateInfo(useCache: useCache),
    ]);

    setState(() => _isLoading = false);
  }

  Future<void> _loadCertificateInfo({bool useCache = true}) async {
    // Use cached certificate if available and valid
    if (useCache &&
        _certificateInfo != null &&
        _lastCertFetch != null &&
        DateTime.now().difference(_lastCertFetch!) < cacheDuration) {
      return;
    }

    final certificate = await _storageService.getCertificate();
    if (certificate != null) {
      final certInfo = KeyCertHelper.parseCertificate(certificate);

      if (mounted) {
        setState(() {
          _certificateInfo = certInfo;
          _lastCertFetch = DateTime.now();
        });
      }

      // Cache locally for future use
      await _storageService.setObject('cached_certificate_info', certInfo.toJson());
      await _storageService.setString('cert_cache_time', DateTime.now().toIso8601String());
    }
  }

  Future<void> _fetchUserData({bool useCache = true}) async {
    try {
      // Try to load from cache first
      if (useCache) {
        final cachedData = await _storageService.getObject('cached_profile_data');
        final cacheTimeStr = await _storageService.getString('profile_cache_time');

        if (cachedData != null && cacheTimeStr != null) {
          final cacheTime = DateTime.parse(cacheTimeStr);
          if (DateTime.now().difference(cacheTime) < cacheDuration) {
            setState(() {
              _username = cachedData['username'] ?? 'N/A';
              _email = cachedData['email'] ?? 'N/A';
              _hasPin = cachedData['hasPin'] ?? false;
              _userId = cachedData['userId'];
              _blockchainConsent = cachedData['blockchainConsent'] ?? false;
              _lastProfileFetch = cacheTime;
            });

            // Load cached avatar
            final cachedAvatar = await _storageService.getBytes('cached_avatar_${_userId}');
            if (cachedAvatar != null) {
              setState(() => _avatarBytes = cachedAvatar);
              return; // Exit if we successfully loaded from cache
            }
          }
        }
      }

      // Fetch from network if cache is invalid or we're forcing refresh
      final accessToken = await _storageService.getAccessToken();
      if (accessToken != null) {
        final userData = await _authService.getUserData(accessToken);
        if (userData != null) {
          final userId = await _storageService.getUserId();

          setState(() {
            _username = userData['username'] ?? 'N/A';
            _email = userData['email'] ?? 'N/A';
            _hasPin = userData['hasPin'] ?? false;
            _userId = userId;
            _blockchainConsent = userData['blockchainConsent'] as bool? ?? false;
            _lastProfileFetch = DateTime.now();
          });

          // Cache the profile data
          await _storageService.setObject('cached_profile_data', {
            'username': _username,
            'email': _email,
            'hasPin': _hasPin,
            'userId': _userId,
            'blockchainConsent': _blockchainConsent,
          });
          await _storageService.setString('profile_cache_time', DateTime.now().toIso8601String());

          if (userData['id'] != null) {
            await _fetchAvatar(userData['id']);
          }
        }
      }
    } catch (e) {
      // If network fetch fails, try using any available cache as fallback
      final cachedData = await _storageService.getObject('cached_profile_data');
      if (cachedData != null) {
        setState(() {
          _username = cachedData['username'] ?? 'N/A';
          _email = cachedData['email'] ?? 'N/A';
          _hasPin = cachedData['hasPin'] ?? false;
          _userId = cachedData['userId'];
          _blockchainConsent = cachedData['blockchainConsent'] ?? false;
        });

        final cachedAvatar = await _storageService.getBytes('cached_avatar_${_userId}');
        if (cachedAvatar != null) {
          setState(() => _avatarBytes = cachedAvatar);
        }
      }
    }
  }

  Future<void> _fetchAvatar(String userId) async {
    final avatarService = AvatarService(_storageService);
    final bytes = await avatarService.getAvatar(userId);
    if (bytes != null) {
      setState(() => _avatarBytes = bytes);
      // Cache the avatar
      await _storageService.setBytes('cached_avatar_$userId', bytes);
    }
  }

  // Add refresh function for pull-to-refresh or button press
  Future<void> refreshProfileData() async {
    await _loadProfileData(useCache: false);
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;

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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: refreshProfileData,
            tooltip: 'Refresh Profile',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: colorScheme.secondary))
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              width: double.infinity,
              height: size.height -
                  kToolbarHeight -
                  kBottomNavigationBarHeight -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
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
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(height: 10),
                  // Avatar and user info
                  Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: colorScheme.secondary, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      colorScheme.secondary.withOpacity(0.15),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),
                          CircleAvatar(
                            radius: 45,
                            backgroundColor:
                                colorScheme.surface.withOpacity(0.5),
                            backgroundImage: _avatarBytes != null
                                ? MemoryImage(_avatarBytes!)
                                : null,
                            child: _avatarBytes == null
                                ? Icon(Icons.person,
                                    size: 45, color: colorScheme.secondary)
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _username,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1.5,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      UserRoleChip(userId: _userId),
                      const SizedBox(height: 6),
                      Text(
                        _email,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                      _buildBlockchainConsentIndicator(),
                    ],
                  ),

                  // Certificate section
                  _buildCertificateSection(),
                ],
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
            : theme.textTheme.bodyMedium?.color?.withOpacity(0.05) ??
                Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _blockchainConsent
              ? colorScheme.secondary.withOpacity(0.3)
              : theme.textTheme.bodyMedium?.color?.withOpacity(0.1) ??
                  Colors.transparent,
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
          _buildCertInfoRow(
              'RSA Key Size', '${_certificateInfo!.keySize} bits'),
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
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 0.5,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                fontFamily: 'monospace',
                color: textColor ?? theme.textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
