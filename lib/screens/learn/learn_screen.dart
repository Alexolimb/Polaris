/// Экран «Учёба» (волна 2б): путь обучения — 5 модулей, уроки как
/// узлы-звёзды на маршруте (пройденные светятся, текущий доступен, будущие
/// приглушены), сверху карточка стрика и общий прогресс.
///
/// Состояние можно передать снаружи (тесты, DI, будущий AppScope) — иначе
/// экран создаёт своё и сам им владеет (паттерн MarketScreen). Контент
/// уроков грузится асинхронно из ассетов через [LessonsRepo], если не
/// передан напрямую через [content] (удобно для тестов/превью).
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
import 'lesson_player.dart';

/// Язык контента по умолчанию для [LessonsRepo], если интегратор не передал
/// [LearnScreen.lang] (например, экран используется вне Shell/AppScope в
/// тестах или превью) — русский, тот же фолбэк, что и в LessonsRepo самом.
String _defaultContentLang() => 'ru';

class LearnScreen extends StatefulWidget {
  /// Внешнее состояние; null — экран создаёт и владеет своим.
  final LearnState? state;

  /// Кастомный источник контента (тесты, оффлайн-демо); null — [LessonsRepo].
  final LessonsRepo? repo;

  /// Контент уже загружен снаружи — экран не пойдёт в ассеты вообще.
  final LessonsContent? content;

  /// Колбэк «попробуй на своём портфеле»: интегратор решает, куда перейти
  /// (вкладка Рынки, тема, конкретный актив) — экран сам вкладки не знает.
  final void Function(TryIt tryIt)? onTryIt;

  /// 'ru' | 'en' | 'es' — язык контента уроков (см.
  /// [AppSettings.resolvedLanguageCode] в main.dart/Shell). null — русский.
  final String Function()? lang;

  const LearnScreen({
    super.key,
    this.state,
    this.repo,
    this.content,
    this.onTryIt,
    this.lang,
  });

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  late final LearnState _state;
  late final bool _ownsState;
  LessonsContent? _content;

  @override
  void initState() {
    super.initState();
    _state = widget.state ?? LearnState();
    _ownsState = widget.state == null;
    if (!_state.loaded) unawaited(_state.load());
    if (widget.content != null) {
      _content = widget.content;
    } else {
      unawaited(_loadContent());
    }
  }

  @override
  void dispose() {
    if (_ownsState) _state.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    final repo = widget.repo ?? LessonsRepo(lang: widget.lang ?? _defaultContentLang);
    final c = await repo.load();
    if (mounted) setState(() => _content = c);
  }

