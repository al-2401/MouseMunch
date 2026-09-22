import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../audio/sound_manager.dart';
import 'crumb.dart';
import 'game_settings.dart';

/// What the mouse is doing right now. Each value has its own animation.
enum MouseActivity {
  /// Nothing left to eat: the mouse waits, breathing and flicking its tail.
  idle,

  /// Running head first towards the next crumb.
  moving,

  /// Standing still over a crumb and chewing it.
  eating,

  /// Poked by the player: squeaking and struggling.
  struggling,

  /// Floor is empty: standing up on its hind legs at the centre, asking to
  /// be fed.
  begging,
}

/// Runs the simulation: the crumbs, the mouse and the transitions between its
/// activities. The controller notifies its listeners once per frame.
class GameController extends ChangeNotifier {
  GameController({required this.settings, required this.sound}) {
    settings.addListener(_onSettingsChanged);
  }

  /// How long the mouse struggles after being poked, in seconds.
  static const double struggleDuration = 1.1;

  /// How long a begging mouse stands up before dropping back down, in seconds.
  static const double beggingDuration = 1.6;

  /// How long the mouse waits at the centre between begs, in seconds.
  static const double beggingCooldown = 2.4;

  /// How close the mouse has to get before it can start eating.
  static const double arriveDistance = 24;

  /// How fast the mouse turns towards its target, in radians per second.
  static const double turnRate = 7;

  /// Tightest curve the mouse can run, in pixels. Fast mice turn faster so the
  /// curve stays tighter than [arriveDistance] and they cannot end up circling
  /// a crumb forever.
  static const double minTurnRadius = 16;

  /// Keeps crumbs away from the edges of the screen.
  static const double fieldMargin = 30;

  /// Repeat interval of the crunch sound while eating.
  static const double _crunchInterval = 0.36;

  final GameSettings settings;
  final SoundManager sound;

  final List<Crumb> crumbs = <Crumb>[];
  final math.Random _random = math.Random();

  Size fieldSize = Size.zero;

  /// Area of the feeder, kept free of crumbs.
  Rect feederRect = Rect.zero;

  Offset mousePosition = Offset.zero;

  /// Facing of the mouse in radians, 0 means "looking right".
  double heading = 0;

  MouseActivity activity = MouseActivity.idle;

  /// Seconds spent in the current activity, drives the activity animations.
  double activityTime = 0;

  /// Seconds since the game started, drives idle breathing and tail motion.
  double clock = 0;

  int eatenCount = 0;

  int? _targetId;
  bool _headingToCenter = false;
  int _nextCrumbId = 0;
  double _crunchTimer = 0;

  /// Crumbs that are still on the floor.
  int get remainingCrumbs => crumbs.length;

  /// The crumb the mouse is heading for, if it still exists.
  Crumb? get targetCrumb {
    final id = _targetId;
    if (id == null) return null;
    for (final crumb in crumbs) {
      if (crumb.id == id) return crumb;
    }
    return null;
  }

  /// Progress of the current meal, 0 to 1. Used by the eating animation.
  double get eatProgress {
    if (activity != MouseActivity.eating) return 0;
    return (activityTime / settings.eatDuration).clamp(0, 1);
  }

  /// Where the mouse waits and begs once the floor is empty.
  Offset get _fieldCenter => Offset(fieldSize.width / 2, fieldSize.height / 2);

  /// Called by the layout once the size of the play field is known.
  void resize(Size size, Rect feeder) {
    feederRect = feeder;
    if (size == fieldSize) return;
    final isFirstLayout = fieldSize.isEmpty;
    fieldSize = size;
    if (isFirstLayout) {
      mousePosition = Offset(size.width * 0.5, size.height * 0.72);
      heading = -math.pi / 2;
    } else {
      mousePosition = _clampToField(mousePosition);
    }
    notifyListeners();
  }

