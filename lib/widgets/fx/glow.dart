/// Светящиеся элементы Polaris: стеклянная карточка, пульсирующая точка,
/// заголовок с плывущим градиентом сияния.
library;

import 'package:flutter/material.dart';

import '../../theme/theme.dart';

// ---------------------------------------------------------------- GlowCard

/// Стеклянная карточка: полупрозрачная поверхность, тонкая светящаяся рамка,
/// мягкая тень-свечение цветом [glowColor]. Статична — дёшева в списках.
class GlowCard extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;

  const GlowCard({
    super.key,
    required this.child,
    this.glowColor = PolarisColors.polar,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        // «Стекло»: лёгкий диагональный перелив поверхности.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PolarisColors.surfaceHigh.withValues(alpha: .72),
            PolarisColors.surface.withValues(alpha: .55),
          ],
        ),
        border: Border.all(
          color: glowColor.withValues(alpha: .28),
          width: 1,
        ),
        boxShadow: [
          // Свечение цветом — «ореол» карточки.
          BoxShadow(
            color: glowColor.withValues(alpha: .16),
            blurRadius: 26,
            spreadRadius: -6,
          ),
          // Глубина — обычная тёмная тень вниз.
          BoxShadow(
            color: Colors.black.withValues(alpha: .35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------- PulseDot

/// Пульсирующая точка-индикатор (live-статус, «рынок открыт» и т.п.).
/// [animated] = false — статичная точка с мягким ореолом.
class PulseDot extends StatefulWidget {
  final Color color;
  final double size;
  final bool animated;

  const PulseDot({
    super.key,
    this.color = PolarisColors.aurora,
    this.size = 12,
    this.animated = true,
  });

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  // Не лениво: ленивый late-контроллер, впервые тронутый в dispose(),
  // падает на поиске TickerMode у предков.
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.animated) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant PulseDot old) {
    super.didUpdateWidget(old);
    if (widget.animated && !_c.isAnimating) _c.repeat();
    if (!widget.animated && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          painter: _PulsePainter(
            u: widget.animated ? _c.value : 0,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  final double u; // фаза пульса 0..1
  final Color color;
  _PulsePainter({required this.u, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    // Расходящееся кольцо: растёт и тает.
    final ring = r * (.35 + .65 * u);
    canvas.drawCircle(
      c,
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * (1 - u) + .3
        ..color = color.withValues(alpha: .45 * (1 - u)),
    );
    // Мягкий ореол вокруг ядра.
    canvas.drawCircle(
      c,
      r * .8,
      Paint()
        ..shader = RadialGradient(colors: [
          color.withValues(alpha: .35),
          color.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: c, radius: r * .8)),
    );
    // Ядро.
    canvas.drawCircle(c, r * .32, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.u != u || old.color != color;
}

// -------------------------------------------------------------- AuroraText

/// Заголовок с медленно плывущим градиентом полярного сияния.
/// [animated] = false — градиент замирает (текст всё равно цветной).
class AuroraText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final bool animated;
  final List<Color> colors;
  final Duration period;
  final TextAlign? textAlign;

  const AuroraText(
    this.text, {
    super.key,
    this.style,
    this.animated = true,
    this.colors = const [
      PolarisColors.polar,
      PolarisColors.aurora,
      PolarisColors.violet,
    ],
    this.period = const Duration(seconds: 6),
    this.textAlign,
  });

  @override
  State<AuroraText> createState() => _AuroraTextState();
}

class _AuroraTextState extends State<AuroraText>
    with SingleTickerProviderStateMixin {
  // Не лениво: см. комментарий в _PulseDotState.
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.period);
    if (widget.animated) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant AuroraText old) {
    super.didUpdateWidget(old);
    if (widget.animated && !_c.isAnimating) _c.repeat();
    if (!widget.animated && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.style ?? Theme.of(context).textTheme.headlineSmall;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) {
          final w = bounds.width == 0 ? 1.0 : bounds.width;
          // Сдвигаем широкий зеркальный градиент — сияние «плывёт» по буквам.
          final dx = w * 2 * _c.value;
          return LinearGradient(
            colors: [...widget.colors, widget.colors.first],
            tileMode: TileMode.mirror,
          ).createShader(Rect.fromLTWH(-dx, 0, w * 2, bounds.height));
        },
        child: child,
      ),
      // Под маской текст белый — цвет даёт градиент.
      child: Text(
        widget.text,
        textAlign: widget.textAlign,
        style: (base ?? const TextStyle()).copyWith(color: Colors.white),
      ),
    );
  }
}
