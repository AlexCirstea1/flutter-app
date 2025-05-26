import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class ChatBackground extends StatelessWidget {
  final Widget child;

  const ChatBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String backgroundImage;

    if (cs == AppTheme.lightTheme.colorScheme) {
      backgroundImage = 'assets/images/chat_bg.png';
    } else if (cs == AppTheme.darkTheme.colorScheme) {
      backgroundImage = 'assets/images/chat_bg_dark.png';
    } else {
      backgroundImage = 'assets/images/chat_bg_cyber.png';
    }

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(backgroundImage),
          repeat: ImageRepeat.repeat,
          fit: BoxFit.contain,
          opacity: 0.2,
          colorFilter: ColorFilter.mode(
            cs.surface,
            BlendMode.color,
          ),
        ),
      ),
      child: child,
    );
  }
}
