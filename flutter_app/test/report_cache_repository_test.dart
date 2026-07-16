import 'dart:io';

import 'package:accounting_app/api/accounting_api_client.dart';
import 'package:accounting_app/reports/report_cache_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  final trialBalance = TrialBalanceReport(
    asOfDate: DateTime.utc(2026, 7, 31),
    rows: const [
      ReportRowSummary(
        accountId: 'acct-cash',
        accountCode: '1000',
        accountName: 'Cash',
        accountType: 'asset',
        debitMinor: 125000,
        creditMinor: 0,
        balanceMinor: 125000,
      ),
      ReportRowSummary(
        accountId: 'acct-equity',
        accountCode: '3000',
        accountName: 'Owner Equity',
        accountType: 'equity',
        debitMinor: 0,
        creditMinor: 125000,
        balanceMinor: -125000,
      ),
    ],
    totalDebitMinor: 125000,
    totalCreditMinor: 125000,
    balanced: true,
  );
  final profitAndLoss = ProfitAndLossReport(
    fromDate: DateTime.utc(2026, 4),
    toDate: DateTime.utc(2026, 7, 31),
    incomeRows: const [
      ReportRowSummary(
        accountId: 'acct-sales',
        accountCode: '4000',
        accountName: 'Sales',
        accountType: 'income',
        debitMinor: 0,
        creditMinor: 500000,
        balanceMinor: -500000,
      ),
    ],
    expenseRows: const [
      ReportRowSummary(
        accountId: 'acct-rent',
        accountCode: '5000',
        accountName: 'Rent',
        accountType: 'expense',
        debitMinor: 150000,
        creditMinor: 0,
        balanceMinor: 150000,
      ),
    ],
    totalIncomeMinor: 500000,
    totalExpenseMinor: 150000,
    netIncomeMinor: 350000,
  );
  final balanceSheet = BalanceSheetReport(
    asOfDate: DateTime.utc(2026, 7, 31),
    assetRows: const [
      ReportRowSummary(
        accountId: 'acct-bank',
        accountCode: '1010',
        accountName: 'Bank',
        accountType: 'asset',
        debitMinor: 350000,
        creditMinor: 0,
        balanceMinor: 350000,
      ),
    ],
    liabilityRows: const [],
    equityRows: const [
      ReportRowSummary(
        accountId: 'acct-retained',
        accountCode: '3100',
        accountName: 'Retained Earnings',
        accountType: 'equity',
        debitMinor: 0,
        creditMinor: 350000,
        balanceMinor: -350000,
      ),
    ],
    totalAssetsMinor: 350000,
    totalLiabilitiesMinor: 0,
    totalEquityMinor: 350000,
    balanced: true,
  );
  final cashFlow = CashFlowReport(
    fromDate: DateTime.utc(2026, 4),
    toDate: DateTime.utc(2026, 7, 31),
    rows: const [
      CashFlowRow(
        accountId: 'acct-bank',
        accountCode: '1010',
        accountName: 'Bank',
        sourceModule: 'invoice',
        inflowMinor: 500000,
        outflowMinor: 150000,
        netCashFlowMinor: 350000,
      ),
    ],
    totalInflowsMinor: 500000,
    totalOutflowsMinor: 150000,
    netCashFlowMinor: 350000,
    openingCashMinor: 250000,
    closingCashMinor: 600000,
    generatedFromSubtypes: const ['bank', 'cash'],
  );
  final arAging = ARAgingReport(
    asOfDate: DateTime.utc(2026, 7, 31),
    rows: [
      ARAgingRow(
        customerId: 'cust-1',
        customerName: 'Acme',
        invoiceId: 'inv-1',
        invoiceNumber: 'INV-001',
        dueDate: DateTime.utc(2026, 7, 1),
        daysOverdue: 30,
        outstandingMinor: 118000,
        currentMinor: 0,
        oneToThirtyMinor: 118000,
        thirtyOneToSixtyMinor: 0,
        sixtyOneToNinetyMinor: 0,
        overNinetyMinor: 0,
      ),
    ],
    totalCurrentMinor: 0,
    totalOneToThirtyMinor: 118000,
    totalThirtyOneToSixtyMinor: 0,
    totalSixtyOneToNinetyMinor: 0,
    totalOverNinetyMinor: 0,
    totalOutstandingMinor: 118000,
  );
  final apAging = APAgingReport(
    asOfDate: DateTime.utc(2026, 7, 31),
    rows: [
      APAgingRow(
        vendorId: 'vendor-1',
        vendorName: 'Office Supplies Co',
        billId: 'bill-1',
        billNumber: 'BILL-001',
        dueDate: DateTime.utc(2026, 6, 30),
        daysOverdue: 31,
        outstandingMinor: 59000,
        currentMinor: 0,
        oneToThirtyMinor: 0,
        thirtyOneToSixtyMinor: 59000,
        sixtyOneToNinetyMinor: 0,
        overNinetyMinor: 0,
      ),
    ],
    totalCurrentMinor: 0,
    totalOneToThirtyMinor: 0,
    totalThirtyOneToSixtyMinor: 59000,
    totalSixtyOneToNinetyMinor: 0,
    totalOverNinetyMinor: 0,
    totalOutstandingMinor: 59000,
  );
  final taxLiability = TaxLiabilityReport(
    fromDate: DateTime.utc(2026, 4),
    toDate: DateTime.utc(2026, 7, 31),
    outputTaxMinor: 90000,
    inputTaxMinor: 27000,
    netPayableMinor: 63000,
    rows: const [
      TaxReportRowSummary(
        taxRateId: 'gst-18',
        taxGroupId: '',
        name: 'GST 18%',
        outputTaxMinor: 90000,
        inputTaxMinor: 27000,
        netPayableMinor: 63000,
      ),
    ],
  );
  final taxSummary = TaxSummaryReport(
    fromDate: DateTime.utc(2026, 4),
    toDate: DateTime.utc(2026, 7, 31),
    rows: const [
      TaxReportRowSummary(
        taxRateId: 'gst-18',
        taxGroupId: 'gst-group-18',
        name: 'GST 18%',
        outputTaxMinor: 90000,
        inputTaxMinor: 27000,
        netPayableMinor: 63000,
      ),
    ],
  );

  test('memory report cache stores core reports', () async {
    final repository = MemoryReportCacheRepository();

    await repository.saveCached(
      ReportCacheSnapshot(
        trialBalance: trialBalance,
        profitAndLoss: profitAndLoss,
        balanceSheet: balanceSheet,
        cashFlow: cashFlow,
        arAging: arAging,
        apAging: apAging,
        taxLiability: taxLiability,
        taxSummary: taxSummary,
      ),
    );

    final cached = await repository.loadCached();
    expect(cached.trialBalance?.balanced, true);
    expect(cached.trialBalance?.rows.first.accountName, 'Cash');
    expect(cached.profitAndLoss?.netIncomeMinor, 350000);
    expect(cached.balanceSheet?.equityRows.single.accountCode, '3100');
    expect(cached.cashFlow?.closingCashMinor, 600000);
    expect(cached.arAging?.rows.single.invoiceNumber, 'INV-001');
    expect(cached.apAging?.rows.single.billNumber, 'BILL-001');
    expect(cached.taxLiability?.netPayableMinor, 63000);
    expect(cached.taxSummary?.rows.single.taxGroupId, 'gst-group-18');
  });

  test('file report cache persists core reports', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ledger-report-cache-test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = FileReportCacheRepository(
      File('${directory.path}/reports.json'),
    );

    await repository.saveCached(
      ReportCacheSnapshot(
        trialBalance: trialBalance,
        profitAndLoss: profitAndLoss,
        balanceSheet: balanceSheet,
        cashFlow: cashFlow,
        arAging: arAging,
        apAging: apAging,
        taxLiability: taxLiability,
        taxSummary: taxSummary,
      ),
    );

    final cached = await repository.loadCached();
    expect(cached.trialBalance?.totalDebitMinor, 125000);
    expect(cached.trialBalance?.rows.first.accountCode, '1000');
    expect(cached.profitAndLoss?.incomeRows.single.accountName, 'Sales');
    expect(cached.balanceSheet?.totalAssetsMinor, 350000);
    expect(cached.cashFlow?.generatedFromSubtypes, ['bank', 'cash']);
    expect(cached.arAging?.totalOutstandingMinor, 118000);
    expect(cached.apAging?.totalOutstandingMinor, 59000);
    expect(cached.taxLiability?.outputTaxMinor, 90000);
    expect(cached.taxSummary?.rows.single.name, 'GST 18%');
  });

  test('sqlite report cache persists and replaces core reports', () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) => createReportCacheTables(database),
      ),
    );
    addTearDown(database.close);
    final repository = SqliteReportCacheRepository(database);

    await repository.saveCached(
      ReportCacheSnapshot(
        trialBalance: trialBalance,
        profitAndLoss: profitAndLoss,
        balanceSheet: balanceSheet,
        cashFlow: cashFlow,
        arAging: arAging,
        apAging: apAging,
        taxLiability: taxLiability,
        taxSummary: taxSummary,
      ),
    );
    await repository.saveCached(
      ReportCacheSnapshot(
        trialBalance: TrialBalanceReport(
          asOfDate: DateTime.utc(2026, 8, 31),
          rows: const [
            ReportRowSummary(
              accountId: 'acct-bank',
              accountCode: '1010',
              accountName: 'Bank',
              accountType: 'asset',
              debitMinor: 250000,
              creditMinor: 0,
              balanceMinor: 250000,
            ),
          ],
          totalDebitMinor: 250000,
          totalCreditMinor: 250000,
          balanced: true,
        ),
      ),
    );

    final cached = await repository.loadCached();
    expect(cached.trialBalance?.asOfDate.year, 2026);
    expect(cached.trialBalance?.asOfDate.month, 8);
    expect(cached.trialBalance?.asOfDate.day, 31);
    expect(cached.trialBalance?.rows, hasLength(1));
    expect(cached.trialBalance?.rows.single.accountCode, '1010');
    expect(cached.profitAndLoss?.netIncomeMinor, isNull);
    expect(cached.balanceSheet?.totalAssetsMinor, isNull);
    expect(cached.cashFlow?.netCashFlowMinor, isNull);
    expect(cached.arAging?.totalOutstandingMinor, isNull);
    expect(cached.apAging?.totalOutstandingMinor, isNull);
    expect(cached.taxLiability?.netPayableMinor, isNull);
    expect(cached.taxSummary?.rows, isNull);
  });

  test('snapshot copyWith preserves existing cached reports', () {
    final updated = ReportCacheSnapshot(
      trialBalance: trialBalance,
      profitAndLoss: profitAndLoss,
      cashFlow: cashFlow,
    ).copyWith(balanceSheet: balanceSheet, arAging: arAging, apAging: apAging);

    expect(updated.trialBalance?.balanced, true);
    expect(updated.profitAndLoss?.totalIncomeMinor, 500000);
    expect(updated.balanceSheet?.balanced, true);
    expect(updated.cashFlow?.openingCashMinor, 250000);
    expect(updated.arAging?.totalOutstandingMinor, 118000);
    expect(updated.apAging?.totalOutstandingMinor, 59000);
    final withTax = updated.copyWith(
      taxLiability: taxLiability,
      taxSummary: taxSummary,
    );
    expect(withTax.taxLiability?.netPayableMinor, 63000);
    expect(withTax.taxSummary?.rows.single.taxRateId, 'gst-18');
  });
}
