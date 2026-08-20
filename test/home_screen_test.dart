import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/l10n/app_localizations.dart';
import 'package:polaris/models/models.dart';
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

  /// Экран обязан СКАЗАТЬ про перерасход, а не показывать «всё хорошо».
  ///
  /// Раньше приложение решало это молча: покупку, на которую не хватило,
  /// просто выбрасывало вместе с бумагой и историей. Теперь минус на экране
  /// честный, названа виноватая сделка и есть кнопка убрать её руками.
  testWidgets('счёт в минусе: экран называет сделку и даёт её убрать',
      (tester) async {
    // Тот самый случай: сложили два устройства по 6000 из 10 000 каждое.
    Trade pokupka(String sym, int cents, int minuta) => Trade(
          id: '',
          uid: 'tr_$sym',
          symbol: sym,
          side: TradeSide.buy,
          qty: cents / 10000,
          priceCents: 10000,
          totalCents: cents,
          ts: DateTime(2026, 8, 1, 10, minuta),
        );

    final p = PortfolioState(storage: MemoryStorage());
    await p.load();
    await p.podgotovitUid('noutbuk');
    await p.primenitSliyanie(
      trades: [
        pokupka('AAPL', 300000, 1),
        pokupka('MSFT', 300000, 2),
        pokupka('TSLA', 300000, 3),
        pokupka('NVDA', 300000, 4),
      ],
      dividends: const [],
      deleted: const {},
    );
    expect(p.cashCents, -200000, reason: 'минус честный, а не спрятанный');

    final m = MarketState(repo: MarketRepo.local(), autoPoll: false);
    await m.init();
    await tester.pumpWidget(_wrap(p, m));
    await _settle(tester);

    expect(find.textContaining('потратил больше, чем было на счёте'),
        findsOneWidget);
    // Виноватая сделка названа: бумага, сумма и дата.
    expect(find.textContaining('NVDA · \$3,000.00 · 01.08.2026'), findsOneWidget);

    // И её можно убрать руками — прямо отсюда, но только после ясного «да»:
    // одно случайное касание не должно стирать запись навсегда.
    await tester.tap(find.widgetWithText(TextButton, 'Убрать'));
    await _settle(tester);
    expect(find.text('Убрать сделку?'), findsOneWidget);
    expect(p.trades, hasLength(4), reason: 'до подтверждения ничего не убрано');

    await tester.tap(find.widgetWithText(FilledButton, 'Убрать'));
    await _settle(tester);

    expect(p.cashCents, 100000, reason: '10 000 − 9 000 = 1 000');
    expect(p.positions.containsKey('NVDA'), isFalse);
    expect(p.trades, hasLength(3));
    expect(find.textContaining('потратил больше, чем было на счёте'),
        findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
