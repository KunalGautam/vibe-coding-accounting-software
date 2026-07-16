import 'package:accounting_app/api/accounting_api_client.dart';
import 'package:accounting_app/reports/report_cache_repository.dart';
import 'package:accounting_app/reports/report_csv_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds CSV exports for cached report snapshots', () {
    final exports = buildReportCsvExports(
      ReportCacheSnapshot(
        trialBalance: TrialBalanceReport(
          asOfDate: DateTime.utc(2026, 7, 31),
          rows: const [
            ReportRowSummary(
              accountId: 'acct-cash',
              accountCode: '1000',
              accountName: 'Cash, Bank',
              accountType: 'asset',
              debitMinor: 125000,
              creditMinor: 0,
              balanceMinor: 125000,
            ),
          ],
          totalDebitMinor: 125000,
          totalCreditMinor: 125000,
          balanced: true,
        ),
        taxSummary: TaxSummaryReport(
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
        ),
        budgetVsActual: BudgetVsActualReport(
          budgetId: 'budget-1',
          rows: [
            BudgetVsActualReportRow(
              accountId: 'acct-rent',
              accountCode: '5000',
              accountName: 'Rent',
              periodStart: DateTime.utc(2026, 4),
              periodEnd: DateTime.utc(2026, 4, 30),
              budgetMinor: 150000,
              actualMinor: 125000,
              varianceMinor: 25000,
              variancePercentBasis: 1667,
            ),
          ],
        ),
      ),
    );

    expect(exports.map((export) => export.fileName), [
      'trial_balance_2026-07-31.csv',
      'tax_summary_2026-04-01_2026-07-31.csv',
      'budget_vs_actual_budget-1.csv',
    ]);
    expect(exports.first.rowCount, 1);
    expect(exports.first.contents, contains('"Cash, Bank"'));
    expect(exports.last.contents, contains('budget-1,acct-rent,5000,Rent'));
    expect(exports.last.contents, contains('150000,125000,25000,1667'));
  });
}
