import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/ui_overlay_helper.dart';

/// ──────────────────────────────────────────────────────────
///  4*-state* theme selector:  **system → light → dark → cyber**
/// ──────────────────────────────────────────────────────────
enum AppThemeOption { system, light, dark, cyber }

class ThemeProvider extends ChangeNotifier {
  AppThemeOption _option = AppThemeOption.system;

  AppThemeOption get option => _option; // expose raw option
  ThemeMode get themeMode {
    // MaterialApp will still
    switch (_option) {
      // need a ThemeMode
      case AppThemeOption.light:
        return ThemeMode.light;
      case AppThemeOption.dark:
        return ThemeMode.dark;
      case AppThemeOption.system:
      case AppThemeOption.cyber:
        return ThemeMode.dark; // cyber → dark base
    }
  }

  bool get isCyber => _option == AppThemeOption.cyber;

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  /* ─────────────  toggle  ───────────── */
  void toggleTheme() {
    _option = switch (_option) {
      AppThemeOption.system => AppThemeOption.light,
      AppThemeOption.light => AppThemeOption.dark,
      AppThemeOption.dark => AppThemeOption.cyber,
      AppThemeOption.cyber => AppThemeOption.system,
    };

    _applyOverlayStyle();
    _saveThemeToPrefs();
    notifyListeners();
  }

  /* ─────────────  helpers  ───────────── */
  void setTheme(AppThemeOption option) {
    _option = option;
    _applyOverlayStyle();
    _saveThemeToPrefs();
    notifyListeners();
  }

  void _applyOverlayStyle() {
    final brightness = WidgetsBinding.instance.window.platformBrightness;
    UIOverlayHelper.refreshStatusBarIconsForTheme(themeMode, brightness);
  }

  /* ─────────────  persistence  ───────────── */
  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('themeMode') ?? 'system';

    _option = switch (value) {
      'light' => AppThemeOption.light,
      'dark' => AppThemeOption.dark,
      'cyber' => AppThemeOption.cyber,
      _ => AppThemeOption.system,
    };

    _applyOverlayStyle();
    notifyListeners();
  }

  Future<void> _saveThemeToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final str = switch (_option) {
      AppThemeOption.light => 'light',
      AppThemeOption.dark => 'dark',
      AppThemeOption.cyber => 'cyber',
      AppThemeOption.system => 'system',
    };
    await prefs.setString('themeMode', str);
  }
}
