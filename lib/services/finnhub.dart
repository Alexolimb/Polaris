import 'dart:convert';

import '../models/models.dart';
import 'api.dart';

/// Настоящие биржевые котировки через Finnhub (бесплатный тариф).
///
/// Зачем это вообще: до сих пор цены в Polaris рисовал синтетический движок
/// сервера — правдоподобные, честно помеченные «ДЕМО», но выдуманные. Учиться
/// на них можно, а посмотреть «что там с моим Apple сегодня» — нет.
///
/// Почему прямо из приложения, а не через сервер: приложение ходит за данными
/// в n8n, а туда сейчас нельзя лезть (там работает другая задача). Прямой
/// запрос даёт настоящие цены сегодня и ничего не ломает на сервере. Ключ
/// живёт только на устройстве — как ключ Gemini в Dayo.
///
/// Бесплатный тариф Finnhub: 60 запросов в минуту, только акции и ETF США.
/// Крипта и валюты на бесплатном ключе не отдаются — по ним останется прежний
/// источник, и бейдж «ДЕМО» у них честно сохранится.
class FinnhubApi {
  FinnhubApi({
    required this.apiKey,
    HttpGetFn? httpGet,
    this.timeout = const Duration(seconds: 6),
    this.maxPerMinute = 50,
    DateTime Function()? now,
  })  : _get = httpGet ?? ioHttpGet,
        _now = now ?? DateTime.now;

  final String apiKey;
  final Duration timeout;
  final HttpGetFn _get;
  final DateTime Function() _now;

  /// Сколько запросов в минуту себе разрешаем.
  ///
  /// ⚠️ У бесплатного тарифа Finnhub потолок 60 запросов в минуту, а запрос
  /// нужен на КАЖДУЮ бумагу. Экран «Рынки» опрашивает до 80 бумаг раз в
  /// 30 секунд — это 160 запросов в минуту, то есть лимит выбивается за
  /// полминуты, дальше приходят отказы, и настоящие цены пропадают у всех.
  /// Держим потолок ниже разрешённого, с запасом.
  final int maxPerMinute;

  /// Времена последних запросов — скользящее окно в минуту.
  final List<DateTime> _sent = [];

  static const _base = 'https://finnhub.io/api/v1';

  bool get configured => apiKey.trim().isNotEmpty;

  /// Сколько запросов ещё можно сделать в текущем окне.
  int get budgetLeft {
    final edge = _now().subtract(const Duration(minutes: 1));
    _sent.removeWhere((t) => t.isBefore(edge));
    final left = maxPerMinute - _sent.length;
    return left < 0 ? 0 : left;
  }

  /// Котировки по списку тикеров. Finnhub отдаёт по одной бумаге за запрос,
  /// поэтому идём подряд; неответившие бумаги просто отсутствуют в результате,
  /// и вызывающий возьмёт для них прежний источник (и честно вернёт им
  /// бейдж «ДЕМО»).
  ///
  /// Ошибка одной бумаги не роняет остальные: это фон, а не действие человека.
  /// Кончился бюджет запросов — молча останавливаемся: лучше отдать половину
  /// настоящих цен, чем нарваться на отказы и не отдать ни одной.
  Future<List<Quote>> fetchQuotes(List<String> symbols) async {
    if (!configured || symbols.isEmpty) return const [];
    final out = <Quote>[];
    for (final symbol in symbols) {
      if (budgetLeft <= 0) break;
      _sent.add(_now());
      final quote = await _one(symbol);
      if (quote != null) out.add(quote);
    }
    return out;
  }

  Future<Quote?> _one(String symbol) async {
    try {
      final uri = Uri.parse('$_base/quote').replace(queryParameters: {
        'symbol': symbol,
        'token': apiKey.trim(),
      });
      final body = await _get(uri, timeout);
      final j = jsonDecode(body);
      if (j is! Map<String, dynamic>) return null;

      // c — текущая цена, pc — закрытие прошлого дня, t — время (секунды).
      final current = (j['c'] as num?)?.toDouble() ?? 0;
      final prevClose = (j['pc'] as num?)?.toDouble() ?? 0;

      // Ноль означает «нет данных по этой бумаге на бесплатном тарифе»
      // (крипта, не-США), а не «акция стоит ноль». Молча пропускаем: иначе
      // портфель обнулился бы на пустом месте.
      if (current <= 0) return null;

      final tsSec = (j['t'] as num?)?.toInt() ?? 0;
      return Quote(
        symbol: symbol,
        priceCents: (current * 100).round(),
        prevCloseCents:
            prevClose > 0 ? (prevClose * 100).round() : (current * 100).round(),
        ts: tsSec > 0
            ? DateTime.fromMillisecondsSinceEpoch(tsSec * 1000)
            : DateTime.now(),
        marketOpen: true,
      );
    } catch (_) {
      return null; // сеть/ключ/лимит — тихо откатываемся на прежний источник
    }
  }
}
