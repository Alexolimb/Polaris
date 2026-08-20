/// Общий портфель Polaris: телефон, ноутбук и Финансист в Telegram.
///
/// ── Как это работает по-простому ─────────────────────────────────────────────
/// На нашем сервере лежит один общий склад (воркфлоу n8n `polaris-sync`).
/// Устройство отправляет туда свои СОБЫТИЯ — сделки и начисленные дивиденды, —
/// склад складывает их с чужими и возвращает общий список. Деньги и позиции
/// каждое устройство считает само, проигрывая этот список по порядку.
///
/// Почему именно события, а не «портфель целиком». Деньги — одно число. Два
/// числа с двух устройств всегда спорят, и любой ответ кого-то обворовывает.
/// А события складываются честно: сделка либо была, либо нет. Проиграв
/// одинаковый список, телефон и ноутбук приходят к одинаковым цифрам без спора.
///
/// ── Четыре правила, которых нельзя нарушать (уроки Dayo, Nutri и Tycha) ──────
/// 1. У каждой записи есть ГЛОБАЛЬНЫЙ номер. Местный счётчик («сделка №1»)
///    на разных устройствах означает РАЗНЫЕ сделки: синхронизировать по нему —
///    значит склеить чужое и потерять половину. На этом уже обожглись в Dayo.
/// 2. Спор двух копий решает время ИЗМЕНЕНИЯ (`changedAt`), а не время
///    отправки. Иначе телефон, неделю пролежавший в кармане, затрёт своей
///    старой копией свежую правку с ноутбука — молча, без следа в логе.
/// 3. Удаление — событие, а не пропажа: у стёртой записи остаётся надгробие.
///    Иначе «начать заново» на телефоне ничего не значит: портфель вернётся
///    с ноутбука при первом же обмене.
/// 4. Пустой или непонятный ответ склада НЕ ТРОГАЕТ местные данные. «Склад
///    пуст» и «склад не ответил» — это разные вещи, и вторая не должна ничего
///    стирать. Ровно на этом чинили Fluxo и Polaris 10.08.2026.
///
/// ── Секрет ──────────────────────────────────────────────────────────────────
/// Ключ склада НЕ лежит в коде. Он приходит из сборки:
///   flutter build apk --dart-define=POLARIS_SYNC_SECRET=...
/// Нет ключа — обмен просто выключен, и приложение работает ровно как раньше.
/// Так же сделано у всех четырёх соседей.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../state/learn_state.dart';
import '../state/portfolio_state.dart';
import 'api.dart' show ApiErrorKind, ApiException;
import 'storage.dart';

/// Адрес склада и ключ к нему. Оба задаются при сборке, значений по умолчанию
/// у ключа НЕТ — секрету не место в исходниках.
class PolarisSyncConfig {
  final String url;
  final String secret;

  const PolarisSyncConfig({required this.url, required this.secret});

  /// То, с чем приложение собрано. Пустой ключ = обмен выключен.
  static const PolarisSyncConfig izSborki = PolarisSyncConfig(
    url: String.fromEnvironment(
      'POLARIS_SYNC_URL',
      defaultValue: 'https://178-105-123-85.nip.io/webhook/polaris-sync',
    ),
    secret: String.fromEnvironment('POLARIS_SYNC_SECRET'),
  );

  bool get nastroen => url.trim().isNotEmpty && secret.trim().isNotEmpty;
}

/* ── Перевод записей в то, что уезжает на склад, и обратно ─────────────────── */

/// На складе у записи ОДИН номер — глобальный. Местный счётчик («t3») туда не
/// едет вовсе: за пределами своего устройства он не значит ничего.
class TradeWire {
  static Map<String, dynamic> toJson(Trade t) => {
        'id': t.uid,
        'symbol': t.symbol,
        'side': t.side.name,
        'qty': t.qty,
        'priceCents': t.priceCents,
        'totalCents': t.totalCents,
        // Момент сделки едет ВСЕМИРНЫМ временем: по нему выстраивается порядок
        // событий, а порядок обязан быть одинаковым на всех устройствах.
        'ts': t.ts.toUtc().toIso8601String(),
        'realizedPnlCents': t.realizedPnlCents,
        'changedAt': t.changed.toUtc().toIso8601String(),
      };

