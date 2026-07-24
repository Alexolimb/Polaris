/// Виджет-тесты «Готов к настоящим инвестициям?»: предупреждения о риске
/// сверху и снизу, список только лицензированных в ЕС брокеров акций, БЕЗ
/// единого криптоброкера/криптообменника, кнопки внешних ссылок
/// присутствуют, но url_launcher реально не вызываем (только проверяем
/// наличие кнопок — тап уходит в platform channel, которого в тестах нет).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/l10n/app_localizations.dart';
import 'package:polaris/screens/more/brokers_screen.dart';

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

/// Экран длинный (6 карточек брокеров + баннеры риска) — обычная тестовая
/// поверхность 800×600 не вмещает всё, а офскрин-виджеты внутри ListView
/// вообще не инфлейтятся (не отрисовать — не найти find'ом). Расширяем
/// поверхность, чтобы весь список поместился без скролла.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 5000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Криптоброкеры/биржи, которых в этом разделе НЕ должно быть ни в каком
/// виде (план 20.07.2026: раздел брокеров — без крипто-рефералок).
const _bannedCryptoNames = [
  'Binance',
  'Coinbase',
  'Kraken',
  'Bitpanda',
  'Crypto.com',
  'KuCoin',
  'MoonPay',
];

void main() {
  testWidgets('BrokersScreen показывает предупреждения о риске сверху и снизу',
      (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_wrap(const BrokersScreen()));
    await _settle(tester);

    expect(find.textContaining('риск'), findsWidgets);
    expect(find.textContaining('не является'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('BrokersScreen перечисляет только лицензированные в ЕС брокеры акций',
      (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_wrap(const BrokersScreen()));
    await _settle(tester);

    for (final name in const [
      'eToro',
      'Interactive Brokers',
      'Lightyear',
      'Scalable Capital',
      'Trade Republic',
      'XTB',
    ]) {
      expect(find.textContaining(name), findsWidgets, reason: '$name должен быть в списке');
    }
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('BrokersScreen НЕ содержит криптоброкеров/бирж', (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_wrap(const BrokersScreen()));
    await _settle(tester);

    for (final name in _bannedCryptoNames) {
      expect(find.textContaining(name), findsNothing,
          reason: '$name не должен упоминаться в разделе брокеров (без крипты)');
    }
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('BrokersScreen показывает кнопки внешних сайтов (без реального launch)',
      (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_wrap(const BrokersScreen()));
    await _settle(tester);

    expect(find.text('Открыть сайт'), findsNWidgets(6));
    expect(find.text('внешний сайт'), findsNWidgets(6));
    expect(find.byIcon(Icons.open_in_new_rounded), findsNWidgets(6));
    // Намеренно НЕ тапаем по кнопкам — launchUrl полез бы в platform channel.
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
