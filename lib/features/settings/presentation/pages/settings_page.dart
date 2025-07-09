import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../../core/config/environment.dart';
import '../../../../core/data/services/service_locator.dart';
import '../../../../core/data/services/storage_service.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/key_cert_helper.dart';
import '../../../../core/widget/bottom_nav_bar.dart';
import '../../../../core/widget/consent_dialog.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../auth/data/services/biometric_auth_service.dart';
import '../../../blockchain/presentation/pages/learn_more_page.dart';

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

  bool _bioEnabled = false;
  bool _bioAvail = false;

  final StorageService _storageService = StorageService();
  final AuthService _authService = serviceLocator<AuthService>();

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _loadBiometricPref();
  }

  Future<void> _loadBiometricPref() async {
    _bioEnabled = await _storageService.isBiometricEnabled();
    _bioAvail = await BiometricAuthService().isAvailable();
    if (mounted) setState(() {});
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

  Future<void> _showBlockchainConsentDialog() async {
    // First get the current consent status to show the initial state
    final currentConsent =
        await _storageService.getFromStorage('blockchainConsent');
    final initialConsent = currentConsent == 'true';

    try {
      // Show the consent dialog and wait for user decision
      final consentGiven = await showDialog<bool>(
        context: context,
        barrierDismissible: false, // Force the user to decide
        builder: (context) => ConsentDialog(
          onConsentGiven: () {
            Navigator.of(context).pop(true);
          },
          onConsentDenied: () {
            Navigator.of(context).pop(false);
          },
          onLearnMore: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LearnMorePage()),
            );
          },
        ),
      );

      // Default to current consent if dialog is dismissed unexpectedly
      final bool consent = consentGiven ?? initialConsent;

      // Only update if consent changed
      if (consent != initialConsent) {
        // Update consent on backend
        await _updateBlockchainConsent(consent);

        // Save consent locally
        await _storageService.saveInStorage(
            'blockchainConsent', consent ? 'true' : 'false');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Blockchain consent ${consent ? 'enabled' : 'disabled'}'),
              backgroundColor: Colors.green.shade800,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update consent: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  Future<void> _updateBlockchainConsent(bool consent) async {
    final token = await _storageService.getAccessToken();
    if (token == null) {
      throw Exception('Authentication required');
    }

    final url = Uri.parse(
        '${Environment.apiBaseUrl}/user/blockchain-consent?consent=$consent');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to update consent status: ${response.statusCode}');
    }
  }

  Future<void> _setBiometric(bool enabled) async {
    await _storageService.setBiometricEnabled(enabled);
    if (mounted) setState(() => _bioEnabled = enabled);
  }

  Widget _buildBiometricItem() {
    final cs = Theme.of(context).colorScheme;

    if (!_bioAvail) {
      return _buildSettingItem(
        title: 'BIOMETRIC AUTHENTICATION',
        subtitle: 'Not available on this device',
        icon: Icons.not_interested,
        onTap: null,
        trailing: null,
        titleStyle: TextStyle(
          fontSize: 13,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w500,
          color: cs.error,
        ),
        subtitleStyle: TextStyle(
          fontSize: 12,
          color: cs.error.withOpacity(0.7),
        ),
      );
    }

    return _buildSettingItem(
      title: 'BIOMETRIC AUTHENTICATION',
      subtitle: _bioEnabled ? 'Enabled' : 'Disabled',
      icon: Icons.fingerprint,
      onTap: () async {
        await _setBiometric(!_bioEnabled);
      },
      trailing: null,
      titleStyle: TextStyle(
        fontSize: 13,
        letterSpacing: 0.5,
        fontWeight: FontWeight.w500,
        color: _bioEnabled ? cs.primary : cs.onSurface.withOpacity(0.6),
      ),
      subtitleStyle: TextStyle(
        fontSize: 12,
        color: _bioEnabled
            ? cs.primary.withOpacity(0.8)
            : cs.onSurface.withOpacity(0.7),
      ),
    );
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
                  _buildBiometricItem()
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
                    onTap: _showBlockchainConsentDialog,
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
                        subtitle: _getThemeText(themeProvider.option),
                        icon: Icons.color_lens,
                        onTap: themeProvider.toggleTheme,
                        trailing: _getThemeIcon(themeProvider.option),
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
                  Divider(
                      height: 1, color: colorScheme.onSurface.withOpacity(0.1)),
                  _buildSettingItem(
                    title: 'ABOUT',
                    subtitle: 'About this application',
                    icon: Icons.info_outline,
                    onTap: () {
                      Navigator.pushNamed(context, '/about');
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
          color: theme.iconTheme.color, // ensures contrast
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

  String _getThemeText(AppThemeOption opt) {
    switch (opt) {
      case AppThemeOption.system:
        return 'System default';
      case AppThemeOption.light:
        return 'Light mode';
      case AppThemeOption.dark:
        return 'Dark mode';
      case AppThemeOption.cyber:
        return 'Cyber / Hacker';
    }
  }

  Widget _getThemeIcon(AppThemeOption opt) {
    final cs = Theme.of(context).colorScheme;
    final icon = switch (opt) {
      AppThemeOption.system => Icons.brightness_auto,
      AppThemeOption.light => Icons.brightness_7,
      AppThemeOption.dark => Icons.brightness_2,
      AppThemeOption.cyber => Icons.terminal, // cool hacker glyph
    };
    return Icon(icon, size: 20, color: cs.primary);
  }
}
