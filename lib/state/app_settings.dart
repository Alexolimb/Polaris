/// Настройки игрока Polaris, которые не относятся напрямую к портфелю или
/// обучению: пройден ли онбординг, зачем пользователь пришёл в приложение,
/// какие типы локальных уведомлений включены, предпочтение языка (задел под
/// локализацию волны 3).
///
/// Тот же паттерн, что у [LearnState]/[PortfolioState]: персистентность через
/// [StorageGateway], терпимость к битому снапшоту (не роняем старт), гостевой
/// режим — никакого аккаунта.
library;

import 'package:flutter/foundation.dart';

import '../services/storage.dart';

const _settingsSnapshotKey = 'polaris.settings.v1';

/// Зачем пользователь пришёл — выбор на шаге 4 онбординга. Влияет только на
/// тон приветствия (и, возможно, на порядок первых уроков в будущем) —
/// никогда не используется для персональных инвест-рекомендаций.
enum UserGoal { saveForFuture, learnInvesting, curious }

UserGoal? _parseGoal(String? name) {
  for (final g in UserGoal.values) {
    if (g.name == name) return g;
  }
  return null;
}

/// Предпочтение языка интерфейса: авто — по локали устройства, иначе
/// принудительный выбор. Полная локализация (arb-файлы) — волна 3, здесь
/// только хранение флага, чтобы экран настроек уже мог его переключать.
enum LocalePref { auto, en, ru, es }

LocalePref _parseLocalePref(String? name) {
  for (final l in LocalePref.values) {
    if (l.name == name) return l;
  }
  return LocalePref.auto;
}

/// Какие типы локальных уведомлений включены. По решению Алекса (ответы
/// фазы вопросов, 20.07.2026): урок дня + недельная сводка включены по
/// умолчанию (полезные, не давящие), дивиденд/крупные движения — выключены
/// (чтобы не заваливать новичка событиями, включает сам в настройках).
@immutable
class NotificationPrefs {
  final bool lessonReminder;
  final bool weeklySummary;
  final bool dividendPaid;
  final bool bigMoves;

  const NotificationPrefs({
    this.lessonReminder = true,
    this.weeklySummary = true,
    this.dividendPaid = false,
    this.bigMoves = false,
  });

  NotificationPrefs copyWith({
    bool? lessonReminder,
    bool? weeklySummary,
    bool? dividendPaid,
    bool? bigMoves,
  }) =>
      NotificationPrefs(
        lessonReminder: lessonReminder ?? this.lessonReminder,
        weeklySummary: weeklySummary ?? this.weeklySummary,
        dividendPaid: dividendPaid ?? this.dividendPaid,
        bigMoves: bigMoves ?? this.bigMoves,
      );

  Map<String, dynamic> toJson() => {
        'lessonReminder': lessonReminder,
        'weeklySummary': weeklySummary,
        'dividendPaid': dividendPaid,
        'bigMoves': bigMoves,
      };

