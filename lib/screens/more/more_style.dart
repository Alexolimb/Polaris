/// Общие кирпичики вкладки «Ещё»: шапка подэкрана с кнопкой назад,
/// информационный блок (иконка+заголовок+текст) и плашка-предупреждение
/// о риске. Используются во всех подэкранах этой вкладки — брокеры, о
/// приложении, конфиденциальность, правовая информация.
library;

import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../../widgets/fx/glow.dart';
import '../../widgets/fx/stars_background.dart';

/// Каркас подэкрана: звёздный фон + шапка с «назад» + прокручиваемое тело.
class MoreSubScreen extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const MoreSubScreen({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return StarsBackground(
      intensity: 0.45,
      child: SafeArea(
        child: Column(
          children: [
            _topBar(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded,
                color: PolarisColors.textPrimary),
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: PolarisColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Блок с иконкой, заголовком и абзацем текста внутри стеклянной карточки.
/// Базовый строительный блок разделов «Правовая информация» и
/// «Конфиденциальность».
class InfoBlock extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const InfoBlock({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.color = PolarisColors.polar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlowCard(
        glowColor: color,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: PolarisColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: const TextStyle(
                      color: PolarisColors.textSecondary,
                      fontSize: 13,
                      height: 1.45,
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

/// Плашка предупреждения о риске — жёлто-красный акцент, всегда видна.
/// Используется сверху и снизу раздела брокеров (требование плана).
class RiskBanner extends StatelessWidget {
  final String text;

  const RiskBanner({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PolarisColors.loss.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PolarisColors.loss.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: PolarisColors.loss, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: PolarisColors.textPrimary,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Небольшая плашка атрибуции источника данных («Powered by …») — обязательна
/// по условиям бесплатных лицензий провайдеров (см. server/README.md).
class AttributionChip extends StatelessWidget {
  final String text;

  const AttributionChip({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: PolarisColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PolarisColors.textFaint.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: PolarisColors.textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
