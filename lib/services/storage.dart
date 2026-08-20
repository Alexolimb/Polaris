/// Хранилище профиля игрока Polaris. Всё живёт на устройстве (гостевой режим —
/// решение Алекса), синхронизация между устройствами — задача этапа 2.
///
/// Абстракция [StorageGateway] нужна, чтобы (а) подменять хранилище в тестах,
/// (б) на этапе 2 добавить облачную синхронизацию, не трогая портфель.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract class StorageGateway {
  Future<Map<String, dynamic>?> readJson(String key);
  Future<void> writeJson(String key, Map<String, dynamic> value);
  Future<void> remove(String key);
}

/// Запись на устройство НЕ прошла.
///
/// ⚠️ Раньше ответ системы «не сохранил» просто выбрасывался: приложение
/// рапортовало «Куплено AAPL», а на диске не появлялось ничего. Человек мог
/// неделю растить портфель и потерять всё при первом перезапуске — без
/// единого слова. Найдено ревизией 10.08.2026.
///
/// Теперь неудачная запись — громкая: тот, кто её заказал, обязан либо
/// откатить изменение, либо сказать человеку вслух.
class StorageWriteFailed implements Exception {
  final String key;
  final Object? cause;

  const StorageWriteFailed(this.key, [this.cause]);

  @override
  String toString() =>
      'StorageWriteFailed($key)${cause == null ? '' : ': $cause'}';
}

/// Боевая реализация на SharedPreferences.
class PrefsStorage implements StorageGateway {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<Map<String, dynamic>?> readJson(String key) async {
    final raw = (await _p).getString(key);
    if (raw == null) return null; // записи нет — это новый человек, всё честно

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      decoded = null;
    }
    if (decoded is Map<String, dynamic>) return decoded;

    /*
     * Запись ЕСТЬ, но не разбирается. Это НЕ новый человек.
     *
     * ⚠️ Раньше здесь просто возвращался null — то же самое, что «данных нет».
     * Приложение показывало свежие 10 000 долларов, как после установки, а
     * первая же покупка записывала пустой портфель поверх настоящего: позиции,
     * вся история сделок и все дивиденды исчезали навсегда, без единого слова.
     * Найдено ревизией 10.08.2026.
     *
     * Теперь непрочитанное откладывается в сторону под своим именем с датой —
     * оно остаётся на устройстве, и его можно разобрать руками, — а приложение
     * узнаёт о беде и говорит о ней вслух.
     */
    final kuda = '$key.broken-${DateTime.now().toIso8601String().substring(0, 10)}';
    final prefs = await _p;
    if (!prefs.containsKey(kuda)) await prefs.setString(kuda, raw);
    _bityeKlyuchi.add(key);
    return null;
  }

  /// Записи, которые нашлись на устройстве, но не разобрались.
  /// Пусто — всё в порядке.
  static final Set<String> _bityeKlyuchi = <String>{};

  /// Была ли запись по этому ключу и оказалась ли она нечитаемой.
  static bool bitaya(String key) => _bityeKlyuchi.contains(key);

  /// ⚠️ Ответ `setString` — это «да/нет», и раньше он никуда не присваивался.
  /// Через эту одну строку идёт ВСЁ: портфель, прогресс обучения, история
  /// чата, настройки. Молчаливое «нет» означало потерю всего, что человек
  /// накопил с последнего удачного сохранения. Найдено ревизией 10.08.2026.
  @override
  Future<void> writeJson(String key, Map<String, dynamic> value) async {
    final bool ok;
    try {
      ok = await (await _p).setString(key, jsonEncode(value));
    } catch (e) {
      throw StorageWriteFailed(key, e);
    }
    if (!ok) throw StorageWriteFailed(key);
  }

  @override
  Future<void> remove(String key) async => (await _p).remove(key);
}

/// Хранилище в памяти — для тестов и превью.
class MemoryStorage implements StorageGateway {
  final Map<String, Map<String, dynamic>> _data;
  MemoryStorage([Map<String, Map<String, dynamic>>? seed]) : _data = seed ?? {};

  /// Всё содержимое разом — снимок «файла на диске». Нужен тестам, чтобы
  /// проверять именно то, что переживёт перезапуск, а не то, что на экране.
  Map<String, Map<String, dynamic>> get vsyo => Map.of(_data);

  @override
  Future<Map<String, dynamic>?> readJson(String key) async => _data[key];

  @override
  Future<void> writeJson(String key, Map<String, dynamic> value) async =>
      _data[key] = value;

  @override
  Future<void> remove(String key) async => _data.remove(key);
}
