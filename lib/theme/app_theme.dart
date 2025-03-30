import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData darkTheme = ThemeData.dark().copyWith(
    scaffoldBackgroundColor: Colors.black,
    colorScheme: const ColorScheme.dark(
      primary: Colors.cyan,
      secondary: Colors.cyanAccent,
      error: Colors.red,
      background: Colors.black,
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
      background: Colors.white,
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