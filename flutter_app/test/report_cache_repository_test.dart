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

  test('memory report cache stores trial balance', () async {
    final repository = MemoryReportCacheRepository();

    await repository.saveCached(
      ReportCacheSnapshot(trialBalance: trialBalance),
    );

    final cached = await repository.loadCached();
    expect(cached.trialBalance?.balanced, true);
    expect(cached.trialBalance?.rows.first.accountName, 'Cash');
  });

  test('file report cache persists trial balance', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ledger-report-cache-test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = FileReportCacheRepository(
      File('${directory.path}/reports.json'),
    );

    await repository.saveCached(
      ReportCacheSnapshot(trialBalance: trialBalance),
    );

    final cached = await repository.loadCached();
    expect(cached.trialBalance?.totalDebitMinor, 125000);
    expect(cached.trialBalance?.rows.first.accountCode, '1000');
  });

  test('sqlite report cache persists and replaces trial balance', () async {
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
      ReportCacheSnapshot(trialBalance: trialBalance),
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
  });
}
