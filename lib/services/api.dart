/// Клиент сервера Polaris (волна 1б). Все цены — в центах (int), как в моделях.
///
/// Контракт эндпоинтов v1 (для волны 1а — сервера; менять синхронно!):
///
///   GET {base}/v1/assets
///     → {"assets":[{"symbol":"AAPL","name":"Apple Inc.","type":"stock",
///         "currency":"USD","themes":["bigtech"],"sector":"Technology",
///         "freshness":"realtime"}],
///        "themes":[{"id":"bigtech","title":"Большие технологии"}]}
///
///   GET {base}/v1/quotes?symbols=AAPL,MSFT
///     → {"quotes":[{"symbol":"AAPL","priceCents":23412,"prevCloseCents":23180,
///         "ts":"2026-07-20T14:00:00Z","marketOpen":true}]}
///
///   GET {base}/v1/candles?symbol=AAPL&range=1d|1w|1m|1y
///     → {"candles":[{"t":1784822400000,"o":23100,"h":23500,"l":23050,"c":23412}]}
///       (t — epoch-миллисекунды ИЛИ ISO-строка, парсим оба варианта)
///
///   GET {base}/v1/dividends?symbol=AAPL
///     → {"dividends":[{"symbol":"AAPL","exDate":"2026-08-08",
///         "payDate":"2026-08-14","perShareCents":26}]}
///
/// Устойчивость: таймауты на каждом шаге, битая запись в списке пропускается,
/// целиком кривой JSON и сетевые беды превращаются в ApiException с понятным
/// kind — репозиторий по нему решает, что делать (обычно — оффлайн-фикстуры).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/models.dart';

/// Конфиг клиента: база и таймаут. Дефолт — наш Hetzner за nip.io.
class PolarisApiConfig {
  final String baseUrl;
  final Duration timeout;

  const PolarisApiConfig({
    this.baseUrl = defaultBaseUrl,
    this.timeout = const Duration(seconds: 6),
  });

  // Боевой бэкенд Polaris. Развёрнут 24.07.2026 как воркфлоу n8n (вебхуки) на
  // сервере Hetzner — эндпоинты v1 под этим базовым путём (рыночные данные +
  // наставник Cosmo на бесплатной Groq). Node-версия сервера (server/) —
  // резерв на случай переезда на SSH-хостинг; контракт идентичен.
  // Если сервер недоступен — приложение падает на встроенные офлайн-фикстуры.
  static const defaultBaseUrl = 'https://178-105-123-85.nip.io/webhook/polaris';
}

/// Что пошло не так — по kind репозиторий выбирает фолбэк.
enum ApiErrorKind { offline, timeout, badResponse, http }

class ApiException implements Exception {
  final ApiErrorKind kind;
  final String message;

  const ApiException(this.kind, this.message);

  /// Текст для человека (показывается в UI как есть), русский по умолчанию —
  /// для мест без доступа к языку пользователя. Экраны/состояния, которые
  /// знают язык (см. `lang()` в ChatState), должны звать [localizedMessage].
  String get userMessage => localizedMessage('ru');

  /// То же самое, но на нужном языке — 'ru' | 'en' | 'es' (иначе английский).
  /// Тот же паттерн маленьких lang-словарей, что уже используют
  /// `ChatState._emptyReplyNotice` и строки экрана Cosmo (без BuildContext
  /// сервисный слой не может звать AppLocalizations).
  String localizedMessage(String lang) => switch (kind) {
        ApiErrorKind.offline => switch (lang) {
            'ru' => 'Нет сети — показываю сохранённые данные',
            'es' => 'Sin conexión — mostrando datos guardados',
            _ => 'No connection — showing saved data',
          },
        ApiErrorKind.timeout => switch (lang) {
            'ru' => 'Сервер отвечает слишком долго',
            'es' => 'El servidor tarda demasiado en responder',
            _ => 'The server is taking too long to respond',
          },
        ApiErrorKind.badResponse => switch (lang) {
            'ru' => 'Сервер вернул неожиданный ответ',
            'es' => 'El servidor devolvió una respuesta inesperada',
            _ => 'The server returned an unexpected response',
          },
        ApiErrorKind.http => switch (lang) {
            'ru' => 'Сервер временно недоступен',
            'es' => 'El servidor no está disponible por el momento',
            _ => 'The server is temporarily unavailable',
          },
      };

