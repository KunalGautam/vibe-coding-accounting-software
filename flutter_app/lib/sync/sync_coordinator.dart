import '../api/accounting_api_client.dart';
import 'offline_sync_queue.dart';
import 'sync_operation_repository.dart';

class SyncCoordinator {
  const SyncCoordinator({
    required OfflineSyncQueue queue,
    required AccountingApiClient apiClient,
    SyncOperationRepository? repository,
  }) : this._(queue, apiClient, repository);

  const SyncCoordinator._(this._queue, this._apiClient, this._repository);

  final OfflineSyncQueue _queue;
  final AccountingApiClient _apiClient;
  final SyncOperationRepository? _repository;

  Future<SyncResult> syncPending() async {
    var synced = 0;
    var skipped = 0;
    final failed = <SyncFailure>[];

    final repository = _repository;
    if (repository != null) {
      _queue.replaceAll(await repository.loadPending());
    }

    for (final operation in _queue.pending) {
      try {
        if (_canSync(operation)) {
          await _syncOperation(operation);
          _queue.markSynced(operation.id);
          synced += 1;
        } else {
          skipped += 1;
        }
      } on Object catch (error) {
        failed.add(SyncFailure(operationId: operation.id, error: error));
      }
    }

    if (repository != null) {
      await repository.savePending(_queue.pending);
    }

    return SyncResult(synced: synced, skipped: skipped, failed: failed);
  }

  bool _canSync(SyncOperation operation) {
    return operation.module == 'expenses' && operation.action == 'create_draft';
  }

  Future<void> _syncOperation(SyncOperation operation) async {
    await _apiClient.syncExpenseDraft(operation);
  }
}

class SyncResult {
  const SyncResult({
    required this.synced,
    required this.skipped,
    required this.failed,
  });

  final int synced;
  final int skipped;
  final List<SyncFailure> failed;

  bool get hasFailures => failed.isNotEmpty;
}

class SyncFailure {
  const SyncFailure({required this.operationId, required this.error});

  final String operationId;
  final Object error;
}
