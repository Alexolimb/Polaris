/// Прохождение одного урока (волна 2б): свайп по экранам-карточкам → квиз
/// (подсветка верного/неверного + объяснение) → экран завершения с начислением
/// прогресса, обновлением стрика и кнопкой «попробуй на своём портфеле».
///
/// [learnState] — то же самое состояние, что живёт в [LearnScreen] (шарим
/// инстанс через конструктор при пуше, как MarketScreen шарит MarketState с
/// AssetScreen) — так прогресс сразу виден на «пути» после возврата.
///
/// Переход между вкладками — не наша забота: при нажатии на «попробуй» мы
/// зовём [onTryIt] с готовым [TryIt] (что открыть — рынок/тему/актив) и
/// закрываем экран; интегратор в main.dart решает, куда именно перейти.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/lessons.dart';
import '../../state/learn_state.dart';
import '../../theme/theme.dart';
import '../../widgets/fx/glow.dart';
import '../../widgets/fx/motion.dart';
import '../../widgets/fx/stars_background.dart';

enum _Phase { screens, quiz, done }

enum _OptionVisual { idle, selected, correct, wrong, dimmed }

class LessonPlayer extends StatefulWidget {
  final Lesson lesson;
  final LearnState learnState;
  final void Function(TryIt tryIt)? onTryIt;

  const LessonPlayer({
    super.key,
    required this.lesson,
    required this.learnState,
    this.onTryIt,
  });

  @override
  State<LessonPlayer> createState() => _LessonPlayerState();
}

class _LessonPlayerState extends State<LessonPlayer> {
  late final PageController _pageController;
  late List<int?> _selected;
  late List<bool> _revealed;

  _Phase _phase = _Phase.screens;
  int _screenIndex = 0;
  int _quizIndex = 0;
  bool _completedOnce = false; // защита от двойного начисления прогресса

