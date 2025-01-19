import 'package:flutter/material.dart';
import 'package:vaultx_app/config/logger_config.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

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
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
