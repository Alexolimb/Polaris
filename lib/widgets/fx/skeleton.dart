/// Скелетоны загрузки: серые заготовки той формы, что вот-вот появится.
///
/// Зачем не крутилка. Крутящееся колечко говорит «жди» и ничего больше —
/// человек смотрит в пустоту и не знает, что получит. Скелетон показывает
/// каркас будущего экрана: список, карточку, график. Ожидание кажется короче,
/// а переход к данным перестаёт быть рывком, потому что ничего не «прыгает» —
/// заготовка стоит там же и того же размера, что и настоящий элемент.
///
/// Здесь свой мягкий блик, а не пакет с shimmer: одна анимация на весь список
/// (`AnimatedBuilder` вокруг общего контроллера), и без новой зависимости.
library;

import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// Одна серая плашка с бегущим бликом. Размер задаёт вызывающий код —
/// скелетон должен повторять форму того, что грузится.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final t = SkeletonPulse.of(context);
    // Блик идёт слева направо: -1 → 2, чтобы он успевал уйти за правый край
    // широкой плашки и не «дёргался» обратно из середины.
    final shift = -1.0 + t * 3.0;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment(shift - 1, 0),
          end: Alignment(shift, 0),
          colors: const [
            PolarisColors.surface,
            PolarisColors.surfaceHigh,
            PolarisColors.surface,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

/// Общий такт блика для всех скелетонов внутри. Один контроллер на экран —
/// иначе двадцать плашек завели бы двадцать анимаций и мигали вразнобой.
class SkeletonPulse extends StatefulWidget {
  final Widget child;
  const SkeletonPulse({super.key, required this.child});

  /// Фаза блика 0..1. Вне [SkeletonPulse] возвращает 0.35 — статичную плашку:
  /// скелетон без анимации всё ещё полезен и ничего не ломает.
  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_SkeletonPhase>()
          ?.phase ??
      0.35;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    // Уважаем «уменьшить анимацию» в системе: там блик не бежит, остаётся
    // ровная плашка. Проверяется в build — настройку можно сменить на ходу.
    _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      if (_c.isAnimating) _c.stop();
      return _SkeletonPhase(phase: 0.35, child: widget.child);
    }
    if (!_c.isAnimating) _c.repeat();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) =>
          _SkeletonPhase(phase: _c.value, child: widget.child),
    );
  }
}

class _SkeletonPhase extends InheritedWidget {
  final double phase;
  const _SkeletonPhase({required this.phase, required super.child});

  @override
  bool updateShouldNotify(_SkeletonPhase old) => old.phase != phase;
}

/// Заготовка строки списка активов/уроков: кружок слева, две строки текста,
/// цифра справа. Повторяет геометрию настоящей строки, чтобы при появлении
/// данных ничего не сдвигалось.
class SkeletonRow extends StatelessWidget {
  /// Показывать ли правый блок (цена/прогресс). Для уроков он не нужен.
  final bool trailing;

  const SkeletonRow({super.key, this.trailing = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const SkeletonBox(width: 38, height: 38, radius: 19),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120, height: 13, radius: 6),
                SizedBox(height: 7),
                SkeletonBox(width: 78, height: 10, radius: 5),
              ],
            ),
          ),
          if (trailing) ...[
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SkeletonBox(width: 62, height: 13, radius: 6),
                SizedBox(height: 7),
                SkeletonBox(width: 40, height: 10, radius: 5),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Список заготовок с заголовком секции — типовая «загружающаяся» лента.
class SkeletonList extends StatelessWidget {
  final int rows;
  final bool trailing;

  const SkeletonList({super.key, this.rows = 6, this.trailing = true});

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 16, 10),
            child: SkeletonBox(width: 96, height: 11, radius: 5),
          ),
          for (var i = 0; i < rows; i++) SkeletonRow(trailing: trailing),
        ],
      ),
    );
  }
}
