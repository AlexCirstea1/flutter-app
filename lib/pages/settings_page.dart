import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../config/environment.dart';
import '../services/auth_service.dart';
import '../services/service_locator.dart';
import '../services/storage_service.dart';
import '../theme/theme_provider.dart';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'SETTINGS',
          style: theme.appBarTheme.titleTextStyle,
        ),
        automaticallyImplyLeading: false,
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
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.secondary,
                            ),
                          )
                        : Icon(
                            Icons.refresh,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                  ),
                  Divider(
                      height: 1, color: colorScheme.onSurface.withOpacity(0.1)),
                  _buildSettingItem(
                    title: 'SETUP PIN',
                    subtitle: 'Configure a security PIN code for the app',
                    icon: Icons.pin,
                    onTap: () {
                      Navigator.pushNamed(context, '/set-pin');
                    },
                  ),
                  Divider(
                      height: 1, color: colorScheme.onSurface.withOpacity(0.1)),
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
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    subtitleStyle: TextStyle(
                      color: colorScheme.secondary,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    onTap: null,
                  ),
                  Divider(
                      height: 1, color: colorScheme.onSurface.withOpacity(0.1)),
                  _buildSettingItem(
                    title: 'EDIT PROFILE',
                    subtitle: 'Change your username and details',
                    icon: Icons.edit,
                    onTap: () {
                      Navigator.pushNamed(context, '/edit-profile');
                    },
                  ),
                  Divider(
                      height: 1, color: colorScheme.onSurface.withOpacity(0.1)),
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
                  Divider(
                      height: 1, color: colorScheme.onSurface.withOpacity(0.1)),
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, child) {
                      return _buildSettingItem(
                        title: 'THEME',
                        subtitle: _getThemeModeText(themeProvider.themeMode),
                        icon: Icons.color_lens,
                        onTap: () {
                          themeProvider.toggleTheme();
                        },
                        trailing: _getThemeModeIcon(themeProvider.themeMode),
                      );
                    },
                  ),
                  Divider(
                      height: 1, color: colorScheme.onSurface.withOpacity(0.1)),
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
                        color: colorScheme.error.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: -5,
                      ),
                    ],
                  ),
                  child: TextButton.icon(
                    onPressed: _logout,
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: BorderSide(
                            color: colorScheme.error.withOpacity(0.3)),
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
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
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
        style: titleStyle ??
            TextStyle(
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
          style: subtitleStyle ??
              TextStyle(
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

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System default (current device settings)';
      case ThemeMode.light:
        return 'Light mode';
      case ThemeMode.dark:
        return 'Dark mode';
    }
  }

  Widget _getThemeModeIcon(ThemeMode mode) {
    final colorScheme = Theme.of(context).colorScheme;

    IconData iconData;
    switch (mode) {
      case ThemeMode.system:
        iconData = Icons.brightness_auto;
        break;
      case ThemeMode.light:
        iconData = Icons.brightness_7;
        break;
      case ThemeMode.dark:
        iconData = Icons.brightness_2;
        break;
    }

    return Icon(
      iconData,
      size: 20,
      color: colorScheme.primary,
    );
  }
}
