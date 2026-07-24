/// «Готов к настоящим инвестициям?» (волна 3г) — спокойный переход из
/// симулятора к реальному брокеру, БЕЗ давления и БЕЗ крипты.
///
/// Юридическая рамка (см. `.build/recon.md`, раздел 2): реальную торговлю
/// само приложение не ведёт и не может — регулируемая деятельность в ЕС.
/// Здесь только честный список лицензированных в Евросоюзе брокеров АКЦИЙ,
/// нейтральные однострочные описания и предупреждения о риске сверху и
/// снизу. Никакой крипты в этом разделе — крипто-рефералки под запретом
/// рекламных правил Испании (Circular CNMV 1/2022) и требуют лицензии MiCA
/// CASP, которой у Алекса нет и не планируется на этапе 1.
///
/// Ссылки — placeholder-домены официальных сайтов брокеров, БЕЗ партнёрских
/// меток (см. комментарий у каждой ссылки, где именно её потом вставить).
///
/// Пользовательские строки — через [AppLocalizations] (lib/l10n/), 3 языка.
/// Названия брокеров — собственные имена, не переводятся; описания — ключи
/// brokers*Desc.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/theme.dart';
import '../../widgets/fx/glow.dart';
import '../../widgets/fx/motion.dart';
import 'more_style.dart';

class _Broker {
  final String name;
  final String Function(AppLocalizations) description;
  final String url;

  const _Broker({required this.name, required this.description, required this.url});
}

/// Список брокеров — только акции/ETF, только лицензированные в ЕС.
/// НИКАКОЙ крипты (см. комментарий в шапке файла).
const _brokers = <_Broker>[
  _Broker(
    name: 'eToro',
    description: _descEtoro,
    // TODO Алекс: вставить партнёрскую метку в URL, когда будет заключён
    // партнёрский договор (например ?partner_id=...). Пока — чистый домен.
    url: 'https://www.etoro.com',
  ),
  _Broker(
    name: 'Interactive Brokers',
    description: _descIbkr,
    // TODO Алекс: партнёрская метка сюда, если IBKR предложит affiliate.
    url: 'https://www.interactivebrokers.com',
  ),
  _Broker(
    name: 'Lightyear',
    description: _descLightyear,
    // TODO Алекс: партнёрская метка сюда, если Lightyear предложит affiliate.
    url: 'https://www.lightyear.com',
  ),
  _Broker(
    name: 'Scalable Capital',
    description: _descScalable,
    // TODO Алекс: партнёрская метка сюда, если Scalable предложит affiliate.
    url: 'https://scalable.capital',
  ),
  _Broker(
    name: 'Trade Republic',
    description: _descTraderepublic,
    // TODO Алекс: партнёрская метка сюда, если Trade Republic предложит affiliate.
    url: 'https://www.traderepublic.com',
  ),
  _Broker(
    name: 'XTB',
    description: _descXtb,
    // TODO Алекс: партнёрская метка сюда, если XTB предложит affiliate.
    url: 'https://www.xtb.com',
  ),
];

String _descEtoro(AppLocalizations l) => l.brokersEtoroDesc;
String _descIbkr(AppLocalizations l) => l.brokersIbkrDesc;
String _descLightyear(AppLocalizations l) => l.brokersLightyearDesc;
String _descScalable(AppLocalizations l) => l.brokersScalableDesc;
String _descTraderepublic(AppLocalizations l) => l.brokersTraderepublicDesc;
String _descXtb(AppLocalizations l) => l.brokersXtbDesc;

class BrokersScreen extends StatelessWidget {
  const BrokersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MoreSubScreen(
      title: l10n.brokersTitle,
      children: [
        RiskBanner(text: l10n.brokersRiskTop),
        Text(
          l10n.brokersIntro,
          style: const TextStyle(
            color: PolarisColors.textSecondary,
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          l10n.brokersSectionListTitle,
          style: const TextStyle(
            color: PolarisColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.block_rounded, color: PolarisColors.textFaint, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.brokersNoCryptoNote,
                style: const TextStyle(
                  color: PolarisColors.textFaint,
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final b in _brokers) _BrokerCard(broker: b, l10n: l10n),
        const SizedBox(height: 6),
        RiskBanner(text: l10n.brokersRiskBottom),
      ],
    );
  }
}

class _BrokerCard extends StatelessWidget {
  final _Broker broker;
  final AppLocalizations l10n;

  const _BrokerCard({required this.broker, required this.l10n});

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(broker.url);
    var ok = false;
    try {
      if (await canLaunchUrl(uri)) {
        ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.brokersOpenFailed),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlowCard(
        glowColor: PolarisColors.aurora,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              broker.name,
              style: const TextStyle(
                color: PolarisColors.textPrimary,
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              broker.description(l10n),
              style: const TextStyle(
                color: PolarisColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Springy(
                    onTap: () => _open(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: PolarisColors.aurora.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: PolarisColors.aurora.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.open_in_new_rounded,
                              color: PolarisColors.aurora, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            l10n.brokersOpenSiteLabel,
                            style: const TextStyle(
                              color: PolarisColors.aurora,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.brokersExternalSiteNote,
                  style: const TextStyle(
                      color: PolarisColors.textFaint, fontSize: 10.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
