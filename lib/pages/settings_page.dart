import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/environment.dart';
import '../services/auth_service.dart';
import '../services/service_locator.dart';
import '../services/storage_service.dart';
import '../utils/key_cert_helper.dart';
import '../widget/bottom_nav_bar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _selectedIndex = 4;
  bool _isGeneratingKeys = false;
  bool _isLoadingUserId = true;
  String? _userId;

  final StorageService _storageService = StorageService();
  final AuthService _authService = serviceLocator<AuthService>();

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final userId = await _storageService.getUserId();
    setState(() {
      _userId = userId;
      _isLoadingUserId = false;
    });
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _logout() async {
    final token = await _storageService.getAccessToken();
    if (token != null) {
      final success = await _authService.logout(token);
      if (success && mounted) {
        await _storageService.clearLoginDetails();
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    }
  }

  Future<void> _regenerateKeys() async {
    setState(() => _isGeneratingKeys = true);
    try {
      // Generate the keys and certificate using records (Dart 3+)
      final (privatePem, certificatePem, publicPem) =
          await KeyCertHelper.generateSelfSignedCert();

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
          await _storageService.saveCertificate(keyVersion, certificatePem);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Security keys regenerated successfully'),
                backgroundColor: Colors.green.shade800,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Failed to update public key on server'),
                backgroundColor: Colors.red.shade800,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to regenerate keys: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      setState(() => _isGeneratingKeys = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'SETTINGS',
          style: TextStyle(
            fontSize: 16,
            letterSpacing: 2.0,
            fontWeight: FontWeight.w300,
            color: Colors.cyan.shade100,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Color(0xFF101720)],
          ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Security section
              _buildSectionHeader('SECURITY SETTINGS', Icons.security),
              const SizedBox(height: 16),
              _buildSettingsCard(
                children: [
                  _buildSettingItem(
                    title: 'REGENERATE SECURITY KEYS',
                    subtitle: 'Create new encryption keys for your account',
                    icon: Icons.vpn_key_rounded,
                    onTap: _isGeneratingKeys ? null : _regenerateKeys,
                    trailing: _isGeneratingKeys
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.cyanAccent,
                            ),
                          )
                        : Icon(
                            Icons.refresh,
                            size: 18,
                            color: Colors.cyan.shade300,
                          ),
                  ),
                  const Divider(height: 1, color: Color(0xFF1A2530)),
                  _buildSettingItem(
                    title: 'SETUP PIN',
                    subtitle: 'Configure a security PIN code for the app',
                    icon: Icons.pin,
                    onTap: () {
                      Navigator.pushNamed(context, '/pin-setup');
                    },
                  ),
                  const Divider(height: 1, color: Color(0xFF1A2530)),
                  _buildSettingItem(
                    title: 'BIOMETRIC AUTHENTICATION',
                    subtitle: 'Use fingerprint or face recognition',
                    icon: Icons.fingerprint,
                    onTap: () {
                      Navigator.pushNamed(context, '/biometric-setup');
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Account section
              _buildSectionHeader('ACCOUNT MANAGEMENT', Icons.account_circle),
              const SizedBox(height: 16),
              _buildSettingsCard(
                children: [
                  _buildSettingItem(
                    title: 'USER ID',
                    subtitle: _isLoadingUserId
                        ? 'Loading...'
                        : _userId?.substring(0, 10) ?? 'Not available',
                    icon: Icons.perm_identity,
                    titleStyle: TextStyle(
                      color: Colors.grey.shade300,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    subtitleStyle: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    onTap: null,
                  ),
                  const Divider(height: 1, color: Color(0xFF1A2530)),
                  _buildSettingItem(
                    title: 'EDIT PROFILE',
                    subtitle: 'Change your username and details',
                    icon: Icons.edit,
                    onTap: () {
                      Navigator.pushNamed(context, '/edit-profile');
                    },
                  ),
                  const Divider(height: 1, color: Color(0xFF1A2530)),
                  _buildSettingItem(
                    title: 'BLOCKCHAIN CONSENT',
                    subtitle: 'Manage your consent for blockchain features',
                    icon: Icons.link,
                    onTap: () {
                      Navigator.pushNamed(context, '/blockchain-consent');
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // App settings section
              _buildSectionHeader('APPLICATION', Icons.settings),
              const SizedBox(height: 16),
              _buildSettingsCard(
                children: [
                  _buildSettingItem(
                    title: 'NOTIFICATIONS',
                    subtitle: 'Configure message notifications',
                    icon: Icons.notifications,
                    onTap: () {
                      Navigator.pushNamed(context, '/notifications');
                    },
                  ),
                  const Divider(height: 1, color: Color(0xFF1A2530)),
                  _buildSettingItem(
                    title: 'THEME SETTINGS',
                    subtitle: 'Customize app appearance',
                    icon: Icons.color_lens,
                    onTap: () {
                      Navigator.pushNamed(context, '/theme-settings');
                    },
                  ),
                  const Divider(height: 1, color: Color(0xFF1A2530)),
                  _buildSettingItem(
                    title: 'PRIVACY POLICY',
                    subtitle: 'Review our privacy terms',
                    icon: Icons.privacy_tip,
                    onTap: () {
                      Navigator.pushNamed(context, '/privacy-policy');
                    },
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Logout section
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 40),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: -5,
                      ),
                    ],
                  ),
                  child: TextButton.icon(
                    onPressed: _logout,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: BorderSide(
                            color: Colors.redAccent.withOpacity(0.3)),
                      ),
                    ),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text(
                      'SECURE LOGOUT',
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.cyan.shade400),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w400,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121A24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyan.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.03),
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
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.cyan.withOpacity(0.2), width: 1),
        ),
        child: Icon(
          icon,
          size: 18,
          color: Colors.cyan.shade200,
        ),
      ),
      title: Text(
        title,
        style: titleStyle ??
            TextStyle(
              fontSize: 13,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade300,
            ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: subtitleStyle ??
              TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
        ),
      ),
      trailing: trailing ??
          (onTap == null
              ? null
              : Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey.shade600,
                )),
      onTap: onTap,
    );
  }
}