  @override
  String toString() => 'ApiException(${kind.name}): $message';
}

/// Диапазоны графика на карточке актива.
enum CandleRange {
  d1('1d', '1Д'),
  w1('1w', '1Н'),
  m1('1m', '1М'),
  y1('1y', '1Г');

  const CandleRange(this.query, this.label);

  /// Значение query-параметра для сервера.
  final String query;

  /// Подпись на кнопке диапазона.
  final String label;
}

/// Одна свеча. Всё в центах.
class Candle {
  final DateTime t;
  final int o;
  final int h;
  final int l;
  final int c;

  const Candle({
    required this.t,
    required this.o,
    required this.h,
    required this.l,
    required this.c,
  });
}

/// Тема-подборка для чипов («ИИ», «Дивидендные гиганты»…).
class MarketTheme {
  final String id;
  final String title;

  const MarketTheme({required this.id, required this.title});
}

/// Ближайшая дивидендная выплата по бумаге.
class DividendEvent {
  final String symbol;
  final DateTime? exDate;
  final DateTime? payDate;
  final int perShareCents;

  const DividendEvent({
    required this.symbol,
    this.exDate,
    this.payDate,
    required this.perShareCents,
  });
}

/// Каталог: активы + темы одним ответом.
class MarketCatalog {
  final List<Asset> assets;
  final List<MarketTheme> themes;

  const MarketCatalog({required this.assets, required this.themes});
}

/// Транспорт: отдаёт тело ответа строкой или бросает
/// SocketException / TimeoutException / ApiException(http).
/// Подменяется в тестах — сеть в тестах не нужна.
typedef HttpGetFn = Future<String> Function(Uri uri, Duration timeout);

/// Боевой транспорт на dart:io (пакетов не тянем — http нам не нужен).
Future<String> _ioGet(Uri uri, Duration timeout) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client.getUrl(uri).timeout(timeout);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(timeout);
    final body = await utf8.decodeStream(response).timeout(timeout);
    if (response.statusCode != 200) {
      throw ApiException(
          ApiErrorKind.http, 'Сервер ответил ${response.statusCode}');
    }
    return body;
  } finally {
    client.close(force: true);
  }
}

class PolarisApi {
  final PolarisApiConfig config;
  final HttpGetFn _http;

  PolarisApi({this.config = const PolarisApiConfig(), HttpGetFn? httpGet})
      : _http = httpGet ?? _ioGet;

  // ---- эндпоинты ----

  Future<MarketCatalog> fetchCatalog() async {
    final json = await _getJson('/v1/assets');
    if (json is! Map<String, dynamic>) {
      throw const ApiException(
          ApiErrorKind.badResponse, 'Ожидался объект с полем assets');
    }
    // is List, а НЕ `as List?`: если поле присутствует, но не список,
    // `as List?` бросил бы TypeError мимо ApiException — и оффлайн-фолбэк
    // репозитория не сработал бы (как у остальных эндпоинтов).
    final assets = <Asset>[];
    final assetsRaw = json['assets'];
    if (assetsRaw is List) {
      for (final raw in assetsRaw) {
        try {
          assets.add(Asset.fromJson(raw as Map<String, dynamic>));
        } catch (_) {
          // битую запись пропускаем — одна кривая бумага не роняет каталог
        }
      }
    }
    final themes = <MarketTheme>[];
    final themesRaw = json['themes'];
    if (themesRaw is List) {
      for (final raw in themesRaw) {
        try {
          final m = raw as Map<String, dynamic>;
          final id = m['id'] as String;
          themes.add(MarketTheme(id: id, title: (m['title'] as String?) ?? id));
        } catch (_) {}
      }
    }
    return MarketCatalog(assets: assets, themes: themes);
  }

