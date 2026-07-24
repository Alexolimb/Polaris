/// Маскот Polaris — дружелюбный астронавт **Cosmo**, лицо приложения.
///
/// Полностью на CustomPainter (без Rive/Lottie — фолбэк из плана, см.
/// `.build/plan.md` п.5.5: «программный маскот, как солнце Altron»).
/// Один Ticker гонит непрерывное время [_t] секунд — поза, глаза и мелкие
/// эффекты каждого настроения [CosmoMood] выводятся из него формулами
/// (приём из `fx/stars_background.dart`), поэтому смена mood на лету не
/// требует пересборки анимации, а [animated] = false даёт статичный кадр
/// (t = 0) без тикера — экономия батареи / детерминизм в тестах.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../theme/theme.dart';
import '../fx/motion.dart' show reduceMotion;

// -------------------------------------------------------------------- Mood

/// Настроение Cosmo — определяет позу, глаза и вспомогательные эффекты.
enum CosmoMood {
  /// Спокойное парение вверх-вниз, редкое моргание. Настроение по умолчанию.
  idle,

  /// Глаза-дуги, бодрое подпрыгивание — после удачной сделки/мелкой похвалы.
  happy,

  /// Взгляд «в сторону», три звёздочки крутятся над шлемом — AI печатает.
  thinking,

  /// Искры вокруг, энергичный подскок — завершение урока, крупная удача.
  celebrate,

  /// Глаза-капельки, лёгкое покачивание — просадка портфеля. Без драмы.
  concerned,
}

// --------------------------------------------------------------- CosmoMascot

/// Маскот в полный рост: шлем со стеклянным визором + тело в скафандре.
/// Используй на крупных сценах (онбординг, экран завершения урока, крупные
/// уведомления в чате) — для мелких аватаров есть [CosmoBadge].
class CosmoMascot extends StatefulWidget {
  final double size;
  final CosmoMood mood;

  /// false — статичная поза настроения без тикера (тесты, экономия батареи).
  final bool animated;

  const CosmoMascot({
    super.key,
    this.size = 120,
    this.mood = CosmoMood.idle,
    this.animated = true,
  });

  @override
  State<CosmoMascot> createState() => _CosmoMascotState();
}

