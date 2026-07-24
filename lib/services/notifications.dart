/// Локальные уведомления Polaris: обёртка над flutter_local_notifications.
///
/// Два уровня:
/// - [NotificationsGateway] — тонкая абстракция над плагином. Настоящая
///   реализация [LocalNotificationsPluginGateway] заворачивает КАЖДЫЙ вызов
///   плагина в try/catch — если плагин не поднялся (неподдерживаемая
///   платформа, тестовое окружение без платформенных каналов) все методы
///   тихо no-op, приложение не падает. [FakeNotificationsGateway] — для
///   тестов, ничего не трогает по-настоящему, только запоминает вызовы.
/// - [NotificationsController] — уровень выше: слушает [AppSettings] и решает,
///   какие уведомления должны быть запланированы прямо сейчас (урок дня,
///   недельная сводка — по флагам), плюс разовые вызовы из кода движка/рынка
///   (дивиденд начислен, крупное движение цены) — тоже с проверкой флага.
///
/// Тексты уведомлений нейтральные и без призывов к сделкам — юридическое
/// требование анти-казино тона (см. .build/plan.md, раздел «Табу»).
library;

import 'dart:async';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../state/app_settings.dart';

/// Стабильные id канала/повторяющихся уведомлений — повторный schedule
/// обновляет существующее, а не плодит дубликаты. Разовые уведомления
/// (дивиденд/движение) получают динамический id по тикеру+типу события.
class NotifIds {
  const NotifIds._();

  static const channelId = 'polaris_default';
  static const channelName = 'Polaris';
  static const channelDescription =
      'Уроки, сводки и события портфеля Polaris';

  static const lessonReminder = 1001;
  static const weeklySummary = 1002;
}

/// Абстракция над плагином уведомлений — чтобы (а) подменять фейком в
/// тестах, (б) изолировать платформенные особенности от остального кода.
abstract class NotificationsGateway {
  Future<void> init();

  /// Ежедневное повторяющееся уведомление в [time] (устройство-локальное).
  Future<void> scheduleDailyAt({
    required int id,
    required TimeOfDay time,
    required String title,
    required String body,
  });

  /// Еженедельное повторяющееся уведомление в день недели [weekday]
  /// (1 = понедельник .. 7 = воскресенье, как [DateTime.weekday]) в [time].
  Future<void> scheduleWeeklyAt({
    required int id,
    required int weekday,
    required TimeOfDay time,
    required String title,
    required String body,
  });

  /// Показать уведомление немедленно (разовое событие — дивиденд, движение).
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  });

  Future<void> cancel(int id);
  Future<void> cancelAll();
}

// --------------------------------------------------------- боевая реализация

/// Боевая реализация на flutter_local_notifications. Любая ошибка плагина
/// (нет платформенного канала, платформа не поддерживает уведомления,
/// разрешение не выдано и т.п.) — молча гасится, метод просто ничего не
/// делает. Уведомления — приятное дополнение, а не критичная функция:
/// они никогда не должны быть причиной падения приложения.
class LocalNotificationsPluginGateway implements NotificationsGateway {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _tzReady = false;