  @override
  Widget build(BuildContext context) {
    return StarsBackground(
      intensity: 0.6,
      child: SafeArea(
        child: AnimatedBuilder(
          animation: _state,
          builder: (context, _) => _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = _content;
    if (content == null || !_state.loaded) {
      return const Center(
        child: CircularProgressIndicator(
            color: PolarisColors.polar, strokeWidth: 2.5),
      );
    }
    // Пустой экран не только когда уроков нет, но и когда ни один модуль не
    // отрисовывается (битый/пустой modules при живых lessons) — иначе показали
    // бы заголовок со стриком без единого урока.
    if (content.isEmpty || content.modulesSorted.isEmpty) {
      return _emptyState(l10n);
    }

    // Прогресс и порядок — ТОЛЬКО по реально отображаемым урокам (из известных
    // модулей). Уроки-сироты (moduleId без модуля) не рендерятся и не должны
    // раздувать знаменатель, иначе 100% недостижимы.
    final orderedIds = [
      for (final module in content.modulesSorted)
        ...content.lessonsOf(module.id).map((l) => l.id),
    ];
    final overallPct = _state.overallProgressPct(orderedIds);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _header(content, overallPct, l10n)),
        SliverToBoxAdapter(child: _streakCard(l10n)),
        for (final module in content.modulesSorted)
          SliverToBoxAdapter(
            child: _ModuleSection(
              module: module,
              lessons: content.lessonsOf(module.id),
              learnState: _state,
              orderedLessonIds: orderedIds,
              onOpenLesson: _openLesson,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }

  void _openLesson(Lesson lesson) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LessonPlayer(
        lesson: lesson,
        learnState: _state,
        onTryIt: widget.onTryIt,
      ),
    ));
  }

  void _openGlossary(LessonsContent content) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PolarisColors.surfaceHigh,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _GlossarySheet(terms: content.glossary),
    );
  }

  Widget _header(LessonsContent content, double overallPct, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.learnScreenTitle,
                  style: const TextStyle(
                    color: PolarisColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.learnProgressLabel(overallPct.round().toString()),
                  style: const TextStyle(
                      color: PolarisColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_outlined,
                color: PolarisColors.textSecondary),
            tooltip: l10n.learnGlossaryTooltip,
            onPressed: () => _openGlossary(content),
          ),
        ],
      ),
    );
  }

  Widget _streakCard(AppLocalizations l10n) {
    final streak = _state.currentStreak;
    final completedToday = _state.completedToday;
    final subtitle = streak == 0
        ? l10n.streakSubtitleNone
        : completedToday
            ? l10n.streakSubtitleDoneToday
            : l10n.streakSubtitleTodo;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: GlowCard(
        glowColor: PolarisColors.dividend,
        child: Row(
          children: [
            // Была эмодзи-«свечка» 🔥 30 px — рисуется шрифтом системы и
            // выбивается из палитры. Своя иконка в цвет «дивиденда».
            const Icon(Icons.local_fire_department_rounded,
                size: 30, color: PolarisColors.dividend),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    streak > 0
                        ? l10n.streakDaysInARow(streak)
                        : l10n.streakStartYours,
                    style: const TextStyle(
                      color: PolarisColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: PolarisColors.textSecondary, fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_stories_outlined,
                color: PolarisColors.textFaint, size: 48),
            const SizedBox(height: 14),
            Text(l10n.learnEmptyTitle,
                style: const TextStyle(
                    color: PolarisColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              l10n.learnEmptyBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: PolarisColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== модуль и узлы-звёзды ====================

class _ModuleSection extends StatelessWidget {
  final Module module;
  final List<Lesson> lessons;
  final LearnState learnState;
  final List<String> orderedLessonIds;
  final void Function(Lesson lesson) onOpenLesson;

  const _ModuleSection({
    required this.module,
    required this.lessons,
    required this.learnState,
    required this.orderedLessonIds,
    required this.onOpenLesson,
  });

  @override
  Widget build(BuildContext context) {
    final ids = lessons.map((l) => l.id).toList();
    final pct = learnState.moduleProgressPct(ids);
    final done = ids.where(learnState.isCompleted).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: GlowCard(
        glowColor: module.accent,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(module.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    module.title,
                    style: const TextStyle(
                        color: PolarisColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '$done/${ids.length}',
                  style: TextStyle(
                      color: module.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: PolarisColors.surfaceHigh,
                valueColor: AlwaysStoppedAnimation(module.accent),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 76,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: lessons.length,
                itemBuilder: (context, i) {
                  final lesson = lessons[i];
                  final completed = learnState.isCompleted(lesson.id);
                  final unlocked =
                      learnState.isUnlocked(lesson.id, orderedLessonIds);
                  return Row(
                    children: [
                      _LessonNode(
                        index: i + 1,
                        completed: completed,
                        unlocked: unlocked,
                        current: !completed && unlocked,
                        accent: module.accent,
                        onTap: unlocked ? () => onOpenLesson(lesson) : null,
                      ),
                      if (i < lessons.length - 1)
                        _Connector(lit: completed, accent: module.accent),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonNode extends StatelessWidget {
  final int index;
  final bool completed;
  final bool unlocked;
  final bool current;
  final Color accent;
  final VoidCallback? onTap;

  const _LessonNode({
    required this.index,
    required this.completed,
    required this.unlocked,
    required this.current,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = unlocked ? accent : PolarisColors.textFaint;
    final bg = completed
        ? accent.withValues(alpha: .22)
        : unlocked
            ? PolarisColors.surface
            : PolarisColors.surface.withValues(alpha: .4);
    return Springy(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: Border.all(
            color: color.withValues(alpha: unlocked ? .9 : .35),
            width: current ? 2.4 : 1.6,
          ),
          boxShadow: current
              ? [
                  BoxShadow(
                      color: accent.withValues(alpha: .35),
                      blurRadius: 16,
                      spreadRadius: 1)
                ]
              : null,
        ),
        child: completed
            ? Icon(Icons.check_rounded, color: accent, size: 24)
            : unlocked
                ? Text('$index',
                    style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 16))
                : const Icon(Icons.lock_outline_rounded,
                    color: PolarisColors.textFaint, size: 18),
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  final bool lit;
  final Color accent;
  const _Connector({required this.lit, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: lit ? accent.withValues(alpha: .7) : PolarisColors.surfaceHigh,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ==================== глоссарий (шторка с поиском) ====================

class _GlossarySheet extends StatefulWidget {
  final List<GlossaryTerm> terms;
  const _GlossarySheet({required this.terms});

  @override
  State<_GlossarySheet> createState() => _GlossarySheetState();
}

class _GlossarySheetState extends State<_GlossarySheet> {
  String _query = '';

  List<GlossaryTerm> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.terms;
    return widget.terms
        .where((t) =>
            t.term.toLowerCase().contains(q) ||
            t.definition.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filtered = _filtered;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.learnGlossarySheetTitle,
                style: const TextStyle(
                    color: PolarisColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: PolarisColors.textPrimary),
                decoration: InputDecoration(
                  hintText: l10n.learnGlossarySearchHint,
                  hintStyle: const TextStyle(color: PolarisColors.textFaint),
                  prefixIcon:
                      const Icon(Icons.search, color: PolarisColors.textSecondary),
                  filled: true,
                  fillColor: PolarisColors.surface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(l10n.commonNothingFound,
                            style: const TextStyle(color: PolarisColors.textFaint)))
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const Divider(color: PolarisColors.surface, height: 20),
                        itemBuilder: (context, i) {
                          final t = filtered[i];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.term,
                                  style: const TextStyle(
                                      color: PolarisColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(t.definition,
                                  style: const TextStyle(
                                      color: PolarisColors.textSecondary,
                                      fontSize: 13.5,
                                      height: 1.4)),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