class _CosmoMascotState extends State<CosmoMascot>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => setState(() => _t = d.inMicroseconds / 1e6));
    // Старт — в didChangeDependencies (reduce-motion доступен там).
  }

  void _syncAnim() {
    final on = widget.animated && !reduceMotion(context);
    if (on && !_ticker.isActive) {
      _ticker.start();
    } else if (!on && _ticker.isActive) {
      _ticker.stop();
      _t = 0; // за _syncAnim всегда следует build — setState не нужен
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnim();
  }

  @override
  void didUpdateWidget(covariant CosmoMascot old) {
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
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _CosmoMascotPainter(
            t: widget.animated ? _t : 0,
            mood: widget.mood,
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- CosmoBadge

/// Маленький аватар Cosmo — только шлем, без тела. Для шапок экранов и
/// пузырей чата (заменяет старый простой `CosmoAvatar` из cosmo_screen.dart).
/// По умолчанию статичен ([animated] = false) — дёшево в списках сообщений;
/// включи анимацию для одиночной шапки экрана, если нужно живое моргание.
class CosmoBadge extends StatefulWidget {
  final double size;
  final CosmoMood mood;
  final bool animated;

  const CosmoBadge({
    super.key,
    this.size = 32,
    this.mood = CosmoMood.idle,
    this.animated = false,
  });

  @override
  State<CosmoBadge> createState() => _CosmoBadgeState();
}

class _CosmoBadgeState extends State<CosmoBadge>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => setState(() => _t = d.inMicroseconds / 1e6));
    // Старт — в didChangeDependencies (reduce-motion доступен там).
  }

  void _syncAnim() {
    final on = widget.animated && !reduceMotion(context);
    if (on && !_ticker.isActive) {
      _ticker.start();
    } else if (!on && _ticker.isActive) {
      _ticker.stop();
      _t = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnim();
  }

  @override
  void didUpdateWidget(covariant CosmoBadge old) {
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
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _CosmoBadgePainter(
            t: widget.animated ? _t : 0,
            mood: widget.mood,
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ CosmoGreeting

/// Маскот + короткая реплика рядом — приветствие в онбординге и пустых
/// состояниях (пустой чат, пустой каталог и т.п.). Стеклянная карточка в
/// стиле `GlowCard`, чтобы не тянуть за собой ещё одну зависимость.
class CosmoGreeting extends StatelessWidget {
  final String text;
  final CosmoMood mood;
  final bool animated;
  final double mascotSize;
  final Color glowColor;

  const CosmoGreeting({
    super.key,
    required this.text,
    this.mood = CosmoMood.idle,
    this.animated = true,
    this.mascotSize = 56,
    this.glowColor = PolarisColors.aurora,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PolarisColors.surfaceHigh.withValues(alpha: .72),
            PolarisColors.surface.withValues(alpha: .55),
          ],
        ),
        border: Border.all(color: glowColor.withValues(alpha: .28)),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: .16),
            blurRadius: 26,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CosmoMascot(size: mascotSize, mood: mood, animated: animated),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                text,
                style: const TextStyle(
                  color: PolarisColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================== рисование

/// Общая геометрия шлема — переиспользуется полным маскотом и бейджем,
/// чтобы «лицо» Cosmo выглядело одинаково в любом размере.
class _Face {
  final Offset center;
  final double r;
  const _Face(this.center, this.r);

  /// Внешний ореол свечения вокруг шлема.
  void paintGlow(Canvas canvas) {
    canvas.drawCircle(
      center,
      r * 1.35,
      Paint()
        ..shader = RadialGradient(colors: [
          PolarisColors.polar.withValues(alpha: .30),
          PolarisColors.polar.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: center, radius: r * 1.35)),
    );
  }

  /// Корпус шлема: непрозрачная сфера + светлый ободок.
  void paintShell(Canvas canvas) {
    canvas.drawCircle(center, r, Paint()..color = PolarisColors.surfaceHigh);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .07
        ..color = PolarisColors.star.withValues(alpha: .85),
    );
  }

  Rect get visorRect => Rect.fromCenter(
        center: center.translate(0, r * .05),
        width: r * 1.5,
        height: r * 1.12,
      );

  /// Стеклянный визор: градиент полярного сияния + блик.
  void paintVisor(Canvas canvas) {
    final rect = visorRect;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(r * .56));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PolarisColors.polar,
            PolarisColors.aurora,
            PolarisColors.violet,
          ],
        ).createShader(rect),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(-r * .34, -r * .26),
        width: r * .5,
        height: r * .28,
      ),
      Paint()..color = Colors.white.withValues(alpha: .40),
    );
  }

  /// Тёплый огонёк-глаз: радиальное свечение с ярким ядром.
  void _glowDot(Canvas canvas, Offset pos, double radius, Color color) {
    canvas.drawCircle(
      pos,
      radius * 2.1,
      Paint()
        ..shader = RadialGradient(colors: [
          color.withValues(alpha: .5),
          color.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: pos, radius: radius * 2.1)),
    );
    canvas.drawCircle(pos, radius, Paint()..color = color);
    canvas.drawCircle(
        pos, radius * .45, Paint()..color = Colors.white.withValues(alpha: .9));
  }

  /// Глаза Cosmo — форма и движение зависят от настроения и времени [t].
  void paintEyes(Canvas canvas, double t, CosmoMood mood) {
    final vc = visorRect.center;
    final dx = r * .34;
    final left = vc.translate(-dx, 0);
    final right = vc.translate(dx, 0);

    switch (mood) {
      case CosmoMood.idle:
        // Редкое моргание: короткое закрытие раз в ~4 секунды.
        final phase = t % 4.0;
        final blinking = phase > 2.55 && phase < 2.70;
        for (final p in [left, right]) {
          if (blinking) {
            _eyelid(canvas, p, r);
          } else {
            _glowDot(canvas, p, r * .11, PolarisColors.aurora);
          }
        }
      case CosmoMood.thinking:
        // Взгляд «в сторону» — Cosmo обдумывает ответ.
        final shift = math.sin(t * 1.6) * r * .07;
        for (final p in [left, right]) {
          _glowDot(canvas, p.translate(shift, 0), r * .09, PolarisColors.polar);
        }
      case CosmoMood.happy:
        // Счастливые дуги вместо глаз.
        for (final p in [left, right]) {
          _happyArc(canvas, p, r);
        }
      case CosmoMood.celebrate:
        // Те же дуги + мигающая искра над каждым глазом.
        for (final p in [left, right]) {
          _happyArc(canvas, p, r);
        }
        final twinkle = .5 + .5 * math.sin(t * 6);
        for (final p in [left, right]) {
          _sparkle(canvas, p.translate(0, -r * .32), r * .12 * twinkle,
              PolarisColors.dividend);
        }
      case CosmoMood.concerned:
        // Глаза-капельки: круглый верх, зауженный низ. Дыхание — медленный
        // масштаб, без резких движений (по требованию — «без драмы»).
        final breathe = 1 + .06 * math.sin(t * .8);
        for (final p in [left, right]) {
          _teardropEye(canvas, p, r * .95 * breathe);
        }
    }
  }

  void _eyelid(Canvas canvas, Offset p, double r) {
    canvas.drawLine(
      p.translate(-r * .11, 0),
      p.translate(r * .11, 0),
      Paint()
        ..strokeWidth = r * .045
        ..strokeCap = StrokeCap.round
        ..color = PolarisColors.textFaint,
    );
  }

  void _happyArc(Canvas canvas, Offset p, double r) {
    final rect = Rect.fromCenter(center: p, width: r * .34, height: r * .34);
    final path = Path()
      ..addArc(rect, math.pi * 1.05, math.pi * .9); // дуга-«улыбка» глазом
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .075
        ..strokeCap = StrokeCap.round
        ..color = PolarisColors.aurora,
    );
  }

  void _sparkle(Canvas canvas, Offset p, double s, Color color) {
    final paint = Paint()
      ..color = color.withValues(alpha: .85)
      ..strokeWidth = s * .3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(p.translate(-s, 0), p.translate(s, 0), paint);
    canvas.drawLine(p.translate(0, -s), p.translate(0, s), paint);
  }

  void _teardropEye(Canvas canvas, Offset p, double radius) {
    final r = radius * .17;
    // Круглая «нижняя» часть капли.
    canvas.drawCircle(
        p.translate(0, r * .35), r, Paint()..color = PolarisColors.polar.withValues(alpha: .8));
    // Заострённая «верхняя» часть — треугольник, сходящийся вверх.
    final path = Path()
      ..moveTo(p.dx - r * .85, p.dy)
      ..lineTo(p.dx + r * .85, p.dy)
      ..lineTo(p.dx, p.dy - r * 1.3)
      ..close();
    canvas.drawPath(path, Paint()..color = PolarisColors.polar.withValues(alpha: .8));
    canvas.drawCircle(
        p.translate(-r * .3, r * .1), r * .35, Paint()..color = Colors.white.withValues(alpha: .7));
  }

  /// Три звёздочки, кружащие над шлемом — Cosmo думает.
  void paintThinkingDots(Canvas canvas, double t) {
    final orbit = center.translate(0, -r * 1.25);
    const colors = [
      PolarisColors.polar,
      PolarisColors.aurora,
      PolarisColors.violet,
    ];
    for (var i = 0; i < 3; i++) {
      final angle = t * 2.2 + i * (math.pi * 2 / 3);
      final pos =
          orbit.translate(math.cos(angle) * r * .55, math.sin(angle) * r * .20);
      final s = r * .10 * (.7 + .3 * math.sin(t * 3 + i));
      _sparkle(canvas, pos, s, colors[i]);
    }
  }
}

