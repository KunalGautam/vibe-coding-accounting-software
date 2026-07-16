import 'package:share_plus/share_plus.dart';

import 'report_export_repository.dart';

abstract interface class ReportShareService {
  Future<ReportShareResult> shareExports(ReportExportResult exportResult);
}

class ReportShareResult {
  const ReportShareResult({required this.fileCount, required this.status});

  final int fileCount;
  final String status;
}

ReportShareService createDefaultReportShareService() {
  return SharePlusReportShareService();
}

class SharePlusReportShareService implements ReportShareService {
  @override
  Future<ReportShareResult> shareExports(
    ReportExportResult exportResult,
  ) async {
    if (exportResult.files.isEmpty) {
      throw const ReportExportUnavailableException(
        'No report CSV files are available to share.',
      );
    }

    final result = await SharePlus.instance.share(
      ShareParams(
        title: 'Accounting report CSV exports',
        subject: 'Accounting report CSV exports',
        text: 'Accounting report CSV exports',
        files: [
          for (final file in exportResult.files)
            XFile(file.path, name: file.fileName, mimeType: 'text/csv'),
        ],
      ),
    );

    return ReportShareResult(
      fileCount: exportResult.fileCount,
      status: result.status.name,
    );
  }
}

class MemoryReportShareService implements ReportShareService {
  final sharedResults = <ReportExportResult>[];

  @override
  Future<ReportShareResult> shareExports(
    ReportExportResult exportResult,
  ) async {
    sharedResults.add(exportResult);
    return ReportShareResult(
      fileCount: exportResult.fileCount,
      status: 'success',
    );
  }
}
