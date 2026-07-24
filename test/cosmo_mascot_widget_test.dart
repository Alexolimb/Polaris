// Тесты маскота Cosmo (CosmoMascot): каждое настроение пампится без
// исключений, animated true/false, смена mood на лету.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/widgets/cosmo/cosmo_mascot.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  for (final mood in CosmoMood.values) {
    testWidgets('CosmoMascot $mood animated:true пампится без исключений',
        (tester) async {
      await tester.pumpWidget(_wrap(CosmoMascot(mood: mood)));
      // Несколько кадров живой анимации — достаточно, чтобы задеть моргание,
      // подскок, звёздочки и искры (циклы короче 2.5-4с).
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      // Глушим тикеры, чтобы не висели таймеры (грабля из Altron).
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('CosmoMascot $mood animated:false — статичная поза',
        (tester) async {
      await tester.pumpWidget(_wrap(CosmoMascot(mood: mood, animated: false)));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('CosmoMascot смена mood на лету не роняет', (tester) async {
    await tester.pumpWidget(_wrap(const CosmoMascot(mood: CosmoMood.idle)));
    await tester.pump(const Duration(milliseconds: 200));
    for (final mood in CosmoMood.values) {
      await tester.pumpWidget(_wrap(CosmoMascot(mood: mood)));
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('CosmoMascot переключение animated на лету', (tester) async {
    await tester.pumpWidget(_wrap(
      const CosmoMascot(mood: CosmoMood.celebrate, animated: true),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(_wrap(
      const CosmoMascot(mood: CosmoMood.celebrate, animated: false),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(_wrap(
      const CosmoMascot(mood: CosmoMood.celebrate, animated: true),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('CosmoMascot разные размеры не роняют painter', (tester) async {
    for (final size in [16.0, 26.0, 40.0, 120.0, 240.0]) {
      await tester.pumpWidget(_wrap(
        CosmoMascot(size: size, mood: CosmoMood.happy, animated: false),
      ));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
