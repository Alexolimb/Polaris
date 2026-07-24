/// Движок симулятора Polaris — чистый Dart, ни одной зависимости от Flutter.
/// Это сердце приложения, где живут деньги пользователя, поэтому:
/// - все суммы в центах (int), количества бумаг — double c округлением до 1e-8;
/// - каждая операция либо проходит целиком, либо бросает SimError — половинных
///   состояний не бывает;
/// - публичное состояние снаружи только читается.
library;

import 'dart:math' as math;

import '../models/models.dart';

class SimError implements Exception {
  // Коды стабильны и используются UI-слоем (см. trade_sheet.dart) для
  // локализации сообщения через AppLocalizations — не переименовывать без
  // обновления соответствующей switch-ветки там.
  final String code;
  final String message;
  const SimError(this.code, this.message);
  @override
  String toString() => 'SimError($code): $message';
}

const startingCashCents = 1000000; // $10 000.00 — решение Алекса, фикс у всех

double _roundQty(double q) => (q * 1e8).roundToDouble() / 1e8;
// Для ПОКУПКИ на сумму: округляем количество ВНИЗ, чтобы никогда не выдать
// больше долей, чем реально оплачено (round мог бы дать «бесплатную» долю).
double _floorQty(double q) => (q * 1e8).floorToDouble() / 1e8;

class SimEngine {
  int _cashCents;
  final Map<String, Position> _positions;
  final List<Trade> _trades;
  final List<DividendPayout> _dividends;
  int _seq = 0;
  final DateTime Function() _now;

  SimEngine({DateTime Function()? now})
      : _cashCents = startingCashCents,
        _positions = {},
        _trades = [],
        _dividends = [],
        _now = now ?? DateTime.now;

  // ---- чтение состояния ----
  int get cashCents => _cashCents;
  Map<String, Position> get positions => Map.unmodifiable(_positions);
  List<Trade> get trades => List.unmodifiable(_trades);
  List<DividendPayout> get dividends => List.unmodifiable(_dividends);

  /// Стоимость позиций по переданным котировкам (нет котировки — позиция по её costCents).
  int holdingsValueCents(Map<String, Quote> quotes) {
    var sum = 0;
    for (final p in _positions.values) {
      final q = quotes[p.symbol];
      sum += q == null ? p.costCents : (p.qty * q.priceCents).round();
    }
    return sum;
  }

  int totalValueCents(Map<String, Quote> quotes) =>
      _cashCents + holdingsValueCents(quotes);

  /// Нереализованный P&L по открытым позициям.
  int unrealizedPnlCents(Map<String, Quote> quotes) {
    var sum = 0;
    for (final p in _positions.values) {
      final q = quotes[p.symbol];
      if (q != null) sum += (p.qty * q.priceCents).round() - p.costCents;
    }
    return sum;
  }

  int get realizedPnlCents =>
      _trades.fold(0, (s, t) => s + t.realizedPnlCents);

  int get dividendsTotalCents => _dividends.fold(0, (s, d) => s + d.totalCents);

  // ---- операции ----

  /// Покупка на сумму [spendCents] по цене [priceCents] за штуку.
  Trade buyForAmount(String symbol, int spendCents, int priceCents) {
    if (spendCents <= 0 || priceCents <= 0) {
      throw const SimError(
          'buy_amount_price_invalid', 'Сумма и цена должны быть больше нуля');
    }
    if (spendCents > _cashCents) {
      throw const SimError('insufficient_cash', 'Не хватает виртуальных денег');
    }
    final qty = _floorQty(spendCents / priceCents);
    if (qty <= 0) {
      throw const SimError('amount_too_small', 'Слишком маленькая сумма для этой цены');
    }
    // Списываем ровно за купленное количество (не полный spendCents): остаток-
    // «пыль» ниже цены одной 1e-8-доли остаётся кэшем, а не превращается в
    // фантомный убыток. Для ровных делений actualCents == spendCents.
    final actualCents = (qty * priceCents).round();
    _cashCents -= actualCents;
    final old = _positions[symbol];
    _positions[symbol] = Position(
      symbol: symbol,
      qty: _roundQty((old?.qty ?? 0) + qty),
      costCents: (old?.costCents ?? 0) + actualCents,
    );
    final t = Trade(
      id: 't${++_seq}',
      symbol: symbol,
      side: TradeSide.buy,
      qty: qty,
      priceCents: priceCents,
      totalCents: actualCents,
      ts: _now(),
    );
    _trades.add(t);
    return t;
  }

