/// Виджет-тесты прохождения урока: свайп/кнопка по экранам-карточкам, квиз
/// с подсветкой верного/неверного + объяснением, начисление прогресса и
/// стрика, колбэк «попробуй на своём портфеле».
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/l10n/app_localizations.dart';
import 'package:polaris/screens/learn/lesson_player.dart';
import 'package:polaris/services/lessons.dart';
import 'package:polaris/services/storage.dart';
import 'package:polaris/state/learn_state.dart';

Lesson _lessonWithQuizAndTryIt() => Lesson(
      id: 'l1',
      moduleId: 'm1',
      order: 1,
      title: 'Урок про акции',
      screens: const [
        LessonScreen(
            title: 'Первый экран',
            emoji: '🙂',
            accent: Color(0xFF6C8EFF),
            paragraphs: ['Первый текст']),
        LessonScreen(
            title: 'Второй экран',
            emoji: '🚀',
            accent: Color(0xFF6C8EFF),
            paragraphs: ['Второй текст']),
      ],
      quiz: const [
        QuizQuestion(
          question: 'Что такое акция?',
          options: ['Кусочек компании', 'Подарочный купон'],
          correctIndex: 0,
          explanation: 'Акция — доля во владении компанией.',
        ),
      ],
      tryIt: const TryIt(
          action: TryItAction.openTheme, theme: 'big-tech', text: 'Загляни в тему'),
      disclaimer: 'Это не инвестиционная рекомендация.',
    );

Lesson _lessonNoQuizNoTryIt() => Lesson(
      id: 'l2',
      moduleId: 'm1',
      order: 2,
      title: 'Простой урок',
      screens: const [
        LessonScreen(
            title: 'Единственный экран',
            emoji: '🙂',
            accent: Color(0xFF6C8EFF),
            paragraphs: ['Текст'])
      ],
      quiz: const [],
    );

/// Оборачиваем в экран с кнопкой-пусковиком, чтобы проверять, что
/// LessonPlayer реально уходит с экрана (Navigator.pop) после «Готово»/tryIt.
Widget _harness(Lesson lesson, LearnState state, {void Function(TryIt)? onTryIt}) {
  return MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  LessonPlayer(lesson: lesson, learnState: state, onTryIt: onTryIt),
            )),
            child: const Text('Открыть урок'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  testWidgets('свайп-карточки → квиз с верным ответом → завершение с tryIt',
      (tester) async {
    final now = DateTime(2026, 7, 20);
    final state = LearnState(storage: MemoryStorage(), now: () => now);
    TryIt? received;
    final lesson = _lessonWithQuizAndTryIt();

    await tester.pumpWidget(_harness(lesson, state, onTryIt: (t) => received = t));
    await tester.tap(find.text('Открыть урок'));
    await _settle(tester);

    expect(find.byType(LessonPlayer), findsOneWidget);
    expect(find.text('Первый экран'), findsOneWidget);

    // Кнопкой «Дальше» — на второй экран.
    await tester.tap(find.text('Дальше'));
    await _settle(tester);
    expect(find.text('Второй экран'), findsOneWidget);

    // Последний экран — кнопка ведёт «К квизу».
    await tester.tap(find.text('К квизу'));
    await _settle(tester);
    expect(find.text('Что такое акция?'), findsOneWidget);

    // «Ответить» недоступна, пока не выбран вариант.
    await tester.tap(find.text('Ответить'));
    await _settle(tester);
    expect(find.text('Акция — доля во владении компанией.'), findsNothing);

    await tester.tap(find.text('Кусочек компании')); // верный вариант
    await _settle(tester);
    await tester.tap(find.text('Ответить'));
    await _settle(tester);
    expect(find.text('Акция — доля во владении компанией.'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    await tester.tap(find.text('Завершить урок'));
    await _settle(tester);

    // Прогресс и стрик уже начислены к моменту показа финального экрана.
    expect(state.isCompleted('l1'), isTrue);
    expect(state.currentStreak, 1);
    expect(state.quizResultOf('l1')!.correct, 1);
    expect(find.text('Верно 1 из 1'), findsOneWidget);
    expect(find.textContaining('Серия: 1'), findsOneWidget);
    expect(find.text('Это не инвестиционная рекомендация.'), findsOneWidget);

    // Кнопка tryIt зовёт колбэк и закрывает экран урока.
    await tester.tap(find.text('Загляни в тему'));
    await _settle(tester);
    expect(received, isNotNull);
    expect(received!.action, TryItAction.openTheme);
    expect(received!.theme, 'big-tech');
    expect(find.byType(LessonPlayer), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('неверный ответ подсвечивается красным, верный — зелёным',
      (tester) async {
    final state = LearnState(storage: MemoryStorage());
    final lesson = _lessonWithQuizAndTryIt();
    await tester.pumpWidget(_harness(lesson, state));
    await tester.tap(find.text('Открыть урок'));
    await _settle(tester);

    await tester.tap(find.text('Дальше'));
    await _settle(tester);
    await tester.tap(find.text('К квизу'));
    await _settle(tester);

    await tester.tap(find.text('Подарочный купон')); // неверный вариант
    await _settle(tester);
    await tester.tap(find.text('Ответить'));
    await _settle(tester);

    expect(find.byIcon(Icons.cancel_rounded), findsOneWidget); // неверный — крестик
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget); // верный подсвечен
    expect(find.text('Акция — доля во владении компанией.'), findsOneWidget);

    await tester.tap(find.text('Завершить урок'));
    await _settle(tester);
    expect(state.quizResultOf('l1')!.correct, 0);
    expect(find.text('Верно 0 из 1'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('урок без квиза и tryIt завершается сразу кнопкой «Готово»',
      (tester) async {
    final state = LearnState(storage: MemoryStorage());
    final lesson = _lessonNoQuizNoTryIt();
    await tester.pumpWidget(_harness(lesson, state));
    await tester.tap(find.text('Открыть урок'));
    await _settle(tester);

    // Один экран, квиза нет — сразу «Готово».
    await tester.tap(find.text('Готово'));
    await _settle(tester);

    expect(state.isCompleted('l2'), isTrue);
    expect(find.text('Урок пройден!'), findsOneWidget);
    // Без квиза счёт не показываем.
    expect(find.textContaining('Верно'), findsNothing);
    // Без tryIt карточки-приглашения нет.
    expect(find.byIcon(Icons.explore_outlined), findsNothing);

    await tester.tap(find.text('Готово'));
    await _settle(tester);
    expect(find.byType(LessonPlayer), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
