import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'offline_sync_queue.dart';

Future<SyncOperationRepository> createDefaultSyncOperationRepository() async {
  final directory = await getApplicationSupportDirectory();
  return FileSyncOperationRepository(
    File('${directory.path}/pending-sync-operations.json'),
  );
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
