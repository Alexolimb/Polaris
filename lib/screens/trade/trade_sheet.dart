/// Шторка покупки/продажи — реальная торговля в симуляторе (волна 2).
/// Заменяет заглушку showTradeStubSheet. Считает всё через [PortfolioState],
/// цены — в центах. Для новичка: крупные суммы, быстрые кнопки долей, честный
/// расчёт «сколько получишь» до подтверждения.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../services/sim_engine.dart';
import '../../state/portfolio_state.dart';
import '../../theme/theme.dart';
import '../../widgets/fx/motion.dart';

/// Открыть шторку сделки. Возвращает совершённую [Trade] или null (отмена).
Future<Trade?> showTradeSheet(
  BuildContext context, {
  required Asset asset,
  required PortfolioState portfolio,
  required bool buy,
  required int? priceCents,
}) {
  if (priceCents == null || priceCents <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).tradeNoPriceSnack)));
    return Future.value(null);
  }
  return showModalBottomSheet<Trade>(
    context: context,
    isScrollControlled: true,
    backgroundColor: PolarisColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _TradeSheet(
          asset: asset, portfolio: portfolio, buy: buy, priceCents: priceCents),
    ),
  );
}

class _TradeSheet extends StatefulWidget {
  final Asset asset;
  final PortfolioState portfolio;
  final bool buy;
  final int priceCents;
  const _TradeSheet({
    required this.asset,
    required this.portfolio,
    required this.buy,
    required this.priceCents,
  });

  @override
  State<_TradeSheet> createState() => _TradeSheetState();
}

class _TradeSheetState extends State<_TradeSheet> {
  final _ctrl = TextEditingController();
  String? _error;
  bool _busy = false;
  // Флаг «продать всё»: ставится кнопкой 100%, снимается ручным вводом.
  // Нужен, чтобы продавать РОВНО pos.qty (8 знаков), а не округлённое до 6
  // знаков число из текстового поля — иначе продажа «всего» то не проходит
  // (qty чуть больше позиции), то оставляет микро-хвост.
  bool _sellAll = false;

  bool get _buy => widget.buy;
  Position? get _pos => widget.portfolio.positions[widget.asset.symbol];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Разбор числа из поля. Отдельный хелпер, потому что `double.tryParse`
  /// на длинной строке цифр возвращает не null, а `Infinity` — и дальше
  /// `(Infinity * 100).round()` бросает «Unsupported operation: Infinity or
  /// NaN toInt» ПРЯМО В build(), то есть пользователь видел красный экран
  /// ошибки вместо шторки. Нечисловое и бесконечное считаем нулём.
  double get _amount {
    final v = double.tryParse(_ctrl.text.replaceAll(',', '.'));
    if (v == null || !v.isFinite || v < 0) return 0;
    return v;
  }

  // Сумма для покупки (в центах) из поля ввода — вводят доллары.
  int get _spendCents {
    final cents = _amount * 100;
    // Верхняя граница — заведомо больше любого мыслимого портфеля, но
    // безопасно влезает в int: движок всё равно откажет по нехватке кэша.
    if (cents > 1e15) return 1000000000000000;
    return cents.round();
  }

  // Количество для продажи из поля ввода (доли штук).
  double get _sellQty => _amount;

  void _setBuyFraction(double f) {
    final cents = (widget.portfolio.cashCents * f).round();
    _ctrl.text = (cents / 100).toStringAsFixed(2);
    setState(() => _error = null);
  }

  void _setSellFraction(double f) {
    final qty = (_pos?.qty ?? 0) * f;
    _ctrl.text = _trimQty(qty);
    setState(() {
      _error = null;
      _sellAll = f >= 1.0; // «Всё» — продаём точное pos.qty, не текст из поля
    });
  }

