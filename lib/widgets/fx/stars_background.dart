/// Живой космос Polaris: слои звёзд с параллаксом, мерцание, крестики-блики
/// у ярких звёзд и фирменное ПОЛЯРНОЕ СИЯНИЕ — волны-занавеси, колышущиеся
/// суммой синусов, градиент polar → aurora → violet, BlendMode.plus.
///
/// Один CustomPainter, один Ticker, RepaintBoundary — приём проверен в Altron.
/// [animated] = false — статичный кадр (экономия батареи), уважать всегда.
/// [intensity] 0..1 — насыщенность сияния (0 — только звёзды и виньетка).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../theme/theme.dart';
import 'motion.dart' show reduceMotion;

// ------------------------------------------------------------------- модели

class _Star {
  final double x, y, r, tw, layer;
  final Color tint;
  const _Star(this.x, this.y, this.r, this.tw, this.layer, this.tint);
}

/// Занавесь сияния: базовая высота, амплитуда волн, толщина, скорость, фаза,
/// множитель яркости. Все доли — от высоты экрана.
class _Curtain {
  final double base, amp, thick, speed, phase, glow;
  const _Curtain(this.base, this.amp, this.thick, this.speed, this.phase, this.glow);
}

// ------------------------------------------------------------------- виджет

class StarsBackground extends StatefulWidget {
  final Widget child;

  /// false — рисуем один статичный кадр, тикер не запускаем (батарея).
  final bool animated;

  /// 0..1 — сила полярного сияния (фон под контент, держим ненавязчиво).
  final double intensity;

  final int starCount;

  const StarsBackground({
    super.key,
    required this.child,
    this.animated = true,
    this.intensity = 1.0,
    this.starCount = 120,
  });

  @override
  State<StarsBackground> createState() => _StarsBackgroundState();

  /// Рисует небо во всю переданную область и объявляет потомкам, что своё
  /// небо им рисовать уже не нужно. Нужно для десктопной раскладки: фон
  /// full-bleed на всё окно, а контент — в колонке ограниченной ширины.
  static Widget provide({required Widget child, bool animated = true}) =>
      StarsBackground(
        animated: animated,
        child: _SkyProvided(child: child),
      );

