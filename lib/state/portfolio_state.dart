/// Ядро игрока: портфель + торговля + дивиденды + сохранение.
///
/// Оборачивает чистый [SimEngine] (движок денег), добавляет:
/// - персистентность через [StorageGateway] (снапшот на устройстве);
/// - оценку по живым котировкам;
/// - начисление дивидендов из календаря с дедупликацией;
/// - анонимный снапшот для AI-наставника (без личных данных).
///
/// Это разделяемое ядро: его читают экран Портфель, шторка торговли, AI-чат,
/// генератор комментариев к сделкам. Один источник правды.
library;

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/sim_engine.dart';
import '../services/storage.dart';

/// Причитающийся дивиденд из календаря (сервер /v1/dividends).
class DividendDue {
  final String symbol;
  final int perShareCents;
  final DateTime exDate;
  const DividendDue(
      {required this.symbol, required this.perShareCents, required this.exDate});
}

const _snapshotKey = 'polaris.portfolio.v1';

class PortfolioState extends ChangeNotifier {
  final StorageGateway storage;
  final DateTime Function() _now;
  SimEngine _engine;

  // Ключи уже начисленных дивидендов (symbol@exDate) — защита от повторного
  // начисления при каждом заходе.
  final Set<String> _paidDividendKeys;

  // Когда открыта ТЕКУЩАЯ позиция по бумаге (первая покупка после того, как
  // позиции не было). Нужно для ЧЕСТНЫХ дивидендов: начисляем только те, чья
  // ex-date наступила ПОСЛЕ того, как игрок начал держать бумагу — иначе
  // покупка сегодня давала бы «бесплатный» дивиденд за прошлый период.
  // Сбрасывается при полном закрытии позиции.
  final Map<String, DateTime> _firstHeldAt = {};

  bool _loaded = false;
  bool get loaded => _loaded;

  // Барьер против notifyListeners после dispose: операции делают await
  // _persist() (disk I/O), а виджет мог уйти — как в MarketState/ChatState.
  // Переопределяем notifyListeners, чтобы защитить ВСЕ вызовы разом.
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  PortfolioState({
    StorageGateway? storage,
    DateTime Function()? now,
    SimEngine? engine,
  })  : storage = storage ?? MemoryStorage(),
        _now = now ?? DateTime.now,
        _engine = engine ?? SimEngine(now: now),
        _paidDividendKeys = {};

  // ---- чтение ----
  int get cashCents => _engine.cashCents;
  Map<String, Position> get positions => _engine.positions;
  List<Trade> get trades => _engine.trades;
  List<DividendPayout> get dividends => _engine.dividends;
  int get realizedPnlCents => _engine.realizedPnlCents;
  int get dividendsTotalCents => _engine.dividendsTotalCents;
  bool get isEmpty => positions.isEmpty && trades.isEmpty;

  int totalValueCents(Map<String, Quote> quotes) =>
      _engine.totalValueCents(quotes);
  int holdingsValueCents(Map<String, Quote> quotes) =>
      _engine.holdingsValueCents(quotes);
  int unrealizedPnlCents(Map<String, Quote> quotes) =>
      _engine.unrealizedPnlCents(quotes);

  /// Прибыль/убыток всего портфеля относительно стартовых $10 000.
  int totalReturnCents(Map<String, Quote> quotes) =>
      totalValueCents(quotes) - startingCashCents;

  double totalReturnPct(Map<String, Quote> quotes) =>
      totalValueCents(quotes) / startingCashCents * 100 - 100;

