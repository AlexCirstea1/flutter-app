import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vaultx_app/features/activity/presentation/pages/activity_page.dart';
import 'package:vaultx_app/features/auth/presentation/pages/login_page.dart';
import 'package:vaultx_app/features/auth/presentation/pages/splash_screen.dart';
import 'package:vaultx_app/features/blockchain/presentation/pages/blockchain_page.dart';
import 'package:vaultx_app/features/home/presentation/pages/home_page.dart';
import 'package:vaultx_app/features/profile/presentation/pages/profile_page.dart';
import 'package:vaultx_app/features/settings/presentation/pages/setpin_page.dart';
import 'package:vaultx_app/features/settings/presentation/pages/settings_page.dart';

import 'core/data/services/service_locator.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/utils/ui_overlay_helper.dart';
import 'core/widget/pin_screen.dart';
import 'features/auth/presentation/pages/register_page.dart';
import 'features/settings/presentation/pages/about_page.dart';
import 'features/settings/presentation/pages/notifications_page.dart';
import 'features/settings/presentation/pages/privacy_policy_page.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupServiceLocator();

  // ── block screenshots / recordings ────────────────────────────────
  await UIOverlayHelper.enableSecureMode();

  // ── set the initial overlay style (system-brightness based) ───────
  final brightness = WidgetsBinding.instance.window.platformBrightness;
  SystemChrome.setSystemUIOverlayStyle(
    brightness == Brightness.dark
        ? AppTheme.darkOverlayStyle
        : AppTheme.lightOverlayStyle,
  );

  runApp(
    ChangeNotifierProvider(
        create: (_) => ThemeProvider(), child: const MyApp()),
  );
}

/*─────────────────────────────────────────────────────────────────*/
/*                         MaterialApp                             */
/*─────────────────────────────────────────────────────────────────*/
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (_, tp, __) {
        // update status-bar icons each rebuild
        final sysBrightness = WidgetsBinding.instance.window.platformBrightness;
        UIOverlayHelper.refreshStatusBarIconsForTheme(
          tp.isCyber ? ThemeMode.dark : tp.themeMode,
          sysBrightness,
        );

        return MaterialApp(
          title: 'Response',
          navigatorKey: navigatorKey,

          /*── base themes ──────────────────────────────────────────*/
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          // use dark mode whenever the cyber option is active
          themeMode: tp.isCyber ? ThemeMode.dark : tp.themeMode,

          /*── if “Cyber” is active, override the dark theme here ──*/
          builder: (ctx, child) => tp.isCyber
              ? Theme(data: AppTheme.cyberTheme, child: child!)
              : child!,

          /*── navigation / routes ────────────────────────────────*/
          initialRoute: '/',
          navigatorObservers: [
            routeObserver,
            _StatusBarObserver(tp.isCyber ? ThemeMode.dark : tp.themeMode),
          ],
          routes: {
            '/': (_) => const SplashScreen(),
            '/login': (_) => const LoginPage(),
            '/register': (_) => const RegisterPage(),
            '/home': (_) => const MyHomePage(),
            '/profile': (_) => const ProfilePage(),
            '/settings': (_) => const SettingsPage(),
            '/pin': (_) => const PinScreen(),
            '/set-pin': (_) => const SetPinPage(),
            '/about': (_) => const AboutPage(),
            '/activity': (_) => const ActivityPage(),
            '/blockchain': (_) => const BlockchainPage(),
            '/notifications': (_) => const NotificationsPage(),
            '/privacy-policy': (_) => const PrivacyPolicyPage(),
          },
        );
      },
    );
  }
}

/*─────────────────────────────────────────────────────────────────*/
/*      keeps the status-bar icons in sync when navigating         */
/*─────────────────────────────────────────────────────────────────*/
class _StatusBarObserver extends NavigatorObserver {
  final ThemeMode _mode;
  _StatusBarObserver(this._mode);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? prev) {
    super.didPush(route, prev);
    _refreshStatusBar();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? prev) {
    super.didPop(route, prev);
    _refreshStatusBar();
  }

  void _refreshStatusBar() {
    final brightness = WidgetsBinding.instance.window.platformBrightness;
    UIOverlayHelper.refreshStatusBarIconsForTheme(_mode, brightness);
  }
}
