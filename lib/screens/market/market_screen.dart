/// Экран «Рынки» (волна 1б): поиск, чипы тем, секции
/// Акции / ETF и облигации / Крипта / Валюты.
///
/// Состояние можно передать снаружи (тесты, DI) — иначе экран создаёт своё
/// и сам им владеет. Видимость экрана включает/выключает 30-секундный опрос
/// котировок в MarketState.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../services/lessons.dart';
import '../../state/market_state.dart';
import '../../theme/theme.dart';
import '../../widgets/fx/stars_background.dart';
import 'asset_screen.dart';
import 'market_style.dart';

class MarketScreen extends StatefulWidget {
  /// Внешнее состояние; null — экран создаёт и владеет своим.
  final MarketState? state;

  /// Активна ли вкладка сейчас. Экран живёт в IndexedStack и не
  /// размонтируется при переключении вкладок, поэтому опрос котировок
  /// включаем/выключаем по этому флагу, а не по mount/dispose.
  final bool active;

  /// Язык контента тем (ru/en/es). Отдельный параметр, чтобы тесты могли
  /// проверить любой язык, не поднимая локализацию всего приложения.
  final String contentLang;

  /// Откуда брать оформление тем. null — из ассетов приложения. В `flutter
  /// test` ассеты проекта не собираются и `rootBundle` их не отдаёт, поэтому
  /// тесты подставляют репозиторий с фейковым bundle (так же устроен
  /// LearnScreen).
  final LessonsRepo? themesRepo;

  const MarketScreen({
    super.key,
    this.state,
    this.active = true,
    this.contentLang = 'ru',
    this.themesRepo,
  });

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  late final MarketState _state;
  late final bool _ownsState;

  /// Оформление тем (эмодзи, цвет) по id. Сервер присылает только id и
  /// название, а красивое описание тем уже лежало в ассетах на трёх языках и
  /// никуда не выводилось — берём его отсюда. Пусто = чипы просто останутся
  /// такими, как были: экран от этого не зависит.
  Map<String, ThemeInfo> _look = const {};

  @override
  void initState() {
    super.initState();
    _state = widget.state ?? MarketState();
    _ownsState = widget.state == null;
    _state.init();
    _state.setVisible(widget.active);
    unawaited(_loadThemeLook());
  }

  Future<void> _loadThemeLook() async {
    try {
      final repo =
          widget.themesRepo ?? LessonsRepo(lang: () => widget.contentLang);
      final c = await repo.load();
      if (!mounted || c.themes.isEmpty) return;
      setState(() {
        _look = {for (final t in c.themes) t.id: t};
      });
    } catch (_) {
      // Оформление — украшение. Не смогли прочитать ассет — экран работает.
    }
  }

  @override
  void didUpdateWidget(MarketScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Переключили вкладку (Shell перестроил с новым active) — гасим/запускаем
    // опрос, иначе он крутился бы 24/7 в фоне поверх других вкладок.
    if (widget.active != oldWidget.active) _state.setVisible(widget.active);
  }

