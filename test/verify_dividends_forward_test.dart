// НЕЗАВИСИМАЯ ПРОВЕРКА патча дивидендов (проверяющий агент, 02.08.2026).
// Отличия от live_dividends_e2e_test.dart:
//  1) ходим через MarketRepo (реальный путь экрана), а не напрямую PolarisApi;
//  2) НЕ отматываем часы в прошлое — покупаем «сегодня» и смотрим,
//     что будет на СЛЕДУЮЩЕЙ отсечке (это и есть путь живого игрока);
//  3) перезапуск приложения эмулируем настоящим JSON-round-trip хранилищем,
//     чтобы поймать «починку до первого перезапуска» (дубль начисления).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/services/market_repo.dart';
import 'package:polaris/state/portfolio_state.dart';
import 'package:polaris/services/storage.dart';

/// Хранилище с настоящей сериализацией (как SharedPreferences на телефоне).
class JsonRoundTripStorage implements StorageGateway {
  final Map<String, String> raw = {};
  @override
  Future<Map<String, dynamic>?> readJson(String key) async {
    final s = raw[key];
    return s == null ? null : jsonDecode(s) as Map<String, dynamic>;
  }

  @override
  Future<void> writeJson(String key, Map<String, dynamic> value) async =>
      raw[key] = jsonEncode(value);
  @override
  Future<void> remove(String key) async => raw.remove(key);
}

void main() {
  test('forward: живой сервер + MarketRepo + перезапуск', () async {
    final repo = MarketRepo(); // боевой PolarisApi по умолчанию
    final events = await repo.dividends('MSFT');
    print('offline-флаг репозитория: ${repo.offline}');
    print('СЕРВЕР(MSFT): ' +
        events
            .map((e) =>
                '${e.exDate?.toIso8601String().substring(0, 10)}/${e.perShareCents}c')
            .join('  '));
    expect(repo.offline, isFalse, reason: 'репозиторий ушёл в фикстуры');

    final dues = [
      for (final e in events)
        if (e.exDate != null)
          DividendDue(
              symbol: 'MSFT', perShareCents: e.perShareCents, exDate: e.exDate!)
    ];
    final next = dues.map((d) => d.exDate).where((d) => d.isAfter(DateTime.now())).toList()
      ..sort();
    expect(next, isNotEmpty, reason: 'нет будущей отсечки');

    final storage = JsonRoundTripStorage();
    var clock = DateTime.now();
    final p1 = PortfolioState(storage: storage, now: () => clock);
    await p1.load();
    final trade = await p1.buy('MSFT', 200000, 42600); // $2000
    print('КУПИЛ сегодня: ${trade.qty} шт MSFT, кэш ${p1.cashCents}');

    // ШАГ 1 — сегодня. Прошедшая отсечка есть, но куплено ПОСЛЕ неё.
    final today = await p1.applyDueDividends(dues);
    print('ШАГ 1 (сегодня): начислено выплат ${today.length}, '
        'дивидендов всего ${p1.dividendsTotalCents}c');

    // ШАГ 2 — день после ближайшей будущей отсечки. Часы вперёд, данные те же.
    clock = next.first.add(const Duration(days: 1));
    final cashBefore = p1.cashCents;
    final due = await p1.applyDueDividends(dues);
    print('ШАГ 2 (${clock.toIso8601String().substring(0, 10)}): '
        'начислено ${due.length} — ' +
        due
            .map((d) => '${d.symbol} ${d.qtyAtRecord} x ${d.perShareCents}c = '
                '${d.totalCents}c')
            .join('; '));
    print('КЭШ: $cashBefore -> ${p1.cashCents}');
    expect(due, isNotEmpty, reason: 'на своей отсечке деньги не пришли');

    // ШАГ 3 — ПЕРЕЗАПУСК приложения: новый объект из того же хранилища.
    final p2 = PortfolioState(storage: storage, now: () => clock);
    await p2.load();
    print('ПОСЛЕ ПЕРЕЗАПУСКА: кэш ${p2.cashCents}, '
        'дивидендов ${p2.dividendsTotalCents}c');
    expect(p2.cashCents, p1.cashCents, reason: 'кэш не пережил перезапуск');
    final again = await p2.applyDueDividends(dues);
    print('ШАГ 3 (после перезапуска) начислено повторно: ${again.length} '
        '(должно быть 0), кэш ${p2.cashCents}');
    expect(again, isEmpty, reason: 'ДУБЛЬ после перезапуска');

    // ШАГ 4 — ещё через квартал сервер отдаст новую пару дат; проверяем,
    // что ключ дедупа не мешает начислить СЛЕДУЮЩУЮ выплату.
    final future = DividendDue(
        symbol: 'MSFT',
        perShareCents: dues.first.perShareCents,
        exDate: next.first.add(const Duration(days: 91)));
    clock = future.exDate.add(const Duration(days: 1));
    final q2 = await p2.applyDueDividends([future]);
    print('ШАГ 4 (следующий квартал): начислено ${q2.length}, '
        'кэш ${p2.cashCents}, дивидендов всего ${p2.dividendsTotalCents}c');
    expect(q2, isNotEmpty, reason: 'следующая квартальная выплата не пришла');
  }, timeout: const Timeout(Duration(seconds: 120)));
}
