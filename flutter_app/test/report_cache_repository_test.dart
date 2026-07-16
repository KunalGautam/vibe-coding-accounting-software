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

  test('memory report cache stores core reports', () async {
    final repository = MemoryReportCacheRepository();

    await repository.saveCached(
      ReportCacheSnapshot(
        trialBalance: trialBalance,
        profitAndLoss: profitAndLoss,
        balanceSheet: balanceSheet,
      ),
    );

    final cached = await repository.loadCached();
    expect(cached.trialBalance?.balanced, true);
    expect(cached.trialBalance?.rows.first.accountName, 'Cash');
    expect(cached.profitAndLoss?.netIncomeMinor, 350000);
    expect(cached.balanceSheet?.equityRows.single.accountCode, '3100');
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
      ),
    );

    final cached = await repository.loadCached();
    expect(cached.trialBalance?.totalDebitMinor, 125000);
    expect(cached.trialBalance?.rows.first.accountCode, '1000');
    expect(cached.profitAndLoss?.incomeRows.single.accountName, 'Sales');
    expect(cached.balanceSheet?.totalAssetsMinor, 350000);
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
  });

  test('snapshot copyWith preserves existing cached reports', () {
    final updated = ReportCacheSnapshot(
      trialBalance: trialBalance,
      profitAndLoss: profitAndLoss,
    ).copyWith(balanceSheet: balanceSheet);

    expect(updated.trialBalance?.balanced, true);
    expect(updated.profitAndLoss?.totalIncomeMinor, 500000);
    expect(updated.balanceSheet?.balanced, true);
  });
}
