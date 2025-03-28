import 'package:flutter/material.dart';
import 'package:icons_flutter/icons_flutter.dart';
import 'package:vaultx_app/pages/home_page.dart';
import 'package:vaultx_app/pages/profile_page.dart';
import 'package:vaultx_app/pages/settings_page.dart';

import '../pages/activity_page.dart';
import '../pages/blockchain_page.dart';

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
        BottomNavigationBarItem(
          icon: Icon(Ionicons.ios_chatbubbles),
          label: 'Chat',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
        BottomNavigationBarItem(
            icon: Icon(Icons.link),
            label: 'Blockchain'
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history_outlined),
          label: 'Activity',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          label: 'Settings',
        ),
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
        destination = const ProfilePage();
        break;
      case 2:
        destination = const BlockchainPage();
        break;
      case 3:
        destination = const ActivityPage();
        break;
      case 4:
        destination = const SettingsPage();
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
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return child;
  }
}
