/// Тесты скелетонов загрузки. Смысл — не «сколько плашек нарисовалось», а три
/// обещания: заготовки появляются, блик уважает системное «уменьшить
/// анимацию», и скелетон вне SkeletonPulse не падает (иначе одна забытая
/// обёртка роняла бы экран загрузки — самое неудачное место для краша).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/widgets/fx/skeleton.dart';

Widget _wrap(Widget child, {bool reduceMotion = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  testWidgets('список заготовок рендерится и не роняет кадр', (tester) async {
    await tester.pumpWidget(_wrap(const SkeletonList(rows: 4)));
    await tester.pump(const Duration(milliseconds: 300));

    // 4 строки: у каждой кружок + две строки текста + две справа = 5 плашек,
    // плюс заголовок секции. Проверяем «не меньше», а не точное число:
    // геометрию строки менять можно, а вот исчезнуть она не должна.
    expect(find.byType(SkeletonBox), findsAtLeast(4 * 5 + 1));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('без правого блока плашек меньше', (tester) async {
    await tester.pumpWidget(_wrap(const SkeletonList(rows: 3)));
    await tester.pump();
    final withTrailing = tester.widgetList(find.byType(SkeletonBox)).length;

    await tester.pumpWidget(
        _wrap(const SkeletonList(rows: 3, trailing: false)));
    await tester.pump();
    final withoutTrailing = tester.widgetList(find.byType(SkeletonBox)).length;

    expect(withoutTrailing, lessThan(withTrailing));

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('«уменьшить анимацию» останавливает блик', (tester) async {
    await tester.pumpWidget(
        _wrap(const SkeletonList(rows: 2), reduceMotion: true));
    await tester.pump(const Duration(milliseconds: 200));

    // Фаза фиксированная — значит бесконечного тикера нет и pumpAndSettle
    // осядет. Именно это и проверяем: с вечной анимацией он завис бы.
    await tester.pumpAndSettle();
    expect(find.byType(SkeletonBox), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('одинокая плашка без SkeletonPulse рисуется статично',
      (tester) async {
    await tester.pumpWidget(_wrap(const SkeletonBox(width: 50, height: 12)));
    await tester.pumpAndSettle();

    expect(find.byType(SkeletonBox), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
