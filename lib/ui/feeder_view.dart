import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The feeder in the top right corner. Tapping it plays a press animation and
/// pours a fresh portion of crumbs onto the floor.
class FeederView extends StatefulWidget {
  const FeederView({super.key, required this.rect, required this.onPour});

  /// Where the feeder sits inside the play field.
  final Rect rect;

  /// Called once per tap, after the press animation has started.
  final VoidCallback onPour;

  @override
  State<FeederView> createState() => _FeederViewState();
}

class _FeederViewState extends State<FeederView> with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 320),
    vsync: this,
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    widget.onPour();
    await _press.forward(from: 0);
    if (mounted) {
      await _press.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: widget.rect,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: _press,
          builder: (context, child) {
            final t = Curves.easeOut.transform(_press.value);
            // The feeder dips, tips over and shakes the crumbs out.
            return Transform.translate(
              offset: Offset(math.sin(t * math.pi * 3) * 2.5, t * 4),
              child: Transform.rotate(
                angle: t * 0.13,
                alignment: Alignment.topCenter,
                child: Transform.scale(
                  scale: 1 - t * 0.06,
                  alignment: Alignment.topCenter,
                  child: CustomPaint(painter: FeederPainter(press: t)),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Draws a wall mounted crumb feeder with a heap of crumbs inside.
class FeederPainter extends CustomPainter {
  FeederPainter({required this.press});

  /// 0 when idle, 1 at the bottom of the press animation.
  final double press;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Bracket holding the feeder.
    final bracket = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, h * 0.02, w * 0.76, h * 0.12),
      const Radius.circular(6),
    );
    canvas.drawRRect(bracket, Paint()..color = const Color(0xFF6D5B4B));

    // Hopper body: a trapezoid narrowing towards the spout.
    final body = Path()
      ..moveTo(w * 0.08, h * 0.14)
      ..lineTo(w * 0.92, h * 0.14)
      ..lineTo(w * 0.72, h * 0.72)
      ..lineTo(w * 0.28, h * 0.72)
      ..close();

    canvas.drawPath(body, Paint()..color = const Color(0xFFD8B27A));
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xFF8A6534)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Glass window with the crumb supply behind it.
    final window = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.22, h * 0.24, w * 0.56, h * 0.34),
      const Radius.circular(5),
    );
    canvas.save();
    canvas.clipRRect(window);
    canvas.drawRRect(window, Paint()..color = const Color(0xFFF3E4C6));
    final random = math.Random(7);
    for (var i = 0; i < 26; i++) {
      final dx = w * (0.22 + random.nextDouble() * 0.56);
      final dy = h * (0.34 + random.nextDouble() * 0.24) + press * 3;
      canvas.drawCircle(
        Offset(dx, dy),
        1.6 + random.nextDouble() * 1.8,
        Paint()..color = const Color(0xFFBE8A4A),
      );
    }
    canvas.restore();
    canvas.drawRRect(
      window,
      Paint()
        ..color = const Color(0xFF8A6534)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Spout.
    final spout = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.34, h * 0.7, w * 0.32, h * 0.18),
      const Radius.circular(4),
    );
    canvas.drawRRect(spout, Paint()..color = const Color(0xFFB98F52));
    canvas.drawRRect(
      spout,
      Paint()
        ..color = const Color(0xFF8A6534)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // A few crumbs escaping while the feeder is pressed.
    if (press > 0.05) {
      final spill = math.Random(19);
      for (var i = 0; i < 6; i++) {
        final t = ((press * 1.4) + i / 6) % 1;
        canvas.drawCircle(
          Offset(w * (0.42 + spill.nextDouble() * 0.16), h * 0.88 + t * h * 0.16),
          2 * (1 - t * 0.5),
          Paint()..color = Color.fromRGBO(0xBE, 0x8A, 0x4A, 1 - t),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant FeederPainter oldDelegate) => oldDelegate.press != press;
}
