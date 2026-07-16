import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'report_csv_exporter.dart';

abstract interface class ReportExportRepository {
  Future<ReportExportResult> saveExports(List<ReportCsvExport> exports);
}

class ReportExportResult {
  const ReportExportResult({required this.directoryPath, required this.files});

  final String directoryPath;
  final List<ReportExportedFile> files;

  int get fileCount => files.length;
}

class ReportExportedFile {
  const ReportExportedFile({
    required this.fileName,
    required this.path,
    required this.bytes,
  });

  final String fileName;
  final String path;
  final int bytes;
}

Future<ReportExportRepository> createDefaultReportExportRepository() async {
  final supportDirectory = await getApplicationSupportDirectory();
  return FileReportExportRepository(
    Directory(p.join(supportDirectory.path, 'report-exports')),
  );
}

class FileReportExportRepository implements ReportExportRepository {
  const FileReportExportRepository(this.directory);

  final Directory directory;

  @override
  Future<ReportExportResult> saveExports(List<ReportCsvExport> exports) async {
    await directory.create(recursive: true);
    final files = <ReportExportedFile>[];
    for (final export in exports) {
      final fileName = _safeFileName(export.fileName);
      final file = File(p.join(directory.path, fileName));
      await file.writeAsString(export.contents, flush: true);
      files.add(
        ReportExportedFile(
          fileName: fileName,
          path: file.path,
          bytes: await file.length(),
        ),
      );
    }
    return ReportExportResult(directoryPath: directory.path, files: files);
  }
}

class MemoryReportExportRepository implements ReportExportRepository {
  MemoryReportExportRepository({
    this.directoryPath = 'memory://report-exports',
  });

  final String directoryPath;
  final Map<String, String> savedFiles = {};

  @override
  Future<ReportExportResult> saveExports(List<ReportCsvExport> exports) async {
    final files = <ReportExportedFile>[];
    for (final export in exports) {
      final fileName = _safeFileName(export.fileName);
      savedFiles[fileName] = export.contents;
      files.add(
        ReportExportedFile(
          fileName: fileName,
          path: '$directoryPath/$fileName',
          bytes: export.contents.length,
        ),
      );
    }
    return ReportExportResult(directoryPath: directoryPath, files: files);
  }
}

String _safeFileName(String fileName) {
  return fileName.replaceAll(RegExp(r'[/\\\x00]'), '_');
}
