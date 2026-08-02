// БОЕВАЯ проверка начисления дивидендов (02.08.2026).
// Не мок: ходит в живой n8n-бэкенд https://178-105-123-85.nip.io/webhook/polaris,
// прогоняет ответ через настоящий PolarisApi и настоящий PortfolioState и
// показывает КОНКРЕТНУЮ сумму, которая упадёт игроку на счёт.
//
// Запуск: flutter test test/live_dividends_e2e_test.dart --plain-name live
// Нужен интернет. В обычный прогон CI не берём (тег live).
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/services/api.dart';
import 'package:polaris/state/portfolio_state.dart';

void main() {
  test('live: дивиденды с боевого сервера реально начисляются', () async {
    final api = PolarisApi();
    final events = await api.fetchDividends('AAPL');
    expect(events, isNotEmpty, reason: 'сервер не вернул ни одной выплаты');

    final now = DateTime.now();
    final past = events.where((e) => e.exDate != null && !e.exDate!.isAfter(now));
    print('СЕРВЕР вернул: '
        '${events.map((e) => "${e.exDate?.toIso8601String().substring(0, 10)}/"
            "${e.perShareCents}c").join("  ")}');
    expect(past, isNotEmpty,
        reason: 'нет ни одной ПРОШЕДШЕЙ отсечки — начислять нечего (это и был баг)');

    // Игрок купил AAPL до отсечки: сдвигаем «сейчас» назад, чтобы firstHeldAt
    // встал раньше ex-date, как у реального пользователя, который держит бумагу.
    final exFirst = past.first.exDate!;
    var fake = exFirst.subtract(const Duration(days: 10));
    final p = PortfolioState(now: () => fake);
    await p.load();
    final cashBefore = p.cashCents;
    final trade = await p.buy('AAPL', 100000, 24699); // $1000 по 246.99
    print('КУПИЛ: ${trade.qty} шт AAPL по 246.99, кэш ${cashBefore} -> ${p.cashCents}');

    fake = now; // «сейчас» — отсечка уже позади
    final cashPreDiv = p.cashCents;
    final fresh = await p.applyDueDividends([
      for (final e in events)
        if (e.exDate != null)
          DividendDue(
              symbol: 'AAPL', perShareCents: e.perShareCents, exDate: e.exDate!),
    ]);

    print('НАЧИСЛЕНО выплат: ${fresh.length}');
    for (final d in fresh) {
      print('  ${d.symbol}  ${d.qtyAtRecord} шт x ${d.perShareCents}c '
          '= ${d.totalCents}c (\$${(d.totalCents / 100).toStringAsFixed(2)})');
    }
    print('КЭШ: $cashPreDiv -> ${p.cashCents}  '
        'итого дивидендов ${p.dividendsTotalCents}c');

    expect(fresh, isNotEmpty, reason: 'дивиденды не начислились');
    expect(p.dividendsTotalCents, greaterThan(0));
    expect(p.cashCents, greaterThan(cashPreDiv));

    // Повторный заход не должен начислить второй раз.
    final again = await p.applyDueDividends([
      for (final e in events)
        if (e.exDate != null)
          DividendDue(
              symbol: 'AAPL', perShareCents: e.perShareCents, exDate: e.exDate!),
    ]);
    print('ПОВТОРНЫЙ заход начислил: ${again.length} (должно быть 0)');
    expect(again, isEmpty, reason: 'дубль начисления');
  }, tags: ['live'], timeout: const Timeout(Duration(seconds: 90)));
}
