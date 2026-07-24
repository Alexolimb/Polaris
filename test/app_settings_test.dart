/// Тесты [AppSettings]: онбординг-флаг+цель, флаги уведомлений, языковое
/// предпочтение, сохранение/перезагрузка через [MemoryStorage], терпимость
/// к битому снапшоту.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/services/storage.dart';
import 'package:polaris/state/app_settings.dart';

void main() {
  group('значения по умолчанию', () {
    test('до загрузки — онбординг не пройден, урок+сводка вкл, остальное выкл',
        () async {
      final s = AppSettings();
      await s.load();
      expect(s.loaded, isTrue);
      expect(s.onboardingDone, isFalse);
      expect(s.userGoal, isNull);
      expect(s.notifyLessonReminder, isTrue);
      expect(s.notifyWeeklySummary, isTrue);
      expect(s.notifyDividend, isFalse);
      expect(s.notifyBigMoves, isFalse);
      expect(s.localePref, LocalePref.auto);
    });
  });

  group('онбординг', () {
    test('completeOnboarding сохраняет флаг и цель, уведомляет слушателей',
        () async {
      final s = AppSettings();
      await s.load();
      var notified = 0;
      s.addListener(() => notified++);

      await s.completeOnboarding(UserGoal.learnInvesting);

      expect(s.onboardingDone, isTrue);
      expect(s.userGoal, UserGoal.learnInvesting);
      expect(notified, greaterThan(0));
    });

    test('флаг и цель переживают перезагрузку из того же хранилища', () async {
      final storage = MemoryStorage();
      final a = AppSettings(storage: storage);
      await a.load();
      await a.completeOnboarding(UserGoal.saveForFuture);

      final b = AppSettings(storage: storage);
      await b.load();
      expect(b.onboardingDone, isTrue);
      expect(b.userGoal, UserGoal.saveForFuture);
    });
  });

  group('уведомления', () {
    test('точечные сеттеры меняют только свой флаг и сохраняются', () async {
      final storage = MemoryStorage();
      final s = AppSettings(storage: storage);
      await s.load();

      await s.setLessonReminder(false);
      expect(s.notifyLessonReminder, isFalse);
      expect(s.notifyWeeklySummary, isTrue); // не тронуто

      await s.setDividendPaid(true);
      await s.setBigMoves(true);
      expect(s.notifyDividend, isTrue);
      expect(s.notifyBigMoves, isTrue);

      final reloaded = AppSettings(storage: storage);
      await reloaded.load();
      expect(reloaded.notifyLessonReminder, isFalse);
      expect(reloaded.notifyWeeklySummary, isTrue);
      expect(reloaded.notifyDividend, isTrue);
      expect(reloaded.notifyBigMoves, isTrue);
    });

    test('повторная установка того же значения не шлёт лишний notify',
        () async {
      final s = AppSettings();
      await s.load();
      var notified = 0;
      s.addListener(() => notified++);
      await s.setLessonReminder(true); // уже true по умолчанию
      expect(notified, 0);
    });
  });

  group('язык', () {
    test('setLocalePref сохраняется и переживает перезагрузку', () async {
      final storage = MemoryStorage();
      final s = AppSettings(storage: storage);
      await s.load();
      await s.setLocalePref(LocalePref.es);

      final reloaded = AppSettings(storage: storage);
      await reloaded.load();
      expect(reloaded.localePref, LocalePref.es);
    });
  });

  group('сброс', () {
    test('reset возвращает всё к значениям по умолчанию', () async {
      final s = AppSettings();
      await s.load();
      await s.completeOnboarding(UserGoal.curious);
      await s.setDividendPaid(true);
      await s.setLocalePref(LocalePref.en);

      await s.reset();

      expect(s.onboardingDone, isFalse);
      expect(s.userGoal, isNull);
      expect(s.notifyDividend, isFalse);
      expect(s.localePref, LocalePref.auto);
    });
  });

  group('битый снапшот', () {
    test('не роняет load(), остаются значения по умолчанию', () async {
      final storage = MemoryStorage({
        'polaris.settings.v1': {
          'onboardingDone': 'да, наверное',
          'userGoal': 42,
          'notifications': 'мусор',
          'localePref': const {'not': 'a string'},
        }
      });
      final s = AppSettings(storage: storage);
      await s.load();
      expect(s.loaded, isTrue);
      expect(s.onboardingDone, isFalse);
      expect(s.userGoal, isNull);
      expect(s.notifyLessonReminder, isTrue);
      expect(s.localePref, LocalePref.auto);
    });

    test('неизвестное имя цели/языка не роняет парсинг', () async {
      final storage = MemoryStorage({
        'polaris.settings.v1': {
          'onboardingDone': true,
          'userGoal': 'inventedGoal',
          'localePref': 'klingon',
        }
      });
      final s = AppSettings(storage: storage);
      await s.load();
      expect(s.onboardingDone, isTrue);
      expect(s.userGoal, isNull);
      expect(s.localePref, LocalePref.auto);
    });
  });
}
