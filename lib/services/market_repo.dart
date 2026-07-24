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

class MarketRepo {
  final PolarisApi? _api; // null — локальный режим (тесты, сервер не задеплоен)
  final DateTime Function() _now;

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
      } on ApiException {
        _offline = true;
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
      final api = _api;
      if (api != null) {
        try {
          final fetched = await api.fetchQuotes(stale);
          final at = _now();
          for (final q in fetched) {
            _quotes[q.symbol] = q;
            _quotesAt[q.symbol] = at;
          }
          if (fetched.isNotEmpty) _offline = false;
        } on ApiException {
          _offline = true;
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
      } on ApiException {
        _offline = true;
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
      } on ApiException {
        _offline = true;
      }
    }
    final fallback = _fixtureDividends(symbol);
    _dividends[symbol] = fallback;
    _dividendsAt[symbol] = _now();
    return fallback;
  }

  bool _fresh(DateTime? at, Duration ttl) =>
      at != null && _now().difference(at) < ttl;

  // ==================== ФИКСТУРЫ ====================
  // Встроенный оффлайн-набор: экран живёт и в тестах, и пока сервер
  // не задеплоен. Цены — реалистичные для июля 2026, в центах.
  // Валюты котируем «за 100 единиц», иначе int-центы съедают точность.

  Quote? _fixtureQuote(String symbol) {
    final p = _fixturePrices[symbol];
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

  List<DividendEvent> _fixtureDividends(String symbol) {
    final per = _fixtureDividendPerShare[symbol];
    if (per == null) return const [];
    final ex = _now().add(Duration(days: 5 + _stableSeed(symbol) % 40));
    return [
      DividendEvent(
        symbol: symbol,
        exDate: ex,
        payDate: ex.add(const Duration(days: 14)),
        perShareCents: per,
      ),
    ];
  }

  /// Детерминированный псевдослучайный ряд свечей: сид из символа+диапазона,
  /// последняя цена закрытия сходится к текущей котировке до цента.
  List<Candle> _generateCandles(String symbol, CandleRange range) {
    final price = _fixturePrices[symbol]?.price ??
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

/// Темы-подборки (фолбэк, если сервер тем не прислал).
const List<MarketTheme> fixtureThemes = [
  MarketTheme(id: 'ai', title: 'ИИ'),
  MarketTheme(id: 'bigtech', title: 'Большие технологии'),
  MarketTheme(id: 'dividends', title: 'Дивидендные гиганты'),
  MarketTheme(id: 'green', title: 'Зелёная энергия'),
  MarketTheme(id: 'base', title: 'Надёжная база'),
  MarketTheme(id: 'crypto-og', title: 'Крипто-старожилы'),
];

/// ~35 активов: акции США (риалтайм), мировые гиганты (EOD), ETF,
/// облигационные ETF, крипта, валюты (за 100 единиц, EOD).
const List<Asset> fixtureAssets = [
  // --- акции США, реальное время ---
  Asset(symbol: 'AAPL', name: 'Apple Inc.', type: AssetType.stock, sector: 'Technology', themeIds: ['bigtech']),
  Asset(symbol: 'MSFT', name: 'Microsoft', type: AssetType.stock, sector: 'Technology', themeIds: ['ai', 'bigtech']),
  Asset(symbol: 'GOOGL', name: 'Alphabet (Google)', type: AssetType.stock, sector: 'Communication Services', themeIds: ['ai', 'bigtech']),
  Asset(symbol: 'AMZN', name: 'Amazon', type: AssetType.stock, sector: 'Consumer Cyclical', themeIds: ['bigtech']),
  Asset(symbol: 'NVDA', name: 'NVIDIA', type: AssetType.stock, sector: 'Technology', themeIds: ['ai', 'bigtech']),
  Asset(symbol: 'META', name: 'Meta Platforms', type: AssetType.stock, sector: 'Communication Services', themeIds: ['ai', 'bigtech']),
  Asset(symbol: 'TSLA', name: 'Tesla', type: AssetType.stock, sector: 'Consumer Cyclical', themeIds: ['green']),
  Asset(symbol: 'AMD', name: 'Advanced Micro Devices', type: AssetType.stock, sector: 'Technology', themeIds: ['ai']),
  Asset(symbol: 'JPM', name: 'JPMorgan Chase', type: AssetType.stock, sector: 'Financial Services', themeIds: ['dividends']),
  Asset(symbol: 'V', name: 'Visa', type: AssetType.stock, sector: 'Financial Services'),
  Asset(symbol: 'JNJ', name: 'Johnson & Johnson', type: AssetType.stock, sector: 'Healthcare', themeIds: ['dividends']),
  Asset(symbol: 'KO', name: 'Coca-Cola', type: AssetType.stock, sector: 'Consumer Defensive', themeIds: ['dividends']),
  Asset(symbol: 'PG', name: 'Procter & Gamble', type: AssetType.stock, sector: 'Consumer Defensive', themeIds: ['dividends']),
  Asset(symbol: 'XOM', name: 'Exxon Mobil', type: AssetType.stock, sector: 'Energy', themeIds: ['dividends']),
  Asset(symbol: 'DIS', name: 'Walt Disney', type: AssetType.stock, sector: 'Communication Services'),
  Asset(symbol: 'NFLX', name: 'Netflix', type: AssetType.stock, sector: 'Communication Services'),
  Asset(symbol: 'NEE', name: 'NextEra Energy', type: AssetType.stock, sector: 'Utilities', themeIds: ['green', 'dividends']),
  Asset(symbol: 'FSLR', name: 'First Solar', type: AssetType.stock, sector: 'Technology', themeIds: ['green']),
  // --- мировые гиганты, конец дня ---
  Asset(symbol: 'ASML', name: 'ASML Holding', type: AssetType.stock, sector: 'Technology', themeIds: ['ai'], freshness: QuoteFreshness.endOfDay),
  Asset(symbol: 'TM', name: 'Toyota Motor', type: AssetType.stock, sector: 'Consumer Cyclical', freshness: QuoteFreshness.endOfDay),
  // --- ETF ---
  Asset(symbol: 'SPY', name: 'S&P 500 (SPDR)', type: AssetType.etf, themeIds: ['base']),
  Asset(symbol: 'QQQ', name: 'Nasdaq 100 (Invesco)', type: AssetType.etf, themeIds: ['bigtech', 'base']),
  Asset(symbol: 'VTI', name: 'Весь рынок США (Vanguard)', type: AssetType.etf, themeIds: ['base']),
  Asset(symbol: 'SCHD', name: 'Дивидендные акции США (Schwab)', type: AssetType.etf, themeIds: ['dividends']),
  Asset(symbol: 'ICLN', name: 'Чистая энергетика (iShares)', type: AssetType.etf, themeIds: ['green']),
  // --- облигационные ETF ---
  Asset(symbol: 'BND', name: 'Облигации США (Vanguard)', type: AssetType.bondEtf, themeIds: ['base']),
  Asset(symbol: 'TLT', name: 'Долгие гособлигации США (iShares)', type: AssetType.bondEtf, themeIds: ['base']),
  // --- крипта, реальное время ---
  Asset(symbol: 'BTC', name: 'Bitcoin', type: AssetType.crypto, themeIds: ['crypto-og']),
  Asset(symbol: 'ETH', name: 'Ethereum', type: AssetType.crypto, themeIds: ['crypto-og']),
  Asset(symbol: 'SOL', name: 'Solana', type: AssetType.crypto),
  Asset(symbol: 'ADA', name: 'Cardano', type: AssetType.crypto),
  // --- валюты, цена за 100 единиц, конец дня ---
  Asset(symbol: 'EUR', name: 'Евро (за 100 EUR)', type: AssetType.fiat, freshness: QuoteFreshness.endOfDay),
  Asset(symbol: 'GBP', name: 'Британский фунт (за 100 GBP)', type: AssetType.fiat, freshness: QuoteFreshness.endOfDay),
  Asset(symbol: 'CHF', name: 'Швейцарский франк (за 100 CHF)', type: AssetType.fiat, freshness: QuoteFreshness.endOfDay),
  Asset(symbol: 'JPY', name: 'Японская иена (за 100 JPY)', type: AssetType.fiat, freshness: QuoteFreshness.endOfDay),
];

/// Цены фикстур: (текущая, вчерашнее закрытие), в центах.
const Map<String, ({int price, int prev})> _fixturePrices = {
  'AAPL': (price: 23412, prev: 23180),
  'MSFT': (price: 51230, prev: 50890),
  'GOOGL': (price: 20510, prev: 20690),
  'AMZN': (price: 24380, prev: 24010),
  'NVDA': (price: 17650, prev: 17210),
  'META': (price: 71540, prev: 72110),
  'TSLA': (price: 31220, prev: 32040),
  'AMD': (price: 19840, prev: 19510),
  'JPM': (price: 26150, prev: 26030),
  'V': (price: 31890, prev: 31760),
  'JNJ': (price: 16240, prev: 16190),
  'KO': (price: 7210, prev: 7180),
  'PG': (price: 17520, prev: 17580),
  'XOM': (price: 12470, prev: 12310),
  'DIS': (price: 11890, prev: 11750),
  'NFLX': (price: 128740, prev: 127210),
  'NEE': (price: 8460, prev: 8390),
  'FSLR': (price: 27390, prev: 26840),
  'ASML': (price: 112450, prev: 111200),
  'TM': (price: 21230, prev: 21340),
  'SPY': (price: 63840, prev: 63510),
  'QQQ': (price: 56210, prev: 55840),
  'VTI': (price: 31240, prev: 31090),
  'SCHD': (price: 8940, prev: 8910),
  'ICLN': (price: 3120, prev: 3060),
  'BND': (price: 7480, prev: 7490),
  'TLT': (price: 9210, prev: 9270),
  'BTC': (price: 11842000, prev: 11731000),
  'ETH': (price: 642000, prev: 631500),
  'SOL': (price: 21400, prev: 22150),
  'ADA': (price: 92, prev: 90),
  'EUR': (price: 10923, prev: 10896),
  'GBP': (price: 12704, prev: 12651),
  'CHF': (price: 11215, prev: 11168),
  'JPY': (price: 68, prev: 67),
};

/// Ближайший дивиденд на акцию, центы (фикстуры; сервер даст реальные).
const Map<String, int> _fixtureDividendPerShare = {
  'AAPL': 26,
  'MSFT': 83,
  'JNJ': 124,
  'KO': 51,
  'PG': 101,
  'XOM': 99,
  'JPM': 140,
  'NEE': 57,
  'V': 59,
  'TM': 120,
  'ASML': 160,
  'SCHD': 74,
  'SPY': 180,
  'VTI': 95,
  'QQQ': 68,
  'BND': 18,
  'TLT': 29,
};
