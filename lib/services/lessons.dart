/// Контент вкладки «Учёба»: загрузка и разбор content/*.json из ассетов.
///
/// Правила устойчивости (как в api.dart/market_repo.dart):
/// - битая ОДНА запись (урок/термин/тема) пропускается, остальные грузятся;
/// - если файл целиком не JSON или отсутствует — секция становится пустой,
///   приложение не падает;
/// - модели — с латинскими полями, без русской специфики в коде, чтобы
///   волна 3 (EN/ES) просто подложила rus/eng/es JSON рядом.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

// ==================== цвета ====================

/// «#RRGGBB» → Color. Кривая или отсутствующая строка — [fallback].
Color parseAccent(String? hex, [Color fallback = const Color(0xFF6C8EFF)]) {
  if (hex == null || hex.isEmpty) return fallback;
  var h = hex.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return fallback;
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

// ==================== модели ====================

/// Модуль — тематический раздел из 6 уроков.
class Module {
  final String id;
  final String title;
  final int order;
  final Color accent;
  final String emoji;

  const Module({
    required this.id,
    required this.title,
    required this.order,
    required this.accent,
    required this.emoji,
  });

  factory Module.fromJson(Map<String, dynamic> j) => Module(
        id: j['id'] as String,
        title: (j['title'] as String?) ?? j['id'] as String,
        order: (j['order'] as num?)?.toInt() ?? 0,
        accent: parseAccent(j['accent'] as String?),
        emoji: (j['emoji'] as String?) ?? '⭐',
      );
}

/// Одна карточка-экран внутри урока (свайпается).
class LessonScreen {
  final String title;
  final String emoji;
  final Color accent;
  final List<String> paragraphs;

  const LessonScreen({
    required this.title,
    required this.emoji,
    required this.accent,
    required this.paragraphs,
  });

  factory LessonScreen.fromJson(Map<String, dynamic> j) => LessonScreen(
        title: (j['title'] as String?) ?? '',
        emoji: (j['emoji'] as String?) ?? '✨',
        accent: parseAccent(j['accent'] as String?),
        paragraphs: ((j['paragraphs'] as List?) ?? const [])
            .whereType<String>()
            .toList(),
      );
}

/// Вопрос квиза в конце урока.
class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  /// Валидна, если есть вопрос, минимум 2 варианта и индекс верного попадает
  /// в диапазон — иначе запись бессмысленна и её лучше пропустить.
  bool get isValid =>
      question.isNotEmpty && options.length >= 2 && correctIndex >= 0 && correctIndex < options.length;

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        question: (j['question'] as String?) ?? '',
        options:
            ((j['options'] as List?) ?? const []).whereType<String>().toList(),
        correctIndex: (j['correctIndex'] as num?)?.toInt() ?? -1,
        explanation: (j['explanation'] as String?) ?? '',
      );
}

/// Действие, которое кнопка «попробуй на своём портфеле» просит выполнить
/// у интегратора (переход между вкладками — не наша забота, только сигнал).
enum TryItAction {
  openMarket,
  openTheme,
  openAsset,
  /// Неизвестное будущее действие — не роняем разбор, просто ничего не делаем.
  unknown,
}

TryItAction _parseTryItAction(String? raw) => switch (raw) {
      'open_market' => TryItAction.openMarket,
      'open_theme' => TryItAction.openTheme,
      'open_asset' => TryItAction.openAsset,
      _ => TryItAction.unknown,
    };

/// Приглашение попробовать что-то в симуляторе сразу после урока.
class TryIt {
  final TryItAction action;
  final String? theme; // id темы — для open_theme
  final String? symbol; // тикер — для open_asset
  final String text;

  const TryIt({
    required this.action,
    this.theme,
    this.symbol,
    required this.text,
  });

  factory TryIt.fromJson(Map<String, dynamic> j) => TryIt(
        action: _parseTryItAction(j['action'] as String?),
        theme: j['theme'] as String?,
        symbol: j['symbol'] as String?,
        text: (j['text'] as String?) ?? 'Загляни в симулятор',
      );
}

/// Один микро-урок.
class Lesson {
  final String id;
  final String moduleId;
  final int order;
  final String title;
  final List<LessonScreen> screens;
  final List<QuizQuestion> quiz;
  final TryIt? tryIt;
  final String? disclaimer;

  const Lesson({
    required this.id,
    required this.moduleId,
    required this.order,
    required this.title,
    required this.screens,
    required this.quiz,
    this.tryIt,
    this.disclaimer,
  });

  /// Без экранов урок показать нечего — считаем запись битой.
  bool get isValid => id.isNotEmpty && screens.isNotEmpty;

