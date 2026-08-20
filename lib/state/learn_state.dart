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

/// Прогресс обучения не сохранён — и урок НЕ засчитан.
///
/// Бросается, когда прогресс не удалось прочитать при запуске (писать поверх
/// нельзя — сотрём всё) или когда запись на устройство не прошла. Экран
/// «Учёба» обязан сказать об этом вслух: молчание здесь стоит человеку всего
/// пройденного и накопленного стрика.
class LearnProgressNotSaved implements Exception {
  final Object? cause;

  const LearnProgressNotSaved([this.cause]);

  @override
  String toString() =>
      'LearnProgressNotSaved${cause == null ? '' : ': $cause'}';
}

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

  /// Когда прогресс правился последний раз. Это время — и только оно — решает
  /// спор двух копий на складе. Не время отправки: у отправителя оно всегда
  /// «сейчас», и побеждал бы не тот, кто занимался последним, а тот, кто
  /// последним открыл приложение.
  DateTime? _changedAt;
  DateTime? get changedAt => _changedAt;

  LearnState({StorageGateway? storage, DateTime Function()? now})
      : storage = storage ?? MemoryStorage(),
        _now = now ?? DateTime.now;

  // ---- чтение ----

  bool isCompleted(String lessonId) => _completed.contains(lessonId);
  int get completedCount => _completed.length;
  Set<String> get completedLessonIds => Set.unmodifiable(_completed);

  /// Живой стрик: если последний урок был сегодня или вчера — хранимое
  /// значение; при пропуске 2+ дней стрик уже «сгорел» (возвращаем 0), даже
  /// если он ещё не пересчитан следующим прохождением. Иначе карточка врала бы
  /// «N дней подряд» после многодневного простоя.
  int get currentStreak {
    final last = _lastLessonDate;
    if (last == null || _currentStreak == 0) return 0;
    return _daysBetween(_dateOnly(_now()), last) <= 1 ? _currentStreak : 0;
  }

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

  /// Прогресс НЕ прочитался с устройства.
  ///
  /// ⚠️ Раньше ошибку чтения никто не ловил: вкладка «Учёба» навсегда
  /// застывала на серых заготовках «загружаю» — ни ошибки, ни кнопки
  /// «повторить». А если человек всё-таки доходил до конца урока в этот
  /// момент, сохранение записывало поверх ПУСТОТУ и стирало все пройденные
  /// уроки и стрик. Найдено ревизией 10.08.2026.
  ///
  /// Теперь: экран говорит вслух и даёт «Попробовать снова», а запись поверх
  /// не пройдёт вообще — [completeLesson] откажется молча портить прогресс.
  bool _loadFailed = false;
  bool get loadFailed => _loadFailed;

  /// Прогресс на устройстве нашёлся, но не разобрался — его отложили в
  /// сторону (см. [PrefsStorage.readJson]). Данные целы, но сказать надо.
  bool _snapshotBityy = false;
  bool get snapshotBityy => _snapshotBityy;

  Future<void> load() async {
    _loadFailed = false;
    final Map<String, dynamic>? snap;
    try {
      snap = await storage.readJson(_learnSnapshotKey);
    } catch (_) {
      // Хранилище отказало целиком. Мы НЕ знаем, что там лежит, — значит
      // писать поверх нельзя ни при каких условиях.
      _loadFailed = true;
      _loaded = true;
      notifyListeners();
      return;
    }
    _snapshotBityy = PrefsStorage.bitaya(_learnSnapshotKey);
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
      try {
        _changedAt = DateTime.tryParse(snap['changedAt'] as String? ?? '');
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
      if (_changedAt != null) 'changedAt': _changedAt!.toIso8601String(),
    });
  }

  // ---- синхронизация ----

  /// Прогресс в том виде, в каком он уезжает на склад.
  Map<String, dynamic> slepokDlyaObmena() => {
        'completed': _completed.toList()..sort(),
        'quizResults': _quizResults.map((k, v) => MapEntry(k, v.toJson())),
        if (_lastLessonDate != null)
          'lastLessonDate': _lastLessonDate!.toIso8601String(),
        'currentStreak': _currentStreak,
        'longestStreak': _longestStreak,
        'changedAt': (_changedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .toUtc()
            .toIso8601String(),
      };

  /// Применить прогресс, получившийся после слияния (см. `LearnMerge`).
  ///
  /// Возвращает false, если записать не удалось: тогда всё остаётся как было.
  /// Если прогресс не прочитался при запуске — не применяем ВООБЩЕ: в памяти
  /// сейчас пусто, и записать поверх значит стереть всё пройденное.
  Future<bool> primenitSliyanie(Map<String, dynamic> merged) async {
    if (_loadFailed) return false;
    final before = (
      completed: Set.of(_completed),
      quiz: Map.of(_quizResults),
      lastDate: _lastLessonDate,
      current: _currentStreak,
      longest: _longestStreak,
      changed: _changedAt,
    );
    _completed
      ..clear()
      ..addAll([
        for (final id in (merged['completed'] as List?) ?? const [])
          if (id is String) id,
      ]);
    _quizResults.clear();
    final results = merged['quizResults'];
    if (results is Map) {
      results.forEach((k, v) {
        if (k is String && v is Map<String, dynamic>) {
          try {
            _quizResults[k] = QuizResult.fromJson(v);
          } catch (_) {}
        }
      });
    }
    final last = DateTime.tryParse(merged['lastLessonDate'] as String? ?? '');
    _lastLessonDate = last == null ? null : _dateOnly(last);
    _currentStreak = (merged['currentStreak'] as num?)?.toInt() ?? 0;
    _longestStreak = (merged['longestStreak'] as num?)?.toInt() ?? 0;
    _changedAt = DateTime.tryParse(merged['changedAt'] as String? ?? '');
    try {
      await _persist();
    } catch (_) {
      _completed
        ..clear()
        ..addAll(before.completed);
      _quizResults
        ..clear()
        ..addAll(before.quiz);
      _lastLessonDate = before.lastDate;
      _currentStreak = before.current;
      _longestStreak = before.longest;
      _changedAt = before.changed;
      notifyListeners();
      return false;
    }
    notifyListeners();
    return true;
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
    // Прогресс не прочитался — в памяти сейчас ПУСТО, и это не «человек ничего
    // не проходил», а «мы не знаем». Записать сейчас = стереть всё пройденное
    // и стрик. Лучше честно отказать.
    if (_loadFailed) throw const LearnProgressNotSaved();
    final before = (
      completed: Set.of(_completed),
      quiz: Map.of(_quizResults),
      lastDate: _lastLessonDate,
      current: _currentStreak,
      longest: _longestStreak,
      changed: _changedAt,
    );
    _completed.add(lessonId);
    if (quizTotal > 0) {
      _quizResults[lessonId] =
          QuizResult(correct: quizCorrect, total: quizTotal, ts: _now());
    }
    _bumpStreak();
    _changedAt = _now().toUtc();
    try {
      await _persist();
    } catch (e) {
      // Не записалось — откатываем и говорим вслух. Иначе урок «пройден» на
      // экране, а после перезапуска его нет: человек уверен, что занимался,
      // а стрик обнулился сам собой.
      _completed
        ..clear()
        ..addAll(before.completed);
      _quizResults
        ..clear()
        ..addAll(before.quiz);
      _lastLessonDate = before.lastDate;
      _currentStreak = before.current;
      _longestStreak = before.longest;
      _changedAt = before.changed;
      notifyListeners();
      throw LearnProgressNotSaved(e);
    }
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
    _changedAt = _now().toUtc();
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
      final diff = _daysBetween(today, last);
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

  /// Разница в КАЛЕНДАРНЫХ днях между двумя датами. Через UTC-полуночи —
  /// иначе в сутки перехода на летнее/зимнее время соседние локальные полуночи
  /// отстоят на 23/25 ч и Duration.inDays даёт неверный 0/2, ломая стрик.
  static int _daysBetween(DateTime a, DateTime b) {
    final ua = DateTime.utc(a.year, a.month, a.day);
    final ub = DateTime.utc(b.year, b.month, b.day);
    return ua.difference(ub).inDays;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