  Lesson get _lesson => widget.lesson;
  bool get _isLastScreen => _screenIndex >= _lesson.screens.length - 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _selected = List<int?>.filled(_lesson.quiz.length, null);
    _revealed = List<bool>.filled(_lesson.quiz.length, false);
    if (_lesson.screens.isEmpty) {
      // Защитный путь для нестандартных данных (в проде Lesson.isValid уже
      // гарантирует непустые экраны) — не должно случаться, но не роняем UI.
      if (_lesson.quiz.isEmpty) {
        _phase = _Phase.done;
        unawaited(_completeAndShowDone());
      } else {
        _phase = _Phase.quiz;
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ---- переходы между фазами ----

  void _nextScreen() {
    if (!_isLastScreen) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _advanceFromScreens();
    }
  }

  void _advanceFromScreens() {
    if (_lesson.quiz.isEmpty) {
      unawaited(_completeAndShowDone());
    } else {
      setState(() => _phase = _Phase.quiz);
    }
  }

  void _selectOption(int optionIndex) {
    if (_revealed[_quizIndex]) return;
    setState(() => _selected[_quizIndex] = optionIndex);
  }

  void _reveal() {
    if (_selected[_quizIndex] == null) return;
    setState(() => _revealed[_quizIndex] = true);
  }

  void _nextQuizQuestion() {
    if (_quizIndex < _lesson.quiz.length - 1) {
      setState(() => _quizIndex += 1);
    } else {
      unawaited(_completeAndShowDone());
    }
  }

  /// Начисляет прогресс/стрик ПЕРЕД показом финального экрана — так цифры
  /// на нём (стрик, счёт квиза) уже свежие, без гонки кадров.
  Future<void> _completeAndShowDone() async {
    if (!_completedOnce) {
      _completedOnce = true;
      var correct = 0;
      for (var i = 0; i < _lesson.quiz.length; i++) {
        if (_selected[i] == _lesson.quiz[i].correctIndex) correct++;
      }
      try {
        await widget.learnState.completeLesson(
          _lesson.id,
          quizCorrect: correct,
          quizTotal: _lesson.quiz.length,
        );
      } on LearnProgressNotSaved {
        // Прогресс не лёг на устройство (или не читался при запуске). Показать
        // «Урок пройден!» здесь — прямое враньё: после перезапуска урока не
        // будет. Говорим прямо и не рисуем поздравление.
        _completedOnce = false; // можно попробовать ещё раз
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).learnNotSavedError),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ));
        return;
      }
    }
    if (mounted) setState(() => _phase = _Phase.done);
  }

  int get _quizCorrectCount {
    var c = 0;
    for (var i = 0; i < _lesson.quiz.length; i++) {
      if (_selected[i] == _lesson.quiz[i].correctIndex) c++;
    }
    return c;
  }

  void _tryIt() {
    final t = _lesson.tryIt;
    if (t == null) return;
    widget.onTryIt?.call(t);
    Navigator.of(context).maybePop();
  }

  // ---- ui ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PolarisColors.bg,
      body: StarsBackground(
        intensity: 0.45,
        child: SafeArea(
          child: Column(
            children: [
              _topBar(context),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 20, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: PolarisColors.textSecondary),
            tooltip: AppLocalizations.of(context).lessonCloseTooltip,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(child: _progressBar()),
        ],
      ),
    );
  }

  Widget _progressBar() {
    final total = _lesson.screens.length + _lesson.quiz.length;
    if (total <= 1) return const SizedBox.shrink();
    final current = switch (_phase) {
      _Phase.screens => _screenIndex,
      _Phase.quiz => _lesson.screens.length + _quizIndex,
      _Phase.done => total,
    };
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: i < current || _phase == _Phase.done
                    ? PolarisColors.polar
                    : (i == current
                        ? PolarisColors.polar.withValues(alpha: .55)
                        : PolarisColors.surfaceHigh),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _body() {
    return switch (_phase) {
      _Phase.screens => _screensView(),
      _Phase.quiz => _lesson.quiz.isEmpty ? _doneView() : _quizView(),
      _Phase.done => _doneView(),
    };
  }

  Widget _screensView() {
    if (_lesson.screens.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _lesson.screens.length,
            onPageChanged: (i) => setState(() => _screenIndex = i),
            itemBuilder: (context, i) => _ScreenCard(screen: _lesson.screens[i]),
          ),
        ),
        _bottomBar(
          label: _isLastScreen
              ? (_lesson.quiz.isEmpty ? l10n.lessonButtonDone : l10n.lessonButtonToQuiz)
              : l10n.lessonButtonNext,
          onPressed: _nextScreen,
        ),
      ],
    );
  }

  Widget _quizView() {
    final l10n = AppLocalizations.of(context);
    final q = _lesson.quiz[_quizIndex];
    final selected = _selected[_quizIndex];
    final revealed = _revealed[_quizIndex];
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.lessonQuizHeader,
                  style: const TextStyle(
                    color: PolarisColors.textFaint,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  q.question,
                  style: const TextStyle(
                    color: PolarisColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                for (var i = 0; i < q.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _QuizOption(
                      text: q.options[i],
                      state: _optionVisual(i, q, selected, revealed),
                      onTap: revealed ? null : () => _selectOption(i),
                    ),
                  ),
                if (revealed) ...[
                  const SizedBox(height: 6),
                  _ExplanationCard(
                    correct: selected == q.correctIndex,
                    text: q.explanation,
                  ),
                ],
              ],
            ),
          ),
        ),
        _bottomBar(
          label: !revealed
              ? l10n.lessonButtonAnswer
              : (_quizIndex < _lesson.quiz.length - 1
                  ? l10n.lessonButtonNextQuestion
                  : l10n.lessonButtonFinish),
          onPressed: !revealed
              ? (selected == null ? null : _reveal)
              : _nextQuizQuestion,
        ),
      ],
    );
  }

  static _OptionVisual _optionVisual(
      int i, QuizQuestion q, int? selected, bool revealed) {
    if (!revealed) {
      return i == selected ? _OptionVisual.selected : _OptionVisual.idle;
    }
    if (i == q.correctIndex) return _OptionVisual.correct;
    if (i == selected) return _OptionVisual.wrong;
    return _OptionVisual.dimmed;
  }

  Widget _doneView() {
    final l10n = AppLocalizations.of(context);
    final total = _lesson.quiz.length;
    final correct = _quizCorrectCount;
    final streak = widget.learnState.currentStreak;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const Icon(Icons.rocket_launch_rounded,
              color: PolarisColors.polar, size: 60),
          const SizedBox(height: 16),
          AuroraText(
            l10n.lessonCompleteTitle,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (total > 0)
            Text(
              l10n.lessonScore(correct, total),
              style: const TextStyle(
                  color: PolarisColors.textSecondary, fontSize: 15),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 17)),
              const SizedBox(width: 6),
              Text(
                l10n.streakLabelWithDays(l10n.streakDaysInARow(streak)),
                style: const TextStyle(
                  color: PolarisColors.dividend,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (_lesson.tryIt != null) ...[
            _TryItCard(tryIt: _lesson.tryIt!, onTap: _tryIt),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: PolarisColors.polar,
                foregroundColor: PolarisColors.bg,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(l10n.lessonButtonReady,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          if (_lesson.disclaimer != null) ...[
            const SizedBox(height: 16),
            Text(
              _lesson.disclaimer!,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: PolarisColors.textFaint, fontSize: 11.5, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bottomBar({required String label, required VoidCallback? onPressed}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: PolarisColors.polar,
            foregroundColor: PolarisColors.bg,
            disabledBackgroundColor: PolarisColors.surfaceHigh,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: onPressed,
          child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ),
    );
  }

}

// ==================== мелкие виджеты ====================

class _ScreenCard extends StatelessWidget {
  final LessonScreen screen;
  const _ScreenCard({required this.screen});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: GlowCard(
        glowColor: screen.accent,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(screen.emoji, style: const TextStyle(fontSize: 42)),
            const SizedBox(height: 14),
            Text(
              screen.title,
              style: const TextStyle(
                color: PolarisColors.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 14),
            for (final p in screen.paragraphs) ...[
              Text(
                p,
                style: const TextStyle(
                    color: PolarisColors.textSecondary, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuizOption extends StatelessWidget {
  final String text;
  final _OptionVisual state;
  final VoidCallback? onTap;

  const _QuizOption({required this.text, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (Color border, Color bg, IconData? icon, Color? iconColor) = switch (state) {
      _OptionVisual.idle => (PolarisColors.surfaceHigh, PolarisColors.surface, null, null),
      _OptionVisual.selected => (
          PolarisColors.polar,
          PolarisColors.polar.withValues(alpha: .14),
          null,
          null,
        ),
      _OptionVisual.correct => (
          PolarisColors.gain,
          PolarisColors.gain.withValues(alpha: .14),
          Icons.check_circle_rounded,
          PolarisColors.gain,
        ),
      _OptionVisual.wrong => (
          PolarisColors.loss,
          PolarisColors.loss.withValues(alpha: .14),
          Icons.cancel_rounded,
          PolarisColors.loss,
        ),
      _OptionVisual.dimmed => (PolarisColors.surfaceHigh, PolarisColors.surface, null, null),
    };
    final dim = state == _OptionVisual.dimmed;
    return Springy(
      onTap: onTap,
      child: Opacity(
        opacity: dim ? .55 : 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1.4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                      color: PolarisColors.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600),
                ),
              ),
              if (icon != null) Icon(icon, color: iconColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  final bool correct;
  final String text;
  const _ExplanationCard({required this.correct, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = correct ? PolarisColors.gain : PolarisColors.loss;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(correct ? Icons.emoji_events_outlined : Icons.lightbulb_outline,
              color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  color: PolarisColors.textSecondary, fontSize: 13.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _TryItCard extends StatelessWidget {
  final TryIt tryIt;
  final VoidCallback onTap;
  const _TryItCard({required this.tryIt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Springy(
      onTap: onTap,
      child: GlowCard(
        glowColor: PolarisColors.aurora,
        child: Row(
          children: [
            const Icon(Icons.explore_outlined, color: PolarisColors.aurora, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tryIt.text,
                style: const TextStyle(
                    color: PolarisColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: PolarisColors.textFaint, size: 14),
          ],
        ),
      ),
    );
  }
}
