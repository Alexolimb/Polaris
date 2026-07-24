import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/services/api.dart';

/// Проверяем КЛИЕНТ-СЕРВЕРНЫЙ контракт напрямую (раньше не был покрыт — из-за
/// этого разъехались форматы /v1/dividends, и честный дивидендный календарь
/// не работал против реального сервера, см. баг #1 из ревью).
void main() {
  PolarisApi apiReturning(String body) =>
      PolarisApi(httpGet: (uri, timeout) async => body);

  group('/v1/dividends контракт', () {
    test('парсит форму сервера {dividends:[{perShareCents}]}', () async {
      // Ровно та форма, что теперь отдаёт Cloudflare Worker (index.js).
      final api = apiReturning(
          '{"dividends":[{"symbol":"AAPL","exDate":"2026-04-04",'
          '"payDate":"2026-04-18","perShareCents":25}],"source":"seed"}');
      final events = await api.fetchDividends('AAPL');
      expect(events, hasLength(1));
      expect(events.first.symbol, 'AAPL');
      expect(events.first.perShareCents, 25);
      expect(events.first.exDate, DateTime.parse('2026-04-04'));
    });

    test('пустой список — не ошибка', () async {
      final api = apiReturning('{"dividends":[],"source":"seed"}');
      expect(await api.fetchDividends('ZZZ'), isEmpty);
    });

    test('битая запись пропускается, валидные остаются', () async {
      final api = apiReturning('{"dividends":['
          '{"symbol":"KO","exDate":"2026-06-14","perShareCents":48},'
          '{"garbage":true}]}');
      final events = await api.fetchDividends('KO');
      expect(events, hasLength(1));
      expect(events.first.perShareCents, 48);
    });
  });

  group('/v1/quotes и каталог — устойчивость', () {
    test('кривой JSON превращается в ApiException, не в краш', () async {
      final api = apiReturning('это не json');
      expect(() => api.fetchCatalog(), throwsA(isA<ApiException>()));
    });

    test('котировки парсятся, в центах', () async {
      final api = apiReturning('{"quotes":[{"symbol":"AAPL","priceCents":23412,'
          '"prevCloseCents":23180,"ts":"2026-07-20T14:00:00Z","marketOpen":true}]}');
      final quotes = await api.fetchQuotes(['AAPL']);
      expect(quotes, hasLength(1));
      expect(quotes.first.priceCents, 23412);
      expect(quotes.first.dayChangePct, closeTo(1.0, 0.05));
    });
  });
}
