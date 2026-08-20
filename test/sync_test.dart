/// Синхронизация Polaris: ноутбук ↔ телефон ↔ Финансист.
///
/// Сети здесь нет ни одной: склад подменён поддельным (`_Sklad`), который
/// повторяет логику воркфлоу n8n `polaris-sync` один в один. Значит тесты
/// ловят ровно то, что ломается тихо, а не «интернет отвалился».
///
/// Что здесь закрыто (все три беды — из прошлого опыта, не выдуманные):
///  1. Местный номер сделки на разных устройствах означает РАЗНЫЕ сделки.
///     Синхронизировать по нему — склеить чужое и потерять половину (Dayo).
///  2. Спор двух копий решает время ПРАВКИ, а не время отправки. Иначе
///     телефон из кармана затрёт свежую правку с ноутбука — молча.
///  3. Пустой или непонятный ответ склада не смеет трогать местные данные
///     (на этом чинили Fluxo и Polaris 10.08.2026).
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/models/models.dart';
import 'package:polaris/services/storage.dart';
import 'package:polaris/services/sim_engine.dart';
import 'package:polaris/services/sync.dart';
import 'package:polaris/state/learn_state.dart';
import 'package:polaris/state/portfolio_state.dart';

/* ── Поддельный склад: то же, что делает воркфлоу n8n ───────────────────────── */

class _Sklad {
  Map<String, dynamic> data = {
    'trades': <dynamic>[],
    'dividends': <dynamic>[],
    'deleted': <dynamic>[],
  };

  /// Сколько раз к складу обращались (и последнее тело запроса).
  int zaprosov = 0;
  Map<String, dynamic>? posledniy;

  /// Что склад ответит вместо нормального ответа. null — работает как обычно.
  String? podmena;

  /// Бросить исключение вместо ответа (нет сети).
  bool padat = false;

  int _kogda(Object? s) => DateTime.tryParse('$s')?.millisecondsSinceEpoch ?? 0;

  Future<String> post(Uri uri, String body, Duration timeout) async {
    zaprosov++;
    if (padat) throw Exception('SocketException: сети нет');
    final telo = jsonDecode(body) as Map<String, dynamic>;
    posledniy = telo;
    if (podmena != null) return podmena!;

    if (telo['read'] == true) {
      return jsonEncode({'ok': true, 'read': true, 'data': data});
    }
    if (telo['reset'] == true) {
      data = {'trades': [], 'dividends': [], 'deleted': []};
      return jsonEncode({'ok': true, 'reset': true, 'data': data});
    }

    final vhod = (telo['data'] as Map?) ?? const {};

    // Надгробия: из двух одной записи остаётся ПОЗДНЕЕ.
    final mogily = <String, Map<String, dynamic>>{};
    for (final list in [data['deleted'], vhod['deleted']]) {
      for (final e in (list as List? ?? const [])) {
        if (e is! Map) continue;
        final id = '${e['id']}';
        if (id.isEmpty || id == 'null') continue;
        if (mogily[id] == null || _kogda(e['at']) > _kogda(mogily[id]!['at'])) {
          mogily[id] = e.cast<String, dynamic>();
        }
      }
    }

    Map<String, Map<String, dynamic>> slozhit(String kluch) {
      final out = <String, Map<String, dynamic>>{};
      for (final list in [data[kluch], vhod[kluch]]) {
        for (final e in (list as List? ?? const [])) {
          if (e is! Map) continue;
          final id = '${e['id']}';
          if (id.isEmpty || id == 'null') continue;
          final bylo = out[id];
          // Строго больше: при равенстве остаётся тот, кто уже лежал.
          if (bylo == null ||
              _kogda(e['changedAt']) > _kogda(bylo['changedAt'])) {
            out[id] = e.cast<String, dynamic>();
          }
        }
      }
      return out;
    }

    List<dynamic> zhivye(Map<String, Map<String, dynamic>> vse) => [
          for (final e in vse.values)
            if (mogily['${e['id']}'] == null ||
                _kogda(mogily['${e['id']}']!['at']) < _kogda(e['changedAt']))
              e,
        ];

    final learnBylo = data['learn'];
    final learnStal = vhod['learn'];
    data = {
      'trades': zhivye(slozhit('trades')),
      'dividends': zhivye(slozhit('dividends')),
      'deleted': mogily.values.toList(),
      // Прогресс обучения — одна запись, спор решает время правки.
      'learn': (learnBylo is Map && learnStal is Map)
          ? (_kogda(learnStal['changedAt']) >= _kogda(learnBylo['changedAt'])
              ? learnStal
              : learnBylo)
          : (learnStal ?? learnBylo),
    };
    return jsonEncode({'ok': true, 'data': data});
  }
}

