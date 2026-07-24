// Тесты звёздного неба с полярным сиянием (StarsBackground).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/widgets/fx/stars_background.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('StarsBackground animated пампится без исключений',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const StarsBackground(child: Center(child: Text('контент'))),
    ));
    // Несколько кадров живой анимации.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('контент'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Глушим тикеры, чтобы не висели таймеры (грабля из Altron).
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('StarsBackground animated:false — статичный кадр без тикера',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const StarsBackground(
        animated: false,
        child: Center(child: Text('статика')),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('статика'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('StarsBackground intensity 0 и 1 рисуются без исключений',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const StarsBackground(
        intensity: 0,
        animated: false,
        child: SizedBox.expand(),
      ),
    ));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_wrap(
      const StarsBackground(
        intensity: 1,
        animated: false,
        child: SizedBox.expand(),
      ),
    ));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('StarsBackground переключение animated на лету', (tester) async {
    await tester.pumpWidget(_wrap(
      const StarsBackground(animated: true, child: Text('т')),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(_wrap(
      const StarsBackground(animated: false, child: Text('т')),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
