import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/models/models.dart';
import 'package:polaris/services/sim_engine.dart';
import 'package:polaris/services/storage.dart';
import 'package:polaris/state/portfolio_state.dart';

Quote q(String s, int price) =>
    Quote(symbol: s, priceCents: price, prevCloseCents: price, ts: DateTime(2026, 7, 20));

void main() {
  group('торговля через портфель', () {
    test('покупка списывает кэш, уведомляет, сохраняет', () async {
      final storage = MemoryStorage();
      final p = PortfolioState(storage: storage);
      var notified = 0;
      p.addListener(() => notified++);
      await p.buy('AAPL', 100000, 20000);
      expect(p.cashCents, startingCashCents - 100000);
      expect(p.positions['AAPL']!.qty, closeTo(5.0, 1e-9));
      expect(notified, greaterThan(0));
      // сохранилось
      final reloaded = PortfolioState(storage: storage);
      await reloaded.load();
      expect(reloaded.cashCents, p.cashCents);
      expect(reloaded.positions['AAPL']!.qty, closeTo(5.0, 1e-9));
    });

    test('продажа возвращает деньги и P&L', () async {
      final p = PortfolioState();
      await p.buy('AAPL', 100000, 20000);
      final t = await p.sell('AAPL', 5, 30000);
      expect(t.realizedPnlCents, 50000);
      expect(p.positions.containsKey('AAPL'), isFalse);
    });

    test('пустой портфель стоит ровно стартовый капитал', () {
      final p = PortfolioState();
      expect(p.totalValueCents({}), startingCashCents);
    });
  });

  group('доходность', () {
    test('рост портфеля виден в проценте и сумме', () async {
      final p = PortfolioState();
      await p.buy('AAPL', 100000, 20000); // 5 шт по $200
      final quotes = {'AAPL': q('AAPL', 24000)}; // +20%
      expect(p.totalReturnCents(quotes), 20000); // +$200
      expect(p.totalReturnPct(quotes), closeTo(2.0, 0.01)); // +2% от $10k
    });
  });

  group('дивиденды из календаря (честные — по факту владения на ex-date)', () {
    test('начисляется, если куплено ДО ex-date; будущий и чужой — нет', () async {
      var clock = DateTime(2026, 7, 10);
      final p = PortfolioState(now: () => clock);
      await p.buy('AAPL', 100000, 20000); // 5 шт, держим с 10 июля
      clock = DateTime(2026, 7, 20); // прошло время
      final due = [
        DividendDue(
            symbol: 'AAPL',
            perShareCents: 24,
            exDate: DateTime(2026, 7, 15)), // держали на эту дату → начислить
        DividendDue(
            symbol: 'MSFT',
            perShareCents: 80,
            exDate: DateTime(2026, 7, 15)), // нет позиции → нет
        DividendDue(
            symbol: 'AAPL',
            perShareCents: 99,
            exDate: DateTime(2026, 8, 1)), // будущий → нет
      ];
      final first = await p.applyDueDividends(due);
      expect(first.length, 1);
      expect(first.first.symbol, 'AAPL');
      expect(first.first.totalCents, 120); // 5 * $0.24
      expect(p.cashCents, startingCashCents - 100000 + 120);
      // повторный вызов — ничего не начисляет (дедуп)
      final second = await p.applyDueDividends(due);
      expect(second, isEmpty);
      expect(p.cashCents, startingCashCents - 100000 + 120);
    });

    test('куплено ПОСЛЕ ex-date — дивиденд НЕ начисляется (не халява)', () async {
      var clock = DateTime(2026, 7, 20);
      final p = PortfolioState(now: () => clock);
      await p.buy('AAPL', 100000, 20000); // купили 20 июля
      final due = [
        // отсечка была 15 июля — ДО покупки, начислять нельзя
        DividendDue(symbol: 'AAPL', perShareCents: 24, exDate: DateTime(2026, 7, 15)),
      ];
      final fresh = await p.applyDueDividends(due);
      expect(fresh, isEmpty);
      expect(p.cashCents, startingCashCents - 100000); // только трата на покупку
    });

    test('продажа всей позиции сбрасывает отсчёт владения', () async {
      var clock = DateTime(2026, 7, 10);
      final p = PortfolioState(now: () => clock);
      await p.buy('AAPL', 100000, 20000); // держим с 10 июля
      clock = DateTime(2026, 7, 12);
      await p.sell('AAPL', 5, 20000); // продали всё 12 июля
      clock = DateTime(2026, 7, 14);
      await p.buy('AAPL', 100000, 20000); // купили заново 14 июля
      clock = DateTime(2026, 7, 20);
      // отсечка 13 июля — МЕЖДУ продажей и повторной покупкой, не держали
      final due = [
        DividendDue(symbol: 'AAPL', perShareCents: 24, exDate: DateTime(2026, 7, 13)),
      ];
      final fresh = await p.applyDueDividends(due);
      expect(fresh, isEmpty); // на дату отсечки бумаги не было
    });

    test('дедуп переживает перезагрузку', () async {
      var clock = DateTime(2026, 7, 10);
      final storage = MemoryStorage();
      final p = PortfolioState(storage: storage, now: () => clock);
      await p.buy('AAPL', 100000, 20000);
      clock = DateTime(2026, 7, 20);
      final due = [
        DividendDue(symbol: 'AAPL', perShareCents: 24, exDate: DateTime(2026, 7, 15))
      ];
      final firstFresh = await p.applyDueDividends(due);
      expect(firstFresh.length, 1); // проверяем, что начислилось
      final cashAfter = p.cashCents;

      final reloaded = PortfolioState(storage: storage, now: () => clock);
      await reloaded.load();
      final again = await reloaded.applyDueDividends(due);
      expect(again, isEmpty); // не начислит повторно
      expect(reloaded.cashCents, cashAfter);
    });
  });

  group('сброс и AI-контекст', () {
    test('reset обнуляет портфель и дедуп дивидендов', () async {
      final p = PortfolioState();
      await p.buy('AAPL', 500000, 20000);
      await p.reset();
      expect(p.cashCents, startingCashCents);
      expect(p.positions, isEmpty);
    });

    test('aiContext не содержит личных данных, только цифры', () async {
      final p = PortfolioState();
      await p.buy('AAPL', 100000, 20000);
      final ctx = p.aiContext({'AAPL': q('AAPL', 24000)});
      expect(ctx['positions'], hasLength(1));
      expect((ctx['positions'] as List).first['symbol'], 'AAPL');
      expect(ctx.containsKey('cash_usd'), isTrue);
      expect(ctx['total_return_pct'], '2.0');
    });

    test('битый снапшот не роняет загрузку', () async {
      final storage = MemoryStorage({
        'polaris.portfolio.v1': {'engine': 'мусор', 'paidDividends': 'тоже мусор'}
      });
      final p = PortfolioState(storage: storage);
      await p.load();
      expect(p.cashCents, startingCashCents);
      expect(p.loaded, isTrue);
    });
  });
}
