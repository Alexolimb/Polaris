// Тесты заставки SplashScreen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/screens/splash.dart';

void main() {
  testWidgets('SplashScreen animated проигрывается и вызывает onDone',
      (tester) async {
    var done = false;
    await tester.pumpWidget(MaterialApp(
      home: SplashScreen(onDone: () => done = true),
    ));
    // Середина анимации: onDone ещё не вызван, исключений нет.
    await tester.pump(const Duration(milliseconds: 900));
    expect(done, isFalse);
    expect(tester.takeException(), isNull);
    // До конца (1.8с всего) и ещё кадр.
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 100));
    expect(done, isTrue);
    expect(tester.takeException(), isNull);
    // Глушим тикеры звёздного фона.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('SplashScreen animated:false — статичный кадр, onDone быстро',
      (tester) async {
    var done = false;
    await tester.pumpWidget(MaterialApp(
      home: SplashScreen(animated: false, onDone: () => done = true),
    ));
    expect(done, isFalse);
    // Статичный режим отпускает через ~300мс.
    await tester.pump(const Duration(milliseconds: 400));
    expect(done, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('SplashScreen вызывает onDone ровно один раз', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
      home: SplashScreen(onDone: () => calls++),
    ));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
