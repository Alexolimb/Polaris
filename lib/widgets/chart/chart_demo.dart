/// Демо-страница графика Polaris — для ручной проверки руками.
/// В приложение НЕ подключена (и не должна быть): открывается только
/// если временно поставить её home'ом в main.dart.
///
/// Что внутри: фейковая серия (случайное блуждание с сидом — стабильна
/// между запусками), переключатели диапазона и режима area/candles,
/// шапка с ценой, живущей от скраббинга, и ряд спарклайнов.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'chart_models.dart';
import 'polaris_chart.dart';

class ChartDemoPage extends StatefulWidget {
  const ChartDemoPage({super.key});

  @override
  State<ChartDemoPage> createState() => _ChartDemoPageState();
}

class _ChartDemoPageState extends State<ChartDemoPage> {
  late final Map<String, List<Candle>> _series;
  String _range = '1М';
  ChartMode _mode = ChartMode.area;
  Candle? _scrub;

  @override
  void initState() {
    super.initState();
    // Разные сиды дают разные «характеры» рынка на каждом диапазоне.
    _series = {
      '1Д': _fakeSeries(n: 78, seed: 11, step: const Duration(minutes: 5)),
      '1Н': _fakeSeries(n: 84, seed: 22, step: const Duration(hours: 2)),
      '1М': _fakeSeries(n: 30, seed: 33, step: const Duration(days: 1)),
      '1Г': _fakeSeries(n: 252, seed: 44, step: const Duration(days: 1)),
    };
  }

  /// Случайное блуждание с лёгким дрейфом вверх — правдоподобная акция.
  static List<Candle> _fakeSeries({
    required int n,
    required int seed,
    required Duration step,
    int startCents = 18500,
  }) {
    final rnd = math.Random(seed);
    final start = DateTime(2026, 7, 20).subtract(step * n);
    final out = <Candle>[];
    var price = startCents;
    for (var i = 0; i < n; i++) {
      final open = price;
      final move = (price * (rnd.nextDouble() * 2 - 1) * 0.02).round() +
          (price * 0.0006).round(); // дрейф
      final close = math.max(100, open + move);
      final wiggle = (price * rnd.nextDouble() * 0.008).round();
      out.add(Candle(
        ts: start.add(step * (i + 1)),
        openCents: open,
        highCents: math.max(open, close) + wiggle,
        lowCents: math.max(50, math.min(open, close) - wiggle),
        closeCents: close,
      ));
      price = close;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final candles = _series[_range]!;
    final shown = _scrub ?? candles.last;
    final first = candles.first;
    final diff = shown.closeCents - first.closeCents;
    final pct = first.closeCents == 0 ? 0.0 : diff / first.closeCents * 100;
    final up = diff >= 0;
    final trendColor = up ? PolarisColors.gain : PolarisColors.loss;

    return Scaffold(
      backgroundColor: PolarisColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Шапка: цена меняется во время скраббинга через onScrub.
            const Text(
              'PLRS · Polaris Demo',
              style: TextStyle(color: PolarisColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              formatCents(shown.closeCents),
              style: const TextStyle(
                color: PolarisColors.star,
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _scrub != null
                  ? formatCandleDate(shown.ts)
                  : '${up ? '+' : '-'}${formatCents(diff.abs())} · '
                      '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%',
              style: TextStyle(color: trendColor, fontSize: 14),
            ),
            const SizedBox(height: 12),
            PolarisChart(
              candles: candles,
              mode: _mode,
              onScrub: (c) => setState(() => _scrub = c),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final r in _series.keys) ...[
                  _Chip(
                    label: r,
                    selected: r == _range,
                    onTap: () => setState(() {
                      _range = r;
                      _scrub = null;
                    }),
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                _Chip(
                  label: 'Линия',
                  selected: _mode == ChartMode.area,
                  onTap: () => setState(() => _mode = ChartMode.area),
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: 'Свечи',
                  selected: _mode == ChartMode.candles,
                  onTap: () => setState(() => _mode = ChartMode.candles),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text(
              'Спарклайны (для строк каталога)',
              style: TextStyle(color: PolarisColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            _sparkRow('Растущая', closesOf(_series['1М']!)),
            _sparkRow('Падающая',
                closesOf(_series['1М']!).reversed.toList(growable: false)),
            _sparkRow('Плоская', List.filled(20, 100)),
            _sparkRow('Пустая', const []),
          ],
        ),
      ),
    );
  }

  Widget _sparkRow(String label, List<double> values) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style:
                  const TextStyle(color: PolarisColors.textPrimary, fontSize: 14),
            ),
          ),
          PolarisSparkline(values: values),
        ],
      ),
    );
  }
}

/// Маленькая кнопка-чип в стиле Polaris (без Material-чипов — им нужна
/// своя тема, а демо должно оставаться лёгким).
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? PolarisColors.surfaceHigh : PolarisColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? PolarisColors.polar.withValues(alpha: 0.6)
                : PolarisColors.surfaceHigh,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? PolarisColors.polar : PolarisColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
