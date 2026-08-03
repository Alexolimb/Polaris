import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/models/models.dart';
import 'package:polaris/services/finnhub.dart';

/// Настоящие котировки: разбор ответа и защита от «нулевой цены».
///
/// Главная опасность здесь денежная: у бесплатного тарифа Finnhub на крипту и
/// не-США бумаги приходит `c: 0`. Принять ноль за цену — обнулить портфель
/// человека на ровном месте. Поэтому такие ответы должны выпадать, а не
/// превращаться в цену.
void main() {
  Future<String> canned(Map<String, Object?> body) async => jsonEncode(body);

  test('обычный ответ превращается в котировку, деньги — в центах', () async {
    final api = FinnhubApi(
      apiKey: 'ключ',
      httpGet: (uri, _) => canned({
        'c': 213.45,
        'pc': 210.0,
        't': 1754226000,
      }),
    );

    final quotes = await api.fetchQuotes(['AAPL']);

    expect(quotes, hasLength(1));
    expect(quotes.single.symbol, 'AAPL');
    expect(quotes.single.priceCents, 21345);
    expect(quotes.single.prevCloseCents, 21000);
    expect(quotes.single.dayChangePct, closeTo(1.64, 0.01));
  });

  test('нулевая цена (нет данных на бесплатном тарифе) НЕ становится ценой',
      () async {
    final api = FinnhubApi(
      apiKey: 'ключ',
      httpGet: (uri, _) => canned({'c': 0, 'pc': 0, 't': 0}),
    );

    expect(await api.fetchQuotes(['BTC']), isEmpty);
  });

  test('без закрытия прошлого дня изменение считается нулевым, а не -100%',
      () async {
    final api = FinnhubApi(
      apiKey: 'ключ',
      httpGet: (uri, _) => canned({'c': 50.0, 'pc': 0, 't': 0}),
    );

    final q = (await api.fetchQuotes(['XYZ'])).single;
    expect(q.prevCloseCents, 5000);
    expect(q.dayChangePct, 0);
  });

  test('поломка сети роняет только свою бумагу, остальные приходят', () async {
    final api = FinnhubApi(
      apiKey: 'ключ',
      httpGet: (uri, _) async {
        if (uri.queryParameters['symbol'] == 'BAD') throw StateError('сеть');
        return jsonEncode({'c': 10.0, 'pc': 10.0, 't': 0});
      },
    );

    final quotes = await api.fetchQuotes(['BAD', 'GOOD']);
    expect(quotes.map((q) => q.symbol), ['GOOD']);
  });

  test('мусор вместо JSON не роняет приложение', () async {
    final api = FinnhubApi(
      apiKey: 'ключ',
      httpGet: (uri, _) async => 'не json вовсе',
    );

    expect(await api.fetchQuotes(['AAPL']), isEmpty);
  });

  test('без ключа в сеть не ходим вообще', () async {
    var calls = 0;
    final api = FinnhubApi(
      apiKey: '   ',
      httpGet: (uri, _) async {
        calls++;
        return '{}';
      },
    );

    expect(api.configured, isFalse);
    expect(await api.fetchQuotes(['AAPL']), isEmpty);
    expect(calls, 0);
  });

  test('ключ уходит в запрос, тикер тоже', () async {
    Uri? seen;
    final api = FinnhubApi(
      apiKey: 'секрет',
      httpGet: (uri, _) async {
        seen = uri;
        return jsonEncode({'c': 1.0, 'pc': 1.0, 't': 0});
      },
    );

    await api.fetchQuotes(['MSFT']);
    expect(seen!.queryParameters['token'], 'секрет');
    expect(seen!.queryParameters['symbol'], 'MSFT');
    expect(seen!.host, 'finnhub.io');
  });

  group('бюджет запросов (бесплатный тариф — 60 в минуту)', () {
    test('больше разрешённого за минуту не спрашиваем', () async {
      var calls = 0;
      var clock = DateTime(2026, 8, 3, 12, 0, 0);
      final api = FinnhubApi(
        apiKey: 'ключ',
        maxPerMinute: 3,
        now: () => clock,
        httpGet: (uri, _) async {
          calls++;
          return jsonEncode({'c': 10.0, 'pc': 10.0, 't': 0});
        },
      );

      // Просим десять бумаг — экран «Рынки» опрашивает до 80 за раз.
      final quotes = await api.fetchQuotes(
          List.generate(10, (i) => 'S$i'));

      expect(calls, 3, reason: 'лимит должен останавливать, а не выбиваться');
      expect(quotes, hasLength(3));
      expect(api.budgetLeft, 0);
    });

    test('через минуту бюджет возвращается', () async {
      var clock = DateTime(2026, 8, 3, 12, 0, 0);
      final api = FinnhubApi(
        apiKey: 'ключ',
        maxPerMinute: 2,
        now: () => clock,
        httpGet: (uri, _) async => jsonEncode({'c': 1.0, 'pc': 1.0, 't': 0}),
      );

      await api.fetchQuotes(['A', 'B', 'C']);
      expect(api.budgetLeft, 0);

      clock = clock.add(const Duration(seconds: 61));
      expect(api.budgetLeft, 2);

      final again = await api.fetchQuotes(['C']);
      expect(again, hasLength(1));
    });

    test('бумаги, до которых не хватило бюджета, просто не возвращаются',
        () async {
      var clock = DateTime(2026, 8, 3, 12, 0, 0);
      final api = FinnhubApi(
        apiKey: 'ключ',
        maxPerMinute: 1,
        now: () => clock,
        httpGet: (uri, _) async => jsonEncode({'c': 5.0, 'pc': 5.0, 't': 0}),
      );

      final quotes = await api.fetchQuotes(['AAPL', 'MSFT']);
      expect(quotes.map((q) => q.symbol), ['AAPL']);
      // MSFT не пришла — значит вызывающий возьмёт её из прежнего источника
      // и честно оставит бейдж «ДЕМО».
    });
  });

  test('бумага с настоящей ценой перестаёт быть «демо»', () {
    const demo = Asset(
        symbol: 'AAPL',
        name: 'Apple',
        type: AssetType.stock,
        freshness: QuoteFreshness.demo);

    final live = demo.withFreshness(QuoteFreshness.realtime);

    expect(live.freshness, QuoteFreshness.realtime);
    expect(live.symbol, demo.symbol);
    expect(live.name, demo.name);
    // Исходная бумага не меняется — модель неизменяемая.
    expect(demo.freshness, QuoteFreshness.demo);
  });
}