/// Поза фигуры целиком: смещение и лёгкий наклон, разные для каждого mood.
class _Pose {
  final double dx, dy, angle;
  const _Pose(this.dx, this.dy, this.angle);
}

_Pose _poseFor(CosmoMood mood, double t, double s) {
  switch (mood) {
    case CosmoMood.idle:
      return _Pose(0, math.sin(t * 1.3) * s * .028, 0);
    case CosmoMood.thinking:
      return _Pose(0, math.sin(t * 1.0) * s * .015, math.sin(t * .7) * .045);
    case CosmoMood.happy:
      return _Pose(0, -math.sin(t * 3).abs() * s * .06, 0);
    case CosmoMood.celebrate:
      return _Pose(0, -math.sin(t * 4).abs() * s * .09, math.sin(t * 4) * .05);
    case CosmoMood.concerned:
      return _Pose(math.sin(t * 1.1) * s * .02, 0, math.sin(t * 1.1) * .05);
  }
}

/// Акцентный цвет скафандра/огонька на груди — по настроению.
Color _accentFor(CosmoMood mood) {
  switch (mood) {
    case CosmoMood.idle:
    case CosmoMood.thinking:
      return PolarisColors.polar;
    case CosmoMood.happy:
      return PolarisColors.aurora;
    case CosmoMood.celebrate:
      return PolarisColors.dividend;
    case CosmoMood.concerned:
      return PolarisColors.violet;
  }
}

// ---------------------------------------------------------- painter: полный

class _CosmoMascotPainter extends CustomPainter {
  final double t;
  final CosmoMood mood;
  const _CosmoMascotPainter({required this.t, required this.mood});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final cx = size.width / 2;
    final helmetR = s * .27;
    final helmetC = Offset(cx, s * .38);
    final face = _Face(helmetC, helmetR);
    final pose = _poseFor(mood, t, s);

