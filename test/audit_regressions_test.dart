// Регресс-тесты на баги, найденные аудитом 24.07.2026 (мульти-агентный).
// Каждый тест ловит конкретный дефект, который был исправлен.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/models/models.dart';
import 'package:polaris/services/ai.dart';
import 'package:polaris/services/sim_engine.dart';
import 'package:polaris/services/storage.dart';
import 'package:polaris/state/learn_state.dart';

void main() {
  group('sim_engine — деньги', () {
    test('покупка на сумму НЕ создаёт «бесплатную» стоимость (округление вниз)', () {
      // Раньше qty округлялось к ближайшему (мог вверх) → накопление микро-
      // покупок + продажа давали профит из воздуха.
      final e = SimEngine();
      const price = 6406100; // как BTC в тестах — провоцирует округление
      final start = e.cashCents;
      for (var i = 0; i < 100; i++) {
        e.buyForAmount('BTC', 1, price); // по 1 центу
      }
      final pos = e.positions['BTC']!;
      e.sellQty('BTC', pos.qty, price); // продать всё по той же цене
      // Ни цента прибыли из ничего: касса не выросла.
      expect(e.cashCents, lessThanOrEqualTo(start));
    });

    test('sellQty с количеством, округляющимся в ноль, — бросает, а не пишет пустую сделку', () {
      final e = SimEngine();
      e.buyForAmount('AAPL', 100000, 20000); // 5 шт
      expect(() => e.sellQty('AAPL', 4e-9, 20000), throwsA(isA<SimError>()));
      expect(e.trades.length, 1); // фантомной sell-сделки не появилось
    });

    test('дивиденд начисляется по количеству на ДАТУ ОТСЕЧКИ, а не текущему', () {
      var clock = DateTime(2026, 7, 10);
      final e = SimEngine(now: () => clock);
      e.buyForAmount('AAPL', 100000, 20000); // day10: 5 шт
      clock = DateTime(2026, 7, 16);
      e.buyForAmount('AAPL', 100000, 20000); // day16: докупили ещё 5 → 10 шт
      // Отсечка была 15 июля — держали тогда только 5.
      final payout = e.payDividend('AAPL', 24, asOf: DateTime(2026, 7, 15));
      expect(payout, isNotNull);
      expect(payout!.qtyAtRecord, closeTo(5, 1e-9));
      expect(payout.totalCents, 120); // 5 * 24, а не 240
    });

    test('fromJson согласует seq с загруженными сделками (нет дублей id)', () {
      // Снапшот со сделками t1..t3, но БЕЗ поля seq.
      final json = {
        'cashCents': 500000,
        'positions': [
          {'symbol': 'AAPL', 'qty': 5.0, 'costCents': 100000},
        ],
        'trades': [
          for (var i = 1; i <= 3; i++)
            {
              'id': 't$i',
              'symbol': 'AAPL',
              'side': 'buy',
              'qty': 1.0,
              'priceCents': 20000,
              'totalCents': 20000,
              'ts': DateTime(2026, 7, 1).toIso8601String(),
              'realizedPnlCents': 0,
            },
        ],
      };
      final e = SimEngine.fromJson(json);
      final t = e.buyForAmount('MSFT', 20000, 20000);
      expect(t.id, 't4'); // не 't1' — счётчик продолжился с максимума
    });

    test('fromJson не падает, если positions/trades пришли не списком', () {
      // Раньше `as List?` бросал TypeError → вечная заставка на старте.
      final e = SimEngine.fromJson({'cashCents': 123, 'positions': 42, 'trades': 'oops'});
      expect(e.cashCents, 123);
      expect(e.positions, isEmpty);
    });
  });

  group('learn_state — стрик', () {
    test('стрик сгорает после пропуска дней (getter не врёт старым значением)', () async {
      var clock = DateTime(2026, 7, 20, 12);
      final s = LearnState(storage: MemoryStorage(), now: () => clock);
      await s.completeLesson('l1');
      expect(s.currentStreak, 1);
      clock = DateTime(2026, 7, 23, 12); // пропущены 21 и 22
      expect(s.currentStreak, 0); // раньше показывал бы 1
    });
  });

  group('ai — SSE', () {
    test('кириллица, разорванная на границе байтового чанка, собирается верно', () async {
      // 'Привет' в UTF-8; режем ровно посреди многобайтового символа.
      final full = utf8.encode('data: {"delta":"Привет"}\n\n');
      final mid = 7; // середина одного из многобайтовых символов
      final ai = PolarisAi(
        streamPost: (uri, body, timeout) async* {
          yield full.sublist(0, mid);
          yield full.sublist(mid);
        },
      );
      final out = <String>[];
      await for (final d in ai.streamChat(messages: const [], lang: 'ru')) {
        out.add(d);
      }
      expect(out.join(), 'Привет'); // без «мусорных» символов замены
    });

    test('последнее событие без хвостового \\n\\n не теряется', () async {
      final ai = PolarisAi(
        streamPost: (uri, body, timeout) async* {
          yield utf8.encode('data: {"delta":"Ответ"}'); // без завершающего \n\n и [DONE]
        },
      );
      final out = <String>[];
      await for (final d in ai.streamChat(messages: const [], lang: 'ru')) {
        out.add(d);
      }
      expect(out.join(), 'Ответ');
    });
  });

  // ---------------------------------------------------------------------
  // Ночной аудит 24→25.07.2026 — три критичных дефекта.
  // ---------------------------------------------------------------------
  group('ночной аудит 25.07.2026', () {
    test('в боевом AndroidManifest есть разрешение INTERNET', () {
      // Без него release-APK физически не может ходить в сеть: живых котировок
      // нет, Cosmo мёртв, и всё это молча падает в демо-фикстуры. В debug и
      // profile манифестах INTERNET добавляет сам Flutter — поэтому при
      // разработке баг незаметен.
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest.contains('android.permission.INTERNET'), isTrue,
          reason: 'release-APK останется без сети');
      // Заодно: имя приложения на устройстве — с большой буквы.
      expect(manifest.contains('android:label="Polaris"'), isTrue);
    });

    test('freshness "demo" не превращается в "конец дня"', () {
      // Сервер честно помечает синтетику freshness:"demo". Раньше в enum такого
      // значения не было, срабатывал фолбэк endOfDay — и выдуманные цены
      // показывались пользователю как биржевые «на конец дня».
      final a = Asset.fromJson(const {
        'symbol': 'AAPL',
        'name': 'Apple Inc.',
        'type': 'stock',
        'freshness': 'demo',
      });
      expect(a.freshness, QuoteFreshness.demo);
    });

    test('неизвестная свежесть трактуется как demo, а не как биржевая', () {
      final a = Asset.fromJson(const {
        'symbol': 'AAPL',
        'name': 'Apple Inc.',
        'type': 'stock',
        'freshness': 'что-то-новое',
      });
      expect(a.freshness, QuoteFreshness.demo);
    });
  });
}
