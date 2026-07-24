// Тесты светящихся элементов: GlowCard, PulseDot, AuroraText.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/widgets/fx/glow.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('GlowCard показывает ребёнка', (tester) async {
    await tester.pumpWidget(_wrap(
      const GlowCard(child: Text('внутри карточки')),
    ));
    expect(find.text('внутри карточки'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PulseDot animated пампится без исключений', (tester) async {
    await tester.pumpWidget(_wrap(const PulseDot()));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byType(PulseDot), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Глушим контроллер-repeat.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('PulseDot animated:false — статичная точка', (tester) async {
    await tester.pumpWidget(_wrap(const PulseDot(animated: false)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PulseDot), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('AuroraText показывает текст (animated и статично)',
      (tester) async {
    await tester.pumpWidget(_wrap(const AuroraText('Северное сияние')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Северное сияние'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_wrap(
      const AuroraText('Статичный заголовок', animated: false),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Статичный заголовок'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
