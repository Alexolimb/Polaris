/// Логика прогресса «Учёбы»: стрик (подряд/сброс), сохранение через
/// MemoryStorage, проценты по модулю, «следующий урок», разблокировка.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/services/storage.dart';
import 'package:polaris/state/learn_state.dart';

void main() {
  group('стрик', () {
    test('первый пройденный урок даёт стрик = 1 и «сегодня уже занимался»', () async {
      final now = DateTime(2026, 7, 20);
      final s = LearnState(now: () => now);
      await s.load();
      await s.completeLesson('l1');
      expect(s.currentStreak, 1);
      expect(s.longestStreak, 1);
      expect(s.completedToday, isTrue);
    });

    test('урок на следующий календарный день увеличивает стрик', () async {
      var now = DateTime(2026, 7, 20);
      final s = LearnState(now: () => now);
      await s.load();
      await s.completeLesson('l1');
      now = DateTime(2026, 7, 21);
      await s.completeLesson('l2');
      expect(s.currentStreak, 2);
      expect(s.longestStreak, 2);
    });

    test('несколько уроков в тот же день не удваивают стрик', () async {
      final now = DateTime(2026, 7, 20);
      final s = LearnState(now: () => now);
      await s.load();
      await s.completeLesson('l1');
      await s.completeLesson('l2');
      await s.completeLesson('l3');
      expect(s.currentStreak, 1);
    });

    test('пропуск дня (2+) сбрасывает текущий стрик, рекорд остаётся', () async {
      var now = DateTime(2026, 7, 20);
      final s = LearnState(now: () => now);
      await s.load();
      await s.completeLesson('l1');
      now = DateTime(2026, 7, 21);
      await s.completeLesson('l2');
      now = DateTime(2026, 7, 25); // пропуск нескольких дней
      await s.completeLesson('l3');
      expect(s.currentStreak, 1);
      expect(s.longestStreak, 2);
    });

    test('completedToday — false, пока сегодня ещё не занимался', () async {
      var now = DateTime(2026, 7, 20);
      final s = LearnState(now: () => now);
      await s.load();
      await s.completeLesson('l1');
      now = DateTime(2026, 7, 21);
      expect(s.completedToday, isFalse);
    });
  });

  group('сохранение и перезагрузка', () {
    test('прогресс и результат квиза переживают перезагрузку', () async {
      final storage = MemoryStorage();
      final now = DateTime(2026, 7, 20);
      final s = LearnState(storage: storage, now: () => now);
      await s.load();
      await s.completeLesson('l1', quizCorrect: 1, quizTotal: 1);

      final reloaded = LearnState(storage: storage, now: () => now);
      await reloaded.load();
      expect(reloaded.isCompleted('l1'), isTrue);
      expect(reloaded.currentStreak, 1);
      expect(reloaded.quizResultOf('l1')!.correct, 1);
      expect(reloaded.quizResultOf('l1')!.total, 1);
    });

    test('стрик через несколько сессий подряд считается верно', () async {
      final storage = MemoryStorage();
      var now = DateTime(2026, 7, 20);
      var s = LearnState(storage: storage, now: () => now);
      await s.load();
      await s.completeLesson('l1');

      now = DateTime(2026, 7, 21);
      s = LearnState(storage: storage, now: () => now);
      await s.load();
      await s.completeLesson('l2');
      expect(s.currentStreak, 2);
    });

    test('битый снапшот не роняет загрузку', () async {
      final storage = MemoryStorage({
        'polaris.learn.v1': {
          'completed': 'мусор',
          'quizResults': 'тоже мусор',
          'currentStreak': 'не число',
          'lastLessonDate': 42,
        }
      });
      final s = LearnState(storage: storage);
      await s.load();
      expect(s.loaded, isTrue);
      expect(s.completedCount, 0);
      expect(s.currentStreak, 0);
    });
  });

  group('прогресс по маршруту', () {
    test('moduleProgressPct считает долю пройденных уроков модуля', () async {
      final s = LearnState();
      await s.load();
      await s.completeLesson('a');
      await s.completeLesson('b');
      expect(s.moduleProgressPct(['a', 'b', 'c', 'd']), closeTo(50, 0.01));
      expect(s.moduleProgressPct([]), 0);
      expect(s.moduleProgressPct(['a', 'b']), 100);
    });

    test('nextLessonId — первый непройденный по порядку, null если всё пройдено', () async {
      final s = LearnState();
      await s.load();
      expect(s.nextLessonId(['a', 'b', 'c']), 'a');
      await s.completeLesson('a');
      expect(s.nextLessonId(['a', 'b', 'c']), 'b');
      await s.completeLesson('b');
      await s.completeLesson('c');
      expect(s.nextLessonId(['a', 'b', 'c']), isNull);
    });

    test('isUnlocked: первый в маршруте всегда открыт, дальше — по цепочке', () async {
      final s = LearnState();
      await s.load();
      expect(s.isUnlocked('a', ['a', 'b', 'c']), isTrue);
      expect(s.isUnlocked('b', ['a', 'b', 'c']), isFalse);
      expect(s.isUnlocked('c', ['a', 'b', 'c']), isFalse);

      await s.completeLesson('a');
      expect(s.isUnlocked('b', ['a', 'b', 'c']), isTrue);
      expect(s.isUnlocked('c', ['a', 'b', 'c']), isFalse);
      // Пройденный урок всегда «доступен» — можно перепройти.
      expect(s.isUnlocked('a', ['a', 'b', 'c']), isTrue);
    });

    test('урок не из маршрута не блокирует остальные (защита от рассинхрона)', () async {
      final s = LearnState();
      await s.load();
      expect(s.isUnlocked('ghost', ['a', 'b', 'c']), isTrue);
    });
  });

  group('сброс', () {
    test('reset обнуляет прогресс, квизы и стрик', () async {
      final s = LearnState();
      await s.load();
      await s.completeLesson('a', quizCorrect: 1, quizTotal: 1);
      await s.reset();
      expect(s.completedCount, 0);
      expect(s.currentStreak, 0);
      expect(s.longestStreak, 0);
      expect(s.lastLessonDate, isNull);
      expect(s.quizResultOf('a'), isNull);
    });
  });
}
