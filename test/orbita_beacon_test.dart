import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/services/orbita_beacon.dart';

/// Проверка маячка «Орбиты».
///
/// Без токена тест только убеждается, что маячок молчит и ничего не ломает.
/// С токеном он реально стучится на сервер:
///   flutter test --dart-define=ORBITA_BEACON_TOKEN=<токен> test/orbita_beacon_test.dart
void main() {
  test('без токена маячок молчит и не бросает', () {
    if (OrbitaBeacon.hasToken) return;
    expect(OrbitaBeacon.ping, returnsNormally);
  });

  test('ping не задерживает запуск приложения', () {
    final sw = Stopwatch()..start();
    OrbitaBeacon.ping();
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(100));
  });

  test('с токеном письмо реально уходит на сервер', () async {
    if (!OrbitaBeacon.hasToken) return;
    await expectLater(OrbitaBeacon.sendNow(), completes);
  }, timeout: const Timeout(Duration(seconds: 20)));
}
