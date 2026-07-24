/// Моушн-ядро Polaris: пружинный тап, каскадное появление, докрутка чисел.
///
/// Всё на голом Flutter (AnimationController), без зависимостей.
/// Паттерны выращены из Altron/Fluxo. Важно: StaggerIn без Future.delayed —
/// один контроллер с Interval, чтобы в тестах не висели таймеры.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ------------------------------------------------------------- тактильность

/// Тактильная отдача. На Windows молча ничего не делает.
class Fx {
  const Fx._();

  static bool get _mobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  static void tap() {
    if (_mobile) HapticFeedback.selectionClick();
  }

  static void hit() {
    if (_mobile) HapticFeedback.mediumImpact();
  }
}

// ------------------------------------------------------------------ Springy

/// Нажатие с пружинным откликом: вдавливается под пальцем, отпускается
/// с лёгким перелётом (elasticOut).
class Springy extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Глубина вдавливания (доля масштаба).
  final double depth;
  final bool haptic;

  const Springy({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.depth = .05,
    this.haptic = true,
  });

  @override
  State<Springy> createState() => _SpringyState();
}

class _SpringyState extends State<Springy> with SingleTickerProviderStateMixin {
  // Создаём в initState, а не лениво: ленивый late-контроллер, впервые
  // тронутый в dispose(), падает на поиске TickerMode у предков.
  late final AnimationController _c;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
      reverseDuration: const Duration(milliseconds: 420),
    );
    _scale = _c.drive(
      Tween(begin: 1.0, end: 1 - widget.depth)
          .chain(CurveTween(curve: Curves.easeOut)),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down(_) => _c.forward();
  void _up([_]) {
    if (mounted) _c.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null && widget.onLongPress == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _up,
      onTap: () {
        if (widget.haptic) Fx.tap();
        widget.onTap?.call();
      },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              Fx.hit();
              widget.onLongPress!.call();
            },
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(
          // На отпускании — пружина с перелётом.
          scale: _c.status == AnimationStatus.reverse
              ? 1 - widget.depth * Curves.elasticOut.transform(1 - _c.value)
              : _scale.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------- StaggerIn

/// Каскадное появление детей списка: сдвиг снизу + проявление, задержка
/// растёт с [index] (капим на 12, чтобы хвост длинного списка не ждал вечно).
/// Без таймеров: задержка зашита в Interval одного контроллера.
class StaggerIn extends StatefulWidget {
  final int index;
  final Widget child;
  final double offsetY;
  final Duration stagger;
  final Duration duration;

  const StaggerIn({
    super.key,
    required this.index,
    required this.child,
    this.offsetY = 18,
    this.stagger = const Duration(milliseconds: 45),
    this.duration = const Duration(milliseconds: 420),
  });

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn>
    with SingleTickerProviderStateMixin {
  late final Duration _delay = widget.stagger * math.min(widget.index, 12);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration + _delay,
  );
  late final Animation<double> _a = CurvedAnimation(
    parent: _c,
    // Задержка — «мёртвая зона» в начале общей длительности.
    curve: Interval(
      _delay.inMilliseconds /
          math.max(1, (widget.duration + _delay).inMilliseconds),
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, child) => Opacity(
        opacity: _a.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _a.value) * widget.offsetY),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

// -------------------------------------------------------------- CountUpText

/// Число, плавно докручивающееся до значения. Деньги храним в ЦЕНТАХ (int),
/// показываем как $1,234.56. Смена [cents] — докрутка от текущего значения.
/// [animated] = false — значение показывается сразу.
class CountUpText extends StatefulWidget {
  /// Целевая сумма в центах (может быть отрицательной).
  final int cents;
  final TextStyle? style;
  final Duration duration;
  final bool animated;
  final String currency;

  const CountUpText({
    super.key,
    required this.cents,
    this.style,
    this.duration = const Duration(milliseconds: 900),
    this.animated = true,
    this.currency = r'$',
  });

  /// Формат денег из центов: 123456 → `$1,234.56`, -987 → `-$9.87`.
  static String formatCents(int cents, {String currency = r'$'}) {
    final neg = cents < 0;
    final v = cents.abs();
    final dollars = (v ~/ 100).toString();
    final rem = (v % 100).toString().padLeft(2, '0');
    final buf = StringBuffer();
    for (var i = 0; i < dollars.length; i++) {
      if (i > 0 && (dollars.length - i) % 3 == 0) buf.write(',');
      buf.write(dollars[i]);
    }
    return '${neg ? '-' : ''}$currency$buf.$rem';
  }

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText>
    with SingleTickerProviderStateMixin {
  // Не лениво: см. комментарий в _SpringyState.
  late final AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    if (widget.animated) {
      // Первый показ — докрутка с нуля (эффектно для суммы портфеля).
      _a = _tween(0, widget.cents.toDouble());
      _c.forward();
    } else {
      _a = AlwaysStoppedAnimation(widget.cents.toDouble());
    }
  }

  Animation<double> _tween(double from, double to) => _c.drive(
        Tween(begin: from, end: to)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
      );

  @override
  void didUpdateWidget(covariant CountUpText old) {
    super.didUpdateWidget(old);
    if (old.cents != widget.cents || old.animated != widget.animated) {
      if (widget.animated) {
        // Докручиваем от текущего показанного значения к новому.
        _a = _tween(_a.value, widget.cents.toDouble());
        _c.forward(from: 0);
      } else {
        _c.stop();
        setState(() {
          _a = AlwaysStoppedAnimation(widget.cents.toDouble());
        });
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, _) => Text(
        CountUpText.formatCents(_a.value.round(), currency: widget.currency),
        style: widget.style,
      ),
    );
  }
}
