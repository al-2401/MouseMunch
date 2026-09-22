import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/sound_manager.dart';
import '../game/game_controller.dart';
import '../game/game_settings.dart';
import '../storage/settings_store.dart';
import 'crumb_view.dart';
import 'feeder_view.dart';
import 'mouse_view.dart';
import 'settings_sheet.dart';

/// The whole game: a floor with crumbs, a mouse and a feeder.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const Size _feederSize = Size(100, 110);
  static const double _feederInset = 14;

  /// Largest simulation step, so a hiccup cannot teleport the mouse.
  static const double _maxStep = 0.05;

  final GameSettings _settings = GameSettings();
  final SettingsStore _settingsStore = SettingsStore();
  late final SoundManager _sound = SoundManager(enabled: _settings.soundEnabled);
  late final GameController _controller =
      GameController(settings: _settings, sound: _sound);

  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick)..start();
    // Applied after the first frame, then every later change is saved back.
    _settingsStore.applySaved(_settings).then((_) {
      if (mounted) _settings.addListener(_persistSettings);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settings.removeListener(_persistSettings);
    _ticker.dispose();
    _controller.dispose();
    _settings.dispose();
    _sound.dispose();
    super.dispose();
  }

  void _persistSettings() {
    _settingsStore.save(_settings);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Never leave the footstep loop running in the background.
    if (state != AppLifecycleState.resumed) {
      _sound.stopMoveLoop();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;
    _controller.tick(dt.clamp(0, _maxStep));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final field = Size(constraints.maxWidth, constraints.maxHeight);
            final feederRect = Rect.fromLTWH(
              field.width - _feederSize.width - _feederInset,
              _feederInset,
              _feederSize.width,
              _feederSize.height,
            );
            // The controller may notify its listeners, so it is resized after
            // the frame instead of during layout.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _controller.resize(field, feederRect);
              }
            });

            return Stack(
              children: <Widget>[
                const Positioned.fill(child: _Floor()),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) => Stack(
                      children: <Widget>[
                        for (final crumb in _controller.crumbs)
                          CrumbView(key: ValueKey<int>(crumb.id), crumb: crumb),
                        MouseView(
                          controller: _controller,
                          onPoke: _controller.pokeMouse,
                        ),
                        if (_controller.crumbs.isEmpty)
                          const _Hint(text: 'Нажми на кормушку — посыплются крошки'),
                        Positioned(
                          left: 12,
                          top: 12,
                          child: _Hud(
                            controller: _controller,
                            onSettings: _openSettings,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                FeederView(
                  rect: feederRect,
                  onPour: () => _pour(feederRect),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _pour(Rect feederRect) {
    _sound.play(Sfx.tap);
    _controller.pourCrumbs(feederRect.bottomCenter - const Offset(0, 10));
  }

  void _openSettings() {
    _sound.play(Sfx.ui);
    SettingsSheet.show(
      context,
      settings: _settings,
      sound: _sound,
      onClearCrumbs: _controller.clearCrumbs,
    );
  }
}

/// Wooden floor the game is played on.
class _Floor extends StatelessWidget {
  const _Floor();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.4,
          colors: <Color>[Color(0xFF5E4630), Color(0xFF3A2A1C)],
        ),
      ),
      child: CustomPaint(painter: _FloorPainter(), child: SizedBox.expand()),
    );
  }
}

class _FloorPainter extends CustomPainter {
  const _FloorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const plankHeight = 74.0;
    final line = Paint()
      ..color = const Color(0x33000000)
      ..strokeWidth = 2;
    final highlight = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 1;

    for (var y = plankHeight; y < size.height; y += plankHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
      canvas.drawLine(Offset(0, y + 2), Offset(size.width, y + 2), highlight);
    }
  }

  @override
  bool shouldRepaint(covariant _FloorPainter oldDelegate) => false;
}

/// Counter and the settings button.
class _Hud extends StatelessWidget {
  const _Hud({required this.controller, required this.onSettings});

  final GameController controller;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Material(
          color: const Color(0xCC2B1F14),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onSettings,
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.tune, color: Colors.white, size: 22),
            ),
          ),
        ),
        const SizedBox(width: 10),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xCC2B1F14),
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              'Крошек: ${controller.remainingCrumbs}   Съедено: ${controller.eatenCount}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

/// Message shown while the floor is empty.
class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 24,
      child: IgnorePointer(
        child: Center(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0x992B1F14),
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
