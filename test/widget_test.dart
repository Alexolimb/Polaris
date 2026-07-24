import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/main.dart';
import 'package:polaris/screens/home/home_screen.dart';
import 'package:polaris/screens/onboarding/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // В приложении бесконечные анимации (звёзды, сияние, PulseDot) и опрос
  // котировок — pumpAndSettle тут никогда не осядет, двигаем время вручную.

  testWidgets('первый запуск: сплэш → онбординг', (tester) async {
    SharedPreferences.setMockInitialValues({}); // чистая установка
    await tester.pumpWidget(const PolarisApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2)); // заставка
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // загрузка настроек

    expect(find.byType(OnboardingScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('повторный запуск (онбординг пройден): сплэш → Портфель',
      (tester) async {
    // Онбординг уже пройден — приложение сразу к каркасу.
    SharedPreferences.setMockInitialValues({
      'flutter.polaris.settings.v1':
          jsonEncode({'onboardingDone': true, 'userGoal': 'curious'}),
    });
    await tester.pumpWidget(const PolarisApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Cosmo'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });
}