  factory Lesson.fromJson(Map<String, dynamic> j) {
    final screensRaw = (j['screens'] as List?) ?? const [];
    final screens = <LessonScreen>[];
    for (final raw in screensRaw) {
      try {
        screens.add(LessonScreen.fromJson(raw as Map<String, dynamic>));
      } catch (_) {
        // битая карточка-экран пропускается, урок не рушится целиком
      }
    }
    final quizRaw = (j['quiz'] as List?) ?? const [];
    final quiz = <QuizQuestion>[];
    for (final raw in quizRaw) {
      try {
        final q = QuizQuestion.fromJson(raw as Map<String, dynamic>);
        if (q.isValid) quiz.add(q);
      } catch (_) {}
    }
    TryIt? tryIt;
    final tryItRaw = j['tryIt'];
    if (tryItRaw is Map<String, dynamic>) {
      try {
        tryIt = TryIt.fromJson(tryItRaw);
      } catch (_) {}
    }
    return Lesson(
      id: (j['id'] as String?) ?? '',
      moduleId: (j['module'] as String?) ?? '',
      order: (j['order'] as num?)?.toInt() ?? 0,
      title: (j['title'] as String?) ?? '',
      screens: screens,
      quiz: quiz,
      tryIt: tryIt,
      disclaimer: j['disclaimer'] as String?,
    );
  }
}

/// Термин глоссария.
class GlossaryTerm {
  final String id;
  final String term;
  final String definition;

  const GlossaryTerm({
    required this.id,
    required this.term,
    required this.definition,
  });

  factory GlossaryTerm.fromJson(Map<String, dynamic> j) => GlossaryTerm(
        id: (j['id'] as String?) ?? '',
        term: (j['term'] as String?) ?? '',
        definition: (j['definition'] as String?) ?? '',
      );
}

/// Тема-подборка (описание для карточки «попробуй» и вкладки Рынки).
/// Не путать с [Module] — это тематическая коллекция активов, не раздел уроков.
class ThemeInfo {
  final String id;
  final String title;
  final String emoji;
  final Color accent;
  final String description;

  const ThemeInfo({
    required this.id,
    required this.title,
    required this.emoji,
    required this.accent,
    required this.description,
  });

