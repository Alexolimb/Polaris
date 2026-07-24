/// Главный экран — Портфель (волна 2). Один экран, одна большая цифра:
/// стоимость портфеля, прибыль/убыток, ниже — позиции. «Живой пульс» —
/// мягкая пульсация вокруг суммы. Пусто → тёплое приглашение начать.
///
/// Читает общее состояние через AppScope: портфель (PortfolioState) и
/// котировки (MarketState). Тянет котировки удерживаемых бумаг и начисляет
/// причитающиеся дивиденды при заходе/обновлении.
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../state/market_state.dart';
import '../../state/portfolio_state.dart';
import '../../theme/theme.dart';
import '../../widgets/chart/polaris_chart.dart';
import '../../widgets/fx/glow.dart';
import '../../widgets/fx/motion.dart';
import '../../widgets/fx/stars_background.dart';
import '../market/asset_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _synced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_synced) {
      _synced = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncHeldQuotes());
    }
  }

  Future<void> _syncHeldQuotes() async {
    final scope = AppScope.read(context);
    final held = scope.portfolio.positions.keys.toList();
    if (held.isEmpty) return;
    await scope.market.ensureQuotesFor(held);
    await _creditDueDividends(scope, held);
    _notifyBigMoves(scope, held);
  }

  // Начисляем причитающиеся дивиденды по календарю (сервер или фикстуры) и
  // шлём уведомление о каждой новой выплате. Всё в try/catch — тихо, не мешаем.
  Future<void> _creditDueDividends(AppScope scope, List<String> held) async {
    try {
      final dues = <DividendDue>[];
      for (final sym in held) {
        final events = await scope.market.repo.dividends(sym);
        for (final e in events) {
          if (e.exDate != null) {
            dues.add(DividendDue(
                symbol: sym, perShareCents: e.perShareCents, exDate: e.exDate!));
          }
        }
      }
      final fresh = await scope.portfolio.applyDueDividends(dues);
      for (final d in fresh) {
        await scope.notifications.notifyDividendPaid(
          symbol: d.symbol,
          amountText: CountUpText.formatCents(d.totalCents),
        );
      }
    } catch (_) {/* нет данных дивидендов — не страшно */}
  }

  // Разовое уведомление о резком движении удерживаемой бумаги (±5% за день).
  void _notifyBigMoves(AppScope scope, List<String> held) {
    final lang = scope.settings.resolvedLanguageCode;
    for (final sym in held) {
      final q = scope.market.quoteOf(sym);
      if (q == null) continue;
      final pct = q.dayChangePct;
      if (pct.abs() >= 5.0) {
        final sign = pct >= 0 ? '+' : '';
        final perDay = switch (lang) {
          'ru' => 'за день',
          'es' => 'en el día',
          _ => 'in a day',
        };
        scope.notifications.notifyBigMove(
            symbol: sym, changeText: '$sign${pct.toStringAsFixed(1)}% $perDay');
      }
    }
  }

  Map<String, Quote> _heldQuotes(MarketState market, PortfolioState p) {
    final m = <String, Quote>{};
    for (final s in p.positions.keys) {
      final q = market.quoteOf(s);
      if (q != null) m[s] = q;
    }
    return m;
  }

  Future<void> _confirmReset(PortfolioState p) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: PolarisColors.surface,
        title: Text(l10n.resetDialogTitle,
            style: const TextStyle(color: PolarisColors.textPrimary)),
        content: Text(
          l10n.resetDialogBody,
          style: const TextStyle(color: PolarisColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancelLabel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: PolarisColors.loss),
              child: Text(l10n.resetConfirmAction)),
        ],
      ),
    );
    if (ok == true) await p.reset();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final portfolio = scope.portfolio;
    final market = scope.market;

    return StarsBackground(
      child: AnimatedBuilder(
        animation: Listenable.merge([portfolio, market]),
        builder: (context, _) {
          final quotes = _heldQuotes(market, portfolio);
          final total = portfolio.totalValueCents(quotes);
          final ret = portfolio.totalReturnCents(quotes);
          final retPct = portfolio.totalReturnPct(quotes);
          final positions = portfolio.positions.values.toList()
            ..sort((a, b) {
              final va = (quotes[a.symbol]?.priceCents ?? 0) * a.qty;
              final vb = (quotes[b.symbol]?.priceCents ?? 0) * b.qty;
              return vb.compareTo(va);
            });

          return SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await market.ensureQuotesFor(
                    portfolio.positions.keys.toList(),
                    refresh: true);
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _header(context, portfolio, total, ret, retPct),
                  ),
                  if (positions.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _emptyState(context),
                    )
                  else
                    SliverList.builder(
                      itemCount: positions.length,
                      itemBuilder: (context, i) => StaggerIn(
                        index: i,
                        child: _positionRow(
                            context, positions[i], quotes[positions[i].symbol], market),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, PortfolioState p, int total, int ret,
      double retPct) {
    final l10n = AppLocalizations.of(context);
    final up = ret >= 0;
    final retColor = up ? PolarisColors.gain : PolarisColors.loss;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.homeMyPortfolio,
                  style: const TextStyle(
                      color: PolarisColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              Row(children: [
                const PulseDot(color: PolarisColors.aurora, size: 8),
                const SizedBox(width: 6),
                Text(l10n.homeLivePrices,
                    style: const TextStyle(
                        color: PolarisColors.textFaint, fontSize: 12)),
                IconButton(
                  icon: const Icon(Icons.restart_alt,
                      color: PolarisColors.textFaint, size: 20),
                  tooltip: l10n.homeResetTooltip,
                  onPressed: () => _confirmReset(p),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 6),
          CountUpText(
            cents: total,
            style: const TextStyle(
                color: PolarisColors.textPrimary,
                fontSize: 40,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(up ? Icons.trending_up : Icons.trending_down,
                  color: retColor, size: 18),
              const SizedBox(width: 4),
              Text(
                '${up ? '+' : ''}${CountUpText.formatCents(ret)}  (${up ? '+' : ''}${retPct.toStringAsFixed(2)}%)',
                style: TextStyle(
                    color: retColor, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(l10n.homeFreeCash(CountUpText.formatCents(p.cashCents)),
              style: const TextStyle(
                  color: PolarisColors.textSecondary, fontSize: 13)),
          if (p.dividendsTotalCents > 0) ...[
            const SizedBox(height: 2),
            Text(l10n.homeDividendsReceived(CountUpText.formatCents(p.dividendsTotalCents)),
                style: const TextStyle(
                    color: PolarisColors.dividend, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _positionRow(
      BuildContext context, Position pos, Quote? quote, MarketState market) {
    final asset = market.assets.cast<Asset?>().firstWhere(
        (a) => a?.symbol == pos.symbol,
        orElse: () => null);
    final priceCents = quote?.priceCents ?? pos.avgCostCentsPerUnit;
    final valueCents = (pos.qty * priceCents).round();
    final pnl = valueCents - pos.costCents;
    final up = pnl >= 0;
    final dayPct = quote?.dayChangePct ?? 0;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Springy(
        onTap: asset == null
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AssetScreen(asset: asset, state: market))),
        child: GlowCard(
          child: Row(
            children: [
              _symbolBadge(pos.symbol),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pos.symbol,
                        style: const TextStyle(
                            color: PolarisColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    Text(l10n.homeSharesCount(_trimQty(pos.qty)),
                        style: const TextStyle(
                            color: PolarisColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(CountUpText.formatCents(valueCents),
                      style: const TextStyle(
                          color: PolarisColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  Text(
                    '${up ? '+' : ''}${CountUpText.formatCents(pnl)}',
                    style: TextStyle(
                        color: up ? PolarisColors.gain : PolarisColors.loss,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 54,
                height: 30,
                child: PolarisSparkline(
                  values: _fakeSpark(priceCents, dayPct),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Мини-тренд для строки: пока нет истории под рукой — рисуем короткую
  // линию по дневному изменению (наглядно вверх/вниз). Реальные свечи —
  // на карточке актива.
  List<double> _fakeSpark(int priceCents, double dayPct) {
    final start = priceCents / (1 + dayPct / 100);
    return List.generate(8, (i) {
      final t = i / 7;
      return start + (priceCents - start) * t;
    });
  }

  Widget _symbolBadge(String symbol) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: PolarisColors.polar.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        symbol.length > 4 ? symbol.substring(0, 4) : symbol,
        style: const TextStyle(
            color: PolarisColors.polar,
            fontWeight: FontWeight.w800,
            fontSize: 11),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.rocket_launch_outlined,
                color: PolarisColors.polar, size: 56),
            const SizedBox(height: 16),
            Text(l10n.homeEmptyTitle,
                style: const TextStyle(
                    color: PolarisColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              l10n.homeEmptyBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: PolarisColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  String _trimQty(double q) {
    var s = q.toStringAsFixed(4);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }
}
