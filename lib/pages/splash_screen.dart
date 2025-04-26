import 'dart:io';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/push_service.dart';
import '../services/service_locator.dart';
import '../services/storage_service.dart';
import '../widget/pin_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = serviceLocator<AuthService>();
  final StorageService _storageService = StorageService();
  final ApiService _api = serviceLocator<ApiService>();
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    String? accessToken = await _storageService.getAccessToken();
    String? refreshToken = await _storageService.getRefreshToken();

    // Check if we have a valid user profile
    final userProfile = await _storageService.getUserProfile();

    if (accessToken != null) {
      bool isTokenValid = await _authService.verifyToken(accessToken);

      if (isTokenValid) {
        // await _registerPushToken();
        // Use the hasPin from the UserProfile if available, otherwise fall back to the stored value
        final hasPin = userProfile?.hasPin ?? await _storageService.getHasPin();

        if (hasPin) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const PinScreen()),
          );
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else if (refreshToken != null) {
        // Try to refresh the token
        String? newAccessToken = await _authService.refreshToken(refreshToken);

        if (newAccessToken != null && userProfile != null) {
          // await _registerPushToken();
          // If we have user data, construct and save a proper auth response
          final authResponse = {
            'access_token': newAccessToken,
            'refresh_token': refreshToken,
            'user': userProfile.toJson(),
          };

          // Save the complete updated auth data
          await _storageService.saveAuthData(authResponse);

          // Navigate based on PIN status
          if (userProfile.hasPin) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const PinScreen()),
            );
          } else {
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          // Token refresh failed or no user profile, redirect to login
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

  // Future<void> _registerPushToken() async {
  //   await PushService.instance.register((token) async {
  //     // Use your ApiService so JWT & error-handling is consistent
  //     try {
  //       await _api.post('/user/device-token', {
  //         'token'   : token,
  //         'platform': Platform.isIOS ? 'IOS' : 'ANDROID',
  //       });
  //     } catch (e) {
  //       // Non-fatal: keep the app going
  //       debugPrint('⚠️  Could not send FCM token: $e');
  //     }
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
