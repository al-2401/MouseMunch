import 'package:flutter/material.dart';

import '../audio/sound_manager.dart';
import '../game/game_settings.dart';

/// Bottom sheet with the tunable game settings.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({
    super.key,
    required this.settings,
    required this.sound,
    required this.onClearCrumbs,
  });

  final GameSettings settings;
  final SoundManager sound;
  final VoidCallback onClearCrumbs;

  static Future<void> show(
    BuildContext context, {
    required GameSettings settings,
    required SoundManager sound,
    required VoidCallback onClearCrumbs,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SettingsSheet(
        settings: settings,
        sound: sound,
        onClearCrumbs: onClearCrumbs,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: AnimatedBuilder(
        animation: settings,
        builder: (context, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Настройки', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                _SettingSlider(
                  label: 'Количество крошек',
                  value: settings.crumbCount.toDouble(),
                  min: GameSettings.minCrumbCount.toDouble(),
                  max: GameSettings.maxCrumbCount.toDouble(),
                  divisions: GameSettings.maxCrumbCount - GameSettings.minCrumbCount,
                  valueLabel: '${settings.crumbCount} шт.',
                  hint: 'Сколько крошек высыпается за одно нажатие на кормушку',
                  onChanged: (value) => settings.crumbCount = value.round(),
                  onChangeEnd: _blip,
                ),
                _SettingSlider(
                  label: 'Скорость мышки',
                  value: settings.mouseSpeed,
                  min: GameSettings.minMouseSpeed,
                  max: GameSettings.maxMouseSpeed,
                  divisions: 40,
                  valueLabel: '${settings.mouseSpeed.round()} px/с',
                  hint: 'Как быстро мышка бежит от крошки к крошке',
                  onChanged: (value) => settings.mouseSpeed = value,
                  onChangeEnd: _blip,
                ),
                _SettingSlider(
                  label: 'Скорость поедания',
                  value: settings.eatSpeed,
                  min: GameSettings.minEatSpeed,
                  max: GameSettings.maxEatSpeed,
                  divisions: 38,
                  valueLabel: '${settings.eatSpeed.toStringAsFixed(1)} крош./с '
                      '(${settings.eatDuration.toStringAsFixed(1)} с на крошку)',
                  hint: 'Сколько мышка возится с одной крошкой',
                  onChanged: (value) => settings.eatSpeed = value,
                  onChangeEnd: _blip,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Звук'),
                  subtitle: const Text('Шаги, хруст, писк и кормушка'),
                  value: settings.soundEnabled,
                  onChanged: (value) {
                    settings.soundEnabled = value;
                    if (value) {
                      sound.play(Sfx.ui);
                    }
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    sound.play(Sfx.ui);
                    onClearCrumbs();
                  },
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: const Text('Убрать крошки с пола'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _blip(double _) => sound.play(Sfx.ui, volume: 0.6);
}

class _SettingSlider extends StatelessWidget {
  const _SettingSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.hint,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final String hint;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(label, style: theme.textTheme.titleMedium),
              Text(valueLabel, style: theme.textTheme.labelLarge),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
          Text(hint, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