/* ── Одно «устройство» целиком ─────────────────────────────────────────────── */

class _Ustroystvo {
  final MemoryStorage storage;
  final PortfolioState portfolio;
  final LearnState learn;
  final PolarisSync sync;

  _Ustroystvo._(this.storage, this.portfolio, this.learn, this.sync);

  static Future<_Ustroystvo> sozdat(
    _Sklad sklad, {
    Map<String, Map<String, dynamic>>? seed,
    String secret = 'TEST-SECRET',
    DateTime Function()? now,
  }) async {
    final storage = MemoryStorage(seed ?? <String, Map<String, dynamic>>{});
    final portfolio = PortfolioState(storage: storage, now: now);
    final learn = LearnState(storage: storage, now: now);
    await portfolio.load();
    await learn.load();
    final sync = PolarisSync(
      portfolio: portfolio,
      learn: learn,
      storage: storage,
      config: PolarisSyncConfig(
          url: 'https://test.local/webhook/polaris-sync', secret: secret),
      makeClient: (c) => PolarisSyncClient(config: c, post: sklad.post),
      minGap: Duration.zero,
    );
    return _Ustroystvo._(storage, portfolio, learn, sync);
  }

  /// Полный обмен: первый раз склад только читают, поэтому зовём дважды —
  /// как это делает `start()` в настоящем приложении.
  Future<SyncItog> obmen() async {
    final pervy = await sync.sync(force: true);
    if (pervy.ok && pervy.tolkoChitali) return sync.sync(force: true);
    return pervy;
  }
}

