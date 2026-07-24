/// Виджет-тесты PolarisChart и PolarisSparkline: рендер обоих режимов,
/// скраббинг через drag, пустые/плоские данные, морф при смене серии.
/// Golden-тестов нет намеренно — проверяем «не бросает и зовёт колбэки».
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/widgets/chart/chart_models.dart';
import 'package:polaris/widgets/chart/polaris_chart.dart';

/// Детерминированная фейковая серия (сид фиксирован — тесты стабильны).
List<Candle> _series(int n, {int seed = 1, int startCents = 10000}) {
  final rnd = math.Random(seed);
  var price = startCents;
  return List.generate(n, (i) {
    final open = price;
    final close = math.max(100, open + rnd.nextInt(400) - 190);
    price = close;
    return Candle(
      ts: DateTime(2026, 7, 1).add(Duration(days: i)),
      openCents: open,
      highCents: math.max(open, close) + 50,
      lowCents: math.max(50, math.min(open, close) - 50),
      closeCents: close,
    );
  });
}

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 360, child: child)),
      ),
    );

void main() {
  testWidgets('area-режим рендерится без исключений', (tester) async {
    await tester.pumpWidget(_wrap(PolarisChart(candles: _series(30))));
    await tester.pump(const Duration(milliseconds: 200)); // середина появления
    await tester.pumpAndSettle();
    expect(find.byType(PolarisChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('candles-режим рендерится без исключений', (tester) async {
    await tester.pumpWidget(_wrap(
        PolarisChart(candles: _series(30), mode: ChartMode.candles)));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('скраббинг: drag зовёт onScrub со свечами, отпускание — с null',
      (tester) async {
    final events = <Candle?>[];
    final candles = _series(30);
    await tester.pumpWidget(_wrap(
      PolarisChart(candles: candles, onScrub: events.add),
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PolarisChart), const Offset(120, 0));
    await tester.pumpAndSettle();

    expect(events, isNotEmpty);
    // По пути были живые свечи из нашей серии...
    final touched = events.whereType<Candle>().toList();
    expect(touched, isNotEmpty);
    for (final c in touched) {
      expect(candles, contains(c));
    }
    // ...а последним событием — null (палец отпущен, шапка возвращается).
    expect(events.last, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('скраббинг работает и в режиме свечей', (tester) async {
    final events = <Candle?>[];
    await tester.pumpWidget(_wrap(PolarisChart(
      candles: _series(20),
      mode: ChartMode.candles,
      onScrub: events.add,
    )));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PolarisChart), const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(events.whereType<Candle>(), isNotEmpty);
    expect(events.last, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('пустая серия не крашит и показывает подпись', (tester) async {
    await tester
        .pumpWidget(_wrap(const PolarisChart(candles: [])));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Drag по пустому графику тоже не должен ничего ломать.
    await tester.drag(find.byType(PolarisChart), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('одна точка и «все цены равны» рисуют плоскую линию без крашей',
      (tester) async {
    final one = [Candle.flat(ts: DateTime(2026, 7, 1), priceCents: 12345)];
    await tester.pumpWidget(_wrap(PolarisChart(candles: one)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final flat = List.generate(
        10, (i) => Candle.flat(ts: DateTime(2026, 7, 1 + i), priceCents: 500));
    await tester.pumpWidget(_wrap(PolarisChart(candles: flat)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // И в режиме свечей тоже.
    await tester.pumpWidget(
        _wrap(PolarisChart(candles: flat, mode: ChartMode.candles)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('морф при смене диапазона не бросает (area)', (tester) async {
    await tester.pumpWidget(_wrap(PolarisChart(candles: _series(30))));
    await tester.pumpAndSettle();

    // Новая серия другой длины и другого уровня цен — твининг серий.
    await tester.pumpWidget(
        _wrap(PolarisChart(candles: _series(90, seed: 7, startCents: 50000))));
    await tester.pump(const Duration(milliseconds: 100)); // середина морфа
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('морф при смене диапазона не бросает (candles + смена режима)',
      (tester) async {
    await tester.pumpWidget(_wrap(
        PolarisChart(candles: _series(30), mode: ChartMode.candles)));
    await tester.pumpAndSettle();

    // Смена серии в режиме свечей — кроссфейд.
    await tester.pumpWidget(_wrap(
        PolarisChart(candles: _series(60, seed: 9), mode: ChartMode.candles)));
    await tester.pump(const Duration(milliseconds: 100));

    // Посреди морфа переключаем режим на area — тоже не должно бросить.
    await tester.pumpWidget(
        _wrap(PolarisChart(candles: _series(60, seed: 9))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('смена серии в пустую и из пустой не крашит', (tester) async {
    await tester.pumpWidget(_wrap(PolarisChart(candles: _series(30))));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_wrap(const PolarisChart(candles: [])));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_wrap(PolarisChart(candles: _series(15))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('скраббинг сбрасывается при смене серии', (tester) async {
    final events = <Candle?>[];
    await tester.pumpWidget(_wrap(
      PolarisChart(candles: _series(30), onScrub: events.add),
    ));
    await tester.pumpAndSettle();

    // Держим палец на графике (долгое нажатие) — скраб активен.
    final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PolarisChart)));
    await tester.pump(const Duration(seconds: 1)); // long press сработал
    expect(events.whereType<Candle>(), isNotEmpty);

    // Меняем серию под пальцем — чарт обязан сам погасить скраб.
    await tester.pumpWidget(_wrap(
      PolarisChart(candles: _series(50, seed: 3), onScrub: events.add),
    ));
    await tester.pumpAndSettle();
    expect(events.last, isNull);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('PolarisSparkline: рост, падение, флет, пусто — без исключений',
      (tester) async {
    await tester.pumpWidget(_wrap(Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const PolarisSparkline(values: [1, 2, 3, 2, 5]),
        const PolarisSparkline(values: [5, 4, 3, 4, 1]),
        PolarisSparkline(values: List.filled(10, 7)),
        const PolarisSparkline(values: []),
        const PolarisSparkline(values: [42]), // одна точка
      ],
    )));
    await tester.pump();
    expect(find.byType(PolarisSparkline), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });
}
