/// Тесты локализации (волна 3а): смена языка в MaterialApp.locale меняет
/// видимые строки, и смена [AppSettings.localePref] в бегущем приложении
/// (main.dart, PolarisApp) сразу перерисовывает MaterialApp на новый язык —
/// без перезапуска.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/l10n/app_localizations.dart';
import 'package:polaris/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:polaris/screens/more/more_screen.dart';
import 'package:polaris/services/notifications.dart';
import 'package:polaris/services/storage.dart';
import 'package:polaris/state/app_scope.dart';
import 'package:polaris/state/app_settings.dart';
import 'package:polaris/state/chat_state.dart';
import 'package:polaris/state/learn_state.dart';
import 'package:polaris/state/market_state.dart';
import 'package:polaris/state/portfolio_state.dart';

Widget _wrapMore(Locale locale) {
  final settings = AppSettings(storage: MemoryStorage());
  return AppScope(
    portfolio: PortfolioState(storage: MemoryStorage()),
    market: MarketState(autoPoll: false),
    chat: ChatState(storage: MemoryStorage()),
    learn: LearnState(storage: MemoryStorage()),
    settings: settings,
    notifications: NotificationsController(
        gateway: FakeNotificationsGateway(), settings: settings),
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const MoreScreen(),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  testWidgets('заголовок вкладки «Ещё» появляется на en/ru/es', (tester) async {
    await tester.pumpWidget(_wrapMore(const Locale('en')));
    await _settle(tester);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    await tester.pumpWidget(_wrapMore(const Locale('ru')));
    await _settle(tester);
    expect(find.text('Ещё'), findsOneWidget);
    expect(find.text('Настройки'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    await tester.pumpWidget(_wrapMore(const Locale('es')));
    await _settle(tester);
    expect(find.text('Más'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'смена AppSettings.localePref в живом PolarisApp сразу меняет язык UI '
      '(без перезапуска)', (tester) async {
    SharedPreferences.setMockInitialValues({}); // чистая установка
    await tester.pumpWidget(const PolarisApp());
    // Тот же ритм пампинга, что и в widget_test.dart («первый запуск»).
    await tester.pump();
    await tester.pump(const Duration(seconds: 2)); // заставка
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // загрузка настроек

    // По умолчанию (locale: null, auto) в тестовом окружении Flutter язык
    // системы — en, так что онбординг должен быть на английском.
    expect(find.text('Hi, I\'m Cosmo'), findsOneWidget);

    // Достаём AppSettings из дерева и переключаем язык напрямую — эмулируем
    // то, что делает SettingsScreen при тапе на пункт языка.
    final settingsElement = find
        .byWidgetPredicate((w) => w is AppScope)
        .evaluate()
        .first;
    final settings = (settingsElement.widget as AppScope).settings;
    await settings.setLocalePref(LocalePref.ru);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Привет, я Cosmo'), findsOneWidget);
    expect(find.text('Hi, I\'m Cosmo'), findsNothing);

    await settings.setLocalePref(LocalePref.es);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Hola, soy Cosmo'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
