// Тесты моушн-ядра: Springy, StaggerIn, CountUpText.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/widgets/fx/motion.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  // ---------------------------------------------------------------- Springy

  testWidgets('Springy вызывает onTap и пружинит без исключений',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(
      Springy(
        onTap: () => tapped = true,
        child: Container(
          width: 80,
          height: 80,
          color: Colors.blue,
          child: const Text('кнопка'),
        ),
      ),
    ));
    await tester.tap(find.text('кнопка'));
    // Прокручиваем пружинный возврат (130мс вперёд + 420мс назад).
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Springy без колбэков просто отдаёт ребёнка', (tester) async {
    await tester.pumpWidget(_wrap(
      const Springy(child: Text('просто текст')),
    ));
    expect(find.text('просто текст'), findsOneWidget);
    expect(find.byType(GestureDetector), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  // -------------------------------------------------------------- StaggerIn

  testWidgets('StaggerIn показывает всех детей после settle', (tester) async {
    final labels = ['первый', 'второй', 'третий', 'четвёртый'];
    await tester.pumpWidget(_wrap(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            StaggerIn(index: i, child: Text(labels[i])),
        ],
      ),
    ));
    await tester.pumpAndSettle();
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
      // Каждый ребёнок полностью проявлен.
      final op = tester.widget<Opacity>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Opacity))
            .first,
      );
      expect(op.opacity, closeTo(1, .01));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  // ------------------------------------------------------------ CountUpText

  test('CountUpText.formatCents форматирует деньги из центов', () {
    expect(CountUpText.formatCents(123456), r'$1,234.56');
    expect(CountUpText.formatCents(0), r'$0.00');
    expect(CountUpText.formatCents(5), r'$0.05');
    expect(CountUpText.formatCents(1000000000), r'$10,000,000.00');
    expect(CountUpText.formatCents(-987), r'-$9.87');
    expect(CountUpText.formatCents(100000, currency: '€'), '€1,000.00');
  });

  testWidgets('CountUpText докручивает до значения', (tester) async {
    await tester.pumpWidget(_wrap(const CountUpText(cents: 123456)));
    // В начале — ещё не целевое значение (крутится с нуля).
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(r'$1,234.56'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text(r'$1,234.56'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('CountUpText animated:false показывает сразу', (tester) async {
    await tester.pumpWidget(_wrap(
      const CountUpText(cents: 999999, animated: false),
    ));
    expect(find.text(r'$9,999.99'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('CountUpText докручивает при смене значения', (tester) async {
    await tester.pumpWidget(_wrap(const CountUpText(cents: 100)));
    await tester.pumpAndSettle();
    expect(find.text(r'$1.00'), findsOneWidget);
    await tester.pumpWidget(_wrap(const CountUpText(cents: 250000)));
    await tester.pumpAndSettle();
    expect(find.text(r'$2,500.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
