/// Репозиторий рынка (волна 1б): единственная дверь к данным для UI.
///
/// Правила:
/// - кэш в памяти с TTL (каталог 10 мин, котировки 25 с, свечи 5 мин);
/// - сервер недоступен → молча переключаемся на встроенные фикстуры
///   (~35 реалистичных активов) и поднимаем флаг [offline];
/// - сервер ожил → флаг снимается при первом удачном походе;
/// - наружу репозиторий НЕ бросает сетевых ошибок — у экрана всегда есть данные.
library;

import 'dart:math' as math;

import '../models/models.dart';
import 'api.dart';
import 'finnhub.dart';
// Каталог, цены и дивиденды офлайн-режима СГЕНЕРИРОВАНЫ из общего с сервером
// канона (server/data/market_base.json). Руками их здесь больше не держим:
// пока таблицы жили в двух местах, они разъехались и портфель прыгал при
// переключении онлайн↔офлайн (см. шапку market_base.g.dart).
export 'market_base.g.dart'
    show fixtureAssets, fixtureThemes, fixturePrices, marketBaseVersion;
import 'market_base.g.dart';

class MarketRepo {
  final PolarisApi? _api; // null — локальный режим (тесты, сервер не задеплоен)
  final DateTime Function() _now;

  /// Источник настоящих котировок. null или без ключа — цены как раньше.
  FinnhubApi? _finnhub;

  /// Бумаги, по которым пришла НАСТОЯЩАЯ биржевая цена. По ним бейдж «ДЕМО»
  /// снимается — а по остальным честно остаётся.
  final Set<String> _realtime = {};

  /// Есть ли хоть одна бумага с настоящей ценой.
  bool get hasRealQuotes => _realtime.isNotEmpty;

  /// Настоящая ли цена у этой бумаги.
  bool isRealQuote(String symbol) => _realtime.contains(symbol);

  /// Подключить/сменить источник настоящих котировок. Пустой ключ — отключить.
  void useFinnhub(String? apiKey) {
    final key = (apiKey ?? '').trim();
    if (key.isEmpty) {
      _finnhub = null;
      _realtime.clear();
      return;
    }
    if (_finnhub?.apiKey == key) return;
    _finnhub = FinnhubApi(apiKey: key);
    // Ключ сменили — прежние отметки «живое» больше ничего не значат, и кэш
    // надо перечитать, иначе на экране останутся старые выдуманные цены.
    _realtime.clear();
    _quotesAt.clear();
  }

  bool _offline = false;

  /// true — работаем на фикстурах/кэше, сервер недоступен. UI честно
  /// показывает бейдж «демо-данные».
  bool get offline => _offline;

  MarketRepo({PolarisApi? api, DateTime Function()? now})
      : _api = api ?? PolarisApi(),
        _now = now ?? DateTime.now;

  /// Локальный режим: в сеть не ходим вообще. Для тестов и офлайн-демо.
  MarketRepo.local({DateTime Function()? now})
      : _api = null,
        _now = now ?? DateTime.now {
    _offline = true;
  }

  // ---- каталог ----

  static const _catalogTtl = Duration(minutes: 10);
  MarketCatalog? _catalog;
  DateTime? _catalogAt;

  Future<MarketCatalog> catalog({bool refresh = false}) async {
    final cached = _catalog;
    if (!refresh &&
        cached != null &&
        _fresh(_catalogAt, _catalogTtl)) {
      return cached;
    }
    final api = _api;
    if (api != null) {
      try {
        final fetched = await api.fetchCatalog();
        if (fetched.assets.isNotEmpty) {
          _offline = false;
          _catalog = MarketCatalog(
            assets: fetched.assets,
            // сервер без тем — подставляем локальный набор
            themes:
                fetched.themes.isEmpty ? fixtureThemes : fetched.themes,
          );
          _catalogAt = _now();
          return _catalog!;
        }
      } on ApiException catch (e) {
        _markOffline(e);
      }
    }
    // Сервер не ответил: старый кэш лучше фикстур, фикстуры лучше пустоты.
    if (_catalog == null) {
      _catalog = const MarketCatalog(
          assets: fixtureAssets, themes: fixtureThemes);
      _catalogAt = _now();
    }
    return _catalog!;
  }

  // ---- котировки ----

  static const _quotesTtl = Duration(seconds: 25);
  final Map<String, Quote> _quotes = {};
  final Map<String, DateTime> _quotesAt = {}; // отметки ТОЛЬКО серверных данных

