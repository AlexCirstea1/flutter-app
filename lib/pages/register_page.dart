import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/environment.dart';
import '../config/logger_config.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/service_locator.dart';
import '../services/storage_service.dart';
import '../utils/key_cert_helper.dart';
import '../widget/consent_dialog.dart';
import 'learn_more_page.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // title: const Text('Create Account'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            Text(
              'Register to Response',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person),
                  labelStyle: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  labelStyle: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  labelStyle: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: Icon(Icons.lock_outline),
                  labelStyle: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _register,
                    child: const Text('Register'),
                  ),
            const SizedBox(height: 16),
            // Dummy registration button
            TextButton(
              onPressed: _registerDummyUser,
              style: TextButton.styleFrom(
                foregroundColor: Colors.greenAccent,
              ),
              child: const Text('Register as Anonymous'),
            ),
            const SizedBox(height: 1),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
              ),
              child: const Text('Already have an account? Log in'),
            ),
          ],
        ),
      ),
    );
  }

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

  /// Sends the blockchain consent decision to the backend.
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

  // New method for dummy registration
  Future<void> _registerDummyUser() async {
    // Generate a random password (adjust length as desired)
    final dummyPassword = _generateRandomPassword(12);
    setState(() => _isLoading = true);

    try {
      // Call the dummy registration endpoint.
      // Here we assume that registerDummyUser returns the parsed JSON as Map<String, dynamic>
      final Map<String, dynamic>? userJson =
          await _authService.registerDummyUser(dummyPassword);
      if (userJson != null) {
        // Build a dummy user using the returned username and email,
        // and the dummy password we generated.
        final dummyUser = User(
          username: userJson['username'] as String,
          email: userJson['email'] as String,
          password: dummyPassword,
        );
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

  // Helper to generate a random password
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
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
