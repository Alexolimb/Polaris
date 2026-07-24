/// Заставка Polaris: тёмный космос, звёзды разгораются, волна сияния
/// проходит по экрану, в центре из света собирается «Polaris» и полярная
/// звезда с лучами, финальная искра — и колбэк [onDone].
///
/// Длительность ~1.8 сек. [animated] = false — статичный финальный кадр,
/// onDone вызывается почти сразу (уважение к батарее/слабым устройствам).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../widgets/fx/stars_background.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  final bool animated;

  const SplashScreen({super.key, required this.onDone, this.animated = true});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _letters = 'Polaris';

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  Timer? _staticTimer;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    if (widget.animated) {
      _c.addStatusListener((s) {
        if (s == AnimationStatus.completed) _finish();
      });
      _c.forward();
    } else {
      // Статичный режим: сразу финальный кадр, короткая пауза — и дальше.
      _c.value = 1;
      _staticTimer = Timer(const Duration(milliseconds: 300), _finish);
    }
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _staticTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PolarisColors.bg,
      body: StarsBackground(
        animated: widget.animated,
        intensity: 1,
        child: Stack(
          children: [
            // Слой сплэш-эффектов: волна света, полярная звезда, искра.
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, _) => CustomPaint(
                    painter: _SplashPainter(_c.value),
                  ),
                ),
              ),
            ),
            // Заголовок: буквы собираются из света под звездой.
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 90),
                child: _title(),
              ),
            ),
            // «Звёзды разгораются»: тёмная вуаль тает в первые 30% времени.
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, _) {
                    final fade = 1 - (_c.value / .3).clamp(0.0, 1.0);
                    return fade == 0
                        ? const SizedBox.shrink()
                        : ColoredBox(
                            color:
                                PolarisColors.bg.withValues(alpha: fade * .9),
                          );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// «Polaris» собирается из света: буквы проявляются каскадом,
  /// цвет — единый градиент сияния поверх всего слова.
  Widget _title() {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(colors: [
        PolarisColors.star,
        PolarisColors.polar,
        PolarisColors.aurora,
        PolarisColors.violet,
      ]).createShader(bounds),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _letters.length; i++)
            AnimatedBuilder(
              animation: _c,
              builder: (_, child) {
                final start = .32 + i * .055;
                final u = ((_c.value - start) / .22).clamp(0.0, 1.0);
                final e = Curves.easeOutCubic.transform(u);
                return Opacity(
                  opacity: e,
                  child: Transform.translate(
                    offset: Offset(0, (1 - e) * 14),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  _letters[i],
                  style: const TextStyle(
                    // Под маской буквы белые — цвет даёт градиент.
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(color: Color(0x996FB7FF), blurRadius: 18),
                      Shadow(color: Color(0x5554E6C1), blurRadius: 34),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ painter

/// Сплэш-эффекты по фазам общего прогресса [p] (0..1):
/// .18–.62 — волна сияния проходит слева направо;
/// .15–.55 — полярная звезда собирается (лучи растут);
/// .82–1.0 — финальная искра (кольцо + вспышка).
class _SplashPainter extends CustomPainter {
  final double p;
  _SplashPainter(this.p);

  static const _tau = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    _paintSweep(canvas, size);
    _paintStar(canvas, size);
    _paintSpark(canvas, size);
  }

  /// Центр полярной звезды — над заголовком.
  Offset _starCenter(Size size) =>
      Offset(size.width / 2, size.height / 2 - 64);

  // ------------------------------------------- волна сияния через экран

  void _paintSweep(Canvas canvas, Size size) {
    if (p <= .18 || p >= .62) return;
    final u = (p - .18) / .44;
    final envelope = math.sin(u * math.pi); // мягкий вход и выход
    final x = size.width * (u * 1.6 - .3);
    final band = size.width * .38;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = LinearGradient(
          colors: [
            PolarisColors.aurora.withValues(alpha: 0),
            PolarisColors.aurora.withValues(alpha: .10 * envelope),
            PolarisColors.polar.withValues(alpha: .07 * envelope),
            PolarisColors.polar.withValues(alpha: 0),
          ],
          stops: const [0, .4, .6, 1],
        ).createShader(Rect.fromLTWH(x - band / 2, 0, band, size.height)),
    );
  }

  // ------------------------------------------- полярная звезда с лучами

  void _paintStar(Canvas canvas, Size size) {
    final ap = ((p - .15) / .4).clamp(0.0, 1.0);
    if (ap == 0) return;
    final e = Curves.easeOutBack.transform(ap);
    final c = _starCenter(size);

    // Ореол ядра.
    final haloR = 30.0 * e.abs() + .1;
    canvas.drawCircle(
      c,
      haloR,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(colors: [
          Colors.white.withValues(alpha: .55 * ap),
          PolarisColors.polar.withValues(alpha: .25 * ap),
          PolarisColors.polar.withValues(alpha: 0),
        ], stops: const [
          0,
          .35,
          1,
        ]).createShader(Rect.fromCircle(center: c, radius: haloR)),
    );

    // Восемь лучей: 4 длинных (крест) + 4 коротких (диагонали).
    final ray = Paint()
      ..blendMode = BlendMode.plus
      ..color = PolarisColors.star.withValues(alpha: .8 * ap);
    for (var i = 0; i < 8; i++) {
      final len = (i.isEven ? 46.0 : 19.0) * e;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(i * math.pi / 4 + .04 * math.sin(p * _tau));
      final tip = Path()
        ..moveTo(0, -1.6)
        ..lineTo(len, 0)
        ..lineTo(0, 1.6)
        ..close();
      canvas.drawPath(tip, ray);
      canvas.restore();
    }

    // Яркое ядро.
    canvas.drawCircle(
        c, 3.2, Paint()..color = Colors.white.withValues(alpha: .95 * ap));
  }

  // ------------------------------------------------------ финальная искра

  void _paintSpark(Canvas canvas, Size size) {
    if (p <= .82) return;
    final u = ((p - .82) / .18).clamp(0.0, 1.0);
    final c = _starCenter(size);
    // Расходящееся кольцо.
    canvas.drawCircle(
      c,
      20 + u * 130,
      Paint()
        ..blendMode = BlendMode.plus
        ..style = PaintingStyle.stroke
        ..strokeWidth = (1 - u) * 2.6 + .4
        ..color = PolarisColors.aurora.withValues(alpha: .45 * (1 - u)),
    );
    // Короткая вспышка в ядре.
    final flash = math.sin(u * math.pi);
    final flashR = 40.0 * flash + .1;
    canvas.drawCircle(
      c,
      flashR,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(colors: [
          Colors.white.withValues(alpha: .5 * flash),
          PolarisColors.polar.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: c, radius: flashR)),
    );
  }

  @override
  bool shouldRepaint(_SplashPainter old) => old.p != p;
}
