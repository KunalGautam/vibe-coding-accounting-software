import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../api/accounting_api_client.dart';
import '../storage/offline_sqlite.dart';

Future<InvestmentCacheRepository>
createDefaultInvestmentCacheRepository() async {
  final database = await openOfflineDatabase(
    fileName: 'offline-investments.sqlite',
    version: 1,
    onCreate: (database, _) => createInvestmentCacheTables(database),
  );
  return SqliteInvestmentCacheRepository(database);
}

class InvestmentCacheSnapshot {
  const InvestmentCacheSnapshot({
    this.lots = const [],
    this.realizedGainsReport,
    this.prices = const [],
    this.valuationReport,
  });

  final List<InvestmentLotSummary> lots;
  final RealizedGainsReport? realizedGainsReport;
  final List<InvestmentPriceSummary> prices;
  final InvestmentValuationReport? valuationReport;

  factory InvestmentCacheSnapshot.fromJson(Map<String, Object?> json) {
    return InvestmentCacheSnapshot(
      lots: (json['lots'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .map(InvestmentLotSummary.fromJson)
          .toList(growable: false),
      realizedGainsReport: json['realized_gains_report'] is Map<String, Object?>
          ? RealizedGainsReport.fromJson(
              json['realized_gains_report']! as Map<String, Object?>,
            )
          : null,
      prices: (json['prices'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .map(InvestmentPriceSummary.fromJson)
          .toList(growable: false),
      valuationReport: json['valuation_report'] is Map<String, Object?>
          ? InvestmentValuationReport.fromJson(
              json['valuation_report']! as Map<String, Object?>,
            )
          : null,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'lots': lots.map((lot) => lot.toJson()).toList(growable: false),
      if (realizedGainsReport != null)
        'realized_gains_report': realizedGainsReport!.toJson(),
      'prices': prices.map((price) => price.toJson()).toList(growable: false),
      if (valuationReport != null)
        'valuation_report': valuationReport!.toJson(),
    };
  }

  InvestmentCacheSnapshot copyWith({
    List<InvestmentLotSummary>? lots,
    RealizedGainsReport? realizedGainsReport,
    List<InvestmentPriceSummary>? prices,
    InvestmentValuationReport? valuationReport,
  }) {
    return InvestmentCacheSnapshot(
      lots: lots ?? this.lots,
      realizedGainsReport: realizedGainsReport ?? this.realizedGainsReport,
      prices: prices ?? this.prices,
      valuationReport: valuationReport ?? this.valuationReport,
    );
  }
}

abstract interface class InvestmentCacheRepository {
  Future<InvestmentCacheSnapshot> loadCached();

  Future<void> saveCached(InvestmentCacheSnapshot snapshot);
}

class MemoryInvestmentCacheRepository implements InvestmentCacheRepository {
  MemoryInvestmentCacheRepository([InvestmentCacheSnapshot? seed])
    : _snapshot = seed ?? const InvestmentCacheSnapshot();

  InvestmentCacheSnapshot _snapshot;

  @override
  Future<InvestmentCacheSnapshot> loadCached() async => _snapshot;

  @override
  Future<void> saveCached(InvestmentCacheSnapshot snapshot) async {
    _snapshot = snapshot;
  }
}

class FileInvestmentCacheRepository implements InvestmentCacheRepository {
  const FileInvestmentCacheRepository(this.file);

  final File file;

  @override
  Future<InvestmentCacheSnapshot> loadCached() async {
    if (!await file.exists()) {
      return const InvestmentCacheSnapshot();
    }

    final contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      return const InvestmentCacheSnapshot();
    }

    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Expected investment cache JSON object');
    }

    return InvestmentCacheSnapshot.fromJson(decoded);
  }

  @override
  Future<void> saveCached(InvestmentCacheSnapshot snapshot) async {
    await file.parent.create(recursive: true);
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(jsonEncode(snapshot.toJson()), flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }
}

class SqliteInvestmentCacheRepository implements InvestmentCacheRepository {
  const SqliteInvestmentCacheRepository(this.database);

  final Database database;

  @override
  Future<InvestmentCacheSnapshot> loadCached() async {
    final lotRows = await database.query(
      'cached_investment_lots',
      orderBy: 'symbol ASC, acquisition_date ASC, id ASC',
    );
    final priceRows = await database.query(
      'cached_investment_prices',
      orderBy: 'symbol ASC, price_date DESC, id ASC',
    );
    return InvestmentCacheSnapshot(
      lots: lotRows.map(_lotFromRow).toList(growable: false),
      realizedGainsReport: await _loadRealizedGainsReport(),
      prices: priceRows.map(_priceFromRow).toList(growable: false),
      valuationReport: await _loadValuationReport(),
    );
  }

  @override
  Future<void> saveCached(InvestmentCacheSnapshot snapshot) async {
    await database.transaction((transaction) async {
      await transaction.delete('cached_investment_lots');
      await transaction.delete('cached_investment_prices');
      await transaction.delete('cached_investment_realized_report');
      await transaction.delete('cached_investment_dispositions');
      await transaction.delete('cached_investment_valuation_report');
      await transaction.delete('cached_investment_valuation_rows');

      for (final lot in snapshot.lots) {
        await transaction.insert(
          'cached_investment_lots',
          _lotToRow(lot),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final price in snapshot.prices) {
        await transaction.insert(
          'cached_investment_prices',
          _priceToRow(price),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      final realized = snapshot.realizedGainsReport;
      if (realized != null) {
        await transaction.insert(
          'cached_investment_realized_report',
          _realizedReportToRow(realized),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        for (var index = 0; index < realized.rows.length; index += 1) {
          await transaction.insert(
            'cached_investment_dispositions',
            _dispositionToRow(index, realized.rows[index]),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      final valuation = snapshot.valuationReport;
      if (valuation != null) {
        await transaction.insert(
          'cached_investment_valuation_report',
          _valuationReportToRow(valuation),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        for (var index = 0; index < valuation.rows.length; index += 1) {
          await transaction.insert(
            'cached_investment_valuation_rows',
            _valuationRowToRow(index, valuation.rows[index]),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  Future<RealizedGainsReport?> _loadRealizedGainsReport() async {
    final reportRows = await database.query(
      'cached_investment_realized_report',
      limit: 1,
    );
    if (reportRows.isEmpty) {
      return null;
    }
    final dispositionRows = await database.query(
      'cached_investment_dispositions',
      orderBy: 'row_index ASC, id ASC',
    );
    return _realizedReportFromRows(reportRows.single, dispositionRows);
  }

  Future<InvestmentValuationReport?> _loadValuationReport() async {
    final reportRows = await database.query(
      'cached_investment_valuation_report',
      limit: 1,
    );
    if (reportRows.isEmpty) {
      return null;
    }
    final valuationRows = await database.query(
      'cached_investment_valuation_rows',
      orderBy: 'row_index ASC, lot_id ASC',
    );
    return _valuationReportFromRows(reportRows.single, valuationRows);
  }
}

Future<void> createInvestmentCacheTables(DatabaseExecutor database) async {
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_investment_lots (
  id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  symbol TEXT NOT NULL,
  security_name TEXT NOT NULL DEFAULT '',
  acquisition_date TEXT NOT NULL,
  quantity_millis INTEGER NOT NULL DEFAULT 0,
  remaining_quantity_millis INTEGER NOT NULL DEFAULT 0,
  cost_basis_minor INTEGER NOT NULL DEFAULT 0,
  currency TEXT NOT NULL,
  cost_method TEXT NOT NULL,
  notes TEXT NOT NULL DEFAULT ''
)
''');
  await database.execute('''
CREATE INDEX IF NOT EXISTS idx_cached_investment_lots_symbol
ON cached_investment_lots (symbol, acquisition_date, id)
''');
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_investment_prices (
  id TEXT PRIMARY KEY,
  symbol TEXT NOT NULL,
  price_date TEXT NOT NULL,
  price_minor INTEGER NOT NULL DEFAULT 0,
  currency TEXT NOT NULL,
  source TEXT NOT NULL DEFAULT ''
)
''');
  await database.execute('''
CREATE INDEX IF NOT EXISTS idx_cached_investment_prices_symbol_date
ON cached_investment_prices (symbol, price_date, id)
''');
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_investment_realized_report (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  from_date TEXT NOT NULL,
  to_date TEXT NOT NULL,
  total_proceeds_minor INTEGER NOT NULL DEFAULT 0,
  total_cost_basis_minor INTEGER NOT NULL DEFAULT 0,
  total_gain_loss_minor INTEGER NOT NULL DEFAULT 0
)
''');
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_investment_dispositions (
  row_index INTEGER NOT NULL,
  id TEXT NOT NULL,
  investment_lot_id TEXT NOT NULL,
  sale_date TEXT NOT NULL,
  quantity_millis INTEGER NOT NULL DEFAULT 0,
  proceeds_minor INTEGER NOT NULL DEFAULT 0,
  allocated_cost_basis_minor INTEGER NOT NULL DEFAULT 0,
  realized_gain_loss_minor INTEGER NOT NULL DEFAULT 0,
  currency TEXT NOT NULL,
  notes TEXT NOT NULL DEFAULT '',
  PRIMARY KEY (row_index, id)
)
''');
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_investment_valuation_report (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  as_of_date TEXT NOT NULL,
  total_cost_basis_minor INTEGER NOT NULL DEFAULT 0,
  total_market_value_minor INTEGER NOT NULL DEFAULT 0,
  total_unrealized_gain_loss_minor INTEGER NOT NULL DEFAULT 0
)
''');
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_investment_valuation_rows (
  row_index INTEGER NOT NULL,
  lot_id TEXT NOT NULL,
  account_id TEXT NOT NULL,
  symbol TEXT NOT NULL,
  security_name TEXT NOT NULL DEFAULT '',
  acquisition_date TEXT NOT NULL,
  remaining_quantity_millis INTEGER NOT NULL DEFAULT 0,
  remaining_cost_basis_minor INTEGER NOT NULL DEFAULT 0,
  market_price_minor INTEGER NOT NULL DEFAULT 0,
  market_value_minor INTEGER NOT NULL DEFAULT 0,
  unrealized_gain_loss_minor INTEGER NOT NULL DEFAULT 0,
  currency TEXT NOT NULL,
  price_date TEXT NOT NULL,
  PRIMARY KEY (row_index, lot_id)
)
''');
}

Map<String, Object?> _lotToRow(InvestmentLotSummary lot) {
  return {
    'id': lot.id,
    'account_id': lot.accountId,
    'symbol': lot.symbol,
    'security_name': lot.securityName,
    'acquisition_date': lot.acquisitionDate.toIso8601String(),
    'quantity_millis': lot.quantityMillis,
    'remaining_quantity_millis': lot.remainingQuantityMillis,
    'cost_basis_minor': lot.costBasisMinor,
    'currency': lot.currency,
    'cost_method': lot.costMethod,
    'notes': lot.notes,
  };
}

InvestmentLotSummary _lotFromRow(Map<String, Object?> row) {
  return InvestmentLotSummary(
    id: row['id']! as String,
    accountId: row['account_id']! as String,
    symbol: row['symbol']! as String,
    securityName: row['security_name'] as String? ?? '',
    acquisitionDate: DateTime.parse(row['acquisition_date']! as String),
    quantityMillis: row['quantity_millis'] as int? ?? 0,
    remainingQuantityMillis: row['remaining_quantity_millis'] as int? ?? 0,
    costBasisMinor: row['cost_basis_minor'] as int? ?? 0,
    currency: row['currency'] as String? ?? 'INR',
    costMethod: row['cost_method'] as String? ?? 'specific_lot',
    notes: row['notes'] as String? ?? '',
  );
}

Map<String, Object?> _priceToRow(InvestmentPriceSummary price) {
  return {
    'id': price.id,
    'symbol': price.symbol,
    'price_date': price.priceDate.toIso8601String(),
    'price_minor': price.priceMinor,
    'currency': price.currency,
    'source': price.source,
  };
}

InvestmentPriceSummary _priceFromRow(Map<String, Object?> row) {
  return InvestmentPriceSummary(
    id: row['id']! as String,
    symbol: row['symbol']! as String,
    priceDate: DateTime.parse(row['price_date']! as String),
    priceMinor: row['price_minor'] as int? ?? 0,
    currency: row['currency'] as String? ?? 'INR',
    source: row['source'] as String? ?? '',
  );
}

Map<String, Object?> _realizedReportToRow(RealizedGainsReport report) {
  return {
    'id': 1,
    'from_date': report.fromDate.toIso8601String(),
    'to_date': report.toDate.toIso8601String(),
    'total_proceeds_minor': report.totalProceedsMinor,
    'total_cost_basis_minor': report.totalCostBasisMinor,
    'total_gain_loss_minor': report.totalGainLossMinor,
  };
}

Map<String, Object?> _dispositionToRow(
  int index,
  InvestmentDispositionSummary disposition,
) {
  return {
    'row_index': index,
    'id': disposition.id,
    'investment_lot_id': disposition.investmentLotId,
    'sale_date': disposition.saleDate.toIso8601String(),
    'quantity_millis': disposition.quantityMillis,
    'proceeds_minor': disposition.proceedsMinor,
    'allocated_cost_basis_minor': disposition.allocatedCostBasisMinor,
    'realized_gain_loss_minor': disposition.realizedGainLossMinor,
    'currency': disposition.currency,
    'notes': disposition.notes,
  };
}

RealizedGainsReport _realizedReportFromRows(
  Map<String, Object?> reportRow,
  List<Map<String, Object?>> dispositionRows,
) {
  return RealizedGainsReport(
    fromDate: DateTime.parse(reportRow['from_date']! as String),
    toDate: DateTime.parse(reportRow['to_date']! as String),
    rows: dispositionRows.map(_dispositionFromRow).toList(growable: false),
    totalProceedsMinor: reportRow['total_proceeds_minor'] as int? ?? 0,
    totalCostBasisMinor: reportRow['total_cost_basis_minor'] as int? ?? 0,
    totalGainLossMinor: reportRow['total_gain_loss_minor'] as int? ?? 0,
  );
}

InvestmentDispositionSummary _dispositionFromRow(Map<String, Object?> row) {
  return InvestmentDispositionSummary(
    id: row['id']! as String,
    investmentLotId: row['investment_lot_id']! as String,
    saleDate: DateTime.parse(row['sale_date']! as String),
    quantityMillis: row['quantity_millis'] as int? ?? 0,
    proceedsMinor: row['proceeds_minor'] as int? ?? 0,
    allocatedCostBasisMinor: row['allocated_cost_basis_minor'] as int? ?? 0,
    realizedGainLossMinor: row['realized_gain_loss_minor'] as int? ?? 0,
    currency: row['currency'] as String? ?? 'INR',
    notes: row['notes'] as String? ?? '',
  );
}

Map<String, Object?> _valuationReportToRow(InvestmentValuationReport report) {
  return {
    'id': 1,
    'as_of_date': report.asOfDate.toIso8601String(),
    'total_cost_basis_minor': report.totalCostBasisMinor,
    'total_market_value_minor': report.totalMarketValueMinor,
    'total_unrealized_gain_loss_minor': report.totalUnrealizedGainLossMinor,
  };
}

Map<String, Object?> _valuationRowToRow(int index, InvestmentValuationRow row) {
  return {
    'row_index': index,
    'lot_id': row.lotId,
    'account_id': row.accountId,
    'symbol': row.symbol,
    'security_name': row.securityName,
    'acquisition_date': row.acquisitionDate.toIso8601String(),
    'remaining_quantity_millis': row.remainingQuantityMillis,
    'remaining_cost_basis_minor': row.remainingCostBasisMinor,
    'market_price_minor': row.marketPriceMinor,
    'market_value_minor': row.marketValueMinor,
    'unrealized_gain_loss_minor': row.unrealizedGainLossMinor,
    'currency': row.currency,
    'price_date': row.priceDate.toIso8601String(),
  };
}

InvestmentValuationReport _valuationReportFromRows(
  Map<String, Object?> reportRow,
  List<Map<String, Object?>> valuationRows,
) {
  return InvestmentValuationReport(
    asOfDate: DateTime.parse(reportRow['as_of_date']! as String),
    rows: valuationRows.map(_valuationRowFromRow).toList(growable: false),
    totalCostBasisMinor: reportRow['total_cost_basis_minor'] as int? ?? 0,
    totalMarketValueMinor: reportRow['total_market_value_minor'] as int? ?? 0,
    totalUnrealizedGainLossMinor:
        reportRow['total_unrealized_gain_loss_minor'] as int? ?? 0,
  );
}

InvestmentValuationRow _valuationRowFromRow(Map<String, Object?> row) {
  return InvestmentValuationRow(
    lotId: row['lot_id']! as String,
    accountId: row['account_id']! as String,
    symbol: row['symbol']! as String,
    securityName: row['security_name'] as String? ?? '',
    acquisitionDate: DateTime.parse(row['acquisition_date']! as String),
    remainingQuantityMillis: row['remaining_quantity_millis'] as int? ?? 0,
    remainingCostBasisMinor: row['remaining_cost_basis_minor'] as int? ?? 0,
    marketPriceMinor: row['market_price_minor'] as int? ?? 0,
    marketValueMinor: row['market_value_minor'] as int? ?? 0,
    unrealizedGainLossMinor: row['unrealized_gain_loss_minor'] as int? ?? 0,
    currency: row['currency'] as String? ?? 'INR',
    priceDate: DateTime.parse(row['price_date']! as String),
  );
}
