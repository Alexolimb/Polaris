/// ДВА ПУТИ, НА КОТОРЫХ ДАННЫЕ ПРОПАДАЛИ МОЛЧА.
///
/// Оба опыта поставил независимый скептик, оба воспроизведены здесь один в один
/// с теми же числами. Сети тут нет: склад подменён поддельным, который делает
/// ровно то же, что воркфлоу n8n `polaris-sync`.
///
/// ── ПУТЬ 1. Сделка, на которую «не хватило денег», выбрасывалась навсегда ────
/// Два устройства, на каждом человек потратил по 6000 из своих 10 000: ноутбук
/// купил AAPL и MSFT, телефон — TSLA и NVDA. После обмена покупка NVDA
/// ИСЧЕЗАЛА: ни в позициях, ни в истории, ни в файле на диске (было 4 записи,
/// стало 3). Человеку писали только «Сделок не сложилось: 1» — какая именно и
/// что пропала целая бумага, не говорили, кнопки «вернуть» не было.
/// Причина: портфель после обмена не дополнялся, а СОБИРАЛСЯ ЗАНОВО с чистых
/// 10 000, а потрачено было с ДВУХ разных счетов по 10 000.
///
/// ── ПУТЬ 2. Одна битая строчка внутри целого файла стоила целой бумаги ──────
/// Файл читается, а у ОДНОЙ сделки одно поле битое. До обмена всё правильно:
/// AAPL, MSFT, TSLA, деньги на месте, флаг «прочиталось не полностью» НЕ поднят
/// — значит в сеть идти разрешено. После обмена позиция MSFT (20 бумаг на 2000)
/// ИСЧЕЗАЛА, деньги пересчитывались, «пропущено: 0», надпись «Готово».
///
/// ── ПУТЬ 3. Кнопка «Убрать» стирала битую запись и снимала запрет ───────────
/// Тот же файл с битой строчкой MSFT, и одновременно в нём лежит сохранённый
/// список «сверх счёта» с покупкой AAPL — значит на Портфеле горят ОБЕ красные
/// плашки сразу и кнопка «Убрать» живая. Одно нажатие на AAPL — и движок
/// пересобирался из журнала ЧИСТЫМ: единственная копия битой записи, из которой
/// её ещё можно было вытащить руками, стиралась навсегда, запрет на обмен
/// опускался САМ СОБОЙ, и приложение спокойно уходило на склад
/// («Готово. Сделок в общем портфеле: 1»). Человеку не говорили ни слова.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/models/models.dart';
import 'package:polaris/services/sim_engine.dart';
import 'package:polaris/services/storage.dart';
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

  int zaprosov = 0;

  int _kogda(Object? s) => DateTime.tryParse('$s')?.millisecondsSinceEpoch ?? 0;

  Future<String> post(Uri uri, String body, Duration timeout) async {
    zaprosov++;
    final telo = jsonDecode(body) as Map<String, dynamic>;

    if (telo['read'] == true) {
      return jsonEncode({'ok': true, 'read': true, 'data': data});
    }

    final vhod = (telo['data'] as Map?) ?? const {};

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

    data = {
      'trades': zhivye(slozhit('trades')),
      'dividends': zhivye(slozhit('dividends')),
      'deleted': mogily.values.toList(),
      'learn': vhod['learn'] ?? data['learn'],
    };
    return jsonEncode({'ok': true, 'data': data});
  }
}

/// Часы, которые идут вперёд сами: порядок событий обязан быть определённым,
/// иначе тест «то падает, то нет».
class _Chasy {
  DateTime _t;
  _Chasy(this._t);
  DateTime call() {
    _t = _t.add(const Duration(minutes: 1));
    return _t;
  }
}

class _Ustroystvo {
  final MemoryStorage storage;
  final PortfolioState portfolio;
  final LearnState learn;
  final PolarisSync sync;

  _Ustroystvo._(this.storage, this.portfolio, this.learn, this.sync);

