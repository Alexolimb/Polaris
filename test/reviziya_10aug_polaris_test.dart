/// Ревизия 10.08.2026 — молчаливые беды Polaris.
///
/// Каждая проверка здесь ПАДАЕТ без своей починки. Правило одно: молчаливый
/// отказ обязан стать громким, а настоящие данные нельзя затирать пустотой.
///
/// Что закрыто этим файлом:
///   1. Запись на диск никем не проверялась («не сохранил» выбрасывалось).
///   2. Сделка списывала деньги ДО сохранения (отказ → двойная покупка).
///   3. «Учёба» навсегда застывала на серых заготовках и затирала прогресс.
///   4. Пустой ответ по дивидендам запоминался на час как «бумага не платит».
///   5. Настоящая цена рядом с ВЫДУМАННЫМ графиком и выдуманным «диапазоном».
library;

// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/l10n/app_localizations.dart';
import 'package:polaris/models/models.dart';
import 'package:polaris/screens/learn/learn_screen.dart';
import 'package:polaris/screens/market/asset_screen.dart';
import 'package:polaris/services/api.dart';
import 'package:polaris/services/lessons.dart';
import 'package:polaris/services/market_repo.dart';
import 'package:polaris/services/notifications.dart';
import 'package:polaris/services/storage.dart';
import 'package:polaris/state/app_scope.dart';
import 'package:polaris/state/app_settings.dart';
import 'package:polaris/state/chat_state.dart';
import 'package:polaris/state/learn_state.dart';
import 'package:polaris/state/market_state.dart';
import 'package:polaris/state/portfolio_state.dart';
import 'package:polaris/widgets/fx/skeleton.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

// ---------------------------------------------------------------- заглушки

/// Хранилище, которое честно отвечает «не сохранил».
class _DiskNeZapisyvaet implements StorageGateway {
  final Map<String, Map<String, dynamic>> data;
  int popytokZapisi = 0;
  bool lomat;

  _DiskNeZapisyvaet({Map<String, Map<String, dynamic>>? seed, this.lomat = true})
      : data = seed ?? {};

  @override
  Future<Map<String, dynamic>?> readJson(String key) async => data[key];

  @override
  Future<void> writeJson(String key, Map<String, dynamic> value) async {
    popytokZapisi++;
    if (lomat) throw Exception('на устройстве нет места');
    data[key] = value;
  }

  @override
  Future<void> remove(String key) async => data.remove(key);
}

/// Хранилище, у которого не читается вообще ничего (права сняты, диск отвалился).
class _DiskNeChitaetsya implements StorageGateway {
  int popytokZapisi = 0;

  @override
  Future<Map<String, dynamic>?> readJson(String key) async =>
      throw Exception('файл не открывается');

  @override
  Future<void> writeJson(String key, Map<String, dynamic> value) async {
    popytokZapisi++;
  }

  @override
  Future<void> remove(String key) async {}
}

/// Системное хранилище, которое на каждую запись отвечает «нет».
class _SistemaGovoritNet extends InMemorySharedPreferencesStore {
  _SistemaGovoritNet() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}

PolarisApi _apiOtvechayushiy(String telo) =>
    PolarisApi(httpGet: (uri, timeout) async => telo);

Widget _vApp(Widget child) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

/// Фиксированный отстой кадров: у экранов бесконечные тикеры (звёзды, пульс),
/// с ними pumpAndSettle не осядет никогда.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

LessonsContent _urokiFikstura() {
  const m1 = Module(
      id: 'm1', title: 'Модуль 1', order: 1, accent: Color(0xFF6C8EFF), emoji: '🌌');
  final l1 = Lesson(
    id: 'l1',
    moduleId: 'm1',
    order: 1,
    title: 'Урок 1',
    screens: const [
      LessonScreen(
          title: 'Экран',
          emoji: '🙂',
          accent: Color(0xFF6C8EFF),
          paragraphs: ['Текст урока'])
    ],
    quiz: const [],
  );
  return LessonsContent(
      modules: const [m1], lessons: [l1], glossary: const [], themes: const []);
}

