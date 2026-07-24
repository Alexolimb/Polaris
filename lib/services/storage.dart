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

/// Боевая реализация на SharedPreferences.
class PrefsStorage implements StorageGateway {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<Map<String, dynamic>?> readJson(String key) async {
    final raw = (await _p).getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null; // битый снапшот не должен ронять старт
    }
  }

  @override
  Future<void> writeJson(String key, Map<String, dynamic> value) async {
    await (await _p).setString(key, jsonEncode(value));
  }

  @override
  Future<void> remove(String key) async => (await _p).remove(key);
}

/// Хранилище в памяти — для тестов и превью.
class MemoryStorage implements StorageGateway {
  final Map<String, Map<String, dynamic>> _data;
  MemoryStorage([Map<String, Map<String, dynamic>>? seed]) : _data = seed ?? {};

  @override
  Future<Map<String, dynamic>?> readJson(String key) async => _data[key];

  @override
  Future<void> writeJson(String key, Map<String, dynamic> value) async =>
      _data[key] = value;

  @override
  Future<void> remove(String key) async => _data.remove(key);
}