  /// Котировки для [symbols]. refresh=true — принудительно идём на сервер
  /// (периодический опрос). Чего нет ни на сервере, ни в кэше — фикстуры.
  Future<Map<String, Quote>> quotes(List<String> symbols,
      {bool refresh = false}) async {
    final stale = symbols
        .where((s) => refresh || !_fresh(_quotesAt[s], _quotesTtl))
        .toList();
    if (stale.isNotEmpty) {
      // Сначала — настоящая биржа, если человек вставил ключ Finnhub.
      // Что она отдала, помечаем как живое; остальное (крипта, валюты, не-США)
      // добирается прежним путём и честно остаётся «ДЕМО».
      final live = _finnhub;
      if (live != null && live.configured) {
        final real = await live.fetchQuotes(stale);
        final at = _now();
        for (final q in real) {
          _quotes[q.symbol] = q;
          _quotesAt[q.symbol] = at;
          _realtime.add(q.symbol);
        }
        if (real.isNotEmpty) _offline = false;
        stale.removeWhere((s) => _realtime.contains(s));
      }

      final api = _api;
      if (api != null && stale.isNotEmpty) {
        try {
          final fetched = await api.fetchQuotes(stale);
          final at = _now();
          for (final q in fetched) {
            _quotes[q.symbol] = q;
            _quotesAt[q.symbol] = at;
          }
          if (fetched.isNotEmpty) _offline = false;
        } on ApiException catch (e) {
          _markOffline(e);
        }
      }
      // Дыры затыкаем фикстурами (отметку времени НЕ ставим — при следующем
      // опросе снова попробуем сервер, так происходит «выздоровление»).
      for (final s in stale) {
        if (!_quotes.containsKey(s)) {
          final fq = _fixtureQuote(s);
          if (fq != null) _quotes[s] = fq;
        }
      }
    }
    return {
      for (final s in symbols)
        if (_quotes[s] != null) s: _quotes[s]!,
    };
  }

  // ---- свечи ----

  static const _candlesTtl = Duration(minutes: 5);
  final Map<String, List<Candle>> _candles = {};
  final Map<String, DateTime> _candlesAt = {};

  Future<List<Candle>> candles(String symbol, CandleRange range) async {
    final key = '$symbol/${range.query}';
    final cached = _candles[key];
    if (cached != null && _fresh(_candlesAt[key], _candlesTtl)) return cached;
    final api = _api;
    if (api != null) {
      try {
        final fetched = await api.fetchCandles(symbol, range);
        if (fetched.isNotEmpty) {
          _offline = false;
          _candles[key] = fetched;
          _candlesAt[key] = _now();
          return fetched;
        }
      } on ApiException catch (e) {
        _markOffline(e);
      }
    }
    final generated = _generateCandles(symbol, range);
    _candles[key] = generated;
    _candlesAt[key] = _now();
    return generated;
  }

  // ---- дивиденды ----

  static const _dividendsTtl = Duration(hours: 1);
  final Map<String, List<DividendEvent>> _dividends = {};
  final Map<String, DateTime> _dividendsAt = {};

  Future<List<DividendEvent>> dividends(String symbol) async {
    final cached = _dividends[symbol];
    if (cached != null && _fresh(_dividendsAt[symbol], _dividendsTtl)) {
      return cached;
    }
    final api = _api;
    if (api != null) {
      try {
        final fetched = await api.fetchDividends(symbol);
        _offline = false;
        _dividends[symbol] = fetched;
        _dividendsAt[symbol] = _now();
        return fetched;
      } on ApiException catch (e) {
        _markOffline(e);
      }
    }
    final fallback = _fixtureDividends(symbol);
    _dividends[symbol] = fallback;
    _dividendsAt[symbol] = _now();
    return fallback;
  }

  bool _fresh(DateTime? at, Duration ttl) =>
      at != null && _now().difference(at) < ttl;

  /// Поднять флаг «офлайн» — но ТОЛЬКО если это правда беда со связью.
  ///
  /// [ApiErrorKind.notFound] — это 404 на конкретный символ: сервер жив,
  /// он просто не знает такого тикера (раньше сервер в этом случае выдумывал
  /// цену $100, теперь честно отвечает 404). Считать это «нет сети» нельзя:
  /// приложение бы повесило бейдж «демо-данные» на весь экран из-за одной
  /// бумаги и перестало ходить на живой сервер за остальными.
  void _markOffline(ApiException e) {
    if (e.kind == ApiErrorKind.notFound) return;
    _offline = true;
  }

  // ==================== ФИКСТУРЫ ====================
  // Встроенный оффлайн-набор: экран живёт и в тестах, и пока сервер
  // не задеплоен. Цены — реалистичные для июля 2026, в центах.
  // Валюты котируем «за 100 единиц», иначе int-центы съедают точность.

