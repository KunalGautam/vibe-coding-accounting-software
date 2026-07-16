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

  test('file repository can save CSV exports to Downloads', () async {
    final appDirectory = await Directory.systemTemp.createTemp(
      'report-app-exports-',
    );
    final downloadsDirectory = await Directory.systemTemp.createTemp(
      'report-downloads-',
    );
    addTearDown(() async {
      if (await appDirectory.exists()) {
        await appDirectory.delete(recursive: true);
      }
      if (await downloadsDirectory.exists()) {
        await downloadsDirectory.delete(recursive: true);
      }
    });
    final repository = FileReportExportRepository(
      appDirectory,
      downloadsDirectory: downloadsDirectory,
    );

    final result = await repository.saveExportsToDownloads([
      const ReportCsvExport(
        fileName: 'tax_summary.csv',
        contents: 'rate,net\nGST 18%,900\n',
        rowCount: 1,
      ),
    ]);

    expect(result.directoryPath, downloadsDirectory.path);
    expect(result.fileCount, 1);
    expect(
      await File('${downloadsDirectory.path}/tax_summary.csv').readAsString(),
      'rate,net\nGST 18%,900\n',
    );
  });

  test('file repository reports unavailable Downloads directory', () async {
    final appDirectory = await Directory.systemTemp.createTemp(
      'report-app-exports-',
    );
    addTearDown(() async {
      if (await appDirectory.exists()) {
        await appDirectory.delete(recursive: true);
      }
    });
    final repository = FileReportExportRepository(appDirectory);

    expect(
      () => repository.saveExportsToDownloads([
        const ReportCsvExport(
          fileName: 'budgets.csv',
          contents: 'budget,total\nFY26,100\n',
          rowCount: 1,
        ),
      ]),
      throwsA(isA<ReportExportUnavailableException>()),
    );
  });

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

  test('memory repository records Downloads exports', () async {
    final repository = MemoryReportExportRepository();

    final result = await repository.saveExportsToDownloads([
      const ReportCsvExport(
        fileName: 'budgets.csv',
        contents: 'budget,total\nFY26,100\n',
        rowCount: 1,
      ),
    ]);

    expect(result.directoryPath, 'memory://downloads/Accounting Reports');
    expect(
      result.files.single.path,
      'memory://downloads/Accounting Reports/budgets.csv',
    );
    expect(
      repository.downloadedFiles['budgets.csv'],
      'budget,total\nFY26,100\n',
    );
  });
}
