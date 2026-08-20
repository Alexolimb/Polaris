/// Движок симулятора Polaris — чистый Dart, ни одной зависимости от Flutter.
/// Это сердце приложения, где живут деньги пользователя, поэтому:
/// - все суммы в центах (int), количества бумаг — double c округлением до 1e-8;
/// - каждая операция либо проходит целиком, либо бросает SimError — половинных
///   состояний не бывает;
/// - публичное состояние снаружи только читается.
library;

import 'dart:convert' show jsonEncode;

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

/// Что получилось, когда портфель пересобрали из событий (см. [SimEngine.fromEvents]).
class ReplayResult {
  final SimEngine engine;

  /// Сколько записей НЕ удалось учесть в деньгах — например, продажа бумаги,
  /// которую в журнале никогда не покупали (тогда деньги взялись бы из
  /// воздуха). ⚠️ Сами записи при этом ОСТАЮТСЯ в журнале с пометкой
  /// `primenena: false`: выбрасывать нельзя ничего.
  final int propushcheno;

  /// С какого момента честно держим каждую бумагу (для честных дивидендов).
  final Map<String, DateTime> firstHeldAt;

  /// Покупки, на которые в общем журнале не хватило учебного счёта. Они
  /// ПРИМЕНЕНЫ (деньги ушли в минус), а не выброшены. Этот список нужен, чтобы
  /// сказать человеку прямо: «вот из-за каких сделок счёт ушёл в минус».
  final List<Trade> sverhScheta;

  /// Насколько счёт ушёл в минус (0 — всё сошлось).
  final int pererashodCents;

  const ReplayResult({
    required this.engine,
    required this.propushcheno,
    required this.firstHeldAt,
    this.sverhScheta = const [],
    this.pererashodCents = 0,
  });
}

class SimEngine {
  int _cashCents;
  final Map<String, Position> _positions;
  final List<Trade> _trades;
  final List<DividendPayout> _dividends;
  int _seq = 0;
  final DateTime Function() _now;

  /// Откуда берётся ГЛОБАЛЬНЫЙ номер новой записи. Пусто — номера не
  /// раздаются (тогда синхронизация просто не включится, а приложение
  /// работает как раньше). Ставится снаружи, когда известно имя устройства.
  String Function()? uidFactory;

