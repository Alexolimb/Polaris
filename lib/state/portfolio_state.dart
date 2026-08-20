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

import 'dart:math' show Random;

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

/// Сделка не сохранилась на устройстве — и поэтому ОТМЕНЕНА целиком.
///
/// ⚠️ Раньше порядок был обратный: движок сначала списывал деньги и менял
/// позиции, и только потом шла запись на диск. Если запись срывалась, человек
/// видел красное «что-то пошло не так» — а деньги уже были списаны и бумага
/// уже куплена. Он жал «Купить» второй раз и покупал дважды, а после
/// перезапуска картинка менялась третий раз. Найдено ревизией 10.08.2026.
///
/// Теперь при неудачной записи портфель возвращается ровно в то состояние,
/// которое было до сделки, а наверх летит эта ошибка — шторка говорит прямо:
/// «сделка не сохранилась и отменена, деньги на месте».
class TradeNotSaved implements Exception {
  final Object cause;

  const TradeNotSaved(this.cause);

  @override
  String toString() => 'TradeNotSaved: $cause';
}

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

  // Надгробия: что было стёрто и когда (ISO UTC). Отсутствие записи в списке
  // ничего не значит — сделки складываются, поэтому «начать заново» должно
  // ехать на склад отдельным событием, иначе стёртый портфель вернулся бы
  // обратно с соседнего устройства. Тот же приём, что в Tycha.
  final Map<String, DateTime> _deleted = {};

  Map<String, DateTime> get deletedUids => Map.unmodifiable(_deleted);

  // Глобальные номера покупок, на которые после слияния двух устройств не
  // хватило учебного счёта. Сами покупки НА МЕСТЕ — и в позициях, и в истории,
  // и в файле; счёт честно ушёл в минус. Этот список нужен, чтобы сказать
  // человеку, из-за чего так вышло, и дать убрать лишнее руками.
  final Set<String> _sverhScheta = {};

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

  /// Счёт ушёл в минус: сложенные с двух устройств покупки не влезли в один
  /// учебный счёт. Ничего не выброшено — это честный остаток.
  bool get denegNeHvatilo => cashCents < 0;

  /// Насколько ушли в минус (0 — всё сошлось).
  int get pererashodCents => cashCents < 0 ? -cashCents : 0;

  /// Покупки, из-за которых счёт ушёл в минус — с суммами и датами.
  /// Именно их приложение показывает человеку и предлагает убрать руками.
  List<Trade> get sdelkiSverhScheta => [
        for (final t in trades)
          if (t.uid.isNotEmpty && _sverhScheta.contains(t.uid)) t,
      ];

  /// Записи, которые есть в журнале, но применить их к деньгам нельзя
  /// (продажа бумаги, которой никогда не покупали). Не выброшены — видны.
  List<Trade> get neprimenennyeSdelki =>
      [for (final t in trades) if (!t.primenena) t];

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

  /// ЕДИНСТВЕННАЯ дверь, через которую движок заменяется на другой.
  ///
  /// ⚠️ Непрочитанные куски файла — это данные человека и единственная копия,
  /// из которой битую запись ещё можно вытащить руками. Раньше о них
  /// заботились только в [reset] (там кусок откладывают в отдельный файл), а
  /// любая ДРУГАЯ пересборка движка — слияние со складом, кнопка «Убрать»,
  /// откат неудачной записи — молча начинала с чистого листа: кусок исчезал,
  /// а вместе с ним сам собой опускался запрет на обмен, и приложение спокойно
  /// уходило на склад. Найдено ревизией 10.08.2026 (второй заход).
  ///
  /// Теперь забота живёт в одном месте: сколько бы раз движок ни пересобрали,
  /// непрочитанное переезжает в новый, а сторож («в сеть нельзя») опускается
  /// только тогда, когда битого куска правда больше нет.
  void _postavitDvizhok(SimEngine noviy) {
    noviy.zabratNeprochitannye(_engine.neprochitannyeZapisi);
    _engine = noviy;
  }

  // ---- загрузка/сохранение ----
  Future<void> load() async {
    final snap = await storage.readJson(_snapshotKey);
    if (snap != null) {
      final engineRaw = snap['engine'];
      _postavitDvizhok(SimEngine.fromJson(
          engineRaw is Map<String, dynamic> ? engineRaw : null, now: _now));
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
      final graves = snap['deleted'];
      if (graves is List) {
        for (final raw in graves) {
          if (raw is! Map) continue;
          final id = raw['id'];
          final at = DateTime.tryParse('${raw['at']}');
          if (id is String && id.isNotEmpty && at != null) {
            _deleted[id] = at.toUtc();
          }
        }
      }
      // Из-за каких покупок счёт ушёл в минус. Список обязан пережить
      // перезапуск: иначе после закрытия приложения человек увидит минус без
      // единого объяснения и без возможности разобраться.
      final sverh = snap['sverhScheta'];
      if (sverh is List) {
        for (final uid in sverh) {
          if (uid is String && uid.isNotEmpty) _sverhScheta.add(uid);
        }
      }
      // Страховка после апгрейда со старого снапшота (без firstHeldAt): для
      // уже открытых позиций считаем, что держим «с начала времён» — не мешаем
      // начислить их будущие дивиденды, но и не выдаём прошлые (их ex-date всё
      // равно уже в _paidDividendKeys, если синк был).
      for (final sym in _engine.positions.keys) {
        _firstHeldAt.putIfAbsent(sym, () => DateTime.fromMillisecondsSinceEpoch(0));
      }
    }
    /*
     * Портфель на устройстве ЕСТЬ, но не прочитался.
     *
     * ⚠️ Раньше это было неотличимо от первого запуска: приложение показывало
     * свежие 10 000 долларов, а первая же покупка записывала пустой портфель
     * поверх настоящего. Позиции, вся история сделок и все дивиденды
     * исчезали навсегда, молча. Найдено ревизией 10.08.2026.
     *
     * Сама запись при этом никуда не делась — хранилище отложило её в сторону
     * (см. PrefsStorage.readJson), поэтому сохранять дальше уже не опасно.
     * Но сказать человеку обязаны: иначе он решит, что приложение «сбросилось
     * само», и продолжит играть на пустом счёте.
     */
    /*
     * ⚠️ Файл прочитался, а ОДНА запись внутри него — нет.
     *
     * Раньше это было незаметно: движок нарочно терпит мусор и битую запись
     * молча пропускал. Деньги и позиции лежат в файле ОТДЕЛЬНО от журнала,
     * поэтому на экране всё выглядело целым, флаг «прочиталось не полностью»
     * не поднимался, и приложение спокойно шло в сеть. А обмен объявляет
     * журнал единственной правдой и стирает всё, чего в журнале нет: целая
     * бумага исчезала при надписи «Готово» и «пропущено: 0».
     * Найдено ревизией 10.08.2026.
     *
     * «В файле есть запись, которую я не смог прочитать» — это тоже
     * «прочиталось не полностью». Сам кусок сохранён как есть (см.
     * SimEngine.neprochitannyeZapisi) и никуда не денется.
     */
    _fajlNeProchitalsya = PrefsStorage.bitaya(_snapshotKey);
    _loaded = true;
    notifyListeners();
  }

  bool _fajlNeProchitalsya = false;

  /// Сохранённый портфель нашёлся, но разобрался не весь (или не разобрался
  /// вовсе). Непрочитанное отложено в сторону, ничего не потеряно — но
  /// человеку надо об этом сказать, и в сеть с таким портфелем нельзя.
  ///
  /// Считается по ДВУМ поводам, и второй раньше не учитывался вовсе:
  ///  1. не прочитался ВЕСЬ файл;
  ///  2. в файле есть ЗАПИСЬ, которую не удалось прочитать.
  bool get snapshotBityy => _fajlNeProchitalsya || _engine.estNeprochitannye;

  /// Сколько кусков файла не прочиталось. Ноль — файл разобран целиком.
  int get neprochitannyhZapisey => _engine.neprochitannyeZapisi.length;

  /// Сами непрочитанные куски — КАК ЕСТЬ. Из них человека ещё можно вытащить
  /// руками, поэтому они хранятся и переезжают из сохранения в сохранение.
  List<Map<String, dynamic>> get neprochitannyeKuski =>
      _engine.neprochitannyeZapisi;

  Future<void> _persist() async {
    await storage.writeJson(_snapshotKey, {
      'engine': _engine.toJson(),
      'paidDividends': _paidDividendKeys.toList(),
      'firstHeldAt': _firstHeldAt
          .map((k, v) => MapEntry(k, v.toIso8601String())),
      'deleted': [
        for (final e in _deleted.entries)
          {'id': e.key, 'at': e.value.toUtc().toIso8601String()},
      ],
      'sverhScheta': _sverhScheta.toList(),
    });
  }

  /// Полный слепок состояния ДО операции — чтобы вернуть всё как было, если
  /// запись на диск не пройдёт.
  ({
    Map<String, dynamic> engine,
    Map<String, DateTime> held,
    Set<String> paid,
    Map<String, DateTime> deleted,
    Set<String> sverh,
  }) _slepok() => (
        engine: _engine.toJson(),
        held: Map.of(_firstHeldAt),
        paid: Set.of(_paidDividendKeys),
        deleted: Map.of(_deleted),
        sverh: Set.of(_sverhScheta),
      );

  /// Сохранить — или откатить операцию целиком и сказать об этом вслух.
  ///
  /// Половинных состояний быть не должно: либо сделка и на экране, и на диске,
  /// либо её нет нигде. Иначе человек видит одно, а после перезапуска — другое.
  Future<void> _persistOrRollback(
    ({
      Map<String, dynamic> engine,
      Map<String, DateTime> held,
      Set<String> paid,
      Map<String, DateTime> deleted,
      Set<String> sverh,
    }) before,
  ) async {
    try {
      await _persist();
    } catch (e) {
      _vernutKak(before);
      notifyListeners(); // экран обязан снова показать прежние деньги
      throw TradeNotSaved(e);
    }
  }

  /// Вернуть состояние ровно к слепку.
  void _vernutKak(
    ({
      Map<String, dynamic> engine,
      Map<String, DateTime> held,
      Set<String> paid,
      Map<String, DateTime> deleted,
      Set<String> sverh,
    }) before,
  ) {
    _postavitDvizhok(
        SimEngine.fromJson(before.engine, now: _now, uidFactory: _uidFactory));
    _firstHeldAt
      ..clear()
      ..addAll(before.held);
    _paidDividendKeys
      ..clear()
      ..addAll(before.paid);
    _deleted
      ..clear()
      ..addAll(before.deleted);
    _sverhScheta
      ..clear()
      ..addAll(before.sverh);
  }

  // ---- операции (каждая сохраняет и уведомляет) ----

  /// Купить на сумму [spendCents] по текущей цене [priceCents]. Бросает [SimError].
  Future<Trade> buy(String symbol, int spendCents, int priceCents) async {
    final before = _slepok();
    final wasHeld = _engine.positions.containsKey(symbol);
    final t = _engine.buyForAmount(symbol, spendCents, priceCents);
    // Открыли новую позицию — фиксируем момент, с которого честно держим.
    if (!wasHeld) _firstHeldAt[symbol] = _now();
    await _persistOrRollback(before); // не записалось — сделки не было вовсе
    notifyListeners();
    return t;
  }

  /// Продать [qty] по текущей цене. Бросает [SimError].
  Future<Trade> sell(String symbol, double qty, int priceCents) async {
    final before = _slepok();
    final t = _engine.sellQty(symbol, qty, priceCents);
    // Позиция закрыта полностью — забываем момент владения (при повторной
    // покупке отсчёт пойдёт заново, дивиденды из «прошлой жизни» не всплывут).
    if (!_engine.positions.containsKey(symbol)) _firstHeldAt.remove(symbol);
    await _persistOrRollback(before);
    notifyListeners();
    return t;
  }

  /// Начать заново (решение Алекса: можно в любой момент).
  ///
  /// Каждой стираемой записи ставим надгробие. Без этого «начать заново» на
  /// телефоне не значило бы ничего: при первом же обмене весь стёртый портфель
  /// приехал бы обратно с ноутбука, и человек решил бы, что кнопка сломана.
  Future<void> reset() async {
    final before = _slepok();
    final teper = _now().toUtc();
    // ⚠️ Надгробие ОБЯЗАНО лечь на КАЖДУЮ запись журнала, включая те, которые
    // раньше выбрасывались при слиянии (покупка «не хватило денег», продажа
    // «нечего продавать»). Без надгробия такая запись после «начать заново»
    // воскресла бы со склада при первом же обмене — человек стёр портфель, а
    // он вернулся. Теперь такие записи в журнале есть, значит и надгробие
    // получат: цикл ниже проходит по ним же.
    for (final t in _engine.trades) {
      if (t.uid.isNotEmpty) _deleted[t.uid] = teper;
    }
    for (final d in _engine.dividends) {
      if (d.uid.isNotEmpty) _deleted[d.uid] = teper;
    }
    // Непрочитанные куски файла нельзя ни стереть молча, ни оставить (иначе
    // «начать заново» не снимет запрет на обмен). Кладём их отдельной записью
    // с датой — на устройстве они остаются, разобрать руками можно.
    if (_engine.estNeprochitannye) {
      final den = teper.toIso8601String().substring(0, 10);
      await storage.writeJson('$_snapshotKey.neprochitannye-$den',
          {'zapisi': _engine.neprochitannyeZapisi});
    }
    _engine.reset();
    _paidDividendKeys.clear();
    _firstHeldAt.clear();
    _sverhScheta.clear();
    _propushchenoPriSliyanii = 0;
    await _persistOrRollback(before);
    notifyListeners();
  }

  // ---- синхронизация: глобальные номера и слияние ----

  String Function()? _uidFactory;

  /// Все записи размечены глобальными номерами и разметка ЛЕЖИТ НА ДИСКЕ.
  ///
  /// Пока это не так, синхронизироваться нельзя: номера, выданные только
  /// в памяти, после перезапуска будут другими, и одна и та же сделка уедет
  /// на склад дважды.
  bool get gotovKObmenu => _engine.vseUidNaMeste && !snapshotBityy;

  /// Сколько сделок пропало при последнем слиянии (не сложились). Ноль — всё
  /// сошлось. Это число экран обязан показать: молча терять сделки нельзя.
  int _propushchenoPriSliyanii = 0;
  int get propushchenoPriSliyanii => _propushchenoPriSliyanii;

  /// Выдать глобальные номера всему, что их ещё не имеет, и сохранить.
  ///
  /// [deviceId] — постоянное имя ЭТОГО устройства. Номер собирается из него,
  /// поэтому «сделка №1» на ноутбуке и «сделка №1» на телефоне получают разные
  /// глобальные номера и никогда не склеятся.
  ///
  /// Возвращает false, если разметку не удалось сохранить — тогда обмен
  /// начинать нельзя.
  Future<bool> podgotovitUid(String deviceId) async {
    if (deviceId.trim().isEmpty) return false;
    var schetchik = 0;
    _uidFactory = () {
      // Порядок частей ВАЖЕН. Номера сравниваются как строки, когда у двух
      // событий совпало время, а на Windows часы идут с точностью до
      // миллисекунды — три сделки подряд получают ОДНО И ТО ЖЕ время.
      // Поэтому сразу за временем идёт счётчик (с ведущими нулями, иначе
      // «10» окажется раньше «9»), и только потом случайная часть. Иначе
      // порядок сделок внутри миллисекунды решал бы случай: при пересборке
      // портфеля продажа могла встать раньше покупки, и сделка «не сложилась».
      final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
      final n = (schetchik++).toString().padLeft(6, '0');
      final r = Random().nextInt(1 << 32).toRadixString(36);
      return 'tr_${deviceId}_${t}_${n}_$r';
    };
    final before = _slepok(); // до миграции: откатывать надо именно к нему
    _engine.uidFactory = _uidFactory;
    final vydano = _engine.vydatUid();
    if (vydano == 0) return _engine.vseUidNaMeste;
    try {
      await _persist();
    } catch (_) {
      // Не записалось — откатываем разметку целиком. Номера, живущие только
      // в памяти, хуже, чем их отсутствие: после перезапуска они станут
      // другими, и склад получит одну сделку дважды.
      _postavitDvizhok(SimEngine.fromJson(before.engine,
          now: _now, uidFactory: _uidFactory));
      return false;
    }
    return true;
  }

  /// Применить то, что получилось после слияния со складом.
  ///
  /// Портфель пересобирается ИЗ СОБЫТИЙ: деньги и позиции — это не то, что
  /// можно «объединить», а вот сделки складываются честно (см. [SimEngine.fromEvents]).
  ///
  /// Возвращает false, если записать не удалось: тогда всё остаётся как было,
  /// а служба обмена обязана сказать об этом вслух.
  Future<bool> primenitSliyanie({
    required List<Trade> trades,
    required List<DividendPayout> dividends,
    required Map<String, DateTime> deleted,
  }) async {
    final before = _slepok();

    // Надгробие побеждает запись, если стёрли ПОЗЖЕ, чем правили. Равенство —
    // в пользу удаления: устройство, ещё не знающее про стирание, присылает
    // старую копию с прежней отметкой и не должно воскрешать её.
    bool zhiv(String uid, DateTime changed) {
      final grave = deleted[uid];
      return grave == null || grave.isBefore(changed.toUtc());
    }

    final itog = SimEngine.fromEvents(
      trades: [for (final t in trades) if (zhiv(t.uid, t.changed)) t],
      dividends: [for (final d in dividends) if (zhiv(d.uid, d.changed)) d],
      now: _now,
      uidFactory: _uidFactory,
    );

    _postavitDvizhok(itog.engine);
    _propushchenoPriSliyanii = itog.propushcheno;
    // Покупки, из-за которых счёт ушёл в минус. Раньше они просто исчезали;
    // теперь они на месте, а здесь остаётся список «из-за чего так вышло».
    _sverhScheta
      ..clear()
      ..addAll([
        for (final t in itog.sverhScheta)
          if (t.uid.isNotEmpty) t.uid,
      ]);
    _firstHeldAt
      ..clear()
      ..addAll(itog.firstHeldAt);
    // Ключи уже начисленных выплат восстанавливаем из самих выплат: иначе
    // дивиденд, начисленный на ноутбуке, приехал бы на телефон записью — и
    // телефон начислил бы его ВТОРОЙ раз, удвоив деньги.
    for (final d in itog.engine.dividends) {
      if (d.exDay != null) _paidDividendKeys.add('${d.symbol}@${d.exDay}');
    }
    _deleted
      ..clear()
      ..addAll(deleted);

    try {
      await _persist();
    } catch (_) {
      _vernutKak(before);
      notifyListeners();
      return false;
    }
    notifyListeners();
    return true;
  }

  /// Убрать лишнюю сделку РУКАМИ — то самое «с возможностью убрать лишние».
  ///
  /// Ставим надгробие (иначе сделка вернётся с соседнего устройства при первом
  /// же обмене) и пересобираем портфель из оставшегося журнала: деньги
  /// пересчитываются сами, потому что они — величина производная от журнала.
  ///
  /// Возвращает false, если записать не удалось: тогда всё остаётся как было.
  Future<bool> ubratSdelku(String uid) async {
    if (uid.isEmpty) return false;
    if (!_engine.trades.any((t) => t.uid == uid)) return false;
    final before = _slepok();

    _deleted[uid] = _now().toUtc();
    final ostalos = [for (final t in _engine.trades) if (t.uid != uid) t];
    final itog = SimEngine.fromEvents(
      trades: ostalos,
      dividends: _engine.dividends,
      now: _now,
      uidFactory: _uidFactory,
    );
    // Пересборка идёт через единственную дверь: битый кусок файла обязан
    // пережить и её, а сторож — остаться поднятым, пока кусок на месте.
    _postavitDvizhok(itog.engine);
    _propushchenoPriSliyanii = itog.propushcheno;
    _sverhScheta
      ..clear()
      ..addAll([
        for (final t in itog.sverhScheta)
          if (t.uid.isNotEmpty) t.uid,
      ]);
    _firstHeldAt
      ..clear()
      ..addAll(itog.firstHeldAt);

    try {
      await _persist();
    } catch (_) {
      _vernutKak(before);
      notifyListeners();
      return false;
    }
    notifyListeners();
    return true;
  }

  /// Начислить причитающиеся дивиденды из календаря. ЧЕСТНО: начисляем выплату
  /// только если (а) ex-date уже наступила, (б) бумага сейчас в портфеле, и
  /// (в) ex-date наступила ПОСЛЕ того, как игрок открыл текущую позицию —
  /// то есть он реально держал бумагу на дату отсечки. Дедуп по symbol@date.
  /// Возвращает список новых выплат (для уведомлений).
  Future<List<DividendPayout>> applyDueDividends(List<DividendDue> dues) async {
    final now = _now();
    final before = _slepok();
    final fresh = <DividendPayout>[];
    for (final d in dues) {
      if (d.exDate.isAfter(now)) continue; // ещё не наступила
      final heldSince = _firstHeldAt[d.symbol];
      if (heldSince == null) continue; // бумаги в портфеле нет — начислять нечего
      if (d.exDate.isBefore(heldSince)) continue; // куплено уже ПОСЛЕ отсечки
      final key = '${d.symbol}@${d.exDate.toIso8601String().substring(0, 10)}';
      if (_paidDividendKeys.contains(key)) continue;
      final payout =
          _engine.payDividend(d.symbol, d.perShareCents, asOf: d.exDate);
      if (payout != null) {
        _paidDividendKeys.add(key); // помечаем только реально начисленные
        fresh.add(payout);
      }
    }
    if (fresh.isNotEmpty) {
      // Не записалось — начисления откатываются целиком. Иначе деньги были бы
      // «на экране, но не на диске», а ключи выплат считались бы отданными.
      await _persistOrRollback(before);
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
