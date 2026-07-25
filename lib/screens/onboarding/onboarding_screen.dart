/// Онбординг Polaris: 5 экранов-слайдов при первом запуске.
///
/// 1) Приветствие от Cosmo. 2) $10 000 виртуальных денег — тренировка на
/// настоящих ценах без риска. 3) Учёба шаг за шагом + AI-наставник рядом.
/// 4) «Зачем ты здесь?» — выбор цели (влияет только на тон приветствия,
/// сохраняется в [AppSettings]). 5) Дисклеймер (юридически важно — не
/// инвестиционная рекомендация, данные могут задерживаться) + «Начать».
///
/// Навигация только кнопками (свайп выключен) — дисклеймер должен быть
/// реально показан, а не проскочен жестом. Флаг «онбординг пройден» и цель
/// пользователя сохраняются через [AppSettings.completeOnboarding], которая
/// персистит их в [StorageGateway] — при следующем холодном старте интегратор
/// (main.dart) читает [AppSettings.onboardingDone] и решает, показывать ли
/// этот экран или сразу [Shell].
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_settings.dart';
import '../../theme/theme.dart';
import '../../widgets/cosmo/cosmo_mascot.dart';
import '../../widgets/fx/glow.dart';
import '../../widgets/fx/motion.dart';
import '../../widgets/fx/stars_background.dart';

class OnboardingScreen extends StatefulWidget {
  /// Настройки — сюда пишем факт прохождения и выбранную цель.
  final AppSettings settings;

  /// Вызывается сразу после сохранения — интегратор переключает на [Shell].
  final VoidCallback onDone;

  /// false — отключает анимации фона/каскада (батарея, тесты).
  final bool animated;