  @override
  void dispose() {
    _state.setVisible(false);
    if (_ownsState) _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Звёздное небо было только на Портфеле/Cosmo/Учёбе/Ещё — при переходе
    // на «Рынки» фон пропадал в плоский чёрный, и приложение «разваливалось»
    // на два разных вида. На широком экране небо уже нарисовано каркасом во
    // всю ширину окна, и этот виджет там сам становится прозрачным.
    return Scaffold(
      backgroundColor: PolarisColors.bg,
      body: StarsBackground(
        starCount: 70,
        intensity: 0.55,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _state,
            builder: (context, _) => _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final s = _state;
    final l10n = AppLocalizations.of(context);
    final booting = s.loading && s.assets.isEmpty;
    final sections = <(String, List<Asset>)>[
      (l10n.marketSectionStocks, s.stocks),
      (l10n.marketSectionEtfs, s.etfs),
      (l10n.marketSectionCrypto, s.cryptos),
      (l10n.marketSectionFiat, s.fiats),
    ];
    final nothingFound =
        !booting && sections.every((sec) => sec.$2.isEmpty);

    // Сквозные смещения секций — для ступенчатого появления строк.
    final offsets = <int>[];
    var acc = 0;
    for (final (_, assets) in sections) {
      offsets.add(acc);
      acc += assets.length;
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(s, l10n),
              _searchField(s, l10n),
              _themeChips(s, l10n),
            ],
          ),
        ),
        if (booting)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(
                  color: PolarisColors.polar, strokeWidth: 2.5),
            ),
          )
        else if (nothingFound)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _NothingFound(l10n: l10n),
          )
        else ...[
          for (final (sectionIndex, (title, assets)) in sections.indexed)
            if (assets.isNotEmpty) ...[
              SliverToBoxAdapter(child: _SectionHeader(title: title)),
              SliverList.builder(
                itemCount: assets.length,
                itemBuilder: (context, i) {
                  final a = assets[i];
                  // Сквозной индекс строки (через все секции) — ступенька
                  // появления не начинается заново в каждой секции.
                  final rowIndex = offsets[sectionIndex] + i;
                  return FadeSlideIn(
                    delayMs: math.min(300, rowIndex * 30),
                    child: _AssetRow(
                      asset: a,
                      quote: s.quoteOf(a.symbol),
                      onTap: () => _openAsset(a),
                    ),
                  );
                },
              ),
            ],
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ],
    );
  }

  void _openAsset(Asset asset) {
    Navigator.of(context)
        .push(polarisRoute(AssetScreen(asset: asset, state: _state)));
  }

  Widget _header(MarketState s, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.marketScreenTitle,
              style: const TextStyle(
                color: PolarisColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (s.offline) _OfflineBadge(l10n: l10n),
        ],
      ),
    );
  }

  Widget _searchField(MarketState s, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: TextField(
        onChanged: s.setQuery,
        style: const TextStyle(color: PolarisColors.textPrimary),
        cursorColor: PolarisColors.polar,
        decoration: InputDecoration(
          hintText: l10n.marketSearchHint,
          hintStyle: const TextStyle(color: PolarisColors.textFaint),
          prefixIcon:
              const Icon(Icons.search, color: PolarisColors.textSecondary),
          filled: true,
          fillColor: PolarisColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: PolarisColors.surfaceHigh),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
                color: PolarisColors.polar.withValues(alpha: 0.6)),
          ),
        ),
      ),
    );
  }

  Widget _themeChips(MarketState s, AppLocalizations l10n) {
    final themes = s.themes;
    if (themes.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _ThemeChip(
            label: l10n.marketThemeAll,
            selected: s.selectedThemeId == null,
            onTap: () => s.selectTheme(null),
          ),
          for (final t in themes)
            _ThemeChip(
              // Название с сервера первично: если тему добавят на бэкенде
              // раньше, чем в ассеты, чип всё равно подпишется правильно.
              label: t.title.isNotEmpty ? t.title : (_look[t.id]?.title ?? t.id),
              emoji: _look[t.id]?.emoji,
              accent: _look[t.id]?.accent,
              selected: s.selectedThemeId == t.id,
              onTap: () =>
                  s.selectTheme(s.selectedThemeId == t.id ? null : t.id),
            ),
        ],
      ),
    );
  }
}

class _OfflineBadge extends StatelessWidget {
  final AppLocalizations l10n;
  const _OfflineBadge({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: PolarisColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: PolarisColors.dividend.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined,
              size: 14, color: PolarisColors.dividend),
          const SizedBox(width: 5),
          Text(
            l10n.marketOfflineBadge,
            style: const TextStyle(
              color: PolarisColors.dividend,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Эмодзи и цвет темы из ассетов. null — чип рисуется как раньше, в
  /// «полярном» цвете: тема без оформления не должна выглядеть сломанной.
  final String? emoji;
  final Color? accent;

  const _ThemeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.emoji,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final hi = accent ?? PolarisColors.polar;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? hi.withValues(alpha: 0.18)
                : PolarisColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? hi : PolarisColors.surfaceHigh,
            ),
          ),
          child: Row(
            children: [
              if (emoji != null && emoji!.isNotEmpty) ...[
                Text(emoji!, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? hi : PolarisColors.textSecondary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 6),
      child: Text(
        title,
        style: const TextStyle(
          color: PolarisColors.textFaint,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _AssetRow extends StatelessWidget {
  final Asset asset;
  final Quote? quote;
  final VoidCallback onTap;

  const _AssetRow({
    required this.asset,
    required this.quote,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final q = quote;
    final pct = q?.dayChangePct;
    final eod = asset.freshness != QuoteFreshness.realtime;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: PolarisColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SymbolBadge(asset: asset),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: PolarisColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        assetTypeLabel(l10n, asset.type),
                        style: const TextStyle(
                          color: PolarisColors.textFaint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      q == null ? '—' : formatCents(q.priceCents),
                      style: const TextStyle(
                        color: PolarisColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (eod) ...[
                          EodTag(freshness: asset.freshness),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          pct == null ? '' : formatChangePct(pct),
                          style: TextStyle(
                            color: pct == null
                                ? PolarisColors.textFaint
                                : changeColor(pct),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NothingFound extends StatelessWidget {
  final AppLocalizations l10n;
  const _NothingFound({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 42, color: PolarisColors.textFaint),
          const SizedBox(height: 10),
          Text(
            l10n.marketNothingFoundTitle,
            style: const TextStyle(
              color: PolarisColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.marketNothingFoundBody,
            style:
                const TextStyle(color: PolarisColors.textFaint, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
