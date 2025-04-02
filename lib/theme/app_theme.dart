import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Define system UI overlay styles
  static final SystemUiOverlayStyle darkOverlayStyle =
      SystemUiOverlayStyle.light.copyWith(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark, // iOS: white status bar icons
    statusBarIconBrightness:
        Brightness.light, // Android: white status bar icons
  );

  static final SystemUiOverlayStyle lightOverlayStyle =
      SystemUiOverlayStyle.dark.copyWith(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light, // iOS: dark status bar icons
    statusBarIconBrightness: Brightness.dark, // Android: dark status bar icons
  );

  static final ThemeData darkTheme = ThemeData.dark().copyWith(
    scaffoldBackgroundColor: Colors.black,
    colorScheme: const ColorScheme.dark(
      primary: Colors.cyan,
      secondary: Colors.cyanAccent,
      error: Colors.red,
      surface: Color(0xFF121A24),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 16,
        letterSpacing: 2.0,
        fontWeight: FontWeight.w300,
        color: Colors.cyan,
      ),
      iconTheme: IconThemeData(
        color: Colors.cyan,
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
    ),
    dialogTheme: const DialogTheme(
      backgroundColor: Color(0xFF121A24),
    ),
  );

  static final ThemeData lightTheme = ThemeData.light().copyWith(
    scaffoldBackgroundColor: Colors.white,
    colorScheme: const ColorScheme.light(
      primary: Colors.blue,
      secondary: Colors.lightBlue,
      error: Colors.redAccent,
      surface: Color(0xFFF5F5F5),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 16,
        letterSpacing: 2.0,
        fontWeight: FontWeight.w300,
        color: Colors.blue,
      ),
      iconTheme: IconThemeData(
        color: Colors.blue,
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black),
      bodyMedium: TextStyle(color: Colors.black87),
    ),
    dialogTheme: const DialogTheme(
      backgroundColor: Colors.white,
    ),
  );
}
