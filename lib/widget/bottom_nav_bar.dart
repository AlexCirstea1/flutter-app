import 'package:flutter/material.dart';
import 'package:vaultx_app/pages/home_page.dart';
import 'package:vaultx_app/pages/profile_page.dart';
import 'package:vaultx_app/pages/settings_page.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BottomNavigationBar(
      backgroundColor: colorScheme.surface,
      selectedItemColor: const Color(0xFF00B5FF),
      unselectedItemColor: Colors.grey.shade500,
      selectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
        BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined), label: 'Settings'),
        BottomNavigationBarItem(
            icon: Icon(Icons.person_outline), label: 'Profile'),
      ],
      onTap: (index) {
        _onTabSelected(context, index);
        onTap(index);
      },
    );
  }

  void _onTabSelected(BuildContext context, int index) {
    Widget destination;
    switch (index) {
      case 0:
        destination = const MyHomePage();
        break;
      case 1:
        destination = const SettingsPage();
        break;
      case 2:
        destination = const ProfilePage();
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      NoTransitionPageRoute(builder: (_) => destination),
    );
  }
}

class NoTransitionPageRoute<T> extends MaterialPageRoute<T> {
  NoTransitionPageRoute({required super.builder, super.settings});

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
