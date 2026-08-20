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

  /// Та же бумага с другой свежестью цены. Нужна, когда приходит настоящая
  /// биржевая котировка и бумага перестаёт быть «демо».
  Asset withFreshness(QuoteFreshness value) => Asset(
        symbol: symbol,
        name: name,
        type: type,
        currency: currency,
        themeIds: themeIds,
        sector: sector,
        freshness: value,
      );

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
  /// МЕСТНЫЙ номер: «t1», «t2» — обычный счётчик внутри этого устройства.
  ///
  /// ⚠️ Между устройствами он ничего не значит: «сделка t1» на ноутбуке и
  /// «сделка t1» на телефоне — это РАЗНЫЕ сделки. Синхронизировать по нему
  /// нельзя: записи склеятся и часть пропадёт. На этом уже обожглись в Dayo.
  /// Для обмена есть [uid].
  final String id;

  /// ГЛОБАЛЬНЫЙ номер, одинаковый на всех устройствах и на складе.
  /// Пусто — сделка ещё не получила его (старая запись до синхронизации);
  /// такие раздаёт миграция при запуске, см. `SimEngine.vydatUid`.
  final String uid;

  final String symbol;
  final TradeSide side;
  final double qty;
  final int priceCents; // цена за штуку на момент сделки
  final int totalCents; // сколько ушло/пришло денег
  final DateTime ts;
  final int realizedPnlCents; // только для продаж

  /// Когда запись ПРАВИЛАСЬ последний раз. Именно это время решает спор двух
  /// копий на складе — не время отправки. Иначе телефон, неделю пролежавший
  /// в кармане, затёр бы своей старой копией свежую правку с ноутбука.
  /// null — сделка ни разу не правилась, тогда это момент сделки.
  final DateTime? changedAt;

  /// Учтена ли эта сделка в деньгах и позициях.
  ///
  /// ⚠️ false НЕ значит «сделки не было». Значит «запись в журнале есть, но
  /// применить её к деньгам нельзя» — например, продажа бумаги, которой в
  /// журнале никогда не покупали. Раньше такие записи просто ВЫБРАСЫВАЛИСЬ
  /// при слиянии двух устройств: ни в позициях, ни в истории, ни в файле на
  /// диске. Теперь запись остаётся на месте и её видно человеку.
  final bool primenena;

  const Trade({
    required this.id,
    this.uid = '',
    required this.symbol,
    required this.side,
    required this.qty,
    required this.priceCents,
    required this.totalCents,
    required this.ts,
    this.realizedPnlCents = 0,
    this.changedAt,
    this.primenena = true,
  });

  /// Время последней правки — то, по которому спорят копии.
  DateTime get changed => changedAt ?? ts;

  Trade copyWith({
    String? id,
    String? uid,
    int? realizedPnlCents,
    bool? primenena,
  }) =>
      Trade(
        id: id ?? this.id,
        uid: uid ?? this.uid,
        symbol: symbol,
        side: side,
        qty: qty,
        priceCents: priceCents,
        totalCents: totalCents,
        ts: ts,
        realizedPnlCents: realizedPnlCents ?? this.realizedPnlCents,
        changedAt: changedAt,
        primenena: primenena ?? this.primenena,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (uid.isNotEmpty) 'uid': uid,
        'symbol': symbol,
        'side': side.name,
        'qty': qty,
        'priceCents': priceCents,
        'totalCents': totalCents,
        'ts': ts.toIso8601String(),
        'realizedPnlCents': realizedPnlCents,
        if (changedAt != null) 'changedAt': changedAt!.toIso8601String(),
        // Пишем только «не применена»: у подавляющего большинства записей флаг
        // обычный, и раздувать файл незачем.
        if (!primenena) 'primenena': false,
      };

  factory Trade.fromJson(Map<String, dynamic> j) => Trade(
        id: j['id'] as String,
        uid: (j['uid'] as String?) ?? '',
        symbol: j['symbol'] as String,
        side: TradeSide.values.asNameMap()[j['side']] ?? TradeSide.buy,
        qty: (j['qty'] as num).toDouble(),
        priceCents: (j['priceCents'] as num).toInt(),
        totalCents: (j['totalCents'] as num).toInt(),
        ts: DateTime.tryParse(j['ts'] as String? ?? '') ?? DateTime.now(),
        realizedPnlCents: (j['realizedPnlCents'] as num?)?.toInt() ?? 0,
        changedAt: DateTime.tryParse(j['changedAt'] as String? ?? ''),
        primenena: j['primenena'] is bool ? j['primenena'] as bool : true,
      );
}

/// Начисленный дивиденд (событие в истории).
class DividendPayout {
  final String symbol;
  final int perShareCents;
  final double qtyAtRecord;
  final int totalCents;
  final DateTime ts;

  /// ГЛОБАЛЬНЫЙ номер выплаты. Для начислений из календаря он НАРОЧНО
  /// одинаков на всех устройствах — «dv_AAPL_2026-08-08». Телефон и ноутбук
  /// начислят один и тот же дивиденд каждый у себя, и на складе эти две записи
  /// обязаны слиться в одну. Иначе деньги в учебном портфеле удвоятся.
  final String uid;

  /// День отсечки (ex-date), «2026-08-08». Из него собирается [uid] и по нему
  /// же приложение помнит, что эту выплату уже начисляло.
  final String? exDay;

  /// Когда запись правилась. Для выплаты это момент начисления.
  final DateTime? changedAt;

  const DividendPayout({
    required this.symbol,
    required this.perShareCents,
    required this.qtyAtRecord,
    required this.totalCents,
    required this.ts,
    this.uid = '',
    this.exDay,
    this.changedAt,
  });

  DateTime get changed => changedAt ?? ts;

  DividendPayout copyWith({String? uid}) => DividendPayout(
        symbol: symbol,
        perShareCents: perShareCents,
        qtyAtRecord: qtyAtRecord,
        totalCents: totalCents,
        ts: ts,
        uid: uid ?? this.uid,
        exDay: exDay,
        changedAt: changedAt,
      );

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'perShareCents': perShareCents,
        'qtyAtRecord': qtyAtRecord,
        'totalCents': totalCents,
        'ts': ts.toIso8601String(),
        if (uid.isNotEmpty) 'uid': uid,
        if (exDay != null) 'exDay': exDay,
        if (changedAt != null) 'changedAt': changedAt!.toIso8601String(),
      };

  factory DividendPayout.fromJson(Map<String, dynamic> j) => DividendPayout(
        symbol: j['symbol'] as String,
        perShareCents: (j['perShareCents'] as num).toInt(),
        qtyAtRecord: (j['qtyAtRecord'] as num).toDouble(),
        totalCents: (j['totalCents'] as num).toInt(),
        ts: DateTime.tryParse(j['ts'] as String? ?? '') ?? DateTime.now(),
        uid: (j['uid'] as String?) ?? '',
        exDay: j['exDay'] as String?,
        changedAt: DateTime.tryParse(j['changedAt'] as String? ?? ''),
      );
}