  static Future<_Ustroystvo> sozdat(
    _Sklad sklad, {
    Map<String, Map<String, dynamic>>? seed,
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
      config: const PolarisSyncConfig(
          url: 'https://test.local/webhook/polaris-sync', secret: 'TEST-SECRET'),
      makeClient: (c) => PolarisSyncClient(config: c, post: sklad.post),
      minGap: Duration.zero,
    );
    return _Ustroystvo._(storage, portfolio, learn, sync);
  }

  /// Полный обмен: первый раз склад только читают, поэтому зовём дважды.
  Future<SyncItog> obmen() async {
    final pervy = await sync.sync(force: true);
    if (pervy.ok && pervy.tolkoChitali) return sync.sync(force: true);
    return pervy;
  }

  /// Что лежит на диске у этого устройства — именно то, что переживёт
  /// перезапуск. Скептик проверял ИМЕННО файл, а не экран.
  Future<List<Map<String, dynamic>>> sdelkiVFayle() async {
    final snap = await storage.readJson('polaris.portfolio.v1');
    final engine = snap?['engine'] as Map<String, dynamic>?;
    return [
      for (final t in (engine?['trades'] as List? ?? const []))
        (t as Map).cast<String, dynamic>(),
    ];
  }
}

void main() {
  const cena = 10000; // $100.00 за штуку
  const shestTysyach = 600000; // $6 000.00 в центах
  const triTysyachi = 300000; // $3 000.00 в центах

  /* ══ ПУТЬ 1 ══════════════════════════════════════════════════════════════ */

  group('ПУТЬ 1: покупка, на которую «не хватило денег»', () {
    /// Опыт скептика один в один: по 6000 из 10 000 на каждом устройстве.
    Future<(_Ustroystvo, _Ustroystvo, _Sklad)> dvaUstroystva({
      int nvdaCents = triTysyachi,
    }) async {
      final sklad = _Sklad();
      // Часы одни на оба устройства — как настоящее время в мире. Иначе
      // порядок событий зависел бы от того, у кого часы спешат.
      final chasy = _Chasy(DateTime(2026, 8, 1, 10, 0));
      final noutbuk = await _Ustroystvo.sozdat(sklad, now: chasy.call);
      final telefon = await _Ustroystvo.sozdat(sklad, now: chasy.call);

      // Ноутбук: 3000 + 3000 = 6000 из 10 000.
      await noutbuk.portfolio.buy('AAPL', triTysyachi, cena);
      await noutbuk.portfolio.buy('MSFT', triTysyachi, cena);
      // Телефон: 3000 + NVDA — из своих отдельных 10 000.
      await telefon.portfolio.buy('TSLA', triTysyachi, cena);
      await telefon.portfolio.buy('NVDA', nvdaCents, cena);

      // По отдельности всё честно: каждый уложился в свой счёт.
      expect(noutbuk.portfolio.cashCents, startingCashCents - shestTysyach);
      expect(noutbuk.portfolio.trades, hasLength(2));
      expect(telefon.portfolio.trades, hasLength(2));

      return (noutbuk, telefon, sklad);
    }

    test('покупка NVDA НЕ исчезает: ни из позиций, ни из истории, ни из файла',
        () async {
      final (noutbuk, telefon, _) = await dvaUstroystva();

      await noutbuk.obmen();
      await telefon.obmen();
      final itog = await noutbuk.obmen();

      // ── Было 4 записи — осталось 4. Раньше становилось 3.
      expect(noutbuk.portfolio.trades, hasLength(4),
          reason: 'из журнала не выбрасывается НИЧЕГО');
      expect(telefon.portfolio.trades, hasLength(4));

      // ── NVDA на месте в позициях.
      expect(noutbuk.portfolio.positions.keys.toSet(),
          {'AAPL', 'MSFT', 'TSLA', 'NVDA'});
      expect(telefon.portfolio.positions.keys.toSet(),
          {'AAPL', 'MSFT', 'TSLA', 'NVDA'});

      // ── NVDA на месте в истории.
      expect(noutbuk.portfolio.trades.where((t) => t.symbol == 'NVDA'),
          hasLength(1));

      // ── NVDA на месте В ФАЙЛЕ НА ДИСКЕ — то, что переживёт перезапуск.
      final vFayle = await noutbuk.sdelkiVFayle();
      expect(vFayle, hasLength(4), reason: 'в файле было 4 записи — 4 и осталось');
      expect(vFayle.where((t) => t['symbol'] == 'NVDA'), hasLength(1));

      // ── Деньги честно ушли в минус: 10 000 − 12 000 = −2 000.
      expect(noutbuk.portfolio.cashCents, startingCashCents - 4 * triTysyachi);
      expect(noutbuk.portfolio.cashCents, isNegative);
      expect(noutbuk.portfolio.cashCents, telefon.portfolio.cashCents,
          reason: 'оба устройства обязаны прийти к одному числу');

      // ── И приложение говорит об этом ВСЛУХ, а не «Готово».
      expect(noutbuk.portfolio.denegNeHvatilo, isTrue);
      expect(noutbuk.portfolio.pererashodCents, 200000); // $2 000.00
      expect(itog.pererashodCents, 200000);

      final tekst = PolarisSync.itogTekstom(itog, 'ru');
      expect(tekst, contains('потратил больше, чем было на счёте'));
      expect(tekst, contains('2000.00'));
      expect(tekst, contains('Ничего не выброшено'));
    });

    test('названа ИМЕННО та сделка — бумага, сумма и дата', () async {
      final (noutbuk, telefon, _) = await dvaUstroystva();
      // Как покупка выглядела на телефоне ДО обмена.
      final nvdaDo =
          telefon.portfolio.trades.firstWhere((t) => t.symbol == 'NVDA');

      await noutbuk.obmen();
      await telefon.obmen();
      await noutbuk.obmen();

      final vinovnye = noutbuk.portfolio.sdelkiSverhScheta;
      expect(vinovnye, hasLength(1),
          reason: 'человеку показывают, из-за какой сделки счёт ушёл в минус');
      expect(vinovnye.single.symbol, 'NVDA');
      expect(vinovnye.single.totalCents, triTysyachi);
      expect(vinovnye.single.ts, nvdaDo.ts,
          reason: 'дата сделки на месте — человеку есть за что зацепиться');
      // Это ровно та же запись, что лежит на телефоне, — не двойник.
      expect(vinovnye.single.uid,
          telefon.portfolio.trades.firstWhere((t) => t.symbol == 'NVDA').uid);
      expect(vinovnye.single.uid, isNotEmpty);
    });

    test('покупка ровно на 6000, на которую после слияния не хватило', () async {
      // Второе прочтение опыта: NVDA стоила все 6000 сразу.
      final (noutbuk, telefon, _) =
          await dvaUstroystva(nvdaCents: shestTysyach);
      await noutbuk.obmen();
      await telefon.obmen();
      await noutbuk.obmen();

      expect(noutbuk.portfolio.trades, hasLength(4));
      expect(noutbuk.portfolio.positions['NVDA'], isNotNull);
      expect(noutbuk.portfolio.positions['NVDA']!.costCents, shestTysyach);
      expect(noutbuk.portfolio.sdelkiSverhScheta.single.totalCents, shestTysyach);
      // 10 000 − (3000+3000+3000+6000) = −5 000.
      expect(noutbuk.portfolio.cashCents, startingCashCents - 1500000);
    });

    test('обмен три раза подряд — не выбрасывает НИ РАЗУ', () async {
      final (noutbuk, telefon, _) = await dvaUstroystva();
      await noutbuk.obmen();
      await telefon.obmen();

      for (var i = 1; i <= 3; i++) {
        await noutbuk.obmen();
        expect(noutbuk.portfolio.trades, hasLength(4),
            reason: 'обмен №$i: раньше выбрасывало КАЖДЫЙ раз');
        expect(noutbuk.portfolio.positions.containsKey('NVDA'), isTrue,
            reason: 'обмен №$i: бумага обязана остаться');
        expect(noutbuk.portfolio.cashCents, startingCashCents - 4 * triTysyachi,
            reason: 'обмен №$i: деньги не «чинятся» сами по себе');
      }
    });

    test('лишнюю сделку можно убрать РУКАМИ — и она не воскресает со склада',
        () async {
      final (noutbuk, telefon, _) = await dvaUstroystva();
      await noutbuk.obmen();
      await telefon.obmen();
      await noutbuk.obmen();

      final nvda =
          noutbuk.portfolio.trades.firstWhere((t) => t.symbol == 'NVDA');
      expect(await noutbuk.portfolio.ubratSdelku(nvda.uid), isTrue);

      // Деньги пересчитались сами — они производная от журнала.
      expect(noutbuk.portfolio.cashCents, startingCashCents - 3 * triTysyachi);
      expect(noutbuk.portfolio.denegNeHvatilo, isFalse);
      expect(noutbuk.portfolio.trades, hasLength(3));
      expect(noutbuk.portfolio.positions.containsKey('NVDA'), isFalse);

      // И обратно со склада она не приезжает — на ней надгробие.
      await noutbuk.obmen();
      await telefon.obmen();
      expect(noutbuk.portfolio.trades, hasLength(3));
      expect(telefon.portfolio.trades, hasLength(3),
          reason: 'убранное руками не должно возвращаться на второе устройство');
    });

    test('«Начать заново» ставит надгробия на ВСЕ 4 сделки — воскресать нечему',
        () async {
      final (noutbuk, telefon, _) = await dvaUstroystva();
      await noutbuk.obmen();
      await telefon.obmen();
      await noutbuk.obmen();
      expect(noutbuk.portfolio.trades, hasLength(4));

      await noutbuk.portfolio.reset();

      // ⚠️ Раньше выброшенная покупка NVDA не попадала в журнал, значит и
      // надгробия не получала — и после сброса воскресала бы со склада.
      expect(noutbuk.portfolio.deletedUids, hasLength(4),
          reason: 'надгробие обязано лечь на КАЖДУЮ сделку, включая NVDA');
      expect(noutbuk.portfolio.trades, isEmpty);
      expect(noutbuk.portfolio.cashCents, startingCashCents);
      expect(noutbuk.portfolio.denegNeHvatilo, isFalse);

      await noutbuk.obmen();
      expect(noutbuk.portfolio.trades, isEmpty,
          reason: 'стёртый портфель не должен приезжать обратно со склада');
      expect(noutbuk.portfolio.positions, isEmpty);

      // И на второе устройство стирание тоже доезжает целиком.
      await telefon.obmen();
      expect(telefon.portfolio.trades, isEmpty);
    });

    test('движок: покупка сверх счёта применяется, а не пропускается', () {
      Trade pokupka(String sym, int cents, int minuta) => Trade(
            id: '',
            uid: 'tr_$sym',
            symbol: sym,
            side: TradeSide.buy,
            qty: cents / cena,
            priceCents: cena,
            totalCents: cents,
            ts: DateTime(2026, 8, 1, 10, minuta),
          );

      final itog = SimEngine.fromEvents(
        trades: [
          pokupka('AAPL', triTysyachi, 1),
          pokupka('MSFT', triTysyachi, 2),
          pokupka('TSLA', triTysyachi, 3),
          pokupka('NVDA', triTysyachi, 4),
        ],
        dividends: const [],
      );

      expect(itog.engine.trades, hasLength(4));
      expect(itog.propushcheno, 0, reason: 'ничего не пропущено — всё учтено');
      expect(itog.engine.cashCents, -200000);
      expect(itog.pererashodCents, 200000);
      expect(itog.sverhScheta.map((t) => t.symbol), ['NVDA']);
      expect(itog.engine.positions.keys.toSet(),
          {'AAPL', 'MSFT', 'TSLA', 'NVDA'});
    });

    test('минус переживает перезапуск, а не «чинится» до нуля', () async {
      final (noutbuk, telefon, sklad) = await dvaUstroystva();
      await noutbuk.obmen();
      await telefon.obmen();
      await noutbuk.obmen();
      expect(noutbuk.portfolio.cashCents, -200000);

      // Перезапуск приложения на том же устройстве.
      final posle = await _Ustroystvo.sozdat(sklad, seed: noutbuk.storage.vsyo);
      expect(posle.portfolio.cashCents, -200000,
          reason: 'зажать минус в ноль — значит подарить деньги и скрыть беду');
      expect(posle.portfolio.denegNeHvatilo, isTrue);
      expect(posle.portfolio.sdelkiSverhScheta.single.symbol, 'NVDA',
          reason: 'человек и после перезапуска должен видеть, из-за чего минус');
    });
  });

  /* ══ ПУТЬ 2 ══════════════════════════════════════════════════════════════ */

  group('ПУТЬ 2: одна битая строчка внутри целого файла', () {
    /// Портфель скептика: файл читается, а у ОДНОЙ сделки (MSFT) одно поле
    /// битое — вместо числа строка. Так бывает при обрыве записи и при авариях
    /// с кодировкой.
    Map<String, Map<String, dynamic>> portfelSBitoyStrochkoy() => {
          'polaris.portfolio.v1': {
            'engine': {
              // 10 000 − 1000 (AAPL) − 20 (MSFT) − 1000 (TSLA) = 7 980.
              'cashCents': 798000,
              'seq': 3,
              'positions': [
                {'symbol': 'AAPL', 'qty': 10.0, 'costCents': 100000},
                {'symbol': 'MSFT', 'qty': 20.0, 'costCents': 2000},
                {'symbol': 'TSLA', 'qty': 5.0, 'costCents': 100000},
              ],
              'trades': <Map<String, dynamic>>[
                {
                  'id': 't1',
                  'uid': 'tr_noutbuk_aapl',
                  'symbol': 'AAPL',
                  'side': 'buy',
                  'qty': 10.0,
                  'priceCents': cena,
                  'totalCents': 100000,
                  'ts': '2026-08-01T10:00:00.000',
                  'realizedPnlCents': 0,
                },
                {
                  'id': 't2',
                  'uid': 'tr_noutbuk_msft',
                  'symbol': 'MSFT',
                  'side': 'buy',
                  // ⚠️ ВОТ ОНО: одно поле битое, всё остальное на месте.
                  'qty': 'двадцать',
                  'priceCents': 100,
                  'totalCents': 2000,
                  'ts': '2026-08-01T10:05:00.000',
                  'realizedPnlCents': 0,
                },
                {
                  'id': 't3',
                  'uid': 'tr_noutbuk_tsla',
                  'symbol': 'TSLA',
                  'side': 'buy',
                  'qty': 5.0,
                  'priceCents': 20000,
                  'totalCents': 100000,
                  'ts': '2026-08-01T10:10:00.000',
                  'realizedPnlCents': 0,
                },
              ],
              'dividends': <dynamic>[],
            },
          },
        };

    test('ДО обмена всё выглядит правильно — и это не повод молчать', () async {
      final sklad = _Sklad();
      final d = await _Ustroystvo.sozdat(sklad, seed: portfelSBitoyStrochkoy());

      // Ровно то, что видел скептик: три бумаги и деньги на месте.
      expect(d.portfolio.positions.keys.toSet(), {'AAPL', 'MSFT', 'TSLA'});
      expect(d.portfolio.positions['MSFT']!.qty, 20.0);
      expect(d.portfolio.positions['MSFT']!.costCents, 2000);
      expect(d.portfolio.cashCents, 798000);

      // ⚠️ А ВОТ ЭТО раньше было false — и потому приложение шло в сеть.
      expect(d.portfolio.snapshotBityy, isTrue,
          reason: '«есть запись, которую я не смог прочитать» — это тоже '
              '«прочиталось не полностью»');
      expect(d.portfolio.neprochitannyhZapisey, 1);
      expect(d.portfolio.gotovKObmenu, isFalse);
    });

    test('в сеть с таким портфелем не выходим — MSFT остаётся жива', () async {
      final sklad = _Sklad();
      final d = await _Ustroystvo.sozdat(sklad, seed: portfelSBitoyStrochkoy());

      final itog = await d.obmen();

      expect(itog.ok, isFalse);
      expect(itog.beda, 'портфель на устройстве прочитался не полностью');
      expect(sklad.zaprosov, 0,
          reason: 'к складу не должно уйти ни одного запроса');

      // Позиция MSFT (20 бумаг на 2000) НЕ исчезла. Раньше исчезала при
      // надписи «Готово» и «пропущено: 0».
      expect(d.portfolio.positions.keys.toSet(), {'AAPL', 'MSFT', 'TSLA'});
      expect(d.portfolio.positions['MSFT']!.qty, 20.0);
      expect(d.portfolio.positions['MSFT']!.costCents, 2000);
      expect(d.portfolio.cashCents, 798000);
    });

    test('битая запись сохраняется КАК ЕСТЬ — её можно разобрать руками',
        () async {
      final sklad = _Sklad();
      final d = await _Ustroystvo.sozdat(sklad, seed: portfelSBitoyStrochkoy());

      final kusok = d.portfolio.neprochitannyeKuski;
      expect(kusok, hasLength(1));
      expect(kusok.single['gde'], 'trades');
      final raw = (kusok.single['raw'] as Map).cast<String, dynamic>();
      expect(raw['symbol'], 'MSFT');
      expect(raw['qty'], 'двадцать', reason: 'битое поле сохранено как есть');
      expect(raw['totalCents'], 2000);

      // Любая запись портфеля на диск НЕ должна стирать непрочитанный кусок.
      await d.portfolio.buy('AAPL', 1000, cena);
      final snap = await d.storage.readJson('polaris.portfolio.v1');
      final engine = snap!['engine'] as Map<String, dynamic>;
      final ostalos = engine['neprochitannye'] as List;
      expect(ostalos, hasLength(1));
      expect(((ostalos.single as Map)['raw'] as Map)['qty'], 'двадцать');

      // И после перезапуска флаг всё ещё поднят — беда не «рассасывается».
      final posle = await _Ustroystvo.sozdat(sklad, seed: d.storage.vsyo);
      expect(posle.portfolio.snapshotBityy, isTrue);
      expect(posle.portfolio.neprochitannyhZapisey, 1);
      expect(posle.portfolio.positions['MSFT']!.qty, 20.0,
          reason: 'бумага на месте и после перезапуска');
    });

    test('«Начать заново» снимает запрет — но кусок остаётся на устройстве',
        () async {
      // Иначе человек с одной битой строчкой не смог бы обмениваться НИКОГДА.
      final sklad = _Sklad();
      final d = await _Ustroystvo.sozdat(sklad, seed: portfelSBitoyStrochkoy());
      expect(d.portfolio.snapshotBityy, isTrue);

      await d.portfolio.reset();
      expect(d.portfolio.snapshotBityy, isFalse);
      expect(d.portfolio.neprochitannyhZapisey, 0);

      // Непрочитанное НЕ стёрто: оно отложено в сторону под своим именем.
      final otlozheno = d.storage.vsyo.keys
          .where((k) => k.startsWith('polaris.portfolio.v1.neprochitannye-'))
          .toList();
      expect(otlozheno, hasLength(1),
          reason: 'разобрать руками должно быть из чего');
      final zapisi =
          (d.storage.vsyo[otlozheno.single]!['zapisi'] as List).single as Map;
      expect((zapisi['raw'] as Map)['qty'], 'двадцать');

      final itog = await d.obmen();
      expect(itog.ok, isTrue, reason: 'обмен снова разрешён: ${itog.beda}');
    });

    test('целый файл читается молча — ложной тревоги нет', () async {
      final sklad = _Sklad();
      final seed = portfelSBitoyStrochkoy();
      // Чиним ту самую строчку — и всё должно стать спокойным.
      final sdelki = (seed['polaris.portfolio.v1']!['engine']
          as Map<String, dynamic>)['trades'] as List<Map<String, dynamic>>;
      sdelki[1]['qty'] = 20.0;

      final d = await _Ustroystvo.sozdat(sklad, seed: seed);
      expect(d.portfolio.snapshotBityy, isFalse);
      expect(d.portfolio.neprochitannyhZapisey, 0);

      final itog = await d.obmen();
      expect(itog.ok, isTrue, reason: 'обмен обязан работать: ${itog.beda}');
      expect(d.portfolio.positions.keys.toSet(), {'AAPL', 'MSFT', 'TSLA'});
    });
  });

  /* ══ ПУТЬ 3 ══════════════════════════════════════════════════════════════ */

  group('ПУТЬ 3: кнопка «Убрать» при поднятом стороже', () {
    /// Обстановка скептика один в один: тот же файл с битой строчкой MSFT
    /// (20 бумаг на 2000) И сохранённый список «сверх счёта» с покупкой AAPL.
    /// Обе красные плашки горят разом, кнопка «Убрать» живая.
    Map<String, Map<String, dynamic>> portfelSObemyaBedami() => {
          'polaris.portfolio.v1': {
            'engine': {
              // 10 000 − 1000 (AAPL) − 20 (MSFT) − 1000 (TSLA) = 7 980.
              'cashCents': 798000,
              'seq': 3,
              'positions': [
                {'symbol': 'AAPL', 'qty': 10.0, 'costCents': 100000},
                {'symbol': 'MSFT', 'qty': 20.0, 'costCents': 2000},
                {'symbol': 'TSLA', 'qty': 5.0, 'costCents': 100000},
              ],
              'trades': <Map<String, dynamic>>[
                {
                  'id': 't1',
                  'uid': 'tr_noutbuk_aapl',
                  'symbol': 'AAPL',
                  'side': 'buy',
                  'qty': 10.0,
                  'priceCents': cena,
                  'totalCents': 100000,
                  'ts': '2026-08-01T10:00:00.000',
                  'realizedPnlCents': 0,
                },
                {
                  'id': 't2',
                  'uid': 'tr_noutbuk_msft',
                  'symbol': 'MSFT',
                  'side': 'buy',
                  // ⚠️ Одно поле битое, всё остальное на месте.
                  'qty': 'двадцать',
                  'priceCents': 100,
                  'totalCents': 2000,
                  'ts': '2026-08-01T10:05:00.000',
                  'realizedPnlCents': 0,
                },
                {
                  'id': 't3',
                  'uid': 'tr_noutbuk_tsla',
                  'symbol': 'TSLA',
                  'side': 'buy',
                  'qty': 5.0,
                  'priceCents': 20000,
                  'totalCents': 100000,
                  'ts': '2026-08-01T10:10:00.000',
                  'realizedPnlCents': 0,
                },
              ],
              'dividends': <dynamic>[],
            },
            // Вторая красная плашка: список «из-за чего счёт ушёл в минус»
            // пережил перезапуск, поэтому кнопка «Убрать» у AAPL живая.
            'sverhScheta': <dynamic>['tr_noutbuk_aapl'],
          },
        };

    test('ДО нажатия: горят обе плашки и кнопка «Убрать» живая', () async {
      final d = await _Ustroystvo.sozdat(_Sklad(), seed: portfelSObemyaBedami());

      expect(d.portfolio.positions.keys.toSet(), {'AAPL', 'MSFT', 'TSLA'});
      expect(d.portfolio.snapshotBityy, isTrue, reason: 'плашка про портфель');
      expect(d.portfolio.neprochitannyhZapisey, 1, reason: 'битых кусков 1');
      expect(d.portfolio.sdelkiSverhScheta.single.symbol, 'AAPL',
          reason: 'плашка про перерасход — она и рисует кнопку «Убрать»');
      expect(d.portfolio.gotovKObmenu, isFalse, reason: 'сторож поднят');
    });

    test('«Убрать» на AAPL НЕ стирает битую запись и НЕ опускает сторожа',
        () async {
      final d = await _Ustroystvo.sozdat(_Sklad(), seed: portfelSObemyaBedami());

      expect(await d.portfolio.ubratSdelku('tr_noutbuk_aapl'), isTrue);

      // Так это и выглядело у скептика: в журнале осталась одна TSLA.
      expect(d.portfolio.positions.keys.toSet(), {'TSLA'});

      // ⚠️ А ВОТ ЭТО раньше стиралось одним нажатием.
      expect(d.portfolio.neprochitannyhZapisey, 1,
          reason: 'единственная копия битой записи обязана пережить пересборку');
      expect(d.portfolio.snapshotBityy, isTrue,
          reason: 'сторож опускается только когда битого куска правда нет');
      expect(d.portfolio.gotovKObmenu, isFalse);

      // Сам кусок цел — из него ещё можно вытащить бумагу руками.
      final raw = (d.portfolio.neprochitannyeKuski.single['raw'] as Map)
          .cast<String, dynamic>();
      expect(raw['symbol'], 'MSFT');
      expect(raw['qty'], 'двадцать');
      expect(raw['totalCents'], 2000);

      // И на диске тоже — а значит и после перезапуска.
      final snap = await d.storage.readJson('polaris.portfolio.v1');
      final engine = snap!['engine'] as Map<String, dynamic>;
      expect(engine['neprochitannye'], hasLength(1));

      final posle = await _Ustroystvo.sozdat(_Sklad(), seed: d.storage.vsyo);
      expect(posle.portfolio.neprochitannyhZapisey, 1);
      expect(posle.portfolio.snapshotBityy, isTrue);
    });

    test('после «Убрать» приложение НЕ уходит на склад', () async {
      final sklad = _Sklad();
      final d = await _Ustroystvo.sozdat(sklad, seed: portfelSObemyaBedami());

      expect(await d.portfolio.ubratSdelku('tr_noutbuk_aapl'), isTrue);
      final itog = await d.obmen();

      expect(itog.ok, isFalse, reason: 'раньше писало «Готово» и шло на склад');
      expect(itog.beda, 'портфель на устройстве прочитался не полностью');
      expect(sklad.zaprosov, 0,
          reason: 'к складу не должно уйти ни одного запроса');
    });

    test('соседняя дверь: слияние со складом кусок тоже не стирает', () async {
      final d = await _Ustroystvo.sozdat(_Sklad(), seed: portfelSObemyaBedami());

      // Та же пересборка из событий, только другой вызов.
      expect(
        await d.portfolio.primenitSliyanie(
            trades: d.portfolio.trades, dividends: const [], deleted: const {}),
        isTrue,
      );

      expect(d.portfolio.neprochitannyhZapisey, 1);
      expect(d.portfolio.snapshotBityy, isTrue);
    });

    test('и всё же «Начать заново» сторожа опускает — кусок отложен', () async {
      // Проверка, что чинили не наглухо: когда кусок ПРАВДА убран, запрет снят.
      final d = await _Ustroystvo.sozdat(_Sklad(), seed: portfelSObemyaBedami());
      expect(await d.portfolio.ubratSdelku('tr_noutbuk_aapl'), isTrue);

      await d.portfolio.reset();
      expect(d.portfolio.neprochitannyhZapisey, 0);
      expect(d.portfolio.snapshotBityy, isFalse);
      expect(
          d.storage.vsyo.keys
              .where((k) =>
                  k.startsWith('polaris.portfolio.v1.neprochitannye-'))
              .length,
          1,
          reason: 'разобрать руками должно быть из чего');
    });
  });
}
