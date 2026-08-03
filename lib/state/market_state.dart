/// Состояние вкладки «Рынки» (волна 1б): каталог, котировки, поиск, темы,
/// периодический опрос котировок видимых активов.
///
/// Опрос идёт раз в [pollInterval] (30 с) и ТОЛЬКО пока экран виден —
/// [setVisible] дёргает сам экран в initState/dispose. В тестах опрос
/// выключается флагом autoPoll: false.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/api.dart';
import '../services/market_repo.dart';

class MarketState extends ChangeNotifier {
  final MarketRepo repo;
  final Duration pollInterval;
  final bool autoPoll;

  MarketState({
    MarketRepo? repo,
    this.pollInterval = const Duration(seconds: 30),
    this.autoPoll = true,
  }) : repo = repo ?? MarketRepo();

  // ---- данные ----
  List<Asset> _assets = [];
  List<MarketTheme> _themes = [];
  final Map<String, Quote> _quotes = {};

  /// Свежесть, какой её объявил каталог сервера. Нужна, чтобы вернуть бумаге
  /// её честное «демо», когда настоящая цена перестала приходить: в _assets к
  /// тому моменту уже лежит поднятое `realtime`, и исходное значение иначе
  /// негде взять.
  final Map<String, QuoteFreshness> _catalogFreshness = {};

  // ---- ui-состояние ----
  bool _loading = false;
  bool _initDone = false;
  String? _error;
  String _query = '';
  String? _themeId;

  // ---- жизненный цикл ----
  Timer? _timer;
  bool _visible = false;
  bool _disposed = false;

  bool get loading => _loading;
  String? get error => _error;
  String get query => _query;
  String? get selectedThemeId => _themeId;
  bool get offline => repo.offline;
  List<Asset> get assets => List.unmodifiable(_assets);

  /// true — показанные цены СМОДЕЛИРОВАНЫ, а не пришли с биржи: либо мы
  /// офлайн и рисуем фикстуры, либо сервер честно пометил данные
  /// `freshness:"demo"` (сейчас его движок котировок синтетический).
  /// Нужен, чтобы приложение не подписывало выдуманные числа как «живые цены»
  /// — для обучающего инвест-продукта это принципиально.
  /// ⚠️ Бумагам с настоящей биржевой ценой (ключ Finnhub) свежесть поднимается
  /// до `realtime` в [_upgradeRealAssets], поэтому проверка ниже автоматически
  /// перестаёт считать их выдуманными.
  bool get pricesAreSimulated =>
      offline ||
      _assets.isEmpty ||
      _assets.any((a) => a.freshness == QuoteFreshness.demo);

  /// Темы, в которых есть хотя бы один актив (пустые чипы не показываем).
  List<MarketTheme> get themes => _themes
      .where((t) => _assets.any((a) => a.themeIds.contains(t.id)))
      .toList();

  Quote? quoteOf(String symbol) => _quotes[symbol];

  /// Активы после поиска и фильтра по теме.
  List<Asset> get filtered {
    final q = _query.trim().toLowerCase();
    return _assets.where((a) {
      if (_themeId != null && !a.themeIds.contains(_themeId)) return false;
      if (q.isEmpty) return true;
      return a.symbol.toLowerCase().contains(q) ||
          a.name.toLowerCase().contains(q);
    }).toList();
  }

  // Секции списка.
  List<Asset> get stocks =>
      filtered.where((a) => a.type == AssetType.stock).toList();
  List<Asset> get etfs => filtered
      .where((a) => a.type == AssetType.etf || a.type == AssetType.bondEtf)
      .toList();
  List<Asset> get cryptos =>
      filtered.where((a) => a.type == AssetType.crypto).toList();
  List<Asset> get fiats =>
      filtered.where((a) => a.type == AssetType.fiat).toList();

  /// Первичная загрузка: каталог + котировки. Повторный вызов — no-op.
  Future<void> init() async {
    if (_initDone || _loading) return;
    _loading = true;
    _notify();
    try {
      final cat = await repo.catalog();
      _assets = cat.assets;
      // Запоминаем, что сказал каталог, ДО того как поднимем свежесть по
      // настоящим ценам — иначе вернуть честное «демо» будет уже не из чего.
      for (final a in cat.assets) {
        _catalogFreshness[a.symbol] = a.freshness;
      }
      _themes = cat.themes;
      final qs = await repo.quotes(_pollSymbols());
      _mergeQuotes(qs);
      _error = null;
      _initDone = true;
    } catch (_) {
      // Репозиторий сам умеет в фикстуры, сюда попадать не должен, но экран
      // не имеет права упасть ни при каком раскладе.
      _error = 'Не удалось загрузить рынок';
    }
    _loading = false;
    _notify();
  }

