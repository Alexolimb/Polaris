/// «О приложении» (волна 3г) — что такое Polaris, версия, маскот Cosmo,
/// обязательные плашки-атрибуции источников данных.
///
/// Атрибуции обязательны условиями бесплатных лицензий провайдеров данных
/// (см. `server/README.md`): CoinGecko требует явную плашку «Powered by
/// CoinGecko», open.er-api.com — упоминание источника курсов валют. Binance
/// public и котировки акций (Yahoo chart-эндпоинт) официальной атрибуции не
/// требуют, но упомянуты для честности — то же самое правило прозрачности,
/// что и пометка `EOD`/`delayed` в каталоге рынков.
///
/// Пользовательские строки — через [AppLocalizations] (lib/l10n/), 3 языка.
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/theme.dart';
import '../chat/cosmo_screen.dart' show CosmoAvatar;
import 'more_style.dart';

/// Версия MVP — держать синхронно с `pubspec.yaml` (`version:`) вручную,
/// пока не подключён пакет `package_info_plus` (не входит в зону этой волны).
const _appVersion = '1.0.0';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MoreSubScreen(
      title: l10n.aboutTitle,
      children: [
        const SizedBox(height: 8),
        const Center(child: CosmoAvatar(size: 72)),
        const SizedBox(height: 14),
        const Center(
          child: Text(
            'Polaris',
            style: TextStyle(
              color: PolarisColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Center(
          child: Text(
            l10n.aboutVersionLabel(_appVersion),
            style: const TextStyle(
                color: PolarisColors.textSecondary, fontSize: 12.5),
          ),
        ),
        const SizedBox(height: 20),
        InfoBlock(
          icon: Icons.auto_awesome_rounded,
          color: PolarisColors.polar,
          title: l10n.aboutWhatIsItTitle,
          body: l10n.aboutWhatIsItBody,
        ),
        InfoBlock(
          icon: Icons.school_outlined,
          color: PolarisColors.violet,
          title: l10n.aboutSimNoteTitle,
          body: l10n.aboutSimNoteBody,
        ),
        InfoBlock(
          icon: Icons.rocket_launch_outlined,
          color: PolarisColors.aurora,
          title: l10n.aboutMascotTitle,
          body: l10n.aboutMascotBody,
        ),
        InfoBlock(
          icon: Icons.dns_outlined,
          color: PolarisColors.dividend,
          title: l10n.aboutDataTitle,
          body: l10n.aboutDataBody,
        ),
        const SizedBox(height: 6),
        Text(
          l10n.aboutThanksTitle,
          style: const TextStyle(
            color: PolarisColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        // ЧЕСТНОСТЬ: раньше здесь висели плашки «Powered by CoinGecko»,
        // «Yahoo Finance», «Binance», «open.er-api» — ни один из этих
        // источников в приложении не используется, все цены синтетические
        // (бэкенд отдаёт freshness:"demo"). Приписывать себе чужие фиды в
        // публичном инвест-продукте нельзя. Плашки вернуть можно будет только
        // вместе с реально подключённым провайдером.
        Text(
          l10n.marketDemoNotice,
          style: const TextStyle(
            color: PolarisColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
