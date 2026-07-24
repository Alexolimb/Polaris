/// «Правовая информация» (волна 3г) — дисклеймеры образовательного
/// симулятора. Юр-рамка из `.build/recon.md`: реальную торговлю приложение
/// не ведёт (нет лицензии CNMV/MiFID II), AI не даёт персональных
/// инвестиционных рекомендаций (правило ЕС/ESMA — либо конкретный тикер,
/// либо персонализация, никогда одновременно), обязательны предупреждения
/// «не является инвестиционной рекомендацией» и «прошлые результаты не
/// гарантируют будущих».
///
/// Пользовательские строки — через [AppLocalizations] (lib/l10n/), 3 языка.
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/theme.dart';
import 'more_style.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MoreSubScreen(
      title: l10n.legalTitle,
      children: [
        Text(
          l10n.legalIntro,
          style: const TextStyle(
            color: PolarisColors.textSecondary,
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        InfoBlock(
          icon: Icons.school_outlined,
          color: PolarisColors.polar,
          title: l10n.legalSimTitle,
          body: l10n.legalSimBody,
        ),
        InfoBlock(
          icon: Icons.do_not_disturb_alt_rounded,
          color: PolarisColors.loss,
          title: l10n.legalNoAdviceTitle,
          body: l10n.legalNoAdviceBody,
        ),
        InfoBlock(
          icon: Icons.trending_down_rounded,
          color: PolarisColors.loss,
          title: l10n.legalPastResultsTitle,
          body: l10n.legalPastResultsBody,
        ),
        InfoBlock(
          icon: Icons.schedule_rounded,
          color: PolarisColors.dividend,
          title: l10n.legalDelayedDataTitle,
          body: l10n.legalDelayedDataBody,
        ),
        InfoBlock(
          icon: Icons.smart_toy_outlined,
          color: PolarisColors.violet,
          title: l10n.legalAiTitle,
          body: l10n.legalAiBody,
        ),
        InfoBlock(
          icon: Icons.apartment_outlined,
          color: PolarisColors.textSecondary,
          title: l10n.legalEntityTitle,
          body: l10n.legalEntityBody,
        ),
      ],
    );
  }
}
