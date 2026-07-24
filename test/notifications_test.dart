/// Тесты локальных уведомлений:
/// - [NotificationsController] на [FakeNotificationsGateway] — планирует/
///   отменяет повторяющиеся уведомления по флагам [AppSettings], разовые
///   события (дивиденд/движение) уважают свой флаг;
/// - [LocalNotificationsPluginGateway] (боевой шлюз) — не должен падать,
///   даже когда платформенный плагин недоступен (как в тестовом окружении).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris/services/notifications.dart';
import 'package:polaris/services/storage.dart';
import 'package:polaris/state/app_settings.dart';

void main() {
  // AppSettings.notifyListeners() дёргает контроллер асинхронно (fire-and-
  // forget — UI не обязан ждать перепланирования уведомлений). Тесты, где
  // мы проверяем эффект этого прослушивания, дают микрозадачам «стечь»
  // через pumpEventQueue() перед проверкой состояния фейкового шлюза.

  group('NotificationsController — повторяющиеся уведомления по флагам', () {
    test('init() ставит урок дня и недельную сводку (флаги по умолчанию вкл)',
        () async {
      final settings = AppSettings(storage: MemoryStorage());
      await settings.load();
      final fake = FakeNotificationsGateway();
      final controller = NotificationsController(gateway: fake, settings: settings);

      await controller.init();

      expect(fake.initCalled, isTrue);
      expect(fake.daily.containsKey(NotifIds.lessonReminder), isTrue);
      expect(fake.weekly.containsKey(NotifIds.weeklySummary), isTrue);

      controller.dispose();
    });

    test('выключение флага отменяет соответствующее уведомление', () async {
      final settings = AppSettings(storage: MemoryStorage());
      await settings.load();
      final fake = FakeNotificationsGateway();
      final controller = NotificationsController(gateway: fake, settings: settings);
      await controller.init();

      await settings.setLessonReminder(false);
      await pumpEventQueue();

      expect(fake.daily.containsKey(NotifIds.lessonReminder), isFalse);
      expect(fake.cancelled.contains(NotifIds.lessonReminder), isTrue);
      // Сводку не тронули.
      expect(fake.weekly.containsKey(NotifIds.weeklySummary), isTrue);

      controller.dispose();
    });

    test('включение флага обратно снова планирует уведомление', () async {
      final settings = AppSettings(storage: MemoryStorage());
      await settings.load();
      final fake = FakeNotificationsGateway();
      final controller = NotificationsController(gateway: fake, settings: settings);
      await controller.init();

      await settings.setWeeklySummary(false);
      await pumpEventQueue();
      expect(fake.weekly.containsKey(NotifIds.weeklySummary), isFalse);

      await settings.setWeeklySummary(true);
      await pumpEventQueue();
      expect(fake.weekly.containsKey(NotifIds.weeklySummary), isTrue);

      controller.dispose();
    });

    test('после dispose изменения настроек больше не трогают шлюз', () async {
      final settings = AppSettings(storage: MemoryStorage());
      await settings.load();
      final fake = FakeNotificationsGateway();
      final controller = NotificationsController(gateway: fake, settings: settings);
      await controller.init();
      controller.dispose();

      await settings.setLessonReminder(false);
      // Уведомление осталось запланированным — контроллер больше не слушает.
      expect(fake.daily.containsKey(NotifIds.lessonReminder), isTrue);
    });
  });

  group('NotificationsController — разовые события', () {
    test('дивиденд не показывается, пока флаг выключен (по умолчанию)',
        () async {
      final settings = AppSettings(storage: MemoryStorage());
      await settings.load();
      final fake = FakeNotificationsGateway();
      final controller = NotificationsController(gateway: fake, settings: settings);
      await controller.init();

      await controller.notifyDividendPaid(symbol: 'AAPL', amountText: r'$1.20');
      expect(fake.shown, isEmpty);

      controller.dispose();
    });

    test('дивиденд показывается после включения флага, текст нейтральный',
        () async {
      final settings = AppSettings(storage: MemoryStorage());
      await settings.load();
      await settings.setDividendPaid(true);
      final fake = FakeNotificationsGateway();
      final controller = NotificationsController(gateway: fake, settings: settings);
      await controller.init();

      await controller.notifyDividendPaid(symbol: 'AAPL', amountText: r'$1.20');

      expect(fake.shown.length, 1);
      final n = fake.shown.single;
      expect(n.body, contains('AAPL'));
      expect(n.body, contains(r'$1.20'));
      // Без призывов к сделке.
      expect(n.body.toLowerCase(), isNot(contains('купи')));
      expect(n.body.toLowerCase(), isNot(contains('продай')));

      controller.dispose();
    });

    test('крупное движение показывается только при включённом флаге', () async {
      final settings = AppSettings(storage: MemoryStorage());
      await settings.load();
      final fake = FakeNotificationsGateway();
      final controller = NotificationsController(gateway: fake, settings: settings);
      await controller.init();

      await controller.notifyBigMove(symbol: 'TSLA', changeText: '+8% за день');
      expect(fake.shown, isEmpty);

      await settings.setBigMoves(true);
      await controller.notifyBigMove(symbol: 'TSLA', changeText: '+8% за день');
      expect(fake.shown.length, 1);
      expect(fake.shown.single.body, contains('TSLA'));

      controller.dispose();
    });

    test('разные события не перетирают id друг друга', () async {
      final settings = AppSettings(storage: MemoryStorage());
      await settings.load();
      await settings.setDividendPaid(true);
      await settings.setBigMoves(true);
      final fake = FakeNotificationsGateway();
      final controller = NotificationsController(gateway: fake, settings: settings);
      await controller.init();

      await controller.notifyDividendPaid(symbol: 'AAPL', amountText: r'$1');
      await controller.notifyBigMove(symbol: 'AAPL', changeText: '+9%');

      expect(fake.shown.length, 2);
      expect(fake.shown[0].id, isNot(fake.shown[1].id));

      controller.dispose();
    });
  });

  group('LocalNotificationsPluginGateway — не должен падать без плагина', () {
    test('init/schedule/show/cancel не бросают исключений', () async {
      final gateway = LocalNotificationsPluginGateway();

      // В тестовом окружении платформенного канала нет — весь смысл шлюза
      // в том, чтобы это было незаметно для остального приложения.
      await gateway.init();
      await gateway.scheduleDailyAt(
        id: 1,
        time: const TimeOfDay(hour: 19, minute: 0),
        title: 'т',
        body: 'б',
      );
      await gateway.scheduleWeeklyAt(
        id: 2,
        weekday: DateTime.sunday,
        time: const TimeOfDay(hour: 10, minute: 0),
        title: 'т',
        body: 'б',
      );
      await gateway.showNow(id: 3, title: 'т', body: 'б');
      await gateway.cancel(1);
      await gateway.cancelAll();

      // Если дошли сюда — ни один вызов не уронил тест.
    });

    test('NotificationsController поверх боевого шлюза тоже не падает',
        () async {
      final settings = AppSettings(storage: MemoryStorage());
      await settings.load();
      final controller = NotificationsController(
        gateway: LocalNotificationsPluginGateway(),
        settings: settings,
      );

      await controller.init();
      await controller.notifyDividendPaid(symbol: 'AAPL', amountText: r'$1');
      await settings.setDividendPaid(true);
      await controller.notifyDividendPaid(symbol: 'AAPL', amountText: r'$1');

      controller.dispose();
    });
  });
}
