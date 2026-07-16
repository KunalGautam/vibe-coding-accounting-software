import '../api/accounting_api_client.dart';
import 'report_cache_repository.dart';

class ReportCsvExport {
  const ReportCsvExport({
    required this.fileName,
    required this.contents,
    required this.rowCount,
  });

  final String fileName;
  final String contents;
  final int rowCount;
}

List<ReportCsvExport> buildReportCsvExports(ReportCacheSnapshot snapshot) {
  return [
    if (snapshot.trialBalance != null)
      _trialBalanceExport(snapshot.trialBalance!),
    if (snapshot.profitAndLoss != null)
      _profitAndLossExport(snapshot.profitAndLoss!),
    if (snapshot.balanceSheet != null)
      _balanceSheetExport(snapshot.balanceSheet!),
    if (snapshot.cashFlow != null) _cashFlowExport(snapshot.cashFlow!),
    if (snapshot.arAging != null) _arAgingExport(snapshot.arAging!),
    if (snapshot.apAging != null) _apAgingExport(snapshot.apAging!),
    if (snapshot.taxLiability != null)
      _taxLiabilityExport(snapshot.taxLiability!),
    if (snapshot.taxSummary != null) _taxSummaryExport(snapshot.taxSummary!),
    if (snapshot.budgets.isNotEmpty) _budgetsExport(snapshot.budgets),
    if (snapshot.budgetVsActual != null)
      _budgetVsActualExport(snapshot.budgetVsActual!),
  ];
}

ReportCsvExport _trialBalanceExport(TrialBalanceReport report) {
  final rows = [
    [
      'as_of_date',
      'account_id',
      'account_code',
      'account_name',
      'account_type',
      'debit_minor',
      'credit_minor',
      'balance_minor',
    ],
    for (final row in report.rows)
      [
        _dateOnly(report.asOfDate),
        row.accountId,
        row.accountCode,
        row.accountName,
        row.accountType,
        row.debitMinor,
        row.creditMinor,
        row.balanceMinor,
      ],
  ];
  return _export('trial_balance_${_dateOnly(report.asOfDate)}.csv', rows);
}

ReportCsvExport _profitAndLossExport(ProfitAndLossReport report) {
  final rows = [
    [
      'section',
      'from_date',
      'to_date',
      'account_id',
      'account_code',
      'account_name',
      'account_type',
      'balance_minor',
    ],
    for (final row in report.incomeRows)
      _reportRow('income', report.fromDate, report.toDate, row),
    for (final row in report.expenseRows)
      _reportRow('expense', report.fromDate, report.toDate, row),
  ];
  return _export(
    'profit_and_loss_${_dateOnly(report.fromDate)}_${_dateOnly(report.toDate)}.csv',
    rows,
  );
}

ReportCsvExport _balanceSheetExport(BalanceSheetReport report) {
  final rows = [
    [
      'section',
      'as_of_date',
      'account_id',
      'account_code',
      'account_name',
      'account_type',
      'balance_minor',
    ],
    for (final row in report.assetRows)
      _balanceSheetRow('asset', report.asOfDate, row),
    for (final row in report.liabilityRows)
      _balanceSheetRow('liability', report.asOfDate, row),
    for (final row in report.equityRows)
      _balanceSheetRow('equity', report.asOfDate, row),
  ];
  return _export('balance_sheet_${_dateOnly(report.asOfDate)}.csv', rows);
}

ReportCsvExport _cashFlowExport(CashFlowReport report) {
  final rows = [
    [
      'from_date',
      'to_date',
      'account_id',
      'account_code',
      'account_name',
      'source_module',
      'inflow_minor',
      'outflow_minor',
      'net_cash_flow_minor',
    ],
    for (final row in report.rows)
      [
        _dateOnly(report.fromDate),
        _dateOnly(report.toDate),
        row.accountId,
        row.accountCode,
        row.accountName,
        row.sourceModule,
        row.inflowMinor,
        row.outflowMinor,
        row.netCashFlowMinor,
      ],
  ];
  return _export(
    'cash_flow_${_dateOnly(report.fromDate)}_${_dateOnly(report.toDate)}.csv',
    rows,
  );
}

ReportCsvExport _arAgingExport(ARAgingReport report) {
  final rows = [
    _agingHeader(
      'customer_id',
      'customer_name',
      'invoice_id',
      'invoice_number',
    ),
    for (final row in report.rows)
      [
        _dateOnly(report.asOfDate),
        row.customerId,
        row.customerName,
        row.invoiceId,
        row.invoiceNumber,
        _dateOnly(row.dueDate),
        row.daysOverdue,
        row.outstandingMinor,
        row.currentMinor,
        row.oneToThirtyMinor,
        row.thirtyOneToSixtyMinor,
        row.sixtyOneToNinetyMinor,
        row.overNinetyMinor,
      ],
  ];
  return _export('ar_aging_${_dateOnly(report.asOfDate)}.csv', rows);
}

