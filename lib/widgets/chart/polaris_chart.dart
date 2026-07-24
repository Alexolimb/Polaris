/// График котировок Polaris — свой CustomPainter, без чартинг-пакетов
/// (решение из плана: полный контроль + свечи, которых нет в fl_chart).
///
/// Умеет:
/// - режим area: плавная линия со свечением и градиентной заливкой
///   в цвет тренда (рост — PolarisColors.gain, падение — loss);
/// - режим candles: свечи с хвостами;
/// - появление: линия прорисовывается слева направо;
/// - морф при смене серии: поточечный твининг (area) / кроссфейд (candles);
/// - скраббинг пальцем: вертикальный луч + точка + плашка с ценой и датой,
///   наружу — колбэк onScrub(Candle?), null = палец отпущен;
/// - пустая серия / одна точка / все цены равны — плоская линия с подписью,
///   без крашей.
///
/// Производительность: путь area-линии кэшируется и пересобирается только
/// при смене данных или размера; скраббинг перерисовывает только оверлей
/// поверх готового пути. shouldRepaint сверяет данные и фазы анимаций.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'chart_models.dart';

/// Режим отображения графика.
enum ChartMode { area, candles }

/// Внутренние отступы: сверху место под плашку скраббинга.
const double _padTop = 12;
const double _padBottom = 8;

/// Потолок точек при морфе — глазу больше не нужно, а твинить дешевле.
const int _morphMaxSamples = 300;

class PolarisChart extends StatefulWidget {
  /// Серия свечей по возрастанию времени. Для area берутся закрытия.
  final List<Candle> candles;

  final ChartMode mode;

  /// Скраббинг: свеча под пальцем, null — палец отпущен (вернуть шапке
  /// текущую цену). Вызывается только при смене свечи, без спама.
  final ValueChanged<Candle?>? onScrub;

  final double height;

  /// Подпись при пустой серии.
  final String emptyLabel;

  final Duration appearDuration;
  final Duration morphDuration;

  const PolarisChart({
    super.key,
    required this.candles,
    this.mode = ChartMode.area,
    this.onScrub,
    this.height = 220,
    this.emptyLabel = 'Нет данных',
    this.appearDuration = const Duration(milliseconds: 900),
    this.morphDuration = const Duration(milliseconds: 380),
  });

  @override
  State<PolarisChart> createState() => _PolarisChartState();
}

