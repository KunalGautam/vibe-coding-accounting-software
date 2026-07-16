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
        final conflict = _isConflict(error);
        _queue.updateOperation(
          operation.markAttemptFailed(error: error, conflict: conflict),
        );
        failed.add(SyncFailure(operationId: operation.id, error: error));
      }
    }

    if (repository != null) {
      await repository.savePending(_queue.pending);
    }

    return SyncResult(synced: synced, skipped: skipped, failed: failed);
  }

  bool _canSync(SyncOperation operation) {
    return _syncHandlers.containsKey(_operationKey(operation));
  }

  Future<void> _syncOperation(SyncOperation operation) async {
    final handler = _syncHandlers[_operationKey(operation)];
    if (handler == null) {
      return;
    }
    await handler(_apiClient, operation);
  }

  bool _isConflict(Object error) {
    if (error is AccountingApiException) {
      return error.statusCode == 409 || error.statusCode == 412;
    }
    return false;
  }
}

String _operationKey(SyncOperation operation) {
  return '${operation.module}.${operation.action}';
}

typedef _SyncHandler =
    Future<void> Function(AccountingApiClient client, SyncOperation operation);

final Map<String, _SyncHandler> _syncHandlers = {
  'expenses.create_draft': (client, operation) async {
    await client.syncExpenseDraft(operation);
  },
  'invoices.create_draft': (client, operation) async {
    await client.syncInvoiceDraft(operation);
  },
  'ledger.post_invoice': (client, operation) async {
    await client.syncInvoicePost(operation);
  },
  'ledger.post_expense': (client, operation) async {
    await client.syncExpensePost(operation);
  },
  'ledger.post_bill': (client, operation) async {
    await client.syncBillPost(operation);
  },
  'ledger.post_credit_note': (client, operation) async {
    await client.syncCreditNotePost(operation);
  },
  'attachments.create_metadata': (client, operation) async {
    await client.syncAttachmentMetadata(operation);
  },
  'attachments.upload_binary': (client, operation) async {
    await client.syncAttachmentUpload(operation);
  },
  'investments.create_price': (client, operation) async {
    await client.syncInvestmentPrice(operation);
  },
  'payments.record_customer': (client, operation) async {
    await client.syncCustomerPayment(operation);
  },
  'payments.record_vendor': (client, operation) async {
    await client.syncVendorPayment(operation);
  },
  'commercial_documents.update_estimate_status': (client, operation) async {
    await client.syncEstimateStatusUpdate(operation);
  },
  'commercial_documents.update_purchase_order_status':
      (client, operation) async {
        await client.syncPurchaseOrderStatusUpdate(operation);
      },
};

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

  int get conflicts => failed.where((failure) => failure.isConflict).length;
}

class SyncFailure {
  const SyncFailure({required this.operationId, required this.error});

  final String operationId;
  final Object error;

  bool get isConflict {
    final error = this.error;
    return error is AccountingApiException &&
        (error.statusCode == 409 || error.statusCode == 412);
  }
}
