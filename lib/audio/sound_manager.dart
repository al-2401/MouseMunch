import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Every sound effect the game can play.
enum Sfx {
  /// Looping pitter-patter while the mouse walks.
  move('audio/move.wav'),

  /// Crunching while a crumb is eaten.
  eat('audio/eat.wav'),

  /// Startled squeak when the mouse is poked.
  squeak('audio/squeak.wav'),

  /// Crumbs raining out of the feeder.
  pour('audio/pour.wav'),

  /// Knock on the feeder.
  tap('audio/tap.wav'),

  /// Soft blip for menu interactions.
  ui('audio/ui.wav');

  const Sfx(this.asset);

  final String asset;
}

/// Plays the game's sound effects.
///
/// Each effect owns its own [AudioPlayer] so that a crunch does not cut off a
/// squeak. Playback is fire and forget: audio must never be able to stall or
/// crash the game loop, so every call swallows platform errors.
class SoundManager {
  SoundManager({this.enabled = true});

  final Map<Sfx, AudioPlayer> _players = <Sfx, AudioPlayer>{};
  bool _disposed = false;
  bool _movingLoopActive = false;

  /// Mirrors the sound switch from the settings sheet.
  bool enabled;

  AudioPlayer _playerFor(Sfx sfx) {
    return _players.putIfAbsent(sfx, () {
      final player = AudioPlayer();
      if (sfx == Sfx.move) {
        _guard(() => player.setReleaseMode(ReleaseMode.loop));
      } else {
        _guard(() => player.setReleaseMode(ReleaseMode.stop));
        _guard(() => player.setPlayerMode(PlayerMode.lowLatency));
      }
      return player;
    });
  }

  /// Plays a one shot effect, restarting it if it is already sounding.
  void play(Sfx sfx, {double volume = 1.0}) {
    if (!enabled || _disposed || sfx == Sfx.move) return;
    _guard(() async {
      final player = _playerFor(sfx);
      await player.stop();
      await player.play(AssetSource(sfx.asset), volume: volume);
    });
  }

  /// Starts the looping footstep sound. [rate] speeds the loop up for a faster
  /// mouse; it is ignored on platforms that cannot change the playback rate.
  void startMoveLoop({double rate = 1.0}) {
    if (!enabled || _disposed) return;
    if (_movingLoopActive) {
      setMoveRate(rate);
      return;
    }
    _movingLoopActive = true;
    _guard(() async {
      final player = _playerFor(Sfx.move);
      await player.stop();
      await player.play(AssetSource(Sfx.move.asset), volume: 0.7);
      await player.setPlaybackRate(rate);
    });
  }

  /// Stops the looping footstep sound.
  void stopMoveLoop() {
    if (!_movingLoopActive) return;
    _movingLoopActive = false;
    if (_disposed) return;
    _guard(() => _playerFor(Sfx.move).stop());
  }

  /// Adjusts the footstep loop to a new mouse speed.
  void setMoveRate(double rate) {
    if (!_movingLoopActive || _disposed || !enabled) return;
    _guard(() => _playerFor(Sfx.move).setPlaybackRate(rate));
  }

  /// Applies the sound toggle from the settings screen.
  void setEnabled(bool value) {
    if (enabled == value) return;
    enabled = value;
    if (!value) {
      stopMoveLoop();
      for (final player in _players.values) {
        _guard(player.stop);
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _movingLoopActive = false;
    for (final player in _players.values) {
      try {
        await player.dispose();
      } catch (error, stack) {
        _report(error, stack);
      }
    }
    _players.clear();
  }

  void _guard(Future<void> Function() action) {
    action().catchError((Object error, StackTrace stack) {
      _report(error, stack);
    });
  }

  void _report(Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('MouseMunch audio error: $error');
    }
  }
}