ReportCsvExport _apAgingExport(APAgingReport report) {
  final rows = [
    _agingHeader('vendor_id', 'vendor_name', 'bill_id', 'bill_number'),
    for (final row in report.rows)
      [
        _dateOnly(report.asOfDate),
        row.vendorId,
        row.vendorName,
        row.billId,
        row.billNumber,
        _dateOnly(row.dueDate),
        row.daysOverdue,
        row.outstandingMinor,
        row.currentMinor,
        row.oneToThirtyMinor,
        row.thirtyOneToSixtyMinor,
        row.sixtyOneToNinetyMinor,
        row.overNinetyMinor,
      ],
  ];
  return _export('ap_aging_${_dateOnly(report.asOfDate)}.csv', rows);
}

ReportCsvExport _taxLiabilityExport(TaxLiabilityReport report) {
  return _export(
    'tax_liability_${_dateOnly(report.fromDate)}_${_dateOnly(report.toDate)}.csv',
    _taxRows(report.fromDate, report.toDate, report.rows),
  );
}

ReportCsvExport _taxSummaryExport(TaxSummaryReport report) {
  return _export(
    'tax_summary_${_dateOnly(report.fromDate)}_${_dateOnly(report.toDate)}.csv',
    _taxRows(report.fromDate, report.toDate, report.rows),
  );
}

ReportCsvExport _budgetsExport(List<BudgetSummary> budgets) {
  final rows = [
    [
      'budget_id',
      'name',
      'status',
      'start_date',
      'end_date',
      'line_id',
      'account_id',
      'period_start',
      'period_end',
      'amount_minor',
    ],
    for (final budget in budgets)
      for (final line in budget.lines)
        [
          budget.id,
          budget.name,
          budget.status,
          _dateOnly(budget.startDate),
          _dateOnly(budget.endDate),
          line.id,
          line.accountId,
          _dateOnly(line.periodStart),
          _dateOnly(line.periodEnd),
          line.amountMinor,
        ],
  ];
  return _export('budgets.csv', rows);
}

ReportCsvExport _budgetVsActualExport(BudgetVsActualReport report) {
  final rows = [
    [
      'budget_id',
      'account_id',
      'account_code',
      'account_name',
      'period_start',
      'period_end',
      'budget_minor',
      'actual_minor',
      'variance_minor',
      'variance_percent_basis',
    ],
    for (final row in report.rows)
      [
        report.budgetId,
        row.accountId,
        row.accountCode,
        row.accountName,
        _dateOnly(row.periodStart),
        _dateOnly(row.periodEnd),
        row.budgetMinor,
        row.actualMinor,
        row.varianceMinor,
        row.variancePercentBasis,
      ],
  ];
  return _export('budget_vs_actual_${report.budgetId}.csv', rows);
}

List<Object?> _reportRow(
  String section,
  DateTime fromDate,
  DateTime toDate,
  ReportRowSummary row,
) {
  return [
    section,
    _dateOnly(fromDate),
    _dateOnly(toDate),
    row.accountId,
    row.accountCode,
    row.accountName,
    row.accountType,
    row.balanceMinor,
  ];
}

List<Object?> _balanceSheetRow(
  String section,
  DateTime asOfDate,
  ReportRowSummary row,
) {
  return [
    section,
    _dateOnly(asOfDate),
    row.accountId,
    row.accountCode,
    row.accountName,
    row.accountType,
    row.balanceMinor,
  ];
}

List<Object?> _agingHeader(
  String partyId,
  String partyName,
  String documentId,
  String documentNumber,
) {
  return [
    'as_of_date',
    partyId,
    partyName,
    documentId,
    documentNumber,
    'due_date',
    'days_overdue',
    'outstanding_minor',
    'current_minor',
    'one_to_thirty_minor',
    'thirty_one_to_sixty_minor',
    'sixty_one_to_ninety_minor',
    'over_ninety_minor',
  ];
}

List<List<Object?>> _taxRows(
  DateTime fromDate,
  DateTime toDate,
  List<TaxReportRowSummary> rows,
) {
  return [
    [
      'from_date',
      'to_date',
      'tax_rate_id',
      'tax_group_id',
      'name',
      'output_tax_minor',
      'input_tax_minor',
      'net_payable_minor',
    ],
    for (final row in rows)
      [
        _dateOnly(fromDate),
        _dateOnly(toDate),
        row.taxRateId,
        row.taxGroupId,
        row.name,
        row.outputTaxMinor,
        row.inputTaxMinor,
        row.netPayableMinor,
      ],
  ];
}

ReportCsvExport _export(String fileName, List<List<Object?>> rows) {
  return ReportCsvExport(
    fileName: fileName,
    contents: _csv(rows),
    rowCount: rows.length > 1 ? rows.length - 1 : 0,
  );
}

String _csv(List<List<Object?>> rows) {
  return rows.map((row) => row.map(_csvCell).join(',')).join('\n');
}

String _csvCell(Object? value) {
  final text = value?.toString() ?? '';
  if (!text.contains(',') && !text.contains('"') && !text.contains('\n')) {
    return text;
  }
  return '"${text.replaceAll('"', '""')}"';
}

String _dateOnly(DateTime date) {
  final normalized = date.toUtc();
  final month = normalized.month.toString().padLeft(2, '0');
  final day = normalized.day.toString().padLeft(2, '0');
  return '${normalized.year}-$month-$day';
}