  SimEngine({DateTime Function()? now, this.uidFactory})
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
      uid: uidFactory?.call() ?? '',
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
      uid: uidFactory?.call() ?? '',
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
      // Запись, которую не удалось применить, лежит в журнале, но в деньгах и
      // бумагах её нет — иначе она исказила бы базу дивиденда.
      if (!t.primenena) continue;
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
    final exDay = asOf?.toIso8601String().substring(0, 10);
    final d = DividendPayout(
      symbol: symbol,
      perShareCents: perShareCents,
      qtyAtRecord: basisQty,
      totalCents: total,
      ts: _now(),
      // Номер выплаты НАРОЧНО не зависит от устройства: телефон и ноутбук
      // начислят один и тот же дивиденд каждый у себя, и на складе эти две
      // записи обязаны слиться в одну, а не удвоить деньги.
      uid: exDay != null ? uidVyplaty(symbol, exDay) : (uidFactory?.call() ?? ''),
      exDay: exDay,
    );
    _dividends.add(d);
    return d;
  }

  /// Глобальный номер выплаты по бумаге и дате отсечки — одинаковый везде.
  static String uidVyplaty(String symbol, String exDay) => 'dv_${symbol}_$exDay';

  /// Полный сброс к старту (решение Алекса: можно в любой момент).
  void reset() {
    _cashCents = startingCashCents;
    _positions.clear();
    _trades.clear();
    _dividends.clear();
    _neprochitannye.clear();
    _seq = 0;
  }

  // ---- непрочитанные куски файла ----

  /// Записи, которые в файле ЕСТЬ, но прочитать их не удалось (оборвалась
  /// запись, испортилась кодировка, поле не того вида).
  ///
  /// ⚠️ Раньше такие записи просто молча пропускались, и приложение считало,
  /// что прочитало файл целиком. На экране всё выглядело целым (деньги и
  /// позиции лежат в файле ОТДЕЛЬНО от журнала), приложение спокойно шло в
  /// сеть — а обмен объявляет журнал единственной правдой и стирает то, чего
  /// в журнале нет. Так испарялась целая бумага. Найдено ревизией 10.08.2026.
  ///
  /// Теперь: непрочитанный кусок ХРАНИТСЯ КАК ЕСТЬ (человека из него ещё можно
  /// вытащить руками), переезжает из сохранения в сохранение и поднимает флаг
  /// «прочиталось не полностью» — с таким портфелем в сеть не выходим.
  final List<Map<String, dynamic>> _neprochitannye = [];

  List<Map<String, dynamic>> get neprochitannyeZapisi =>
      List.unmodifiable(_neprochitannye);

  /// В файле остались куски, которые не прочитались.
  bool get estNeprochitannye => _neprochitannye.isNotEmpty;

  /// Забрать непрочитанные куски у прежнего движка.
  ///
  /// ⚠️ Пересборка движка (см. [fromEvents]) создаёт ЧИСТЫЙ движок: у него
  /// своих непрочитанных кусков нет. Раньше это значило, что любая пересборка
  /// — слияние со складом или кнопка «Убрать» — стирала единственную копию
  /// битой записи, из которой её ещё можно было вытащить руками, И ЗАОДНО
  /// молча опускала запрет на обмен: приложение спокойно уходило на склад, а
  /// склад стирает всё, чего нет в журнале. Найдено ревизией 10.08.2026.
  ///
  /// Теперь непрочитанное переживает ЛЮБУЮ пересборку, а запрет опускается
  /// только там, где кусок правда убран и отложен в сторону (см. [reset]).
  ///
  /// Кусков после вызова не меньше, чем было в [byli]. Те, что уже приехали
  /// вместе со снапшотом, повторно не добавляются; одинаковые считаются
  /// поштучно — два одинаковых битых куска так и останутся двумя.
  void zabratNeprochitannye(List<Map<String, dynamic>> byli) {
    if (byli.isEmpty) return;
    final uzheEst = <String, int>{};
    for (final m in _neprochitannye) {
      final k = _otpechatok(m);
      uzheEst[k] = (uzheEst[k] ?? 0) + 1;
    }
    for (final m in byli) {
      final k = _otpechatok(m);
      final skolko = uzheEst[k] ?? 0;
      if (skolko > 0) {
        uzheEst[k] = skolko - 1; // такой кусок уже здесь — не удваиваем
        continue;
      }
      _neprochitannye.add(m);
    }
  }

  /// Отпечаток куска — только чтобы не удваивать одно и то же. Сравнение
  /// нарочно грубое: ошибиться можно лишь в сторону «оставить лишнюю копию»,
  /// а терять куски нельзя.
  static String _otpechatok(Map<String, dynamic> m) {
    try {
      return jsonEncode(m);
    } catch (_) {
      return '$m';
    }
  }

  // ---- сохранение/загрузка (json-friendly) ----
  Map<String, dynamic> toJson() => {
        'cashCents': _cashCents,
        'seq': _seq,
        'positions': _positions.values.map((p) => p.toJson()).toList(),
        'trades': _trades.map((t) => t.toJson()).toList(),
        'dividends': _dividends.map((d) => d.toJson()).toList(),
        // Непрочитанное НЕ выбрасываем при следующей записи: иначе первое же
        // сохранение стёрло бы то единственное, из чего запись ещё можно
        // восстановить руками.
        if (_neprochitannye.isNotEmpty) 'neprochitannye': _neprochitannye,
      };

  /// Загрузка терпима к мусору: движок обязан подняться с любого снапшота.
  /// Но «поднялся» ≠ «прочитал всё»: каждый непрочитанный кусок запоминается
  /// в [neprochitannyeZapisi] и остаётся в файле.
  static int? _asInt(Object? v) => v is num ? v.toInt() : null;

  static SimEngine fromJson(
    Map<String, dynamic>? j, {
    DateTime Function()? now,
    String Function()? uidFactory,
  }) {
    final e = SimEngine(now: now, uidFactory: uidFactory);
    if (j == null) return e;
    // ⚠️ Кэш БОЛЬШЕ НЕ зажимается в ноль. После слияния двух устройств счёт
    // может честно уйти в минус (потратили с двух счетов больше, чем было на
    // одном), и «поправить» его до нуля значило бы подарить человеку деньги и
    // молча скрыть перерасход при следующем запуске.
    e._cashCents = _asInt(j['cashCents']) ?? startingCashCents;
    // Поля-списки берём с проверкой типа (is List), а НЕ через `as List?`:
    // валидный JSON, где positions/trades оказались не списком, иначе бросил бы
    // TypeError мимо внутренних try/catch и уронил бы старт (вечная заставка).
    var maxSeq = _asInt(j['seq']) ?? 0;

    void neprochitano(String gde, Object? raw) =>
        e._neprochitannye.add({'gde': gde, 'raw': raw});

    final positionsRaw = j['positions'];
    if (positionsRaw is List) {
      for (final raw in positionsRaw) {
        try {
          final p = Position.fromJson(raw as Map<String, dynamic>);
          if (p.qty > 0 && p.costCents >= 0) {
            e._positions[p.symbol] = p;
          } else {
            neprochitano('positions', raw);
          }
        } catch (_) {
          neprochitano('positions', raw);
        }
      }
    } else if (positionsRaw != null) {
      neprochitano('positions', positionsRaw);
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
        } catch (_) {
          neprochitano('trades', raw);
        }
      }
    } else if (tradesRaw != null) {
      neprochitano('trades', tradesRaw);
    }

    final dividendsRaw = j['dividends'];
    if (dividendsRaw is List) {
      for (final raw in dividendsRaw) {
        try {
          e._dividends.add(DividendPayout.fromJson(raw as Map<String, dynamic>));
        } catch (_) {
          neprochitano('dividends', raw);
        }
      }
    } else if (dividendsRaw != null) {
      neprochitano('dividends', dividendsRaw);
    }

    // То, что не прочиталось в прошлые разы, едет дальше без изменений.
    final staroe = j['neprochitannye'];
    if (staroe is List) {
      for (final raw in staroe) {
        if (raw is Map) {
          e._neprochitannye.add(raw.cast<String, dynamic>());
        } else {
          neprochitano('?', raw);
        }
      }
    } else if (staroe != null) {
      neprochitano('?', staroe);
    }

    e._seq = maxSeq;
    return e;
  }

  // ---- глобальные номера и пересборка из событий ----

  /// Раздать ГЛОБАЛЬНЫЕ номера записям, у которых их ещё нет.
  ///
  /// ⚠️ Это и есть та самая миграция, без которой синхронизировать нельзя.
  /// У всего, что человек накопил ДО обновления, есть только местный счётчик
  /// («t1», «t2»), и он на разных устройствах означает разные сделки. Пока
  /// каждой записи не выдан свой глобальный номер, на склад отправлять нечего.
  ///
  /// Возвращает, скольким записям номер выдали. Ноль — всё уже размечено.
  int vydatUid() {
    final gen = uidFactory;
    if (gen == null) return 0;
    var skolko = 0;
    for (var i = 0; i < _trades.length; i++) {
      if (_trades[i].uid.isEmpty) {
        _trades[i] = _trades[i].copyWith(uid: gen());
        skolko++;
      }
    }
    for (var i = 0; i < _dividends.length; i++) {
      if (_dividends[i].uid.isEmpty) {
        final d = _dividends[i];
        // Есть дата отсечки — номер device-независимый (склеится с копией
        // соседнего устройства). Нет — только случайный, иначе не отличить.
        _dividends[i] =
            d.copyWith(uid: d.exDay != null ? uidVyplaty(d.symbol, d.exDay!) : gen());
        skolko++;
      }
    }
    return skolko;
  }

  /// Все записи размечены глобальными номерами — синхронизироваться можно.
  bool get vseUidNaMeste =>
      _trades.every((t) => t.uid.isNotEmpty) &&
      _dividends.every((d) => d.uid.isNotEmpty);

  /// Пересобрать портфель ЦЕЛИКОМ из списка событий (сделки + выплаты).
  ///
  /// Зачем так, а не «слить два портфеля». Деньги и позиции — это не то, что
  /// можно «объединить»: два числа всегда спорят, и любое решение кого-то
  /// обворовывает. А вот сделки складываются честно: событие либо было, либо
  /// нет. Поэтому склад хранит ЖУРНАЛ СОБЫТИЙ, а деньги и позиции каждое
  /// устройство считает само, проигрывая журнал по порядку. Тогда телефон и
  /// ноутбук приходят к одинаковым цифрам без всякого спора.
  ///
  /// ⚠️ ИЗ ЖУРНАЛА НЕ ВЫБРАСЫВАЕТСЯ НИЧЕГО. Раньше покупка, на которую при
  /// пересборке «не хватило денег», просто пропускалась — и исчезала навсегда:
  /// ни в позициях, ни в истории, ни в файле на диске. Так испарялась целая
  /// бумага, купленная на втором устройстве, и обмен повторял это каждый раз.
  /// Найдено ревизией 10.08.2026.
  ///
  /// Теперь деньги — величина ПРОИЗВОДНАЯ от журнала: если сложенные с двух
  /// устройств покупки не влезают в один учебный счёт, счёт честно уходит в
  /// минус, а список таких покупок возвращается наверх, чтобы приложение
  /// сказало об этом прямо. Это учебное приложение: некрасивый минус не
  /// страшен, потеря записи — страшна.
  ///
  /// Записи, которые применить нельзя вообще (продажа бумаги, которой в
  /// журнале никогда не покупали — деньги взялись бы из воздуха), остаются в
  /// журнале с пометкой `primenena: false` и считаются в [ReplayResult.propushcheno].
  static ReplayResult fromEvents({
    required List<Trade> trades,
    required List<DividendPayout> dividends,
    DateTime Function()? now,
    String Function()? uidFactory,
  }) {
    final e = SimEngine(now: now, uidFactory: uidFactory);
    final firstHeld = <String, DateTime>{};
    final sverhScheta = <Trade>[];
    var propushcheno = 0;

    // Порядок — по времени события. При равенстве времени по глобальному
    // номеру: иначе телефон и ноутбук могли бы проиграть журнал по-разному
    // и получить разные деньги из одних и тех же событий.
    final sobytiya = <(DateTime, String, Trade?, DividendPayout?)>[
      for (final t in trades) (t.ts, t.uid, t, null),
      for (final d in dividends) (d.ts, d.uid, null, d),
    ]..sort((a, b) {
        final c = a.$1.compareTo(b.$1);
        return c != 0 ? c : a.$2.compareTo(b.$2);
      });

    for (final s in sobytiya) {
      final d = s.$4;
      if (d != null) {
        e._cashCents += d.totalCents;
        e._dividends.add(d);
        continue;
      }
      final t = s.$3!;
      if (t.side == TradeSide.buy) {
        // Мусорная запись (нулевое количество, отрицательная сумма) — применить
        // нельзя: деньги взялись бы из воздуха. Но и выбросить нельзя, поэтому
        // она едет в журнал непринятой.
        if (t.qty <= 0 || t.totalCents < 0) {
          propushcheno++;
          e._trades.add(
              t.copyWith(id: 't${++e._seq}', primenena: false, realizedPnlCents: 0));
          continue;
        }
        // Денег не хватило — покупку всё равно ПРИМЕНЯЕМ, счёт уходит в минус,
        // а сама покупка попадает в список «из-за чего так вышло».
        if (t.totalCents > e._cashCents) sverhScheta.add(t);
        e._cashCents -= t.totalCents;
        final old = e._positions[t.symbol];
        if (old == null) firstHeld[t.symbol] = t.ts;
        e._positions[t.symbol] = Position(
          symbol: t.symbol,
          qty: _roundQty((old?.qty ?? 0) + t.qty),
          costCents: (old?.costCents ?? 0) + t.totalCents,
        );
        e._trades.add(t.copyWith(id: 't${++e._seq}'));
      } else {
        final pos = e._positions[t.symbol];
        if (pos == null || t.qty <= 0 || t.qty > pos.qty + 1e-8) {
          // Продать больше, чем в журнале покупали, нельзя — это были бы деньги
          // из воздуха. Запись остаётся в журнале непринятой: её видно, она
          // едет на склад, её накрывает надгробие при «начать заново».
          propushcheno++;
          e._trades.add(
              t.copyWith(id: 't${++e._seq}', primenena: false, realizedPnlCents: 0));
          continue;
        }
        final q = (pos.qty - t.qty).abs() < 1e-8 ? pos.qty : _roundQty(t.qty);
        final costOfSold = q >= pos.qty
            ? pos.costCents
            : (pos.costCents * (q / pos.qty)).round();
        e._cashCents += t.totalCents;
        final remaining = _roundQty(pos.qty - q);
        if (remaining <= 0) {
          e._positions.remove(t.symbol);
          firstHeld.remove(t.symbol);
        } else {
          e._positions[t.symbol] = Position(
            symbol: t.symbol,
            qty: remaining,
            costCents: pos.costCents - costOfSold,
          );
        }
        e._trades.add(t.copyWith(
          id: 't${++e._seq}',
          realizedPnlCents: t.totalCents - costOfSold,
        ));
      }
    }

    return ReplayResult(
      engine: e,
      propushcheno: propushcheno,
      firstHeldAt: firstHeld,
      sverhScheta: List.unmodifiable(sverhScheta),
      pererashodCents: e._cashCents < 0 ? -e._cashCents : 0,
    );
  }
}
