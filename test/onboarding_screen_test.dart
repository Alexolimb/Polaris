/// Тесты онбординга: слайды листаются только кнопками, выбор цели блокирует
/// «Далее» пока не выбран вариант, дисклеймер обязателен к показу, финал
/// сохраняет флаг+цель в [AppSettings] и вызывает onDone.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/l10n/app_localizations.dart';
import 'package:polaris/screens/onboarding/onboarding_screen.dart';
import 'package:polaris/services/storage.dart';
import 'package:polaris/state/app_settings.dart';

void main() {
  Future<void> pumpOnboarding(
    WidgetTester tester, {
    required AppSettings settings,
    required VoidCallback onDone,
  }) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: OnboardingScreen(settings: settings, onDone: onDone, animated: false),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('первый слайд показывает приветствие от Cosmo', (tester) async {
    final settings = AppSettings(storage: MemoryStorage());
    await pumpOnboarding(tester, settings: settings, onDone: () {});

    expect(find.text('Привет, я Cosmo'), findsOneWidget);
    expect(find.text('Далее'), findsOneWidget);
    expect(find.text('Назад'), findsNothing); // на первом слайде некуда назад

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('кнопка Назад возвращает на предыдущий слайд', (tester) async {
    final settings = AppSettings(storage: MemoryStorage());
    await pumpOnboarding(tester, settings: settings, onDone: () {});

    await tester.tap(find.byKey(const Key('onboarding_cta')));
    await tester.pumpAndSettle();
    expect(find.text(r'$10 000 виртуальных денег'), findsOneWidget);
    expect(find.text('Назад'), findsOneWidget);

    await tester.tap(find.text('Назад'));
    await tester.pumpAndSettle();
    expect(find.text('Привет, я Cosmo'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('на слайде цели «Далее» неактивна, пока цель не выбрана',
      (tester) async {
    final settings = AppSettings(storage: MemoryStorage());
    await pumpOnboarding(tester, settings: settings, onDone: () {});

    // Долистать до слайда выбора цели (индекс 3) — 3 нажатия «Далее».
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('onboarding_cta')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Зачем ты здесь?'), findsOneWidget);

    // Тап по неактивной кнопке ничего не двигает.
    await tester.tap(find.byKey(const Key('onboarding_cta')));
    await tester.pumpAndSettle();
    expect(find.text('Зачем ты здесь?'), findsOneWidget);

    // Выбираем вариант — кнопка оживает.
    await tester.tap(find.text('Разобраться в инвестициях'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_cta')));
    await tester.pumpAndSettle();

    expect(find.text('Важно понимать'), findsOneWidget);
    expect(find.text('Начать'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'полное прохождение сохраняет флаг+цель в AppSettings и вызывает onDone',
      (tester) async {
    final settings = AppSettings(storage: MemoryStorage());
    var done = false;
    await pumpOnboarding(tester, settings: settings, onDone: () => done = true);

    // Слайды 1-3: просто «Далее».
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('onboarding_cta')));
      await tester.pumpAndSettle();
    }

    // Слайд 4: выбор цели.
    await tester.tap(find.text('Просто любопытно'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_cta')));
    await tester.pumpAndSettle();

    // Слайд 5: дисклеймер — обязательно показан перед финишем.
    expect(find.text('Важно понимать'), findsOneWidget);
    expect(done, isFalse);
    expect(settings.onboardingDone, isFalse);

    await tester.tap(find.byKey(const Key('onboarding_cta')));
    await tester.pumpAndSettle();

    expect(done, isTrue);
    expect(settings.onboardingDone, isTrue);
    expect(settings.userGoal, UserGoal.curious);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('свайп пальцем не листает слайды (физика отключена)',
      (tester) async {
    final settings = AppSettings(storage: MemoryStorage());
    await pumpOnboarding(tester, settings: settings, onDone: () {});

    await tester.drag(find.text('Привет, я Cosmo'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    // Остались на первом слайде — свайп не сработал.
    expect(find.text('Привет, я Cosmo'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
