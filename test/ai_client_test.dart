/// Тесты клиента AI-наставника Cosmo (services/ai.dart): парсер SSE на кривых/
/// обрывающихся чанках, реконнект при пустом обрыве, отсутствие дублей при
/// обрыве после начала ответа, и commentOnTrade (не потоковый эндпоинт).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/services/ai.dart';
import 'package:polaris/services/api.dart';

Stream<List<int>> _sse(List<String> lines) async* {
  for (final l in lines) {
    yield utf8.encode(l);
  }
}

void main() {
  group('streamChat — happy path', () {
    test('собирает дельты по мере прихода и останавливается на [DONE]', () async {
      final ai = PolarisAi(
        streamPost: (uri, body, timeout) => _sse([
          'data: {"delta":"Hel"}\n\n',
          'data: {"delta":"lo"}\n\n',
          'data: [DONE]\n\n',
        ]),
      );
      final out = <String>[];
      await for (final d in ai.streamChat(messages: const [], lang: 'en')) {
        out.add(d);
      }
      expect(out.join(), 'Hello');
    });

    test('тело запроса содержит messages/lang/portfolio', () async {
      String? sentBody;
      Uri? sentUri;
      final ai = PolarisAi(
        streamPost: (uri, body, timeout) {
          sentUri = uri;
          sentBody = body;
          return _sse(['data: [DONE]\n\n']);
        },
      );
      await for (final _ in ai.streamChat(
        messages: const [ChatMessage(role: 'user', content: 'Привет')],
        lang: 'ru',
        portfolio: const {'cash_usd': '9000.00'},
      )) {}
      expect(sentUri!.path, endsWith('/v1/ai/chat'));
      final decoded = jsonDecode(sentBody!) as Map<String, dynamic>;
      expect(decoded['lang'], 'ru');
      expect(decoded['portfolio'], {'cash_usd': '9000.00'});
      expect((decoded['messages'] as List).first, {'role': 'user', 'content': 'Привет'});
    });
  });

  group('streamChat — кривые/рваные чанки', () {
    test('событие разрезано ровно посреди сетевого чанка', () async {
      const full = 'data: {"delta":"Hello world"}\n\ndata: [DONE]\n\n';
      final bytes = utf8.encode(full);
      final mid = bytes.length ~/ 2;
      final ai = PolarisAi(
        streamPost: (uri, body, timeout) async* {
          yield bytes.sublist(0, mid);
          yield bytes.sublist(mid);
        },
      );
      final out = <String>[];
      await for (final d in ai.streamChat(messages: const [], lang: 'en')) {
        out.add(d);
      }
      expect(out.join(), 'Hello world');
    });

    test('битый JSON в одном событии пропускается, остальные доходят', () async {
      final ai = PolarisAi(
        streamPost: (uri, body, timeout) => _sse([
          'data: {совсем не json}\n\n',
          'data: {"delta":"ok"}\n\n',
          'data: [DONE]\n\n',
        ]),
      );
      final out = <String>[];
      await for (final d in ai.streamChat(messages: const [], lang: 'en')) {
        out.add(d);
      }
      expect(out.join(), 'ok');
    });
  });

  group('streamChat — обрывы мобильной сети', () {
    test('обрыв ПОСЛЕ начала ответа — отдаёт частичный текст без исключения', () async {
      final ai = PolarisAi(
        streamPost: (uri, body, timeout) async* {
          yield utf8.encode('data: {"delta":"Часть ответа. "}\n\n');
          throw const SocketException('connection reset by peer');
        },
      );
      final out = <String>[];
      await for (final d in ai.streamChat(messages: const [], lang: 'ru')) {
        out.add(d);
      }
      expect(out.join(), 'Часть ответа. ');
    });

    test('пустой обрыв ДО первого куска — один реконнект вытаскивает ответ', () async {
      var call = 0;
      final ai = PolarisAi(
        streamPost: (uri, body, timeout) async* {
          call++;
          if (call == 1) return; // сервер закрыл соединение молча, без единого байта
          yield utf8.encode('data: {"delta":"Recovered"}\n\n');
          yield utf8.encode('data: [DONE]\n\n');
        },
      );
      final out = <String>[];
      await for (final d in ai.streamChat(messages: const [], lang: 'en')) {
        out.add(d);
      }
      expect(call, 2);
      expect(out.join(), 'Recovered');
    });

    test('обе попытки не удались до единого байта — бросает ApiException(offline)', () async {
      final ai = PolarisAi(
        streamPost: (uri, body, timeout) async* {
          throw const SocketException('no route to host');
        },
      );
      await expectLater(
        () async {
          await for (final _ in ai.streamChat(messages: const [], lang: 'en')) {}
        },
        throwsA(isA<ApiException>()),
      );
    });

    test('пустой ответ без ошибки и без реконнектов (попытки исчерпаны) завершается тихо', () async {
      final ai = PolarisAi(
        streamPost: (uri, body, timeout) => _sse([]), // закрылся сразу, без единого чанка
      );
      final out = <String>[];
      await for (final d in ai.streamChat(messages: const [], lang: 'en')) {
        out.add(d);
      }
      expect(out, isEmpty); // вторая (последняя) попытка тоже пуста — тихо завершаем
    });
  });

  group('commentOnTrade', () {
    test('парсит {"comment": "..."} и обрезает пробелы', () async {
      final ai = PolarisAi(post: (uri, body, timeout) async => '{"comment":"  Хорошая диверсификация.  "}');
      final c = await ai.commentOnTrade(
          trade: const {'side': 'buy'}, portfolio: const {}, lang: 'ru');
      expect(c, 'Хорошая диверсификация.');
    });

    test('шлёт trade/portfolio/lang в теле запроса', () async {
      String? sentBody;
      final ai = PolarisAi(post: (uri, body, timeout) async {
        sentBody = body;
        return '{"comment":"ok"}';
      });
      await ai.commentOnTrade(
        trade: const {'side': 'sell', 'symbol': 'AAPL'},
        portfolio: const {'cash_usd': '100.00'},
        lang: 'en',
      );
      final decoded = jsonDecode(sentBody!) as Map<String, dynamic>;
      expect(decoded['trade'], {'side': 'sell', 'symbol': 'AAPL'});
      expect(decoded['lang'], 'en');
    });

    test('кривой JSON превращается в ApiException(badResponse)', () async {
      final ai = PolarisAi(post: (uri, body, timeout) async => 'это не json');
      expect(
        () => ai.commentOnTrade(trade: const {}, portfolio: const {}, lang: 'en'),
        throwsA(isA<ApiException>()),
      );
    });

    test('пустой comment превращается в ApiException(badResponse)', () async {
      final ai = PolarisAi(post: (uri, body, timeout) async => '{"comment":"   "}');
      expect(
        () => ai.commentOnTrade(trade: const {}, portfolio: const {}, lang: 'en'),
        throwsA(isA<ApiException>()),
      );
    });

    test('сетевая ошибка превращается в ApiException', () async {
      final ai = PolarisAi(post: (uri, body, timeout) async => throw const SocketException('x'));
      expect(
        () => ai.commentOnTrade(trade: const {}, portfolio: const {}, lang: 'en'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
