/// «Конфиденциальность» (волна 3г) — простыми словами, GDPR-дружелюбно:
/// что хранится на устройстве, что уходит на сервер и зачем, без юр-жаргона.
/// Полный текст политики — по ссылке-плейсхолдеру (пока приложение не
/// опубликовано, полноценной страницы политики ещё нет — см. TODO ниже).
///
/// Пользовательские строки — через [AppLocalizations] (lib/l10n/), 3 языка.
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/theme.dart';
import '../../widgets/fx/motion.dart';
import 'more_style.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MoreSubScreen(
      title: l10n.privacyTitle,
      children: [
        Text(
          l10n.privacyIntro,
          style: const TextStyle(
            color: PolarisColors.textSecondary,
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        InfoBlock(
          icon: Icons.smartphone_rounded,
          color: PolarisColors.polar,
          title: l10n.privacyLocalTitle,
          body: l10n.privacyLocalBody,
        ),
        InfoBlock(
          icon: Icons.cloud_outlined,
          color: PolarisColors.aurora,
          title: l10n.privacyServerTitle,
          body: l10n.privacyServerBody,
        ),
        InfoBlock(
          icon: Icons.visibility_off_outlined,
          color: PolarisColors.violet,
          title: l10n.privacyNoTrackersTitle,
          body: l10n.privacyNoTrackersBody,
        ),
        InfoBlock(
          icon: Icons.verified_user_outlined,
          color: PolarisColors.dividend,
          title: l10n.privacyRightsTitle,
          body: l10n.privacyRightsBody,
        ),
        const SizedBox(height: 4),
        _FullPolicyLink(l10n: l10n),
      ],
    );
  }
}

class _FullPolicyLink extends StatelessWidget {
  final AppLocalizations l10n;
  const _FullPolicyLink({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Springy(
      // Полноценной страницы политики пока нет — появится вместе с
      // публикацией в Google Play (интегратор/Алекс вставит реальный URL,
      // например https://polaris-app.example/privacy). Тап сейчас безопасно
      // ничего не делает, чтобы не вести на несуществующую страницу.
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: PolarisColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: PolarisColors.textFaint.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.description_outlined,
                color: PolarisColors.textSecondary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.privacyFullPolicyLabel,
                    style: const TextStyle(
                      color: PolarisColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    l10n.privacyFullPolicyNote,
                    style: const TextStyle(
                        color: PolarisColors.textFaint, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: PolarisColors.textFaint),
          ],
        ),
      ),
    );
  }
}
