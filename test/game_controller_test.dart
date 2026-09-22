import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mouse_munch/audio/sound_manager.dart';
import 'package:mouse_munch/game/game_controller.dart';
import 'package:mouse_munch/game/game_settings.dart';

const Size _field = Size(400, 800);
const Rect _feeder = Rect.fromLTWH(286, 14, 100, 110);

/// Builds a controller with muted audio, so no platform plugin is touched.
GameController _buildController({
  int crumbCount = 1,
  double mouseSpeed = 220,
  double eatSpeed = 4,
}) {
  final settings = GameSettings(
    crumbCount: crumbCount,
    mouseSpeed: mouseSpeed,
    eatSpeed: eatSpeed,
    soundEnabled: false,
  );
  final controller = GameController(
    settings: settings,
    sound: SoundManager(enabled: false),
  );
  controller.resize(_field, _feeder);
  return controller;
}

/// Runs the simulation for [seconds], or until [until] is satisfied.
void _simulate(GameController controller, double seconds, {bool Function()? until}) {
  const step = 1 / 60;
  for (var elapsed = 0.0; elapsed < seconds; elapsed += step) {
    if (until != null && until()) return;
    controller.tick(step);
  }
}

void main() {
  test('poured crumbs land on the floor, clear of the feeder', () {
    final controller = _buildController(crumbCount: 20);
    controller.pourCrumbs(_feeder.bottomCenter);

    expect(controller.crumbs, hasLength(20));
    for (final crumb in controller.crumbs) {
      expect(crumb.hasLanded, isFalse);
      expect(crumb.position.dx, inInclusiveRange(GameController.fieldMargin, _field.width - GameController.fieldMargin));
      expect(crumb.position.dy, inInclusiveRange(GameController.fieldMargin, _field.height - GameController.fieldMargin));
      expect(_feeder.contains(crumb.position), isFalse);
    }

    _simulate(controller, 3);
    expect(controller.crumbs.every((crumb) => crumb.hasLanded), isTrue);
  });

  test('the mouse runs to a crumb, eats it and then waits', () {
    final controller = _buildController();
    controller.pourCrumbs(_feeder.bottomCenter);

    _simulate(controller, 2, until: () => controller.activity == MouseActivity.moving);
    expect(controller.activity, MouseActivity.moving);

    _simulate(controller, 6, until: () => controller.activity == MouseActivity.eating);
    expect(controller.activity, MouseActivity.eating);

    _simulate(controller, 4);
    expect(controller.crumbs, isEmpty);
    expect(controller.eatenCount, 1);
    expect(controller.activity, MouseActivity.idle);
  });

  test('the mouse always runs head first', () {
    final controller = _buildController(crumbCount: 12, mouseSpeed: 60);
    controller.pourCrumbs(_feeder.bottomCenter);

    var samples = 0;
    for (var frame = 0; frame < 60 * 30; frame++) {
      controller.tick(1 / 60);
      final target = controller.targetCrumb;
      if (controller.activity != MouseActivity.moving || target == null) continue;
      // Skip the first moments of a leg, while the mouse is still turning, and
      // the last ones, where a tiny sideways offset is a large angle.
      if (controller.activityTime < 0.6) continue;
      if ((target.position - controller.mousePosition).distance < 60) continue;

      var diff = (target.position - controller.mousePosition).direction - controller.heading;
      diff %= 2 * math.pi;
      if (diff > math.pi) diff -= 2 * math.pi;
      expect(diff.abs(), lessThan(0.2), reason: 'the head points at the crumb');
      samples++;
    }

    expect(samples, greaterThan(10), reason: 'the mouse did travel during the test');
  });

  test('poking the mouse interrupts it and then it goes back to the crumb', () {
    final controller = _buildController(crumbCount: 3, eatSpeed: 0.5);
    controller.pourCrumbs(_feeder.bottomCenter);
    _simulate(controller, 3, until: () => controller.activity == MouseActivity.moving);

    controller.pokeMouse();
    expect(controller.activity, MouseActivity.struggling);

    final frozenAt = controller.mousePosition;
    _simulate(controller, GameController.struggleDuration * 0.5);
    expect(controller.activity, MouseActivity.struggling);
    expect(controller.mousePosition, frozenAt, reason: 'a struggling mouse does not travel');

    _simulate(controller, GameController.struggleDuration);
    expect(controller.activity, isNot(MouseActivity.struggling));
    expect(controller.crumbs, hasLength(3), reason: 'nothing is eaten while struggling');
  });

  test('every crumb is eventually eaten and the mouse ends up idle', () {
    final controller = _buildController(crumbCount: 8, mouseSpeed: 420, eatSpeed: 4);
    controller.pourCrumbs(_feeder.bottomCenter);

    _simulate(controller, 60, until: () => controller.crumbs.isEmpty);
    expect(controller.crumbs, isEmpty);
    expect(controller.eatenCount, 8);

    // The floor is empty, so the mouse heads off to beg instead of staying put.
    _simulate(controller, 1);
    expect(controller.activity, isNot(MouseActivity.eating));
    expect(controller.activity, isNot(MouseActivity.struggling));
  });

  test('an empty floor sends the mouse to beg at the centre until fed', () {
    final controller = _buildController(crumbCount: 1, mouseSpeed: 300, eatSpeed: 4);
    controller.pourCrumbs(_feeder.bottomCenter);
    _simulate(controller, 10, until: () => controller.crumbs.isEmpty);
    expect(controller.crumbs, isEmpty);

    _simulate(controller, 5, until: () => controller.activity == MouseActivity.begging);
    expect(controller.activity, MouseActivity.begging);
    final centre = Offset(_field.width / 2, _field.height / 2);
    expect(
      (controller.mousePosition - centre).distance,
      lessThan(GameController.arriveDistance + 1),
    );

    // It drops back down after a while...
    _simulate(controller, GameController.beggingDuration + 0.5);
    expect(controller.activity, isNot(MouseActivity.begging));

    // ...and asks again on its own, since nothing was poured.
    _simulate(
      controller,
      GameController.beggingCooldown + 1,
      until: () => controller.activity == MouseActivity.begging,
    );
    expect(controller.activity, MouseActivity.begging);

    // Feeding it interrupts the begging cycle for good.
    controller.pourCrumbs(_feeder.bottomCenter);
    _simulate(
      controller,
      6,
      until: () => controller.activity == MouseActivity.moving && controller.targetCrumb != null,
    );
    expect(controller.targetCrumb, isNotNull);
  });

  test('settings stay inside their limits and drive the eating duration', () {
    final settings = GameSettings();

    settings.crumbCount = 1000;
    expect(settings.crumbCount, GameSettings.maxCrumbCount);
    settings.crumbCount = -5;
    expect(settings.crumbCount, GameSettings.minCrumbCount);

    settings.mouseSpeed = 10000;
    expect(settings.mouseSpeed, GameSettings.maxMouseSpeed);

    settings.eatSpeed = 2;
    expect(settings.eatDuration, closeTo(0.5, 1e-9));
    settings.eatSpeed = 0.5;
    expect(settings.eatDuration, closeTo(2, 1e-9));
  });
}
