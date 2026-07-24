/// Состояние чата с Cosmo (волна 2а). История сообщений живёт в памяти, а
/// последние ~50 кэшируются на диск через [StorageGateway] — переживает
/// перезапуск приложения (гостевой режим, аккаунтов нет).
///
/// Портфельный контекст в запрос кладёт вызывающий экран (см. cosmo_screen.dart)
/// через анонимный `PortfolioState.aiContext(quotes)` — этот класс сам не трогает
/// портфель, чтобы не зависеть от AppScope и оставаться тестируемым в изоляции.
library;

import 'package:flutter/foundation.dart';

import '../services/ai.dart';
import '../services/api.dart' show ApiException;
import '../services/storage.dart';

enum ChatRole { user, assistant }

/// Одно сообщение в истории. [text] не final — стриминг дописывает по мере
/// прихода кусков, экран перерисовывается на каждый notifyListeners.
class ChatEntry {
  final String id;
  final ChatRole role;
  String text;
  final DateTime ts;

  ChatEntry({
    required this.id,
    required this.role,
    required this.text,
    required this.ts,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'text': text,
        'ts': ts.toIso8601String(),
      };

  factory ChatEntry.fromJson(Map<String, dynamic> j, int fallbackSeq) => ChatEntry(
        id: j['id'] as String? ?? 'legacy-$fallbackSeq',
        role: ChatRole.values.asNameMap()[j['role']] ?? ChatRole.assistant,
        text: j['text'] as String? ?? '',
        ts: DateTime.tryParse(j['ts'] as String? ?? '') ?? DateTime.now(),
      );
}

const _historyKey = 'polaris.chat.v1';
const _maxKeep = 50;

/// Дефолт языка ответа, если экран не передал реальный (например, в тестах
/// состояния без UI) — сам чат не знает о локали устройства/пользователя.
String _defaultLang() => 'en';

class ChatState extends ChangeNotifier {
  final PolarisAi ai;
  final StorageGateway storage;
  final String Function() lang;

  final List<ChatEntry> _entries = [];
  int _idSeq = 0;
  bool _loaded = false;
  bool _sending = false;
  String? _error;
  bool _disposed = false;

  ChatState({
    PolarisAi? ai,
    StorageGateway? storage,
    String Function()? lang,
  })  : ai = ai ?? PolarisAi(),
        storage = storage ?? MemoryStorage(),
        lang = lang ?? _defaultLang;

  List<ChatEntry> get entries => List.unmodifiable(_entries);
  bool get loaded => _loaded;
  bool get sending => _sending;
  String? get error => _error;
  bool get isEmpty => _entries.isEmpty;

  Future<void> load() async {
    if (_loaded) return;
    final snap = await storage.readJson(_historyKey);
    if (snap != null) {
      final raw = snap['entries'];
      if (raw is List) {
        var i = 0;
        for (final e in raw) {
          try {
            if (e is Map<String, dynamic>) {
              _entries.add(ChatEntry.fromJson(e, i));
            }
          } catch (_) {
            // битую запись пропускаем — одно кривое сообщение не рушит историю
          }
          i++;
        }
      }
    }
    _loaded = true;
    _notify();
  }

  Future<void> _persist() async {
    final keep =
        _entries.length > _maxKeep ? _entries.sublist(_entries.length - _maxKeep) : _entries;
    await storage.writeJson(_historyKey, {
      'entries': keep.map((e) => e.toJson()).toList(),
    });
  }

  String _nextId() => 'c${DateTime.now().microsecondsSinceEpoch}-${_idSeq++}';

  /// Отправить сообщение пользователя и стримить ответ Cosmo.
  /// [portfolio] — анонимный снапшот (см. `PortfolioState.aiContext`), можно null.
  Future<void> send(String text, {Map<String, dynamic>? portfolio}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return;

    _error = null;
    _entries.add(ChatEntry(id: _nextId(), role: ChatRole.user, text: trimmed, ts: DateTime.now()));
    final assistant =
        ChatEntry(id: _nextId(), role: ChatRole.assistant, text: '', ts: DateTime.now());
    _entries.add(assistant);
    _sending = true;
    _notify();

    // История для контекста запроса — все сообщения, кроме ещё пустого ответа Cosmo.
    final history = _entries
        .where((e) => e.id != assistant.id)
        .map((e) => ChatMessage(
              role: e.role == ChatRole.user ? 'user' : 'assistant',
              content: e.text,
            ))
        .toList();

    try {
      await for (final delta in ai.streamChat(
        messages: history,
        lang: lang(),
        portfolio: portfolio,
      )) {
        if (_disposed) return;
        assistant.text += delta;
        _notify();
      }
      if (assistant.text.isEmpty) {
        assistant.text = _emptyReplyNotice(lang());
      }
    } on ApiException catch (e) {
      final msg = e.localizedMessage(lang());
      if (assistant.text.isEmpty) assistant.text = msg;
      _error = msg;
    } catch (e) {
      if (assistant.text.isEmpty) {
        assistant.text = _emptyReplyNotice(lang());
      }
      _error = 'chat_unknown_error';
    }

    _sending = false;
    await _persist();
    _notify();
  }

  String _emptyReplyNotice(String l) => switch (l) {
        'ru' => 'Cosmo не смог ответить — попробуй ещё раз чуть позже.',
        'es' => 'Cosmo no pudo responder — inténtalo de nuevo en un momento.',
        _ => "Cosmo couldn't reply — try again in a bit.",
      };

  /// Cosmo коротко комментирует свежую сделку (после покупки/продажи).
  /// Комментарий добавляется в историю чата как сообщение Cosmo. Если AI
  /// недоступен — тихо пропускаем (сделка важнее болтовни, ошибку не показываем).
  /// Возвращает текст комментария или null.
  Future<String?> noteTrade(
      Map<String, dynamic> trade, Map<String, dynamic> portfolio) async {
    if (!_loaded) await load();
    try {
      final comment = await ai.commentOnTrade(
        trade: trade,
        portfolio: portfolio,
        lang: lang(),
      );
      final text = comment.trim();
      if (text.isEmpty) return null;
      _entries.add(ChatEntry(
          id: _nextId(),
          role: ChatRole.assistant,
          text: text,
          ts: DateTime.now()));
      await _persist();
      _notify();
      return text;
    } catch (_) {
      return null; // наставник промолчал — не мешаем игроку
    }
  }

  /// Очистить историю (например, кнопка «начать разговор заново»).
  Future<void> clear() async {
    _entries.clear();
    _error = null;
    await _persist();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
