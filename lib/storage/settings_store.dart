import 'package:shared_preferences/shared_preferences.dart';

import '../game/game_settings.dart';

/// Persists [GameSettings] to on-device storage so they survive a restart.
class SettingsStore {
  static const _crumbCountKey = 'settings.crumbCount';
  static const _mouseSpeedKey = 'settings.mouseSpeed';
  static const _eatSpeedKey = 'settings.eatSpeed';
  static const _soundEnabledKey = 'settings.soundEnabled';

  /// Overwrites [settings] with whatever was saved last, if anything.
  Future<void> applySaved(GameSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    settings
      ..crumbCount = prefs.getInt(_crumbCountKey) ?? settings.crumbCount
      ..mouseSpeed = prefs.getDouble(_mouseSpeedKey) ?? settings.mouseSpeed
      ..eatSpeed = prefs.getDouble(_eatSpeedKey) ?? settings.eatSpeed
      ..soundEnabled = prefs.getBool(_soundEnabledKey) ?? settings.soundEnabled;
  }

  Future<void> save(GameSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait(<Future<bool>>[
      prefs.setInt(_crumbCountKey, settings.crumbCount),
      prefs.setDouble(_mouseSpeedKey, settings.mouseSpeed),
      prefs.setDouble(_eatSpeedKey, settings.eatSpeed),
      prefs.setBool(_soundEnabledKey, settings.soundEnabled),
    ]);
  }
}
