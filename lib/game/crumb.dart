import 'dart:math' as math;
import 'dart:ui';

/// A single crumb lying on the floor.
///
/// A crumb is poured out of the feeder, so it first flies from [origin] to its
/// resting place at [position]; only after it has landed can the mouse eat it.
class Crumb {
  Crumb({
    required this.id,
    required this.origin,
    required this.position,
    required this.size,
    required this.rotation,
    required this.shapeSeed,
    required double delay,
  }) : _delay = delay;

  /// How long a crumb needs to reach the floor, in seconds.
  static const double fallDuration = 0.55;

  final int id;
  final Offset origin;
  final Offset position;
  final double size;
  final double rotation;
  final int shapeSeed;

  double _delay;
  double _fall = 0;

  /// Progress of the falling animation, 0 while still in the feeder, 1 once the
  /// crumb has settled on the floor.
  double get fallProgress => _fall;

  bool get hasLanded => _fall >= 1;

  /// Advances the falling animation by [dt] seconds.
  void advance(double dt) {
    if (hasLanded) return;
    if (_delay > 0) {
      _delay -= dt;
      if (_delay > 0) return;
      dt = -_delay;
      _delay = 0;
    }
    _fall = math.min(1, _fall + dt / fallDuration);
  }

  /// Where the crumb is drawn right now.
  Offset get currentPosition {
    if (hasLanded) return position;
    final t = _fall;
    // Horizontal travel eases out, the vertical one accelerates like gravity.
    final x = origin.dx + (position.dx - origin.dx) * (1 - (1 - t) * (1 - t));
    var y = origin.dy + (position.dy - origin.dy) * t * t;
    // A tiny hop right before the crumb settles.
    if (t > 0.82) {
      final bounce = (t - 0.82) / 0.18;
      y -= math.sin(bounce * math.pi) * 9 * (1 - bounce);
    }
    return Offset(x, y);
  }

  /// Crumbs pop into existence as they leave the feeder.
  double get currentScale => math.min(1, 0.2 + _fall * 3);

  /// Crumbs tumble while they fall and then lie still.
  double get currentRotation => rotation + (1 - _fall) * math.pi * 1.5;
}
