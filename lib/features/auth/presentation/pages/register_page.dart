import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/environment.dart';
import '../../../../core/config/logger_config.dart';
import '../../../../core/data/services/dummy_password_store.dart';
import '../../../../core/data/services/service_locator.dart';
import '../../../../core/data/services/storage_service.dart';
import '../../../../core/utils/key_cert_helper.dart';
import '../../../../core/widget/consent_dialog.dart';
import '../../../blockchain/presentation/pages/learn_more_page.dart';
import '../../data/services/auth_service.dart';
import '../../domain/models/user.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;

  final AuthService _authService = serviceLocator<AuthService>();
  final StorageService _storageService = StorageService();

  void _register() {
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match!')),
      );
      return;
    }

    final newUser = User(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    _registerUser(newUser);
  }

  Future<void> _registerUser(User user) async {
    setState(() => _isLoading = true);

    try {
      bool success = await _authService.registerUser(
          user.username, user.email, user.password);
      if (success) {
        await _loginUser(user);
      } else {
        _showError('Registration failed. Please try again.');
      }
    } catch (e) {
      LoggerService.logError('Registration error: $e');
      _showError('An error occurred during registration.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loginUser(User user) async {
    try {
      final response =
          await _authService.loginUser(user.username, user.password);
      if (response != null &&
          await _authService.saveUserData(response, _storageService)) {
        await _generateAndUploadKeys();

        final userId = response['user']?['id'] as String?;
        if (userId != null) {
          await _storageService.addRecentAccount(userId);
        }

        // Show the consent dialog after registration is complete.
        final consentGiven = await showDialog<bool>(
          context: context,
          barrierDismissible: false, // Force the user to decide.
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

        // Default to false if the dialog is dismissed unexpectedly.
        final bool consent = consentGiven ?? false;

        // Send the consent decision to the backend.
        await _updateBlockchainConsent(consent);

        // Save the decision locally (for example, for later use in the app).
        await _storageService.saveInStorage(
            'blockchainConsent', consent ? 'true' : 'false');

        // Proceed to home page.
        Navigator.pushNamed(context, '/home');
      } else {
        _showError('Login failed after registration.');
      }
    } catch (e) {
      LoggerService.logError('Login after registration error: $e');
      _showError('An error occurred during login.');
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

  Future<void> _generateAndUploadKeys() async {
    final (privatePem, certificatePem, publicPem) =
        await KeyCertHelper.generateSelfSignedCert();

    final token = await _storageService.getAccessToken();
    final response = await http.post(
      Uri.parse('${Environment.apiBaseUrl}/user/publicKey'),
      headers: {'Content-Type': 'text/plain', 'Authorization': 'Bearer $token'},
      body: publicPem,
    );

    if (response.statusCode == 200) {
      // Extract the key version from the response
      final keyVersion = response.body;

      // Save private key with version
      await _storageService.savePrivateKey(keyVersion, privatePem);

      // Save certificate with the same version
      await _storageService.saveCertificate(keyVersion, certificatePem);
    }
  }

  Future<void> _registerDummyUser() async {
    final dummyPassword = _generateRandomPassword(12);
    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic>? userJson =
          await _authService.registerDummyUser(dummyPassword);
      if (userJson != null) {
        final dummyUser = User(
          username: userJson['username'] as String,
          email: userJson['email'] as String,
          password: dummyPassword,
        );
        // Store generated password in memory.
        DummyPasswordStore.setPassword(dummyUser.username, dummyPassword);
        await _loginUser(dummyUser);
      } else {
        _showError('Dummy registration failed.');
      }
    } catch (e) {
      LoggerService.logError('Dummy registration error: $e');
      _showError('An error occurred during dummy registration.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _generateRandomPassword(int length) {
    const charset =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      resizeToAvoidBottomInset: true,
      body: Container(
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
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        constraints.maxHeight - 48, // Account for padding
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo with glow effect
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(0.25),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.shield_outlined,
                            size: 70,
                            color: colorScheme.primary,
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Title with theme styling
                        Text(
                          'SECURE REGISTRATION',
                          style: TextStyle(
                            fontSize: 20,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w300,
                            color: colorScheme.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 40),

                        // Username field with theme styling
                        Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: colorScheme.primary.withOpacity(0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(0.05),
                                blurRadius: 10,
                                spreadRadius: -5,
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _usernameController,
                            style: theme.textTheme.bodyLarge,
                            decoration: InputDecoration(
                              labelText: 'USERNAME',
                              labelStyle: TextStyle(
                                color: theme.textTheme.bodyMedium?.color,
                                fontSize: 12,
                                letterSpacing: 1.0,
                                fontWeight: FontWeight.w400,
                              ),
                              prefixIcon: Icon(Icons.person,
                                  color: colorScheme.primary, size: 20),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Email field with theme styling
                        Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: colorScheme.primary.withOpacity(0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(0.05),
                                blurRadius: 10,
                                spreadRadius: -5,
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _emailController,
                            style: TextStyle(
                              color: theme.textTheme.bodyLarge?.color,
                              fontFamily: 'monospace',
                            ),
                            decoration: InputDecoration(
                              labelText: 'EMAIL',
                              labelStyle: TextStyle(
                                color: theme.textTheme.bodyMedium?.color,
                                fontSize: 12,
                                letterSpacing: 1.0,
                                fontWeight: FontWeight.w400,
                              ),
                              prefixIcon: Icon(Icons.email,
                                  color: colorScheme.primary, size: 20),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password field with theme styling
                        Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: colorScheme.primary.withOpacity(0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(0.05),
                                blurRadius: 10,
                                spreadRadius: -5,
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _passwordController,
                            obscureText: true,
                            style: TextStyle(
                              color: theme.textTheme.bodyLarge?.color,
                              fontFamily: 'monospace',
                            ),
                            decoration: InputDecoration(
                              labelText: 'PASSWORD',
                              labelStyle: TextStyle(
                                color: theme.textTheme.bodyMedium?.color,
                                fontSize: 12,
                                letterSpacing: 1.0,
                                fontWeight: FontWeight.w400,
                              ),
                              prefixIcon: Icon(Icons.lock,
                                  color: colorScheme.primary, size: 20),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Confirm Password field with theme styling
                        Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: colorScheme.primary.withOpacity(0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(0.05),
                                blurRadius: 10,
                                spreadRadius: -5,
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            style: TextStyle(
                              color: theme.textTheme.bodyLarge?.color,
                              fontFamily: 'monospace',
                            ),
                            decoration: InputDecoration(
                              labelText: 'CONFIRM PASSWORD',
                              labelStyle: TextStyle(
                                color: theme.textTheme.bodyMedium?.color,
                                fontSize: 12,
                                letterSpacing: 1.0,
                                fontWeight: FontWeight.w400,
                              ),
                              prefixIcon: Icon(Icons.lock_outline,
                                  color: colorScheme.primary, size: 20),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 16),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Register button with theme styling
                        _isLoading
                            ? Center(
                                child: CircularProgressIndicator(
                                    color: colorScheme.secondary))
                            : Container(
                                height: 54,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      colorScheme.primary,
                                      colorScheme.primary.withOpacity(0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          colorScheme.primary.withOpacity(0.3),
                                      blurRadius: 12,
                                      spreadRadius: -6,
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _register,
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: colorScheme.onPrimary,
                                    backgroundColor: Colors.transparent,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'SECURE REGISTRATION',
                                    style: TextStyle(
                                      letterSpacing: 1.5,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),

                        const SizedBox(height: 20),

                        // Anonymous registration option with theme styling
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border.all(
                                color: theme.textTheme.bodyMedium?.color
                                        ?.withOpacity(0.2) ??
                                    Colors.grey.withOpacity(0.2)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextButton(
                            onPressed: _registerDummyUser,
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.secondary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shield,
                                    size: 16, color: colorScheme.secondary),
                                const SizedBox(width: 8),
                                Text(
                                  'REGISTER ANONYMOUSLY',
                                  style: TextStyle(
                                    letterSpacing: 1.0,
                                    fontSize: 12,
                                    color: colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Spacer to push content down
                        const Spacer(),

                        // Login link with theme styling
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: 1,
                              width: 60,
                              color: colorScheme.primary.withOpacity(0.1),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 20),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: colorScheme.surface.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: colorScheme.primary
                                          .withOpacity(0.15)),
                                ),
                                child: Text(
                                  'BACK TO LOGIN',
                                  style: TextStyle(
                                    color: theme.textTheme.bodyMedium?.color,
                                    fontSize: 12,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              height: 1,
                              width: 60,
                              color: colorScheme.primary.withOpacity(0.1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