class _PolarisChartState extends State<PolarisChart>
    with TickerProviderStateMixin {
  late final AnimationController _appear;
  late final AnimationController _morph;

  /// Текущая area-серия (double-центы, всегда пустая или >= 2 точек).
  late List<double> _closes;

  // Слепки для морфа: откуда и куда твиним (общая длина).
  List<double>? _morphFrom;
  List<double>? _morphTo;

  /// Прошлые свечи — для кроссфейда в режиме candles.
  List<Candle>? _prevCandles;

  /// Тренд прошлой серии — чтобы цвет тоже перетекал, а не прыгал.
  bool? _prevGain;

  int? _scrubIndex;

  /// Кэш геометрии area-линии, живёт в состоянии и переживает кадры.
  final _AreaCache _cache = _AreaCache();

  @override
  void initState() {
    super.initState();
    _appear = AnimationController(vsync: this, duration: widget.appearDuration);
    _morph = AnimationController(vsync: this, duration: widget.morphDuration);
    _closes = _closesFor(widget.candles);
    _appear.forward();
  }

  @override
  void dispose() {
    _appear.dispose();
    _morph.dispose();
    super.dispose();
  }

  /// Закрытия серии; одна точка дублируется, чтобы линии было из чего
  /// состоять (плоская чёрточка через всю ширину).
  static List<double> _closesFor(List<Candle> candles) {
    final closes = closesOf(candles);
    if (closes.length == 1) return [closes.first, closes.first];
    return closes;
  }

  @override
  void didUpdateWidget(covariant PolarisChart old) {
    super.didUpdateWidget(old);
    if (_sameSeries(old.candles, widget.candles)) return;

    final shown = _samplesForPaint();
    final target = _closesFor(widget.candles);

    // Скраббинг по старой серии больше не осмыслен — гасим.
    if (_scrubIndex != null) {
      _scrubIndex = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onScrub?.call(null);
      });
    }

    if (shown.isEmpty || target.isEmpty) {
      // Из пустоты (или в пустоту) морфить нечего — просто прорисовка заново.
      _morphFrom = null;
      _morphTo = null;
      _prevCandles = null;
      _prevGain = null;
      _closes = target;
      _appear.forward(from: 0);
      return;
    }

    final n = math.max(2,
        math.min(_morphMaxSamples, math.max(shown.length, target.length)));
    _morphFrom = resampleValues(shown, n);
    _morphTo = resampleValues(target, n);
    _prevCandles = old.candles;
    _prevGain = trendIsGain(old.candles);
    _closes = target;
    _appear.value = 1; // морф сам «приводит» линию, повторная прорисовка не нужна
    _morph.forward(from: 0);
  }

  static bool _sameSeries(List<Candle> a, List<Candle> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  double get _morphT => Curves.easeInOutCubic.transform(_morph.value);

  /// Что рисуем в кадре: во время морфа — лерп слепков, иначе — серию как есть.
  List<double> _samplesForPaint() {
    if (_morph.isAnimating && _morphFrom != null && _morphTo != null) {
      return lerpSamples(_morphFrom!, _morphTo!, _morphT);
    }
    return _closes;
  }

  /// Цвет тренда; при морфе плавно перетекает от прошлого к новому.
  Color _trendColor() {
    final cur = trendIsGain(widget.candles)
        ? PolarisColors.gain
        : PolarisColors.loss;
    final prevGain = _prevGain;
    if (_morph.isAnimating && prevGain != null) {
      final prev = prevGain ? PolarisColors.gain : PolarisColors.loss;
      return Color.lerp(prev, cur, _morphT) ?? cur;
    }
    return cur;
  }

  // ---- скраббинг ----

  int? _indexForDx(double dx) {
    final n = widget.candles.length;
    if (n == 0) return null;
    if (n == 1) return 0;
    final w = context.size?.width ?? 0;
    if (w <= 0) return null;
    final int i;
    if (widget.mode == ChartMode.area) {
      i = (dx / w * (n - 1)).round();
    } else {
      i = dx ~/ (w / n);
    }
    return math.max(0, math.min(n - 1, i));
  }

  void _setScrub(Offset local) {
    final i = _indexForDx(local.dx);
    if (i == null || i == _scrubIndex) return;
    setState(() => _scrubIndex = i);
    widget.onScrub?.call(widget.candles[i]);
  }

  void _clearScrub() {
    if (_scrubIndex == null) return;
    setState(() => _scrubIndex = null);
    widget.onScrub?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Горизонтальное ведение пальцем — основной жест скраббинга.
      onHorizontalDragStart: (d) => _setScrub(d.localPosition),
      onHorizontalDragUpdate: (d) => _setScrub(d.localPosition),
      onHorizontalDragEnd: (_) => _clearScrub(),
      onHorizontalDragCancel: _clearScrub,
      // Долгое нажатие — то же самое (удобно внутри вертикального скролла).
      onLongPressStart: (d) => _setScrub(d.localPosition),
      onLongPressMoveUpdate: (d) => _setScrub(d.localPosition),
      onLongPressEnd: (_) => _clearScrub(),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_appear, _morph]),
            builder: (context, _) => CustomPaint(
              painter: _ChartPainter(
                mode: widget.mode,
                samples: _samplesForPaint(),
                candles: widget.candles,
                prevCandles: _morph.isAnimating ? _prevCandles : null,
                appearT: Curves.easeOutCubic.transform(_appear.value),
                morphT: _morph.isAnimating ? _morphT : 1,
                scrubIndex: _scrubIndex,
                trend: _trendColor(),
                emptyLabel: widget.emptyLabel,
                cache: _cache,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Кэш геометрии area-линии: пересобирается только при смене данных/размера.
// ---------------------------------------------------------------------------

class _AreaCache {
  Size size = Size.zero;
  List<double>? samples; // сверяем по identity
  ChartRange? range;
  final Path line = Path();
  final Path fill = Path();
  List<ui.PathMetric> metrics = const [];
  double length = 0;
}

/// Плавная линия через точки: кубические сегменты с контрольными точками
/// на середине шага — гладко и без вылетов за диапазон значений.
Path _smoothLine(List<Offset> pts) {
  final path = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (var i = 1; i < pts.length; i++) {
    final p0 = pts[i - 1];
    final p1 = pts[i];
    final cx = (p0.dx + p1.dx) / 2;
    path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
  }
  return path;
}

class _ChartPainter extends CustomPainter {
  final ChartMode mode;
  final List<double> samples;
  final List<Candle> candles;
  final List<Candle>? prevCandles;
  final double appearT;
  final double morphT;
  final int? scrubIndex;
  final Color trend;
  final String emptyLabel;
  final _AreaCache cache;

  const _ChartPainter({
    required this.mode,
    required this.samples,
    required this.candles,
    required this.prevCandles,
    required this.appearT,
    required this.morphT,
    required this.scrubIndex,
    required this.trend,
    required this.emptyLabel,
    required this.cache,
  });

  double _yFor(double v, ChartRange range, Size size) {
    if (range.isFlat) return size.height / 2;
    final h = size.height - _padTop - _padBottom;
    return _padTop + (range.maxCents - v) / range.spanCents * h;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    if (samples.isEmpty) {
      // Пустая серия: плоская пунктирная линия и подпись, без паники.
      _paintFlatPlaceholder(canvas, size);
      return;
    }

    final ChartRange range;
    if (mode == ChartMode.area) {
      _ensureAreaCache(size);
      range = cache.range!;
      _paintArea(canvas, size);
    } else {
      range = _paintCandles(canvas, size);
    }

    if (range.isFlat && candles.isNotEmpty) {
      // Все цены равны — честно подписываем, какая именно.
      _paintLabel(canvas, size, formatCents(candles.last.closeCents),
          dy: size.height / 2 + 14);
    }

    _paintScrub(canvas, size, range);
  }

  // ---- area ----

  void _ensureAreaCache(Size size) {
    if (identical(cache.samples, samples) && cache.size == size) return;
    cache
      ..samples = samples
      ..size = size
      ..range = rangeOfValues(samples)!.padded(0.08);
    final range = cache.range!;
    final n = samples.length;
    final pts = List<Offset>.generate(
      n,
      (i) => Offset(
        n == 1 ? size.width / 2 : i / (n - 1) * size.width,
        _yFor(samples[i], range, size),
      ),
    );
    cache.line
      ..reset()
      ..addPath(_smoothLine(pts), Offset.zero);
    cache.fill
      ..reset()
      ..addPath(cache.line, Offset.zero)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    cache.metrics = cache.line.computeMetrics().toList();
    cache.length = cache.metrics.fold(0, (s, m) => s + m.length);
  }

  void _paintArea(Canvas canvas, Size size) {
    final reveal = ui.clampDouble(appearT, 0, 1);
    if (reveal <= 0) return;

    // Заливка под линией — градиент в цвет тренда, тающий к низу.
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          trend.withValues(alpha: 0.28),
          trend.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.save();
    if (reveal < 1) {
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width * reveal, size.height));
    }
    canvas.drawPath(cache.fill, fillPaint);
    canvas.restore();

    // Линия: при появлении вытягиваем кусок пути по его длине —
    // эффект «рисуется слева направо».
    final Path linePath;
    if (reveal >= 1) {
      linePath = cache.line;
    } else {
      linePath = Path();
      var remaining = cache.length * reveal;
      for (final m in cache.metrics) {
        if (remaining <= 0) break;
        final take = math.min(remaining, m.length);
        linePath.addPath(m.extractPath(0, take), Offset.zero);
        remaining -= take;
      }
    }

    // Свечение — размытый широкий штрих под основной линией.
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = trend.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(linePath, glowPaint);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = trend;
    canvas.drawPath(linePath, linePaint);
  }

  // ---- candles ----

  /// Рисует свечи, возвращает диапазон, в котором они легли (для скраба).
  ChartRange _paintCandles(Canvas canvas, Size size) {
    final cur = candles;
    final prev = prevCandles;
    final curRange = (rangeOfCandles(cur) ?? const ChartRange(0, 0)).padded(0.08);

    final prevRange = prev == null ? null : rangeOfCandles(prev);
    if (prev != null && prevRange != null && morphT < 1) {
      // Морф в режиме свечей — кроссфейд серий в перетекающем диапазоне.
      final r = ChartRange.lerp(prevRange.padded(0.08), curRange, morphT);
      _drawCandleSeries(canvas, size, prev, r, alpha: 1 - morphT);
      _drawCandleSeries(canvas, size, cur, r, alpha: morphT);
      return r;
    }

    _drawCandleSeries(canvas, size, cur, curRange, alpha: 1, reveal: appearT);
    return curRange;
  }

  void _drawCandleSeries(
    Canvas canvas,
    Size size,
    List<Candle> list,
    ChartRange range, {
    required double alpha,
    double reveal = 1,
  }) {
    if (list.isEmpty || alpha <= 0) return;
    final n = list.length;
    final slot = size.width / n;
    final bodyW = ui.clampDouble(slot * 0.6, 1.5, 14);
    final visible = math.min(n, (n * reveal).ceil());
    final wickPaint = Paint()
      ..strokeWidth = math.max(1, bodyW * 0.16)
      ..strokeCap = StrokeCap.round;
    final bodyPaint = Paint();

    for (var i = 0; i < visible; i++) {
      final c = list[i];
      // Крайняя свеча при прорисовке проявляется постепенно.
      var a = alpha;
      if (reveal < 1 && i == visible - 1) {
        a *= ui.clampDouble(n * reveal - i, 0, 1);
      }
      final color = (c.bullish ? PolarisColors.gain : PolarisColors.loss)
          .withValues(alpha: 0.95 * a);
      final x = (i + 0.5) * slot;
      final yHigh = _yFor(c.highCents.toDouble(), range, size);
      final yLow = _yFor(c.lowCents.toDouble(), range, size);
      final yOpen = _yFor(c.openCents.toDouble(), range, size);
      final yClose = _yFor(c.closeCents.toDouble(), range, size);

      wickPaint.color = color.withValues(alpha: 0.8 * a);
      canvas.drawLine(Offset(x, yHigh), Offset(x, yLow), wickPaint);

      var top = math.min(yOpen, yClose);
      var bottom = math.max(yOpen, yClose);
      if (bottom - top < 1.4) {
        // Дожи: тело не тоньше волоска, иначе свечу не видно.
        final mid = (top + bottom) / 2;
        top = mid - 0.7;
        bottom = mid + 0.7;
      }
      bodyPaint.color = color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x - bodyW / 2, top, x + bodyW / 2, bottom),
          Radius.circular(math.min(2, bodyW / 3)),
        ),
        bodyPaint,
      );
    }
  }

  // ---- скраббинг: луч + точка + плашка ----

  void _paintScrub(Canvas canvas, Size size, ChartRange range) {
    final i = scrubIndex;
    if (i == null || i < 0 || i >= candles.length) return;
    final c = candles[i];
    final n = candles.length;
    final double x;
    if (n == 1) {
      x = size.width / 2;
    } else if (mode == ChartMode.area) {
      x = i / (n - 1) * size.width;
    } else {
      x = (i + 0.5) * size.width / n;
    }
    final y = _yFor(c.closeCents.toDouble(), range, size);

    // Вертикальный луч — звёздный белый, тающий к краям.
    final rayPaint = Paint()
      ..strokeWidth = 1.2
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x00EFF4FF), Color(0x7DEFF4FF), Color(0x00EFF4FF)],
      ).createShader(Rect.fromLTWH(x - 1, 0, 2, size.height));
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), rayPaint);

    // Точка на линии: свечение + яркое ядро.
    canvas.drawCircle(
      Offset(x, y),
      7,
      Paint()
        ..color = trend.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(Offset(x, y), 3.4, Paint()..color = PolarisColors.star);

    _paintScrubBubble(canvas, size, x, c);
  }

  void _paintScrubBubble(Canvas canvas, Size size, double x, Candle c) {
    final priceTp = TextPainter(
      text: TextSpan(
        text: formatCents(c.closeCents),
        style: const TextStyle(
          color: PolarisColors.star,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dateTp = TextPainter(
      text: TextSpan(
        text: formatCandleDate(c.ts),
        style: const TextStyle(
          color: PolarisColors.textSecondary,
          fontSize: 11,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const padH = 10.0;
    const padV = 6.0;
    final w = math.max(priceTp.width, dateTp.width) + padH * 2;
    final h = priceTp.height + dateTp.height + padV * 2 + 2;
    // Плашка липнет к лучу, но не выходит за края графика.
    final bx = ui.clampDouble(x - w / 2, 4, math.max(4, size.width - w - 4));
    const by = 4.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bx, by, w, h),
      const Radius.circular(9),
    );
    canvas.drawRRect(
        rect, Paint()..color = PolarisColors.surfaceHigh.withValues(alpha: 0.96));
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = PolarisColors.polar.withValues(alpha: 0.35),
    );
    priceTp.paint(canvas, Offset(bx + padH, by + padV));
    dateTp.paint(canvas, Offset(bx + padH, by + padV + priceTp.height + 2));
  }

  // ---- пустая/плоская серия ----

  void _paintFlatPlaceholder(Canvas canvas, Size size) {
    final y = size.height / 2;
    final linePaint = Paint()
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = PolarisColors.textFaint.withValues(alpha: 0.7);
    // Пунктир руками: чартинг-пакетов нет, dashPath тоже не нужен.
    const dash = 6.0;
    const gap = 5.0;
    var xPos = 0.0;
    while (xPos < size.width) {
      canvas.drawLine(Offset(xPos, y),
          Offset(math.min(xPos + dash, size.width), y), linePaint);
      xPos += dash + gap;
    }
    _paintLabel(canvas, size, emptyLabel, dy: y + 14);
  }

  void _paintLabel(Canvas canvas, Size size, String text, {required double dy}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: PolarisColors.textSecondary, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    tp.paint(canvas,
        Offset((size.width - tp.width) / 2, math.min(dy, size.height - tp.height)));
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.mode != mode ||
      !identical(old.samples, samples) ||
      !identical(old.candles, candles) ||
      !identical(old.prevCandles, prevCandles) ||
      old.appearT != appearT ||
      old.morphT != morphT ||
      old.scrubIndex != scrubIndex ||
      old.trend != trend ||
      old.emptyLabel != emptyLabel;
}

// ---------------------------------------------------------------------------
// PolarisSparkline — мини-линия тренда для строк списка.
// ---------------------------------------------------------------------------

/// Маленькая линия тренда: без осей, без жестов, один цвет по знаку
/// изменения (вырос — gain, упал — loss). Для каталогов и списков —
/// поэтому без glow-эффектов: дёшево рисуется сотней штук в скролле.
class PolarisSparkline extends StatelessWidget {
  /// Ряд значений (обычно закрытия в центах — см. [closesOf]).
  final List<double> values;

  final double width;
  final double height;

  /// Принудительный цвет; по умолчанию — по знаку изменения.
  final Color? color;

  const PolarisSparkline({
    super.key,
    required this.values,
    this.width = 64,
    this.height = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _SparklinePainter(values, color)),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color? color;

  const _SparklinePainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (values.length < 2) {
      // Нет данных (или одна точка) — тихая плоская чёрточка.
      paint.color = color ?? PolarisColors.textFaint;
      canvas.drawLine(Offset(0, size.height / 2),
          Offset(size.width, size.height / 2), paint);
      return;
    }

    final range = rangeOfValues(values)!.padded(0.1);
    paint.color = color ??
        (values.last >= values.first ? PolarisColors.gain : PolarisColors.loss);
    final n = values.length;
    // Небольшой вертикальный отступ, чтобы линия не резалась о края.
    const inset = 1.5;
    final h = size.height - inset * 2;
    final pts = List<Offset>.generate(n, (i) {
      final y = range.isFlat
          ? size.height / 2
          : inset + (range.maxCents - values[i]) / range.spanCents * h;
      return Offset(i / (n - 1) * size.width, y);
    });
    canvas.drawPath(_smoothLine(pts), paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      !identical(old.values, values) || old.color != color;
}