  /// Экран сообщает о своей видимости: запуск/остановка опроса.
  void setVisible(bool visible) {
    _visible = visible;
    _syncTimer();
    if (visible && _initDone) {
      unawaited(refreshQuotes());
    }
  }

  void setQuery(String q) {
    if (q == _query) return;
    _query = q;
    _notify();
    unawaited(_ensureQuotes());
  }

  /// null — сбросить фильтр («Все»).
  void selectTheme(String? id) {
    if (id == _themeId) return;
    _themeId = id;
    _notify();
    unawaited(_ensureQuotes());
  }

  /// Принудительный опрос котировок видимых активов (тикает по таймеру).
  Future<void> refreshQuotes() async {
    if (!_initDone || _disposed) return;
    final qs = await repo.quotes(_pollSymbols(), refresh: true);
    if (_disposed) return;
    _mergeQuotes(qs);
    _notify();
  }

  /// Догрузить котировки для произвольных символов (например, бумаг из
  /// портфеля игрока, которых может не быть в текущем списке Рынков).
  Future<void> ensureQuotesFor(List<String> symbols, {bool refresh = false}) async {
    if (_disposed) return;
    final need = refresh
        ? symbols
        : symbols.where((s) => !_quotes.containsKey(s)).toList();
    if (need.isEmpty) return;
    final qs = await repo.quotes(need, refresh: refresh);
    if (_disposed) return;
    _mergeQuotes(qs);
    _notify();
  }

  // ---- внутренности ----

  /// Символы, которые сейчас на экране (кап 80 — щадим сервер).
  List<String> _pollSymbols() {
    final f = filtered;
    final source = f.isEmpty ? _assets : f;
    return source.map((a) => a.symbol).take(80).toList();
  }

  /// Дозагрузка котировок для активов, появившихся после смены фильтра.
  Future<void> _ensureQuotes() async {
    final missing =
        _pollSymbols().where((s) => !_quotes.containsKey(s)).toList();
    if (missing.isEmpty || _disposed) return;
    final qs = await repo.quotes(missing);
    if (_disposed) return;
    _mergeQuotes(qs);
    _notify();
  }

  void _syncTimer() {
    final want = _visible && autoPoll;
    if (want && _timer == null) {
      _timer = Timer.periodic(pollInterval, (_) => unawaited(refreshQuotes()));
    } else if (!want && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  /// Слить пришедшие котировки, НЕ затирая более свежие. Запросы идут
  /// параллельно (таймер + смена фильтра + догрузка), порядок завершения не
  /// гарантирован — поздно пришедший СТАРЫЙ ответ (ts раньше) игнорируется по
  /// символу, иначе на экране мигала бы устаревшая цена.
  void _mergeQuotes(Map<String, Quote> qs) {
    qs.forEach((sym, q) {
      final existing = _quotes[sym];
      if (existing == null || !q.ts.isBefore(existing.ts)) _quotes[sym] = q;
    });
    _upgradeRealAssets();
  }

  /// Приводит свежесть бумаг в соответствие с тем, откуда взята цена ПРЯМО
  /// СЕЙЧАС: пришла настоящая биржевая — `realtime`, не пришла — как было в
  /// каталоге сервера (обычно `demo`).
  ///
  /// Сделано здесь, а не в каждом месте интерфейса: бейдж «ДЕМО» и подписи
  /// читают `asset.freshness` в семи местах на двух экранах. Поправить одну
  /// точку надёжнее, чем семь — и новый экран получит правильный бейдж сам.
  ///
  /// ⚠️ Работает В ОБЕ СТОРОНЫ, и это главное. Первая версия только поднимала
  /// свежесть. Тогда после того, как человек убирал ключ (или кончался лимит
  /// запросов к бирже), цены снова становились выдуманными, а надпись
  /// «настоящие» оставалась. Приложение учит инвестировать — показывать
  /// выдуманную цену как биржевую нельзя ни секунды.
  void _upgradeRealAssets() {
    var changed = false;
    for (var i = 0; i < _assets.length; i++) {
      final a = _assets[i];
      final want = repo.isRealQuote(a.symbol)
          ? QuoteFreshness.realtime
          : (_catalogFreshness[a.symbol] ?? a.freshness);
      if (a.freshness != want) {
        _assets[i] = a.withFreshness(want);
        changed = true;
      }
    }
    if (changed) _assets = List.of(_assets);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
