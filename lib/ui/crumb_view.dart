import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/crumb.dart';

/// A crumb on the floor, still tumbling out of the feeder or already waiting
/// to be eaten.
class CrumbView extends StatelessWidget {
  const CrumbView({super.key, required this.crumb});

  final Crumb crumb;

  @override
  Widget build(BuildContext context) {
    final position = crumb.currentPosition;
    final box = crumb.size * 2.6;
    return Positioned(
      left: position.dx - box / 2,
      top: position.dy - box / 2,
      width: box,
      height: box,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: crumb.currentRotation,
          child: Transform.scale(
            scale: crumb.currentScale,
            child: CustomPaint(
              painter: CrumbPainter(seed: crumb.shapeSeed, radius: crumb.size / 2),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints one irregular, bread coloured crumb.
class CrumbPainter extends CustomPainter {
  CrumbPainter({required this.seed, required this.radius});

  final int seed;
  final double radius;

  static const List<Color> _crusts = <Color>[
    Color(0xFFC79355),
    Color(0xFFB5813F),
    Color(0xFFD9AA6C),
    Color(0xFFA76F34),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final center = Offset(size.width / 2, size.height / 2);
    const corners = 7;

    final path = Path();
    for (var i = 0; i < corners; i++) {
      final angle = i / corners * 2 * math.pi;
      final r = radius * (0.62 + random.nextDouble() * 0.38);
      final point = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, radius * 0.45),
        width: radius * 2.1,
        height: radius * 1.1,
      ),
      Paint()..color = const Color(0x22000000),
    );

    final color = _crusts[random.nextInt(_crusts.length)];
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x55704620)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      center + Offset(-radius * 0.25, -radius * 0.25),
      radius * 0.22,
      Paint()..color = const Color(0x66FFF0D8),
    );
  }

  @override
  bool shouldRepaint(covariant CrumbPainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.radius != radius;
}
