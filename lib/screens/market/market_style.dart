/// Общие кирпичики вкладки «Рынки»: форматирование денег, цвета классов,
/// бейдж символа, мягкое появление, переход между экранами, шторка-заглушка
/// торговли и «человеческие» описания активов.
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';

// ---------- цвета и подписи классов активов ----------

Color assetTypeColor(AssetType t) => switch (t) {
      AssetType.stock => PolarisColors.stock,
      AssetType.etf => PolarisColors.etf,
      AssetType.bondEtf => PolarisColors.etf,
      AssetType.crypto => PolarisColors.crypto,
      AssetType.fiat => PolarisColors.fx,
    };

String assetTypeLabel(AppLocalizations l10n, AssetType t) => switch (t) {
      AssetType.stock => l10n.assetTypeStock,
      AssetType.etf => l10n.assetTypeEtf,
      AssetType.bondEtf => l10n.assetTypeBondEtf,
      AssetType.crypto => l10n.assetTypeCrypto,
      AssetType.fiat => l10n.assetTypeFiat,
    };

// ---------- форматирование ----------

/// Центы → доллары с разделителями тысяч: 11842000 → «$118,420.00».
String formatCents(int cents) {
  final neg = cents < 0;
  final abs = cents.abs();
  final dollars = (abs ~/ 100).toString();
  final rem = (abs % 100).toString().padLeft(2, '0');
  final buf = StringBuffer();
  for (var i = 0; i < dollars.length; i++) {
    if (i > 0 && (dollars.length - i) % 3 == 0) buf.write(',');
    buf.write(dollars[i]);
  }
  return '${neg ? '-' : ''}\$$buf.$rem';
}

/// Дневное изменение: «+1.34%» / «-0.86%».
String formatChangePct(double pct) =>
    '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%';

Color changeColor(double pct) =>
    pct >= 0 ? PolarisColors.gain : PolarisColors.loss;

const _monthsShort = [
  'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
  'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
];

/// «14 авг» — без пакета intl (он приедет с волной локализации).
String formatShortDate(DateTime d) => '${d.day} ${_monthsShort[d.month - 1]}';

// ---------- описания простыми словами ----------

/// «Что это?» — объяснение класса актива без жаргона.
String assetPlainDescription(AppLocalizations l10n, Asset a) {
  final base = switch (a.type) {
    AssetType.stock => l10n.assetDescStock(a.name),
    AssetType.etf => l10n.assetDescEtf,
    AssetType.bondEtf => l10n.assetDescBondEtf,
    AssetType.crypto => l10n.assetDescCrypto,
    AssetType.fiat => l10n.assetDescFiat,
  };
  final sector = sectorHuman(l10n, a.sector);
  return sector == null ? base : '$base\n\n${l10n.assetSectorLine(sector)}';
}

/// Сектор по-человечески (ключи — как их шлёт сервер/FMP).
String? sectorHuman(AppLocalizations l10n, String? sector) {
  if (sector == null || sector.isEmpty) return null;
  return switch (sector) {
    'Technology' => l10n.sectorTechnology,
    'Financial Services' => l10n.sectorFinancial,
    'Healthcare' => l10n.sectorHealthcare,
    'Consumer Defensive' => l10n.sectorConsumerDefensive,
    'Consumer Cyclical' => l10n.sectorConsumerCyclical,
    'Communication Services' => l10n.sectorCommunication,
    'Energy' => l10n.sectorEnergy,
    'Utilities' => l10n.sectorUtilities,
    'Industrials' => l10n.sectorIndustrials,
    _ => sector,
  };
}

// ---------- виджеты ----------

/// Квадратный бейдж с тикером, окрашенный в цвет класса актива.
class SymbolBadge extends StatelessWidget {
  final Asset asset;
  final double size;

  const SymbolBadge({super.key, required this.asset, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final color = assetTypeColor(asset.type);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          asset.symbol,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.3,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

/// Плашка «EOD» — цена на конец дня, честная пометка не-реалтайма.
class EodTag extends StatelessWidget {
  /// Свежесть цены. По умолчанию — «конец дня» (совместимость со старыми
  /// вызовами без аргумента).
  final QuoteFreshness freshness;

  const EodTag({super.key, this.freshness = QuoteFreshness.endOfDay});

  @override
  Widget build(BuildContext context) {
    // ВАЖНО (честность данных): цена из синтетического движка НЕ должна
    // выглядеть как биржевая. Для demo рисуем заметный тёплый бейдж «ДЕМО»,
    // а не блёклый серый «EOD».
    final isDemo = freshness == QuoteFreshness.demo;
    final color = isDemo ? PolarisColors.dividend : PolarisColors.textFaint;
    final text = isDemo ? AppLocalizations.of(context).marketDemoTag : 'EOD';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: isDemo ? color.withValues(alpha: 0.12) : null,
        border: Border.all(color: color.withValues(alpha: isDemo ? 0.75 : 0.6)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Мягкое появление: прозрачность + подъём. Без сторонних пакетов —
/// TweenAnimationBuilder, задержка зашита в кривую (никаких таймеров).
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int delayMs;

  const FadeSlideIn({super.key, required this.child, this.delayMs = 0});

  @override
  Widget build(BuildContext context) {
    final total = 320 + delayMs;
    final curve = delayMs == 0
        ? Curves.easeOutCubic
        : Interval(delayMs / total, 1, curve: Curves.easeOutCubic);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: curve,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Премиум-переход между экранами: фейд + лёгкий подъём.
Route<T> polarisRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, _, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
                .animate(curved),
            child: child,
          ),
        );
      },
    );

/// Шторка-заглушка торговли. Сам движок подключает волна 2 —
/// здесь sim_engine НЕ вызываем.
Future<void> showTradeStubSheet(
  BuildContext context, {
  required Asset asset,
  required bool buy,
}) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: PolarisColors.surfaceHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rocket_launch_outlined,
                size: 40,
                color: PolarisColors.polar.withValues(alpha: 0.9)),
            const SizedBox(height: 14),
            Text(
              l10n.marketTradeComingTitle,
              style: const TextStyle(
                color: PolarisColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              buy
                  ? l10n.marketTradeComingBodyBuy(asset.symbol)
                  : l10n.marketTradeComingBodySell(asset.symbol),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: PolarisColors.textSecondary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: PolarisColors.polar,
                  foregroundColor: PolarisColors.bg,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text(l10n.doneLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