  static Trade? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final uid = '${raw['id'] ?? ''}';
    if (uid.isEmpty || uid == 'null') return null;
    final ts = DateTime.tryParse('${raw['ts']}')?.toLocal();
    final qty = raw['qty'];
    final price = raw['priceCents'];
    final total = raw['totalCents'];
    if (ts == null || qty is! num || price is! num || total is! num) return null;
    return Trade(
      id: '', // местный номер выдаст пересборка портфеля
      uid: uid,
      symbol: '${raw['symbol']}',
      side: TradeSide.values.asNameMap()['${raw['side']}'] ?? TradeSide.buy,
      qty: qty.toDouble(),
      priceCents: price.toInt(),
      totalCents: total.toInt(),
      ts: ts,
      realizedPnlCents: (raw['realizedPnlCents'] as num?)?.toInt() ?? 0,
      changedAt: DateTime.tryParse('${raw['changedAt']}')?.toUtc(),
    );
  }
}

class DividendWire {
  static Map<String, dynamic> toJson(DividendPayout d) => {
        'id': d.uid,
        'symbol': d.symbol,
        'perShareCents': d.perShareCents,
        'qtyAtRecord': d.qtyAtRecord,
        'totalCents': d.totalCents,
        'ts': d.ts.toUtc().toIso8601String(),
        if (d.exDay != null) 'exDay': d.exDay,
        'changedAt': d.changed.toUtc().toIso8601String(),
      };

  static DividendPayout? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final uid = '${raw['id'] ?? ''}';
    if (uid.isEmpty || uid == 'null') return null;
    final ts = DateTime.tryParse('${raw['ts']}')?.toLocal();
    final per = raw['perShareCents'];
    final total = raw['totalCents'];
    if (ts == null || per is! num || total is! num) return null;
    return DividendPayout(
      symbol: '${raw['symbol']}',
      perShareCents: per.toInt(),
      qtyAtRecord: (raw['qtyAtRecord'] as num?)?.toDouble() ?? 0,
      totalCents: total.toInt(),
      ts: ts,
      uid: uid,
      exDay: raw['exDay'] is String ? raw['exDay'] as String : null,
      changedAt: DateTime.tryParse('${raw['changedAt']}')?.toUtc(),
    );
  }
}

/// Что получилось после слияния.
class MergedPortfolio {
  final List<Trade> trades;
  final List<DividendPayout> dividends;
  final Map<String, DateTime> deleted;

  const MergedPortfolio({
    required this.trades,
    required this.dividends,
    required this.deleted,
  });
}

/// Слияние чужого журнала со своим. Ни сети, ни диска — чтобы это можно было
/// проверить обычным тестом, а не «на живом сервере».
class PolarisMerge {
  static MergedPortfolio merge({
    required List<Trade> localTrades,
    required List<DividendPayout> localDividends,
    required Map<String, DateTime> localDeleted,
    required List<dynamic> remoteTrades,
    required List<dynamic> remoteDividends,
    required List<dynamic> remoteDeleted,
  }) {
    // ── Надгробия. Из двух одной записи оставляем ПОЗДНЕЕ (правило 3).
    final deleted = <String, DateTime>{...localDeleted};
    for (final raw in remoteDeleted) {
      if (raw is! Map) continue;
      final id = '${raw['id']}';
      final at = DateTime.tryParse('${raw['at']}')?.toUtc();
      if (at == null || id.isEmpty || id == 'null') continue;
      final was = deleted[id];
      if (was == null || at.isAfter(was)) deleted[id] = at;
    }

    // ── Сделки. Складываем по ГЛОБАЛЬНОМУ номеру, спор решает время ПРАВКИ.
    final tradesById = <String, Trade>{
      for (final t in localTrades)
        if (t.uid.isNotEmpty) t.uid: t,
    };
    for (final raw in remoteTrades) {
      final t = TradeWire.fromJson(raw);
      if (t == null) continue;
      final was = tradesById[t.uid];
      // Строго позже: при равенстве остаётся своё, иначе каждый обмен без
      // единой правки перетряхивал бы весь портфель.
      if (was == null || t.changed.toUtc().isAfter(was.changed.toUtc())) {
        tradesById[t.uid] = t;
      }
    }

    final divsById = <String, DividendPayout>{
      for (final d in localDividends)
        if (d.uid.isNotEmpty) d.uid: d,
    };
    for (final raw in remoteDividends) {
      final d = DividendWire.fromJson(raw);
      if (d == null) continue;
      final was = divsById[d.uid];
      if (was == null || d.changed.toUtc().isAfter(was.changed.toUtc())) {
        divsById[d.uid] = d;
      }
    }

    // ── Надгробие побеждает запись, если стёрли ПОЗЖЕ, чем правили.
    // Ровное равенство — в пользу удаления: устройство, ещё не знающее про
    // стирание, присылает старую копию с прежней отметкой и не должно её
    // воскрешать.
    bool zhiv(String uid, DateTime changed) {
      final grave = deleted[uid];
      return grave == null || grave.isBefore(changed.toUtc());
    }

    final trades = [
      for (final t in tradesById.values)
        if (zhiv(t.uid, t.changed)) t,
    ]..sort((a, b) => a.ts.compareTo(b.ts));
    final dividends = [
      for (final d in divsById.values)
        if (zhiv(d.uid, d.changed)) d,
    ]..sort((a, b) => a.ts.compareTo(b.ts));

    // Надгробия не копятся бесконечно: держим последние три тысячи ПО ВРЕМЕНИ,
    // а не по порядку появления, — иначе обрезка выбросила бы свежее надгробие
    // и воскресила стёртую сделку.
    final spisok = deleted.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final obrezannye = <String, DateTime>{
      for (final e in spisok.length > 3000
          ? spisok.sublist(spisok.length - 3000)
          : spisok)
        e.key: e.value,
    };

    return MergedPortfolio(
      trades: trades,
      dividends: dividends,
      deleted: obrezannye,
    );
  }