  /// Advances the simulation by [dt] seconds.
  void tick(double dt) {
    if (fieldSize.isEmpty) return;
    clock += dt;
    activityTime += dt;

    for (final crumb in crumbs) {
      crumb.advance(dt);
    }

    switch (activity) {
      case MouseActivity.idle:
        _tickIdle();
      case MouseActivity.moving:
        _tickMoving(dt);
      case MouseActivity.eating:
        _tickEating(dt);
      case MouseActivity.struggling:
        _tickStruggling();
      case MouseActivity.begging:
        _tickBegging(dt);
    }

    notifyListeners();
  }

  /// Pours [GameSettings.crumbCount] crumbs onto the floor, starting at
  /// [from] — the mouth of the feeder.
  void pourCrumbs(Offset from) {
    if (fieldSize.isEmpty) return;
    sound.play(Sfx.pour);
    for (var i = 0; i < settings.crumbCount; i++) {
      crumbs.add(
        Crumb(
          id: _nextCrumbId++,
          origin: from,
          position: _randomFloorPoint(),
          size: 7 + _random.nextDouble() * 6,
          rotation: _random.nextDouble() * math.pi * 2,
          shapeSeed: _random.nextInt(1 << 30),
          delay: i * 0.05 + _random.nextDouble() * 0.06,
        ),
      );
    }
    notifyListeners();
  }

  /// The player poked the mouse.
  void pokeMouse() {
    sound.play(Sfx.squeak);
    if (activity != MouseActivity.moving && activity != MouseActivity.eating) {
      return;
    }
    sound.stopMoveLoop();
    _setActivity(MouseActivity.struggling);
  }

  /// Removes every crumb and sends the mouse back to waiting.
  void clearCrumbs() {
    if (crumbs.isEmpty) return;
    crumbs.clear();
    _targetId = null;
    _headingToCenter = false;
    sound.stopMoveLoop();
    _setActivity(MouseActivity.idle);
  }

  @override
  void dispose() {
    settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _tickIdle() {
    final next = _nearestCrumb();
    if (next != null) {
      _targetId = next.id;
      sound.startMoveLoop(rate: settings.footstepRate);
      _setActivity(MouseActivity.moving);
      return;
    }
    // Crumbs still falling from the feeder: wait for them to land instead of
    // heading off to beg.
    if (crumbs.isNotEmpty) return;
    _tickCraving();
  }

  /// Nothing left on the floor: the mouse heads to the centre and asks for
  /// more, on a loop, until it is fed again.
  void _tickCraving() {
    if ((_fieldCenter - mousePosition).distance > arriveDistance) {
      _headingToCenter = true;
      sound.startMoveLoop(rate: settings.footstepRate);
      _setActivity(MouseActivity.moving);
      return;
    }
    if (activityTime >= beggingCooldown) {
      _beginBegging();
    }
  }

  void _tickMoving(double dt) {
    // A crumb landed while the mouse was on its way to beg: go eat instead.
    if (_headingToCenter && crumbs.isNotEmpty) {
      final nearest = _nearestCrumb();
      if (nearest != null) {
        _headingToCenter = false;
        _targetId = nearest.id;
      }
    }

    Offset targetPosition;
    if (_headingToCenter) {
      targetPosition = _fieldCenter;
    } else {
      final target = targetCrumb;
      if (target == null || !target.hasLanded) {
        sound.stopMoveLoop();
        _targetId = null;
        _setActivity(MouseActivity.idle);
        return;
      }
      targetPosition = target.position;
    }

    final toTarget = targetPosition - mousePosition;
    final distance = toTarget.distance;
    if (distance <= arriveDistance) {
      sound.stopMoveLoop();
      if (_headingToCenter) {
        _headingToCenter = false;
        _beginBegging();
      } else {
        _beginEating();
      }
      return;
    }

    // The mouse always runs head first, so it turns towards the target and
    // then moves along its own facing.
    final desired = toTarget.direction;
    final maxTurn = math.max(turnRate, settings.mouseSpeed / minTurnRadius) * dt;
    heading = _turnTowards(heading, desired, maxTurn);

    // Rounding a sharp corner slows the mouse down, the way a real one skids.
    final offCourse = _angleDifference(desired, heading).abs();
    final slowdown = offCourse > 1.0 ? 0.4 : 1.0;
    final step = math.min(settings.mouseSpeed * slowdown * dt, distance);
    mousePosition = _clampToField(
      mousePosition + Offset(math.cos(heading), math.sin(heading)) * step,
    );
  }

  void _tickEating(double dt) {
    _crunchTimer -= dt;
    if (_crunchTimer <= 0) {
      sound.play(Sfx.eat, volume: 0.9);
      _crunchTimer = _crunchInterval;
    }

    if (activityTime < settings.eatDuration) return;

    final target = targetCrumb;
    if (target != null) {
      crumbs.removeWhere((crumb) => crumb.id == target.id);
      eatenCount++;
    }
    _targetId = null;
    _setActivity(MouseActivity.idle);
  }

  void _tickStruggling() {
    if (activityTime < struggleDuration) return;
    // Back to work: the idle step picks the nearest crumb again on the next
    // frame, which is the one the mouse was busy with.
    _setActivity(MouseActivity.idle);
  }

  void _tickBegging(double dt) {
    // Face the player while asking.
    heading = _turnTowards(heading, -math.pi / 2, turnRate * dt);

    // A crumb landed while the mouse was mid-beg: drop down and go eat.
    if (crumbs.isNotEmpty) {
      _setActivity(MouseActivity.idle);
      return;
    }
    if (activityTime >= beggingDuration) {
      _setActivity(MouseActivity.idle);
    }
  }

  void _beginEating() {
    _crunchTimer = 0;
    _setActivity(MouseActivity.eating);
  }

  void _beginBegging() {
    sound.play(Sfx.squeak, volume: 0.45);
    _setActivity(MouseActivity.begging);
  }

  void _setActivity(MouseActivity next) {
    activity = next;
    activityTime = 0;
  }

  Crumb? _nearestCrumb() {
    Crumb? best;
    var bestDistance = double.infinity;
    for (final crumb in crumbs) {
      if (!crumb.hasLanded) continue;
      final distance = (crumb.position - mousePosition).distanceSquared;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = crumb;
      }
    }
    return best;
  }

