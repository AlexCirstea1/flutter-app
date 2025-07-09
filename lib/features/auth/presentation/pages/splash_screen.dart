import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/data/services/api_service.dart';
import '../../../../core/data/services/service_locator.dart';
import '../../../../core/data/services/storage_service.dart';
import '../../../../core/widget/pin_screen.dart';
import '../../data/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = serviceLocator<AuthService>();
  final StorageService _storageService = StorageService();
  final ApiService _api = serviceLocator<ApiService>();

  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isDataReady = false;
  String? _nextRoute;
  Widget? _nextScreen;

  @override
  void initState() {
    super.initState();

    // Setup animation controller for the 2 second loading
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController)
      ..addListener(() {
        setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && _isDataReady) {
          _navigateToNextScreen();
        }
      });

    _animationController.forward();

    // Start checking login status in parallel
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    String? accessToken = await _storageService.getAccessToken();
    String? refreshToken = await _storageService.getRefreshToken();

    // Check if we have a valid user profile
    final userProfile = await _storageService.getUserProfile();

    if (accessToken != null) {
      bool isTokenValid = await _authService.verifyToken(accessToken);

      if (isTokenValid) {
        // Use the hasPin from the UserProfile if available, otherwise fall back to the stored value
        final hasPin = userProfile?.hasPin ?? await _storageService.getHasPin();

        if (hasPin) {
          _nextScreen = const PinScreen();
        } else {
          _nextRoute = '/home';
        }
      } else if (refreshToken != null) {
        // Try to refresh the token
        String? newAccessToken = await _authService.refreshToken(refreshToken);

        if (newAccessToken != null && userProfile != null) {
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
            _nextScreen = const PinScreen();
          } else {
            _nextRoute = '/home';
          }
        } else {
          // Token refresh failed or no user profile, redirect to login
          _nextRoute = '/login';
        }
      } else {
        // No refresh token available, redirect to login
        _nextRoute = '/login';
      }
    } else {
      // User is not logged in, navigate to login page
      _nextRoute = '/login';
    }

    // Mark data ready for navigation
    setState(() {
      _isDataReady = true;
    });

    // If animation already complete, navigate now
    if (_animationController.status == AnimationStatus.completed) {
      _navigateToNextScreen();
    }
  }

  void _navigateToNextScreen() {
    if (_nextScreen != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => _nextScreen!),
      );
    } else if (_nextRoute != null) {
      Navigator.pushReplacementNamed(context, _nextRoute!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo with theme-based coloring
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.12),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  colorScheme.primary,
                  BlendMode.srcIn,
                ),
                child: Image.asset(
                  'assets/images/response_transparent_logo.png',
                  width: 120,
                  height: 120,
                ),
              ),
            ),

            const SizedBox(height: 40),

            // App name
            Text(
              "RESPONSE",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w300,
                letterSpacing: 3.0,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),

            const SizedBox(height: 8),

            // Tagline
            Text(
              "Secure Communications",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.2,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),

            const SizedBox(height: 60),

            // Custom progress indicator
            Container(
              width: 200,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: colorScheme.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  // Background track
                  Container(
                    width: 200,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Animated progress
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _animation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.secondary,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.secondary.withOpacity(0.3),
                            blurRadius: 5,
                            spreadRadius: -1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Loading text with status
            Text(
              _isDataReady ? "Ready" : "Initializing...",
              style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
