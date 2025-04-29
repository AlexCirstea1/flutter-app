import 'package:flutter/material.dart';
import 'package:icons_flutter/icons_flutter.dart';
import 'package:vaultx_app/features/blockchain/presentation/pages/events_page.dart';

import '../../features/activity/presentation/pages/activity_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 75,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.surface,
            colorScheme.surface.withOpacity(0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.6),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(0, -3),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: colorScheme.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 21),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
              color: isSelected ? colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Icon(
              icon,
              color: isSelected
                  ? colorScheme.primary
                  : theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
              size: 24,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? colorScheme.primary.withOpacity(0.9)
                    : theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 1.0,
                shadows: isSelected
                    ? [
                        Shadow(
                          color: colorScheme.primary.withOpacity(0.3),
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
        destination = const EventsPage();
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
