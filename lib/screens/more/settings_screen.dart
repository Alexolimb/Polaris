/// «Настройки» (волна локализации, заменяет прежнюю заглушку
/// `_openSettingsStub`): выбор языка интерфейса, переключатели локальных
/// уведомлений и сброс портфеля — всё, что реально хранится в [AppSettings]
/// и [PortfolioState].
///
/// Экран слушает [AppSettings] напрямую (он ChangeNotifier) — переключение
/// языка здесь сразу перерисовывает MaterialApp выше по дереву (см.
/// main.dart, PolarisApp), эффект виден мгновенно, без перезапуска.
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_scope.dart';
import '../../state/app_settings.dart';
import '../../theme/theme.dart';
import '../../widgets/fx/glow.dart';
import '../../widgets/fx/motion.dart';
import 'more_style.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = AppScope.of(context).settings;
    return AnimatedBuilder(
      animation: settings,
      // Material transparente: Switch (уведомления) — материальный виджет,
      // MoreSubScreen сам его не предоставляет (другие подэкраны «Ещё»
      // обходятся Springy/GestureDetector, этому экрану нужен настоящий).
      builder: (context, _) => Material(
        type: MaterialType.transparency,
        child: MoreSubScreen(
          title: l10n.settingsTitle,
          children: [
            _SectionLabel(l10n.settingsLanguageSection),
            _LanguageCard(settings: settings, l10n: l10n),
            const SizedBox(height: 8),
            _SectionLabel(l10n.settingsNotificationsSection),
            GlowCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SwitchTile(
                    title: l10n.settingsNotifLesson,
                    subtitle: l10n.settingsNotifLessonSub,
                    value: settings.notifyLessonReminder,
                    onChanged: settings.setLessonReminder,
                  ),
                  const _TileDivider(),
                  _SwitchTile(
                    title: l10n.settingsNotifWeekly,
                    subtitle: l10n.settingsNotifWeeklySub,
                    value: settings.notifyWeeklySummary,
                    onChanged: settings.setWeeklySummary,
                  ),
                  const _TileDivider(),
                  _SwitchTile(
                    title: l10n.settingsNotifDividend,
                    subtitle: l10n.settingsNotifDividendSub,
                    value: settings.notifyDividend,
                    onChanged: settings.setDividendPaid,
                  ),
                  const _TileDivider(),
                  _SwitchTile(
                    title: l10n.settingsNotifBigMoves,
                    subtitle: l10n.settingsNotifBigMovesSub,
                    value: settings.notifyBigMoves,
                    onChanged: settings.setBigMoves,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _SectionLabel(l10n.settingsDataSection),
            _ResetPortfolioTile(l10n: l10n),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: PolarisColors.textFaint,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();
  @override
  Widget build(BuildContext context) => const Divider(
    color: PolarisColors.surfaceHigh,
    height: 1,
    indent: 16,
    endIndent: 16,
  );
}

class _LanguageCard extends StatelessWidget {
  final AppSettings settings;
  final AppLocalizations l10n;
  const _LanguageCard({required this.settings, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final options = <(LocalePref, String)>[
      (LocalePref.auto, l10n.settingsLanguageAuto),
      (LocalePref.en, l10n.settingsLanguageEnglish),
      (LocalePref.ru, l10n.settingsLanguageRussian),
      (LocalePref.es, l10n.settingsLanguageSpanish),
    ];
    return GlowCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const _TileDivider(),
            _RadioTile(
              label: options[i].$2,
              selected: settings.localePref == options[i].$1,
              onTap: () => settings.setLocalePref(options[i].$1),
            ),
          ],
        ],
      ),
    );
  }
}

class _RadioTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RadioTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Springy(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: PolarisColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? PolarisColors.polar : PolarisColors.textFaint,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: PolarisColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: PolarisColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: PolarisColors.polar,
          ),
        ],
      ),
    );
  }
}

class _ResetPortfolioTile extends StatelessWidget {
  final AppLocalizations l10n;
  const _ResetPortfolioTile({required this.l10n});

  Future<void> _confirmReset(BuildContext context) async {
    final scope = AppScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: PolarisColors.surface,
        title: Text(
          l10n.resetDialogTitle,
          style: const TextStyle(color: PolarisColors.textPrimary),
        ),
        content: Text(
          l10n.resetDialogBody,
          style: const TextStyle(color: PolarisColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: PolarisColors.loss),
            child: Text(l10n.resetConfirmAction),
          ),
        ],
      ),
    );
    if (ok == true) await scope.portfolio.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Springy(
      onTap: () => _confirmReset(context),
      child: GlowCard(
        glowColor: PolarisColors.loss,
        child: Row(
          children: [
            const Icon(Icons.restart_alt_rounded, color: PolarisColors.loss),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.settingsResetPortfolio,
                    style: const TextStyle(
                      color: PolarisColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.settingsResetPortfolioSub,
                    style: const TextStyle(
                      color: PolarisColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