  Quote? _fixtureQuote(String symbol) {
    final p = fixturePrices[symbol];
    if (p == null) return null;
    final asset = fixtureAssetBySymbol(symbol);
    final realtime =
        asset == null || asset.freshness == QuoteFreshness.realtime;
    return Quote(
      symbol: symbol,
      priceCents: p.price,
      prevCloseCents: p.prev,
      ts: _now(),
      marketOpen: realtime,
    );
  }

  /// Якорь дивидендной сетки — фиксированная дата, а НЕ «сейчас».
  /// Раньше офлайн-фикстуры (как и сервер) считали ex-date как `now + 5..40
  /// дней`, поэтому отсечка вечно убегала вперёд и `applyDueDividends`
  /// (там условие `exDate <= now`) не начислял НИ РАЗУ. Теперь сетка
  /// квартальная и привязана к эпохе: даты не зависят от момента запроса.
  static final DateTime _dividendEpoch = DateTime.utc(2026, 1, 1);
  static const int _quarterDays = 91;

  List<DividendEvent> _fixtureDividends(String symbol) {
    final per = fixtureDividendPerShare[symbol];
    if (per == null) return const [];
    final offsetDays = _stableSeed(symbol) % _quarterDays;
    final anchor = _dividendEpoch.add(Duration(days: offsetDays));
    final step = const Duration(days: _quarterDays);
    final k = _now().difference(anchor).inDays ~/ _quarterDays;
    DividendEvent make(int i) {
      final ex = anchor.add(step * i);
      return DividendEvent(
        symbol: symbol,
        exDate: ex,
        payDate: ex.add(const Duration(days: 7)),
        perShareCents: per,
      );
    }

    return [
      if (k >= 0) make(k), // последняя прошедшая — её и начислят
      make(k + 1), // следующая — для календаря
    ];
  }

  /// Детерминированный псевдослучайный ряд свечей: сид из символа+диапазона,
  /// последняя цена закрытия сходится к текущей котировке до цента.
  List<Candle> _generateCandles(String symbol, CandleRange range) {
    final price = fixturePrices[symbol]?.price ??
        _quotes[symbol]?.priceCents ??
        10000;
    final type = fixtureAssetBySymbol(symbol)?.type ?? AssetType.stock;
    final (count, step) = _rangeSpec(range);
    final vol = _volFor(type) * _rangeVolFactor(range);
    final rnd = math.Random(_stableSeed('$symbol/${range.query}'));

    var v = 1.0;
    final walk = <double>[];
    for (var i = 0; i < count; i++) {
      v *= 1 + (rnd.nextDouble() * 2 - 1) * vol;
      walk.add(v);
    }
    final scale = price / walk.last;
    final end = _now();
    final out = <Candle>[];
    var prevClose = walk.first * scale;
    for (var i = 0; i < count; i++) {
      final c = math.max(1, (walk[i] * scale).round());
      final o = math.max(1, prevClose.round());
      final hi = math.max(math.max(o, c),
          ((math.max(o, c)) * (1 + rnd.nextDouble() * vol * 0.5)).round());
      final lo = math.max(
          1,
          math.min(math.min(o, c),
              ((math.min(o, c)) * (1 - rnd.nextDouble() * vol * 0.5)).round()));
      out.add(Candle(
        t: end.subtract(step * (count - 1 - i)),
        o: o,
        h: hi,
        l: lo,
        c: c,
      ));
      prevClose = c.toDouble();
    }
    return out;
  }

  static (int, Duration) _rangeSpec(CandleRange r) => switch (r) {
        CandleRange.d1 => (24, const Duration(hours: 1)),
        CandleRange.w1 => (42, const Duration(hours: 4)),
        CandleRange.m1 => (30, const Duration(days: 1)),
        CandleRange.y1 => (52, const Duration(days: 7)),
      };

  static double _volFor(AssetType t) => switch (t) {
        AssetType.stock => 0.012,
        AssetType.etf => 0.008,
        AssetType.bondEtf => 0.004,
        AssetType.crypto => 0.03,
        AssetType.fiat => 0.0025,
      };

  static double _rangeVolFactor(CandleRange r) => switch (r) {
        CandleRange.d1 => 0.35,
        CandleRange.w1 => 0.6,
        CandleRange.m1 => 1.0,
        CandleRange.y1 => 1.8,
      };

  /// Стабильный сид (String.hashCode между запусками не гарантирован).
  static int _stableSeed(String s) {
    var h = 17;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  static Asset? fixtureAssetBySymbol(String symbol) {
    for (final a in fixtureAssets) {
      if (a.symbol == symbol) return a;
    }
    return null;
  }
}
