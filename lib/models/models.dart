/// Модели Polaris. Деньги считаем в центах (int) — никаких копеек, потерянных
/// на двоичных дробях. Количество бумаг — double (дробные доли), округляется
/// до 8 знаков при записи.
library;

/// Класс актива в каталоге.
enum AssetType { stock, etf, bondEtf, crypto, fiat }

/// Откуда цена и насколько она живая.
///
/// `demo` — цена СМОДЕЛИРОВАНА (синтетический движок бэкенда, `freshness:"demo"`).
/// Это не рыночные данные, и пользователю это должно быть видно: показывать
/// такую цену как «конец дня» — обманывать. Неизвестное значение трактуем как
/// `demo` (наименее достоверное), а не как биржевое.
enum QuoteFreshness { realtime, delayed, endOfDay, demo }

class Asset {
  final String symbol; // AAPL, BTC, EUR
  final String name; // Apple Inc.
  final AssetType type;
  final String currency; // валюта котировки, обычно USD
  final List<String> themeIds; // темы-подборки, в которые входит
  final String? sector; // для акций
  final QuoteFreshness freshness;

  const Asset({
    required this.symbol,
    required this.name,
    required this.type,
    this.currency = 'USD',
    this.themeIds = const [],
    this.sector,
    this.freshness = QuoteFreshness.realtime,
  });

  factory Asset.fromJson(Map<String, dynamic> j) => Asset(
        symbol: j['symbol'] as String,
        name: (j['name'] as String?) ?? (j['symbol'] as String),
        type: AssetType.values.asNameMap()[j['type']] ?? AssetType.stock,
        currency: (j['currency'] as String?) ?? 'USD',
        themeIds: ((j['themes'] as List?) ?? const []).cast<String>(),
        sector: j['sector'] as String?,
        freshness: QuoteFreshness.values.asNameMap()[j['freshness']] ??
            QuoteFreshness.demo,
      );
}

class Quote {
  final String symbol;
  final int priceCents; // текущая цена за 1 штуку
  final int prevCloseCents; // закрытие прошлого дня (для дневного изменения)
  final DateTime ts;
  final bool marketOpen;

  const Quote({
    required this.symbol,
    required this.priceCents,
    required this.prevCloseCents,
    required this.ts,
    this.marketOpen = true,
  });

  double get dayChangePct =>
      prevCloseCents == 0 ? 0 : (priceCents - prevCloseCents) / prevCloseCents * 100;
}

/// Позиция в портфеле.
class Position {
  final String symbol;
  final double qty; // дробные доли
  final int costCents; // суммарно вложено в текущие qty (для средней цены)

  const Position({required this.symbol, required this.qty, required this.costCents});

  int get avgCostCentsPerUnit => qty <= 0 ? 0 : (costCents / qty).round();

  Map<String, dynamic> toJson() =>
      {'symbol': symbol, 'qty': qty, 'costCents': costCents};

  factory Position.fromJson(Map<String, dynamic> j) => Position(
        symbol: j['symbol'] as String,
        qty: (j['qty'] as num).toDouble(),
        costCents: (j['costCents'] as num).toInt(),
      );
}

enum TradeSide { buy, sell }

class Trade {
  final String id;
  final String symbol;
  final TradeSide side;
  final double qty;
  final int priceCents; // цена за штуку на момент сделки
  final int totalCents; // сколько ушло/пришло денег
  final DateTime ts;
  final int realizedPnlCents; // только для продаж

  const Trade({
    required this.id,
    required this.symbol,
    required this.side,
    required this.qty,
    required this.priceCents,
    required this.totalCents,
    required this.ts,
    this.realizedPnlCents = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'side': side.name,
        'qty': qty,
        'priceCents': priceCents,
        'totalCents': totalCents,
        'ts': ts.toIso8601String(),
        'realizedPnlCents': realizedPnlCents,
      };

  factory Trade.fromJson(Map<String, dynamic> j) => Trade(
        id: j['id'] as String,
        symbol: j['symbol'] as String,
        side: TradeSide.values.asNameMap()[j['side']] ?? TradeSide.buy,
        qty: (j['qty'] as num).toDouble(),
        priceCents: (j['priceCents'] as num).toInt(),
        totalCents: (j['totalCents'] as num).toInt(),
        ts: DateTime.tryParse(j['ts'] as String? ?? '') ?? DateTime.now(),
        realizedPnlCents: (j['realizedPnlCents'] as num?)?.toInt() ?? 0,
      );
}

/// Начисленный дивиденд (событие в истории).
class DividendPayout {
  final String symbol;
  final int perShareCents;
  final double qtyAtRecord;
  final int totalCents;
  final DateTime ts;

  const DividendPayout({
    required this.symbol,
    required this.perShareCents,
    required this.qtyAtRecord,
    required this.totalCents,
    required this.ts,
  });

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'perShareCents': perShareCents,
        'qtyAtRecord': qtyAtRecord,
        'totalCents': totalCents,
        'ts': ts.toIso8601String(),
      };

  factory DividendPayout.fromJson(Map<String, dynamic> j) => DividendPayout(
        symbol: j['symbol'] as String,
        perShareCents: (j['perShareCents'] as num).toInt(),
        qtyAtRecord: (j['qtyAtRecord'] as num).toDouble(),
        totalCents: (j['totalCents'] as num).toInt(),
        ts: DateTime.tryParse(j['ts'] as String? ?? '') ?? DateTime.now(),
      );
}
