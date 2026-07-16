import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../api/accounting_api_client.dart';
import '../storage/offline_sqlite.dart';

Future<AttachmentCacheRepository>
createDefaultAttachmentCacheRepository() async {
  final database = await openOfflineDatabase(
    fileName: 'offline-attachments.sqlite',
    version: 1,
    onCreate: (database, _) => createAttachmentCacheTables(database),
  );
  return SqliteAttachmentCacheRepository(database);
}

Future<AttachmentBinaryCacheRepository>
createDefaultAttachmentBinaryCacheRepository() async {
  final directory = await getApplicationSupportDirectory();
  return FileAttachmentBinaryCacheRepository(
    Directory('${directory.path}/attachment-binaries'),
  );
}

Future<AttachmentUploadManifestRepository>
createDefaultAttachmentUploadManifestRepository() async {
  final database = await openOfflineDatabase(
    fileName: 'offline-attachments.sqlite',
    version: 1,
    onCreate: (database, _) => createAttachmentUploadManifestTables(database),
  );
  return SqliteAttachmentUploadManifestRepository(database);
}

abstract interface class AttachmentCacheRepository {
  Future<List<AttachmentSummary>> loadCached();

  Future<void> saveCached(List<AttachmentSummary> attachments);
}

abstract interface class AttachmentBinaryCacheRepository {
  Future<void> saveDownloaded(String attachmentId, AttachmentDownload download);

  Future<AttachmentDownload?> loadDownloaded(String attachmentId);
}

abstract interface class AttachmentUploadManifestRepository {
  Future<List<AttachmentUploadManifestEntry>> loadPending();

  Future<void> savePending(List<AttachmentUploadManifestEntry> entries);

  Future<void> upsert(AttachmentUploadManifestEntry entry);
}

class AttachmentUploadManifestEntry {
  const AttachmentUploadManifestEntry({
    required this.operationId,
    required this.fileName,
    required this.localFilePath,
    required this.sizeBytes,
    required this.createdAt,
    this.contentType,
  });

  final String operationId;
  final String fileName;
  final String localFilePath;
  final int sizeBytes;
  final DateTime createdAt;
  final String? contentType;

  Map<String, Object?> toJson() {
    return {
      'operation_id': operationId,
      'file_name': fileName,
      'local_file_path': localFilePath,
      'size_bytes': sizeBytes,
      'created_at': createdAt.toIso8601String(),
      'content_type': contentType,
    }..removeWhere((_, value) => value == null);
  }

  factory AttachmentUploadManifestEntry.fromJson(Map<String, Object?> json) {
    return AttachmentUploadManifestEntry(
      operationId: json['operation_id']! as String,
      fileName: json['file_name']! as String,
      localFilePath: json['local_file_path']! as String,
      sizeBytes: json['size_bytes'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at']! as String),
      contentType: json['content_type'] as String?,
    );
  }
}

class MemoryAttachmentCacheRepository implements AttachmentCacheRepository {
  MemoryAttachmentCacheRepository([List<AttachmentSummary>? seed])
    : _attachments = [...?seed];

  final List<AttachmentSummary> _attachments;

  @override
  Future<List<AttachmentSummary>> loadCached() async {
    return List.unmodifiable(_attachments);
  }

  @override
  Future<void> saveCached(List<AttachmentSummary> attachments) async {
    _attachments
      ..clear()
      ..addAll(attachments);
  }
}

class FileAttachmentCacheRepository implements AttachmentCacheRepository {
  const FileAttachmentCacheRepository(this.file);

  final File file;

  @override
  Future<List<AttachmentSummary>> loadCached() async {
    if (!await file.exists()) {
      return [];
    }

    final contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      return [];
    }

    final decoded = jsonDecode(contents);
    if (decoded is! List) {
      throw const FormatException('Expected attachment cache JSON array');
    }

