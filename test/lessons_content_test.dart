/// Разбор контента «Учёбы»: реальный content/*.json (30 уроков) + устойчивость
/// к битым записям и целиком кривым файлам. Чистые (не виджет-) тесты —
/// LessonsContent.parse не трогает Flutter-биндинги, поэтому идёт без
/// TestWidgetsFlutterBinding и без сборки ассетов (см. lessons.dart).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/services/lessons.dart';

void main() {
  late String lessonsJson;
  late String themesJson;
  late String glossaryJson;

  setUpAll(() {
    lessonsJson = File('assets/content/lessons.json').readAsStringSync();
    themesJson = File('assets/content/themes.json').readAsStringSync();
    glossaryJson = File('assets/content/glossary.json').readAsStringSync();
  });

  group('разбор реального контента', () {
    test('загружаются все 30 уроков в 5 модулях', () {
      final content = LessonsContent.parse(
        lessonsJson: lessonsJson,
        themesJson: themesJson,
        glossaryJson: glossaryJson,
      );
      expect(content.lessons.length, 30);
      expect(content.modules.length, 5);
      expect(content.isEmpty, isFalse);
    });

    test('каждый модуль содержит ровно 6 уроков по возрастанию order', () {
      final content = LessonsContent.parse(lessonsJson: lessonsJson);
      for (final m in content.modulesSorted) {
        final ls = content.lessonsOf(m.id);
        expect(ls.length, 6, reason: 'модуль ${m.id}');
        for (var i = 1; i < ls.length; i++) {
          expect(ls[i].order, greaterThan(ls[i - 1].order));
        }
      }
    });

    test('сквозной маршрут даёт 30 уникальных id по порядку модулей', () {
      final content = LessonsContent.parse(lessonsJson: lessonsJson);
      final ids = content.lessonIdsInPathOrder;
      expect(ids.length, 30);
      expect(ids.toSet().length, 30);
      // Первый урок маршрута — приветствие, последний — модуль психологии.
      expect(ids.first, 'welcome-to-polaris');
      final lastModule = content.modulesSorted.last;
      expect(content.lessonById(ids.last)!.moduleId, lastModule.id);
    });

    test('у первого урока есть экраны, квиз и tryIt с открытием рынка', () {
      final content = LessonsContent.parse(lessonsJson: lessonsJson);
      final first = content.lessonById('welcome-to-polaris');
      expect(first, isNotNull);
      expect(first!.screens, isNotEmpty);
      expect(first.quiz, isNotEmpty);
      final q = first.quiz.first;
      expect(q.correctIndex, inInclusiveRange(0, q.options.length - 1));
      expect(first.tryIt, isNotNull);
      expect(first.tryIt!.action, TryItAction.openMarket);
    });

    test('уроки с tryIt по теме несут id темы, существующей в themes.json', () {
      final content = LessonsContent.parse(
        lessonsJson: lessonsJson,
        themesJson: themesJson,
      );
      final withThemeTryIt = content.lessons
          .where((l) => l.tryIt?.action == TryItAction.openTheme)
          .toList();
      expect(withThemeTryIt, isNotEmpty);
      for (final l in withThemeTryIt) {
        expect(l.tryIt!.theme, isNotNull);
        expect(content.themeById(l.tryIt!.theme!), isNotNull,
            reason: 'тема ${l.tryIt!.theme} из урока ${l.id} должна существовать');
      }
    });

    test('темы и глоссарий разбираются', () {
      final content = LessonsContent.parse(
        lessonsJson: lessonsJson,
        themesJson: themesJson,
        glossaryJson: glossaryJson,
      );
      expect(content.themes, isNotEmpty);
      expect(content.glossary, isNotEmpty);
      expect(content.themeById('ai'), isNotNull);
      expect(content.termById('stock'), isNotNull);
    });
  });

  group('устойчивость к мусору', () {
    test('битая запись урока пропускается, валидные грузятся', () {
      final raw = jsonEncode({
        'modules': [
          {'id': 'm1', 'title': 'Модуль', 'order': 1, 'accent': '#112233', 'emoji': '🌟'}
        ],
        'lessons': [
          {
            'id': 'ok-1',
            'module': 'm1',
            'order': 1,
            'title': 'Ок',
            'screens': [
              {'title': 'A', 'emoji': '🙂', 'accent': '#112233', 'paragraphs': ['текст']}
            ],
            'quiz': [],
          },
          {'id': 'broken', 'module': 'm1', 'order': 2, 'title': 'Сломан'}, // нет screens
          'просто строка вместо объекта',
          {'screens': []}, // нет id, нет экранов
        ],
      });
      final content = LessonsContent.parse(lessonsJson: raw);
      expect(content.lessons.length, 1);
      expect(content.lessons.first.id, 'ok-1');
      expect(content.modules.length, 1);
    });

    test('битый вопрос квиза (без верного индекса) пропускается', () {
      final raw = jsonEncode({
        'lessons': [
          {
            'id': 'l1',
            'module': 'm1',
            'order': 1,
            'title': 'Урок',
            'screens': [
              {'title': 'A', 'paragraphs': ['текст']}
            ],
            'quiz': [
              {'question': 'Ок?', 'options': ['Да', 'Нет'], 'correctIndex': 0, 'explanation': 'ясно'},
              {'question': 'Битый', 'options': ['Да'], 'correctIndex': 5, 'explanation': 'вне диапазона'},
              {'question': 'Без опций', 'options': [], 'correctIndex': 0, 'explanation': ''},
            ],
          },
        ],
      });
      final content = LessonsContent.parse(lessonsJson: raw);
      expect(content.lessons.single.quiz.length, 1);
      expect(content.lessons.single.quiz.single.question, 'Ок?');
    });

    test('целиком не-JSON контент не роняет разбор — пустые списки', () {
      final content = LessonsContent.parse(
        lessonsJson: 'вот это точно не json {{{',
        themesJson: 'мусор мусор',
        glossaryJson: null,
      );
      expect(content.lessons, isEmpty);
      expect(content.themes, isEmpty);
      expect(content.glossary, isEmpty);
      expect(content.isEmpty, isTrue);
    });

    test('всё null (файлы не нашлись) — пустой, не падающий результат', () {
      final content = LessonsContent.parse();
      expect(content.lessons, isEmpty);
      expect(content.modules, isEmpty);
      expect(content.isEmpty, isTrue);
    });

    test('битый термин глоссария пропускается, валидные грузятся', () {
      final raw = jsonEncode({
        'terms': [
          {'id': 't1', 'term': 'Термин', 'definition': 'Определение'},
          'мусор вместо объекта',
        ]
      });
      final content = LessonsContent.parse(glossaryJson: raw);
      expect(content.glossary.length, 1);
      expect(content.glossary.first.term, 'Термин');
    });
  });

  group('вспомогательное', () {
    test('parseAccent разбирает #RRGGBB и падает на дефолт для мусора', () {
      expect(parseAccent('#6C8EFF'), const Color(0xFF6C8EFF));
      final fallback = parseAccent(null);
      expect(parseAccent('не похоже на цвет'), fallback);
      expect(parseAccent(''), fallback);
    });

    test('pluralDaysRu — русское склонение', () {
      expect(pluralDaysRu(1), 'день');
      expect(pluralDaysRu(2), 'дня');
      expect(pluralDaysRu(5), 'дней');
      expect(pluralDaysRu(11), 'дней');
      expect(pluralDaysRu(21), 'день');
      expect(pluralDaysRu(0), 'дней');
    });
  });

  group('LessonsRepo', () {
    test('несуществующий ассет не роняет load(), контент пуст', () async {
      final repo = LessonsRepo(bundle: _FakeBundle(const {}));
      final content = await repo.load();
      expect(content.isEmpty, isTrue);
    });

    test('читает три файла из bundle и парсит их в контент', () async {
      final repo = LessonsRepo(bundle: _FakeBundle({
        LessonsPaths.lessonsBase: lessonsJson,
        LessonsPaths.themesBase: themesJson,
        LessonsPaths.glossaryBase: glossaryJson,
      }));
      final content = await repo.load();
      expect(content.lessons.length, 30);
      expect(content.themes, isNotEmpty);
      expect(content.glossary, isNotEmpty);
    });
  });
}

/// Мини-подмена AssetBundle для тестов LessonsRepo — без реальной сборки
/// ассетов. Возвращает заранее заданные строки по ключу пути.
class _FakeBundle extends AssetBundle {
  final Map<String, String> files;
  _FakeBundle(this.files);

  @override
  Future<ByteData> load(String key) async {
    final content = files[key];
    if (content == null) throw Exception('asset not found: $key');
    final bytes = utf8.encode(content);
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final content = files[key];
    if (content == null) throw Exception('asset not found: $key');
    return content;
  }
}
