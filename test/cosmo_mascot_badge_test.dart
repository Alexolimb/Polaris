// Тесты CosmoBadge (мини-аватар) и CosmoGreeting (маскот + реплика).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/widgets/cosmo/cosmo_mascot.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  // ------------------------------------------------------------ CosmoBadge

  for (final mood in CosmoMood.values) {
    testWidgets('CosmoBadge $mood рисуется без исключений (static по умолчанию)',
        (tester) async {
      await tester.pumpWidget(_wrap(CosmoBadge(mood: mood)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('CosmoBadge animated:true пампится без исключений', (tester) async {
    await tester.pumpWidget(_wrap(
      const CosmoBadge(mood: CosmoMood.idle, animated: true, size: 40),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('CosmoBadge маленький размер (как в пузыре чата, 26px)',
      (tester) async {
    await tester.pumpWidget(_wrap(const CosmoBadge(size: 26)));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  // --------------------------------------------------------- CosmoGreeting

  testWidgets('CosmoGreeting показывает текст и маскота', (tester) async {
    await tester.pumpWidget(_wrap(
      const CosmoGreeting(text: 'Привет, я Cosmo!'),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Привет, я Cosmo!'), findsOneWidget);
    expect(find.byType(CosmoMascot), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('CosmoGreeting animated:false не роняет', (tester) async {
    await tester.pumpWidget(_wrap(
      const CosmoGreeting(
        text: 'Статичное приветствие',
        mood: CosmoMood.concerned,
        animated: false,
      ),
    ));
    expect(find.text('Статичное приветствие'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