    canvas.save();
    canvas.clipRect(Offset.zero & size); // искры/дуги не вылезают за рамку
    canvas.translate(pose.dx, pose.dy);
    canvas.rotate(pose.angle);

    if (mood == CosmoMood.celebrate) _paintSparkleBurst(canvas, helmetC, s, t);

    _paintBody(canvas, helmetC, helmetR, size, mood, t);
    if (mood == CosmoMood.thinking) face.paintThinkingDots(canvas, t);

    face.paintGlow(canvas);
    face.paintShell(canvas);
    face.paintVisor(canvas);
    face.paintEyes(canvas, t, mood);

    canvas.restore();
  }

  /// Тело в скафандре: закруглённый корпус + акцентный огонёк на груди +
  /// маленькие руки-стабилизаторы по бокам.
  void _paintBody(Canvas canvas, Offset helmetC, double helmetR, Size size,
      CosmoMood mood, double t) {
    final bodyW = size.shortestSide * .52;
    final bodyH = size.shortestSide * .46;
    final bodyTop = helmetC.dy + helmetR * .58;
    final bodyRect = Rect.fromLTWH(
      helmetC.dx - bodyW / 2,
      bodyTop,
      bodyW,
      bodyH,
    );
    final rr = RRect.fromRectAndRadius(bodyRect, Radius.circular(bodyW * .34));

    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            PolarisColors.surfaceHigh.withValues(alpha: .95),
            PolarisColors.surface.withValues(alpha: .95),
          ],
        ).createShader(bodyRect),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * .015
        ..color = PolarisColors.star.withValues(alpha: .35),
    );

    // Руки-стабилизаторы — простые овалы по бокам корпуса.
    final armY = bodyTop + bodyH * .35;
    final armPaint = Paint()..color = PolarisColors.surfaceHigh.withValues(alpha: .9);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(bodyRect.left - bodyW * .04, armY),
            width: bodyW * .22,
            height: bodyH * .5),
        armPaint);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(bodyRect.right + bodyW * .04, armY),
            width: bodyW * .22,
            height: bodyH * .5),
        armPaint);

    // Огонёк на груди — пульсирующее свечение фирменным акцентом настроения.
    final chest = Offset(helmetC.dx, bodyTop + bodyH * .30);
    final accent = _accentFor(mood);
    final pulse = .6 + .4 * (.5 + .5 * math.sin(t * 2.2));
    canvas.drawCircle(
      chest,
      bodyW * .16,
      Paint()
        ..shader = RadialGradient(colors: [
          accent.withValues(alpha: .55 * pulse),
          accent.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: chest, radius: bodyW * .16)),
    );
    canvas.drawCircle(chest, bodyW * .055, Paint()..color = accent);
  }

  /// Искры-конфетти вокруг мaскота — только для celebrate. Замкнутый цикл
  /// по времени, детерминирован индексом частицы (без Random — предсказуемо
  /// и для animated:false, и для animated:true).
  void _paintSparkleBurst(Canvas canvas, Offset center, double s, double t) {
    const colors = [
      PolarisColors.polar,
      PolarisColors.aurora,
      PolarisColors.violet,
      PolarisColors.dividend,
    ];
    for (var i = 0; i < 8; i++) {
      final seed = i * .78;
      final life = (t * .55 + seed) % 2.0;
      final progress = life / 2.0;
      final angle = seed * (math.pi * 2 / 8) + t * .25;
      final dist = s * (.42 + progress * .40);
      final pos = center.translate(
        math.cos(angle) * dist,
        math.sin(angle) * dist * .7 - progress * s * .22,
      );
      final alpha = (1 - progress).clamp(0.0, 1.0);
      final size = s * .045 * (1 - progress * .35);
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: alpha * .9)
        ..strokeWidth = size * .35
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(pos.translate(-size, 0), pos.translate(size, 0), paint);
      canvas.drawLine(pos.translate(0, -size), pos.translate(0, size), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CosmoMascotPainter old) =>
      old.t != t || old.mood != mood;
}

// -------------------------------------------------------------- painter: бейдж

/// Компактный painter только шлема — для [CosmoBadge]. Делит геометрию лица
/// с полным маскотом через [_Face], поэтому «лицо» узнаваемо в любом размере.
class _CosmoBadgePainter extends CustomPainter {
  final double t;
  final CosmoMood mood;
  const _CosmoBadgePainter({required this.t, required this.mood});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * .42;
    final face = _Face(c, r);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    face.paintGlow(canvas);
    face.paintShell(canvas);
    face.paintVisor(canvas);
    face.paintEyes(canvas, t, mood);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CosmoBadgePainter old) =>
      old.t != t || old.mood != mood;
}
