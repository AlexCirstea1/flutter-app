import 'package:flutter/material.dart';

class BackgroundWithCurve extends StatelessWidget {
  const BackgroundWithCurve({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipPath(
          clipper: RightSideCurveClipper(),
          child: Container(
            height: 300,
            color: const Color(0xFF1B4A36),
          ),
        ),
        child,
      ],
    );
  }
}

class RightSideCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();

    path.lineTo(0, 0);

    path.lineTo(0, size.height);

    path.lineTo(size.width * 0.8, size.height);
    path.quadraticBezierTo(
      size.width,
      size.height,
      size.width,
      size.height * 0.7,
    );

    path.lineTo(size.width, 0);

    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