  /// Слияние прогресса обучения.
  ///
  /// Пройденные уроки СКЛАДЫВАЮТСЯ: урок, пройденный где угодно, считается
  /// пройденным. Это нарочно — забрать у человека уже пройденный урок хуже,
  /// чем засчитать лишний. Всё остальное решает время правки.
  ///
  /// [remote] не карта (склад промолчал или ответил мусором) — возвращаем
  /// местное как есть. Пустой ответ ничего не стирает (правило 4).
  static Map<String, dynamic> mergeLearn(
    Map<String, dynamic> local,
    Object? remote,
  ) {
    if (remote is! Map) return local;

    final completed = <String>{
      for (final id in (local['completed'] as List?) ?? const [])
        if (id is String) id,
      for (final id in (remote['completed'] as List?) ?? const [])
        if (id is String) id,
    };

    final quiz = <String, Map<String, dynamic>>{};
    void vlozhit(Object? src) {
      if (src is! Map) return;
      src.forEach((k, v) {
        if (k is! String || v is! Map) return;
        final novy = v.cast<String, dynamic>();
        final bylo = quiz[k];
        final tNovy = DateTime.tryParse('${novy['ts']}');
        final tBylo = bylo == null ? null : DateTime.tryParse('${bylo['ts']}');
        if (bylo == null ||
            (tNovy != null && (tBylo == null || tNovy.isAfter(tBylo)))) {
          quiz[k] = novy;
        }
      });
    }

    vlozhit(local['quizResults']);
    vlozhit(remote['quizResults']);

    final lastLocal = DateTime.tryParse('${local['lastLessonDate']}');
    final lastRemote = DateTime.tryParse('${remote['lastLessonDate']}');
    final DateTime? last;
    if (lastLocal == null) {
      last = lastRemote;
    } else if (lastRemote == null) {
      last = lastLocal;
    } else {
      last = lastRemote.isAfter(lastLocal) ? lastRemote : lastLocal;
    }

    final streakLocal = (local['currentStreak'] as num?)?.toInt() ?? 0;
    final streakRemote = (remote['currentStreak'] as num?)?.toInt() ?? 0;
    // Текущий стрик берём у того, кто занимался позже; при одной дате — больший.
    final int current;
    if (lastLocal != null && lastRemote != null && lastLocal != lastRemote) {
      current = lastRemote.isAfter(lastLocal) ? streakRemote : streakLocal;
    } else {
      current = streakLocal > streakRemote ? streakLocal : streakRemote;
    }

    final longLocal = (local['longestStreak'] as num?)?.toInt() ?? 0;
    final longRemote = (remote['longestStreak'] as num?)?.toInt() ?? 0;

    final chLocal = DateTime.tryParse('${local['changedAt']}');
    final chRemote = DateTime.tryParse('${remote['changedAt']}');
    final DateTime? changed;
    if (chLocal == null) {
      changed = chRemote;
    } else if (chRemote == null) {
      changed = chLocal;
    } else {
      changed = chRemote.isAfter(chLocal) ? chRemote : chLocal;
    }

    return {
      'completed': completed.toList()..sort(),
      'quizResults': quiz,
      if (last != null) 'lastLessonDate': last.toIso8601String(),
      'currentStreak': current,
      'longestStreak': longLocal > longRemote ? longLocal : longRemote,
      if (changed != null) 'changedAt': changed.toUtc().toIso8601String(),
    };
  }
}

