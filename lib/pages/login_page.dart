import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:vaultx_app/widget/user_role_chip.dart';
import '../config/environment.dart';
import '../config/logger_config.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/avatar_service.dart';
import '../services/storage_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  late final AvatarService _avatarService;

  // List of recent accounts stored as maps containing 'id' and 'username'
  List<Map<String, String>> _recentAccounts = [];

  @override
  void initState() {
    super.initState();
    _avatarService = AvatarService(_storageService);
    _loadRecentAccounts();
    // Ensure the scroll view starts at the top after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.jumpTo(0);
    });
  }

  Future<void> _loadRecentAccounts() async {
    try {
      final ids = await _storageService.getRecentAccounts();
      final List<Map<String, String>> tmpList = [];
      for (final id in ids) {
        final userData = await _fetchUserDataById(id);
        debugPrint('Fetched user data for $id: $userData');
        if (userData != null) {
          tmpList.add({
            'id': userData['id'] as String,
            'username': userData['username'] as String,
          });
        }
      }
      setState(() {
        _recentAccounts = tmpList;
      });
      debugPrint('Recent accounts loaded: $_recentAccounts');
    } catch (e) {
      LoggerService.logError('Error loading recent accounts', e);
    }
  }

  // Example method to call GET /api/auth/user/{id}
  Future<Map<String, dynamic>?> _fetchUserDataById(String userId) async {
    try {
      final url = Uri.parse('${Environment.apiBaseUrl}/user/public/$userId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        _storageService.removeRecentAccount(userId);
      } else{
        debugPrint(
            'Error fetching user data for $userId: ${response.statusCode}');
      }
    } catch (e) {
      LoggerService.logError('Error fetching user data by ID $userId', e);
    }
    return null;
  }

  void _handleLogin() {
    final user = User(
      email: "",
      username: _usernameController.text,
      password: _passwordController.text,
    );
    _loginUser(user);
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
          // Get the userId from the response; adjust the field name as needed.
          final userId = response['user']['id'] as String?;
          if (userId != null) {
            // Add to recent accounts list.
            await _storageService.addRecentAccount(userId);
          }
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

  /// Build a wide card for each recent account.
  Widget _buildRecentAccountCard(Map<String, String> account) {
    final userId = account['id'];

    return GestureDetector(
      onTap: () {
        setState(() {
          _usernameController.text = account['username'] ?? '';
        });
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 3,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Avatar with FutureBuilder
              FutureBuilder<Uint8List?>(
                future:
                    userId != null ? _avatarService.getAvatar(userId) : null,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }

                  if (snapshot.hasData && snapshot.data != null) {
                    // Display the avatar image
                    return CircleAvatar(
                      radius: 16,
                      backgroundImage: MemoryImage(snapshot.data!),
                    );
                  } else {
                    // Fallback to the default icon
                    return const Icon(
                      Icons.account_circle,
                      size: 32,
                      color: Colors.blueAccent,
                    );
                  }
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  account['username'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              UserRoleChip(userId: userId, isCompact: true),
              const SizedBox(width: 3),
              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 100),
              // Logo
              Image.asset(
                'assets/images/response_transparent_logo.png',
                width: 120,
              ),
              const SizedBox(height: 50),

              // Login Form
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
                      onPressed: _handleLogin,
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                        child: Text('Login'),
                      ),
                    ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: const Text(
                  'Don\'t have an account? Register',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 32),
              // Recent Accounts Section displayed as wide cards
              if (_recentAccounts.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Accounts',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children:
                          _recentAccounts.map(_buildRecentAccountCard).toList(),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
