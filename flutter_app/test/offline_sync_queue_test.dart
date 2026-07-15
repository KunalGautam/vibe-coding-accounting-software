import 'package:accounting_app/sync/offline_sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('queues expense drafts with sync metadata', () {
    final queue = OfflineSyncQueue();
    final createdAt = DateTime.utc(2026, 7, 11, 12);

    final operation = queue.enqueueExpenseDraft(
      merchantName: 'Stationery House',
      amountMinor: 125000,
      taxInclusive: true,
      createdAt: createdAt,
    );

    expect(queue.pendingCount, 1);
    expect(operation.module, 'expenses');
    expect(operation.action, 'create_draft');
    expect(operation.payload['currency'], 'INR');
    expect(operation.payload['amount_minor'], 125000);
    expect(operation.payload['tax_inclusive'], true);
    expect(operation.payload['reimbursable'], false);
  });

  test('queues reimbursable expense drafts', () {
    final queue = OfflineSyncQueue();

    final operation = queue.enqueueExpenseDraft(
      merchantName: 'Client taxi',
      amountMinor: 85000,
      receiptAttachmentId: 'attachment-1',
      taxRateId: 'tax-rate-1',
      taxGroupId: 'tax-group-1',
      reimbursable: true,
    );

    expect(operation.payload['merchant_name'], 'Client taxi');
    expect(operation.payload['amount_minor'], 85000);
    expect(operation.payload['receipt_attachment_id'], 'attachment-1');
    expect(operation.payload['tax_rate_id'], isNull);
    expect(operation.payload['tax_group_id'], 'tax-group-1');
    expect(operation.payload['reimbursable'], true);
  });

  test('removes operations after successful sync', () {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'expense-1',
        module: 'expenses',
        action: 'create_draft',
        createdAt: DateTime.utc(2026, 7, 11),
      ),
    ]);

    queue.markSynced('expense-1');

    expect(queue.pendingCount, 0);
  });

  test('removes operations by id for local deletion', () {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'expense-1',
        module: 'expenses',
        action: 'create_draft',
        createdAt: DateTime.utc(2026, 7, 11),
      ),
      SyncOperation(
        id: 'expense-2',
        module: 'expenses',
        action: 'create_draft',
        createdAt: DateTime.utc(2026, 7, 12),
      ),
    ]);

    queue.remove('expense-1');

    expect(queue.pendingCount, 1);
    expect(queue.pending.single.id, 'expense-2');
  });

  test('updates expense draft payload while preserving sync identity', () {
    final createdAt = DateTime.utc(2026, 7, 11);
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'expense-1',
        module: 'expenses',
        action: 'create_draft',
        createdAt: createdAt,
        payload: const {
          'merchant_name': 'Metro Taxi',
          'amount_minor': 84550,
          'expense_account_id': 'expense-account',
          'payment_account_id': 'cash-account',
          'receipt_attachment_id': 'receipt-old',
          'tax_rate_id': 'tax-rate-old',
          'tax_group_id': 'tax-group-old',
          'tax_inclusive': false,
          'reimbursable': false,
          'currency': 'INR',
        },
      ),
    ]);

    queue.updateExpenseDraft(
      id: 'expense-1',
      merchantName: 'Airport Taxi',
      amountMinor: 95000,
      receiptAttachmentId: 'receipt-new',
      taxRateId: 'tax-rate-new',
      taxGroupId: 'tax-group-new',
      taxInclusive: true,
      reimbursable: true,
    );

    final operation = queue.pending.single;
    expect(operation.id, 'expense-1');
    expect(operation.createdAt, createdAt);
    expect(operation.payload['merchant_name'], 'Airport Taxi');
    expect(operation.payload['amount_minor'], 95000);
    expect(operation.payload['receipt_attachment_id'], 'receipt-new');
    expect(operation.payload['tax_rate_id'], isNull);
    expect(operation.payload['tax_group_id'], 'tax-group-new');
    expect(operation.payload['tax_inclusive'], true);
    expect(operation.payload['reimbursable'], true);
    expect(operation.payload['expense_account_id'], 'expense-account');
    expect(operation.payload['payment_account_id'], 'cash-account');
  });

  test('editing a failed draft clears stale retry and conflict state', () {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'expense-1',
        module: 'expenses',
        action: 'create_draft',
        createdAt: DateTime.utc(2026, 7, 11),
        retryCount: 2,
        lastAttemptAt: DateTime.utc(2026, 7, 12),
        lastError: 'duplicate expense number',
        conflictReason: 'duplicate expense number',
        payload: const {
          'merchant_name': 'Metro Taxi',
          'amount_minor': 84550,
          'expense_account_id': 'expense-account',
          'payment_account_id': 'cash-account',
          'currency': 'INR',
        },
      ),
    ]);

    queue.updateExpenseDraft(
      id: 'expense-1',
      merchantName: 'Airport Taxi',
      amountMinor: 95000,
      taxInclusive: false,
      reimbursable: false,
    );

    final operation = queue.pending.single;
    expect(operation.retryCount, 0);
    expect(operation.lastAttemptAt, isNull);
    expect(operation.lastError, isNull);
    expect(operation.conflictReason, isNull);
  });

  test('serializes and hydrates sync operations', () {
    final operation = SyncOperation(
      id: 'expense-1',
      module: 'expenses',
      action: 'create_draft',
      createdAt: DateTime.utc(2026, 7, 11, 12),
      payload: const {'expense_number': 'EXP-001', 'amount_minor': 125000},
    );

    final hydrated = SyncOperation.fromJson(operation.toJson());

    expect(hydrated.id, operation.id);
    expect(hydrated.createdAt, operation.createdAt);
    expect(hydrated.payload['amount_minor'], 125000);
  });

  test('replaces all pending operations when hydrating from storage', () {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'old',
        module: 'expenses',
        action: 'create_draft',
        createdAt: DateTime.utc(2026, 7, 10),
      ),
    ]);

    queue.replaceAll([
      SyncOperation(
        id: 'new',
        module: 'invoices',
        action: 'cache_view',
        createdAt: DateTime.utc(2026, 7, 11),
      ),
    ]);

    expect(queue.pendingCount, 1);
    expect(queue.pending.single.id, 'new');
  });
}