  const OnboardingScreen({
    super.key,
    required this.settings,
    required this.onDone,
    this.animated = true,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pageCount = 5;
  static const _goalPageIndex = 3;

  final PageController _controller = PageController();
  int _page = 0;
  UserGoal? _goal;
  bool _finishing = false;

  bool get _isLastPage => _page == _pageCount - 1;
  bool get _canProceed => _page != _goalPageIndex || _goal != null;

  void _goTo(int page) {
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleNext() {
    if (!_canProceed) return;
    if (_isLastPage) {
      _finish();
    } else {
      _goTo(_page + 1);
    }
  }

  void _handleBack() {
    if (_page == 0) return;
    _goTo(_page - 1);
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    // Цель не выбрана дойти до диалога быть не может (кнопка заблокирована
    // на шаге выбора), но на всякий случай — нейтральный дефолт.
    await widget.settings.completeOnboarding(_goal ?? UserGoal.curious);
    widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: PolarisColors.bg,
      body: StarsBackground(
        animated: widget.animated,
        intensity: .55,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _controller,
                  // Свайп выключен намеренно: пользователь обязан пройти
                  // через дисклеймер кнопкой, а не проскочить жестом.
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    _WelcomeSlide(animated: widget.animated, l10n: l10n),
                    _VirtualMoneySlide(animated: widget.animated, l10n: l10n),
                    _LearnStepByStepSlide(animated: widget.animated, l10n: l10n),
                    _GoalSlide(
                      animated: widget.animated,
                      selected: _goal,
                      onSelect: (g) => setState(() => _goal = g),
                      l10n: l10n,
                    ),
                    _DisclaimerSlide(animated: widget.animated, l10n: l10n),
                  ],
                ),
              ),
              _BottomBar(
                page: _page,
                pageCount: _pageCount,
                canProceed: _canProceed,
                isLastPage: _isLastPage,
                onBack: _page == 0 ? null : _handleBack,
                onNext: _handleNext,
                l10n: l10n,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ общий каркас

/// Общая раскладка слайда: иллюстрация, заголовок сиянием, текст,
/// опциональный доп.контент (выбор цели). Каскадное появление —
/// [StaggerIn], без таймеров (безопасно для тестов).
///
/// Раньше иллюстрацией был эмодзи 68 px (🧑‍🚀 💫 📚 🎯). Эмодзи рисует
/// шрифт операционной системы: на разных Windows/Android они выглядят
/// по-разному, не связаны с палитрой и делают дорогое приложение детским.
/// Теперь это наши собственные виджеты — маскот Cosmo и иконки в цветах
/// «полярной звезды».
class _SlideScaffold extends StatelessWidget {
  final Widget illustration;
  final Widget title;
  final String body;
  final Widget? extra;

  const _SlideScaffold({
    required this.illustration,
    required this.title,
    required this.body,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height * .55,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            StaggerIn(index: 0, child: illustration),
            const SizedBox(height: 24),
            StaggerIn(index: 1, child: title),
            const SizedBox(height: 16),
            StaggerIn(
              index: 2,
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: PolarisColors.textSecondary,
                ),
              ),
            ),
            if (extra != null) ...[
              const SizedBox(height: 24),
              StaggerIn(index: 3, child: extra!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Заголовок с плывущим градиентом сияния. [animated] прокидывается сюда из
/// [OnboardingScreen.animated] — иначе AuroraText крутит бесконечный
/// repeat() и pumpAndSettle() в тестах никогда не «успокаивается».
Widget _slideTitle(String text, {required bool animated}) => AuroraText(
      text,
      animated: animated,
      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
      textAlign: TextAlign.center,
    );

// ---------------------------------------------------------------- слайд 1

class _WelcomeSlide extends StatelessWidget {
  final bool animated;
  final AppLocalizations l10n;
  const _WelcomeSlide({required this.animated, required this.l10n});

  @override
  Widget build(BuildContext context) => _SlideScaffold(
        // Наш собственный астронавт вместо системного эмодзи — заодно
        // маскот наконец появляется в живом приложении, а не только в
        // demo-файле.
        illustration: CosmoMascot(size: 132, animated: animated),
        title: _slideTitle(l10n.onboardingWelcomeTitle, animated: animated),
        body: l10n.onboardingWelcomeBody,
      );
}

// ---------------------------------------------------------------- слайд 2

class _VirtualMoneySlide extends StatelessWidget {
  final bool animated;
  final AppLocalizations l10n;
  const _VirtualMoneySlide({required this.animated, required this.l10n});

  @override
  Widget build(BuildContext context) => _SlideScaffold(
        illustration: const _SlideIcon(
            icon: Icons.savings_outlined, color: PolarisColors.aurora),
        title: _slideTitle(l10n.onboardingMoneyTitle, animated: animated),
        body: l10n.onboardingMoneyBody,
      );
}

// ---------------------------------------------------------------- слайд 3

class _LearnStepByStepSlide extends StatelessWidget {
  final bool animated;
  final AppLocalizations l10n;
  const _LearnStepByStepSlide({required this.animated, required this.l10n});

  @override
  Widget build(BuildContext context) => _SlideScaffold(
        illustration: const _SlideIcon(
            icon: Icons.school_outlined, color: PolarisColors.polar),
        title: _slideTitle(l10n.onboardingLearnTitle, animated: animated),
        body: l10n.onboardingLearnBody,
      );
}

// ---------------------------------------------------------------- слайд 4

class _GoalSlide extends StatelessWidget {
  final bool animated;
  final UserGoal? selected;
  final ValueChanged<UserGoal> onSelect;
  final AppLocalizations l10n;

  const _GoalSlide({
    required this.animated,
    required this.selected,
    required this.onSelect,
    required this.l10n,
  });

  List<({UserGoal goal, IconData icon, Color color, String label})> _options(
          AppLocalizations l10n) =>
      [
        (
          goal: UserGoal.saveForFuture,
          icon: Icons.eco_outlined,
          color: PolarisColors.gain,
          label: l10n.onboardingGoalSave
        ),
        (
          goal: UserGoal.learnInvesting,
          icon: Icons.school_outlined,
          color: PolarisColors.polar,
          label: l10n.onboardingGoalLearn
        ),
        (
          goal: UserGoal.curious,
          icon: Icons.auto_awesome_outlined,
          color: PolarisColors.violet,
          label: l10n.onboardingGoalCurious
        ),
      ];

  @override
  Widget build(BuildContext context) => _SlideScaffold(
        illustration: const _SlideIcon(
            icon: Icons.flag_outlined, color: PolarisColors.violet),
        title: _slideTitle(l10n.onboardingGoalTitle, animated: animated),
        body: l10n.onboardingGoalBody,
        extra: Column(
          children: [
            for (final o in _options(l10n))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _GoalCard(
                  icon: o.icon,
                  iconColor: o.color,
                  label: o.label,
                  selected: selected == o.goal,
                  onTap: () => onSelect(o.goal),
                ),
              ),
          ],
        ),
      );
}

class _GoalCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GoalCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Springy(
      onTap: onTap,
      haptic: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected
              ? PolarisColors.polar.withValues(alpha: .16)
              : PolarisColors.surface.withValues(alpha: .6),
          border: Border.all(
            color: selected
                ? PolarisColors.polar
                : PolarisColors.textFaint.withValues(alpha: .35),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: PolarisColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: PolarisColors.aurora, size: 22),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- слайд 5

/// Юридически важный текст: обучающий симулятор, не инвестрекомендация,
/// данные могут задерживаться. Держать формулировку стабильной — на неё
/// ссылается security/юридический чек-лист релиза.
class _DisclaimerSlide extends StatelessWidget {
  final bool animated;
  final AppLocalizations l10n;
  const _DisclaimerSlide({required this.animated, required this.l10n});

  @override
  Widget build(BuildContext context) => _SlideScaffold(
        illustration: const _SlideIcon(
            icon: Icons.gavel_outlined, color: PolarisColors.dividend),
        title: _slideTitle(l10n.onboardingDisclaimerTitle, animated: animated),
        body: l10n.onboardingDisclaimerBody,
      );
}

// ------------------------------------------------------------- нижняя панель

class _BottomBar extends StatelessWidget {
  final int page;
  final int pageCount;
  final bool canProceed;
  final bool isLastPage;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final AppLocalizations l10n;

  const _BottomBar({
    required this.page,
    required this.pageCount,
    required this.canProceed,
    required this.isLastPage,
    required this.onBack,
    required this.onNext,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < pageCount; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == page ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: i == page
                        ? PolarisColors.polar
                        : PolarisColors.textFaint.withValues(alpha: .4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 72,
                child: onBack == null
                    ? null
                    : TextButton(
                        onPressed: onBack,
                        child: Text(l10n.onboardingBack,
                            style: const TextStyle(color: PolarisColors.textSecondary)),
                      ),
              ),
              const Spacer(),
              Springy(
                key: const Key('onboarding_cta'),
                onTap: canProceed ? onNext : null,
                child: Opacity(
                  opacity: canProceed ? 1 : .4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        colors: [PolarisColors.polar, PolarisColors.aurora],
                      ),
                    ),
                    child: Text(
                      isLastPage ? l10n.onboardingStart : l10n.onboardingNext,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Иллюстрация слайда: иконка в круге с мягким сиянием фирменного цвета.
/// Пришла на смену эмодзи 68 px — в отличие от них, выглядит одинаково на
/// всех системах и живёт в палитре «полярной звезды».
class _SlideIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _SlideIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      height: 118,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [
          color.withValues(alpha: 0.20),
          color.withValues(alpha: 0.04),
        ]),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Icon(icon, size: 52, color: color),
    );
  }
}
