import 'package:flutter/material.dart';
import 'package:vaultx_app/pages/home_page.dart';
import 'package:vaultx_app/pages/login_page.dart';
import 'package:vaultx_app/pages/profile_page.dart';
import 'package:vaultx_app/pages/register_page.dart';
import 'package:vaultx_app/pages/setpin_page.dart';
import 'package:vaultx_app/pages/settings_page.dart';
import 'package:vaultx_app/pages/splash_screen.dart';
import 'package:vaultx_app/widget/pin_screen.dart';

// Splash screen to check token state

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0A0E1A);
    const secondaryColor = Color(0xFF192233);
    const accentColor = Color(0xFF00B5FF); // Matching logo color (blue)
    const errorColor = Color(0xFFFF5555);
    const surfaceColor = Color(0xFF121924);

    return MaterialApp(
      title: 'Response',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: primaryColor,
          secondary: secondaryColor,
          surface: surfaceColor,
          error: errorColor,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.white70,
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: primaryColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: secondaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          bodyMedium: TextStyle(fontSize: 16, color: Colors.white70),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const MyHomePage(),
        '/profile': (context) => const ProfilePage(),
        '/settings': (context) => const SettingsPage(),
        '/pin': (context) => const PinScreen(),
        '/set-pin': (context) => const SetPinPage(),
      },
    );
  }
}