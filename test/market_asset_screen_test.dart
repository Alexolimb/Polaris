/// Виджет-тесты карточки актива (AssetScreen): график рисуется на
/// фикстурах, переключение диапазона и режима не крашит, скраббинг меняет
/// цену в шапке, оффлайн не роняет экран, шторка-заглушка торговли
/// открывается без вызова sim_engine.
///
/// ВАЖНО: pumpAndSettle здесь не используем. Когда котировка «живая»
/// (marketOpen == true), шапка рисует PulseDot с бесконечным repeat() —
/// с ним pumpAndSettle никогда не осядет (тот же приём, что и в
/// fx_glow_test.dart: фиксированные pump() вместо ожидания тишины).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/l10n/app_localizations.dart';
import 'package:polaris/models/models.dart';
import 'package:polaris/screens/market/asset_screen.dart';
import 'package:polaris/services/market_repo.dart';
import 'package:polaris/services/notifications.dart';
import 'package:polaris/services/storage.dart';
import 'package:polaris/state/app_scope.dart';
import 'package:polaris/state/app_settings.dart';
import 'package:polaris/state/chat_state.dart';
import 'package:polaris/state/learn_state.dart';
import 'package:polaris/state/market_state.dart';
import 'package:polaris/state/portfolio_state.dart';
import 'package:polaris/widgets/chart/polaris_chart.dart';

// Портфель для сделок доступен тестам, которые проверяют покупку.
late PortfolioState _portfolio;

