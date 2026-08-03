import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/services/api.dart';
import 'package:polaris/services/finnhub.dart';
import 'package:polaris/services/market_repo.dart';

/// ЧЕСТНОСТЬ ЦЕНЫ — самое важное свойство этого приложения.
///
/// Polaris учит инвестировать. Показать выдуманную цену без бейджа «ДЕМО» —
/// значит соврать человеку про деньги. Здесь проверяется, что отметка «эта
/// цена настоящая» ставится и, главное, СНИМАЕТСЯ вовремя.
///
/// Эти тесты появились после ревизии 03.08.2026: первая версия умела только
/// поднимать отметку. Убрал ключ — цены снова выдуманные, а надпись
/// «настоящие» оставалась.
void main() {
  /// Поддельный сервер Polaris: отдаёт синтетические цены, как настоящий.
  PolarisApi fakeServer() => PolarisApi(
        httpGet: (uri, _) async {
          if (uri.path.endsWith('/v1/quotes')) {
            final symbols = (uri.queryParameters['symbols'] ?? '').split(',');
            return jsonEncode({
              'quotes': [
                for (final s in symbols)
                  if (s.isNotEmpty)
                    {
                      'symbol': s,
                      'priceCents': 10000,
                      'prevCloseCents': 10000,
                      'marketOpen': true,
                    }
              ]
            });
          }
          throw const ApiException(ApiErrorKind.notFound, 'не тот путь');
        },
      );

  FinnhubApi fakeExchange({
    required Set<String> knows,
    int maxPerMinute = 50,
    DateTime Function()? now,
  }) =>
      FinnhubApi(
        apiKey: 'ключ',
        maxPerMinute: maxPerMinute,
        now: now,
        httpGet: (uri, _) async {
          final s = uri.queryParameters['symbol'] ?? '';
          // Так Finnhub отвечает про бумаги вне бесплатного тарифа: нулями.
          if (!knows.contains(s)) return jsonEncode({'c': 0, 'pc': 0, 't': 0});
          return jsonEncode({'c': 250.0, 'pc': 240.0, 't': 0});
        },
      );

  test('настоящая цена помечается, выдуманная — нет', () async {
    final repo = MarketRepo(api: fakeServer());
    repo.useFinnhubApi(fakeExchange(knows: {'AAPL'}));

    final qs = await repo.quotes(['AAPL', 'BTC']);

    expect(repo.isRealQuote('AAPL'), isTrue);
    expect(repo.isRealQuote('BTC'), isFalse, reason: 'крипты нет в тарифе');
    expect(qs['AAPL']!.priceCents, 25000, reason: 'цена от биржи');
    expect(qs['BTC']!.priceCents, 10000, reason: 'цена от прежнего источника');
  });

  test('убрали ключ — отметка «настоящая» снимается', () async {
    final repo = MarketRepo(api: fakeServer());
    repo.useFinnhubApi(fakeExchange(knows: {'AAPL'}));
    await repo.quotes(['AAPL']);
    expect(repo.isRealQuote('AAPL'), isTrue);

    final changed = repo.useFinnhub('');

    expect(changed, isTrue);
    expect(repo.isRealQuote('AAPL'), isFalse,
        reason: 'источника больше нет — цена снова выдуманная');
    expect(repo.hasRealQuotes, isFalse);
  });

  test('биржа перестала отвечать — отметка снимается на следующем опросе',
      () async {
    final repo = MarketRepo(api: fakeServer());
    repo.useFinnhubApi(fakeExchange(knows: {'AAPL'}));
    await repo.quotes(['AAPL']);
    expect(repo.isRealQuote('AAPL'), isTrue);

    // Биржа больше не знает эту бумагу (лимит, отзыв ключа, что угодно).
    repo.useFinnhubApi(fakeExchange(knows: <String>{}));
    await repo.quotes(['AAPL'], refresh: true);

    expect(repo.isRealQuote('AAPL'), isFalse,
        reason: 'цена приехала от прежнего источника — она не биржевая');
  });

  test('кончился бюджет запросов — недостающие честно теряют отметку',
      () async {
    final clock = DateTime(2026, 8, 3, 12, 0, 0);
    final repo = MarketRepo(api: fakeServer());
    // Бюджета хватает на обе бумаги.
    repo.useFinnhubApi(
        fakeExchange(knows: {'AAPL', 'MSFT'}, now: () => clock));
    await repo.quotes(['AAPL', 'MSFT']);
    expect(repo.isRealQuote('AAPL'), isTrue);
    expect(repo.isRealQuote('MSFT'), isTrue);

    // Тот же час, бюджета хватает только на одну.
    repo.useFinnhubApi(fakeExchange(
        knows: {'AAPL', 'MSFT'}, maxPerMinute: 1, now: () => clock));
    await repo.quotes(['AAPL', 'MSFT'], refresh: true);

    expect(repo.isRealQuote('AAPL'), isTrue);
    expect(repo.isRealQuote('MSFT'), isFalse,
        reason: 'до неё бюджет не дошёл — цена не биржевая');
  });

  test('тот же ключ второй раз не считается сменой источника', () {
    final repo = MarketRepo(api: fakeServer());

    expect(repo.useFinnhub('abc'), isTrue, reason: 'первый раз — смена');
    expect(repo.useFinnhub('abc'), isFalse, reason: 'то же самое — не смена');
    expect(repo.useFinnhub(' abc '), isFalse, reason: 'пробелы не считаются');
    expect(repo.useFinnhub('другой'), isTrue);
    expect(repo.useFinnhub(''), isTrue, reason: 'выключение — смена');
    expect(repo.useFinnhub(''), isFalse, reason: 'выключать нечего');
    expect(repo.useFinnhub(null), isFalse);
  });

  test('без ключа всё работает как раньше', () async {
    final repo = MarketRepo(api: fakeServer());

    final qs = await repo.quotes(['AAPL']);

    expect(qs['AAPL']!.priceCents, 10000);
    expect(repo.hasRealQuotes, isFalse);
  });
}
