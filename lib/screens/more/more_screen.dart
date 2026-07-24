/// Экран «Ещё» (волна 3г): разделы настроек и информации — переход к
/// настоящим инвестициям, о приложении, конфиденциальность, правовая
/// информация. Экран навигационный: своего состояния не хранит, интегратор
/// просто вставляет `const MoreScreen()` пятой вкладкой в main.dart.
///
/// Заголовки/подписи идут через [AppLocalizations] (см. lib/l10n/) — 3 языка,
/// переключаются в разделе «Настройки» ([SettingsScreen]).
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/theme.dart';
import '../../widgets/fx/glow.dart';
import '../../widgets/fx/motion.dart';
import '../../widgets/fx/stars_background.dart';
import '../market/market_style.dart' show FadeSlideIn, polarisRoute;
import 'about_screen.dart';
import 'brokers_screen.dart';
import 'legal_screen.dart';
import 'privacy_screen.dart';
import 'settings_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = <_MoreItem>[
      _MoreItem(
        icon: Icons.tune_rounded,
        color: PolarisColors.polar,
        title: l10n.moreSettingsTitle,
        subtitle: l10n.moreSettingsSubtitle,
        onTap: () => Navigator.of(context)
            .push(polarisRoute(const SettingsScreen())),
      ),
      _MoreItem(
        icon: Icons.rocket_launch_rounded,
        color: PolarisColors.aurora,
        title: l10n.moreBrokersTitle,
        subtitle: l10n.moreBrokersSubtitle,
        onTap: () =>
            Navigator.of(context).push(polarisRoute(const BrokersScreen())),
      ),
      _MoreItem(
        icon: Icons.info_outline_rounded,
        color: PolarisColors.violet,
        title: l10n.moreAboutTitle,
        subtitle: l10n.moreAboutSubtitle,
        onTap: () =>
            Navigator.of(context).push(polarisRoute(const AboutScreen())),
      ),
      _MoreItem(
        icon: Icons.lock_outline_rounded,
        color: PolarisColors.dividend,
        title: l10n.morePrivacyTitle,
        subtitle: l10n.morePrivacySubtitle,
        onTap: () =>
            Navigator.of(context).push(polarisRoute(const PrivacyScreen())),
      ),
      _MoreItem(
        icon: Icons.gavel_rounded,
        color: PolarisColors.textSecondary,
        title: l10n.moreLegalTitle,
        subtitle: l10n.moreLegalSubtitle,
        onTap: () =>
            Navigator.of(context).push(polarisRoute(const LegalScreen())),
      ),
    ];

    return StarsBackground(
      intensity: 0.5,
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(title: l10n.moreScreenTitle)),
            SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, i) => FadeSlideIn(
                delayMs: i * 40,
                child: _MoreRow(item: items[i]),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Text(
        title,
        style: const TextStyle(
          color: PolarisColors.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

class _MoreItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  _MoreItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class _MoreRow extends StatelessWidget {
  final _MoreItem item;

  const _MoreRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Springy(
        onTap: item.onTap,
        child: GlowCard(
          glowColor: item.color,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: PolarisColors.textPrimary,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                          color: PolarisColors.textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: PolarisColors.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}
