import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Centralised **themes** (light / dark / cyber) + status-bar styles.
///
/// • Fixes the _“Failed to interpolate TextStyles with different inherit
///   values”_ crash by giving **every** theme the same `TextButton`
///   text-style (`inherit: false`, monospace).
///
/// • Keeps your previous colour / typography choices intact.
class AppTheme {
/*──────────────────────────  STATUS-BAR STYLES  ──────────────────────────*/

  static final SystemUiOverlayStyle darkOverlayStyle =
      SystemUiOverlayStyle.light.copyWith(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  );

  static final SystemUiOverlayStyle lightOverlayStyle =
      SystemUiOverlayStyle.dark.copyWith(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
  );

/*────────────────────  SHARED BUTTON-TEXT HELPERS  ─────────────────────*/

  /*  TextButton needs the **same** TextStyle in all themes so that
      TextStyle.lerp() can animate without hitting the “inherit mismatch”
      assertion.                                                 */
  static const _buttonText = TextStyle(
    inherit: false, // 🚩 keep fixed across themes
    fontFamily: 'monospace',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.10,
    height: 1.4,
  );

  static ButtonStyle _textButton(ColorScheme cs) =>
      TextButton.styleFrom(foregroundColor: cs.primary, textStyle: _buttonText);

/*──────────────────────────  LIGHT THEME  ──────────────────────────*/

  static const _lightScheme = ColorScheme.light(
    primary: Colors.blue,
    secondary: Colors.lightBlueAccent,
    error: Colors.redAccent,
    tertiary: Color(0xFFCAE4FF),
    surface: Color(0xFFFFFFFF),
  );

  static final ThemeData lightTheme = ThemeData.light().copyWith(
    scaffoldBackgroundColor: const Color(0xFFF2F5F8),
    colorScheme: _lightScheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 16,
        letterSpacing: 2.0,
        fontWeight: FontWeight.w300,
        color: Colors.blue,
      ),
      iconTheme: IconThemeData(color: Colors.blue),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF1A1A1A)),
      bodyMedium: TextStyle(color: Color(0xFF3C3C3C)),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Color(0xFFFFFFFF)),
    dividerColor: Colors.grey,
    cardColor: const Color(0xFFFFFFFF),
    textButtonTheme: TextButtonThemeData(style: _textButton(_lightScheme)),
  );

/*──────────────────────────  DARK THEME  ──────────────────────────*/

  static const _darkScheme = ColorScheme.dark(
    primary: Colors.cyan,
    secondary: Colors.cyanAccent,
    error: Colors.red,
    tertiary: Color(0xFF26A69A),
    surface: Color(0xFF121A24),
  );

  static final ThemeData darkTheme = ThemeData.dark().copyWith(
    scaffoldBackgroundColor: const Color(0xFF0D1117),
    colorScheme: _darkScheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 16,
        letterSpacing: 2.0,
        fontWeight: FontWeight.w300,
        color: Colors.cyan,
      ),
      iconTheme: IconThemeData(color: Colors.cyan),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF121A24)),
    dividerColor: Colors.white12,
    cardColor: const Color(0xFF121A24),
    textButtonTheme: TextButtonThemeData(style: _textButton(_darkScheme)),
  );

/*───────────────────────  CYBER / HACKER THEME  ───────────────────────*/

  static const _cyberScheme = ColorScheme.dark(
    primary: Color(0xFF00FF9F), // neon-green
    secondary: Color(0xFF00C3FF), // electric-cyan
    error: Color(0xFFFF005B),
    tertiary: Color(0xFF488F73),
    surface: Color(0xFF10151B),
  );

  static final ThemeData cyberTheme = ThemeData.dark().copyWith(
    scaffoldBackgroundColor: const Color(0xFF0B0E11),
    splashFactory: InkRipple.splashFactory,
    colorScheme: _cyberScheme,

    /* typography */
    textTheme: const TextTheme(
      displayLarge: TextStyle(
          fontSize: 48, fontWeight: FontWeight.w300, letterSpacing: 1.5),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
      bodyLarge: TextStyle(fontSize: 14, color: Color(0xFFCED4DE)),
      bodyMedium: TextStyle(fontSize: 13, color: Color(0xFF8F9BB3)),
      labelLarge: TextStyle(fontSize: 12, letterSpacing: 1.1),
    ),

    /* app-bar */
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'monospace',
        fontSize: 16,
        letterSpacing: 2.0,
        fontWeight: FontWeight.w400,
        color: Color(0xFF00FF9F),
      ),
      iconTheme: IconThemeData(color: Color(0xFF00FF9F)),
    ),

    /* inputs */
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF141922),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF00FF9F), width: .8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF00C3FF), width: 1.0),
      ),
      hintStyle: const TextStyle(color: Color(0xFF56616E)),
      labelStyle: const TextStyle(color: Color(0xFF00FF9F)),
    ),

    /* buttons */
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.black,
        backgroundColor: const Color(0xFF00FF9F),
        textStyle: const TextStyle(
            fontFamily: 'monospace', fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: _textButton(_cyberScheme)),

    /* misc */
    dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF10151B)),
    cardColor: const Color(0xFF10151B),
    dividerColor: Colors.white12,
    iconTheme: const IconThemeData(color: Color(0xFF00C3FF)),
  );
}