  Future<List<Quote>> fetchQuotes(List<String> symbols) async {
    if (symbols.isEmpty) return const [];
    final json =
        await _getJson('/v1/quotes', {'symbols': symbols.join(',')});
    final list = json is Map<String, dynamic> ? json['quotes'] : null;
    if (list is! List) {
      throw const ApiException(
          ApiErrorKind.badResponse, 'Ожидался объект с полем quotes');
    }
    final out = <Quote>[];
    for (final raw in list) {
      try {
        final m = raw as Map<String, dynamic>;
        final price = (m['priceCents'] as num).toInt();
        out.add(Quote(
          symbol: m['symbol'] as String,
          priceCents: price,
          prevCloseCents: (m['prevCloseCents'] as num?)?.toInt() ?? price,
          ts: _asTime(m['ts']) ?? DateTime.now(),
          marketOpen: m['marketOpen'] as bool? ?? true,
        ));
      } catch (_) {}
    }
    return out;
  }

  Future<List<Candle>> fetchCandles(String symbol, CandleRange range) async {
    final json = await _getJson(
        '/v1/candles', {'symbol': symbol, 'range': range.query});
    final list = json is Map<String, dynamic> ? json['candles'] : null;
    if (list is! List) {
      throw const ApiException(
          ApiErrorKind.badResponse, 'Ожидался объект с полем candles');
    }
    final out = <Candle>[];
    for (final raw in list) {
      try {
        final m = raw as Map<String, dynamic>;
        final t = _asTime(m['t']);
        if (t == null) continue;
        out.add(Candle(
          t: t,
          o: (m['o'] as num).toInt(),
          h: (m['h'] as num).toInt(),
          l: (m['l'] as num).toInt(),
          c: (m['c'] as num).toInt(),
        ));
      } catch (_) {}
    }
    out.sort((a, b) => a.t.compareTo(b.t));
    return out;
  }

  Future<List<DividendEvent>> fetchDividends(String symbol) async {
    final json = await _getJson('/v1/dividends', {'symbol': symbol});
    final list = json is Map<String, dynamic> ? json['dividends'] : null;
    if (list is! List) {
      throw const ApiException(
          ApiErrorKind.badResponse, 'Ожидался объект с полем dividends');
    }
    final out = <DividendEvent>[];
    for (final raw in list) {
      try {
        final m = raw as Map<String, dynamic>;
        out.add(DividendEvent(
          symbol: (m['symbol'] as String?) ?? symbol,
          exDate: _asTime(m['exDate']),
          payDate: _asTime(m['payDate']),
          perShareCents: (m['perShareCents'] as num).toInt(),
        ));
      } catch (_) {}
    }
    return out;
  }

  // ---- внутренности ----

  Future<Object?> _getJson(String path, [Map<String, String>? query]) async {
    var base = config.baseUrl;
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    final uri = Uri.parse('$base$path').replace(queryParameters: query);
    String body;
    try {
      body = await _http(uri, config.timeout);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(ApiErrorKind.timeout,
          'Сервер не ответил за ${config.timeout.inSeconds} с');
    } on IOException catch (e) {
      // SocketException, HandshakeException, HttpException — всё сюда
      throw ApiException(
          ApiErrorKind.offline, 'Нет соединения с сервером Polaris: $e');
    } on FormatException {
      // Битое/усечённое UTF-8 тело — это плохой ОТВЕТ, а не отсутствие сети.
      throw const ApiException(
          ApiErrorKind.badResponse, 'Сервер вернул некорректные данные');
    } catch (e) {
      throw ApiException(ApiErrorKind.offline, 'Сеть недоступна: $e');
    }
    try {
      return jsonDecode(body);
    } on FormatException {
      throw const ApiException(
          ApiErrorKind.badResponse, 'Сервер вернул некорректный JSON');
    }
  }

  /// Время терпимо к формату: epoch-миллисекунды или ISO-строка.
  ///
  /// Обязательно приводим к ЛОКАЛЬНОМУ времени. Раньше момент оставался в UTC,
  /// и подписи на графике врали на величину часового пояса: в Мадриде (UTC+2)
  /// при скраббинге показывалось «17:00» там, где по часам пользователя 19:00,
  /// а поздним вечером — ещё и вчерашняя ДАТА.
  ///
  /// На датах-без-времени (`"2026-08-27"` у дивидендов) это ничего не меняет:
  /// `DateTime.tryParse` для строки без «Z» и без смещения уже возвращает
  /// локальную полночь, и `toLocal()` для неё — тождество.
  static DateTime? _asTime(Object? v) {
    if (v is num) {
      return DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true)
          .toLocal();
    }
    if (v is String) return DateTime.tryParse(v)?.toLocal();
    return null;
  }
}