  factory NotificationPrefs.fromJson(Map<String, dynamic> j) => NotificationPrefs(
        lessonReminder: j['lessonReminder'] as bool? ?? true,
        weeklySummary: j['weeklySummary'] as bool? ?? true,
        dividendPaid: j['dividendPaid'] as bool? ?? false,
        bigMoves: j['bigMoves'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is NotificationPrefs &&
      other.lessonReminder == lessonReminder &&
      other.weeklySummary == weeklySummary &&
      other.dividendPaid == dividendPaid &&
      other.bigMoves == bigMoves;

  @override
  int get hashCode =>
      Object.hash(lessonReminder, weeklySummary, dividendPaid, bigMoves);
}

class AppSettings extends ChangeNotifier {
  final StorageGateway storage;

  bool _loaded = false;
  bool get loaded => _loaded;

  bool _onboardingDone = false;
  UserGoal? _userGoal;
  NotificationPrefs _notifications = const NotificationPrefs();
  LocalePref _localePref = LocalePref.auto;

  /// Ключ Finnhub — источник НАСТОЯЩИХ биржевых цен. Пусто = как раньше,
  /// синтетические цены с честным бейджем «ДЕМО».
  /// Хранится только на этом устройстве и никуда не отправляется, кроме самого
  /// Finnhub (тот же принцип, что у ключа Gemini в Dayo).
  String _finnhubKey = '';

  AppSettings({StorageGateway? storage}) : storage = storage ?? MemoryStorage();

  // ---- чтение ----

  bool get onboardingDone => _onboardingDone;
  UserGoal? get userGoal => _userGoal;
  NotificationPrefs get notifications => _notifications;
  LocalePref get localePref => _localePref;
  String get finnhubKey => _finnhubKey;
  bool get hasRealQuotesKey => _finnhubKey.trim().isNotEmpty;

  /// Язык интерфейса как код 'ru' | 'en' | 'es' — учитывает выбор в настройках,
  /// а для [LocalePref.auto] распознаёт язык устройства (тот же принцип, что
  /// раньше был захардкожен только для Cosmo — теперь общий для всего UI:
  /// MaterialApp.locale, ChatState.lang, уведомления, контент уроков).
  String get resolvedLanguageCode => switch (_localePref) {
        LocalePref.en => 'en',
        LocalePref.ru => 'ru',
        LocalePref.es => 'es',
        LocalePref.auto => _deviceLanguageCode(),
      };

  static String _deviceLanguageCode() {
    final code = PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    return (code == 'ru' || code == 'es') ? code : 'en';
  }

  // Плоские геттеры-удобства — их читает NotificationsController, чтобы не
  // тащить весь NotificationPrefs в каждый вызов.
  bool get notifyLessonReminder => _notifications.lessonReminder;
  bool get notifyWeeklySummary => _notifications.weeklySummary;
  bool get notifyDividend => _notifications.dividendPaid;
  bool get notifyBigMoves => _notifications.bigMoves;

  // ---- загрузка/сохранение ----

  Future<void> load() async {
    final snap = await storage.readJson(_settingsSnapshotKey);
    if (snap != null) {
      try {
        _onboardingDone = snap['onboardingDone'] as bool? ?? false;
      } catch (_) {}
      try {
        _userGoal = _parseGoal(snap['userGoal'] as String?);
      } catch (_) {}
      try {
        final n = snap['notifications'];
        if (n is Map<String, dynamic>) {
          _notifications = NotificationPrefs.fromJson(n);
        }
      } catch (_) {}
      try {
        _localePref = _parseLocalePref(snap['localePref'] as String?);
      } catch (_) {}
      try {
        _finnhubKey = (snap['finnhubKey'] as String?)?.trim() ?? '';
      } catch (_) {}
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    await storage.writeJson(_settingsSnapshotKey, {
      'onboardingDone': _onboardingDone,
      'userGoal': _userGoal?.name,
      'notifications': _notifications.toJson(),
      'localePref': _localePref.name,
      'finnhubKey': _finnhubKey,
    });
  }

  /// Вставить/убрать ключ настоящих котировок.
  Future<void> setFinnhubKey(String key) async {
    final next = key.trim();
    if (next == _finnhubKey) return;
    _finnhubKey = next;
    await _persist();
    notifyListeners();
  }

  // ---- операции ----

  /// Завершение онбординга (последний слайд-дисклеймер): фиксируем цель,
  /// выбранную на шаге 4, и ставим флаг «больше не показывать онбординг».
  Future<void> completeOnboarding(UserGoal goal) async {
    _onboardingDone = true;
    _userGoal = goal;
    await _persist();
    notifyListeners();
  }

  Future<void> setNotificationPrefs(NotificationPrefs prefs) async {
    if (prefs == _notifications) return;
    _notifications = prefs;
    await _persist();
    notifyListeners();
  }

  Future<void> setLessonReminder(bool v) =>
      setNotificationPrefs(_notifications.copyWith(lessonReminder: v));
  Future<void> setWeeklySummary(bool v) =>
      setNotificationPrefs(_notifications.copyWith(weeklySummary: v));
  Future<void> setDividendPaid(bool v) =>
      setNotificationPrefs(_notifications.copyWith(dividendPaid: v));
  Future<void> setBigMoves(bool v) =>
      setNotificationPrefs(_notifications.copyWith(bigMoves: v));

  Future<void> setLocalePref(LocalePref pref) async {
    if (pref == _localePref) return;
    _localePref = pref;
    await _persist();
    notifyListeners();
  }

  /// Полный сброс — для тестов и дев-меню (портфель сбрасывается отдельно).
  Future<void> reset() async {
    _onboardingDone = false;
    _userGoal = null;
    _notifications = const NotificationPrefs();
    _localePref = LocalePref.auto;
    await _persist();
    notifyListeners();
  }
}