  @override
  Future<void> init() async {
    try {
      _ensureTimezone();

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _plugin.initialize(initSettings);

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        NotifIds.channelId,
        NotifIds.channelName,
        description: NotifIds.channelDescription,
        importance: Importance.defaultImportance,
      ));
      // Android 13+ (API 33) требует явный запрос разрешения на показ
      // уведомлений — без него платформа их просто не покажет.
      await android?.requestNotificationsPermission();
    } catch (_) {
      // Платформа/тест-окружение без поддержки — тихо no-op.
    }
  }

  @override
  Future<void> scheduleDailyAt({
    required int id,
    required TimeOfDay time,
    required String title,
    required String body,
  }) async {
    try {
      _ensureTimezone();
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        _nextInstanceOfTime(time),
        _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {}
  }

  @override
  Future<void> scheduleWeeklyAt({
    required int id,
    required int weekday,
    required TimeOfDay time,
    required String title,
    required String body,
  }) async {
    try {
      _ensureTimezone();
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        _nextInstanceOfWeekday(weekday, time),
        _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (_) {}
  }

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.show(id, title, body, _details());
    } catch (_) {}
  }

  @override
  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  @override
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  NotificationDetails _details() => const NotificationDetails(
        android: AndroidNotificationDetails(
          NotifIds.channelId,
          NotifIds.channelName,
          channelDescription: NotifIds.channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      );

  void _ensureTimezone() {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(_deviceLocation());
    _tzReady = true;
  }

  /// Без пакета flutter_timezone честного имени зоны не узнать — подбираем
  /// локацию из базы timezone по текущему смещению устройства (тот же
  /// UTC-офсет прямо сейчас). Если совпадения нет (редкий кейс) — падаем на
  /// UTC: расписание всё равно сработает, просто по UTC-времени.
  tz.Location _deviceLocation() {
    try {
      // timezone 0.9: TimeZone.offset — миллисекунды (int).
      final offsetMs = DateTime.now().timeZoneOffset.inMilliseconds;
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (loc.currentTimeZone.offset == offsetMs) return loc;
      }
    } catch (_) {}
    return tz.UTC;
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextInstanceOfWeekday(int weekday, TimeOfDay time) {
    var scheduled = _nextInstanceOfTime(time);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

// ------------------------------------------------------------- фейк-реализация

/// Фейк для тестов: ничего не трогает по-настоящему, только запоминает,
/// что было запланировано/отменено/показано.
class FakeNotificationsGateway implements NotificationsGateway {
  bool initCalled = false;
  bool cancelAllCalled = false;
  final Map<int, ({String title, String body})> daily = {};
  final Map<int, ({int weekday, String title, String body})> weekly = {};
  final List<({int id, String title, String body})> shown = [];
  final Set<int> cancelled = {};

  @override
  Future<void> init() async {
    initCalled = true;
  }

  @override
  Future<void> scheduleDailyAt({
    required int id,
    required TimeOfDay time,
    required String title,
    required String body,
  }) async {
    weekly.remove(id);
    cancelled.remove(id);
    daily[id] = (title: title, body: body);
  }

  @override
  Future<void> scheduleWeeklyAt({
    required int id,
    required int weekday,
    required TimeOfDay time,
    required String title,
    required String body,
  }) async {
    daily.remove(id);
    cancelled.remove(id);
    weekly[id] = (weekday: weekday, title: title, body: body);
  }

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    shown.add((id: id, title: title, body: body));
  }

  @override
  Future<void> cancel(int id) async {
    daily.remove(id);
    weekly.remove(id);
    cancelled.add(id);
  }

  @override
  Future<void> cancelAll() async {
    daily.clear();
    weekly.clear();
    cancelAllCalled = true;
  }
}

// --------------------------------------------------------------- контроллер

/// Связывает [AppSettings] (флаги вкл/выкл) с [NotificationsGateway]:
/// при инициализации и при каждом изменении настроек — (пере)ставит или
/// отменяет повторяющиеся уведомления; разовые события (дивиденд, крупное
/// движение) дёргаются кодом движка/рынка через [notifyDividendPaid] /
/// [notifyBigMoves] и сами проверяют флаг перед показом.
class NotificationsController {
  final NotificationsGateway gateway;
  final AppSettings settings;

  /// Время урока-напоминания — вечер буднего дня, удобное большинству.
  /// Настройка времени пользователем — не в MVP (см. .build/answers.md).
  final TimeOfDay lessonTime;
  final TimeOfDay weeklyTime;
  final int weeklyWeekday;

  NotificationsController({
    required this.gateway,
    required this.settings,
    this.lessonTime = const TimeOfDay(hour: 19, minute: 0),
    this.weeklyTime = const TimeOfDay(hour: 10, minute: 0),
    this.weeklyWeekday = DateTime.sunday,
  }) {
    settings.addListener(_onSettingsChanged);
  }

  Future<void> init() async {
    await gateway.init();
    await _applyAll();
  }

  void _onSettingsChanged() {
    // Настройки меняются редко (экран «Ещё») — фоновая асинхронность ок,
    // ошибку внутри applyAll гасит сам gateway.
    unawaited(_applyAll());
  }

  Future<void> _applyAll() async {
    await _applyLesson();
    await _applyWeekly();
  }

  Future<void> _applyLesson() async {
    if (settings.notifyLessonReminder) {
      final t = _NotifText.lessonReminder(settings.resolvedLanguageCode);
      await gateway.scheduleDailyAt(
        id: NotifIds.lessonReminder,
        time: lessonTime,
        title: t.title,
        body: t.body,
      );
    } else {
      await gateway.cancel(NotifIds.lessonReminder);
    }
  }

  Future<void> _applyWeekly() async {
    if (settings.notifyWeeklySummary) {
      final t = _NotifText.weeklySummary(settings.resolvedLanguageCode);
      await gateway.scheduleWeeklyAt(
        id: NotifIds.weeklySummary,
        weekday: weeklyWeekday,
        time: weeklyTime,
        title: t.title,
        body: t.body,
      );
    } else {
      await gateway.cancel(NotifIds.weeklySummary);
    }
  }

  /// Дёргается движком в день выплаты дивиденда по календарю.
  Future<void> notifyDividendPaid({
    required String symbol,
    required String amountText,
  }) async {
    if (!settings.notifyDividend) return;
    final t = _NotifText.dividendPaid(settings.resolvedLanguageCode, symbol, amountText);
    await gateway.showNow(
      id: _oneOffId(symbol, 'div'),
      title: t.title,
      body: t.body,
    );
  }

  /// Дёргается кодом рынка при заметном движении цены по бумаге из портфеля.
  /// [changeText] — нейтральная формулировка вроде «+7% за день», без
  /// оценочных слов и без призыва купить/продать.
  Future<void> notifyBigMove({
    required String symbol,
    required String changeText,
  }) async {
    if (!settings.notifyBigMoves) return;
    final t = _NotifText.bigMove(settings.resolvedLanguageCode, symbol, changeText);
    await gateway.showNow(
      id: _oneOffId(symbol, 'move'),
      title: t.title,
      body: t.body,
    );
  }

  /// Стабильный id для разового уведомления по тикеру+типу события — чтобы
  /// повторное срабатывание в тот же день обновляло уведомление, а не
  /// плодило дубликаты; разные тикеры/типы не пересекаются.
  int _oneOffId(String symbol, String kind) =>
      Object.hash(symbol, kind).abs() % 1000000 + 2000;

  void dispose() {
    settings.removeListener(_onSettingsChanged);
  }
}

// ------------------------------------------------------------ тексты (i18n)

/// Заголовок+текст уведомления на нужном языке. Локальные уведомления
/// планируются вне дерева виджетов (нет BuildContext/AppLocalizations), так
/// что используем тот же паттерн маленьких lang-словарей, что уже есть в
/// ChatState/CosmoScreen — 'ru' | 'en' | 'es', иначе английский.
class _NotifText {
  final String title;
  final String body;
  const _NotifText(this.title, this.body);

  static _NotifText lessonReminder(String lang) => switch (lang) {
        'ru' => const _NotifText(
            'Время для урока', 'Пять минут — и ты на шаг ближе к пониманию инвестиций.'),
        'es' => const _NotifText(
            'Hora de tu lección', 'Cinco minutos y estarás más cerca de entender la inversión.'),
        _ => const _NotifText(
            'Time for your lesson', 'Five minutes, and you\'re one step closer to understanding investing.'),
      };

  static _NotifText weeklySummary(String lang) => switch (lang) {
        'ru' => const _NotifText(
            'Сводка портфеля за неделю', 'Загляни посмотреть, как изменился твой виртуальный портфель.'),
        'es' => const _NotifText(
            'Resumen semanal de tu cartera', 'Entra a ver cómo cambió tu cartera virtual.'),
        _ => const _NotifText(
            'Your weekly portfolio summary', 'Take a look at how your virtual portfolio changed.'),
      };

  static _NotifText dividendPaid(String lang, String symbol, String amountText) => switch (lang) {
        'ru' => _NotifText(
            'Дивиденд начислен', '$symbol начислил дивиденд: +$amountText на твой виртуальный баланс.'),
        'es' => _NotifText(
            'Dividendo acreditado', '$symbol pagó un dividendo: +$amountText en tu saldo virtual.'),
        _ => _NotifText(
            'Dividend credited', '$symbol paid a dividend: +$amountText to your virtual balance.'),
      };

  static _NotifText bigMove(String lang, String symbol, String changeText) => switch (lang) {
        'ru' => _NotifText(
            'Заметное движение цены', '$symbol изменился на $changeText. Загляни посмотреть, что происходит.'),
        'es' => _NotifText(
            'Movimiento de precio notable', '$symbol cambió $changeText. Entra a ver qué está pasando.'),
        _ => _NotifText(
            'Notable price move', '$symbol moved $changeText. Take a look at what\'s going on.'),
      };
}
