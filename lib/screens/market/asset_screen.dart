/// Карточка актива вкладки «Рынки»: крупная цена, живой график с диапазонами
/// и режимом Линия/Свечи, объяснение «что это» простыми словами, метрики,
/// кнопки Купить/Продать (волна 2 — реальная сделка через PortfolioState).
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../services/api.dart' show CandleRange;
import '../../state/app_scope.dart';
import '../../state/market_state.dart';
import '../../theme/theme.dart';
import '../../widgets/chart/chart_models.dart' as cm;
import '../../widgets/chart/polaris_chart.dart';
import '../../widgets/fx/glow.dart';
import '../../widgets/fx/motion.dart';
import '../trade/trade_sheet.dart';
import 'market_style.dart';

class AssetScreen extends StatefulWidget {
  final Asset asset;

  /// Состояние вкладки «Рынки» — источник котировок и репозитория свечей.
  /// Экран его не создаёт и не владеет им (принадлежит MarketScreen).
  final MarketState state;

  const AssetScreen({super.key, required this.asset, required this.state});

  @override
  State<AssetScreen> createState() => _AssetScreenState();
}

class _AssetScreenState extends State<AssetScreen> {
  CandleRange _range = CandleRange.d1;
  ChartMode _mode = ChartMode.area;

  List<cm.Candle> _candles = const [];
  bool _loadingCandles = true;

  /// Свеча под пальцем при скраббинге; null — палец отпущен, шапка
  /// показывает актуальную котировку.
  cm.Candle? _scrubCandle;

  @override
  void initState() {
    super.initState();
    _loadCandles();
  }

  Future<void> _loadCandles() async {
    final symbol = widget.asset.symbol;
    final range = _range;
    setState(() => _loadingCandles = true);
    final raw = await widget.state.repo.candles(symbol, range);
    // Экран мог уйти, либо пользователь успел переключить диапазон/уйти
    // с этого символа, пока ответ шёл — не подставляем устаревшие данные.
    if (!mounted || _range != range || widget.asset.symbol != symbol) return;
    setState(() {
      _candles = raw
          .map((c) => cm.Candle(
                ts: c.t,
                openCents: c.o,
                highCents: c.h,
                lowCents: c.l,
                closeCents: c.c,
              ))
          .toList();
      _loadingCandles = false;
    });
  }

  void _setRange(CandleRange r) {
    if (r == _range) return;
    setState(() => _range = r);
    _loadCandles();
  }