/* ── Разговор со складом ───────────────────────────────────────────────────── */

/// Транспорт: отдаёт тело ответа строкой или бросает. Подменяется в тестах —
/// сеть в тестах не нужна. Тот же приём, что у [HttpGetFn] в `api.dart`.
typedef SyncPostFn = Future<String> Function(
    Uri uri, String body, Duration timeout);

Future<String> _ioPost(Uri uri, String body, Duration timeout) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client.postUrl(uri).timeout(timeout);
    // charset=utf-8 обязателен: без него русские названия приезжают на сервер
    // вопросительными знаками. На этом уже погибали воркфлоу.
    request.headers.contentType =
        ContentType('application', 'json', charset: 'utf-8');
    request.add(utf8.encode(body));
    final response = await request.close().timeout(timeout);
    final text = await utf8.decodeStream(response).timeout(timeout);
    if (response.statusCode >= 400) {
      throw ApiException(ApiErrorKind.http, 'Склад ответил ${response.statusCode}');
    }
    return text;
  } finally {
    client.close(force: true);
  }
}

class PolarisSyncClient {
  final PolarisSyncConfig config;
  final Duration timeout;
  final SyncPostFn _post;

  PolarisSyncClient({
    required this.config,
    this.timeout = const Duration(seconds: 30),
    SyncPostFn? post,
  }) : _post = post ?? _ioPost;

  bool get nastroen => config.nastroen;

  Future<Map<String, dynamic>?> _zapros(Map<String, dynamic> telo) async {
    final body = jsonEncode({'secret': config.secret, ...telo});
    final text = await _post(Uri.parse(config.url), body, timeout);
    final Object? j;
    try {
      j = jsonDecode(text);
    } on FormatException {
      return null;
    }
    // Ответ бывает объектом, а бывает СПИСКОМ из одного элемента — это зависит
    // от одной галочки в интерфейсе n8n. 09.08.2026 из-за неё молча перестал
    // работать обмен в Nexus. Разбираем оба вида.
    final one = j is List ? (j.isEmpty ? null : j.first) : j;
    if (one is! Map) return null;
    return one.cast<String, dynamic>();
  }

  /// Только прочитать склад, ничего не отправляя и не становясь «самым свежим
  /// устройством». Свежепоставленное приложение начинает именно с этого:
  /// отправь оно сначала свой пустой журнал — склад решил бы, что сделок
  /// не было ни одной.
  Future<Map<String, dynamic>?> read() => _zapros({'read': true});

  /// Отправить своё и забрать общее.
  Future<Map<String, dynamic>?> push({
    required String deviceId,
    required List<Trade> trades,
    required List<DividendPayout> dividends,
    required Map<String, DateTime> deleted,
    required Map<String, dynamic> learn,
  }) =>
      _zapros({
        'deviceId': deviceId,
        'at': DateTime.now().toUtc().toIso8601String(),
        'data': {
          'trades': [for (final t in trades) TradeWire.toJson(t)],
          'dividends': [for (final d in dividends) DividendWire.toJson(d)],
          'deleted': [
            for (final e in deleted.entries)
              {'id': e.key, 'at': e.value.toUtc().toIso8601String()},
          ],
          'learn': learn,
        },
      });

  /// Стереть общий склад — «начать с нуля». Местные данные не трогает.
  Future<bool> ochistit() async {
    final j = await _zapros({'reset': true});
    return j?['ok'] == true;
  }
}

/* ── Служба: решает КОГДА обмениваться и что делать с ответом ──────────────── */

