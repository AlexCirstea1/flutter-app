import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/logger_config.dart';
import '../config/environment.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../utils/key_cert_helper.dart';

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

  final AuthService _authService = AuthService();
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
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
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
            TextButton(
              onPressed: () => Navigator.pop(context),
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
      bool success = await _authService.registerUser(user.username, user.email, user.password);
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
      final response = await _authService.loginUser(user.username, user.password);
      if (response != null && await _authService.saveUserData(response, _storageService)) {
        await _generateAndUploadKeys();
        if (mounted) Navigator.pushNamed(context, '/home');
      } else {
        _showError('Login failed after registration.');
      }
    } catch (e) {
      LoggerService.logError('Login after registration error: $e');
      _showError('An error occurred during login.');
    }
  }

  Future<void> _generateAndUploadKeys() async {
    final (privatePem, _, publicPem) = await KeyCertHelper.generateSelfSignedCert(
      dn: {'CN': _usernameController.text.trim()},
      keySize: 2048,
      daysValid: 365,
    );

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
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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