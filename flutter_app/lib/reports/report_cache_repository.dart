import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../api/accounting_api_client.dart';
import '../storage/offline_sqlite.dart';

Future<ReportCacheRepository> createDefaultReportCacheRepository() async {
  final database = await openOfflineDatabase(
    fileName: 'offline-reports.sqlite',
    version: 2,
    onCreate: (database, _) => createReportCacheTables(database),
    onUpgrade: (database, _, _) => createReportCacheTables(database),
  );
  return SqliteReportCacheRepository(database);
}

class ReportCacheSnapshot {
  const ReportCacheSnapshot({
    this.trialBalance,
    this.profitAndLoss,
    this.balanceSheet,
  });

  final TrialBalanceReport? trialBalance;
  final ProfitAndLossReport? profitAndLoss;
  final BalanceSheetReport? balanceSheet;

  factory ReportCacheSnapshot.fromJson(Map<String, Object?> json) {
    return ReportCacheSnapshot(
      trialBalance: json['trial_balance'] is Map<String, Object?>
          ? TrialBalanceReport.fromJson(
              json['trial_balance']! as Map<String, Object?>,
            )
          : null,
      profitAndLoss: json['profit_and_loss'] is Map<String, Object?>
          ? ProfitAndLossReport.fromJson(
              json['profit_and_loss']! as Map<String, Object?>,
            )
          : null,
      balanceSheet: json['balance_sheet'] is Map<String, Object?>
          ? BalanceSheetReport.fromJson(
              json['balance_sheet']! as Map<String, Object?>,
            )
          : null,
    );
  }

  ReportCacheSnapshot copyWith({
    TrialBalanceReport? trialBalance,
    ProfitAndLossReport? profitAndLoss,
    BalanceSheetReport? balanceSheet,
  }) {
    return ReportCacheSnapshot(
      trialBalance: trialBalance ?? this.trialBalance,
      profitAndLoss: profitAndLoss ?? this.profitAndLoss,
      balanceSheet: balanceSheet ?? this.balanceSheet,
    );
  }

  Map<String, Object?> toJson() {
    return {
      if (trialBalance != null) 'trial_balance': trialBalance!.toJson(),
      if (profitAndLoss != null) 'profit_and_loss': profitAndLoss!.toJson(),
      if (balanceSheet != null) 'balance_sheet': balanceSheet!.toJson(),
    };
  }
}

abstract interface class ReportCacheRepository {
  Future<ReportCacheSnapshot> loadCached();

  Future<void> saveCached(ReportCacheSnapshot snapshot);
}

class MemoryReportCacheRepository implements ReportCacheRepository {
  MemoryReportCacheRepository([ReportCacheSnapshot? seed])
    : _snapshot = seed ?? const ReportCacheSnapshot();

  ReportCacheSnapshot _snapshot;

  @override
  Future<ReportCacheSnapshot> loadCached() async => _snapshot;

  @override
  Future<void> saveCached(ReportCacheSnapshot snapshot) async {
    _snapshot = snapshot;
  }
}

class FileReportCacheRepository implements ReportCacheRepository {
  const FileReportCacheRepository(this.file);

  final File file;

  @override
  Future<ReportCacheSnapshot> loadCached() async {
    if (!await file.exists()) {
      return const ReportCacheSnapshot();
    }
    final contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      return const ReportCacheSnapshot();
    }
    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Expected report cache JSON object');
    }
    return ReportCacheSnapshot.fromJson(decoded);
  }

  @override
  Future<void> saveCached(ReportCacheSnapshot snapshot) async {
    await file.parent.create(recursive: true);
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(jsonEncode(snapshot.toJson()), flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }
}

class SqliteReportCacheRepository implements ReportCacheRepository {
  const SqliteReportCacheRepository(this.database);

  final Database database;

  @override
  Future<ReportCacheSnapshot> loadCached() async {
    final trialBalanceRows = await database.query(
      'cached_trial_balance_report',
      limit: 1,
    );
    final trialBalanceDetailRows = await database.query(
      'cached_trial_balance_rows',
      orderBy: 'row_index ASC, account_code ASC, account_id ASC',
    );
    final profitAndLossRows = await database.query(
      'cached_profit_and_loss_report',
      limit: 1,
    );
    final profitAndLossDetailRows = await database.query(
      'cached_profit_and_loss_rows',
      orderBy: 'section ASC, row_index ASC, account_code ASC, account_id ASC',
    );
    final balanceSheetRows = await database.query(
      'cached_balance_sheet_report',
      limit: 1,
    );
    final balanceSheetDetailRows = await database.query(
      'cached_balance_sheet_rows',
      orderBy: 'section ASC, row_index ASC, account_code ASC, account_id ASC',
    );
    return ReportCacheSnapshot(
      trialBalance: trialBalanceRows.isEmpty
          ? null
          : _trialBalanceFromRows(
              trialBalanceRows.single,
              trialBalanceDetailRows,
            ),
      profitAndLoss: profitAndLossRows.isEmpty
          ? null
          : _profitAndLossFromRows(
              profitAndLossRows.single,
              profitAndLossDetailRows,
            ),
      balanceSheet: balanceSheetRows.isEmpty
          ? null
          : _balanceSheetFromRows(
              balanceSheetRows.single,
              balanceSheetDetailRows,
            ),
    );
  }

