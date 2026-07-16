import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../api/accounting_api_client.dart';
import '../storage/offline_sqlite.dart';

Future<ReportCacheRepository> createDefaultReportCacheRepository() async {
  final database = await openOfflineDatabase(
    fileName: 'offline-reports.sqlite',
    version: 5,
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
    this.cashFlow,
    this.arAging,
    this.apAging,
    this.taxLiability,
    this.taxSummary,
    this.budgets = const [],
    this.budgetVsActual,
  });

  final TrialBalanceReport? trialBalance;
  final ProfitAndLossReport? profitAndLoss;
  final BalanceSheetReport? balanceSheet;
  final CashFlowReport? cashFlow;
  final ARAgingReport? arAging;
  final APAgingReport? apAging;
  final TaxLiabilityReport? taxLiability;
  final TaxSummaryReport? taxSummary;
  final List<BudgetSummary> budgets;
  final BudgetVsActualReport? budgetVsActual;

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
      cashFlow: json['cash_flow'] is Map<String, Object?>
          ? CashFlowReport.fromJson(json['cash_flow']! as Map<String, Object?>)
          : null,
      arAging: json['ar_aging'] is Map<String, Object?>
          ? ARAgingReport.fromJson(json['ar_aging']! as Map<String, Object?>)
          : null,
      apAging: json['ap_aging'] is Map<String, Object?>
          ? APAgingReport.fromJson(json['ap_aging']! as Map<String, Object?>)
          : null,
      taxLiability: json['tax_liability'] is Map<String, Object?>
          ? TaxLiabilityReport.fromJson(
              json['tax_liability']! as Map<String, Object?>,
            )
          : null,
      taxSummary: json['tax_summary'] is Map<String, Object?>
          ? TaxSummaryReport.fromJson(
              json['tax_summary']! as Map<String, Object?>,
            )
          : null,
      budgets: (json['budgets'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .map(BudgetSummary.fromJson)
          .toList(growable: false),
      budgetVsActual: json['budget_vs_actual'] is Map<String, Object?>
          ? BudgetVsActualReport.fromJson(
              json['budget_vs_actual']! as Map<String, Object?>,
            )
          : null,
    );
  }

  ReportCacheSnapshot copyWith({
    TrialBalanceReport? trialBalance,
    ProfitAndLossReport? profitAndLoss,
    BalanceSheetReport? balanceSheet,
    CashFlowReport? cashFlow,
    ARAgingReport? arAging,
    APAgingReport? apAging,
    TaxLiabilityReport? taxLiability,
    TaxSummaryReport? taxSummary,
    List<BudgetSummary>? budgets,
    BudgetVsActualReport? budgetVsActual,
  }) {
    return ReportCacheSnapshot(
      trialBalance: trialBalance ?? this.trialBalance,
      profitAndLoss: profitAndLoss ?? this.profitAndLoss,
      balanceSheet: balanceSheet ?? this.balanceSheet,
      cashFlow: cashFlow ?? this.cashFlow,
      arAging: arAging ?? this.arAging,
      apAging: apAging ?? this.apAging,
      taxLiability: taxLiability ?? this.taxLiability,
      taxSummary: taxSummary ?? this.taxSummary,
      budgets: budgets ?? this.budgets,
      budgetVsActual: budgetVsActual ?? this.budgetVsActual,
    );
  }

  Map<String, Object?> toJson() {
    return {
      if (trialBalance != null) 'trial_balance': trialBalance!.toJson(),
      if (profitAndLoss != null) 'profit_and_loss': profitAndLoss!.toJson(),
      if (balanceSheet != null) 'balance_sheet': balanceSheet!.toJson(),
      if (cashFlow != null) 'cash_flow': cashFlow!.toJson(),
      if (arAging != null) 'ar_aging': arAging!.toJson(),
      if (apAging != null) 'ap_aging': apAging!.toJson(),
      if (taxLiability != null) 'tax_liability': taxLiability!.toJson(),
      if (taxSummary != null) 'tax_summary': taxSummary!.toJson(),
      if (budgets.isNotEmpty)
        'budgets': budgets
            .map((budget) => budget.toJson())
            .toList(growable: false),
      if (budgetVsActual != null) 'budget_vs_actual': budgetVsActual!.toJson(),
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
    final cashFlowRows = await database.query(
      'cached_cash_flow_report',
      limit: 1,
    );
    final cashFlowDetailRows = await database.query(
      'cached_cash_flow_rows',
      orderBy: 'row_index ASC, account_code ASC, account_id ASC',
    );
    final arAgingRows = await database.query(
      'cached_ar_aging_report',
      limit: 1,
    );
    final arAgingDetailRows = await database.query(
      'cached_ar_aging_rows',
      orderBy: 'row_index ASC, due_date ASC, invoice_number ASC',
    );
    final apAgingRows = await database.query(
      'cached_ap_aging_report',
      limit: 1,
    );
    final apAgingDetailRows = await database.query(
      'cached_ap_aging_rows',
      orderBy: 'row_index ASC, due_date ASC, bill_number ASC',
    );
    final taxLiabilityRows = await database.query(
      'cached_tax_liability_report',
      limit: 1,
    );
    final taxLiabilityDetailRows = await database.query(
      'cached_tax_liability_rows',
      orderBy: 'row_index ASC, name ASC, tax_rate_id ASC, tax_group_id ASC',
    );
    final taxSummaryRows = await database.query(
      'cached_tax_summary_report',
      limit: 1,
    );
    final taxSummaryDetailRows = await database.query(
      'cached_tax_summary_rows',
      orderBy: 'row_index ASC, name ASC, tax_rate_id ASC, tax_group_id ASC',
    );
    final budgetRows = await database.query(
      'cached_budgets',
      orderBy: 'row_index ASC, name ASC',
    );
    final budgetVsActualRows = await database.query(
      'cached_budget_vs_actual_report',
      limit: 1,
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
      cashFlow: cashFlowRows.isEmpty
          ? null
          : _cashFlowFromRows(cashFlowRows.single, cashFlowDetailRows),
      arAging: arAgingRows.isEmpty
          ? null
          : _arAgingFromRows(arAgingRows.single, arAgingDetailRows),
      apAging: apAgingRows.isEmpty
          ? null
          : _apAgingFromRows(apAgingRows.single, apAgingDetailRows),
      taxLiability: taxLiabilityRows.isEmpty
          ? null
          : _taxLiabilityFromRows(
              taxLiabilityRows.single,
              taxLiabilityDetailRows,
            ),
      taxSummary: taxSummaryRows.isEmpty
          ? null
          : _taxSummaryFromRows(taxSummaryRows.single, taxSummaryDetailRows),
      budgets: budgetRows.map(_budgetFromCacheRow).toList(growable: false),
      budgetVsActual: budgetVsActualRows.isEmpty
          ? null
          : _budgetVsActualFromCacheRow(budgetVsActualRows.single),
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
      await transaction.delete('cached_cash_flow_report');
      await transaction.delete('cached_cash_flow_rows');
      await transaction.delete('cached_ar_aging_report');
      await transaction.delete('cached_ar_aging_rows');
      await transaction.delete('cached_ap_aging_report');
      await transaction.delete('cached_ap_aging_rows');
      await transaction.delete('cached_tax_liability_report');
      await transaction.delete('cached_tax_liability_rows');
      await transaction.delete('cached_tax_summary_report');
      await transaction.delete('cached_tax_summary_rows');
      await transaction.delete('cached_budgets');
      await transaction.delete('cached_budget_vs_actual_report');

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

      final cashFlow = snapshot.cashFlow;
      if (cashFlow != null) {
        await transaction.insert(
          'cached_cash_flow_report',
          _cashFlowToRow(cashFlow),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        for (var index = 0; index < cashFlow.rows.length; index += 1) {
          await transaction.insert(
            'cached_cash_flow_rows',
            _cashFlowRowToRow(index, cashFlow.rows[index]),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      final arAging = snapshot.arAging;
      if (arAging != null) {
        await transaction.insert(
          'cached_ar_aging_report',
          _arAgingToRow(arAging),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        for (var index = 0; index < arAging.rows.length; index += 1) {
          await transaction.insert(
            'cached_ar_aging_rows',
            _arAgingRowToRow(index, arAging.rows[index]),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      final apAging = snapshot.apAging;
      if (apAging != null) {
        await transaction.insert(
          'cached_ap_aging_report',
          _apAgingToRow(apAging),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        for (var index = 0; index < apAging.rows.length; index += 1) {
          await transaction.insert(
            'cached_ap_aging_rows',
            _apAgingRowToRow(index, apAging.rows[index]),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      final taxLiability = snapshot.taxLiability;
      if (taxLiability != null) {
        await transaction.insert(
          'cached_tax_liability_report',
          _taxLiabilityToRow(taxLiability),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await _insertTaxRows(
          transaction,
          'cached_tax_liability_rows',
          taxLiability.rows,
        );
      }

      final taxSummary = snapshot.taxSummary;
      if (taxSummary != null) {
        await transaction.insert(
          'cached_tax_summary_report',
          _taxSummaryToRow(taxSummary),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await _insertTaxRows(
          transaction,
          'cached_tax_summary_rows',
          taxSummary.rows,
        );
      }

      for (var index = 0; index < snapshot.budgets.length; index += 1) {
        await transaction.insert(
          'cached_budgets',
          _budgetToCacheRow(index, snapshot.budgets[index]),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final budgetVsActual = snapshot.budgetVsActual;
      if (budgetVsActual != null) {
        await transaction.insert(
          'cached_budget_vs_actual_report',
          _budgetVsActualToCacheRow(budgetVsActual),
          conflictAlgorithm: ConflictAlgorithm.replace,
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
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_cash_flow_report (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  from_date TEXT NOT NULL,
  to_date TEXT NOT NULL,
  total_inflows_minor INTEGER NOT NULL DEFAULT 0,
  total_outflows_minor INTEGER NOT NULL DEFAULT 0,
  net_cash_flow_minor INTEGER NOT NULL DEFAULT 0,
  opening_cash_minor INTEGER NOT NULL DEFAULT 0,
  closing_cash_minor INTEGER NOT NULL DEFAULT 0,
  generated_from_subtypes TEXT NOT NULL DEFAULT '[]'
)
''');
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_cash_flow_rows (
  row_index INTEGER NOT NULL,
  account_id TEXT NOT NULL,
  account_code TEXT NOT NULL DEFAULT '',
  account_name TEXT NOT NULL DEFAULT '',
  source_module TEXT NOT NULL DEFAULT '',
  inflow_minor INTEGER NOT NULL DEFAULT 0,
  outflow_minor INTEGER NOT NULL DEFAULT 0,
  net_cash_flow_minor INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (row_index, account_id, source_module)
)
''');
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_ar_aging_report (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  as_of_date TEXT NOT NULL,
  total_current_minor INTEGER NOT NULL DEFAULT 0,
  total_one_to_thirty_minor INTEGER NOT NULL DEFAULT 0,
  total_thirty_one_to_sixty_minor INTEGER NOT NULL DEFAULT 0,
  total_sixty_one_to_ninety_minor INTEGER NOT NULL DEFAULT 0,
  total_over_ninety_minor INTEGER NOT NULL DEFAULT 0,
  total_outstanding_minor INTEGER NOT NULL DEFAULT 0
)
''');
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_ar_aging_rows (
  row_index INTEGER NOT NULL,
  customer_id TEXT NOT NULL,
  customer_name TEXT NOT NULL DEFAULT '',
  invoice_id TEXT NOT NULL,
  invoice_number TEXT NOT NULL DEFAULT '',
  due_date TEXT NOT NULL,
  days_overdue INTEGER NOT NULL DEFAULT 0,
  outstanding_minor INTEGER NOT NULL DEFAULT 0,
  current_minor INTEGER NOT NULL DEFAULT 0,
  one_to_thirty_minor INTEGER NOT NULL DEFAULT 0,
  thirty_one_to_sixty_minor INTEGER NOT NULL DEFAULT 0,
  sixty_one_to_ninety_minor INTEGER NOT NULL DEFAULT 0,
  over_ninety_minor INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (row_index, invoice_id)
)
''');
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_ap_aging_report (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  as_of_date TEXT NOT NULL,
  total_current_minor INTEGER NOT NULL DEFAULT 0,
  total_one_to_thirty_minor INTEGER NOT NULL DEFAULT 0,
  total_thirty_one_to_sixty_minor INTEGER NOT NULL DEFAULT 0,
  total_sixty_one_to_ninety_minor INTEGER NOT NULL DEFAULT 0,
  total_over_ninety_minor INTEGER NOT NULL DEFAULT 0,
  total_outstanding_minor INTEGER NOT NULL DEFAULT 0
)
''');
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_ap_aging_rows (
  row_index INTEGER NOT NULL,
  vendor_id TEXT NOT NULL,
  vendor_name TEXT NOT NULL DEFAULT '',
  bill_id TEXT NOT NULL,
  bill_number TEXT NOT NULL DEFAULT '',
  due_date TEXT NOT NULL,
  days_overdue INTEGER NOT NULL DEFAULT 0,
  outstanding_minor INTEGER NOT NULL DEFAULT 0,
  current_minor INTEGER NOT NULL DEFAULT 0,
  one_to_thirty_minor INTEGER NOT NULL DEFAULT 0,
  thirty_one_to_sixty_minor INTEGER NOT NULL DEFAULT 0,
  sixty_one_to_ninety_minor INTEGER NOT NULL DEFAULT 0,
  over_ninety_minor INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (row_index, bill_id)
)
''');
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_tax_liability_report (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  from_date TEXT NOT NULL,
  to_date TEXT NOT NULL,
  output_tax_minor INTEGER NOT NULL DEFAULT 0,
  input_tax_minor INTEGER NOT NULL DEFAULT 0,
  net_payable_minor INTEGER NOT NULL DEFAULT 0
)
''');
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_tax_liability_rows (
  row_index INTEGER NOT NULL,
  tax_rate_id TEXT NOT NULL DEFAULT '',
  tax_group_id TEXT NOT NULL DEFAULT '',
  name TEXT NOT NULL DEFAULT '',
  output_tax_minor INTEGER NOT NULL DEFAULT 0,
  input_tax_minor INTEGER NOT NULL DEFAULT 0,
  net_payable_minor INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (row_index, tax_rate_id, tax_group_id)
)
''');
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_tax_summary_report (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  from_date TEXT NOT NULL,
  to_date TEXT NOT NULL
)
''');
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_tax_summary_rows (
  row_index INTEGER NOT NULL,
  tax_rate_id TEXT NOT NULL DEFAULT '',
  tax_group_id TEXT NOT NULL DEFAULT '',
  name TEXT NOT NULL DEFAULT '',
  output_tax_minor INTEGER NOT NULL DEFAULT 0,
  input_tax_minor INTEGER NOT NULL DEFAULT 0,
  net_payable_minor INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (row_index, tax_rate_id, tax_group_id)
)
''');
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_budgets (
  row_index INTEGER NOT NULL,
  budget_id TEXT NOT NULL,
  name TEXT NOT NULL DEFAULT '',
  budget_json TEXT NOT NULL,
  PRIMARY KEY (row_index, budget_id)
)
''');
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_budget_vs_actual_report (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  budget_id TEXT NOT NULL,
  report_json TEXT NOT NULL
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

Map<String, Object?> _cashFlowToRow(CashFlowReport report) {
  return {
    'id': 1,
    'from_date': _dateOnly(report.fromDate),
    'to_date': _dateOnly(report.toDate),
    'total_inflows_minor': report.totalInflowsMinor,
    'total_outflows_minor': report.totalOutflowsMinor,
    'net_cash_flow_minor': report.netCashFlowMinor,
    'opening_cash_minor': report.openingCashMinor,
    'closing_cash_minor': report.closingCashMinor,
    'generated_from_subtypes': jsonEncode(report.generatedFromSubtypes),
  };
}

Map<String, Object?> _cashFlowRowToRow(int index, CashFlowRow row) {
  return {
    'row_index': index,
    'account_id': row.accountId,
    'account_code': row.accountCode,
    'account_name': row.accountName,
    'source_module': row.sourceModule,
    'inflow_minor': row.inflowMinor,
    'outflow_minor': row.outflowMinor,
    'net_cash_flow_minor': row.netCashFlowMinor,
  };
}

Map<String, Object?> _agingTotalsToRow({
  required DateTime asOfDate,
  required AgingBucketTotals totals,
}) {
  return {
    'id': 1,
    'as_of_date': _dateOnly(asOfDate),
    'total_current_minor': totals.currentMinor,
    'total_one_to_thirty_minor': totals.oneToThirtyMinor,
    'total_thirty_one_to_sixty_minor': totals.thirtyOneToSixtyMinor,
    'total_sixty_one_to_ninety_minor': totals.sixtyOneToNinetyMinor,
    'total_over_ninety_minor': totals.overNinetyMinor,
    'total_outstanding_minor': totals.outstandingMinor,
  };
}

Map<String, Object?> _arAgingToRow(ARAgingReport report) {
  return _agingTotalsToRow(asOfDate: report.asOfDate, totals: report.totals);
}

Map<String, Object?> _apAgingToRow(APAgingReport report) {
  return _agingTotalsToRow(asOfDate: report.asOfDate, totals: report.totals);
}

Map<String, Object?> _arAgingRowToRow(int index, ARAgingRow row) {
  return {
    'row_index': index,
    'customer_id': row.customerId,
    'customer_name': row.customerName,
    'invoice_id': row.invoiceId,
    'invoice_number': row.invoiceNumber,
    'due_date': _dateOnly(row.dueDate),
    'days_overdue': row.daysOverdue,
    'outstanding_minor': row.outstandingMinor,
    'current_minor': row.currentMinor,
    'one_to_thirty_minor': row.oneToThirtyMinor,
    'thirty_one_to_sixty_minor': row.thirtyOneToSixtyMinor,
    'sixty_one_to_ninety_minor': row.sixtyOneToNinetyMinor,
    'over_ninety_minor': row.overNinetyMinor,
  };
}

Map<String, Object?> _apAgingRowToRow(int index, APAgingRow row) {
  return {
    'row_index': index,
    'vendor_id': row.vendorId,
    'vendor_name': row.vendorName,
    'bill_id': row.billId,
    'bill_number': row.billNumber,
    'due_date': _dateOnly(row.dueDate),
    'days_overdue': row.daysOverdue,
    'outstanding_minor': row.outstandingMinor,
    'current_minor': row.currentMinor,
    'one_to_thirty_minor': row.oneToThirtyMinor,
    'thirty_one_to_sixty_minor': row.thirtyOneToSixtyMinor,
    'sixty_one_to_ninety_minor': row.sixtyOneToNinetyMinor,
    'over_ninety_minor': row.overNinetyMinor,
  };
}

Map<String, Object?> _taxLiabilityToRow(TaxLiabilityReport report) {
  return {
    'id': 1,
    'from_date': _dateOnly(report.fromDate),
    'to_date': _dateOnly(report.toDate),
    'output_tax_minor': report.outputTaxMinor,
    'input_tax_minor': report.inputTaxMinor,
    'net_payable_minor': report.netPayableMinor,
  };
}

Map<String, Object?> _taxSummaryToRow(TaxSummaryReport report) {
  return {
    'id': 1,
    'from_date': _dateOnly(report.fromDate),
    'to_date': _dateOnly(report.toDate),
  };
}

Map<String, Object?> _taxReportRowToRow(int index, TaxReportRowSummary row) {
  return {
    'row_index': index,
    'tax_rate_id': row.taxRateId,
    'tax_group_id': row.taxGroupId,
    'name': row.name,
    'output_tax_minor': row.outputTaxMinor,
    'input_tax_minor': row.inputTaxMinor,
    'net_payable_minor': row.netPayableMinor,
  };
}

Future<void> _insertTaxRows(
  DatabaseExecutor transaction,
  String table,
  List<TaxReportRowSummary> rows,
) async {
  for (var index = 0; index < rows.length; index += 1) {
    await transaction.insert(
      table,
      _taxReportRowToRow(index, rows[index]),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

Map<String, Object?> _budgetToCacheRow(int index, BudgetSummary budget) {
  return {
    'row_index': index,
    'budget_id': budget.id,
    'name': budget.name,
    'budget_json': jsonEncode(budget.toJson()),
  };
}

BudgetSummary _budgetFromCacheRow(Map<String, Object?> row) {
  final decoded = jsonDecode(row['budget_json']! as String);
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Expected cached budget JSON object');
  }
  return BudgetSummary.fromJson(decoded);
}

Map<String, Object?> _budgetVsActualToCacheRow(BudgetVsActualReport report) {
  return {
    'id': 1,
    'budget_id': report.budgetId,
    'report_json': jsonEncode(report.toJson()),
  };
}

BudgetVsActualReport _budgetVsActualFromCacheRow(Map<String, Object?> row) {
  final decoded = jsonDecode(row['report_json']! as String);
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Expected cached budget-vs-actual JSON object');
  }
  return BudgetVsActualReport.fromJson(decoded);
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

CashFlowReport _cashFlowFromRows(
  Map<String, Object?> report,
  List<Map<String, Object?>> rows,
) {
  final decodedSubtypes = jsonDecode(
    report['generated_from_subtypes'] as String? ?? '[]',
  );
  return CashFlowReport(
    fromDate: DateTime.parse(report['from_date']! as String),
    toDate: DateTime.parse(report['to_date']! as String),
    rows: rows.map(_cashFlowRowFromRow).toList(growable: false),
    totalInflowsMinor: report['total_inflows_minor'] as int? ?? 0,
    totalOutflowsMinor: report['total_outflows_minor'] as int? ?? 0,
    netCashFlowMinor: report['net_cash_flow_minor'] as int? ?? 0,
    openingCashMinor: report['opening_cash_minor'] as int? ?? 0,
    closingCashMinor: report['closing_cash_minor'] as int? ?? 0,
    generatedFromSubtypes: decodedSubtypes is List
        ? decodedSubtypes.cast<String>().toList(growable: false)
        : const [],
  );
}

ARAgingReport _arAgingFromRows(
  Map<String, Object?> report,
  List<Map<String, Object?>> rows,
) {
  return ARAgingReport(
    asOfDate: DateTime.parse(report['as_of_date']! as String),
    rows: rows.map(_arAgingRowFromRow).toList(growable: false),
    totalCurrentMinor: report['total_current_minor'] as int? ?? 0,
    totalOneToThirtyMinor: report['total_one_to_thirty_minor'] as int? ?? 0,
    totalThirtyOneToSixtyMinor:
        report['total_thirty_one_to_sixty_minor'] as int? ?? 0,
    totalSixtyOneToNinetyMinor:
        report['total_sixty_one_to_ninety_minor'] as int? ?? 0,
    totalOverNinetyMinor: report['total_over_ninety_minor'] as int? ?? 0,
    totalOutstandingMinor: report['total_outstanding_minor'] as int? ?? 0,
  );
}

APAgingReport _apAgingFromRows(
  Map<String, Object?> report,
  List<Map<String, Object?>> rows,
) {
  return APAgingReport(
    asOfDate: DateTime.parse(report['as_of_date']! as String),
    rows: rows.map(_apAgingRowFromRow).toList(growable: false),
    totalCurrentMinor: report['total_current_minor'] as int? ?? 0,
    totalOneToThirtyMinor: report['total_one_to_thirty_minor'] as int? ?? 0,
    totalThirtyOneToSixtyMinor:
        report['total_thirty_one_to_sixty_minor'] as int? ?? 0,
    totalSixtyOneToNinetyMinor:
        report['total_sixty_one_to_ninety_minor'] as int? ?? 0,
    totalOverNinetyMinor: report['total_over_ninety_minor'] as int? ?? 0,
    totalOutstandingMinor: report['total_outstanding_minor'] as int? ?? 0,
  );
}

TaxLiabilityReport _taxLiabilityFromRows(
  Map<String, Object?> report,
  List<Map<String, Object?>> rows,
) {
  return TaxLiabilityReport(
    fromDate: DateTime.parse(report['from_date']! as String),
    toDate: DateTime.parse(report['to_date']! as String),
    outputTaxMinor: report['output_tax_minor'] as int? ?? 0,
    inputTaxMinor: report['input_tax_minor'] as int? ?? 0,
    netPayableMinor: report['net_payable_minor'] as int? ?? 0,
    rows: rows.map(_taxReportRowFromRow).toList(growable: false),
  );
}

TaxSummaryReport _taxSummaryFromRows(
  Map<String, Object?> report,
  List<Map<String, Object?>> rows,
) {
  return TaxSummaryReport(
    fromDate: DateTime.parse(report['from_date']! as String),
    toDate: DateTime.parse(report['to_date']! as String),
    rows: rows.map(_taxReportRowFromRow).toList(growable: false),
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

TaxReportRowSummary _taxReportRowFromRow(Map<String, Object?> row) {
  return TaxReportRowSummary(
    taxRateId: row['tax_rate_id'] as String? ?? '',
    taxGroupId: row['tax_group_id'] as String? ?? '',
    name: row['name'] as String? ?? '',
    outputTaxMinor: row['output_tax_minor'] as int? ?? 0,
    inputTaxMinor: row['input_tax_minor'] as int? ?? 0,
    netPayableMinor: row['net_payable_minor'] as int? ?? 0,
  );
}

CashFlowRow _cashFlowRowFromRow(Map<String, Object?> row) {
  return CashFlowRow(
    accountId: row['account_id']! as String,
    accountCode: row['account_code'] as String? ?? '',
    accountName: row['account_name'] as String? ?? '',
    sourceModule: row['source_module'] as String? ?? '',
    inflowMinor: row['inflow_minor'] as int? ?? 0,
    outflowMinor: row['outflow_minor'] as int? ?? 0,
    netCashFlowMinor: row['net_cash_flow_minor'] as int? ?? 0,
  );
}

ARAgingRow _arAgingRowFromRow(Map<String, Object?> row) {
  return ARAgingRow(
    customerId: row['customer_id']! as String,
    customerName: row['customer_name'] as String? ?? '',
    invoiceId: row['invoice_id']! as String,
    invoiceNumber: row['invoice_number'] as String? ?? '',
    dueDate: DateTime.parse(row['due_date']! as String),
    daysOverdue: row['days_overdue'] as int? ?? 0,
    outstandingMinor: row['outstanding_minor'] as int? ?? 0,
    currentMinor: row['current_minor'] as int? ?? 0,
    oneToThirtyMinor: row['one_to_thirty_minor'] as int? ?? 0,
    thirtyOneToSixtyMinor: row['thirty_one_to_sixty_minor'] as int? ?? 0,
    sixtyOneToNinetyMinor: row['sixty_one_to_ninety_minor'] as int? ?? 0,
    overNinetyMinor: row['over_ninety_minor'] as int? ?? 0,
  );
}

APAgingRow _apAgingRowFromRow(Map<String, Object?> row) {
  return APAgingRow(
    vendorId: row['vendor_id']! as String,
    vendorName: row['vendor_name'] as String? ?? '',
    billId: row['bill_id']! as String,
    billNumber: row['bill_number'] as String? ?? '',
    dueDate: DateTime.parse(row['due_date']! as String),
    daysOverdue: row['days_overdue'] as int? ?? 0,
    outstandingMinor: row['outstanding_minor'] as int? ?? 0,
    currentMinor: row['current_minor'] as int? ?? 0,
    oneToThirtyMinor: row['one_to_thirty_minor'] as int? ?? 0,
    thirtyOneToSixtyMinor: row['thirty_one_to_sixty_minor'] as int? ?? 0,
    sixtyOneToNinetyMinor: row['sixty_one_to_ninety_minor'] as int? ?? 0,
    overNinetyMinor: row['over_ninety_minor'] as int? ?? 0,
  );
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
