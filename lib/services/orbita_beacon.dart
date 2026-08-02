import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Маячок для пульта «Орбита»: при запуске говорит «я жив, вот моя версия».
///
/// Три правила, которые нельзя нарушать:
///  1. Приложение не должно ждать маячок — он уходит фоном.
///  2. Нет сети, нет сервера, нет токена — приложение работает как обычно.
///  3. Токен НЕ хранится в коде: он приходит из `--dart-define`.
///     Репозиторий Polaris публичный — секрет туда попасть не должен.
///
/// Сборка с маячком:
///   flutter build apk --release --dart-define=ORBITA_BEACON_TOKEN=<токен>
/// Токен лежит в `Brain\Claud\orbita_secrets.json`.
class OrbitaBeacon {
  OrbitaBeacon._();

  static const String _endpoint = 'https://orbita.178-105-123-85.nip.io/beacon';
  static const String _token = String.fromEnvironment('ORBITA_BEACON_TOKEN');

  /// Как проект называется в Орбите. Совпадает со `slug` в её базе.
  static const String _slug = 'polaris';

  /// Версия из pubspec.yaml. Обновляется вместе с ней.
  static const String _version = '1.0.0';

  /// Зовётся из main() и НЕ ожидается.
  static void ping() {
    if (_token.isEmpty) return; // собрано без токена — молчим
    if (kIsWeb) return; // в вебе dart:io недоступен
    unawaited(_send());
  }

  /// То же самое, но ожидаемо — чтобы проверку можно было довести до конца.
  @visibleForTesting
  static Future<void> sendNow() => _send();

  /// Собран ли маячок с токеном.
  @visibleForTesting
  static bool get hasToken => _token.isNotEmpty;

  static Future<void> _send() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client.postUrl(Uri.parse(_endpoint));
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(<String, String>{
          'slug': _slug,
          'version': _version,
          'platform': Platform.operatingSystem,
          'token': _token,
        }),
      );
      final response = await request.close().timeout(const Duration(seconds: 5));
      await response.drain<void>();
    } catch (_) {
      // Маячок не имеет права мешать приложению — любая ошибка глотается.
    } finally {
      client.close(force: true);
    }
  }
}
