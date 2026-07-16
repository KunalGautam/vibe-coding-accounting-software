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

  test('queues draft expense edits for offline replay', () {
    final queue = OfflineSyncQueue();

    final operation = queue.enqueueExpenseDraftUpdate(
      expenseId: 'expense-1',
      merchantName: 'Updated Client Taxi',
      amountMinor: 99000,
      expenseAccountId: 'acct-expense',
      paymentAccountId: 'acct-bank',
      receiptAttachmentId: 'receipt-new',
      taxRateId: 'tax-rate-ignored',
      taxGroupId: 'gst-group',
      taxInclusive: true,
      reimbursable: true,
      createdAt: DateTime.utc(2026, 7, 16, 10),
    );

    expect(operation.module, 'expenses');
    expect(operation.action, 'update_draft');
    expect(operation.id, startsWith('expense-update-'));
    expect(operation.payload['expense_id'], 'expense-1');
    expect(operation.payload['merchant_name'], 'Updated Client Taxi');
    expect(operation.payload['amount_minor'], 99000);
    expect(operation.payload['expense_account_id'], 'acct-expense');
    expect(operation.payload['payment_account_id'], 'acct-bank');
    expect(operation.payload['receipt_attachment_id'], 'receipt-new');
    expect(operation.payload['tax_rate_id'], isNull);
    expect(operation.payload['tax_group_id'], 'gst-group');
    expect(operation.payload['tax_inclusive'], true);
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

  test('queues draft invoice edits for offline replay', () {
    final queue = OfflineSyncQueue();

    final operation = queue.enqueueInvoiceDraftUpdate(
      invoiceId: 'invoice-1',
      customerId: 'customer-1',
      invoiceNumber: 'INV-MOB-001-EDIT',
      accountsReceivableId: 'acct-ar',
      description: 'Updated field service',
      unitPriceMinor: 175000,
      incomeAccountId: 'acct-income',
      taxRateId: 'tax-rate-ignored',
      taxGroupId: 'gst-group',
      createdAt: DateTime.utc(2026, 7, 16, 9),
    );

    expect(operation.module, 'invoices');
    expect(operation.action, 'update_draft');
    expect(operation.id, startsWith('invoice-update-'));
    expect(operation.payload['invoice_id'], 'invoice-1');
    expect(operation.payload['invoice_number'], 'INV-MOB-001-EDIT');
    final lines = operation.payload['lines']! as List<Map<String, Object?>>;
    expect(lines.single['description'], 'Updated field service');
    expect(lines.single['unit_price_minor'], 175000);
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

  test('queues investment lots for later API creation', () {
    final queue = OfflineSyncQueue();

    final operation = queue.enqueueInvestmentLot(
      accountId: 'acct-invest',
      symbol: 'INFY',
      securityName: 'Infosys',
      acquisitionDate: DateTime.utc(2026, 7, 31),
      quantityMillis: 2500,
      costBasisMinor: 375000,
      costMethod: 'average_cost',
      notes: 'Initial mobile lot',
      createdAt: DateTime.utc(2026, 7, 31, 9),
    );

    expect(operation.module, 'investments');
    expect(operation.action, 'create_lot');
    expect(operation.payload['account_id'], 'acct-invest');
    expect(operation.payload['symbol'], 'INFY');
    expect(operation.payload['security_name'], 'Infosys');
    expect(operation.payload['acquisition_date'], '2026-07-31');
    expect(operation.payload['quantity_millis'], 2500);
    expect(operation.payload['cost_basis_minor'], 375000);
    expect(operation.payload['cost_method'], 'average_cost');
    expect(operation.payload['notes'], 'Initial mobile lot');
  });

  test('queues broker holdings price imports for later replay', () {
    final queue = OfflineSyncQueue();

    final operation = queue.enqueueBrokerHoldingsPriceImport(
      csv: 'Symbol,As of Date,Last Traded Price\nTCS,31-Jul-2026,3450.75',
      createdAt: DateTime.utc(2026, 7, 15, 9),
    );

    expect(operation.module, 'investments');
    expect(operation.action, 'import_broker_holdings');
    expect(operation.payload['source'], 'broker_holdings_csv');
    expect(operation.payload['csv'], contains('TCS'));
  });

  test('queues average-cost investment sales for later replay', () {
    final queue = OfflineSyncQueue();

    final operation = queue.enqueueAverageCostSale(
      accountId: 'acct-invest',
      symbol: 'INFY',
      saleDate: DateTime.utc(2026, 7, 15),
      quantityMillis: 2500,
      proceedsMinor: 375000,
      proceedsAccountId: 'acct-bank',
      gainLossAccountId: 'acct-gain-loss',
      notes: 'Partial sale from mobile',
      createdAt: DateTime.utc(2026, 7, 15, 9),
    );

    expect(operation.module, 'investments');
    expect(operation.action, 'sell_average_cost');
    expect(operation.payload['account_id'], 'acct-invest');
    expect(operation.payload['symbol'], 'INFY');
    expect(operation.payload['sale_date'], '2026-07-15');
    expect(operation.payload['quantity_millis'], 2500);
    expect(operation.payload['proceeds_minor'], 375000);
    expect(operation.payload['proceeds_account_id'], 'acct-bank');
    expect(operation.payload['gain_loss_account_id'], 'acct-gain-loss');
    expect(operation.payload['notes'], 'Partial sale from mobile');
  });

  test('queues specific-lot investment sales for later replay', () {
    final queue = OfflineSyncQueue();

    final operation = queue.enqueueInvestmentLotSale(
      lotId: 'lot-1',
      saleDate: DateTime.utc(2026, 7, 31),
      quantityMillis: 1000,
      proceedsMinor: 150000,
      proceedsAccountId: 'acct-bank',
      gainLossAccountId: 'acct-gain-loss',
      notes: 'Specific sale from mobile',
      createdAt: DateTime.utc(2026, 7, 31, 9),
    );

    expect(operation.module, 'investments');
    expect(operation.action, 'sell_lot');
    expect(operation.payload['lot_id'], 'lot-1');
    expect(operation.payload['sale_date'], '2026-07-31');
    expect(operation.payload['quantity_millis'], 1000);
    expect(operation.payload['proceeds_minor'], 150000);
    expect(operation.payload['proceeds_account_id'], 'acct-bank');
    expect(operation.payload['gain_loss_account_id'], 'acct-gain-loss');
    expect(operation.payload['notes'], 'Specific sale from mobile');
  });

  test('queues investment dividends for later replay', () {
    final queue = OfflineSyncQueue();

    final operation = queue.enqueueInvestmentDividend(
      accountId: 'acct-invest',
      symbol: 'INFY',
      dividendDate: DateTime.utc(2026, 7, 31),
      amountMinor: 12500,
      cashAccountId: 'acct-bank',
      incomeAccountId: 'acct-dividend-income',
      notes: 'Quarterly dividend',
      createdAt: DateTime.utc(2026, 7, 31, 10),
    );

    expect(operation.module, 'investments');
    expect(operation.action, 'create_dividend');
    expect(operation.payload['account_id'], 'acct-invest');
    expect(operation.payload['symbol'], 'INFY');
    expect(operation.payload['dividend_date'], '2026-07-31');
    expect(operation.payload['amount_minor'], 12500);
    expect(operation.payload['cash_account_id'], 'acct-bank');
    expect(operation.payload['income_account_id'], 'acct-dividend-income');
    expect(operation.payload['notes'], 'Quarterly dividend');
  });

  test('queues investment corporate actions for later replay', () {
    final queue = OfflineSyncQueue();

    final operation = queue.enqueueInvestmentCorporateAction(
      accountId: 'acct-invest',
      symbol: 'INFY',
      actionType: 'split',
      actionDate: DateTime.utc(2026, 8, 1),
      ratioNumerator: 2,
      ratioDenominator: 1,
      notes: 'Two-for-one split',
      createdAt: DateTime.utc(2026, 8, 1, 10),
    );

    expect(operation.module, 'investments');
    expect(operation.action, 'create_corporate_action');
    expect(operation.payload['account_id'], 'acct-invest');
    expect(operation.payload['symbol'], 'INFY');
    expect(operation.payload['action_type'], 'split');
    expect(operation.payload['action_date'], '2026-08-01');
    expect(operation.payload['ratio_numerator'], 2);
    expect(operation.payload['ratio_denominator'], 1);
    expect(operation.payload['notes'], 'Two-for-one split');
  });

  test('queues structured bank statement imports for later replay', () {
    final queue = OfflineSyncQueue();

    final operation = queue.enqueueStructuredBankStatementImport(
      accountId: 'acct-bank',
      fileName: 'july-bank.csv',
      lines: const [
        {
          'posted_date': '2026-07-15',
          'description': 'UPI receipt',
          'amount_minor': 125000,
          'reference': 'UPI123',
        },
      ],
      createdAt: DateTime.utc(2026, 7, 15, 9),
    );

    expect(operation.module, 'imports');
    expect(operation.action, 'bank_statement_structured');
    expect(operation.payload['account_id'], 'acct-bank');
    expect(operation.payload['file_name'], 'july-bank.csv');
    expect(operation.payload['format'], 'csv');
    final lines = operation.payload['lines']! as List<Map<String, Object?>>;
    expect(lines.single['posted_date'], '2026-07-15');
    expect(lines.single['amount_minor'], 125000);
  });

  test('queues QIF and OFX bank statement imports for later replay', () {
    final queue = OfflineSyncQueue();

    final qif = queue.enqueueQifBankStatementImport(
      accountId: 'acct-bank',
      fileName: 'july-bank.qif',
      qifContent: '!Type:Bank\nD13/07/2026\nT1250.00\n^',
      createdAt: DateTime.utc(2026, 7, 15, 9),
    );
    final ofx = queue.enqueueOfxBankStatementImport(
      accountId: 'acct-bank',
      fileName: 'july-bank.ofx',
      ofxContent: '<OFX><STMTTRN><TRNAMT>1250.00',
      createdAt: DateTime.utc(2026, 7, 15, 10),
    );

    expect(qif.module, 'imports');
    expect(qif.action, 'bank_statement_qif');
    expect(qif.payload['account_id'], 'acct-bank');
    expect(qif.payload['file_name'], 'july-bank.qif');
    expect(qif.payload['qif_content'], contains('!Type:Bank'));
    expect(ofx.module, 'imports');
    expect(ofx.action, 'bank_statement_ofx');
    expect(ofx.payload['file_name'], 'july-bank.ofx');
    expect(ofx.payload['ofx_content'], contains('<OFX>'));
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

  test('queues estimate and purchase order conversions', () {
    final queue = OfflineSyncQueue();

    final estimateConversion = queue.enqueueEstimateConversion(
      estimateId: 'estimate-1',
      invoiceNumber: 'INV-MOB-002',
      issueDate: DateTime.utc(2026, 7, 18),
      dueDate: DateTime.utc(2026, 8, 17),
      accountsReceivableId: 'acct-ar',
      pdfAttachmentId: 'attachment-pdf',
      createdAt: DateTime.utc(2026, 7, 18, 9),
    );
    final purchaseOrderConversion = queue.enqueuePurchaseOrderConversion(
      purchaseOrderId: 'po-1',
      billNumber: 'BILL-MOB-002',
      issueDate: DateTime.utc(2026, 7, 19),
      dueDate: DateTime.utc(2026, 8, 18),
      accountsPayableId: 'acct-ap',
      documentAttachmentId: 'attachment-bill',
      createdAt: DateTime.utc(2026, 7, 18, 10),
    );

    expect(estimateConversion.module, 'commercial_documents');
    expect(estimateConversion.action, 'convert_estimate_to_invoice');
    expect(estimateConversion.payload['estimate_id'], 'estimate-1');
    expect(estimateConversion.payload['invoice_number'], 'INV-MOB-002');
    expect(estimateConversion.payload['issue_date'], '2026-07-18');
    expect(estimateConversion.payload['due_date'], '2026-08-17');
    expect(estimateConversion.payload['accounts_receivable_id'], 'acct-ar');
    expect(estimateConversion.payload['pdf_attachment_id'], 'attachment-pdf');
    expect(purchaseOrderConversion.module, 'commercial_documents');
    expect(purchaseOrderConversion.action, 'convert_purchase_order_to_bill');
    expect(purchaseOrderConversion.payload['purchase_order_id'], 'po-1');
    expect(purchaseOrderConversion.payload['bill_number'], 'BILL-MOB-002');
    expect(purchaseOrderConversion.payload['issue_date'], '2026-07-19');
    expect(purchaseOrderConversion.payload['due_date'], '2026-08-18');
    expect(purchaseOrderConversion.payload['accounts_payable_id'], 'acct-ap');
    expect(
      purchaseOrderConversion.payload['document_attachment_id'],
      'attachment-bill',
    );
  });

  test('queues ledger posting actions for later replay', () {
    final queue = OfflineSyncQueue();

    final invoicePost = queue.enqueueInvoicePost(
      invoiceId: 'invoice-1',
      createdAt: DateTime.utc(2026, 7, 15, 9),
    );
    final expensePost = queue.enqueueExpensePost(
      expenseId: 'expense-1',
      createdAt: DateTime.utc(2026, 7, 15, 10),
    );
    final billPost = queue.enqueueBillPost(
      billId: 'bill-1',
      createdAt: DateTime.utc(2026, 7, 15, 11),
    );
    final creditNotePost = queue.enqueueCreditNotePost(
      creditNoteId: 'credit-note-1',
      createdAt: DateTime.utc(2026, 7, 15, 12),
    );

    expect(invoicePost.module, 'ledger');
    expect(invoicePost.action, 'post_invoice');
    expect(invoicePost.payload['invoice_id'], 'invoice-1');
    expect(expensePost.action, 'post_expense');
    expect(expensePost.payload['expense_id'], 'expense-1');
    expect(billPost.action, 'post_bill');
    expect(billPost.payload['bill_id'], 'bill-1');
    expect(creditNotePost.action, 'post_credit_note');
    expect(creditNotePost.payload['credit_note_id'], 'credit-note-1');
  });
}