  void _onScrub(cm.Candle? c) => setState(() => _scrubCandle = c);

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    return Scaffold(
      backgroundColor: PolarisColors.bg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.state,
          builder: (context, _) {
            final quote = widget.state.quoteOf(asset.symbol);
            final scrub = _scrubCandle;
            final priceCents = scrub?.closeCents ?? quote?.priceCents;
            return Column(
              children: [
                _topBar(context, asset),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      StaggerIn(
                        index: 0,
                        child: _priceHeader(asset, quote, priceCents, scrub),
                      ),
                      const SizedBox(height: 14),
                      StaggerIn(index: 1, child: _chartCard()),
                      const SizedBox(height: 10),
                      StaggerIn(index: 2, child: _rangeAndModeRow()),
                      const SizedBox(height: 22),
                      StaggerIn(index: 3, child: _whatIsThisCard(asset)),
                      const SizedBox(height: 16),
                      StaggerIn(
                        index: 4,
                        child: _metricsCard(asset, quote),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: _tradeBar(context, asset),
    );
  }

  // ---------------------------------------------------------------- шапка

  Widget _topBar(BuildContext context, Asset asset) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded,
                color: PolarisColors.textPrimary),
          ),
          SymbolBadge(asset: asset, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.symbol,
                  style: const TextStyle(
                    color: PolarisColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  asset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: PolarisColors.textFaint, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ цена крупно

  Widget _priceHeader(
      Asset asset, Quote? quote, int? priceCents, cm.Candle? scrub) {
    final l10n = AppLocalizations.of(context);
    final pct = quote?.dayChangePct;
    final eod = asset.freshness != QuoteFreshness.realtime;
    return GlowCard(
      glowColor: assetTypeColor(asset.type),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (quote?.marketOpen == true) ...[
                const PulseDot(color: PolarisColors.gain, size: 10),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: priceCents == null
                    ? const Text(
                        '—',
                        style: TextStyle(
                          color: PolarisColors.textPrimary,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    // Пока скраббим — цена меняется мгновенно, без докрутки
                    // (иначе каждое движение пальца плодит анимацию).
                    : CountUpText(
                        cents: priceCents,
                        animated: scrub == null,
                        style: const TextStyle(
                          color: PolarisColors.textPrimary,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (scrub != null)
                Text(
                  cm.formatCandleDate(scrub.ts),
                  style: const TextStyle(
                      color: PolarisColors.textSecondary, fontSize: 13),
                )
              else if (pct != null)
                Text(
                  formatChangePct(pct),
                  style: TextStyle(
                    color: changeColor(pct),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                Text(
                  l10n.assetQuoteUnavailable,
                  style:
                      const TextStyle(color: PolarisColors.textFaint, fontSize: 13),
                ),
              if (eod) ...[
                const SizedBox(width: 10),
                EodTag(freshness: asset.freshness),
                const SizedBox(width: 6),
                // Для demo-цены поясняем прямо, что она смоделирована,
                // а не «биржевая на конец дня».
                Flexible(
                  child: Text(
                    asset.freshness == QuoteFreshness.demo
                        ? l10n.marketDemoNotice
                        : l10n.assetPriceEndOfDay,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: asset.freshness == QuoteFreshness.demo
                          ? PolarisColors.dividend
                          : PolarisColors.textFaint,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- график

  Widget _chartCard() {
    return GlowCard(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
      child: Stack(
        alignment: Alignment.center,
        children: [
          PolarisChart(
            candles: _candles,
            mode: _mode,
            height: 240,
            onScrub: _onScrub,
            emptyLabel: AppLocalizations.of(context).assetNoChartData,
          ),
          if (_loadingCandles && _candles.isEmpty)
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                  color: PolarisColors.polar, strokeWidth: 2.4),
            ),
        ],
      ),
    );
  }

  Widget _rangeAndModeRow() {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in CandleRange.values)
                _Chip(
                  label: _rangeLabel(l10n, r),
                  selected: r == _range,
                  onTap: () => _setRange(r),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _ModeToggle(
          mode: _mode,
          onChanged: (m) => setState(() => _mode = m),
        ),
      ],
    );
  }

  /// Подпись кнопки диапазона на нужном языке — [CandleRange.label] в
  /// модели остаётся русской абвиатурой (значение для сервера/фикстур),
  /// здесь просто переводим для отображения.
  static String _rangeLabel(AppLocalizations l10n, CandleRange r) => switch (r) {
        CandleRange.d1 => l10n.assetRange1D,
        CandleRange.w1 => l10n.assetRange1W,
        CandleRange.m1 => l10n.assetRange1M,
        CandleRange.y1 => l10n.assetRange1Y,
      };

  // -------------------------------------------------------------- «что это»

  Widget _whatIsThisCard(Asset asset) {
    final l10n = AppLocalizations.of(context);
    return GlowCard(
      glowColor: PolarisColors.aurora,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  size: 18, color: PolarisColors.aurora.withValues(alpha: .9)),
              const SizedBox(width: 8),
              Text(
                l10n.assetWhatIsThisTitle,
                style: const TextStyle(
                  color: PolarisColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            assetPlainDescription(l10n, asset),
            style: const TextStyle(
              color: PolarisColors.textSecondary,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- метрики

  Widget _metricsCard(Asset asset, Quote? quote) {
    final l10n = AppLocalizations.of(context);
    final metrics = _buildMetrics(l10n, asset, quote, _candles);
    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.assetMetricsTitle,
            style: const TextStyle(
              color: PolarisColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < metrics.length; i++) ...[
            if (i > 0)
              const Divider(color: PolarisColors.surfaceHigh, height: 22),
            _MetricTile(metric: metrics[i]),
          ],
        ],
      ),
    );
  }

  List<_Metric> _buildMetrics(
      AppLocalizations l10n, Asset asset, Quote? quote, List<cm.Candle> candles) {
    final metrics = <_Metric>[];
    if (quote != null) {
      metrics.add(_Metric(
        label: l10n.assetMetricPrevClose,
        value: formatCents(quote.prevCloseCents),
        hint: l10n.assetMetricPrevCloseHint,
      ));
    }
    final range = candles.isEmpty ? null : cm.rangeOfCandles(candles);
    if (range != null && !range.isFlat) {
      metrics.add(_Metric(
        label: l10n.assetMetricRange,
        value: l10n.assetMetricRangeValue(
            formatCents(range.minCents.round()), formatCents(range.maxCents.round())),
        hint: l10n.assetMetricRangeHint,
      ));
    }
    metrics.add(_Metric(
      label: l10n.assetMetricAssetClass,
      value: assetTypeLabel(l10n, asset.type),
      hint: l10n.assetMetricAssetClassHint,
    ));
    metrics.add(_Metric(
      label: l10n.assetMetricCurrency,
      value: asset.currency,
      hint: l10n.assetMetricCurrencyHint,
    ));
    metrics.add(_Metric(
      label: l10n.assetMetricUpdate,
      value: asset.freshness == QuoteFreshness.realtime
          ? l10n.assetMetricUpdateRealtime
          : l10n.assetMetricUpdateEod,
      hint: asset.freshness == QuoteFreshness.realtime
          ? l10n.assetMetricUpdateHintRealtime
          : l10n.assetMetricUpdateHintEod,
    ));
    final sector = sectorHuman(l10n, asset.sector);
    if (sector != null) {
      metrics.add(_Metric(
        label: l10n.assetMetricSector,
        value: sector,
        hint: l10n.assetMetricSectorHint,
      ));
    }
    return metrics;
  }

  // --------------------------------------------------------------- торговля

  /// Текущая цена для сделки: живая котировка, иначе последняя цена графика.
  int? _currentPriceCents() =>
      widget.state.quoteOf(widget.asset.symbol)?.priceCents ??
      (_candles.isNotEmpty ? _candles.last.closeCents : null);

  bool _tradeSheetOpen = false; // защита от двойного тапа (две шторки подряд)

  Future<void> _openTrade(Asset asset, {required bool buy}) async {
    if (_tradeSheetOpen) return;
    _tradeSheetOpen = true;
    final scope = AppScope.read(context);
    final trade = await showTradeSheet(
      context,
      asset: asset,
      portfolio: scope.portfolio,
      buy: buy,
      priceCents: _currentPriceCents(),
    );
    _tradeSheetOpen = false; // шторка закрыта — снова можно открыть
    if (trade == null || !mounted) return;

    final l10n = AppLocalizations.of(context);
    final verb = buy ? l10n.tradeBoughtVerb : l10n.tradeSoldVerb;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.tradeDoneSnack(verb, asset.symbol)),
      behavior: SnackBarBehavior.floating,
    ));

    // Cosmo комментирует сделку (в рамках юр-границы: объясняет, не советует).
    // Тихо: если наставник недоступен — просто нет комментария.
    final quotes = <String, Quote>{
      for (final s in scope.portfolio.positions.keys)
        if (scope.market.quoteOf(s) != null) s: scope.market.quoteOf(s)!,
    };
    final comment = await scope.chat.noteTrade(
      trade.toJson(),
      scope.portfolio.aiContext(quotes),
    );
    if (comment != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.tradeCosmoComment(comment)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ));
    }
  }

  Widget _tradeBar(BuildContext context, Asset asset) {
    final l10n = AppLocalizations.of(context);
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomSafe),
      decoration: const BoxDecoration(
        color: PolarisColors.surface,
        border: Border(top: BorderSide(color: PolarisColors.surfaceHigh)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Springy(
              onTap: () => _openTrade(asset, buy: false),
              child: Container(
                // Явная высота обязательна: внутри bottomNavigationBar
                // Scaffold даёт ОГРАНИЧЕННЫЕ (но не тесные) constraints —
                // Container с alignment и без height/width в такой ситуации
                // разворачивается на всю доступную высоту (см. доку
                // Container: "alignment + bounded constraints => expand to
                // fit parent"). Без height кнопка съедала весь экран.
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PolarisColors.loss.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: PolarisColors.loss.withValues(alpha: 0.5)),
                ),
                child: Text(
                  l10n.assetSellAction,
                  style: const TextStyle(
                      color: PolarisColors.loss,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Springy(
              onTap: () => _openTrade(asset, buy: true),
              child: Container(
                height: 52, // см. комментарий у кнопки «Продать» выше
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PolarisColors.gain,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  l10n.assetBuyAction,
                  style: const TextStyle(
                      color: PolarisColors.bg,
                      fontWeight: FontWeight.w800,
                      fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Мелкие приватные виджеты экрана.
// --------------------------------------------------------------------------

/// Чип диапазона (1Д/1Н/1М/1Г) — тот же стиль, что чипы тем на «Рынках».
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? PolarisColors.polar.withValues(alpha: 0.18)
              : PolarisColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                selected ? PolarisColors.polar : PolarisColors.surfaceHigh,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                selected ? PolarisColors.polar : PolarisColors.textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Переключатель Линия/Свечи — два значка в одной таблетке.
class _ModeToggle extends StatelessWidget {
  final ChartMode mode;
  final ValueChanged<ChartMode> onChanged;

  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: PolarisColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PolarisColors.surfaceHigh),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeButton(Icons.show_chart_rounded, ChartMode.area, l10n.assetModeLine),
          _modeButton(
              Icons.candlestick_chart_outlined, ChartMode.candles, l10n.assetModeCandles),
        ],
      ),
    );
  }

  Widget _modeButton(IconData icon, ChartMode m, String tooltip) {
    final selected = mode == m;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => onChanged(m),
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected
                ? PolarisColors.polar.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            size: 18,
            color:
                selected ? PolarisColors.polar : PolarisColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Одна строка метрики: значение + пояснение простыми словами.
class _Metric {
  final String label;
  final String value;
  final String hint;

  const _Metric({required this.label, required this.value, required this.hint});
}

class _MetricTile extends StatelessWidget {
  final _Metric metric;

  const _MetricTile({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Flexible обязателен: на испанском («Actualización del precio» +
        // «Una vez al día (cierre de sesión)») и на русском («Диапазон за
        // период» + «$12,345.67 – $23,456.78») два голых Text в Row со
        // spaceBetween гарантированно срывались в жёлто-чёрный overflow
        // на узких экранах (360 dp и меньше).
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              flex: 4,
              child: Text(
                metric.label,
                maxLines: 2,
                style: const TextStyle(
                    color: PolarisColors.textSecondary, fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              flex: 5,
              child: Text(
                metric.value,
                maxLines: 2,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: PolarisColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          metric.hint,
          style: const TextStyle(
              color: PolarisColors.textFaint, fontSize: 11.5, height: 1.4),
        ),
      ],
    );
  }
}