  factory ThemeInfo.fromJson(Map<String, dynamic> j) => ThemeInfo(
        id: (j['id'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        emoji: (j['emoji'] as String?) ?? '⭐',
        accent: parseAccent(j['accent'] as String?),
        description: (j['description'] as String?) ?? '',
      );
}

// ==================== агрегат + разбор ====================

/// Весь контент «Учёбы» одним снимком.
class LessonsContent {
  final List<Module> modules;
  final List<Lesson> lessons;
  final List<GlossaryTerm> glossary;
  final List<ThemeInfo> themes;

  const LessonsContent({
    required this.modules,
    required this.lessons,
    required this.glossary,
    required this.themes,
  });

  static const empty =
      LessonsContent(modules: [], lessons: [], glossary: [], themes: []);

  bool get isEmpty => lessons.isEmpty;

  Module? moduleById(String id) {
    for (final m in modules) {
      if (m.id == id) return m;
    }
    return null;
  }

  Lesson? lessonById(String id) {
    for (final l in lessons) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// Модули по возрастанию [Module.order].
  List<Module> get modulesSorted =>
      [...modules]..sort((a, b) => a.order.compareTo(b.order));

  /// Уроки модуля по возрастанию [Lesson.order].
  List<Lesson> lessonsOf(String moduleId) {
    final list = lessons.where((l) => l.moduleId == moduleId).toList();
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  /// Все уроки одним списком: сквозной порядок — модуль за модулем
  /// (по order модуля), внутри модуля — по order урока. Это и есть
  /// «маршрут» для разблокировки/следующего урока.
  List<Lesson> get lessonsInPathOrder {
    final out = <Lesson>[];
    for (final m in modulesSorted) {
      out.addAll(lessonsOf(m.id));
    }
    // Уроки без известного модуля (защита от рассинхрона контента) — в конец.
    final orphanModuleIds = modules.map((m) => m.id).toSet();
    for (final l in lessons) {
      if (!orphanModuleIds.contains(l.moduleId)) out.add(l);
    }
    return out;
  }

  List<String> get lessonIdsInPathOrder =>
      lessonsInPathOrder.map((l) => l.id).toList();

  GlossaryTerm? termById(String id) {
    for (final t in glossary) {
      if (t.id == id) return t;
    }
    return null;
  }

  ThemeInfo? themeById(String id) {
    for (final t in themes) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Чистый разбор из сырых JSON-строк (по одной на файл). null — файл не
  /// прочитался (нет ассета/сеть/whatever) — секция станет пустой.
  /// Специально pure/статичный — не трогает Flutter-биндинги, поэтому
  /// тестируется без TestWidgetsFlutterBinding и без сборки ассетов.
  factory LessonsContent.parse({
    String? lessonsJson,
    String? themesJson,
    String? glossaryJson,
  }) {
    return LessonsContent(
      modules: _parseModules(lessonsJson),
      lessons: _parseLessons(lessonsJson),
      themes: _parseThemes(themesJson),
      glossary: _parseGlossary(glossaryJson),
    );
  }

  static List<Module> _parseModules(String? raw) {
    final json = _decode(raw);
    final list = json is Map<String, dynamic> ? json['modules'] : null;
    if (list is! List) return const [];
    final out = <Module>[];
    for (final item in list) {
      try {
        out.add(Module.fromJson(item as Map<String, dynamic>));
      } catch (_) {}
    }
    return out;
  }

  static List<Lesson> _parseLessons(String? raw) {
    final json = _decode(raw);
    final list = json is Map<String, dynamic> ? json['lessons'] : null;
    if (list is! List) return const [];
    final out = <Lesson>[];
    for (final item in list) {
      try {
        final l = Lesson.fromJson(item as Map<String, dynamic>);
        if (l.isValid) out.add(l);
      } catch (_) {
        // одна кривая запись не должна ронять остальные 29 уроков
      }
    }
    return out;
  }

  static List<ThemeInfo> _parseThemes(String? raw) {
    final json = _decode(raw);
    final list = json is Map<String, dynamic> ? json['themes'] : null;
    if (list is! List) return const [];
    final out = <ThemeInfo>[];
    for (final item in list) {
      try {
        out.add(ThemeInfo.fromJson(item as Map<String, dynamic>));
      } catch (_) {}
    }
    return out;
  }

  static List<GlossaryTerm> _parseGlossary(String? raw) {
    final json = _decode(raw);
    final list = json is Map<String, dynamic> ? json['terms'] : null;
    if (list is! List) return const [];
    final out = <GlossaryTerm>[];
    for (final item in list) {
      try {
        out.add(GlossaryTerm.fromJson(item as Map<String, dynamic>));
      } catch (_) {}
    }
    return out;
  }

  static Object? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null; // битый файл целиком — не роняем приложение
    }
  }
}

// ==================== мелкий текстовый инструментарий ====================

/// Русское склонение «день/дня/дней» по числу. Заглушка до локализации —
/// волна 3 (EN/ES) заменит на intl plural, здесь просто не хотим дублировать
/// одну и ту же функцию в LearnScreen и LessonPlayer.
String pluralDaysRu(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 14) return 'дней';
  if (mod10 == 1) return 'день';
  if (mod10 >= 2 && mod10 <= 4) return 'дня';
  return 'дней';
}

// ==================== загрузка из ассетов ====================

/// Пути к контенту в ассетах (см. pubspec.yaml → flutter/assets).
///
/// Базовые файлы без суффикса (`lessons.json` и т.д.) — русский контент,
/// он был первым и остаётся фолбэком. Переводы на en/es лежат рядом с
/// суффиксом языка (`lessons.en.json`, `lessons.es.json`, аналогично для
/// themes/glossary) — их наполняет отдельная волна перевода контента
/// (content/, app/assets/content/), эта волна (лок. UI) только умеет их
/// найти и устойчиво откатиться на русский, если перевод ещё не готов.
class LessonsPaths {
  const LessonsPaths._();
  static const lessonsBase = 'assets/content/lessons.json';
  static const themesBase = 'assets/content/themes.json';
  static const glossaryBase = 'assets/content/glossary.json';

  static String lessonsFor(String lang) =>
      lang == 'ru' ? lessonsBase : 'assets/content/lessons.$lang.json';
  static String themesFor(String lang) =>
      lang == 'ru' ? themesBase : 'assets/content/themes.$lang.json';
  static String glossaryFor(String lang) =>
      lang == 'ru' ? glossaryBase : 'assets/content/glossary.$lang.json';
}

/// Дверь к контенту уроков для UI. Читает bundle → зовёт чистый парсер.
/// [bundle] подменяется в тестах (или контент передаётся напрямую через
/// [LessonsContent.parse], без похода в ассеты вообще).
///
/// [lang] — 'ru' | 'en' | 'es' (см. [AppSettings.resolvedLanguageCode]).
/// Пробуем файл нужного языка, а если его ещё нет в ассетах (перевод
/// контента не готов/не задеплоен) — тихо откатываемся на базовый русский,
/// чтобы экран «Учёба» никогда не оставался пустым.
class LessonsRepo {
  final AssetBundle _bundle;
  final String Function() lang;

  LessonsRepo({AssetBundle? bundle, String Function()? lang})
      : _bundle = bundle ?? rootBundle,
        lang = lang ?? (() => 'ru');

  Future<LessonsContent> load() async {
    final l = lang();
    final lessonsJson = await _tryRead(LessonsPaths.lessonsFor(l)) ??
        await _tryRead(LessonsPaths.lessonsBase);
    final themesJson = await _tryRead(LessonsPaths.themesFor(l)) ??
        await _tryRead(LessonsPaths.themesBase);
    final glossaryJson = await _tryRead(LessonsPaths.glossaryFor(l)) ??
        await _tryRead(LessonsPaths.glossaryBase);
    return LessonsContent.parse(
      lessonsJson: lessonsJson,
      themesJson: themesJson,
      glossaryJson: glossaryJson,
    );
  }

  Future<String?> _tryRead(String key) async {
    try {
      return await _bundle.loadString(key);
    } catch (_) {
      return null; // ассет не задеплоен/не собран — секция станет пустой
    }
  }
}
