/// Виджет-тесты «пути обучения»: модули, узлы-звёзды (открыт/пройден/заперт),
/// стрик-карточка, глоссарий. Контент подаётся напрямую через [LearnScreen.content]
/// — в ассеты не ходим, тестируем чистую логику экрана на фикстурах.
///
/// autoPoll здесь ни при чём, но StarsBackground крутит бесконечный тикер —
/// поэтому вместо pumpAndSettle используем фиксированный отстой кадров
/// (тот же приём, что в market_screen_test.dart).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/l10n/app_localizations.dart';
import 'package:polaris/services/lessons.dart';
import 'package:polaris/screens/learn/learn_screen.dart';
import 'package:polaris/screens/learn/lesson_player.dart';
import 'package:polaris/services/storage.dart';
import 'package:polaris/state/learn_state.dart';

LessonsContent _fixtureContent() {
  const m1 = Module(
      id: 'm1', title: 'Модуль 1', order: 1, accent: Color(0xFF6C8EFF), emoji: '🌌');
  const m2 = Module(
      id: 'm2', title: 'Модуль 2', order: 2, accent: Color(0xFF4FD1C5), emoji: '🪐');
  final l1 = Lesson(
    id: 'l1',
    moduleId: 'm1',
    order: 1,
    title: 'Урок 1',
    screens: const [
      LessonScreen(
          title: 'Экран', emoji: '🙂', accent: Color(0xFF6C8EFF), paragraphs: ['Текст урока'])
    ],
    quiz: const [
      QuizQuestion(
          question: 'Вопрос?',
          options: ['Неверно', 'Верно'],
          correctIndex: 1,
          explanation: 'Потому что так.')
    ],
    tryIt: const TryIt(action: TryItAction.openMarket, text: 'Загляни в рынки'),
  );
  final l2 = Lesson(
    id: 'l2',
    moduleId: 'm1',
    order: 2,
    title: 'Урок 2',
    screens: const [
      LessonScreen(title: 'Экран2', emoji: '🙂', accent: Color(0xFF6C8EFF), paragraphs: ['Ещё'])
    ],
    quiz: const [],
  );
  final l3 = Lesson(
    id: 'l3',
    moduleId: 'm2',
    order: 1,
    title: 'Урок 3',
    screens: const [
      LessonScreen(title: 'Экран3', emoji: '🙂', accent: Color(0xFF4FD1C5), paragraphs: ['Текст 3'])
    ],
    quiz: const [],
  );
  return LessonsContent(
    modules: const [m1, m2],
    lessons: [l1, l2, l3],
    glossary: const [
      GlossaryTerm(id: 't1', term: 'Акция', definition: 'Кусочек компании'),
    ],
    themes: const [],
  );
}

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  testWidgets('путь рисуется: заголовок, модули, стрик, первый урок открыт',
      (tester) async {
    final state = LearnState(storage: MemoryStorage());
    await tester.pumpWidget(_wrap(LearnScreen(state: state, content: _fixtureContent())));
    await _settle(tester);

    expect(find.text('Учёба'), findsOneWidget);
    expect(find.text('Модуль 1'), findsOneWidget);
    expect(find.text('Модуль 2'), findsOneWidget);
    // Стрик ещё не начат.
    expect(find.text('Начни свою серию'), findsOneWidget);
    // Первый урок маршрута открыт — виден его номер.
    expect(find.text('1'), findsOneWidget);
    // Второй и третий уроки заперты — иконки замков.
    expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('тап по открытому узлу открывает LessonPlayer', (tester) async {
    final state = LearnState(storage: MemoryStorage());
    await tester.pumpWidget(_wrap(LearnScreen(state: state, content: _fixtureContent())));
    await _settle(tester);

    await tester.tap(find.text('1'));
    await _settle(tester);

    expect(find.byType(LessonPlayer), findsOneWidget);
    expect(find.text('Экран'), findsOneWidget);
    expect(find.text('Текст урока'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('тап по запертому узлу не открывает урок', (tester) async {
    final state = LearnState(storage: MemoryStorage());
    await tester.pumpWidget(_wrap(LearnScreen(state: state, content: _fixtureContent())));
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.lock_outline_rounded).first);
    await _settle(tester);

    expect(find.byType(LessonPlayer), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('после прохождения урока узел светится и открывает следующий',
      (tester) async {
    final now = DateTime(2026, 7, 20);
    final state = LearnState(storage: MemoryStorage(), now: () => now);
    await tester.pumpWidget(_wrap(LearnScreen(state: state, content: _fixtureContent())));
    await _settle(tester);

    await state.completeLesson('l1', quizCorrect: 1, quizTotal: 1);
    await _settle(tester);

    // Пройденный узел — галочка вместо номера, заперт остался только один (l3).
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    // Стрик уже виден в карточке.
    expect(find.textContaining('подряд'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('глоссарий открывается шторкой и фильтруется поиском', (tester) async {
    final state = LearnState(storage: MemoryStorage());
    await tester.pumpWidget(_wrap(LearnScreen(state: state, content: _fixtureContent())));
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await _settle(tester);
    expect(find.text('Глоссарий'), findsOneWidget);
    expect(find.text('Акция'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz_nonexistent');
    await _settle(tester);
    expect(find.text('Ничего не нашлось'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('пустой контент показывает честную заглушку без краша',
      (tester) async {
    final state = LearnState(storage: MemoryStorage());
    await tester.pumpWidget(_wrap(LearnScreen(state: state, content: LessonsContent.empty)));
    await _settle(tester);

    expect(find.text('Уроки пока не загрузились'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
