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
import '../services/service_locator.dart';
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
  final AuthService _authService = serviceLocator<AuthService>();
  final StorageService _storageService = StorageService();
  late final AvatarService _avatarService;
  List<Map<String, String>> _recentAccounts = [];
  bool _isLoading = false;

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

  Future<Map<String, dynamic>?> _fetchUserDataById(String userId) async {
    try {
      final url = Uri.parse('${Environment.apiBaseUrl}/user/public/$userId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        _storageService.removeRecentAccount(userId);
      } else {
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
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                // Logo with glow effect
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.15),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/response_transparent_logo.png',
                    width: 120,
                  ),
                ),
                const SizedBox(height: 50),

                // Title with cybersecurity aesthetic
                Text(
                  'SECURE ACCESS',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 3.0,
                  ),
                ),
                const SizedBox(height: 30),

                // Username field with theme styling
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: TextField(
                    controller: _usernameController,
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.person_outline,
                          color: colorScheme.primary, size: 20),
                      labelText: 'USERNAME',
                      labelStyle: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 12,
                        letterSpacing: 1.0,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 16),
                    ),
                  ),
                ),

                // Password field with theme styling
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  margin: const EdgeInsets.only(bottom: 30),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.lock_outline,
                          color: colorScheme.primary, size: 20),
                      labelText: 'PASSWORD',
                      labelStyle: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 12,
                        letterSpacing: 1.0,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 16),
                    ),
                  ),
                ),

                // Login button with theme styling
                _isLoading
                    ? CircularProgressIndicator(color: colorScheme.secondary)
                    : Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.15),
                        blurRadius: 12,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: BorderSide(
                          color: colorScheme.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Text(
                      'ACCESS SECURE NETWORK',
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 12,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Register link with theme styling
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/register'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'CREATE SECURE IDENTITY',
                      style: TextStyle(
                        color: colorScheme.primary.withOpacity(0.7),
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 50),

                // Recent Accounts Section with theme styling
                if (_recentAccounts.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.security,
                              size: 14, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'AUTHORIZED IDENTITIES',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      Divider(color: colorScheme.primary.withOpacity(0.1), height: 20),
                      const SizedBox(height: 10),
                      ..._recentAccounts.map((account) => _buildRecentAccountCard(account, theme)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentAccountCard(Map<String, String> account, ThemeData theme) {
    final userId = account['id'];
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colorScheme.primary.withOpacity(0.2), width: 1),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.05),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: FutureBuilder<Uint8List?>(
            future: userId != null ? _avatarService.getAvatar(userId) : null,
            builder: (context, snapshot) {
              return CircleAvatar(
                backgroundColor: colorScheme.surface.withOpacity(0.8),
                backgroundImage:
                snapshot.hasData ? MemoryImage(snapshot.data!) : null,
                child: snapshot.connectionState == ConnectionState.waiting
                    ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.secondary,
                  ),
                )
                    : snapshot.hasData
                    ? null
                    : Icon(Icons.person,
                    color: colorScheme.secondary, size: 20),
              );
            },
          ),
        ),
        title: Text(
          account['username']?.toUpperCase() ?? 'UNKNOWN',
          style: TextStyle(
            fontSize: 13,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w500,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (userId != null)
              UserRoleChip(
                userId: userId,
                isCompact: true,
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: colorScheme.primary,
            ),
          ],
        ),
        subtitle: userId != null
            ? Text(
          'ID: ${userId.substring(0, 8)}...',
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: theme.textTheme.bodyMedium?.color,
          ),
        )
            : null,
        onTap: () {
          setState(() {
            _usernameController.text = account['username'] ?? '';
          });

          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        },
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
