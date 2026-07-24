/// Демо-страница маскота Cosmo — все настроения рядом, тумблер анимации.
/// В приложение НЕ подключается (main.dart интегратор трогает сам) — только
/// для визуальной проверки художником/интегратором.
library;

import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../fx/stars_background.dart';
import 'cosmo_mascot.dart';

class CosmoMascotDemo extends StatefulWidget {
  const CosmoMascotDemo({super.key});

  @override
  State<CosmoMascotDemo> createState() => _CosmoMascotDemoState();
}

class _CosmoMascotDemoState extends State<CosmoMascotDemo> {
  bool _animated = true;

  static const _moods = [
    (CosmoMood.idle, 'idle'),
    (CosmoMood.happy, 'happy'),
    (CosmoMood.thinking, 'thinking'),
    (CosmoMood.celebrate, 'celebrate'),
    (CosmoMood.concerned, 'concerned'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PolarisColors.bg,
      body: StarsBackground(
        intensity: .6,
        child: SafeArea(
          child: Column(
            children: [
              SwitchListTile(
                value: _animated,
                onChanged: (v) => setState(() => _animated = v),
                title: const Text('animated',
                    style: TextStyle(color: PolarisColors.textPrimary)),
                activeThumbColor: PolarisColors.aurora,
              ),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final (mood, label) in _moods)
                      _moodTile(mood, label),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: CosmoGreeting(
                  text: 'Привет! Я Cosmo — так выглядит CosmoGreeting.',
                  animated: _animated,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final (mood, _) in _moods) ...[
                      CosmoBadge(mood: mood, animated: _animated),
                      const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moodTile(CosmoMood mood, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CosmoMascot(mood: mood, animated: _animated, size: 110),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: PolarisColors.textSecondary)),
      ],
    );
  }
}
