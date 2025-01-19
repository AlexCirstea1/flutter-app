import 'package:flutter/material.dart';
import 'package:vaultx_app/config/logger_config.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset('assets/images/VaultX-Wide-Wide-Dark.png'),
            const SizedBox(height: 50),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'Enter your username',
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
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: () {
                      User loginUser = User(
                        email: "",
                        username: _usernameController.text,
                        password: _passwordController.text,
                      );
                      _loginUser(loginUser);
                    },
                    child: const Text('Login'),
                  ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/register');
              },
              child: const Text('Don\'t have an account? Register here'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loginUser(User user) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response =
          await _authService.loginUser(user.username, user.password);
      LoggerService.logInfo(
          'Login Response: $response'); // Log the entire response

      if (response != null) {
        final accessToken = response['access_token'] as String?;
        final refreshToken = response['refresh_token'] as String?;
        final userData = response['user'] as Map<String, dynamic>?;

        if (accessToken != null &&
            refreshToken != null &&
            userData != null &&
            userData['username'] != null &&
            userData['id'] != null &&
            userData['hasPin'] != null) {
          await _storageService.saveLoginDetails(
            accessToken,
            refreshToken,
            userData['username'] as String,
            userData['id'] as String,
          );

          await _storageService.saveHasPin(userData['hasPin'] == true);

          if (mounted) {
            Navigator.pushNamed(context, '/home');
          }
        } else {
          // Handle missing fields in the response
          LoggerService.logError('Missing fields in login response', response);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid response from server')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login failed')),
          );
        }
      }
    } catch (error, stackTrace) {
      LoggerService.logError('Error during login: $error', error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred during login')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
