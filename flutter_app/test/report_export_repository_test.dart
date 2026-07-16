import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:accounting_app/reports/report_csv_exporter.dart';
import 'package:accounting_app/reports/report_export_repository.dart';

void main() {
  test(
    'file repository saves CSV exports to the configured directory',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'report-exports-',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      final repository = FileReportExportRepository(directory);

      final result = await repository.saveExports([
        const ReportCsvExport(
          fileName: 'trial_balance.csv',
          contents: 'account,balance\nCash,100\n',
          rowCount: 1,
        ),
        const ReportCsvExport(
          fileName: r'tax/summary.csv',
          contents: 'rate,net\nGST 18%,900\n',
          rowCount: 1,
        ),
      ]);

      expect(result.directoryPath, directory.path);
      expect(result.fileCount, 2);
      expect(result.files.last.fileName, 'tax_summary.csv');
      expect(
        await File('${directory.path}/trial_balance.csv').readAsString(),
        'account,balance\nCash,100\n',
      );
      expect(
        await File('${directory.path}/tax_summary.csv').readAsString(),
        'rate,net\nGST 18%,900\n',
      );
    },
  );

  test('memory repository records exports without filesystem access', () async {
    final repository = MemoryReportExportRepository();

    final result = await repository.saveExports([
      const ReportCsvExport(
        fileName: 'budgets.csv',
        contents: 'budget,total\nFY26,100\n',
        rowCount: 1,
      ),
    ]);

    expect(result.directoryPath, 'memory://report-exports');
    expect(result.files.single.path, 'memory://report-exports/budgets.csv');
    expect(repository.savedFiles['budgets.csv'], 'budget,total\nFY26,100\n');
  });
}
