import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/services/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Битый портфель не должен выглядеть как новый человек.
///
/// Беда, найденная ревизией 10.08.2026, и она молчала:
///
///   1. Сохранённый портфель не прочитался (запись есть, но повреждена).
///   2. Хранилище возвращало `null` — ровно то же, что при первом запуске.
///   3. Приложение показывало свежие 10 000 долларов, как после установки.
///   4. Первая же покупка записывала пустой портфель ПОВЕРХ настоящего.
///   → Позиции, вся история сделок и все дивиденды исчезали навсегда.
///     Человек решал, что приложение «сбросилось само», и продолжал играть.
///
/// Теперь: «записи нет» и «запись не читается» — разные ответы, а нечитаемое
/// откладывается в сторону и остаётся на устройстве.
void main() {
  const kluch = 'polaris.portfolio.v1';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('записи нет — это честный первый запуск, тревоги нет', () async {
    final s = PrefsStorage();
    expect(await s.readJson(kluch), isNull);
    expect(PrefsStorage.bitaya(kluch), isFalse);
  });

  test('запись целая — читается как обычно', () async {
    SharedPreferences.setMockInitialValues({kluch: '{"engine":{"cash":123}}'});
    final s = PrefsStorage();
    final d = await s.readJson(kluch);
    expect(d, isNotNull);
    expect(PrefsStorage.bitaya(kluch), isFalse);
  });

  test('запись битая — приложение об этом УЗНАЁТ', () async {
    SharedPreferences.setMockInitialValues({kluch: '{"engine": {"cash": 123'});
    final s = PrefsStorage();
    expect(await s.readJson(kluch), isNull);
    expect(PrefsStorage.bitaya(kluch), isTrue,
        reason: 'битая запись не должна выглядеть как отсутствие записи');
  });

  test('битая запись НЕ пропадает — её откладывают в сторону', () async {
    const musor = '{"engine": {"cash": 999999, "positions": [обрыв';
    SharedPreferences.setMockInitialValues({kluch: musor});
    final s = PrefsStorage();
    await s.readJson(kluch);

    final prefs = await SharedPreferences.getInstance();
    final otlozhennye =
        prefs.getKeys().where((k) => k.startsWith('$kluch.broken-')).toList();
    expect(otlozhennye.length, 1, reason: 'нечитаемое обязано остаться на устройстве');
    expect(prefs.getString(otlozhennye.first), musor);
  });

  test('не тот вид данных (список вместо объекта) — тоже беда, а не пустота', () async {
    SharedPreferences.setMockInitialValues({kluch: '[1,2,3]'});
    final s = PrefsStorage();
    expect(await s.readJson(kluch), isNull);
    expect(PrefsStorage.bitaya(kluch), isTrue);
  });
}
