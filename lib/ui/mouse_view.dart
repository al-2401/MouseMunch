import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game_controller.dart';

/// The mouse, drawn from above so that turning towards a crumb simply rotates
/// the whole animal and it always runs head first.
class MouseView extends StatelessWidget {
  const MouseView({super.key, required this.controller, required this.onPoke});

  /// Size of the widget that holds the mouse. The body centre sits exactly in
  /// the middle, which is also the pivot the heading rotates around.
  static const Size boxSize = Size(150, 86);

  final GameController controller;
  final VoidCallback onPoke;

  @override
  Widget build(BuildContext context) {
    final position = controller.mousePosition;
    return Positioned(
      left: position.dx - boxSize.width / 2,
      top: position.dy - boxSize.height / 2,
      width: boxSize.width,
      height: boxSize.height,
      child: Transform.rotate(
        angle: controller.heading,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPoke,
          child: CustomPaint(
            size: boxSize,
            painter: MousePainter(
              activity: controller.activity,
              activityTime: controller.activityTime,
              clock: controller.clock,
              speed: controller.settings.mouseSpeed,
              eatProgress: controller.eatProgress,
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the mouse and all four of its animations: waiting, running, eating and
/// struggling.
class MousePainter extends CustomPainter {
  MousePainter({
    required this.activity,
    required this.activityTime,
    required this.clock,
    required this.speed,
    required this.eatProgress,
  });

  final MouseActivity activity;
  final double activityTime;
  final double clock;
  final double speed;
  final double eatProgress;

  static const Color _fur = Color(0xFFB4AA9E);
  static const Color _furDark = Color(0xFF8D8377);
  static const Color _belly = Color(0xFFE4DCD2);
  static const Color _outline = Color(0xFF5A5048);
  static const Color _skin = Color(0xFFEAA8AF);
  static const Color _skinDark = Color(0xFFD0808B);
  static const Color _eye = Color(0xFF2B2620);

  bool get _moving => activity == MouseActivity.moving;

  bool get _eating => activity == MouseActivity.eating;

  bool get _struggling => activity == MouseActivity.struggling;

  bool get _idle => activity == MouseActivity.idle;

  bool get _begging => activity == MouseActivity.begging;

  @override
  void paint(Canvas canvas, Size size) {
    // Stride grows with the speed setting so a fast mouse also scurries fast.
    final strideRate = (speed / 38).clamp(1.5, 6.0);
    final walk = clock * strideRate * 2 * math.pi;
    final chew = activityTime * 7 * 2 * math.pi;
    final panic = activityTime * 2 * math.pi;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);

    if (_struggling) {
      // Poked: the whole mouse jerks about.
      canvas.translate(
        math.sin(panic * 12) * 2.2,
        math.cos(panic * 9) * 2.8,
      );
      canvas.rotate(math.sin(panic * 7) * 0.07);
    }

    // Side to side sway while running, a slow breath while waiting, a little
    // hop while begging.
    final sway = _moving ? math.sin(walk) * 1.8 : 0.0;
    final beg = activityTime * 2 * math.pi * 1.3;
    final hop = _begging ? -(0.5 + 0.5 * math.sin(beg)) * 2.5 : 0.0;
    final breath = _idle
        ? 1 + 0.05 * math.sin(clock * 2 * math.pi / 1.9)
        : _begging
            ? 1.16 + 0.04 * math.sin(beg)
            : 1.0;
    canvas.translate(0, sway + hop);

    _drawShadow(canvas);
    _drawTail(canvas, walk, panic);
    _drawPaws(canvas, walk, panic, back: true);
    _drawBody(canvas, breath);
    _drawPaws(canvas, walk, panic, back: false);
    _drawHead(canvas, walk, chew, panic);

    if (_struggling) {
      _drawSqueakWaves(canvas);
    }
    if (_eating) {
      _drawCrumbBits(canvas, chew);
    }
    if (_begging) {
      _drawBegRequest(canvas);
    }

    canvas.restore();
  }

  void _drawShadow(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0x1A000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-4, 6), width: 56, height: 32),
      paint,
    );
  }

  void _drawTail(Canvas canvas, double walk, double panic) {
    final double amplitude;
    final double rate;
    if (_struggling) {
      amplitude = 15;
      rate = panic * 8;
    } else if (_moving) {
      amplitude = 9;
      rate = walk;
    } else if (_eating) {
      amplitude = 4;
      rate = clock * 2 * math.pi * 1.4;
    } else if (_begging) {
      amplitude = 5;
      rate = activityTime * 2 * math.pi * 1.1;
    } else {
      amplitude = 6;
      rate = clock * 2 * math.pi * 0.55;
    }

    final wag = math.sin(rate);
    final path = Path()
      ..moveTo(-26, 0)
      ..cubicTo(
        -38,
        amplitude * wag * 0.5,
        -48,
        -amplitude * wag * 0.6,
        -60,
        amplitude * wag,
      );

    canvas.drawPath(
      path,
      Paint()
        ..color = _skinDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _skin
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawPaws(Canvas canvas, double walk, double panic, {required bool back}) {
    final baseX = back ? -17.0 : 7.0;
    final phase = back ? math.pi : 0.0;
    final paint = Paint()..color = _skin;
    final outline = Paint()
      ..color = const Color(0x735A5048)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (final side in <double>[-1, 1]) {
      double dx = 0;
      double dy = 0;
      double spread = 15;
      if (_moving) {
        dx = math.sin(walk + phase + (side > 0 ? math.pi : 0)) * 6;
        dy = math.cos(walk + phase + (side > 0 ? math.pi : 0)) * 1.2;
      } else if (_struggling) {
        // Flailing legs, each on its own rhythm.
        dx = math.sin(panic * (back ? 11 : 13) + side) * 5;
        dy = side * (2.5 + math.cos(panic * 10 + side) * 2);
      } else if (_eating) {
        // Front paws hold the crumb, hind paws stay put.
        dx = back ? 0 : 3 + math.sin(clock * 2 * math.pi * 3.5) * 0.8;
        dy = back ? 0 : -side * 1.5;
      } else if (_begging && !back) {
        // Front paws pulled together and held up near the chest; hind paws
        // stay planted wide for balance.
        spread = 4;
        dx = 9 + math.sin(activityTime * 2 * math.pi * 1.3) * 1.2;
      }

      final center = Offset(baseX + dx, side * spread + dy);
      final rect = Rect.fromCenter(center: center, width: 13, height: 8);
      canvas.drawOval(rect, paint);
      canvas.drawOval(rect, outline);
    }
  }

  void _drawBody(Canvas canvas, double breath) {
    // Eating squashes the body a little on every bite, waiting makes it breathe.
    final squash = _eating ? 1 + 0.03 * math.sin(activityTime * 7 * 2 * math.pi) : 1.0;
    final rect = Rect.fromCenter(
      center: const Offset(-5, 0),
      width: 50 * (2 - breath) * (2 - squash),
      height: 33 * breath * squash,
    );

    canvas.drawOval(rect, Paint()..color = _fur);
    // Darker fur along the back, lighter fur down the middle.
    canvas.drawOval(
      rect.deflate(3).shift(const Offset(-6, 0)),
      Paint()..color = _furDark,
    );
    canvas.drawOval(
      rect.deflate(7).shift(const Offset(-2, 0)),
      Paint()..color = _belly,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..color = _outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawHead(Canvas canvas, double walk, double chew, double panic) {
    canvas.save();

    // The head dips forward over the crumb while eating and bobs while running.
    if (_eating) {
      canvas.translate(3.5, 0);
      canvas.rotate(math.sin(chew) * 0.05);
    } else if (_moving) {
      canvas.translate(0, math.sin(walk) * 0.8);
      canvas.rotate(math.sin(walk) * 0.04);
    } else if (_struggling) {
      canvas.rotate(math.sin(panic * 9) * 0.12);
    } else if (_begging) {
      canvas.translate(-2, 0);
    }

    _drawEars(canvas, panic);

    // Head and snout in one silhouette.
    final head = Path()
      ..addOval(Rect.fromCircle(center: const Offset(18, 0), radius: 14))
      ..moveTo(16, -10)
      ..quadraticBezierTo(31, -7, 36, 0)
      ..quadraticBezierTo(31, 7, 16, 10)
      ..close();

    canvas.drawPath(head, Paint()..color = _fur);
    canvas.drawPath(
      head,
      Paint()
        ..color = _outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    _drawMouth(canvas, chew);
    _drawEyes(canvas);
    _drawWhiskers(canvas, walk);

    // Nose.
    canvas.drawCircle(const Offset(36, 0), 3, Paint()..color = _skinDark);
    canvas.drawCircle(const Offset(35, -1), 1.1, Paint()..color = _skin);

    canvas.restore();
  }

  void _drawEars(Canvas canvas, double panic) {
    // A twitch every few seconds keeps the waiting mouse alive; when the mouse
    // struggles the ears are pinned back.
    final twitchCycle = clock % 3.2;
    final twitch = _idle && twitchCycle < 0.22 ? math.sin(twitchCycle / 0.22 * math.pi) * 2.5 : 0.0;
    final pinned = _struggling ? -4.0 : 0.0;
    final flutter = _struggling ? math.sin(panic * 10) * 1.5 : 0.0;

    for (final side in <double>[-1, 1]) {
      final center = Offset(12 + pinned, side * (14 + twitch) + flutter * side);
      canvas.drawCircle(center, 9.5, Paint()..color = _fur);
      canvas.drawCircle(
        center,
        9.5,
        Paint()
          ..color = _outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(center, 5.5, Paint()..color = _skin);
    }
  }

  void _drawEyes(Canvas canvas) {
    // Blink now and then while waiting.
    final blinkCycle = clock % 2.9;
    final blinking = _idle && blinkCycle < 0.13;

    for (final side in <double>[-1, 1]) {
      final center = Offset(24, side * 6.5);
      if (blinking) {
        canvas.drawLine(
          center - const Offset(2.4, 0),
          center + const Offset(2.4, 0),
          Paint()
            ..color = _eye
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round,
        );
        continue;
      }
      // Wide open eyes when the mouse is startled.
      final radius = _struggling ? 3.4 : 2.6;
      canvas.drawCircle(center, radius, Paint()..color = _eye);
      canvas.drawCircle(
        center + const Offset(0.9, -0.9),
        radius * 0.35,
        Paint()..color = Colors.white,
      );
    }
  }

  void _drawMouth(Canvas canvas, double chew) {
    if (_eating) {
      // Chewing: the jaw opens and closes quickly.
      final open = (0.5 + 0.5 * math.sin(chew)) * 4.2 + 1;
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(31, 0), width: 7, height: open),
        Paint()..color = const Color(0xFF6B4A44),
      );
      return;
    }
    if (_begging) {
      // A small hopeful "o", asking nicely.
      final open = 2.2 + 0.8 * math.sin(activityTime * 2 * math.pi * 1.3).abs();
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(31, 0), width: 5, height: open),
        Paint()..color = const Color(0xFF6B4A44),
      );
      return;
    }
    if (_struggling) {
      // Squeaking: the mouth stays wide open.
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(31, 0), width: 8, height: 7),
        Paint()..color = const Color(0xFF6B4A44),
      );
    }
  }

  void _drawWhiskers(Canvas canvas, double walk) {
    final double jitter;
    if (_struggling) {
      jitter = math.sin(activityTime * 2 * math.pi * 11) * 3;
    } else if (_eating) {
      jitter = math.sin(activityTime * 2 * math.pi * 7) * 1.6;
    } else if (_moving) {
      jitter = math.sin(walk) * 1.2;
    } else if (_begging) {
      jitter = math.sin(activityTime * 2 * math.pi * 1.3) * 1.0;
    } else {
      jitter = math.sin(clock * 2 * math.pi * 0.5) * 0.6;
    }

    final paint = Paint()
      ..color = const Color(0xB35A5048)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;

    const tips = <Offset>[Offset(53, 2), Offset(51, 9), Offset(47, 16)];
    for (final side in <double>[-1, 1]) {
      for (final tip in tips) {
        canvas.drawLine(
          Offset(33, side * 3),
          Offset(tip.dx, side * (tip.dy + jitter)),
          paint,
        );
      }
    }
  }

  void _drawSqueakWaves(Canvas canvas) {
    // Little arcs in front of the muzzle to make the squeak visible.
    for (var i = 0; i < 3; i++) {
      final phase = (activityTime * 2.2 + i * 0.33) % 1;
      final paint = Paint()
        ..color = Color.fromRGBO(255, 255, 255, (1 - phase) * 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(34, 0), radius: 10 + phase * 18),
        -0.7,
        1.4,
        false,
        paint,
      );
    }
  }

  void _drawCrumbBits(Canvas canvas, double chew) {
    // Crumbs spraying from the mouth while the mouse chews; fewer and fewer as
    // the crumb is finished off.
    final fade = 1 - eatProgress * 0.7;
    for (var i = 0; i < 3; i++) {
      final phase = (chew / (2 * math.pi) + i / 3) % 1;
      final paint = Paint()
        ..color = Color.fromRGBO(0xB0, 0x7B, 0x48, (1 - phase) * 0.9 * fade);
      canvas.drawCircle(
        Offset(36 + phase * 9, (i - 1) * 6.0 * (0.4 + phase)),
        1.8 * (1 - phase * 0.5),
        paint,
      );
    }
  }

  void _drawBegRequest(Canvas canvas) {
    // A little crumb bobbing above the head: "feed me".
    final bounce = 0.5 + 0.5 * math.sin(activityTime * 2 * math.pi * 1.3);
    final center = Offset(30, -14 - bounce * 4);
    canvas.drawCircle(
      center,
      4.5,
      Paint()..color = Color.fromRGBO(0xB0, 0x7B, 0x48, 0.55 + bounce * 0.35),
    );
    canvas.drawCircle(
      center,
      4.5,
      Paint()
        ..color = const Color(0x665A5048)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant MousePainter oldDelegate) => true;
}
