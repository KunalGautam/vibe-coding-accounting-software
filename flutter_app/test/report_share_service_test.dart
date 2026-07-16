import 'package:flutter_test/flutter_test.dart';
import 'package:accounting_app/reports/report_export_repository.dart';
import 'package:accounting_app/reports/report_share_service.dart';

void main() {
  test('memory share service records shared export results', () async {
    final service = MemoryReportShareService();
    const exportResult = ReportExportResult(
      directoryPath: 'memory://report-exports',
      files: [
        ReportExportedFile(
          fileName: 'trial_balance.csv',
          path: 'memory://report-exports/trial_balance.csv',
          bytes: 42,
        ),
      ],
    );

    final result = await service.shareExports(exportResult);

    expect(result.fileCount, 1);
    expect(result.status, 'success');
    expect(
      service.sharedResults.single.directoryPath,
      'memory://report-exports',
    );
  });
}
