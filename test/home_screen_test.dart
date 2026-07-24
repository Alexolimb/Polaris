import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/l10n/app_localizations.dart';
import 'package:polaris/screens/home/home_screen.dart';
import 'package:polaris/services/market_repo.dart';
import 'package:polaris/services/sim_engine.dart';
import 'package:polaris/services/notifications.dart';
import 'package:polaris/services/storage.dart';
import 'package:polaris/state/app_scope.dart';
import 'package:polaris/state/app_settings.dart';
import 'package:polaris/state/chat_state.dart';
import 'package:polaris/state/learn_state.dart';
import 'package:polaris/state/market_state.dart';
import 'package:polaris/state/portfolio_state.dart';
import 'package:polaris/widgets/chart/polaris_chart.dart';

Widget _wrap(PortfolioState p, MarketState m) {
  final settings = AppSettings(storage: MemoryStorage());
  return AppScope(
    portfolio: p,
    market: m,
    chat: ChatState(storage: MemoryStorage()),
    learn: LearnState(storage: MemoryStorage()),
    settings: settings,
    notifications: NotificationsController(
        gateway: FakeNotificationsGateway(), settings: settings),
    child: const MaterialApp(
      locale: Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: HomeScreen()),
    ),
  );
}

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('пустой портфель показывает приглашение начать', (tester) async {
    final p = PortfolioState(storage: MemoryStorage());
    final m = MarketState(repo: MarketRepo.local(), autoPoll: false);
    await m.init();
    await tester.pumpWidget(_wrap(p, m));
    await _settle(tester);

    expect(find.text('Портфель пока пуст'), findsOneWidget);
    // Стартовая стоимость = $10 000.
    expect(find.textContaining('10,000'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('портфель с позицией показывает строку и стоимость',
      (tester) async {
    final p = PortfolioState(storage: MemoryStorage());
    await p.buy('AAPL', 200000, 20000); // 10 шт по $200
    final m = MarketState(repo: MarketRepo.local(), autoPoll: false);
    await m.init();
    await tester.pumpWidget(_wrap(p, m));
    await _settle(tester);

    expect(find.text('AAPL'), findsWidgets);
    expect(find.byType(PolarisSparkline), findsWidgets);
    expect(find.text('Портфель пока пуст'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('кнопка «начать заново» обнуляет портфель', (tester) async {
    final p = PortfolioState(storage: MemoryStorage());
    await p.buy('AAPL', 500000, 20000);
    final m = MarketState(repo: MarketRepo.local(), autoPoll: false);
    await m.init();
    await tester.pumpWidget(_wrap(p, m));
    await _settle(tester);

    await tester.tap(find.byTooltip('Начать заново'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Начать заново'));
    await _settle(tester);

    expect(p.cashCents, startingCashCents);
    expect(p.positions, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
