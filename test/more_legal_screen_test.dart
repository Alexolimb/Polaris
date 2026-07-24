/// Виджет-тесты «Правовая информация»: обязательные дисклеймеры —
/// образовательный симулятор, не инвестиционная рекомендация, прошлые
/// результаты не гарантируют будущих, данные могут задерживаться.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/l10n/app_localizations.dart';
import 'package:polaris/screens/more/legal_screen.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
}

/// Экран длинный (6 информационных блоков) — расширяем поверхность, чтобы
/// весь ListView поместился без скролла (офскрин-виджеты в SliverList не
/// инфлейтятся и find их не находит).
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4500);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('LegalScreen содержит все ключевые дисклеймеры', (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_wrap(const LegalScreen()));
    await _settle(tester);

    expect(find.text('Правовая информация'), findsOneWidget);
    expect(find.textContaining('Образовательный симулятор'), findsOneWidget);
    expect(find.textContaining('Не инвестиционная рекомендация'), findsOneWidget);
    expect(find.textContaining('Прошлое не гарантирует будущего'), findsOneWidget);
    expect(find.textContaining('задерживаться'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('LegalScreen честно объясняет ограничения Cosmo', (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_wrap(const LegalScreen()));
    await _settle(tester);

    expect(find.textContaining('Cosmo'), findsWidgets);
    expect(find.textContaining('не советник'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
