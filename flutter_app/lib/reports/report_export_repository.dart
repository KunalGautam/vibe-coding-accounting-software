import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'report_csv_exporter.dart';

abstract interface class ReportExportRepository {
  Future<ReportExportResult> saveExports(List<ReportCsvExport> exports);

  Future<ReportExportResult> saveExportsToDownloads(
    List<ReportCsvExport> exports,
  );
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
  final downloadsDirectory = await getDownloadsDirectory();
  return FileReportExportRepository(
    Directory(p.join(supportDirectory.path, 'report-exports')),
    downloadsDirectory: downloadsDirectory == null
        ? null
        : Directory(p.join(downloadsDirectory.path, 'Accounting Reports')),
  );
}

class FileReportExportRepository implements ReportExportRepository {
  const FileReportExportRepository(this.directory, {this.downloadsDirectory});

  final Directory directory;
  final Directory? downloadsDirectory;

  @override
  Future<ReportExportResult> saveExports(List<ReportCsvExport> exports) async {
    return _saveExports(exports, directory);
  }

  @override
  Future<ReportExportResult> saveExportsToDownloads(
    List<ReportCsvExport> exports,
  ) async {
    final target = downloadsDirectory;
    if (target == null) {
      throw const ReportExportUnavailableException(
        'Downloads directory is not available on this platform.',
      );
    }
    return _saveExports(exports, target);
  }

  Future<ReportExportResult> _saveExports(
    List<ReportCsvExport> exports,
    Directory targetDirectory,
  ) async {
    await targetDirectory.create(recursive: true);
    final files = <ReportExportedFile>[];
    for (final export in exports) {
      final fileName = _safeFileName(export.fileName);
      final file = File(p.join(targetDirectory.path, fileName));
      await file.writeAsString(export.contents, flush: true);
      files.add(
        ReportExportedFile(
          fileName: fileName,
          path: file.path,
          bytes: await file.length(),
        ),
      );
    }
    return ReportExportResult(
      directoryPath: targetDirectory.path,
      files: files,
    );
  }
}

class ReportExportUnavailableException implements Exception {
  const ReportExportUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MemoryReportExportRepository implements ReportExportRepository {
  MemoryReportExportRepository({
    this.directoryPath = 'memory://report-exports',
  });

  final String directoryPath;
  final Map<String, String> savedFiles = {};
  final Map<String, String> downloadedFiles = {};

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

  @override
  Future<ReportExportResult> saveExportsToDownloads(
    List<ReportCsvExport> exports,
  ) async {
    final files = <ReportExportedFile>[];
    const downloadsPath = 'memory://downloads/Accounting Reports';
    for (final export in exports) {
      final fileName = _safeFileName(export.fileName);
      downloadedFiles[fileName] = export.contents;
      files.add(
        ReportExportedFile(
          fileName: fileName,
          path: '$downloadsPath/$fileName',
          bytes: export.contents.length,
        ),
      );
    }
    return ReportExportResult(directoryPath: downloadsPath, files: files);
  }
}

String _safeFileName(String fileName) {
  return fileName.replaceAll(RegExp(r'[/\\\x00]'), '_');
}
