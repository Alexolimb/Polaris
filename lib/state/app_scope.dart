/// Единая точка доступа к общему состоянию приложения: портфель игрока,
/// рыночные данные, чат с Cosmo и прогресс обучения. Всё нужно нескольким
/// экранам сразу, поэтому живёт в корне и раздаётся через InheritedWidget —
/// без сторонних state-пакетов (наш паттерн из Altron).
library;

import 'package:flutter/widgets.dart';

import '../services/notifications.dart';
import '../services/sync.dart';
import 'app_settings.dart';
import 'chat_state.dart';
import 'learn_state.dart';
import 'market_state.dart';
import 'portfolio_state.dart';

class AppScope extends InheritedWidget {
  final PortfolioState portfolio;
  final MarketState market;
  final ChatState chat;
  final LearnState learn;
  final AppSettings settings;
  final NotificationsController notifications;

  /// Обмен с общим складом (телефон ↔ ноутбук ↔ Финансист). null — приложение
  /// собрано без ключа склада, обмена нет, всё работает как раньше.
  final PolarisSync? sync;

  const AppScope({
    super.key,
    required this.portfolio,
    required this.market,
    required this.chat,
    required this.learn,
    required this.settings,
    required this.notifications,
    this.sync,
    required super.child,
  });

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope не найден выше по дереву');
    return scope!;
  }

  /// Доступ без подписки на перестройку (для колбэков).
  static AppScope read(BuildContext context) {
    final scope =
        context.getElementForInheritedWidgetOfExactType<AppScope>()?.widget;
    return scope! as AppScope;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      portfolio != oldWidget.portfolio ||
      market != oldWidget.market ||
      chat != oldWidget.chat ||
      learn != oldWidget.learn ||
      settings != oldWidget.settings ||
      notifications != oldWidget.notifications ||
      sync != oldWidget.sync;
}
