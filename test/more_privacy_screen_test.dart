/// Виджет-тесты «Конфиденциальность»: простыми словами про локальное
/// хранение, что уходит на сервер (анонимные котировки + вопросы Cosmo) и
/// ссылка на полный текст политики (плейсхолдер).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/l10n/app_localizations.dart';
import 'package:polaris/screens/more/privacy_screen.dart';

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

/// Экран длинный (4 информационных блока + ссылка на политику) — расширяем
/// поверхность, чтобы весь ListView поместился без скролла (офскрин-виджеты
/// в SliverList не инфлейтятся и find их не находит).
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('PrivacyScreen объясняет локальное хранение данных',
      (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_wrap(const PrivacyScreen()));
    await _settle(tester);

    expect(find.text('Конфиденциальность'), findsOneWidget);
    expect(find.textContaining('устройстве'), findsWidgets);
    expect(find.textContaining('аккаунта'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('PrivacyScreen честно перечисляет, что уходит на сервер',
      (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_wrap(const PrivacyScreen()));
    await _settle(tester);

    expect(find.textContaining('котировок'), findsWidgets);
    expect(find.textContaining('Cosmo'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('PrivacyScreen даёт ссылку на полный текст политики',
      (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_wrap(const PrivacyScreen()));
    await _settle(tester);

    expect(find.textContaining('Полный текст политики'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