/// Чем кончился обмен. Показывается человеку, поэтому здесь человеческие
/// слова, а не коды ошибок.
class SyncItog {
  final bool ok;

  /// Почему не вышло — уже человеческим языком.
  final String? beda;

  /// Сколько сделок в общем портфеле после обмена.
  final int sdelok;

  /// Обмен прошёл в режиме «только почитать»: чужое забрали, своё НЕ отправили.
  ///
  /// ⚠️ Экран обязан это показывать. В Tycha ровно на этом врала одна строчка:
  /// человек видел «Готово», считал, что его записи уже у всех, — а они уехали
  /// бы только при следующем запуске.
  final bool tolkoChitali;

  /// Сколько записей не удалось учесть в деньгах (продажа того, чего в журнале
  /// никогда не покупали). ⚠️ Сами записи НЕ выброшены — они в журнале.
  final int propushcheno;

  /// Насколько учебный счёт ушёл в минус после слияния: на двух устройствах
  /// потратили больше, чем было на одном счёте. 0 — всё сошлось.
  ///
  /// ⚠️ Экран обязан это показывать. Раньше лишняя покупка просто исчезала —
  /// и человеку писали «Готово».
  final int pererashodCents;

  /// Сколько покупок оказалось сверх счёта.
  final int sverhScheta;

  const SyncItog({
    required this.ok,
    this.beda,
    this.sdelok = 0,
    this.tolkoChitali = false,
    this.propushcheno = 0,
    this.pererashodCents = 0,
    this.sverhScheta = 0,
  });
}

const _deviceKey = 'polaris.device.v1';
const _lastSyncKey = 'polaris.sync.v1';

class PolarisSync extends ChangeNotifier {
  final PortfolioState portfolio;
  final LearnState learn;
  final StorageGateway storage;
  final PolarisSyncConfig config;
  final PolarisSyncClient Function(PolarisSyncConfig) makeClient;
  final DateTime Function() _now;

  /// Реже этого сами в сеть не ходим, что бы ни случилось.
  final Duration _minGap;

  PolarisSync({
    required this.portfolio,
    required this.learn,
    StorageGateway? storage,
    this.config = PolarisSyncConfig.izSborki,
    PolarisSyncClient Function(PolarisSyncConfig)? makeClient,
    Duration? minGap,
    DateTime Function()? now,
  })  : storage = storage ?? MemoryStorage(),
        makeClient =
            makeClient ?? ((c) => PolarisSyncClient(config: c)),
        _minGap = minGap ?? const Duration(minutes: 2),
        _now = now ?? DateTime.now;

  bool _busy = false;
  bool get busy => _busy;

  DateTime? lastOk;
  String? beda;
  DateTime? _lastTry;
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

  /// Обмен вообще включён (есть адрес и ключ). Нет ключа — молча выключен,
  /// и приложение работает ровно как раньше.
  bool get vklyuchen => config.nastroen;

  /// Постоянное имя ЭТОГО устройства. Из него собираются глобальные номера
  /// сделок, поэтому оно обязано пережить перезапуск: сгенерировать новое
  /// значит отправить на склад все свои сделки заново, дубликатами.
  Future<String?> deviceId() async {
    Map<String, dynamic>? snap;
    try {
      snap = await storage.readJson(_deviceKey);
    } catch (_) {
      return null;
    }
    final saved = snap?['id'];
    if (saved is String && saved.isNotEmpty) return saved;
    final novy = 'plr-${_now().microsecondsSinceEpoch.toRadixString(36)}'
        '-${Random().nextInt(1 << 32).toRadixString(36)}';
    try {
      await storage.writeJson(_deviceKey, {'id': novy});
    } catch (_) {
      // Имя не записалось — обмениваться нельзя: при следующем запуске имя
      // будет другим, и склад получит те же сделки второй раз.
      return null;
    }
    return novy;
  }

  Future<DateTime?> _lastSync() async {
    try {
      final snap = await storage.readJson(_lastSyncKey);
      return DateTime.tryParse('${snap?['at']}');
    } catch (_) {
      return null;
    }
  }