const _aapl = Asset(
  symbol: 'AAPL',
  name: 'Apple Inc.',
  type: AssetType.stock,
  sector: 'Technology',
  themeIds: ['bigtech'],
);

void main() {
  // =====================================================================
  // 1. Запись на диск никем не проверялась.
  // =====================================================================
  group('«не сохранил» больше не выбрасывается молча', () {
    test('система ответила «нет» — хранилище говорит об этом вслух', () async {
      SharedPreferences.setMockInitialValues({}); // сбрасываем кэш
      SharedPreferencesStorePlatform.instance = _SistemaGovoritNet();

      final s = PrefsStorage();
      await expectLater(
        () => s.writeJson('polaris.portfolio.v1', {'engine': {}}),
        throwsA(isA<StorageWriteFailed>()),
        reason: 'ответ setString «да/нет» раньше никуда не присваивался: '
            'приложение рапортовало об успехе, а на диске не было ничего',
      );

      SharedPreferences.setMockInitialValues({}); // возвращаем рабочее хранилище
    });
  });

  // =====================================================================
  // 2. Сделка списывала деньги ДО сохранения.
  // =====================================================================
  group('сделка, которая не сохранилась, ОТМЕНЯЕТСЯ целиком', () {
    test('покупка не записалась — деньги и позиции на месте, ошибка громкая',
        () async {
      final hranilishche = _DiskNeZapisyvaet();
      final p = PortfolioState(storage: hranilishche);
      await p.load();
      final denegBylo = p.cashCents;

      await expectLater(
        () => p.buy('AAPL', 100000, 20000),
        throwsA(isA<TradeNotSaved>()),
        reason: 'раньше сюда прилетала «неизвестная ошибка», '
            'а деньги уже были списаны',
      );

      expect(p.cashCents, denegBylo, reason: 'деньги обязаны вернуться');
      expect(p.positions, isEmpty, reason: 'бумага не куплена');
      expect(p.trades, isEmpty, reason: 'сделки не было вовсе');
    });

    test('после отказа повторное нажатие покупает ОДИН раз, а не два',
        () async {
      final hranilishche = _DiskNeZapisyvaet();
      final p = PortfolioState(storage: hranilishche);
      await p.load();

      // Первая попытка — диск отказал.
      await expectLater(
          () => p.buy('AAPL', 100000, 20000), throwsA(isA<TradeNotSaved>()));

      // Человек видит ошибку и жмёт «Купить» ещё раз. Диск уже здоров.
      hranilishche.lomat = false;
      await p.buy('AAPL', 100000, 20000);

      expect(p.trades.length, 1,
          reason: 'раньше первая (якобы неудачная) покупка тоже оставалась — '
              'получалось две бумаги вместо одной');
      expect(p.cashCents, 1000000 - 100000);
    });

    test('продажа не записалась — позиция остаётся как была', () async {
      final hranilishche = _DiskNeZapisyvaet(lomat: false);
      final p = PortfolioState(storage: hranilishche);
      await p.load();
      await p.buy('AAPL', 100000, 20000);
      final pozicijaBylo = p.positions['AAPL']!.qty;
      final denegBylo = p.cashCents;

      hranilishche.lomat = true;
      await expectLater(
          () => p.sell('AAPL', pozicijaBylo, 20000),
          throwsA(isA<TradeNotSaved>()));

      expect(p.positions['AAPL']?.qty, pozicijaBylo);
      expect(p.cashCents, denegBylo);
      expect(p.trades.length, 1, reason: 'продажи не было');
    });

    test('дивиденды не записались — начисление откатывается, а не «висит»',
        () async {
      final den = DateTime(2026, 7, 24);
      final hranilishche = _DiskNeZapisyvaet(lomat: false);
      final p = PortfolioState(storage: hranilishche, now: () => den);
      await p.load();
      await p.buy('KO', 100000, 7000);
      final denegBylo = p.cashCents;

      hranilishche.lomat = true;
      await expectLater(
        () => p.applyDueDividends([
          // Отсечка в день покупки: бумагу на эту дату уже держим.
          DividendDue(symbol: 'KO', perShareCents: 50, exDate: den),
        ]),
        throwsA(isA<TradeNotSaved>()),
      );

      expect(p.cashCents, denegBylo,
          reason: 'деньги «на экране, но не на диске» — так нельзя');
      expect(p.dividends, isEmpty);
    });
  });

  // =====================================================================
  // 3. «Учёба» застывала на заготовках и затирала прогресс.
  // =====================================================================
  group('«Учёба»: прогресс не прочитался', () {
    test('приложение об этом ЗНАЕТ, а не ждёт вечно', () async {
      final s = LearnState(storage: _DiskNeChitaetsya());
      await s.load(); // раньше ошибка летела наружу и _loaded оставался false

      expect(s.loaded, isTrue, reason: 'экран обязан перестать «грузиться»');
      expect(s.loadFailed, isTrue, reason: 'и обязан знать, что это беда');
    });

    test('урок не засчитывается и НИЧЕГО не пишет поверх', () async {
      final hranilishche = _DiskNeChitaetsya();
      final s = LearnState(storage: hranilishche);
      await s.load();

      await expectLater(
        () => s.completeLesson('l1', quizCorrect: 1, quizTotal: 1),
        throwsA(isA<LearnProgressNotSaved>()),
      );
      expect(hranilishche.popytokZapisi, 0,
          reason: 'запись пустоты поверх стирала все пройденные уроки и стрик');
      expect(s.completedCount, 0);
    });

    test('запись сорвалась — урок откатывается, а не «пройден до перезапуска»',
        () async {
      final hranilishche = _DiskNeZapisyvaet();
      final s = LearnState(storage: hranilishche);
      await s.load();

      await expectLater(() => s.completeLesson('l1'),
          throwsA(isA<LearnProgressNotSaved>()));
      expect(s.completedCount, 0);
      expect(s.currentStreak, 0);
    });

    testWidgets('экран показывает беду и кнопку «Попробовать снова»',
        (tester) async {
      final s = LearnState(storage: _DiskNeChitaetsya());
      await s.load();

      await tester.pumpWidget(_vApp(Scaffold(
          body: LearnScreen(state: s, content: _urokiFikstura()))));
      await _settle(tester);

      expect(find.byType(SkeletonList), findsNothing,
          reason: 'серые заготовки навсегда — это и есть молчаливый отказ');
      expect(find.text('Попробовать снова'), findsOneWidget);
      expect(find.textContaining('Ничего не потеряно'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });

  // =====================================================================
  // 4. Пустой ответ по дивидендам.
  // =====================================================================
  group('дивиденды: пустой ответ — не приговор бумаге', () {
    test('сервер прислал пустой список — подставляем встроенный календарь',
        () async {
      final repo = MarketRepo(
        api: _apiOtvechayushiy('{"dividends":[]}'),
        now: () => DateTime(2026, 7, 24),
      );
      final events = await repo.dividends('AAPL');

      expect(events, isNotEmpty,
          reason: 'раньше пустота запоминалась на час как «бумага не платит», '
              'и дивиденды не начислялись никогда');
      expect(events.any((e) => e.exDate != null && e.exDate!.isBefore(DateTime(2026, 7, 24))),
          isTrue,
          reason: 'в календаре обязана быть прошедшая отсечка — иначе '
              'начислять нечего');
    });

    test('переименованное поле в ответе сервера — тоже не «не платит»',
        () async {
      // Ровно то, что описано в ревизии: разбор молча выбрасывает записи.
      final repo = MarketRepo(
        api: _apiOtvechayushiy(
            '{"dividends":[{"symbol":"AAPL","exDate":"2026-06-17","cents":86}]}'),
        now: () => DateTime(2026, 7, 24),
      );
      expect(await repo.dividends('AAPL'), isNotEmpty);
    });

    test('настоящий ответ сервера принимается как раньше', () async {
      final repo = MarketRepo(
        api: _apiOtvechayushiy(
            '{"dividends":[{"symbol":"AAPL","exDate":"2026-06-17",'
            '"payDate":"2026-06-24","perShareCents":86}]}'),
        now: () => DateTime(2026, 7, 24),
      );
      final events = await repo.dividends('AAPL');
      expect(events.length, 1);
      expect(events.first.perShareCents, 86);
    });
  });

  // =====================================================================
  // 5. Настоящая цена рядом с выдуманным графиком.
  // =====================================================================
  group('график: приложение читает пометку сервера «учебные данные»', () {
    const teloDemo = '{"candles":[{"t":1783850488637,"o":100,"h":110,"l":90,'
        '"c":105}],"freshness":"demo","disclaimer":"Учебные данные: цены и '
        'дивиденды сгенерированы алгоритмом, это НЕ реальные котировки."}';

    test('сервер честно пометил «demo» — приложение это ВИДИТ', () async {
      final r = await _apiOtvechayushiy(teloDemo)
          .fetchCandles('AAPL', CandleRange.y1);
      expect(r.candles, isNotEmpty);
      expect(r.simulated, isTrue,
          reason: 'поле freshness приходит с сервера, но не читалось');
      expect(r.disclaimer, contains('НЕ реальные'));
    });

    test('сервер молчит о свежести — считаем данные учебными', () async {
      final r = await _apiOtvechayushiy(
              '{"candles":[{"t":1783850488637,"o":100,"h":110,"l":90,"c":105}]}')
          .fetchCandles('AAPL', CandleRange.y1);
      expect(r.simulated, isTrue);
    });

    test('только прямое «realtime» снимает пометку', () async {
      final r = await _apiOtvechayushiy(
              '{"candles":[{"t":1783850488637,"o":100,"h":110,"l":90,"c":105}],'
              '"freshness":"realtime"}')
          .fetchCandles('AAPL', CandleRange.y1);
      expect(r.simulated, isFalse);
    });

    test('репозиторий помнит, откуда взялся график', () async {
      final serverDemo = MarketRepo(api: _apiOtvechayushiy(teloDemo));
      await serverDemo.candles('AAPL', CandleRange.y1);
      expect(serverDemo.candlesAreSimulated('AAPL', CandleRange.y1), isTrue);

      // Свечи, нарисованные случайным блужданием прямо на устройстве.
      final mestnyy = MarketRepo.local();
      await mestnyy.candles('AAPL', CandleRange.y1);
      expect(mestnyy.candlesAreSimulated('AAPL', CandleRange.y1), isTrue);
    });

    testWidgets('на карточке актива стоит честная пометка про график',
        (tester) async {
      final state = MarketState(repo: MarketRepo.local(), autoPoll: false);
      await state.init();

      await tester.pumpWidget(_vApp(AssetScreen(asset: _aapl, state: state)));
      await _settle(tester);

      expect(find.textContaining('Учебный график'), findsOneWidget,
          reason: 'настоящая цена и выдуманная история рядом без единого '
              'намёка — так человек переносит вывод на настоящие деньги');
      // «Диапазон за период» считается из тех же выдуманных свечей.
      expect(find.text('Диапазон за период (учебный график)', skipOffstage: false),
          findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('сделка НЕ проходит по цене из выдуманной свечи',
        (tester) async {
      // Котировок нет (init не звали) — раньше цену для сделки брали из
      // последней СГЕНЕРИРОВАННОЙ свечи, то есть из числа, которого на бирже
      // не существовало.
      final state = MarketState(repo: MarketRepo.local(), autoPoll: false);
      final portfolio = PortfolioState(storage: MemoryStorage());
      final settings = AppSettings(storage: MemoryStorage());

      await tester.pumpWidget(_vApp(AppScope(
        portfolio: portfolio,
        market: state,
        chat: ChatState(storage: MemoryStorage()),
        learn: LearnState(storage: MemoryStorage()),
        settings: settings,
        notifications: NotificationsController(
            gateway: FakeNotificationsGateway(), settings: settings),
        child: AssetScreen(asset: _aapl, state: state),
      )));
      await _settle(tester);

      await tester.tap(find.text('Купить'));
      await _settle(tester);

      expect(find.text('Купить AAPL'), findsNothing,
          reason: 'шторка сделки не должна открываться по придуманной цене');
      expect(find.textContaining('Нет актуальной цены'), findsOneWidget);
      expect(portfolio.trades, isEmpty);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
