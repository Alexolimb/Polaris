/// Тесты утилит данных графика (chart_models.dart) — чистый Dart.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/widgets/chart/chart_models.dart';

Candle _c(int o, int h, int l, int c, {int day = 1}) => Candle(
      ts: DateTime(2026, 7, day),
      openCents: o,
      highCents: h,
      lowCents: l,
      closeCents: c,
    );

void main() {
  group('Candle', () {
    test('bullish: рост и дожи — true, падение — false', () {
      expect(_c(100, 120, 90, 110).bullish, isTrue);
      expect(_c(100, 120, 90, 100).bullish, isTrue); // дожи
      expect(_c(100, 120, 90, 95).bullish, isFalse);
    });

    test('== сравнивает по значению', () {
      expect(_c(1, 2, 3, 4), equals(_c(1, 2, 3, 4)));
      expect(_c(1, 2, 3, 4), isNot(equals(_c(1, 2, 3, 5))));
      expect(_c(1, 2, 3, 4).hashCode, _c(1, 2, 3, 4).hashCode);
    });

    test('flat-конструктор ставит все четыре цены', () {
      final c = Candle.flat(ts: DateTime(2026, 7, 1), priceCents: 500);
      expect(c.openCents, 500);
      expect(c.highCents, 500);
      expect(c.lowCents, 500);
      expect(c.closeCents, 500);
      expect(c.bullish, isTrue);
    });

    test('json туда-обратно без потерь, мусор не крашит', () {
      final c = _c(100, 130, 80, 120);
      expect(Candle.fromJson(c.toJson()), equals(c));
      // Битый json — нули, а не исключение.
      final broken = Candle.fromJson(const {'ts': 'мусор', 'o': 'тоже'});
      expect(broken.openCents, 0);
      expect(broken.closeCents, 0);
    });
  });

  group('rangeOfCandles', () {
    final series = [_c(100, 150, 90, 120), _c(120, 160, 110, 130, day: 2)];

    test('с хвостами — по high/low', () {
      final r = rangeOfCandles(series)!;
      expect(r.minCents, 90);
      expect(r.maxCents, 160);
    });

    test('без хвостов — по open/close', () {
      final r = rangeOfCandles(series, wicks: false)!;
      expect(r.minCents, 100);
      expect(r.maxCents, 130);
    });

    test('пустая серия — null', () {
      expect(rangeOfCandles(const []), isNull);
      expect(rangeOfValues(const []), isNull);
    });
  });

  group('ChartRange', () {
    test('padded расширяет на долю, флет не трогает', () {
      final r = const ChartRange(100, 200).padded(0.1);
      expect(r.minCents, 90);
      expect(r.maxCents, 210);
      final flat = const ChartRange(100, 100).padded(0.1);
      expect(flat.isFlat, isTrue);
      expect(flat.minCents, 100);
    });

    test('lerp двигает границы линейно', () {
      final r = ChartRange.lerp(
          const ChartRange(0, 100), const ChartRange(100, 200), 0.5);
      expect(r.minCents, 50);
      expect(r.maxCents, 150);
    });
  });

  group('trendIsGain', () {
    test('рост/флет/пусто — true, падение — false', () {
      expect(trendIsGain([_c(1, 1, 1, 100), _c(1, 1, 1, 200, day: 2)]), isTrue);
      expect(trendIsGain([_c(1, 1, 1, 100), _c(1, 1, 1, 100, day: 2)]), isTrue);
      expect(trendIsGain(const []), isTrue);
      expect(
          trendIsGain([_c(1, 1, 1, 200), _c(1, 1, 1, 100, day: 2)]), isFalse);
    });
  });

  group('resampleValues', () {
    test('длина результата ровно n, концы сохраняются', () {
      final out = resampleValues([10, 20, 30], 5);
      expect(out.length, 5);
      expect(out.first, 10);
      expect(out.last, 30);
      expect(out[2], closeTo(20, 1e-9)); // середина ломаной
    });

    test('точки ложатся на исходную ломаную (апсемплинг)', () {
      final out = resampleValues([0, 100], 5);
      expect(out, [0, 25, 50, 75, 100]);
    });

    test('даунсемплинг сохраняет концы', () {
      final out = resampleValues(List.generate(100, (i) => i.toDouble()), 10);
      expect(out.length, 10);
      expect(out.first, 0);
      expect(out.last, 99);
    });

    test('крайние случаи: пусто, одна точка, n=1, n=0', () {
      expect(resampleValues(const [], 3), [0, 0, 0]);
      expect(resampleValues([42], 3), [42, 42, 42]);
      expect(resampleValues([10, 20, 30], 1), [30]);
      expect(resampleValues([10, 20], 0), isEmpty);
    });
  });

  group('lerpSamples', () {
    test('поточечный лерп при равной длине', () {
      expect(lerpSamples([0, 100], [100, 200], 0.5), [50, 150]);
      expect(lerpSamples([0, 100], [100, 200], 0), [0, 100]);
      expect(lerpSamples([0, 100], [100, 200], 1), [100, 200]);
    });

    test('разные длины приводятся к общей без исключений', () {
      final out = lerpSamples([0, 100], [0, 50, 100], 0.5);
      expect(out.length, 3);
      expect(out.first, 0);
      expect(out.last, 100);
    });

    test('пустые серии не крашат', () {
      expect(lerpSamples(const [], const [], 0.5), isEmpty);
    });
  });

  group('formatCents', () {
    test('доллары с разделителями тысяч', () {
      expect(formatCents(123456), r'$1,234.56');
      expect(formatCents(100), r'$1.00');
      expect(formatCents(5), r'$0.05');
      expect(formatCents(0), r'$0.00');
      expect(formatCents(123456789012), r'$1,234,567,890.12');
    });

    test('минус перед долларом', () {
      expect(formatCents(-50), r'-$0.50');
      expect(formatCents(-123456), r'-$1,234.56');
    });
  });

  group('formatCandleDate', () {
    test('полночь — только дата, иначе дата и время', () {
      expect(formatCandleDate(DateTime(2026, 7, 17)), '17.07.2026');
      expect(formatCandleDate(DateTime(2026, 7, 17, 14, 30)),
          '17.07.2026 14:30');
      expect(formatCandleDate(DateTime(2026, 1, 5, 9, 5)), '05.01.2026 09:05');
    });
  });

  group('closesOf', () {
    test('вынимает закрытия как double', () {
      expect(closesOf([_c(1, 2, 0, 150), _c(1, 2, 0, 250, day: 2)]),
          [150.0, 250.0]);
      expect(closesOf(const []), isEmpty);
    });
  });
}
