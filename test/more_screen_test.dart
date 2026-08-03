/// Виджет-тесты экрана «Ещё»: рендер списка разделов, тап открывает каждый
/// подэкран (настройки/брокеры/о приложении/конфиденциальность/правовая
/// информация).
///
/// StarsBackground крутит бесконечный тикер — pumpAndSettle не используем,
/// фиксированный «отстой» кадров и в конце теста глушим тикеры (грабля из
/// Altron, см. fx_stars_test.dart).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/l10n/app_localizations.dart';
import 'package:polaris/screens/more/about_screen.dart';
import 'package:polaris/screens/more/brokers_screen.dart';
import 'package:polaris/screens/more/legal_screen.dart';
import 'package:polaris/screens/more/more_screen.dart';
import 'package:polaris/screens/more/privacy_screen.dart';
import 'package:polaris/screens/more/settings_screen.dart';
import 'package:polaris/services/notifications.dart';
import 'package:polaris/services/storage.dart';
import 'package:polaris/state/app_scope.dart';
import 'package:polaris/state/app_settings.dart';
import 'package:polaris/state/chat_state.dart';
import 'package:polaris/state/learn_state.dart';
import 'package:polaris/state/market_state.dart';
import 'package:polaris/state/portfolio_state.dart';

Widget _wrap(Widget child) {
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
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  testWidgets('MoreScreen рендерит все разделы', (tester) async {
    await tester.pumpWidget(_wrap(const MoreScreen()));
    await _settle(tester);

    expect(find.text('Ещё'), findsOneWidget);
    expect(find.text('Настройки'), findsOneWidget);
    expect(find.text('Готов к настоящим инвестициям?'), findsOneWidget);
    expect(find.text('О приложении'), findsOneWidget);
    expect(find.text('Конфиденциальность'), findsOneWidget);
    expect(find.text('Правовая информация'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Тап на «Готов к настоящим инвестициям?» открывает BrokersScreen',
      (tester) async {
    await tester.pumpWidget(_wrap(const MoreScreen()));
    await _settle(tester);

    await tester.tap(find.text('Готов к настоящим инвестициям?'));
    await _settle(tester);

    expect(find.byType(BrokersScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Тап на «О приложении» открывает AboutScreen', (tester) async {
    await tester.pumpWidget(_wrap(const MoreScreen()));
    await _settle(tester);

    await tester.tap(find.text('О приложении'));
    await _settle(tester);

    expect(find.byType(AboutScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Тап на «Конфиденциальность» открывает PrivacyScreen',
      (tester) async {
    await tester.pumpWidget(_wrap(const MoreScreen()));
    await _settle(tester);

    await tester.tap(find.text('Конфиденциальность'));
    await _settle(tester);

    expect(find.byType(PrivacyScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Тап на «Правовая информация» открывает LegalScreen',
      (tester) async {
    await tester.pumpWidget(_wrap(const MoreScreen()));
    await _settle(tester);

    await tester.tap(find.text('Правовая информация'));
    await _settle(tester);

    expect(find.byType(LegalScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Тап на «Настройки» открывает реальный SettingsScreen с выбором языка',
      (tester) async {
    await tester.pumpWidget(_wrap(const MoreScreen()));
    await _settle(tester);

    await tester.tap(find.text('Настройки'));
    await _settle(tester);

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Язык'), findsOneWidget);

    // Остальные секции ниже видимой области.
    //
    // ⚠️ Раньше здесь была прокрутка ровно на 500 пикселей — и тест краснел
    // от любой новой секции на экране: одни надписи ещё не доехали, другие
    // уже уехали вверх. Прокручиваем ДО нужной надписи: проверяется «секция
    // есть», а не «секция на такой-то высоте».
    final list = find.byType(Scrollable).first;
    for (final label in const [
      'Уведомления',
      'Настоящие цены',
      'Сбросить портфель',
    ]) {
      await tester.scrollUntilVisible(find.text(label), 120, scrollable: list);
      await _settle(tester);
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