  /// Продажа [qty] штук по цене [priceCents]. qty может быть дробным.
  /// Продажа «всего» должна вызываться с qty позиции, хвосты до 1e-8 прощаем.
  Trade sellQty(String symbol, double qty, int priceCents) {
    if (qty <= 0 || priceCents <= 0) {
      throw const SimError(
          'sell_qty_price_invalid', 'Количество и цена должны быть больше нуля');
    }
    final pos = _positions[symbol];
    if (pos == null || pos.qty <= 0) {
      throw const SimError('no_position', 'Такой бумаги в портфеле нет');
    }
    var sellQty = _roundQty(qty);
    if (sellQty <= 0) {
      throw const SimError(
          'sell_qty_too_small', 'Слишком маленькое количество для продажи');
    }
    if (sellQty > pos.qty + 1e-8) {
      throw const SimError('sell_too_much', 'В портфеле меньше, чем продаёшь');
    }
    if ((pos.qty - sellQty).abs() < 1e-8) sellQty = pos.qty; // продать всё
    final proceeds = (sellQty * priceCents).round();
    // Себестоимость проданной части — пропорцией от средней.
    final costOfSold = sellQty >= pos.qty
        ? pos.costCents
        : (pos.costCents * (sellQty / pos.qty)).round();
    final realized = proceeds - costOfSold;
    _cashCents += proceeds;
    final remaining = _roundQty(pos.qty - sellQty);
    if (remaining <= 0) {
      _positions.remove(symbol);
    } else {
      _positions[symbol] = Position(
        symbol: symbol,
        qty: remaining,
        costCents: pos.costCents - costOfSold,
      );
    }
    final t = Trade(
      id: 't${++_seq}',
      symbol: symbol,
      side: TradeSide.sell,
      qty: sellQty,
      priceCents: priceCents,
      totalCents: proceeds,
      ts: _now(),
      realizedPnlCents: realized,
    );
    _trades.add(t);
    return t;
  }

  /// Сколько бумаг символа держали на конец даты [date] — восстанавливаем
  /// реплеем сделок (buy +qty, sell -qty) с ts <= date. Нужно для честных
  /// дивидендов: начисляем на количество на ДАТУ ОТСЕЧКИ, а не текущее.
  double qtyHeldAsOf(String symbol, DateTime date) {
    var q = 0.0;
    for (final t in _trades) {
      if (t.symbol != symbol || t.ts.isAfter(date)) continue;
      q += t.side == TradeSide.buy ? t.qty : -t.qty;
    }
    return q <= 0 ? 0.0 : _roundQty(q);
  }

  /// Начисление дивиденда: [perShareCents] за штуку. Если задан [asOf]
  /// (дата отсечки), база начисления — количество, которое держали на эту дату
  /// (реплей сделок), иначе текущая позиция. Возвращает null, если держать
  /// было нечего или выплата округлилась в ноль.
  DividendPayout? payDividend(String symbol, int perShareCents, {DateTime? asOf}) {
    if (perShareCents <= 0) {
      throw const SimError('dividend_invalid', 'Дивиденд должен быть больше нуля');
    }
    final pos = _positions[symbol];
    if (pos == null || pos.qty <= 0) return null;
    final basisQty = asOf != null ? qtyHeldAsOf(symbol, asOf) : pos.qty;
    if (basisQty <= 0) return null;
    final total = (basisQty * perShareCents).round();
    if (total <= 0) return null;
    _cashCents += total;
    final d = DividendPayout(
      symbol: symbol,
      perShareCents: perShareCents,
      qtyAtRecord: basisQty,
      totalCents: total,
      ts: _now(),
    );
    _dividends.add(d);
    return d;
  }

  /// Полный сброс к старту (решение Алекса: можно в любой момент).
  void reset() {
    _cashCents = startingCashCents;
    _positions.clear();
    _trades.clear();
    _dividends.clear();
    _seq = 0;
  }

  // ---- сохранение/загрузка (json-friendly) ----
  Map<String, dynamic> toJson() => {
        'cashCents': _cashCents,
        'seq': _seq,
        'positions': _positions.values.map((p) => p.toJson()).toList(),
        'trades': _trades.map((t) => t.toJson()).toList(),
        'dividends': _dividends.map((d) => d.toJson()).toList(),
      };

  /// Загрузка терпима к мусору: битые записи пропускаются, отрицательный кэш
  /// зажимается в ноль — движок обязан подняться с любого снапшота.
  static int? _asInt(Object? v) => v is num ? v.toInt() : null;

  static SimEngine fromJson(Map<String, dynamic>? j, {DateTime Function()? now}) {
    final e = SimEngine(now: now);
    if (j == null) return e;
    e._cashCents = math.max(0, _asInt(j['cashCents']) ?? startingCashCents);
    // Поля-списки берём с проверкой типа (is List), а НЕ через `as List?`:
    // валидный JSON, где positions/trades оказались не списком, иначе бросил бы
    // TypeError мимо внутренних try/catch и уронил бы старт (вечная заставка).
    var maxSeq = _asInt(j['seq']) ?? 0;
    final positionsRaw = j['positions'];
    if (positionsRaw is List) {
      for (final raw in positionsRaw) {
        try {
          final p = Position.fromJson(raw as Map<String, dynamic>);
          if (p.qty > 0 && p.costCents >= 0) e._positions[p.symbol] = p;
        } catch (_) {}
      }
    }
    final tradesRaw = j['trades'];
    if (tradesRaw is List) {
      for (final raw in tradesRaw) {
        try {
          final t = Trade.fromJson(raw as Map<String, dynamic>);
          e._trades.add(t);
          // Согласуем счётчик id с загруженными сделками — иначе при
          // отсутствующем/заниженном seq новые сделки получат дублирующие id.
          final n = t.id.startsWith('t') ? int.tryParse(t.id.substring(1)) : null;
          if (n != null && n > maxSeq) maxSeq = n;
        } catch (_) {}
      }
    }
    final dividendsRaw = j['dividends'];
    if (dividendsRaw is List) {
      for (final raw in dividendsRaw) {
        try {
          e._dividends.add(DividendPayout.fromJson(raw as Map<String, dynamic>));
        } catch (_) {}
      }
    }
    e._seq = maxSeq;
    return e;
  }
}
