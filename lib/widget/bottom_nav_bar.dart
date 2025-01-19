import 'package:flutter/material.dart';
import 'package:vaultx_app/pages/home_page.dart';
import 'package:vaultx_app/pages/profile_page.dart';
import 'package:vaultx_app/pages/settings_page.dart'; // Assuming a settings page exists

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
    return BottomNavigationBar(
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
      currentIndex: currentIndex,
      // selectedItemColor: Colors.orange,
      onTap: (index) {
        _onTabSelected(context, index); // Handle tab selection
        onTap(index); // Notify parent widget
      },
    );
  }

  void _onTabSelected(BuildContext context, int index) {
    // Use NoTransitionPageRoute only for home, settings, and profile
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          NoTransitionPageRoute(builder: (context) => const MyHomePage()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          NoTransitionPageRoute(builder: (context) => const SettingsPage()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          NoTransitionPageRoute(builder: (context) => const ProfilePage()),
        );
        break;
    }
  }
}

class NoTransitionPageRoute<T> extends MaterialPageRoute<T> {
  NoTransitionPageRoute({required super.builder, super.settings});

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return child; // No transitions, return the page immediately
  }
}
