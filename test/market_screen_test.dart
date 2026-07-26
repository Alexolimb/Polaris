/// Виджет-тесты экрана «Рынки»: рендер списка на фикстурах, поиск,
/// открытие карточки актива по тапу, честный офлайн-режим.
/// autoPoll:false везде — таймер опроса котировок тестам не нужен.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/l10n/app_localizations.dart';
import 'package:polaris/screens/market/asset_screen.dart';
import 'package:polaris/screens/market/market_screen.dart';
import 'package:polaris/services/lessons.dart';
import 'package:polaris/services/market_repo.dart';
import 'package:polaris/state/market_state.dart';

/// Bundle, читающий настоящие файлы проекта с диска: в `flutter test` ассеты
/// не собираются, а проверять хочется именно тот контент, который уедет в
/// сборку, а не копию-фикстуру (иначе тест разойдётся с реальностью).
class _AssetFileBundle extends CachingAssetBundle {
  final Map<String, String> paths;
  _AssetFileBundle(this.paths);

  @override
  Future<ByteData> load(String key) async {
    final path = paths[key];
    if (path == null) throw FlutterError('нет ассета: $key');
    final bytes = File(path).readAsBytesSync();
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final path = paths[key];
    if (path == null) throw FlutterError('нет ассета: $key');
    return utf8.decode(File(path).readAsBytesSync());
  }
}

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

/// Фиксированный «отстой» кадров вместо pumpAndSettle. Причин две:
/// (1) карточка актива живого тикера (marketOpen == true) рисует PulseDot с
/// бесконечным repeat(); (2) с 25.07.2026 экран «Рынки» и карточка актива
/// рисуют звёздное небо (StarsBackground) — у него свой вечный Ticker.
/// pumpAndSettle с ними не осядет никогда.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('список рендерится на оффлайн-фикстурах', (tester) async {
    final state = MarketState(repo: MarketRepo.local(), autoPoll: false);
    await tester.pumpWidget(_wrap(MarketScreen(state: state)));
    await _settle(tester);

    expect(find.text('Рынки'), findsOneWidget);
    // Хотя бы несколько фикстурных активов на экране.
    expect(find.text('Apple Inc.'), findsOneWidget);
    // Крипта — далеко внизу списка, за пределами первого экрана: finder'ы
    // по умолчанию пропускают то, что сейчас проскроллено за viewport
    // (skipOffstage:true) — нам важно, что оно есть в дереве, а не что
    // именно сейчас видно глазу.
    expect(find.text('Bitcoin', skipOffstage: false), findsOneWidget);
    // Секции класса активов.
    expect(find.text('АКЦИИ'), findsOneWidget);
    expect(find.text('КРИПТА', skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('офлайн честно показывает бейдж «демо-данные»', (tester) async {
    final state = MarketState(repo: MarketRepo.local(), autoPoll: false);
    await tester.pumpWidget(_wrap(MarketScreen(state: state)));
    await _settle(tester);

    expect(state.offline, isTrue);
    expect(find.text('демо-данные'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('поиск фильтрует список по тикеру и по имени', (tester) async {
    final state = MarketState(repo: MarketRepo.local(), autoPoll: false);
    await tester.pumpWidget(_wrap(MarketScreen(state: state)));
    await _settle(tester);

    await tester.enterText(find.byType(TextField), 'AAPL');
    await _settle(tester);
    expect(find.text('Apple Inc.'), findsOneWidget);
    expect(find.text('Bitcoin'), findsNothing);
    expect(find.text('Microsoft'), findsNothing);

    // Поиск по имени (не только по тикеру).
    await tester.enterText(find.byType(TextField), 'bitcoin');
    await _settle(tester);
    expect(find.text('Bitcoin'), findsOneWidget);
    expect(find.text('Apple Inc.'), findsNothing);

    // Ничего не найдено — честная подпись, без краша.
    await tester.enterText(find.byType(TextField), 'zzz_nonexistent');
    await _settle(tester);
    expect(find.text('Ничего не нашлось'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('тап по активу открывает карточку AssetScreen', (tester) async {
    final state = MarketState(repo: MarketRepo.local(), autoPoll: false);
    await tester.pumpWidget(_wrap(MarketScreen(state: state)));
    await _settle(tester);

    await tester.tap(find.text('Apple Inc.'));
    await _settle(tester);

    expect(find.byType(AssetScreen), findsOneWidget);
    expect(find.text('AAPL'), findsWidgets);
    expect(tester.takeException(), isNull);

    // Возврат назад не крашит.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await _settle(tester);
    expect(find.byType(AssetScreen), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('чип темы фильтрует список без краша', (tester) async {
    // Экран шире стандартных 800 px: после сведения каталога с сервером тем
    // стало 12 вместо 6, и на узком экране нужный чип уезжает за край
    // горизонтальной ленты — tap по нему не проходит.
    tester.view.physicalSize = const Size(2400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = MarketState(repo: MarketRepo.local(), autoPoll: false);
    await tester.pumpWidget(_wrap(MarketScreen(state: state)));
    await _settle(tester);

    await tester.tap(find.text('Дивидендные гиганты'));
    await _settle(tester);
    expect(find.text('Johnson & Johnson'), findsOneWidget);
    expect(find.text('Bitcoin'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('у чипов тем появляются эмодзи из ассетов', (tester) async {
    // Регрессия 26.07.2026: файлы assets/content/themes*.json (RU/EN/ES) с
    // эмодзи, цветами и описаниями лежали в сборке, парсились — и никуда не
    // выводились. Сервер отдаёт только id и название, поэтому чипы были
    // безликими. Тест держит связку «ассет → чип»: если её снова порвут,
    // упадёт здесь, а не тихо обеднеет интерфейс.
    tester.view.physicalSize = const Size(2400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = MarketState(repo: MarketRepo.local(), autoPoll: false);
    // Ассеты проекта в `flutter test` не собираются, rootBundle их не отдаёт —
    // поэтому подсовываем настоящий themes.json через фейковый bundle.
    final themesRepo = LessonsRepo(
      bundle: _AssetFileBundle({
        LessonsPaths.themesBase: 'assets/content/themes.json',
      }),
    );
    await tester.pumpWidget(
        _wrap(MarketScreen(state: state, themesRepo: themesRepo)));
    await _settle(tester);

    // skipOffstage:false — чипы лежат в горизонтальной ленте, часть уезжает
    // за край viewport; нам важно, что эмодзи попало в дерево.
    expect(find.text('🤖', skipOffstage: false), findsOneWidget); // ai
    expect(find.text('💰', skipOffstage: false), findsWidgets); // dividend-giants
    // Название по-прежнему приходит с сервера, эмодзи — из ассета.
    expect(find.text('Дивидендные гиганты'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