  @override
  Future<void> saveCached(ReportCacheSnapshot snapshot) async {
    await database.transaction((transaction) async {
      await transaction.delete('cached_trial_balance_report');
      await transaction.delete('cached_trial_balance_rows');
      await transaction.delete('cached_profit_and_loss_report');
      await transaction.delete('cached_profit_and_loss_rows');
      await transaction.delete('cached_balance_sheet_report');
      await transaction.delete('cached_balance_sheet_rows');

      final trialBalance = snapshot.trialBalance;
      if (trialBalance != null) {
        await transaction.insert(
          'cached_trial_balance_report',
          _trialBalanceToRow(trialBalance),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        for (var index = 0; index < trialBalance.rows.length; index += 1) {
          await transaction.insert(
            'cached_trial_balance_rows',
            _reportRowToRow(index, trialBalance.rows[index]),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      final profitAndLoss = snapshot.profitAndLoss;
      if (profitAndLoss != null) {
        await transaction.insert(
          'cached_profit_and_loss_report',
          _profitAndLossToRow(profitAndLoss),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await _insertSectionRows(
          transaction,
          'cached_profit_and_loss_rows',
          'income',
          profitAndLoss.incomeRows,
        );
        await _insertSectionRows(
          transaction,
          'cached_profit_and_loss_rows',
          'expense',
          profitAndLoss.expenseRows,
        );
      }

      final balanceSheet = snapshot.balanceSheet;
      if (balanceSheet != null) {
        await transaction.insert(
          'cached_balance_sheet_report',
          _balanceSheetToRow(balanceSheet),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await _insertSectionRows(
          transaction,
          'cached_balance_sheet_rows',
          'asset',
          balanceSheet.assetRows,
        );
        await _insertSectionRows(
          transaction,
          'cached_balance_sheet_rows',
          'liability',
          balanceSheet.liabilityRows,
        );
        await _insertSectionRows(
          transaction,
          'cached_balance_sheet_rows',
          'equity',
          balanceSheet.equityRows,
        );
      }
    });
  }
}

Future<void> createReportCacheTables(DatabaseExecutor database) async {
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_trial_balance_report (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  as_of_date TEXT NOT NULL,
  total_debit_minor INTEGER NOT NULL DEFAULT 0,
  total_credit_minor INTEGER NOT NULL DEFAULT 0,
  balanced INTEGER NOT NULL DEFAULT 0
)
''');
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_trial_balance_rows (
  row_index INTEGER NOT NULL,
  account_id TEXT NOT NULL,
  account_code TEXT NOT NULL DEFAULT '',
  account_name TEXT NOT NULL DEFAULT '',
  account_type TEXT NOT NULL DEFAULT '',
  debit_minor INTEGER NOT NULL DEFAULT 0,
  credit_minor INTEGER NOT NULL DEFAULT 0,
  balance_minor INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (row_index, account_id)
)
''');
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_profit_and_loss_report (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  from_date TEXT NOT NULL,
  to_date TEXT NOT NULL,
  total_income_minor INTEGER NOT NULL DEFAULT 0,
  total_expense_minor INTEGER NOT NULL DEFAULT 0,
  net_income_minor INTEGER NOT NULL DEFAULT 0
)
''');
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_profit_and_loss_rows (
  section TEXT NOT NULL,
  row_index INTEGER NOT NULL,
  account_id TEXT NOT NULL,
  account_code TEXT NOT NULL DEFAULT '',
  account_name TEXT NOT NULL DEFAULT '',
  account_type TEXT NOT NULL DEFAULT '',
  debit_minor INTEGER NOT NULL DEFAULT 0,
  credit_minor INTEGER NOT NULL DEFAULT 0,
  balance_minor INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (section, row_index, account_id)
)
''');
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_balance_sheet_report (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  as_of_date TEXT NOT NULL,
  total_assets_minor INTEGER NOT NULL DEFAULT 0,
  total_liabilities_minor INTEGER NOT NULL DEFAULT 0,
  total_equity_minor INTEGER NOT NULL DEFAULT 0,
  balanced INTEGER NOT NULL DEFAULT 0
)
''');
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_balance_sheet_rows (
  section TEXT NOT NULL,
  row_index INTEGER NOT NULL,
  account_id TEXT NOT NULL,
  account_code TEXT NOT NULL DEFAULT '',
  account_name TEXT NOT NULL DEFAULT '',
  account_type TEXT NOT NULL DEFAULT '',
  debit_minor INTEGER NOT NULL DEFAULT 0,
  credit_minor INTEGER NOT NULL DEFAULT 0,
  balance_minor INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (section, row_index, account_id)
)
''');
}

Map<String, Object?> _trialBalanceToRow(TrialBalanceReport report) {
  return {
    'id': 1,
    'as_of_date': _dateOnly(report.asOfDate),
    'total_debit_minor': report.totalDebitMinor,
    'total_credit_minor': report.totalCreditMinor,
    'balanced': report.balanced ? 1 : 0,
  };
}

Map<String, Object?> _reportRowToRow(int index, ReportRowSummary row) {
  return {
    'row_index': index,
    'account_id': row.accountId,
    'account_code': row.accountCode,
    'account_name': row.accountName,
    'account_type': row.accountType,
    'debit_minor': row.debitMinor,
    'credit_minor': row.creditMinor,
    'balance_minor': row.balanceMinor,
  };
}

Map<String, Object?> _sectionReportRowToRow(
  String section,
  int index,
  ReportRowSummary row,
) {
  return {'section': section, ..._reportRowToRow(index, row)};
}

Map<String, Object?> _profitAndLossToRow(ProfitAndLossReport report) {
  return {
    'id': 1,
    'from_date': _dateOnly(report.fromDate),
    'to_date': _dateOnly(report.toDate),
    'total_income_minor': report.totalIncomeMinor,
    'total_expense_minor': report.totalExpenseMinor,
    'net_income_minor': report.netIncomeMinor,
  };
}

Map<String, Object?> _balanceSheetToRow(BalanceSheetReport report) {
  return {
    'id': 1,
    'as_of_date': _dateOnly(report.asOfDate),
    'total_assets_minor': report.totalAssetsMinor,
    'total_liabilities_minor': report.totalLiabilitiesMinor,
    'total_equity_minor': report.totalEquityMinor,
    'balanced': report.balanced ? 1 : 0,
  };
}

Future<void> _insertSectionRows(
  DatabaseExecutor transaction,
  String table,
  String section,
  List<ReportRowSummary> rows,
) async {
  for (var index = 0; index < rows.length; index += 1) {
    await transaction.insert(
      table,
      _sectionReportRowToRow(section, index, rows[index]),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

TrialBalanceReport _trialBalanceFromRows(
  Map<String, Object?> report,
  List<Map<String, Object?>> rows,
) {
  return TrialBalanceReport(
    asOfDate: DateTime.parse(report['as_of_date']! as String),
    rows: rows.map(_reportRowFromRow).toList(growable: false),
    totalDebitMinor: report['total_debit_minor'] as int? ?? 0,
    totalCreditMinor: report['total_credit_minor'] as int? ?? 0,
    balanced: (report['balanced'] as int? ?? 0) == 1,
  );
}

ProfitAndLossReport _profitAndLossFromRows(
  Map<String, Object?> report,
  List<Map<String, Object?>> rows,
) {
  return ProfitAndLossReport(
    fromDate: DateTime.parse(report['from_date']! as String),
    toDate: DateTime.parse(report['to_date']! as String),
    incomeRows: _sectionRows(rows, 'income'),
    expenseRows: _sectionRows(rows, 'expense'),
    totalIncomeMinor: report['total_income_minor'] as int? ?? 0,
    totalExpenseMinor: report['total_expense_minor'] as int? ?? 0,
    netIncomeMinor: report['net_income_minor'] as int? ?? 0,
  );
}

BalanceSheetReport _balanceSheetFromRows(
  Map<String, Object?> report,
  List<Map<String, Object?>> rows,
) {
  return BalanceSheetReport(
    asOfDate: DateTime.parse(report['as_of_date']! as String),
    assetRows: _sectionRows(rows, 'asset'),
    liabilityRows: _sectionRows(rows, 'liability'),
    equityRows: _sectionRows(rows, 'equity'),
    totalAssetsMinor: report['total_assets_minor'] as int? ?? 0,
    totalLiabilitiesMinor: report['total_liabilities_minor'] as int? ?? 0,
    totalEquityMinor: report['total_equity_minor'] as int? ?? 0,
    balanced: (report['balanced'] as int? ?? 0) == 1,
  );
}

List<ReportRowSummary> _sectionRows(
  List<Map<String, Object?>> rows,
  String section,
) {
  return rows
      .where((row) => row['section'] == section)
      .map(_reportRowFromRow)
      .toList(growable: false);
}

ReportRowSummary _reportRowFromRow(Map<String, Object?> row) {
  return ReportRowSummary(
    accountId: row['account_id']! as String,
    accountCode: row['account_code'] as String? ?? '',
    accountName: row['account_name'] as String? ?? '',
    accountType: row['account_type'] as String? ?? '',
    debitMinor: row['debit_minor'] as int? ?? 0,
    creditMinor: row['credit_minor'] as int? ?? 0,
    balanceMinor: row['balance_minor'] as int? ?? 0,
  );
}

String _dateOnly(DateTime date) {
  final normalized = date.toUtc();
  final month = normalized.month.toString().padLeft(2, '0');
  final day = normalized.day.toString().padLeft(2, '0');
  return '${normalized.year}-$month-$day';
}
