/// Прогресс игрока во вкладке «Учёба» (волна 2б): какие уроки пройдены,
/// результаты квизов, стрик (сколько дней подряд занимался).
///
/// Персистентность — через [StorageGateway] (тот же паттерн, что и у
/// [PortfolioState]): снапшот на устройстве, терпимость к битому JSON.
/// Список/порядок уроков сюда не тащим — методы принимают его параметром
/// (как [PortfolioState] принимает котировки), это разделяемое ядро не
/// зависит от того, как контент сейчас загружен.
library;

import 'package:flutter/foundation.dart';

import '../services/storage.dart';

const _learnSnapshotKey = 'polaris.learn.v1';

/// Результат прохождения квиза одного урока (последняя попытка).
class QuizResult {
  final int correct;
  final int total;
  final DateTime ts;

  const QuizResult({required this.correct, required this.total, required this.ts});

  /// Доля верных ответов 0..1 (total == 0 — квиза не было, считаем «сдано»).
  double get ratio => total <= 0 ? 1.0 : correct / total;

  Map<String, dynamic> toJson() => {
        'correct': correct,
        'total': total,
        'ts': ts.toIso8601String(),
      };

  factory QuizResult.fromJson(Map<String, dynamic> j) => QuizResult(
        correct: (j['correct'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        ts: DateTime.tryParse(j['ts'] as String? ?? '') ?? DateTime.now(),
      );
}

class LearnState extends ChangeNotifier {
  final StorageGateway storage;
  final DateTime Function() _now;

  bool _loaded = false;
  bool get loaded => _loaded;

  // Барьер против notifyListeners после dispose (await _persist перед notify).
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  final Set<String> _completed = {};
  final Map<String, QuizResult> _quizResults = {};

  // Стрик: дата (без времени) последнего пройденного урока + счётчики.
  DateTime? _lastLessonDate;
  int _currentStreak = 0;
  int _longestStreak = 0;

  LearnState({StorageGateway? storage, DateTime Function()? now})
      : storage = storage ?? MemoryStorage(),
        _now = now ?? DateTime.now;

  // ---- чтение ----

  bool isCompleted(String lessonId) => _completed.contains(lessonId);
  int get completedCount => _completed.length;
  Set<String> get completedLessonIds => Set.unmodifiable(_completed);

  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;
  DateTime? get lastLessonDate => _lastLessonDate;

  /// Урок сегодня уже засчитан (стрик не «горит» — сегодня можно не спешить).
  bool get completedToday =>
      _lastLessonDate != null && _isSameDay(_lastLessonDate!, _now());

  QuizResult? quizResultOf(String lessonId) => _quizResults[lessonId];

  /// Урок доступен для прохождения: первый в общем маршруте (или урок не
  /// найден в списке — не блокируем) ИЛИ предыдущий по маршруту уже пройден.
  /// Пройденный урок тоже «доступен» — можно перепройти.
  bool isUnlocked(String lessonId, List<String> orderedLessonIds) {
    if (_completed.contains(lessonId)) return true;
    final i = orderedLessonIds.indexOf(lessonId);
    if (i <= 0) return true;
    return _completed.contains(orderedLessonIds[i - 1]);
  }

  /// id первого не пройденного урока по маршруту — «следующий урок».
  /// null — маршрут пуст или пройден целиком.
  String? nextLessonId(List<String> orderedLessonIds) {
    for (final id in orderedLessonIds) {
      if (!_completed.contains(id)) return id;
    }
    return null;
  }

  /// Процент прохождения модуля 0..100 по списку id уроков этого модуля.
  double moduleProgressPct(List<String> lessonIdsInModule) {
    if (lessonIdsInModule.isEmpty) return 0;
    final done = lessonIdsInModule.where(_completed.contains).length;
    return done / lessonIdsInModule.length * 100;
  }

  /// Общий процент прохождения по всему маршруту.
  double overallProgressPct(List<String> allLessonIds) =>
      moduleProgressPct(allLessonIds);

  // ---- загрузка/сохранение ----

  Future<void> load() async {
    final snap = await storage.readJson(_learnSnapshotKey);
    if (snap != null) {
      try {
        final completed = snap['completed'];
        if (completed is List) {
          for (final id in completed) {
            if (id is String) _completed.add(id);
          }
        }
      } catch (_) {}
      try {
        final results = snap['quizResults'];
        if (results is Map) {
          results.forEach((key, value) {
            if (key is String && value is Map<String, dynamic>) {
              try {
                _quizResults[key] = QuizResult.fromJson(value);
              } catch (_) {}
            }
          });
        }
      } catch (_) {}
      try {
        final lastDate = snap['lastLessonDate'];
        if (lastDate is String) {
          final parsed = DateTime.tryParse(lastDate);
          if (parsed != null) _lastLessonDate = _dateOnly(parsed);
        }
      } catch (_) {}
      try {
        _currentStreak = (snap['currentStreak'] as num?)?.toInt() ?? 0;
        _longestStreak = (snap['longestStreak'] as num?)?.toInt() ?? 0;
      } catch (_) {}
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    await storage.writeJson(_learnSnapshotKey, {
      'completed': _completed.toList(),
      'quizResults': _quizResults.map((k, v) => MapEntry(k, v.toJson())),
      'lastLessonDate': _lastLessonDate?.toIso8601String(),
      'currentStreak': _currentStreak,
      'longestStreak': _longestStreak,
    });
  }

  // ---- операции ----

  /// Отметить урок пройденным, сохранить результат квиза и обновить стрик.
  /// Повторное прохождение того же урока в тот же день не портит стрик и
  /// просто обновляет результат квиза свежей попыткой.
  Future<void> completeLesson(
    String lessonId, {
    int quizCorrect = 0,
    int quizTotal = 0,
  }) async {
    _completed.add(lessonId);
    if (quizTotal > 0) {
      _quizResults[lessonId] =
          QuizResult(correct: quizCorrect, total: quizTotal, ts: _now());
    }
    _bumpStreak();
    await _persist();
    notifyListeners();
  }

  /// Сбросить весь прогресс обучения (используется вместе с «Начать заново»
  /// портфеля, если Алекс решит их синхронизировать; сам по себе тоже нужен
  /// для тестов/дев-меню).
  Future<void> reset() async {
    _completed.clear();
    _quizResults.clear();
    _lastLessonDate = null;
    _currentStreak = 0;
    _longestStreak = 0;
    await _persist();
    notifyListeners();
  }

  /// Правило стрика: тот же день — не растёт повторно; ровно вчера — +1;
  /// пропуск (2+ дня) или первый урок вообще — сброс на 1.
  void _bumpStreak() {
    final today = _dateOnly(_now());
    final last = _lastLessonDate;
    if (last == null) {
      _currentStreak = 1;
    } else {
      final diff = today.difference(last).inDays;
      if (diff == 0) {
        // уже отмечались сегодня — стрик не трогаем
      } else if (diff == 1) {
        _currentStreak += 1;
      } else {
        _currentStreak = 1;
      }
    }
    _lastLessonDate = today;
    if (_currentStreak > _longestStreak) _longestStreak = _currentStreak;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
