/// Виджет-тесты «О приложении»: маскот Cosmo, версия, обязательные
/// плашки-атрибуции источников данных (CoinGecko, open.er-api.com и т.д.,
/// см. server/README.md).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/l10n/app_localizations.dart';
import 'package:polaris/screens/chat/cosmo_screen.dart' show CosmoAvatar;
import 'package:polaris/screens/more/about_screen.dart';

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

/// Экран длинный (аватар + 4 блока + плашки атрибуций) — расширяем
/// поверхность, чтобы весь ListView поместился без скролла (офскрин-виджеты
/// в SliverList не инфлейтятся и find их не находит).
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('AboutScreen показывает название, версию и маскота Cosmo',
      (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_wrap(const AboutScreen()));
    await _settle(tester);

    expect(find.text('Polaris'), findsWidgets);
    expect(find.textContaining('Версия'), findsOneWidget);
    expect(find.byType(CosmoAvatar), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('AboutScreen объясняет, что это симулятор', (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_wrap(const AboutScreen()));
    await _settle(tester);

    expect(find.textContaining('симулятор'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('AboutScreen содержит обязательные плашки-атрибуции источников',
      (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_wrap(const AboutScreen()));
    await _settle(tester);

    expect(find.textContaining('CoinGecko'), findsOneWidget);
    expect(find.textContaining('open.er-api.com'), findsOneWidget);
    expect(find.textContaining('Binance'), findsOneWidget);
    expect(find.textContaining('Yahoo Finance'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
