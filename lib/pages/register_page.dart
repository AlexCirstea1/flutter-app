import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:vaultx_app/config/logger_config.dart';

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
        title: const Text('Register'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'Enter your username',
              ),
            ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Enter your email',
              ),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
              ),
            ),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                hintText: 'Confirm your password',
              ),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: () {
                      if (_passwordController.text ==
                          _confirmPasswordController.text) {
                        User newUser = User(
                          username: _usernameController.text,
                          email: _emailController.text,
                          password: _passwordController.text,
                        );
                        _registerUser(newUser);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Passwords do not match')),
                        );
                      }
                    },
                    child: const Text('Register'),
                  ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Already have an account? Login here'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registerUser(User user) async {
    setState(() {
      _isLoading = true;
    });

    try {
      bool isRegistered = await _authService.registerUser(
          user.username, user.email, user.password);
      if (isRegistered) {
        _loginUser(user); // Automatically login after successful registration
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration failed')),
          );
        }
      }
    } catch (error) {
      LoggerService.logError('Error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loginUser(User user) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response =
          await _authService.loginUser(user.username, user.password);
      LoggerService.logInfo('Login Response: $response');

      if (response != null) {
        final success =
            await _authService.saveUserData(response, _storageService);
        if (success) {
          // Now we have an accessToken in secure storage. We can generate
          // local keys & upload the public key to the backend.

          await _generateAndUploadKeys();

          // Finally, navigate to home
          if (mounted) {
            Navigator.pushNamed(context, '/home');
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid response from server')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login failed')),
        );
      }
    } catch (error, stackTrace) {
      LoggerService.logError('Error during login: $error', error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred during login')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// After we have an access token, generate RSA keys, store the private key,
  /// and POST the public key to the server.
  Future<void> _generateAndUploadKeys() async {
    try {
      // 1) Generate a self-signed cert or just raw keys
      final (privatePem, certPem, publicPem) =
          await KeyCertHelper.generateSelfSignedCert(
        dn: {'CN': 'VaultXUser'}, // or user-specific info
        keySize: 2048,
        daysValid: 365,
      );

      // 2) Save private key in secure storage
      await _storageService.savePrivateKey(privatePem);

      // 3) Send the public key to backend
      final accessToken = await _storageService.getAccessToken();
      if (accessToken == null) {
        LoggerService.logError(
            'No access token found. Cannot upload public key.');
        return;
      }

      await _uploadPublicKey(publicPem, accessToken);
      LoggerService.logInfo('Public key uploaded successfully!');
    } catch (e) {
      LoggerService.logError('Key generation/upload failed: $e');
    }
  }

  Future<void> _uploadPublicKey(String publicKeyPem, String accessToken) async {
    final url = Uri.parse('${Environment.apiBaseUrl}/user/publicKey');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'text/plain',
        'Authorization': 'Bearer $accessToken',
      },
      body: publicKeyPem, // raw PEM text
    );
    if (response.statusCode == 200) {
      LoggerService.logInfo('Public key posted to /user/publicKey');
    } else {
      LoggerService.logError(
          'Failed to upload public key. Status: ${response.statusCode}, body: ${response.body}');
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
