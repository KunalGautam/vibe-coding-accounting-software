import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../storage/offline_sqlite.dart';
import 'offline_sync_queue.dart';

Future<SyncOperationRepository> createDefaultSyncOperationRepository() async {
  final database = await openOfflineDatabase(
    fileName: 'offline-sync.sqlite',
    version: 1,
    onCreate: (database, _) => createOfflineSyncTables(database),
  );
  return SqliteSyncOperationRepository(database);
}

abstract interface class SyncOperationRepository {
  Future<List<SyncOperation>> loadPending();

  Future<void> savePending(List<SyncOperation> operations);
}

class MemorySyncOperationRepository implements SyncOperationRepository {
  MemorySyncOperationRepository([List<SyncOperation>? seed])
    : _operations = [...?seed];

  final List<SyncOperation> _operations;

  @override
  Future<List<SyncOperation>> loadPending() async {
    return List.unmodifiable(_operations);
  }

  @override
  Future<void> savePending(List<SyncOperation> operations) async {
    _operations
      ..clear()
      ..addAll(operations);
  }
}

class FileSyncOperationRepository implements SyncOperationRepository {
  const FileSyncOperationRepository(this.file);

  final File file;

  @override
  Future<List<SyncOperation>> loadPending() async {
    if (!await file.exists()) {
      return [];
    }

    final contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      return [];
    }

    final decoded = jsonDecode(contents);
    if (decoded is! List) {
      throw const FormatException('Expected sync operation JSON array');
    }

    return decoded
        .cast<Map<String, Object?>>()
        .map(SyncOperation.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> savePending(List<SyncOperation> operations) async {
    await file.parent.create(recursive: true);
    final tempFile = File('${file.path}.tmp');
    final encoded = jsonEncode(
      operations.map((operation) => operation.toJson()).toList(growable: false),
    );

    await tempFile.writeAsString(encoded, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }
}

class SqliteSyncOperationRepository implements SyncOperationRepository {
  const SqliteSyncOperationRepository(this.database);

  final Database database;

  @override
  Future<List<SyncOperation>> loadPending() async {
    final rows = await database.query(
      'pending_sync_operations',
      orderBy: 'created_at ASC, id ASC',
    );
    return rows.map(_operationFromRow).toList(growable: false);
  }

  @override
  Future<void> savePending(List<SyncOperation> operations) async {
    await database.transaction((transaction) async {
      await transaction.delete('pending_sync_operations');
      for (final operation in operations) {
        await transaction.insert(
          'pending_sync_operations',
          _operationToRow(operation),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}

Future<void> createOfflineSyncTables(DatabaseExecutor database) async {
  await database.execute('''
CREATE TABLE IF NOT EXISTS pending_sync_operations (
  id TEXT PRIMARY KEY,
  module TEXT NOT NULL,
  action TEXT NOT NULL,
  created_at TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  retry_count INTEGER NOT NULL DEFAULT 0,
  last_attempt_at TEXT,
  last_error TEXT,
  conflict_reason TEXT
)
''');
  await database.execute('''
CREATE INDEX IF NOT EXISTS idx_pending_sync_operations_created_at
ON pending_sync_operations (created_at, id)
''');
}

Map<String, Object?> _operationToRow(SyncOperation operation) {
  return {
    'id': operation.id,
    'module': operation.module,
    'action': operation.action,
    'created_at': operation.createdAt.toIso8601String(),
    'payload_json': jsonEncode(operation.payload),
    'retry_count': operation.retryCount,
    'last_attempt_at': operation.lastAttemptAt?.toIso8601String(),
    'last_error': operation.lastError,
    'conflict_reason': operation.conflictReason,
  };
}

SyncOperation _operationFromRow(Map<String, Object?> row) {
  final payload = jsonDecode(row['payload_json']! as String);
  return SyncOperation(
    id: row['id']! as String,
    module: row['module']! as String,
    action: row['action']! as String,
    createdAt: DateTime.parse(row['created_at']! as String),
    payload: payload is Map<String, Object?>
        ? payload
        : Map<String, Object?>.from(payload as Map),
    retryCount: row['retry_count'] as int? ?? 0,
    lastAttemptAt: row['last_attempt_at'] is String
        ? DateTime.parse(row['last_attempt_at']! as String)
        : null,
    lastError: row['last_error'] as String?,
    conflictReason: row['conflict_reason'] as String?,
  );
}
