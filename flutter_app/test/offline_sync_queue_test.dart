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

  test('queues invoice drafts with one line and normalized tax selection', () {
    final queue = OfflineSyncQueue();

    final operation = queue.enqueueInvoiceDraft(
      customerId: 'customer-1',
      invoiceNumber: 'INV-MOB-001',
      accountsReceivableId: 'acct-ar',
      description: 'Field service',
      unitPriceMinor: 150000,
      incomeAccountId: 'acct-income',
      taxRateId: 'tax-rate-ignored',
      taxGroupId: 'gst-group',
      createdAt: DateTime.utc(2026, 7, 15, 9),
    );

    expect(operation.module, 'invoices');
    expect(operation.action, 'create_draft');
    expect(operation.payload['invoice_number'], 'INV-MOB-001');
    expect(operation.payload['issue_date'], '2026-07-15');
    expect(operation.payload['due_date'], '2026-08-14');
    final lines = operation.payload['lines']! as List<Map<String, Object?>>;
    expect(lines.single['income_account_id'], 'acct-income');
    expect(lines.single['tax_rate_id'], isNull);
    expect(lines.single['tax_group_id'], 'gst-group');
  });

  test('queues attachment metadata for later API creation', () {
    final queue = OfflineSyncQueue();

    final operation = queue.enqueueAttachmentMetadata(
      fileName: 'receipt.jpg',
      storageKey: 'offline/receipt.jpg',
      contentType: 'image/jpeg',
      sizeBytes: 42,
      createdAt: DateTime.utc(2026, 7, 15, 9),
    );

    expect(operation.module, 'attachments');
    expect(operation.action, 'create_metadata');
    expect(operation.payload['file_name'], 'receipt.jpg');
    expect(operation.payload['storage_key'], 'offline/receipt.jpg');
    expect(operation.payload['size_bytes'], 42);
  });

  test('queues attachment binary uploads for later replay', () {
    final queue = OfflineSyncQueue();

    final operation = queue.enqueueAttachmentUpload(
      fileName: 'receipt.jpg',
      localFilePath: '/tmp/receipt.jpg',
      createdAt: DateTime.utc(2026, 7, 15, 9),
    );

    expect(operation.module, 'attachments');
    expect(operation.action, 'upload_binary');
    expect(operation.payload['file_name'], 'receipt.jpg');
    expect(operation.payload['local_file_path'], '/tmp/receipt.jpg');
  });

  test('queues investment prices for later API creation', () {
    final queue = OfflineSyncQueue();

    final operation = queue.enqueueInvestmentPrice(
      symbol: 'INFY',
      priceDate: DateTime.utc(2026, 7, 14),
      priceMinor: 158900,
      createdAt: DateTime.utc(2026, 7, 15, 9),
    );

    expect(operation.module, 'investments');
    expect(operation.action, 'create_price');
    expect(operation.payload['symbol'], 'INFY');
    expect(operation.payload['price_date'], '2026-07-14');
    expect(operation.payload['source'], 'mobile-offline');
  });

  test('queues customer and vendor payments for later replay', () {
    final queue = OfflineSyncQueue();

    final customerPayment = queue.enqueueCustomerPayment(
      invoiceId: 'invoice-1',
      paymentNumber: 'RCPT-MOB-001',
      paymentDate: DateTime.utc(2026, 7, 15),
      amountMinor: 118000,
      paymentAccountId: 'acct-bank',
      paymentMethod: 'upi',
      reference: 'UPI123',
      createdAt: DateTime.utc(2026, 7, 15, 9),
    );
    final vendorPayment = queue.enqueueVendorPayment(
      billId: 'bill-1',
      paymentNumber: 'VPAY-MOB-001',
      paymentDate: DateTime.utc(2026, 7, 16),
      amountMinor: 59000,
      paymentAccountId: 'acct-bank',
      createdAt: DateTime.utc(2026, 7, 15, 10),
    );

    expect(customerPayment.module, 'payments');
    expect(customerPayment.action, 'record_customer');
    expect(customerPayment.payload['invoice_id'], 'invoice-1');
    expect(customerPayment.payload['payment_date'], '2026-07-15');
    expect(customerPayment.payload['payment_method'], 'upi');
    expect(customerPayment.payload['reference'], 'UPI123');
    expect(vendorPayment.module, 'payments');
    expect(vendorPayment.action, 'record_vendor');
    expect(vendorPayment.payload['bill_id'], 'bill-1');
    expect(vendorPayment.payload['payment_date'], '2026-07-16');
    expect(vendorPayment.payload['payment_method'], isNull);
  });

  test('queues estimate and purchase order status updates', () {
    final queue = OfflineSyncQueue();

    final estimateStatus = queue.enqueueEstimateStatusUpdate(
      estimateId: 'estimate-1',
      status: 'accepted',
      createdAt: DateTime.utc(2026, 7, 15, 9),
    );
    final purchaseOrderStatus = queue.enqueuePurchaseOrderStatusUpdate(
      purchaseOrderId: 'po-1',
      status: 'approved',
      createdAt: DateTime.utc(2026, 7, 15, 10),
    );

    expect(estimateStatus.module, 'commercial_documents');
    expect(estimateStatus.action, 'update_estimate_status');
    expect(estimateStatus.payload['estimate_id'], 'estimate-1');
    expect(estimateStatus.payload['status'], 'accepted');
    expect(purchaseOrderStatus.module, 'commercial_documents');
    expect(purchaseOrderStatus.action, 'update_purchase_order_status');
    expect(purchaseOrderStatus.payload['purchase_order_id'], 'po-1');
    expect(purchaseOrderStatus.payload['status'], 'approved');
  });
}