  /// Есть ли выше по дереву небо, нарисованное через [provide].
  static bool isProvidedIn(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SkyProvided>() != null;
}

class _StarsBackgroundState extends State<StarsBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    final r = math.Random(11);
    // Три слоя параллакса: дальний (мелкий, медленный) → ближний (крупный).
    _stars = List.generate(widget.starCount, (i) {
      final roll = i % 10;
      final layer = roll < 5 ? .25 : (roll < 8 ? .55 : 1.0);
      final baseR = layer > .8
          ? .9 + r.nextDouble() * 1.2
          : layer > .4
              ? .6 + r.nextDouble() * .8
              : .35 + r.nextDouble() * .55;
      // Изредка — цветная звезда: холодная голубая или бирюзовая (не золото!).
      final tintRoll = r.nextDouble();
      final tint = tintRoll > .93
          ? PolarisColors.aurora
          : tintRoll > .84
              ? const Color(0xFFBFD9FF)
              : Colors.white;
      return _Star(
        r.nextDouble(),
        r.nextDouble(),
        baseR,
        r.nextDouble() * math.pi * 2,
        layer,
        tint,
      );
    });
    _ticker = createTicker((d) {
      setState(() => _t = d.inMicroseconds / 1e6);
    });
    // Старт — в didChangeDependencies (там доступен reduce-motion).
  }

  void _syncAnim() {
    final on = widget.animated && !reduceMotion(context);
    if (on && !_ticker.isActive) {
      _ticker.start();
    } else if (!on && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnim();
  }

  @override
  void didUpdateWidget(covariant StarsBackground old) {
    super.didUpdateWidget(old);
    _syncAnim();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Если небо уже нарисовано выше по дереву во всю ширину окна (десктопная
    // раскладка каркаса), второй раз его рисовать нельзя: внутри колонки
    // ограниченной ширины сияние обрезалось бы прямоугольником с жёсткими
    // краями. Тогда просто пропускаем содержимое.
    if (StarsBackground.isProvidedIn(context)) return widget.child;
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _SkyPainter(
                stars: _stars,
                t: _t,
                intensity: widget.intensity.clamp(0.0, 1.0),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// Маркер «небо уже нарисовано выше» — см. [StarsBackground.provide].
class _SkyProvided extends InheritedWidget {
  const _SkyProvided({required super.child});

  @override
  bool updateShouldNotify(_SkyProvided oldWidget) => false;
}

// ------------------------------------------------------------------ painter

class _SkyPainter extends CustomPainter {
  final List<_Star> stars;
  final double t;
  final double intensity;

  _SkyPainter({required this.stars, required this.t, required this.intensity});

  static const _tau = math.pi * 2;

  /// Занавеси сияния: верхняя треть неба, разные скорости и фазы.
  static const _curtains = [
    _Curtain(.15, .050, .30, .30, 0.0, 1.0),
    _Curtain(.09, .065, .22, .21, 2.1, .70),
    _Curtain(.25, .040, .20, .40, 4.4, .55),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _paintAurora(canvas, size);
    _paintStars(canvas, size);
    _paintVignette(canvas, size);
  }

  // ------------------------------------------- сияние: шум из суммы синусов

  /// Волна занавеси в точке xn (0..1): три синуса разных частот и скоростей.
  double _wave(double xn, _Curtain c) {
    return c.amp *
        (.55 * math.sin(xn * _tau * 1.1 + t * c.speed + c.phase) +
            .30 * math.sin(xn * _tau * 2.3 - t * c.speed * 1.6 + c.phase * 1.7) +
            .15 * math.sin(xn * _tau * 4.7 + t * c.speed * .7 + c.phase * 3.1));
  }

  void _paintAurora(Canvas canvas, Size size) {
    if (intensity <= 0) return;
    final a = intensity;

    // Мягкая «корона» неба над занавесями — едва заметный купол света.
    final crownRect = Rect.fromCircle(
      center: Offset(size.width * .5, -size.height * .08),
      radius: size.height * .55,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(colors: [
          PolarisColors.polar.withValues(alpha: .045 * a),
          PolarisColors.polar.withValues(alpha: 0),
        ]).createShader(crownRect),
    );

    // Сами занавеси: замкнутый путь (волнистый верх + волнистый низ),
    // вертикальный градиент polar → aurora → violet, плюс-блендинг.
    const steps = 28;
    for (final c in _curtains) {
      final top = List<Offset>.generate(steps + 1, (i) {
        final xn = i / steps;
        return Offset(
          xn * size.width,
          size.height * (c.base + _wave(xn, c)),
        );
      });
      final path = Path()..moveTo(top.first.dx, top.first.dy);
      for (final p in top.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      // Нижний край — своя лёгкая волна толщины, идём обратно.
      for (var i = steps; i >= 0; i--) {
        final xn = i / steps;
        final thick = size.height *
            c.thick *
            (1 + .18 * math.sin(xn * _tau * 1.7 - t * c.speed * 1.2 + c.phase));
        path.lineTo(top[i].dx, top[i].dy + thick);
      }
      path.close();

      final bounds = path.getBounds();
      canvas.drawPath(
        path,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              PolarisColors.polar.withValues(alpha: 0),
              PolarisColors.polar.withValues(alpha: .085 * a * c.glow),
              PolarisColors.aurora.withValues(alpha: .11 * a * c.glow),
              PolarisColors.violet.withValues(alpha: .07 * a * c.glow),
              PolarisColors.violet.withValues(alpha: 0),
            ],
            stops: const [0, .28, .55, .8, 1],
          ).createShader(bounds),
      );
    }
  }

  // ------------------------------------------- звёзды: три слоя дрейфа

  void _paintStars(Canvas canvas, Size size) {
    final paint = Paint();
    // Звёзды чуть тускнеют при низкой интенсивности, но не гаснут совсем.
    final starGain = .65 + .35 * intensity;
    for (final s in stars) {
      // Параллакс: ближний слой дрейфует заметно быстрее дальнего.
      final dx = (s.x * size.width + t * 3.0 * s.layer) % size.width;
      final dy = (s.y * size.height + t * 1.0 * s.layer) % size.height;
      // Редкое мерцание: у каждой звезды своя фаза.
      final twinkle = .45 + .55 * (.5 + .5 * math.sin(t * 1.3 + s.tw));
      paint.color =
          s.tint.withValues(alpha: .55 * twinkle * s.layer * starGain);
      canvas.drawCircle(Offset(dx, dy), s.r, paint);
      // У ярких ближних звёзд — крестик-блик.
      if (s.layer > .8 && s.r > 1.6) {
        paint.color = s.tint.withValues(alpha: .22 * twinkle * starGain);
        canvas.drawRect(
            Rect.fromCenter(center: Offset(dx, dy), width: s.r * 5, height: .7),
            paint);
        canvas.drawRect(
            Rect.fromCenter(center: Offset(dx, dy), width: .7, height: s.r * 5),
            paint);
      }
    }
  }

  // ------------------------------------------- виньетка: глубина по краям

  void _paintVignette(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: .95,
          colors: [
            const Color(0x00000000),
            PolarisColors.bg.withValues(alpha: 0),
            PolarisColors.bg.withValues(alpha: .55),
          ],
          stops: const [0, .62, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SkyPainter old) =>
      old.t != t || old.intensity != intensity;
}
