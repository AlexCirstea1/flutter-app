import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../widget/pin_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    String? accessToken = await _storageService.getAccessToken();
    String? refreshToken = await _storageService.getRefreshToken();
    bool savedPin = await _storageService.getHasPin(); // Check if a PIN is set

    if (accessToken != null) {
      bool isTokenValid = await _authService.verifyToken(accessToken);

      if (isTokenValid) {
        // Check if the user has a PIN set
        if (savedPin) {
          // If a PIN is set, navigate to the PIN screen for security check
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const PinScreen()),
          );
        } else {
          // No PIN set, directly navigate to home
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else if (refreshToken != null) {
        String? newAccessToken = await _authService.refreshToken(refreshToken);
        if (newAccessToken != null) {
          await _storageService.saveLoginDetails(
              newAccessToken, refreshToken, '', '');

          // Check if the user has a PIN set after refreshing token
          if (savedPin) {
            // If a PIN is set, navigate to the PIN screen for security check
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const PinScreen()),
            );
          } else {
            // No PIN set, directly navigate to home
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          // Token refresh failed, redirect to login
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        // No refresh token available, redirect to login
        Navigator.pushReplacementNamed(context, '/login');
      }
    } else {
      // User is not logged in, navigate to login page
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
