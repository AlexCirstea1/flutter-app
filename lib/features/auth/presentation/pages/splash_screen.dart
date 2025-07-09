import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/data/services/api_service.dart';
import '../../../../core/data/services/data_preload_service.dart';
import '../../../../core/data/services/service_locator.dart';
import '../../../../core/data/services/storage_service.dart';
import '../../../../core/widget/pin_screen.dart';
import '../../../auth/data/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  /* ───────── deps ───────── */
  final _authService = serviceLocator<AuthService>();
  final _storage = StorageService();
  final _api = serviceLocator<ApiService>();
  final _preload = serviceLocator<DataPreloadService>();

  /* ───────── animation ─── */
  late final AnimationController _animCtl =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..addListener(() => setState(() {}))
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed &&
              _authReady &&
              _preloadDone &&
              mounted) {
            _go();
          }
        })
        ..forward();

  bool _authReady = false;
  bool _preloadDone = false;
  String? _nextRoute;
  Widget? _nextScreen;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus(); // auth & route
    _kickOffPreload(); // background data load
  }

  Future<void> _kickOffPreload() async {
    // start immediately but don't block UI
    await _preload.preloadAppData();
    _preloadDone = true;
    if (_animCtl.isCompleted && _authReady && mounted) _go();
  }

  Future<void> _checkLoginStatus() async {
    final access = await _storage.getAccessToken();
    final refresh = await _storage.getRefreshToken();
    final profile = await _storage.getUserProfile();

    if (access != null && await _authService.verifyToken(access)) {
      final hasPin = profile?.hasPin ?? await _storage.getHasPin();
      _nextScreen = hasPin ? const PinScreen() : null;
      _nextRoute = hasPin ? null : '/home';
    } else if (refresh != null) {
      final newTok = await _authService.refreshToken(refresh);
      if (newTok != null && profile != null) {
        await _storage.saveAuthData({
          'access_token': newTok,
          'refresh_token': refresh,
          'user': profile.toJson(),
        });
        _nextScreen = profile.hasPin ? const PinScreen() : null;
        _nextRoute = profile.hasPin ? null : '/home';
      } else {
        _nextRoute = '/login';
      }
    } else {
      _nextRoute = '/login';
    }

    _authReady = true;
    if (_animCtl.isCompleted && _preloadDone && mounted) _go();
  }

  void _go() {
    if (_nextScreen != null) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => _nextScreen!));
    } else if (_nextRoute != null) {
      Navigator.pushReplacementNamed(context, _nextRoute!);
    }
  }

  @override
  void dispose() {
    _animCtl.dispose();
    super.dispose();
  }

  /* ───────── UI ───────── */
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

            // Progress bar driven by splash animation
            Container(
              width: 200,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: colorScheme.secondary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: FractionallySizedBox(
                widthFactor: _animCtl.value,
                alignment: Alignment.centerLeft,
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
            ),

            const SizedBox(height: 16),

            // Show current preload step
            ValueListenableBuilder<String>(
              valueListenable: _preload.currentOperation,
              builder: (_, txt, __) => Text(
                txt,
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.0,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