    return decoded
        .cast<Map<String, Object?>>()
        .map(AttachmentSummary.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> saveCached(List<AttachmentSummary> attachments) async {
    await file.parent.create(recursive: true);
    final tempFile = File('${file.path}.tmp');
    final encoded = jsonEncode(
      attachments
          .map((attachment) => attachment.toJson())
          .toList(growable: false),
    );

    await tempFile.writeAsString(encoded, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }
}

class SqliteAttachmentCacheRepository implements AttachmentCacheRepository {
  const SqliteAttachmentCacheRepository(this.database);

  final Database database;

  @override
  Future<List<AttachmentSummary>> loadCached() async {
    final rows = await database.query(
      'cached_attachments',
      orderBy: 'file_name ASC, id ASC',
    );
    return rows.map(_attachmentFromRow).toList(growable: false);
  }

  @override
  Future<void> saveCached(List<AttachmentSummary> attachments) async {
    await database.transaction((transaction) async {
      await transaction.delete('cached_attachments');
      for (final attachment in attachments) {
        await transaction.insert(
          'cached_attachments',
          _attachmentToRow(attachment),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}

class MemoryAttachmentBinaryCacheRepository
    implements AttachmentBinaryCacheRepository {
  final Map<String, AttachmentDownload> _downloads = {};

  @override
  Future<void> saveDownloaded(
    String attachmentId,
    AttachmentDownload download,
  ) async {
    _downloads[attachmentId] = download;
  }

  @override
  Future<AttachmentDownload?> loadDownloaded(String attachmentId) async {
    return _downloads[attachmentId];
  }
}

class MemoryAttachmentUploadManifestRepository
    implements AttachmentUploadManifestRepository {
  MemoryAttachmentUploadManifestRepository([
    List<AttachmentUploadManifestEntry>? seed,
  ]) : _entries = [...?seed];

  final List<AttachmentUploadManifestEntry> _entries;

  @override
  Future<List<AttachmentUploadManifestEntry>> loadPending() async {
    return List.unmodifiable(_entries);
  }

  @override
  Future<void> savePending(List<AttachmentUploadManifestEntry> entries) async {
    _entries
      ..clear()
      ..addAll(entries);
  }

  @override
  Future<void> upsert(AttachmentUploadManifestEntry entry) async {
    final existingIndex = _entries.indexWhere(
      (candidate) => candidate.operationId == entry.operationId,
    );
    if (existingIndex == -1) {
      _entries.add(entry);
      return;
    }
    _entries[existingIndex] = entry;
  }
}

class FileAttachmentBinaryCacheRepository
    implements AttachmentBinaryCacheRepository {
  const FileAttachmentBinaryCacheRepository(this.directory);

  final Directory directory;

  @override
  Future<void> saveDownloaded(
    String attachmentId,
    AttachmentDownload download,
  ) async {
    await directory.create(recursive: true);
    final tempFile = File('${_pathFor(attachmentId)}.tmp');
    await tempFile.writeAsBytes(download.bytes, flush: true);
    final destination = File(_pathFor(attachmentId));
    if (await destination.exists()) {
      await destination.delete();
    }
    await tempFile.rename(destination.path);

    final metadata = {
      'file_name': download.fileName,
      'content_type': download.contentType,
    }..removeWhere((_, value) => value == null);
    await File(
      '${_pathFor(attachmentId)}.json',
    ).writeAsString(jsonEncode(metadata), flush: true);
  }

  @override
  Future<AttachmentDownload?> loadDownloaded(String attachmentId) async {
    final file = File(_pathFor(attachmentId));
    if (!await file.exists()) {
      return null;
    }

    String? fileName;
    var contentType = 'application/octet-stream';
    final metadataFile = File('${_pathFor(attachmentId)}.json');
    if (await metadataFile.exists()) {
      final decoded = jsonDecode(await metadataFile.readAsString());
      if (decoded is Map<String, Object?>) {
        fileName = decoded['file_name'] as String?;
        contentType =
            decoded['content_type'] as String? ?? 'application/octet-stream';
      }
    }

    return AttachmentDownload(
      bytes: await file.readAsBytes(),
      contentType: contentType,
      fileName: fileName,
    );
  }

  String _pathFor(String attachmentId) {
    return '${directory.path}/$attachmentId.bin';
  }
}

class FileAttachmentUploadManifestRepository
    implements AttachmentUploadManifestRepository {
  const FileAttachmentUploadManifestRepository(this.file);

  final File file;

  @override
  Future<List<AttachmentUploadManifestEntry>> loadPending() async {
    if (!await file.exists()) {
      return [];
    }

    final contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      return [];
    }

    final decoded = jsonDecode(contents);
    if (decoded is! List) {
      throw const FormatException(
        'Expected attachment upload manifest JSON array',
      );
    }

    return decoded
        .cast<Map<String, Object?>>()
        .map(AttachmentUploadManifestEntry.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> savePending(List<AttachmentUploadManifestEntry> entries) async {
    await file.parent.create(recursive: true);
    final tempFile = File('${file.path}.tmp');
    final encoded = jsonEncode(
      entries.map((entry) => entry.toJson()).toList(growable: false),
    );

    await tempFile.writeAsString(encoded, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }

  @override
  Future<void> upsert(AttachmentUploadManifestEntry entry) async {
    final pending = await loadPending();
    final next = [...pending];
    final existingIndex = next.indexWhere(
      (candidate) => candidate.operationId == entry.operationId,
    );
    if (existingIndex == -1) {
      next.add(entry);
    } else {
      next[existingIndex] = entry;
    }
    await savePending(next);
  }
}

class SqliteAttachmentUploadManifestRepository
    implements AttachmentUploadManifestRepository {
  const SqliteAttachmentUploadManifestRepository(this.database);

  final Database database;

  @override
  Future<List<AttachmentUploadManifestEntry>> loadPending() async {
    final rows = await database.query(
      'queued_attachment_uploads',
      orderBy: 'created_at ASC, operation_id ASC',
    );
    return rows.map(_manifestEntryFromRow).toList(growable: false);
  }

  @override
  Future<void> savePending(List<AttachmentUploadManifestEntry> entries) async {
    await database.transaction((transaction) async {
      await transaction.delete('queued_attachment_uploads');
      for (final entry in entries) {
        await transaction.insert(
          'queued_attachment_uploads',
          _manifestEntryToRow(entry),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<void> upsert(AttachmentUploadManifestEntry entry) async {
    await database.insert(
      'queued_attachment_uploads',
      _manifestEntryToRow(entry),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

Future<void> createAttachmentUploadManifestTables(
  DatabaseExecutor database,
) async {
  await createAttachmentCacheTables(database);
  await database.execute('''
CREATE TABLE IF NOT EXISTS queued_attachment_uploads (
  operation_id TEXT PRIMARY KEY,
  file_name TEXT NOT NULL,
  local_file_path TEXT NOT NULL,
  size_bytes INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  content_type TEXT
)
''');
  await database.execute('''
CREATE INDEX IF NOT EXISTS idx_queued_attachment_uploads_created_at
ON queued_attachment_uploads (created_at, operation_id)
''');
}

Future<void> createAttachmentCacheTables(DatabaseExecutor database) async {
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_attachments (
  id TEXT PRIMARY KEY,
  file_name TEXT NOT NULL,
  content_type TEXT NOT NULL DEFAULT '',
  storage_driver TEXT NOT NULL DEFAULT 'local',
  storage_key TEXT NOT NULL,
  size_bytes INTEGER NOT NULL DEFAULT 0
)
''');
  await database.execute('''
CREATE INDEX IF NOT EXISTS idx_cached_attachments_file_name
ON cached_attachments (file_name, id)
''');
}

Map<String, Object?> _attachmentToRow(AttachmentSummary attachment) {
  return {
    'id': attachment.id,
    'file_name': attachment.fileName,
    'content_type': attachment.contentType,
    'storage_driver': attachment.storageDriver,
    'storage_key': attachment.storageKey,
    'size_bytes': attachment.sizeBytes,
  };
}

AttachmentSummary _attachmentFromRow(Map<String, Object?> row) {
  return AttachmentSummary(
    id: row['id']! as String,
    fileName: row['file_name']! as String,
    contentType: row['content_type'] as String? ?? '',
    storageDriver: row['storage_driver'] as String? ?? 'local',
    storageKey: row['storage_key']! as String,
    sizeBytes: row['size_bytes'] as int? ?? 0,
  );
}

Map<String, Object?> _manifestEntryToRow(AttachmentUploadManifestEntry entry) {
  return {
    'operation_id': entry.operationId,
    'file_name': entry.fileName,
    'local_file_path': entry.localFilePath,
    'size_bytes': entry.sizeBytes,
    'created_at': entry.createdAt.toIso8601String(),
    'content_type': entry.contentType,
  };
}

AttachmentUploadManifestEntry _manifestEntryFromRow(Map<String, Object?> row) {
  return AttachmentUploadManifestEntry(
    operationId: row['operation_id']! as String,
    fileName: row['file_name']! as String,
    localFilePath: row['local_file_path']! as String,
    sizeBytes: row['size_bytes'] as int? ?? 0,
    createdAt: DateTime.parse(row['created_at']! as String),
    contentType: row['content_type'] as String?,
  );
}
