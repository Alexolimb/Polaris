/// Виджет-тесты экрана Cosmo: приветствие + кнопки-подсказки на пустой
/// истории, живой стриминг ответа в пузыре, отправка через поле ввода,
/// экран не падает без AppScope выше по дереву (изолированный запуск).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/screens/chat/cosmo_screen.dart';
import 'package:polaris/services/ai.dart';
import 'package:polaris/services/storage.dart';
import 'package:polaris/state/chat_state.dart';

Stream<List<int>> _sse(List<String> lines) async* {
  for (final l in lines) {
    yield utf8.encode(l);
  }
}

Widget _wrap(ChatState chat) => MaterialApp(
      home: Scaffold(body: CosmoScreen(chatState: chat)),
    );

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('пустая история показывает приветствие Cosmo и кнопки-подсказки',
      (tester) async {
    final chat = ChatState(ai: PolarisAi(), storage: MemoryStorage(), lang: () => 'ru');
    await tester.pumpWidget(_wrap(chat));
    await _settle(tester);

    expect(find.textContaining('Привет, я Cosmo!'), findsOneWidget);
    expect(find.text('Что такое ETF?'), findsOneWidget);
    expect(find.text('С чего начать?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('тап по кнопке-подсказке отправляет вопрос и стримит ответ',
      (tester) async {
    final ai = PolarisAi(
      streamPost: (uri, body, timeout) => _sse([
        'data: {"delta":"ETF "}\n\n',
        'data: {"delta":"— это фонд."}\n\n',
        'data: [DONE]\n\n',
      ]),
    );
    final chat = ChatState(ai: ai, storage: MemoryStorage(), lang: () => 'ru');
    await tester.pumpWidget(_wrap(chat));
    await _settle(tester);

    await tester.tap(find.text('Что такое ETF?'));
    await _settle(tester);

    expect(find.text('Что такое ETF?'), findsOneWidget); // теперь это пузырь пользователя
    expect(find.textContaining('ETF — это фонд.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('поле ввода отправляет произвольный текст', (tester) async {
    final ai = PolarisAi(
      streamPost: (uri, body, timeout) => _sse(['data: {"delta":"Привет!"}\n\n', 'data: [DONE]\n\n']),
    );
    final chat = ChatState(ai: ai, storage: MemoryStorage(), lang: () => 'ru');
    await tester.pumpWidget(_wrap(chat));
    await _settle(tester);

    await tester.enterText(find.byType(TextField), 'Как купить акцию?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await _settle(tester);

    expect(find.text('Как купить акцию?'), findsOneWidget);
    expect(find.textContaining('Привет!'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('во время стриминга видна плашка "Cosmo печатает…"', (tester) async {
    // Стрим, который сознательно не закрывается сам — эмулирует медленный
    // ответ сети, чтобы поймать состояние "ещё печатает" до завершения.
    final controller = StreamController<List<int>>();
    final ai = PolarisAi(streamPost: (uri, body, timeout) => controller.stream);
    final chat = ChatState(ai: ai, storage: MemoryStorage(), lang: () => 'ru');
    await tester.pumpWidget(_wrap(chat));
    await _settle(tester);

    await tester.tap(find.text('С чего начать?'));
    await tester.pump(); // отправка стартовала, стрим ещё не дал ни одного чанка

    expect(chat.sending, isTrue);
    expect(find.textContaining('Cosmo печатает'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await controller.close(); // аккуратно завершаем зависший стрим до конца теста
    await _settle(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('экран не падает без AppScope выше по дереву', (tester) async {
    final chat = ChatState(ai: PolarisAi(), storage: MemoryStorage(), lang: () => 'en');
    await tester.pumpWidget(_wrap(chat));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