  /// Первый обмен после запуска приложения.
  Future<void> start() async {
    if (!vklyuchen) return;
    lastOk = await _lastSync();
    notifyListeners();
    final itog = await sync();
    // Первый раз в жизни мы только ЧИТАЛИ. Но если свои сделки уже есть,
    // отдать их надо сразу же, а не ждать следующего запуска: склад нам уже
    // известен, затереть чужое мы больше не можем.
    if (itog.ok && itog.tolkoChitali && portfolio.trades.isNotEmpty) {
      await sync(force: true);
    }
  }

  /// Обмен. [force] — нажали кнопку руками, паузу не выдерживаем.
  Future<SyncItog> sync({bool force = false}) async {
    if (!vklyuchen) {
      return const SyncItog(ok: false, beda: 'обмен не настроен');
    }
    if (_busy) return const SyncItog(ok: false, beda: 'обмен уже идёт');

    // ⚠️ Портфель прочитался не полностью — не обмениваемся ВООБЩЕ.
    // Отправить половину журнала значит попросить склад забыть вторую.
    if (!portfolio.loaded) {
      return const SyncItog(ok: false, beda: 'портфель ещё не загружен');
    }
    if (portfolio.snapshotBityy) {
      return const SyncItog(
          ok: false, beda: 'портфель на устройстве прочитался не полностью');
    }
    if (learn.loadFailed) {
      return const SyncItog(
          ok: false, beda: 'прогресс обучения прочитался не полностью');
    }

    final last = _lastTry;
    if (!force && last != null && _now().difference(last) < _minGap) {
      return const SyncItog(ok: false, beda: 'обменяемся чуть позже');
    }

    final imya = await deviceId();
    if (imya == null) {
      return const SyncItog(
          ok: false, beda: 'устройство не смогло запомнить своё имя');
    }
    // Разметка глобальными номерами — обязательное условие. Без неё «сделка
    // №1» с телефона склеилась бы со «сделкой №1» с ноутбука.
    if (!await portfolio.podgotovitUid(imya)) {
      return const SyncItog(
          ok: false, beda: 'не удалось раздать сделкам общие номера');
    }

    _busy = true;
    _lastTry = _now();
    notifyListeners();
    try {
      final client = makeClient(config);
      final pervyRaz = await _lastSync() == null;
      final otvet = pervyRaz
          ? await client.read()
          : await client.push(
              deviceId: imya,
              trades: portfolio.trades,
              dividends: portfolio.dividends,
              deleted: portfolio.deletedUids,
              learn: learn.slepokDlyaObmena(),
            );

      final data = otvet?['data'];
      // ⚠️ Правило 4. Непонятный ответ НЕ ТРОГАЕТ местные данные вообще.
      // «Склад пуст» приезжает как ok:true с пустыми списками — вот это
      // применять можно и нужно, оно ничего не стирает.
      if (otvet?['ok'] != true || data is! Map) {
        beda = 'склад ответил непонятно';
        return SyncItog(ok: false, beda: beda);
      }

      final merged = PolarisMerge.merge(
        localTrades: portfolio.trades,
        localDividends: portfolio.dividends,
        localDeleted: portfolio.deletedUids,
        remoteTrades: (data['trades'] as List?) ?? const [],
        remoteDividends: (data['dividends'] as List?) ?? const [],
        remoteDeleted: (data['deleted'] as List?) ?? const [],
      );

      final prinyato = await portfolio.primenitSliyanie(
        trades: merged.trades,
        dividends: merged.dividends,
        deleted: merged.deleted,
      );
      if (!prinyato) {
        beda = 'портфель не записался на устройство';
        return SyncItog(ok: false, beda: beda);
      }

      // Прогресс обучения — отдельной записью, но по тем же правилам.
      // Если он не записался, портфель уже применён — но молчать нельзя:
      // человек решит, что пройденные уроки уже на обоих устройствах.
      var uchebaZapisalas = true;
      if (!learn.loadFailed) {
        uchebaZapisalas = await learn.primenitSliyanie(
          PolarisMerge.mergeLearn(learn.slepokDlyaObmena(), data['learn']),
        );
      }

      final teper = _now();
      try {
        await storage.writeJson(_lastSyncKey, {'at': teper.toIso8601String()});
      } catch (_) {
        // Отметку не записали — не беда: в худшем случае следующий запуск
        // снова начнёт с чтения, а чтение безопасно.
      }
      lastOk = teper;
      beda = uchebaZapisalas ? null : 'прогресс обучения не записался на устройство';
      return SyncItog(
        ok: uchebaZapisalas,
        beda: beda,
        sdelok: merged.trades.length,
        tolkoChitali: pervyRaz,
        propushcheno: portfolio.propushchenoPriSliyanii,
        pererashodCents: portfolio.pererashodCents,
        sverhScheta: portfolio.sdelkiSverhScheta.length,
      );
    } catch (e) {
      beda = poChelovecheski(e);
      return SyncItog(ok: false, beda: beda);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Ошибка человеческим языком. Нет сети — это не поломка, а обычная жизнь
  /// телефона, и говорить об этом надо спокойно.
  static String poChelovecheski(Object e) {
    final t = '$e';
    if (t.contains('TimeoutException')) return 'сервер не ответил вовремя';
    if (t.contains('SocketException') || t.contains('Failed host lookup')) {
      return 'нет связи с сервером';
    }
    if (t.contains('401') || t.contains('403') || t.contains('forbidden')) {
      return 'склад не принял ключ';
    }
    return t.length > 120 ? '${t.substring(0, 120)}…' : t;
  }

  /// Что написать человеку после обмена — на его языке ('ru' | 'en' | 'es').
  ///
  /// Отдельной функцией нарочно: экран, который смотрит только на «получилось
  /// или нет», уже один раз соврал в Tycha — писал «Готово» там, где своё
  /// никуда не уехало.
  static String itogTekstom(SyncItog itog, String lang) {
    if (!itog.ok) {
      final beda = itog.beda ?? '—';
      return switch (lang) {
        'ru' => 'Обмен не прошёл: $beda',
        'es' => 'No se sincronizó: $beda',
        _ => 'Sync failed: $beda',
      };
    }
    // ⚠️ Хвост говорит ПРЯМО и никогда не молчит о том, что не сошлось.
    // Раньше здесь была одна строчка «Сделок не сложилось: 1» — и она врала
    // дважды: не называла бумагу и умалчивала, что запись выброшена навсегда.
    // Теперь не выбрасывается ничего, и текст объясняет, что именно случилось.
    var hvost = '';
    if (itog.pererashodCents > 0) {
      final summa = (itog.pererashodCents / 100).toStringAsFixed(2);
      hvost += switch (lang) {
        'ru' => ' На двух устройствах ты потратил больше, чем было на счёте: '
            'минус \$$summa (покупок сверх счёта: ${itog.sverhScheta}). '
            'Ничего не выброшено — лишние сделки можно убрать в «Портфеле».',
        'es' => ' Gastaste más de lo que había en la cuenta: '
            'menos \$$summa (compras por encima del saldo: ${itog.sverhScheta}). '
            'No se descartó nada: puedes quitar las de más en «Cartera».',
        _ => ' You spent more across devices than the account had: '
            'minus \$$summa (purchases over balance: ${itog.sverhScheta}). '
            'Nothing was dropped — you can remove the extra ones in Portfolio.',
      };
    }
    if (itog.propushcheno > 0) {
      hvost += switch (lang) {
        'ru' => ' Записей, которые не удалось учесть в деньгах: '
            '${itog.propushcheno} — они сохранены в истории, ничего не потеряно.',
        'es' => ' Registros no aplicados al saldo: '
            '${itog.propushcheno}; se conservan en el historial.',
        _ => ' Records not applied to cash: '
            '${itog.propushcheno} — kept in history, nothing lost.',
      };
    }
    if (itog.tolkoChitali) {
      return switch (lang) {
            'ru' => 'Забрал общие данные (сделок: ${itog.sdelok}). '
                'Свои отправлю следующим обменом.',
            'es' => 'Datos recibidos (operaciones: ${itog.sdelok}). '
                'Los míos se enviarán en el próximo intercambio.',
            _ => 'Got shared data (trades: ${itog.sdelok}). '
                'Mine will be sent on the next sync.',
          } +
          hvost;
    }
    return switch (lang) {
          'ru' => 'Готово. Сделок в общем портфеле: ${itog.sdelok}.',
          'es' => 'Listo. Operaciones en la cartera común: ${itog.sdelok}.',
          _ => 'Done. Trades in the shared portfolio: ${itog.sdelok}.',
        } +
        hvost;
  }
}
