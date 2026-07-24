import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/models/models.dart';
import 'package:polaris/services/sim_engine.dart';

Quote q(String s, int price, {int? prev}) => Quote(
    symbol: s,
    priceCents: price,
    prevCloseCents: prev ?? price,
    ts: DateTime(2026, 7, 20));

void main() {
  group('покупка', () {
    test('простая покупка списывает кэш и создаёт позицию', () {
      final e = SimEngine();
      final t = e.buyForAmount('AAPL', 100000, 20000); // $1000 по $200
      expect(t.qty, closeTo(5.0, 1e-9));
      expect(e.cashCents, startingCashCents - 100000);
      expect(e.positions['AAPL']!.qty, closeTo(5.0, 1e-9));
      expect(e.positions['AAPL']!.costCents, 100000);
    });

    test('дробные доли: 1 доллар в акцию за 200', () {
      final e = SimEngine();
      final t = e.buyForAmount('AAPL', 100, 20000);
      expect(t.qty, closeTo(0.005, 1e-9));
    });

    test('усреднение: две покупки складывают qty и cost', () {
      final e = SimEngine();
      e.buyForAmount('AAPL', 100000, 20000); // 5 шт по $200
      e.buyForAmount('AAPL', 100000, 25000); // 4 шт по $250
      final p = e.positions['AAPL']!;
      expect(p.qty, closeTo(9.0, 1e-9));
      expect(p.costCents, 200000);
      expect(p.avgCostCentsPerUnit, closeTo(22222, 1));
    });

    test('нельзя купить дороже, чем есть денег', () {
      final e = SimEngine();
      expect(() => e.buyForAmount('AAPL', startingCashCents + 1, 20000),
          throwsA(isA<SimError>()));
      expect(e.cashCents, startingCashCents); // ничего не списано
      expect(e.trades, isEmpty);
    });

    test('нулевые и отрицательные значения отбиваются', () {
      final e = SimEngine();
      expect(() => e.buyForAmount('AAPL', 0, 20000), throwsA(isA<SimError>()));
      expect(() => e.buyForAmount('AAPL', -5, 20000), throwsA(isA<SimError>()));
      expect(() => e.buyForAmount('AAPL', 100, 0), throwsA(isA<SimError>()));
    });
  });

  group('продажа', () {
    test('частичная продажа с прибылью: кэш, остаток, realized P&L', () {
      final e = SimEngine();
      e.buyForAmount('AAPL', 100000, 20000); // 5 шт, cost $1000
      final t = e.sellQty('AAPL', 2, 30000); // продали 2 по $300
      expect(t.totalCents, 60000);
      expect(t.realizedPnlCents, 60000 - 40000); // cost 2/5 от $1000 = $400
      expect(e.cashCents, startingCashCents - 100000 + 60000);
      final p = e.positions['AAPL']!;
      expect(p.qty, closeTo(3.0, 1e-9));
      expect(p.costCents, 60000); // остаток себестоимости
    });

    test('продажа всего закрывает позицию без пыли', () {
      final e = SimEngine();
      e.buyForAmount('AAPL', 99999, 33333); // кривые числа
      final qty = e.positions['AAPL']!.qty;
      e.sellQty('AAPL', qty, 33333);
      expect(e.positions.containsKey('AAPL'), isFalse);
    });

    test('продать больше, чем есть — ошибка, состояние не тронуто', () {
      final e = SimEngine();
      e.buyForAmount('AAPL', 100000, 20000);
      final cashBefore = e.cashCents;
      expect(() => e.sellQty('AAPL', 10, 20000), throwsA(isA<SimError>()));
      expect(e.cashCents, cashBefore);
      expect(e.positions['AAPL']!.qty, closeTo(5.0, 1e-9));
    });

    test('продажа несуществующей бумаги — ошибка', () {
      final e = SimEngine();
      expect(() => e.sellQty('TSLA', 1, 20000), throwsA(isA<SimError>()));
    });

    test('убыточная продажа даёт отрицательный realized', () {
      final e = SimEngine();
      e.buyForAmount('AAPL', 100000, 20000); // 5 по $200
      final t = e.sellQty('AAPL', 5, 10000); // всё по $100
      expect(t.realizedPnlCents, 50000 - 100000);
    });
  });

  group('дивиденды', () {
    test('начисление по позиции падает в кэш и историю', () {
      final e = SimEngine();
      e.buyForAmount('AAPL', 100000, 20000); // 5 шт
      final d = e.payDividend('AAPL', 24); // $0.24 на штуку
      expect(d!.totalCents, 120);
      expect(e.cashCents, startingCashCents - 100000 + 120);
      expect(e.dividendsTotalCents, 120);
    });

    test('нет бумаги — нет выплаты (null, не ошибка)', () {
      final e = SimEngine();
      expect(e.payDividend('AAPL', 24), isNull);
    });

    test('микро-позиция с нулевой выплатой не мусорит историю', () {
      final e = SimEngine();
      e.buyForAmount('AAPL', 1, 2000000); // пылинка акции
      final d = e.payDividend('AAPL', 1);
      expect(d, isNull);
      expect(e.dividends, isEmpty);
    });
  });

  group('оценка портфеля', () {
    test('totalValue и unrealized по котировкам', () {
      final e = SimEngine();
      e.buyForAmount('AAPL', 100000, 20000); // 5 шт
      final quotes = {'AAPL': q('AAPL', 24000)};
      expect(e.holdingsValueCents(quotes), 120000);
      expect(e.totalValueCents(quotes), startingCashCents + 20000);
      expect(e.unrealizedPnlCents(quotes), 20000);
    });

    test('нет котировки — позиция оценивается по вложенному', () {
      final e = SimEngine();
      e.buyForAmount('AAPL', 100000, 20000);
      expect(e.totalValueCents({}), startingCashCents);
    });
  });

  group('сброс и снапшоты', () {
    test('reset возвращает к стартовым 10 000', () {
      final e = SimEngine();
      e.buyForAmount('AAPL', 500000, 20000);
      e.reset();
      expect(e.cashCents, startingCashCents);
      expect(e.positions, isEmpty);
      expect(e.trades, isEmpty);
    });

    test('toJson → fromJson восстанавливает всё до цента', () {
      final e = SimEngine();
      e.buyForAmount('AAPL', 123456, 21739);
      e.buyForAmount('BTC', 200000, 6406100);
      e.sellQty('AAPL', 1, 25000);
      e.payDividend('AAPL', 24);
      final copy = SimEngine.fromJson(e.toJson());
      expect(copy.cashCents, e.cashCents);
      expect(copy.positions['AAPL']!.qty, closeTo(e.positions['AAPL']!.qty, 1e-9));
      expect(copy.positions['AAPL']!.costCents, e.positions['AAPL']!.costCents);
      expect(copy.trades.length, e.trades.length);
      expect(copy.dividendsTotalCents, e.dividendsTotalCents);
    });

    test('битый снапшот не роняет движок', () {
      final e = SimEngine.fromJson({
        'cashCents': 'мусор',
        'positions': [
          {'symbol': 'OK', 'qty': 1.0, 'costCents': 100},
          {'qty': 'битая запись'},
          {'symbol': 'NEG', 'qty': -5.0, 'costCents': 100},
        ],
        'trades': ['не объект'],
      });
      expect(e.cashCents, startingCashCents);
      expect(e.positions.keys.toList(), ['OK']);
      expect(e.trades, isEmpty);
    });

    test('fromJson(null) — чистый старт', () {
      final e = SimEngine.fromJson(null);
      expect(e.cashCents, startingCashCents);
    });
  });

  group('инварианты денег', () {
    test('кэш + вложено − выручено − дивиденды всегда сходится', () {
      final e = SimEngine();
      e.buyForAmount('AAPL', 123457, 19999);
      e.buyForAmount('BTC', 77777, 6406123);
      e.sellQty('AAPL', 2.5, 21001);
      e.payDividend('AAPL', 13);
      final spent = e.trades
          .where((t) => t.side == TradeSide.buy)
          .fold(0, (s, t) => s + t.totalCents);
      final received = e.trades
          .where((t) => t.side == TradeSide.sell)
          .fold(0, (s, t) => s + t.totalCents);
      expect(e.cashCents,
          startingCashCents - spent + received + e.dividendsTotalCents);
    });
  });
}
