import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart'
    if (dart.library.html) 'package:vaultx_app/utils/flutter_windowmanager_web.dart';
import 'package:vaultx_app/theme/app_theme.dart';

class UIOverlayHelper {
  /// Prevents screenshots and recording across the app
  static Future<void> enableSecureMode() async {
    // Set secure flag for iOS
    if (Platform.isIOS) {
      // This will prevent screenshots on iOS
      await SystemChannels.platform
          .invokeMethod<void>('SystemChrome.setPreventScreenCapture', true);
    }

    // For Android, use flutter_windowmanager
    else if (Platform.isAndroid) {
      await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    }
  }

  /// Disables secure mode if needed
  static Future<void> disableSecureMode() async {
    if (Platform.isIOS) {
      await SystemChannels.platform
          .invokeMethod<void>('SystemChrome.setPreventScreenCapture', false);
    } else if (Platform.isAndroid) {
      await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    }
  }

  static void refreshStatusBarIconsForTheme(
      ThemeMode mode, Brightness platformBrightness) {
    SystemUiOverlayStyle style;

    if (mode == ThemeMode.system) {
      style = platformBrightness == Brightness.dark
          ? AppTheme.darkOverlayStyle
          : AppTheme.lightOverlayStyle;
    } else if (mode == ThemeMode.light) {
      style = AppTheme.lightOverlayStyle;
    } else {
      style = AppTheme.darkOverlayStyle;
    }

    SystemChrome.setSystemUIOverlayStyle(style);
  }
}