void main() {
  const cena = 10000; // $100.00 за штуку

  group('Ловушка 1: местные номера на разных устройствах — разные сделки', () {
    test('«сделка №1» с ноутбука и «сделка №1» с телефона не склеиваются',
        () async {
      final sklad = _Sklad();
      final noutbuk = await _Ustroystvo.sozdat(sklad);
      final telefon = await _Ustroystvo.sozdat(sklad);

      await noutbuk.sync.sync(force: true); // раздали uid и прочитали склад
      await telefon.sync.sync(force: true);

      await noutbuk.portfolio.buy('AAPL', 100000, cena);
      await telefon.portfolio.buy('MSFT', 200000, cena);

      // Местный номер у обеих сделок ОДИНАКОВЫЙ — вот она, ловушка.
      expect(noutbuk.portfolio.trades.single.id, 't1');
      expect(telefon.portfolio.trades.single.id, 't1');
      // А глобальный — разный.
      expect(noutbuk.portfolio.trades.single.uid,
          isNot(telefon.portfolio.trades.single.uid));

      await noutbuk.obmen();
      await telefon.obmen();
      await noutbuk.obmen();

      // Обе сделки живы у обоих. Если бы синхронизировали по местному номеру,
      // осталась бы одна, и вторая исчезла бы навсегда.
      expect(noutbuk.portfolio.trades.length, 2);
      expect(telefon.portfolio.trades.length, 2);
      expect(noutbuk.portfolio.positions.keys.toSet(), {'AAPL', 'MSFT'});
      expect(telefon.portfolio.positions.keys.toSet(), {'AAPL', 'MSFT'});
      // Деньги посчитаны из событий и совпадают на обоих устройствах.
      expect(noutbuk.portfolio.cashCents, telefon.portfolio.cashCents);
      expect(noutbuk.portfolio.cashCents, startingCashCents - 300000);
    });

    test('старым сделкам глобальный номер выдаёт миграция — и он переживает '
        'перезапуск', () async {
      // Портфель «как у человека до обновления»: местные номера есть,
      // глобальных нет.
      final staryy = <String, Map<String, dynamic>>{
        'polaris.portfolio.v1': {
          'engine': {
            'cashCents': 900000,
            'seq': 1,
            'positions': [
              {'symbol': 'AAPL', 'qty': 10.0, 'costCents': 100000}
            ],
            'trades': [
              {
                'id': 't1',
                'symbol': 'AAPL',
                'side': 'buy',
                'qty': 10.0,
                'priceCents': cena,
                'totalCents': 100000,
                'ts': '2026-08-01T10:00:00.000',
                'realizedPnlCents': 0,
              }
            ],
            'dividends': <dynamic>[],
          },
        },
      };

      final sklad = _Sklad();
      final d = await _Ustroystvo.sozdat(sklad, seed: staryy);
      expect(d.portfolio.trades.single.uid, '', reason: 'до миграции пусто');
      expect(d.portfolio.gotovKObmenu, isFalse);

      final itog = await d.sync.sync(force: true);
      expect(itog.ok, isTrue, reason: 'обмен должен был пройти: ${itog.beda}');
      final uid = d.portfolio.trades.single.uid;
      expect(uid, isNotEmpty);
      expect(d.portfolio.gotovKObmenu, isTrue);

      // Перезапуск: номер тот же самый. Иначе одна сделка уехала бы на склад
      // дважды и портфель раздвоился бы.
      final posle = PortfolioState(storage: d.storage);
      await posle.load();
      expect(posle.trades.single.uid, uid);
    });
  });

  group('Ловушка 2: побеждает та копия, что позже ПРАВИЛАСЬ', () {
    test('старая копия сделки не затирает свежую, даже если приехала позже',
        () {
      final svezhaya = Trade(
        id: 't1',
        uid: 'tr_x_1',
        symbol: 'AAPL',
        side: TradeSide.buy,
        qty: 1,
        priceCents: cena,
        totalCents: cena,
        ts: DateTime(2026, 8, 1),
        changedAt: DateTime.utc(2026, 8, 9), // правили ПОЗЖЕ
      );
      final staraya = {
        'id': 'tr_x_1',
        'symbol': 'AAPL',
        'side': 'buy',
        'qty': 1,
        'priceCents': cena,
        'totalCents': 55555, // если победит она — сумма будет эта
        'ts': '2026-08-01T00:00:00.000Z',
        'changedAt': '2026-08-02T00:00:00.000Z', // правили РАНЬШЕ
      };

      final itog = PolarisMerge.merge(
        localTrades: [svezhaya],
        localDividends: const [],
        localDeleted: const {},
        remoteTrades: [staraya],
        remoteDividends: const [],
        remoteDeleted: const [],
      );

      expect(itog.trades.single.totalCents, cena,
          reason: 'осталась та копия, которую правили позже');
    });

    test('прогресс обучения: телефон из кармана не откатывает ноутбук', () {
      final noutbuk = {
        'completed': ['l1', 'l2', 'l3'],
        'quizResults': <String, dynamic>{},
        'lastLessonDate': '2026-08-09T00:00:00.000',
        'currentStreak': 3,
        'longestStreak': 3,
        'changedAt': '2026-08-09T12:00:00.000Z',
      };
      final telefon = {
        'completed': ['l1'],
        'quizResults': <String, dynamic>{},
        'lastLessonDate': '2026-08-02T00:00:00.000',
        'currentStreak': 1,
        'longestStreak': 1,
        // Телефон ВКЛЮЧИЛИ последним, но занимались на нём неделю назад.
        'changedAt': '2026-08-02T09:00:00.000Z',
      };

      final itog = PolarisMerge.mergeLearn(noutbuk, telefon);
      expect(itog['completed'], ['l1', 'l2', 'l3']);
      expect(itog['currentStreak'], 3);
      expect(itog['longestStreak'], 3);
      expect(itog['lastLessonDate'], '2026-08-09T00:00:00.000');
    });
  });

  group('Ловушка 3: пустой или непонятный ответ ничего не стирает', () {
    late _Sklad sklad;
    late _Ustroystvo d;

    setUp(() async {
      sklad = _Sklad();
      d = await _Ustroystvo.sozdat(sklad);
      await d.sync.sync(force: true);
      await d.portfolio.buy('AAPL', 100000, cena);
      await d.obmen();
      expect(d.portfolio.trades, hasLength(1));
    });

    test('склад ответил мусором — местный портфель цел, и это сказано вслух',
        () async {
      sklad.podmena = 'это вообще не json';
      final itog = await d.sync.sync(force: true);
      expect(itog.ok, isFalse);
      expect(itog.beda, isNotNull);
      expect(d.portfolio.trades, hasLength(1));
      expect(d.portfolio.cashCents, startingCashCents - 100000);
    });

    test('склад ответил «не получилось» — ничего не применяем', () async {
      sklad.podmena = jsonEncode({'error': 'forbidden'});
      final itog = await d.sync.sync(force: true);
      expect(itog.ok, isFalse);
      expect(d.portfolio.trades, hasLength(1));
    });

    test('склад ответил ok, но без данных — местное на месте', () async {
      sklad.podmena = jsonEncode({'ok': true});
      final itog = await d.sync.sync(force: true);
      expect(itog.ok, isFalse, reason: '«нет данных» — это не успех');
      expect(d.portfolio.trades, hasLength(1));
    });

    test('склад ПУСТ (честный ok с пустыми списками) — свои сделки не пропали',
        () async {
      sklad.podmena =
          jsonEncode({'ok': true, 'data': {'trades': [], 'dividends': [], 'deleted': []}});
      final itog = await d.sync.sync(force: true);
      expect(itog.ok, isTrue);
      expect(d.portfolio.trades, hasLength(1),
          reason: 'пустой склад не значит «сделок не было»');
    });

    test('нет сети — портфель цел, беда названа по-человечески', () async {
      sklad.padat = true;
      final itog = await d.sync.sync(force: true);
      expect(itog.ok, isFalse);
      expect(itog.beda, 'нет связи с сервером');
      expect(d.portfolio.trades, hasLength(1));
    });

    test('портфель на устройстве прочитался не полностью — в сеть не идём',
        () async {
      final sklad2 = _Sklad();
      final storage = MemoryStorage();
      final portfolio = _BityyPortfel(storage: storage);
      await portfolio.load();
      final learn = LearnState(storage: storage);
      await learn.load();
      final sync = PolarisSync(
        portfolio: portfolio,
        learn: learn,
        storage: storage,
        config: const PolarisSyncConfig(
            url: 'https://test.local/x', secret: 'TEST-SECRET'),
        makeClient: (c) => PolarisSyncClient(config: c, post: sklad2.post),
        minGap: Duration.zero,
      );
      final itog = await sync.sync(force: true);
      expect(itog.ok, isFalse);
      expect(sklad2.zaprosov, 0,
          reason: 'отправить половину журнала = попросить забыть вторую');
    });
  });

  test('прогресс обучения не записался — обмен НЕ выдаёт себя за удачный',
      () async {
    // Молчание тут стоит человеку уверенности, что пройденные уроки уже на
    // обоих устройствах. Портфель при этом применён — так и говорим.
    final sklad = _Sklad();
    final storage = _UchebaNePishetsya();
    final portfolio = PortfolioState(storage: storage);
    final learn = LearnState(storage: storage);
    await portfolio.load();
    await learn.load();
    final sync = PolarisSync(
      portfolio: portfolio,
      learn: learn,
      storage: storage,
      config: const PolarisSyncConfig(
          url: 'https://test.local/x', secret: 'TEST-SECRET'),
      makeClient: (c) => PolarisSyncClient(config: c, post: sklad.post),
      minGap: Duration.zero,
    );

    await sync.sync(force: true); // первый раз только читаем
    final itog = await sync.sync(force: true);
    expect(itog.ok, isFalse);
    expect(itog.beda, contains('обучения'));
  });

  group('Дивиденды и «начать заново»', () {
    test('один дивиденд, начисленный на двух устройствах, не удваивается',
        () async {
      final sklad = _Sklad();
      // Часы двигаем руками: бумагу надо КУПИТЬ до отсечки, иначе приложение
      // (правильно) откажется начислять дивиденд за чужой период.
      var chas = DateTime(2026, 8, 1);
      final noutbuk = await _Ustroystvo.sozdat(sklad, now: () => chas);
      final telefon = await _Ustroystvo.sozdat(sklad, now: () => chas);
      await noutbuk.sync.sync(force: true);
      await telefon.sync.sync(force: true);

      // Оба держат одну бумагу и оба сами начислили ОДНУ И ТУ ЖЕ выплату.
      for (final d in [noutbuk, telefon]) {
        await d.portfolio.buy('AAPL', 100000, cena);
      }
      chas = DateTime(2026, 8, 10);
      for (final d in [noutbuk, telefon]) {
        await d.portfolio.applyDueDividends([
          DividendDue(
              symbol: 'AAPL', perShareCents: 50, exDate: DateTime(2026, 8, 8)),
        ]);
        expect(d.portfolio.dividends, hasLength(1));
      }
      expect(noutbuk.portfolio.dividends.single.uid,
          telefon.portfolio.dividends.single.uid,
          reason: 'номер выплаты нарочно одинаков на всех устройствах');

      await noutbuk.obmen();
      await telefon.obmen();
      await noutbuk.obmen();

      expect(noutbuk.portfolio.dividends, hasLength(1),
          reason: 'две копии одной выплаты обязаны слиться в одну');
      expect(noutbuk.portfolio.dividendsTotalCents,
          telefon.portfolio.dividendsTotalCents);
    });

    test('«начать заново» не отменяется обменом', () async {
      final sklad = _Sklad();
      final noutbuk = await _Ustroystvo.sozdat(sklad);
      await noutbuk.sync.sync(force: true);
      await noutbuk.portfolio.buy('AAPL', 100000, cena);
      await noutbuk.obmen();
      expect((sklad.data['trades'] as List), hasLength(1));

      await noutbuk.portfolio.reset();
      expect(noutbuk.portfolio.trades, isEmpty);

      await noutbuk.obmen();
      expect(noutbuk.portfolio.trades, isEmpty,
          reason: 'стёртый портфель не должен приезжать обратно со склада');
      expect(noutbuk.portfolio.cashCents, startingCashCents);
      expect((sklad.data['deleted'] as List), hasLength(1));
    });
  });

  group('Пересборка портфеля из событий', () {
    test('деньги и позиции те же, что были', () async {
      final storage = MemoryStorage();
      final p = PortfolioState(storage: storage);
      await p.load();
      await p.podgotovitUid('test-device');
      await p.buy('AAPL', 300000, cena);
      await p.sell('AAPL', 10, 12000);
      await p.buy('MSFT', 100000, cena);

      final itog = SimEngine.fromEvents(
        trades: p.trades,
        dividends: p.dividends,
      );
      expect(itog.propushcheno, 0);
      expect(itog.engine.cashCents, p.cashCents);
      expect(itog.engine.positions['AAPL']!.qty, p.positions['AAPL']!.qty);
      expect(itog.engine.positions['MSFT']!.costCents,
          p.positions['MSFT']!.costCents);
    });

    test('запись, которую нельзя учесть в деньгах, ОСТАЁТСЯ в журнале', () {
      final t = Trade(
        id: '',
        uid: 'tr_x_1',
        symbol: 'AAPL',
        side: TradeSide.sell, // продажа бумаги, которой никогда не было
        qty: 5,
        priceCents: cena,
        totalCents: 50000,
        ts: DateTime(2026, 8, 1),
      );
      final itog = SimEngine.fromEvents(trades: [t], dividends: const []);
      expect(itog.propushcheno, 1);
      expect(itog.engine.cashCents, startingCashCents,
          reason: 'деньги из воздуха не берутся');
      // ⚠️ Раньше здесь стояло `expect(itog.engine.trades, isEmpty)` — то есть
      // запись ВЫБРАСЫВАЛАСЬ. Так и терялись данные. Теперь она в журнале,
      // просто помечена «не применена».
      expect(itog.engine.trades, hasLength(1),
          reason: 'из журнала не выбрасывается ничего');
      expect(itog.engine.trades.single.uid, 'tr_x_1');
      expect(itog.engine.trades.single.primenena, isFalse);
    });
  });

  group('Без ключа обмена нет вовсе', () {
    test('пустой секрет — мост выключен и в сеть не ходит', () async {
      final sklad = _Sklad();
      final d = await _Ustroystvo.sozdat(sklad, secret: '');
      expect(d.sync.vklyuchen, isFalse);
      await d.sync.start();
      final itog = await d.sync.sync(force: true);
      expect(itog.ok, isFalse);
      expect(sklad.zaprosov, 0);
    });

    test('в коде секрета нет — только из сборки', () {
      // Тесты идут без --dart-define, значит ключа быть не должно.
      expect(PolarisSyncConfig.izSborki.secret, isEmpty);
      expect(PolarisSyncConfig.izSborki.nastroen, isFalse);
    });
  });

  group('Что видит человек', () {
    test('«только почитал» не выдаётся за «всё отправлено»', () {
      final tekst = PolarisSync.itogTekstom(
          const SyncItog(ok: true, sdelok: 3, tolkoChitali: true), 'ru');
      expect(tekst, contains('следующим обменом'));
      expect(tekst, isNot(contains('Готово')));
    });

    test('пропавшие сделки названы вслух', () {
      final tekst = PolarisSync.itogTekstom(
          const SyncItog(ok: true, sdelok: 5, propushcheno: 2), 'ru');
      expect(tekst, contains('2'));
    });
  });
}

/// Портфель, который «прочитался не полностью». Настоящий флаг ставит
/// [PrefsStorage], в тестах его подменяем наследником.
class _BityyPortfel extends PortfolioState {
  _BityyPortfel({required super.storage});

  @override
  bool get snapshotBityy => true;
}

/// Хранилище, у которого не пишется ИМЕННО прогресс обучения.
class _UchebaNePishetsya extends MemoryStorage {
  @override
  Future<void> writeJson(String key, Map<String, dynamic> value) async {
    if (key == 'polaris.learn.v1') throw Exception('диск сказал «нет»');
    return super.writeJson(key, value);
  }
}