  String _trimQty(double q) {
    var s = q.toStringAsFixed(6);
    if (s.contains('.')) s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return s;
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // При «продать всё» берём ТОЧНОЕ количество позиции (8 знаков), а не
      // округлённое значение из текстового поля — так позиция закрывается
      // без микро-хвоста и кнопка не блокируется на 7-8-м знаке.
      final sellAmount = _sellAll ? (_pos?.qty ?? _sellQty) : _sellQty;
      final Trade t = _buy
          ? await widget.portfolio.buy(widget.asset.symbol, _spendCents, widget.priceCents)
          : await widget.portfolio.sell(widget.asset.symbol, sellAmount, widget.priceCents);
      if (mounted) Navigator.of(context).pop(t);
    } on SimError catch (e) {
      if (!mounted) return; // шторку смахнули во время сделки — молча выходим
      setState(() {
        _busy = false;
        _error = _localizedSimError(AppLocalizations.of(context), e);
      });
    } on TradeNotSaved catch (_) {
      // Сделка НЕ прошла: портфель уже вернули в прежнее состояние. Говорим
      // об этом прямо, иначе человек решит, что «просто глюк», нажмёт ещё раз
      // и купит дважды (ровно этим кончалась прежняя «неизвестная ошибка»).
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = AppLocalizations.of(context).tradeNotSavedError;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = AppLocalizations.of(context).tradeGenericError;
      });
    }
  }

  /// Коды [SimError] стабильны (см. sim_engine.dart) — переводим по ним,
  /// а не по [SimError.message] (тот всегда русский, для логов/дебага).
  static String _localizedSimError(AppLocalizations l10n, SimError e) => switch (e.code) {
        'buy_amount_price_invalid' => l10n.simErrorBuyAmountPriceInvalid,
        'insufficient_cash' => l10n.simErrorInsufficientCash,
        'amount_too_small' => l10n.simErrorAmountTooSmall,
        'sell_qty_price_invalid' => l10n.simErrorSellQtyPriceInvalid,
        'no_position' => l10n.simErrorNoPosition,
        'sell_too_much' => l10n.simErrorSellTooMuch,
        'dividend_invalid' => l10n.simErrorDividendInvalid,
        _ => e.message,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sym = widget.asset.symbol;
    final priceStr = CountUpText.formatCents(widget.priceCents);

    // Предпросмотр результата.
    String preview;
    bool canConfirm;
    if (_buy) {
      final qty = _spendCents > 0 ? _spendCents / widget.priceCents : 0;
      preview = _spendCents > 0 ? l10n.tradePreviewBuy(_trimQty(qty.toDouble()), sym) : ' ';
      canConfirm = _spendCents > 0 && _spendCents <= widget.portfolio.cashCents;
    } else {
      final posQty = _pos?.qty ?? 0;
      final effectiveQty = _sellAll ? posQty : _sellQty;
      final proceeds = (effectiveQty * widget.priceCents).round();
      preview = effectiveQty > 0 ? l10n.tradePreviewSell(CountUpText.formatCents(proceeds)) : ' ';
      canConfirm = _sellAll
          ? posQty > 0
          : (_sellQty > 0 && _sellQty <= posQty + 1e-9);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: PolarisColors.textFaint,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _buy ? l10n.tradeBuyTitle(sym) : l10n.tradeSellTitle(sym),
              style: const TextStyle(
                  color: PolarisColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(l10n.tradePriceLabel(priceStr),
                style: const TextStyle(color: PolarisColors.textSecondary)),
            const SizedBox(height: 2),
            Text(
              _buy
                  ? l10n.tradeFreeCash(CountUpText.formatCents(widget.portfolio.cashCents))
                  : l10n.tradeYouHave(_trimQty(_pos?.qty ?? 0), sym),
              style: const TextStyle(color: PolarisColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                // Ограничитель длины — вторая линия обороны против Infinity
                // (первая — геттер _amount). 18 знаков хватает на любую
                // мыслимую сумму и количество долей.
                LengthLimitingTextInputFormatter(18),
              ],
              onChanged: (_) => setState(() {
        _error = null;
        _sellAll = false; // ручной ввод отменяет режим «продать всё»
      }),
              style: const TextStyle(
                  color: PolarisColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                prefixText: _buy ? '\$ ' : '',
                prefixStyle: const TextStyle(
                    color: PolarisColors.textSecondary, fontSize: 22),
                hintText: _buy ? l10n.tradeHintBuy : l10n.tradeHintSell,
                hintStyle: const TextStyle(color: PolarisColors.textFaint, fontSize: 16),
                filled: true,
                fillColor: PolarisColors.bg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _fractionChip(0.25, l10n),
                const SizedBox(width: 8),
                _fractionChip(0.5, l10n),
                const SizedBox(width: 8),
                _fractionChip(1.0, l10n),
              ],
            ),
            const SizedBox(height: 14),
            // Высота была жёстко 20 px, а тексты ошибок на ES/RU переносятся
            // на 2 строки («El importe y el precio deben ser mayores que
            // cero») → «BOTTOM OVERFLOWED» ровно в момент, когда пользователь
            // и так ошибся. Теперь блок растёт, но не прыгает.
            AnimatedSize(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    _error ?? preview,
                    style: TextStyle(
                        color: _error != null
                            ? PolarisColors.loss
                            : PolarisColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: (canConfirm && !_busy) ? _confirm : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _buy ? PolarisColors.gain : PolarisColors.loss,
                  foregroundColor: _buy ? PolarisColors.bg : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_buy ? l10n.tradeBuyAction : l10n.tradeSellAction,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(l10n.tradeDisclaimer,
                  style: const TextStyle(color: PolarisColors.textFaint, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fractionChip(double f, AppLocalizations l10n) {
    final label = f == 1.0 ? l10n.tradeAll : '${(f * 100).round()}%';
    return Expanded(
      child: GestureDetector(
        onTap: () => _buy ? _setBuyFraction(f) : _setSellFraction(f),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: PolarisColors.surfaceHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: PolarisColors.textPrimary, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
