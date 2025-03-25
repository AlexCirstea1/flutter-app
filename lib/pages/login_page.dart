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
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/response_transparent_logo.png',
                  width: 120),
              const SizedBox(height: 50),
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_outline, color: Colors.white70),
                  labelText: 'Username',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.lock_outline, color: Colors.white70),
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : ElevatedButton(
                      onPressed: () {
                        final user = User(
                          email: "",
                          username: _usernameController.text,
                          password: _passwordController.text,
                        );
                        _loginUser(user);
                      },
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                        child: Text('Login'),
                      ),
                    ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: const Text('Don\'t have an account? Register',
                    style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loginUser(User user) async {
    setState(() => _isLoading = true);
    try {
      final response =
          await _authService.loginUser(user.username, user.password);
      if (response != null) {
        final success =
            await _authService.saveUserData(response, _storageService);
        if (success && mounted) {
          Navigator.pushNamed(context, '/home');
        } else {
          _showSnackBar('Invalid response from server');
        }
      } else {
        _showSnackBar('Login failed');
      }
    } catch (e) {
      LoggerService.logError('Login error', e);
      _showSnackBar('An error occurred during login');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
