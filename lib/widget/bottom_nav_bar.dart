import 'package:flutter/material.dart';
import 'package:icons_flutter/icons_flutter.dart';

import '../pages/activity_page.dart';
import '../pages/blockchain_page.dart';
import '../pages/home_page.dart';
import '../pages/profile_page.dart';
import '../pages/settings_page.dart';

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
    return Container(
      height: 75,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF121A24), Color(0xFF090F16)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(0, -3),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: Colors.cyan.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(
            bottom: 21), // Increased bottom padding to move content up
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(context, 0, Ionicons.ios_chatbubbles, 'CHAT'),
            _buildNavItem(context, 1, Icons.person_outline, 'PROFILE'),
            _buildNavItem(context, 2, Icons.link, 'BLOCKCHAIN'),
            _buildNavItem(context, 3, Icons.history_outlined, 'ACTIVITY'),
            _buildNavItem(context, 4, Icons.settings_outlined, 'SETTINGS'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
      BuildContext context, int index, IconData icon, String label) {
    final isSelected = index == currentIndex;

    return InkWell(
      onTap: () {
        _onTabSelected(context, index);
        onTap(index);
      },
      child: Container(
        width: MediaQuery.of(context).size.width / 5,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isSelected ? Colors.cyan : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8), // Reduced top padding slightly
            Icon(
              icon,
              color: isSelected ? Colors.cyan : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.cyan.shade100 : Colors.grey.shade600,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 1.0,
                shadows: isSelected
                    ? [
                        Shadow(
                          color: Colors.cyan.withOpacity(0.3),
                          blurRadius: 5,
                        )
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
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