  /// Picks a free spot on the floor, away from the edges, the feeder and — as
  /// far as a few attempts allow — from the other crumbs.
  Offset _randomFloorPoint() {
    final maxX = math.max(fieldMargin + 1, fieldSize.width - fieldMargin);
    final maxY = math.max(fieldMargin + 1, fieldSize.height - fieldMargin);
    Offset? fallback;
    for (var attempt = 0; attempt < 16; attempt++) {
      final point = Offset(
        fieldMargin + _random.nextDouble() * (maxX - fieldMargin),
        fieldMargin + _random.nextDouble() * (maxY - fieldMargin),
      );
      fallback ??= point;
      if (feederRect.inflate(8).contains(point)) continue;
      final tooClose = crumbs.any(
        (crumb) => (crumb.position - point).distance < 22,
      );
      if (tooClose) continue;
      return point;
    }
    return fallback!;
  }

  Offset _clampToField(Offset point) {
    if (fieldSize.isEmpty) return point;
    return Offset(
      point.dx.clamp(fieldMargin, math.max(fieldMargin, fieldSize.width - fieldMargin)),
      point.dy.clamp(fieldMargin, math.max(fieldMargin, fieldSize.height - fieldMargin)),
    );
  }

  /// Rotates [from] towards [to] by at most [maxDelta] radians, along the
  /// shortest arc.
  static double _turnTowards(double from, double to, double maxDelta) {
    final diff = _angleDifference(to, from);
    if (diff.abs() <= maxDelta) return to;
    return from + maxDelta * (diff.isNegative ? -1 : 1);
  }

  /// Shortest signed angle that turns [from] into [to], in radians.
  static double _angleDifference(double to, double from) {
    final diff = (to - from) % (2 * math.pi);
    return diff > math.pi ? diff - 2 * math.pi : diff;
  }

  void _onSettingsChanged() {
    sound.setEnabled(settings.soundEnabled);
    sound.setMoveRate(settings.footstepRate);
  }
}
