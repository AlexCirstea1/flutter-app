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
    // Define the color palette
    const Color mainColor = Color(0xFF1B4A36); // Main 60%
    const Color secondaryColor = Color(0xFFF4FBF8); // Secondary 30%
    const Color accentColor = Color(0xFF112D10); // Accent 10%

    return MaterialApp(
      title: 'VaultX App',
      theme: ThemeData(
        colorScheme: const ColorScheme(
          primary: mainColor, // Main color
          secondary: secondaryColor, // Secondary color
          surface: secondaryColor,
          error: Colors.red,
          onPrimary: Colors.white, // Text color on primary
          onSecondary: accentColor, // Text color on secondary
          onSurface: mainColor,
          onError: Colors.white,
          brightness: Brightness.light, // Light theme
        ),
        scaffoldBackgroundColor: secondaryColor, // Background color
        appBarTheme: const AppBarTheme(
          backgroundColor: mainColor, // App bar color
          foregroundColor: Colors.white, // App bar text/icon color
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: mainColor, // Button color
            foregroundColor: Colors.white, // Text color
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0), // Rounded buttons
            ),
          ),
        ),
        useMaterial3: true, // Use Material 3 features
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme(
          primary: mainColor,
          secondary: secondaryColor,
          surface: accentColor,
          error: Colors.red,
          onPrimary: Colors.white,
          onSecondary: Colors.black,
          onSurface: Colors.white,
          onError: Colors.black,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: accentColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: mainColor,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: mainColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system, // Use system theme mode (light or dark)
      initialRoute: '/', // Start with the splash screen
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