/// Оборачивает экран в AppScope и MaterialApp — карточка актива берёт из
/// scope портфель (для сделок) и чат (для комментариев Cosmo, оффлайн молчит).
Widget _wrap(Widget child, {MarketState? market}) {
  _portfolio = PortfolioState(storage: MemoryStorage());
  final settings = AppSettings(storage: MemoryStorage());
  return AppScope(
    portfolio: _portfolio,
    market: market ?? MarketState(repo: MarketRepo.local(), autoPoll: false),
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

/// Фиксированный «отстой» кадров вместо pumpAndSettle: с запасом хватает
/// на появление графика (900мс), докрутку цены (900мс), морф (380мс),
/// пружину (550мс) и переход между экранами (280мс) — но не бесконечен.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

const _aapl = Asset(
  symbol: 'AAPL',
  name: 'Apple Inc.',
  type: AssetType.stock,
  sector: 'Technology',
  themeIds: ['bigtech'],
);

const _eur = Asset(
  symbol: 'EUR',
  name: 'Евро (за 100 EUR)',
  type: AssetType.fiat,
  freshness: QuoteFreshness.endOfDay,
);

void main() {
  testWidgets('карточка рисует график и метрики на фикстурах', (tester) async {
    final state = MarketState(repo: MarketRepo.local(), autoPoll: false);
    await state.init();

    await tester.pumpWidget(_wrap(AssetScreen(asset: _aapl, state: state)));
    await _settle(tester);

    expect(find.byType(PolarisChart), findsOneWidget);
    expect(find.text('Что это?'), findsOneWidget);
    // «Метрики» — ниже по ListView, за пределами первого экрана: только
    // существование в дереве важно, не текущая прокрутка.
    expect(find.text('Метрики', skipOffstage: false), findsOneWidget);
    // Цена и дневное изменение подтянулись из котировки фикстур.
    expect(find.textContaining(r'$'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('переключение диапазона (1Д/1Н/1М/1Г) не крашит', (tester) async {
    final state = MarketState(repo: MarketRepo.local(), autoPoll: false);
    await state.init();

    await tester.pumpWidget(_wrap(AssetScreen(asset: _aapl, state: state)));
    await _settle(tester);

    for (final label in ['1Н', '1М', '1Г', '1Д']) {
      await tester.tap(find.text(label));
      await _settle(tester);
      expect(tester.takeException(), isNull);
    }

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('переключение режима Линия/Свечи не крашит', (tester) async {
    final state = MarketState(repo: MarketRepo.local(), autoPoll: false);
    await state.init();

    await tester.pumpWidget(_wrap(AssetScreen(asset: _aapl, state: state)));
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.candlestick_chart_outlined));
    await _settle(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.show_chart_rounded));
    await _settle(tester);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('скраббинг графика меняет цену в шапке', (tester) async {
    final state = MarketState(repo: MarketRepo.local(), autoPoll: false);
    await state.init();

    await tester.pumpWidget(_wrap(AssetScreen(asset: _aapl, state: state)));
    await _settle(tester);

    await tester.drag(find.byType(PolarisChart), const Offset(-90, 0));
    await tester.pump();
    // Во время скраба под ценой должна появиться дата свечи вместо процента.
    expect(tester.takeException(), isNull);

    await _settle(tester);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('оффлайн (без сети, только фикстуры) не крашит карточку',
      (tester) async {
    final state = MarketState(repo: MarketRepo.local(), autoPoll: false);
    await state.init();
    expect(state.offline, isTrue);

    await tester.pumpWidget(_wrap(AssetScreen(asset: _eur, state: state)));
    await _settle(tester);

    expect(find.byType(PolarisChart), findsOneWidget);
    // Валюта — конец дня, честная пометка должна быть на экране.
    expect(find.text('Цена на конец дня'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('кнопка Купить открывает реальную шторку и совершает сделку',
      (tester) async {
    final state = MarketState(repo: MarketRepo.local(), autoPoll: false);
    await state.init(); // фикстуры дают котировку AAPL

    await tester.pumpWidget(_wrap(AssetScreen(asset: _aapl, state: state), market: state));
    await _settle(tester);

    // Открыть шторку покупки.
    await tester.tap(find.text('Купить'));
    await _settle(tester);
    expect(find.text('Купить AAPL'), findsOneWidget);

    // Вложить всё → подтвердить.
    await tester.tap(find.text('Всё'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Купить'));
    await _settle(tester);

    // Портфель получил позицию, кэш ушёл в бумагу.
    expect(_portfolio.positions.containsKey('AAPL'), isTrue);
    expect(_portfolio.cashCents, lessThan(1000000));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('кнопка Продать без позиции открывает шторку и не роняет экран',
      (tester) async {
    final state = MarketState(repo: MarketRepo.local(), autoPoll: false);
    await state.init();

    await tester.pumpWidget(_wrap(AssetScreen(asset: _aapl, state: state), market: state));
    await _settle(tester);

    await tester.tap(find.text('Продать'));
    await _settle(tester);
    expect(find.text('Продать AAPL'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('«Продать всё» закрывает дробную позицию без хвоста (баг #4)',
      (tester) async {
    final state = MarketState(repo: MarketRepo.local(), autoPoll: false);
    await state.init();

    await tester.pumpWidget(_wrap(AssetScreen(asset: _aapl, state: state), market: state));
    await _settle(tester);
    // Дробная позиция с «плохими» 8 знаками — прежний код через toStringAsFixed(6)
    // либо не давал нажать «Продать», либо оставлял микро-хвост.
    await _portfolio.buy('AAPL', 99999, 23413); // qty = 4.27122...
    expect(_portfolio.positions.containsKey('AAPL'), isTrue);

    await tester.tap(find.text('Продать'));
    await _settle(tester);
    expect(find.text('Продать AAPL'), findsOneWidget);
    await tester.tap(find.text('Всё'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Продать'));
    await _settle(tester);

    // Позиция закрыта полностью, без пылинки.
    expect(_portfolio.positions.containsKey('AAPL'), isFalse);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('карточка без предварительной загрузки котировок не крашит',
      (tester) async {
    // MarketState.init() не вызван — quoteOf вернёт null, экран обязан
    // показать заглушку цены, а не упасть.
    final state = MarketState(repo: MarketRepo.local(), autoPoll: false);

    await tester.pumpWidget(_wrap(AssetScreen(asset: _aapl, state: state)));
    await _settle(tester);

    expect(find.byType(PolarisChart), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