  // ---- загрузка/сохранение ----
  Future<void> load() async {
    final snap = await storage.readJson(_snapshotKey);
    if (snap != null) {
      final engineRaw = snap['engine'];
      _engine = SimEngine.fromJson(
          engineRaw is Map<String, dynamic> ? engineRaw : null, now: _now);
      final paid = snap['paidDividends'];
      if (paid is List) {
        for (final k in paid) {
          if (k is String) _paidDividendKeys.add(k);
        }
      }
      final held = snap['firstHeldAt'];
      if (held is Map) {
        held.forEach((k, v) {
          final ts = v is String ? DateTime.tryParse(v) : null;
          if (k is String && ts != null) _firstHeldAt[k] = ts;
        });
      }
      // Страховка после апгрейда со старого снапшота (без firstHeldAt): для
      // уже открытых позиций считаем, что держим «с начала времён» — не мешаем
      // начислить их будущие дивиденды, но и не выдаём прошлые (их ex-date всё
      // равно уже в _paidDividendKeys, если синк был).
      for (final sym in _engine.positions.keys) {
        _firstHeldAt.putIfAbsent(sym, () => DateTime.fromMillisecondsSinceEpoch(0));
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    await storage.writeJson(_snapshotKey, {
      'engine': _engine.toJson(),
      'paidDividends': _paidDividendKeys.toList(),
      'firstHeldAt': _firstHeldAt
          .map((k, v) => MapEntry(k, v.toIso8601String())),
    });
  }

  // ---- операции (каждая сохраняет и уведомляет) ----

  /// Купить на сумму [spendCents] по текущей цене [priceCents]. Бросает [SimError].
  Future<Trade> buy(String symbol, int spendCents, int priceCents) async {
    final wasHeld = _engine.positions.containsKey(symbol);
    final t = _engine.buyForAmount(symbol, spendCents, priceCents);
    // Открыли новую позицию — фиксируем момент, с которого честно держим.
    if (!wasHeld) _firstHeldAt[symbol] = _now();
    await _persist();
    notifyListeners();
    return t;
  }

  /// Продать [qty] по текущей цене. Бросает [SimError].
  Future<Trade> sell(String symbol, double qty, int priceCents) async {
    final t = _engine.sellQty(symbol, qty, priceCents);
    // Позиция закрыта полностью — забываем момент владения (при повторной
    // покупке отсчёт пойдёт заново, дивиденды из «прошлой жизни» не всплывут).
    if (!_engine.positions.containsKey(symbol)) _firstHeldAt.remove(symbol);
    await _persist();
    notifyListeners();
    return t;
  }

  /// Начать заново (решение Алекса: можно в любой момент).
  Future<void> reset() async {
    _engine.reset();
    _paidDividendKeys.clear();
    _firstHeldAt.clear();
    await _persist();
    notifyListeners();
  }

  /// Начислить причитающиеся дивиденды из календаря. ЧЕСТНО: начисляем выплату
  /// только если (а) ex-date уже наступила, (б) бумага сейчас в портфеле, и
  /// (в) ex-date наступила ПОСЛЕ того, как игрок открыл текущую позицию —
  /// то есть он реально держал бумагу на дату отсечки. Дедуп по symbol@date.
  /// Возвращает список новых выплат (для уведомлений).
  Future<List<DividendPayout>> applyDueDividends(List<DividendDue> dues) async {
    final now = _now();
    final fresh = <DividendPayout>[];
    for (final d in dues) {
      if (d.exDate.isAfter(now)) continue; // ещё не наступила
      final heldSince = _firstHeldAt[d.symbol];
      if (heldSince == null) continue; // бумаги в портфеле нет — начислять нечего
      if (d.exDate.isBefore(heldSince)) continue; // куплено уже ПОСЛЕ отсечки
      final key = '${d.symbol}@${d.exDate.toIso8601String().substring(0, 10)}';
      if (_paidDividendKeys.contains(key)) continue;
      final payout = _engine.payDividend(d.symbol, d.perShareCents);
      if (payout != null) {
        _paidDividendKeys.add(key); // помечаем только реально начисленные
        fresh.add(payout);
      }
    }
    if (fresh.isNotEmpty) {
      await _persist();
      notifyListeners();
    }
    return fresh;
  }

  /// Анонимный снапшот портфеля для AI-наставника Cosmo. БЕЗ личных данных —
  /// только тикеры, доли, оценка и P&L, чтобы он мог осмысленно комментировать.
  Map<String, dynamic> aiContext(Map<String, Quote> quotes) {
    return {
      'cash_usd': (cashCents / 100).toStringAsFixed(2),
      'total_value_usd': (totalValueCents(quotes) / 100).toStringAsFixed(2),
      'total_return_pct': totalReturnPct(quotes).toStringAsFixed(1),
      'positions': positions.values.map((p) {
        final q = quotes[p.symbol];
        final valueCents = q == null ? p.costCents : (p.qty * q.priceCents).round();
        return {
          'symbol': p.symbol,
          'qty': p.qty,
          'value_usd': (valueCents / 100).toStringAsFixed(2),
          'pnl_usd': ((valueCents - p.costCents) / 100).toStringAsFixed(2),
        };
      }).toList(),
    };
  }
}
