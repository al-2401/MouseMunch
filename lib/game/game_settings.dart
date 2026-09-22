import 'package:flutter/foundation.dart';

/// Player tunable settings.
///
/// The values are kept in memory for the lifetime of the app and every change
/// is applied to the running game immediately.
class GameSettings extends ChangeNotifier {
  GameSettings({
    int crumbCount = 12,
    double mouseSpeed = 130,
    double eatSpeed = 1.0,
    bool soundEnabled = true,
  })  : _crumbCount = crumbCount,
        _mouseSpeed = mouseSpeed,
        _eatSpeed = eatSpeed,
        _soundEnabled = soundEnabled;

  /// How many crumbs a single tap on the feeder pours out.
  static const int minCrumbCount = 1;
  static const int maxCrumbCount = 40;

  /// Travel speed of the mouse, in logical pixels per second.
  static const double minMouseSpeed = 20;
  static const double maxMouseSpeed = 420;

  /// How many crumbs the mouse can finish per second.
  static const double minEatSpeed = 0.2;
  static const double maxEatSpeed = 4.0;

  int _crumbCount;
  double _mouseSpeed;
  double _eatSpeed;
  bool _soundEnabled;

  int get crumbCount => _crumbCount;

  set crumbCount(int value) {
    final clamped = value.clamp(minCrumbCount, maxCrumbCount);
    if (clamped == _crumbCount) return;
    _crumbCount = clamped;
    notifyListeners();
  }

  double get mouseSpeed => _mouseSpeed;

  set mouseSpeed(double value) {
    final clamped = value.clamp(minMouseSpeed, maxMouseSpeed);
    if (clamped == _mouseSpeed) return;
    _mouseSpeed = clamped;
    notifyListeners();
  }

  double get eatSpeed => _eatSpeed;

  set eatSpeed(double value) {
    final clamped = value.clamp(minEatSpeed, maxEatSpeed);
    if (clamped == _eatSpeed) return;
    _eatSpeed = clamped;
    notifyListeners();
  }

  /// Time it takes to finish a single crumb, derived from [eatSpeed].
  double get eatDuration => 1 / _eatSpeed;

  bool get soundEnabled => _soundEnabled;

  set soundEnabled(bool value) {
    if (value == _soundEnabled) return;
    _soundEnabled = value;
    notifyListeners();
  }

  /// Playback rate for the footstep loop, so quick mice patter quicker.
  double get footstepRate => (_mouseSpeed / 130).clamp(0.5, 2.0);
}
