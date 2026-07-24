/// Данные и утилиты графиков Polaris — чистый Dart, ни одной зависимости
/// от Flutter: легко тестировать и переиспользовать.
/// Цены — в центах (int), как везде в приложении. После интерполяций
/// (морф, ресемплинг) центы становятся double — это нормально: эти числа
/// уходят в пиксели на экране, а не в движок денег.
library;

import 'dart:math' as math;

/// Одна свеча (или точка) ценовой серии.
class Candle {
  final DateTime ts;
  final int openCents;
  final int highCents;
  final int lowCents;
  final int closeCents;

  const Candle({
    required this.ts,
    required this.openCents,
    required this.highCents,
    required this.lowCents,
    required this.closeCents,
  });

  /// Плоская свеча — все четыре цены равны (одна точка серии).
  const Candle.flat({required this.ts, required int priceCents})
      : openCents = priceCents,
        highCents = priceCents,
        lowCents = priceCents,
        closeCents = priceCents;

  /// Свеча роста (или дожи) — закрылись не ниже, чем открылись.
  bool get bullish => closeCents >= openCents;

  /// Разбор терпим к мусору: битые поля превращаются в нули, а не в краш.
  factory Candle.fromJson(Map<String, dynamic> j) {
    int asInt(Object? v) => v is num ? v.toInt() : 0;
    return Candle(
      ts: DateTime.tryParse(j['ts'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      openCents: asInt(j['o']),
      highCents: asInt(j['h']),
      lowCents: asInt(j['l']),
      closeCents: asInt(j['c']),
    );
  }

  Map<String, dynamic> toJson() => {
        'ts': ts.toIso8601String(),
        'o': openCents,
        'h': highCents,
        'l': lowCents,
        'c': closeCents,
      };

  @override
  bool operator ==(Object other) =>
      other is Candle &&
      other.ts == ts &&
      other.openCents == openCents &&
      other.highCents == highCents &&
      other.lowCents == lowCents &&
      other.closeCents == closeCents;

  @override
  int get hashCode =>
      Object.hash(ts, openCents, highCents, lowCents, closeCents);

  @override
  String toString() =>
      'Candle($ts o:$openCents h:$highCents l:$lowCents c:$closeCents)';
}

/// Вертикальный диапазон графика в центах. Хранится в double, потому что
/// после паддинга и лерпа границы дробные — рисуем-то пиксели.
class ChartRange {
  final double minCents;
  final double maxCents;

  const ChartRange(this.minCents, this.maxCents);

  double get spanCents => maxCents - minCents;

  /// Все цены равны (или диапазон вырожден) — рисуем плоскую линию.
  bool get isFlat => spanCents <= 0;

  /// Расширяет диапазон на долю [frac] сверху и снизу, чтобы линия
  /// не липла к краям. Плоский диапазон не трогаем.
  ChartRange padded(double frac) {
    if (isFlat) return this;
    final pad = spanCents * frac;
    return ChartRange(minCents - pad, maxCents + pad);
  }

  /// Плавный переход между диапазонами — для морфа серий.
  static ChartRange lerp(ChartRange a, ChartRange b, double t) => ChartRange(
        a.minCents + (b.minCents - a.minCents) * t,
        a.maxCents + (b.maxCents - a.maxCents) * t,
      );

  @override
  String toString() => 'ChartRange($minCents..$maxCents)';
}

/// Диапазон по свечам. [wicks] — учитывать хвосты (high/low), иначе
/// только open/close (для area-режима). Пустая серия — null.
ChartRange? rangeOfCandles(List<Candle> candles, {bool wicks = true}) {
  if (candles.isEmpty) return null;
  var min = double.infinity;
  var max = double.negativeInfinity;
  for (final c in candles) {
    final lo = (wicks ? c.lowCents : math.min(c.openCents, c.closeCents)).toDouble();
    final hi = (wicks ? c.highCents : math.max(c.openCents, c.closeCents)).toDouble();
    if (lo < min) min = lo;
    if (hi > max) max = hi;
  }
  return ChartRange(min, max);
}

/// Диапазон по «голым» значениям (area-серия). Пусто — null.
ChartRange? rangeOfValues(List<double> values) {
  if (values.isEmpty) return null;
  var min = values.first;
  var max = values.first;
  for (final v in values) {
    if (v < min) min = v;
    if (v > max) max = v;
  }
  return ChartRange(min, max);
}

/// Закрытия серии как double-центы — сырьё для area-линии и спарклайнов.
List<double> closesOf(List<Candle> candles) =>
    [for (final c in candles) c.closeCents.toDouble()];

/// Тренд серии: выросли или упали от первой точки к последней.
/// Пустая или плоская серия считается ростом (нейтральный зелёный).
bool trendIsGain(List<Candle> candles) =>
    candles.isEmpty || candles.last.closeCents >= candles.first.closeCents;

/// Линейный ресемплинг серии до ровно [n] точек. Нужен морфу: две серии
/// разной длины приводим к общей, чтобы твинить поточечно.
/// Точки ложатся на исходную ломаную, форма не искажается.
List<double> resampleValues(List<double> src, int n) {
  if (n <= 0) return const [];
  if (src.isEmpty) return List.filled(n, 0);
  if (src.length == 1) return List.filled(n, src.first);
  if (n == 1) return [src.last];
  final maxI = src.length - 1;
  final out = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    final pos = i * maxI / (n - 1);
    final lo = pos.floor();
    final hi = math.min(lo + 1, maxI);
    final f = pos - lo;
    out[i] = src[lo] + (src[hi] - src[lo]) * f;
  }
  return out;
}

/// Поточечный лерп двух серий. Разные длины сами приводятся к общей.
List<double> lerpSamples(List<double> a, List<double> b, double t) {
  var from = a;
  var to = b;
  if (from.length != to.length) {
    final n = math.max(from.length, to.length);
    from = resampleValues(from, n);
    to = resampleValues(to, n);
  }
  return List<double>.generate(
      from.length, (i) => from[i] + (to[i] - from[i]) * t);
}

/// Центы в строку вида `$1,234.56` (минус — перед долларом: `-$0.50`).
String formatCents(int cents) {
  final neg = cents < 0;
  final abs = cents.abs();
  final dollars = (abs ~/ 100).toString();
  final buf = StringBuffer();
  for (var i = 0; i < dollars.length; i++) {
    buf.write(dollars[i]);
    final left = dollars.length - 1 - i;
    if (left > 0 && left % 3 == 0) buf.write(',');
  }
  final rem = (abs % 100).toString().padLeft(2, '0');
  return '${neg ? '-' : ''}\$$buf.$rem';
}

/// Дата для плашки скраббинга: `17.07.2026`, для внутридневных точек
/// с временем — `17.07.2026 14:30`.
String formatCandleDate(DateTime ts) {
  String two(int v) => v.toString().padLeft(2, '0');
  final date = '${two(ts.day)}.${two(ts.month)}.${ts.year}';
  if (ts.hour == 0 && ts.minute == 0) return date;
  return '$date ${two(ts.hour)}:${two(ts.minute)}';
}
