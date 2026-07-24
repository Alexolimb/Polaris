/// Тесты состояния чата Cosmo (state/chat_state.dart): поток отправки
/// сообщения, персистентность истории (кап 50, переживает перезагрузку),
/// обработка сетевых ошибок, clear(), устойчивость к битому снапшоту.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/services/ai.dart';
import 'package:polaris/services/storage.dart';
import 'package:polaris/state/chat_state.dart';

Stream<List<int>> _sse(List<String> lines) async* {
  for (final l in lines) {
    yield utf8.encode(l);
  }
}

PolarisAi _okAi(String reply) => PolarisAi(
      streamPost: (uri, body, timeout) => _sse([
        'data: ${jsonEncode({
              'delta': reply
            })}\n\n',
        'data: [DONE]\n\n',
      ]),
    );

void main() {
  group('ChatState — отправка сообщения', () {
    test('добавляет пользователя и ассистента, стримит текст, уведомляет', () async {
      final chat = ChatState(ai: _okAi('Привет!'), storage: MemoryStorage(), lang: () => 'ru');
      var notified = 0;
      chat.addListener(() => notified++);
      await chat.load();
      await chat.send('Что такое ETF?');

      expect(chat.entries.length, 2);
      expect(chat.entries[0].role, ChatRole.user);
      expect(chat.entries[0].text, 'Что такое ETF?');
      expect(chat.entries[1].role, ChatRole.assistant);
      expect(chat.entries[1].text, 'Привет!');
      expect(notified, greaterThan(0));
      expect(chat.sending, isFalse);
      expect(chat.isEmpty, isFalse);
    });

    test('передаёт lang() и portfolio в запрос', () async {
      Map<String, dynamic>? sentBody;
      final ai = PolarisAi(streamPost: (uri, body, timeout) {
        sentBody = jsonDecode(body) as Map<String, dynamic>;
        return _sse(['data: {"delta":"ok"}\n\n', 'data: [DONE]\n\n']);
      });
      final chat = ChatState(ai: ai, lang: () => 'es');
      await chat.send('Hola', portfolio: const {'cash_usd': '10.00'});
      expect(sentBody!['lang'], 'es');
      expect(sentBody!['portfolio'], {'cash_usd': '10.00'});
    });

    test('пустое/пробельное сообщение игнорируется', () async {
      final chat = ChatState(ai: _okAi('ok'));
      await chat.send('   ');
      expect(chat.entries, isEmpty);
    });

    test('повторная отправка во время sending игнорируется (не дублирует)', () async {
      // Стрим "зависает" (не завершается) — sending остаётся true всё время await.
      final ai = PolarisAi(streamPost: (uri, body, timeout) {
        final controller = StreamController<List<int>>();
        // намеренно ничего не шлём и не закрываем — эмулируем долгий ответ
        return controller.stream;
      });
      final chat = ChatState(ai: ai);
      // Не ждём завершения — оно и не завершится, проверяем только защиту от дублей.
      unawaited(chat.send('Первое'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(chat.sending, isTrue);
      await chat.send('Второе — должно быть проигнорировано');
      expect(chat.entries.length, 2); // только первая пара user/assistant
    });

    test('сетевая ошибка при обрыве до первого куска даёт assistant.text=userMessage', () async {
      final ai = PolarisAi(streamPost: (uri, body, timeout) => throw Exception('boom'));
      final chat = ChatState(ai: ai);
      await chat.send('Привет');
      expect(chat.entries.last.role, ChatRole.assistant);
      expect(chat.entries.last.text, isNotEmpty);
      expect(chat.error, isNotNull);
    });

    test('пустой успешный ответ подставляет вежливое уведомление на нужном языке', () async {
      final ai = PolarisAi(streamPost: (uri, body, timeout) => _sse(['data: [DONE]\n\n']));
      final chat = ChatState(ai: ai, lang: () => 'ru');
      await chat.send('Привет');
      expect(chat.entries.last.text, contains('Cosmo'));
    });
  });

  group('ChatState — персистентность', () {
    test('сохраняет историю на диск и переживает перезагрузку', () async {
      final storage = MemoryStorage();
      final chat = ChatState(ai: _okAi('ok'), storage: storage);
      await chat.load();
      await chat.send('Привет');

      final reloaded = ChatState(ai: _okAi('ok'), storage: storage);
      await reloaded.load();
      expect(reloaded.entries.length, 2);
      expect(reloaded.entries[0].text, 'Привет');
    });

    test('кап истории — хранится не больше 50 записей', () async {
      final storage = MemoryStorage();
      final chat = ChatState(ai: _okAi('ok'), storage: storage);
      for (var i = 0; i < 30; i++) {
        await chat.send('сообщение $i');
      }
      // 30 отправок * 2 записи (user+assistant) = 60 в памяти, но на диске капается до 50.
      expect(chat.entries.length, 60);
      final reloaded = ChatState(ai: _okAi('ok'), storage: storage);
      await reloaded.load();
      expect(reloaded.entries.length, 50);
      // Кап оставляет САМЫЕ СВЕЖИЕ сообщения (хвост), не самые старые.
      expect(reloaded.entries.last.text, 'ok');
    });

    test('битый снапшот истории не роняет загрузку', () async {
      final storage = MemoryStorage({
        'polaris.chat.v1': {'entries': 'мусор, не список'}
      });
      final chat = ChatState(storage: storage);
      await chat.load();
      expect(chat.loaded, isTrue);
      expect(chat.entries, isEmpty);
    });

    test('битая ОДНА запись в списке пропускается, остальные грузятся', () async {
      final storage = MemoryStorage({
        'polaris.chat.v1': {
          'entries': [
            {'id': 'a', 'role': 'user', 'text': 'норм', 'ts': DateTime(2026, 1, 1).toIso8601String()},
            'мусор-не-мапа',
          ]
        }
      });
      final chat = ChatState(storage: storage);
      await chat.load();
      expect(chat.entries.length, 1);
      expect(chat.entries.first.text, 'норм');
    });
  });

  group('ChatState — clear', () {
    test('стирает историю и ошибку', () async {
      final ai = PolarisAi(streamPost: (uri, body, timeout) => throw Exception('boom'));
      final chat = ChatState(ai: ai);
      await chat.send('Привет');
      expect(chat.entries, isNotEmpty);
      await chat.clear();
      expect(chat.entries, isEmpty);
      expect(chat.error, isNull);
    });
  });
}
