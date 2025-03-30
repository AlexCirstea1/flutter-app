import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vaultx_app/pages/about_page.dart';
import 'package:vaultx_app/pages/activity_page.dart';
import 'package:vaultx_app/pages/blockchain_page.dart';
import 'package:vaultx_app/pages/home_page.dart';
import 'package:vaultx_app/pages/login_page.dart';
import 'package:vaultx_app/pages/profile_page.dart';
import 'package:vaultx_app/pages/register_page.dart';
import 'package:vaultx_app/pages/setpin_page.dart';
import 'package:vaultx_app/pages/settings_page.dart';
import 'package:vaultx_app/pages/splash_screen.dart';
import 'package:vaultx_app/services/service_locator.dart';
import 'package:vaultx_app/theme/app_theme.dart';
import 'package:vaultx_app/theme/theme_provider.dart';
import 'package:vaultx_app/widget/pin_screen.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
RouteObserver<ModalRoute<void>>();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setupServiceLocator();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Response',
          navigatorKey: navigatorKey,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          initialRoute: '/',
          navigatorObservers: [routeObserver],
          routes: {
            '/': (context) => const SplashScreen(),
            '/login': (context) => const LoginPage(),
            '/register': (context) => const RegisterPage(),
            '/home': (context) => const MyHomePage(),
            '/profile': (context) => const ProfilePage(),
            '/settings': (context) => const SettingsPage(),
            '/pin': (context) => const PinScreen(),
            '/set-pin': (context) => const SetPinPage(),
            '/about': (context) => const AboutPage(),
            '/activity': (context) => const ActivityPage(),
            '/blockchain': (context) => const BlockchainPage(),
          },
        );
      },
    );
  }
}