class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.module,
    required this.action,
    required this.createdAt,
    this.payload = const {},
    this.retryCount = 0,
    this.lastAttemptAt,
    this.lastError,
    this.conflictReason,
  });

  final String id;
  final String module;
  final String action;
  final DateTime createdAt;
  final Map<String, Object?> payload;
  final int retryCount;
  final DateTime? lastAttemptAt;
  final String? lastError;
  final String? conflictReason;

  bool get hasConflict => conflictReason != null && conflictReason!.isNotEmpty;

  SyncOperation copyWith({
    String? id,
    String? module,
    String? action,
    DateTime? createdAt,
    Map<String, Object?>? payload,
    int? retryCount,
    DateTime? lastAttemptAt,
    String? lastError,
    String? conflictReason,
    bool clearLastAttemptAt = false,
    bool clearLastError = false,
    bool clearConflictReason = false,
  }) {
    return SyncOperation(
      id: id ?? this.id,
      module: module ?? this.module,
      action: action ?? this.action,
      createdAt: createdAt ?? this.createdAt,
      payload: payload ?? this.payload,
      retryCount: retryCount ?? this.retryCount,
      lastAttemptAt: clearLastAttemptAt
          ? null
          : lastAttemptAt ?? this.lastAttemptAt,
      lastError: clearLastError ? null : lastError ?? this.lastError,
      conflictReason: clearConflictReason
          ? null
          : conflictReason ?? this.conflictReason,
    );
  }

  SyncOperation markAttemptFailed({
    required Object error,
    DateTime? attemptedAt,
    bool conflict = false,
  }) {
    final message = error.toString();
    return copyWith(
      retryCount: retryCount + 1,
      lastAttemptAt: attemptedAt ?? DateTime.now().toUtc(),
      lastError: message,
      conflictReason: conflict ? message : null,
      clearConflictReason: !conflict,
    );
  }

  SyncOperation clearSyncState() {
    return copyWith(
      retryCount: 0,
      clearLastAttemptAt: true,
      clearLastError: true,
      clearConflictReason: true,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'module': module,
      'action': action,
      'created_at': createdAt.toIso8601String(),
      'payload': payload,
      'retry_count': retryCount,
      'last_attempt_at': lastAttemptAt?.toIso8601String(),
      'last_error': lastError,
      'conflict_reason': conflictReason,
    };
  }

  factory SyncOperation.fromJson(Map<String, Object?> json) {
    final payload = json['payload'];
    return SyncOperation(
      id: json['id']! as String,
      module: json['module']! as String,
      action: json['action']! as String,
      createdAt: DateTime.parse(json['created_at']! as String),
      payload: payload is Map<String, Object?>
          ? payload
          : Map<String, Object?>.from(payload! as Map),
      retryCount: json['retry_count'] as int? ?? 0,
      lastAttemptAt: json['last_attempt_at'] is String
          ? DateTime.parse(json['last_attempt_at']! as String)
          : null,
      lastError: json['last_error'] as String?,
      conflictReason: json['conflict_reason'] as String?,
    );
  }
}

class OfflineSyncQueue {
  final List<SyncOperation> _operations;

  OfflineSyncQueue([List<SyncOperation>? seed]) : _operations = [...?seed];

  int get pendingCount => _operations.length;

  List<SyncOperation> get pending => List.unmodifiable(_operations);

  void replaceAll(Iterable<SyncOperation> operations) {
    _operations
      ..clear()
      ..addAll(operations);
  }

  void enqueue(SyncOperation operation) {
    _operations.add(operation);
  }

  SyncOperation enqueueExpenseDraft({
    required String merchantName,
    required int amountMinor,
    String? expenseAccountId,
    String? paymentAccountId,
    String? receiptAttachmentId,
    String? taxRateId,
    String? taxGroupId,
    bool taxInclusive = false,
    bool reimbursable = false,
    DateTime? createdAt,
  }) {
    final timestamp = createdAt ?? DateTime.now().toUtc();
    final selectedTaxGroupId = normalizedOptional(taxGroupId);
    final selectedTaxRateId = selectedTaxGroupId == null
        ? normalizedOptional(taxRateId)
        : null;
    final operation = SyncOperation(
      id: 'expense-${timestamp.microsecondsSinceEpoch}',
      module: 'expenses',
      action: 'create_draft',
      createdAt: timestamp,
      payload: {
        'merchant_name': merchantName,
        'amount_minor': amountMinor,
        'expense_account_id': ?expenseAccountId,
        'payment_account_id': ?paymentAccountId,
        'receipt_attachment_id': ?receiptAttachmentId,
        'tax_rate_id': ?selectedTaxRateId,
        'tax_group_id': ?selectedTaxGroupId,
        'tax_inclusive': taxInclusive,
        'reimbursable': reimbursable,
        'currency': 'INR',
      },
    );
    enqueue(operation);
    return operation;
  }

  SyncOperation enqueueInvoiceDraft({
    required String customerId,
    required String invoiceNumber,
    required String accountsReceivableId,
    required String description,
    required int unitPriceMinor,
    required String incomeAccountId,
    DateTime? issueDate,
    DateTime? dueDate,
    int quantityMillis = 1000,
    String? pdfAttachmentId,
    String? taxRateId,
    String? taxGroupId,
    bool taxInclusive = false,
    DateTime? createdAt,
  }) {
    final timestamp = createdAt ?? DateTime.now().toUtc();
    final selectedTaxGroupId = normalizedOptional(taxGroupId);
    final selectedTaxRateId = selectedTaxGroupId == null
        ? normalizedOptional(taxRateId)
        : null;
    final operation = SyncOperation(
      id: 'invoice-${timestamp.microsecondsSinceEpoch}',
      module: 'invoices',
      action: 'create_draft',
      createdAt: timestamp,
      payload: {
        'customer_id': customerId,
        'invoice_number': invoiceNumber,
        'issue_date': dateOnlyString(issueDate ?? timestamp),
        'due_date': dateOnlyString(
          dueDate ?? timestamp.add(const Duration(days: 30)),
        ),
        'currency': 'INR',
        'tax_inclusive': taxInclusive,
        'accounts_receivable_id': accountsReceivableId,
        'pdf_attachment_id': ?normalizedOptional(pdfAttachmentId),
        'lines': [
          {
            'description': description,
            'quantity_millis': quantityMillis,
            'unit_price_minor': unitPriceMinor,
            'income_account_id': incomeAccountId,
            'tax_rate_id': ?selectedTaxRateId,
            'tax_group_id': ?selectedTaxGroupId,
          },
        ],
      },
    );
    enqueue(operation);
    return operation;
  }

  SyncOperation enqueueInvoiceDraftUpdate({
    required String invoiceId,
    required String customerId,
    required String invoiceNumber,
    required String accountsReceivableId,
    required String description,
    required int unitPriceMinor,
    required String incomeAccountId,
    DateTime? issueDate,
    DateTime? dueDate,
    int quantityMillis = 1000,
    String? pdfAttachmentId,
    String? taxRateId,
    String? taxGroupId,
    bool taxInclusive = false,
    DateTime? createdAt,
  }) {
    final operation = enqueueInvoiceDraft(
      customerId: customerId,
      invoiceNumber: invoiceNumber,
      accountsReceivableId: accountsReceivableId,
      description: description,
      unitPriceMinor: unitPriceMinor,
      incomeAccountId: incomeAccountId,
      issueDate: issueDate,
      dueDate: dueDate,
      quantityMillis: quantityMillis,
      pdfAttachmentId: pdfAttachmentId,
      taxRateId: taxRateId,
      taxGroupId: taxGroupId,
      taxInclusive: taxInclusive,
      createdAt: createdAt,
    );
    final payload = Map<String, Object?>.from(operation.payload)
      ..['invoice_id'] = invoiceId;
    final updated = operation.copyWith(
      id: 'invoice-update-${operation.createdAt.microsecondsSinceEpoch}',
      action: 'update_draft',
      payload: payload,
    );
    _operations[_operations.length - 1] = updated;
    return updated;
  }

  SyncOperation enqueueAttachmentMetadata({
    required String fileName,
    required String storageKey,
    String contentType = '',
    String storageDriver = 'local',
    int sizeBytes = 0,
    DateTime? createdAt,
  }) {
    final timestamp = createdAt ?? DateTime.now().toUtc();
    final operation = SyncOperation(
      id: 'attachment-${timestamp.microsecondsSinceEpoch}',
      module: 'attachments',
      action: 'create_metadata',
      createdAt: timestamp,
      payload: {
        'file_name': fileName,
        'content_type': contentType,
        'storage_driver': storageDriver,
        'storage_key': storageKey,
        'size_bytes': sizeBytes,
      },
    );
    enqueue(operation);
    return operation;
  }

  SyncOperation enqueueAttachmentUpload({
    required String fileName,
    required String localFilePath,
    DateTime? createdAt,
  }) {
    final timestamp = createdAt ?? DateTime.now().toUtc();
    final operation = SyncOperation(
      id: 'attachment-upload-${timestamp.microsecondsSinceEpoch}',
      module: 'attachments',
      action: 'upload_binary',
      createdAt: timestamp,
      payload: {'file_name': fileName, 'local_file_path': localFilePath},
    );
    enqueue(operation);
    return operation;
  }

  SyncOperation enqueueInvestmentPrice({
    required String symbol,
    required DateTime priceDate,
    required int priceMinor,
    String currency = 'INR',
    String source = 'mobile-offline',
    DateTime? createdAt,
  }) {
    final timestamp = createdAt ?? DateTime.now().toUtc();
    final operation = SyncOperation(
      id: 'investment-price-${timestamp.microsecondsSinceEpoch}',
      module: 'investments',
      action: 'create_price',
      createdAt: timestamp,
      payload: {
        'symbol': symbol,
        'price_date': dateOnlyString(priceDate),
        'price_minor': priceMinor,
        'currency': currency,
        'source': source,
      },
    );
    enqueue(operation);
    return operation;
  }

  SyncOperation enqueueBrokerHoldingsPriceImport({
    required String csv,
    String source = 'broker_holdings_csv',
    DateTime? createdAt,
  }) {
    final timestamp = createdAt ?? DateTime.now().toUtc();
    final operation = SyncOperation(
      id: 'broker-holdings-import-${timestamp.microsecondsSinceEpoch}',
      module: 'investments',
      action: 'import_broker_holdings',
      createdAt: timestamp,
      payload: {'csv': csv, 'source': source},
    );
    enqueue(operation);
    return operation;
  }

  SyncOperation enqueueAverageCostSale({
    required String accountId,
    required String symbol,
    required DateTime saleDate,
    required int quantityMillis,
    required int proceedsMinor,
    String currency = 'INR',
    String? proceedsAccountId,
    String? gainLossAccountId,
    String notes = '',
    DateTime? createdAt,
  }) {
    final timestamp = createdAt ?? DateTime.now().toUtc();
    final operation = SyncOperation(
      id: 'average-cost-sale-${timestamp.microsecondsSinceEpoch}',
      module: 'investments',
      action: 'sell_average_cost',
      createdAt: timestamp,
      payload: {
        'account_id': accountId,
        'symbol': symbol,
        'currency': currency,
        'sale_date': dateOnlyString(saleDate),
        'quantity_millis': quantityMillis,
        'proceeds_minor': proceedsMinor,
        'proceeds_account_id': ?normalizedOptional(proceedsAccountId),
        'gain_loss_account_id': ?normalizedOptional(gainLossAccountId),
        'notes': ?normalizedOptional(notes),
      },
    );
    enqueue(operation);
    return operation;
  }

  SyncOperation enqueueInvestmentDividend({
    required String accountId,
    required String symbol,
    required DateTime dividendDate,
    required int amountMinor,
    String currency = 'INR',
    String? cashAccountId,
    String? incomeAccountId,
    String notes = '',
    DateTime? createdAt,
  }) {
    final timestamp = createdAt ?? DateTime.now().toUtc();
    final operation = SyncOperation(
      id: 'investment-dividend-${timestamp.microsecondsSinceEpoch}',
      module: 'investments',
      action: 'create_dividend',
      createdAt: timestamp,
      payload: {
        'account_id': accountId,
        'symbol': symbol,
        'dividend_date': dateOnlyString(dividendDate),
        'amount_minor': amountMinor,
        'currency': currency,
        'cash_account_id': ?normalizedOptional(cashAccountId),
        'income_account_id': ?normalizedOptional(incomeAccountId),
        'notes': ?normalizedOptional(notes),
      },
    );
    enqueue(operation);
    return operation;
  }

  SyncOperation enqueueInvestmentCorporateAction({
    required String accountId,
    required String symbol,
    required String actionType,
    required DateTime actionDate,
    required int ratioNumerator,
    required int ratioDenominator,
    String notes = '',
    DateTime? createdAt,
  }) {
    final timestamp = createdAt ?? DateTime.now().toUtc();
    final operation = SyncOperation(
      id: 'investment-corporate-action-${timestamp.microsecondsSinceEpoch}',
      module: 'investments',
      action: 'create_corporate_action',
      createdAt: timestamp,
      payload: {
        'account_id': accountId,
        'symbol': symbol,
        'action_type': actionType,
        'action_date': dateOnlyString(actionDate),
        'ratio_numerator': ratioNumerator,
        'ratio_denominator': ratioDenominator,
        'notes': ?normalizedOptional(notes),
      },
    );
    enqueue(operation);
    return operation;
  }

  SyncOperation enqueueStructuredBankStatementImport({
    required String accountId,
    required List<Map<String, Object?>> lines,
    String fileName = '',
    String format = 'csv',
    DateTime? createdAt,
  }) {
    final timestamp = createdAt ?? DateTime.now().toUtc();
    final operation = SyncOperation(
      id: 'bank-import-${timestamp.microsecondsSinceEpoch}',
      module: 'imports',
      action: 'bank_statement_structured',
      createdAt: timestamp,
      payload: {
        'account_id': accountId,
        'file_name': ?normalizedOptional(fileName),
        'format': ?normalizedOptional(format),
        'lines': lines,
      },
    );
    enqueue(operation);
    return operation;
  }

  SyncOperation enqueueQifBankStatementImport({
    required String accountId,
    required String qifContent,
    String fileName = '',
    DateTime? createdAt,
  }) {
    return _enqueueRawBankStatementImport(
      action: 'bank_statement_qif',
      idPrefix: 'qif-bank-import',
      accountId: accountId,
      contentKey: 'qif_content',
      content: qifContent,
      fileName: fileName,
      createdAt: createdAt,
    );
  }

  SyncOperation enqueueOfxBankStatementImport({
    required String accountId,
    required String ofxContent,
    String fileName = '',
    DateTime? createdAt,
  }) {
    return _enqueueRawBankStatementImport(
      action: 'bank_statement_ofx',
      idPrefix: 'ofx-bank-import',
      accountId: accountId,
      contentKey: 'ofx_content',
      content: ofxContent,
      fileName: fileName,
      createdAt: createdAt,
    );
  }

  SyncOperation enqueueCustomerPayment({
    required String invoiceId,
    required String paymentNumber,
    required DateTime paymentDate,
    required int amountMinor,
    required String paymentAccountId,
    String paymentMethod = '',
    String reference = '',
    String currency = 'INR',
    DateTime? createdAt,
  }) {
    return _enqueuePayment(
      module: 'payments',
      action: 'record_customer',
      idPrefix: 'customer-payment',
      documentKey: 'invoice_id',
      documentId: invoiceId,
      paymentNumber: paymentNumber,
      paymentDate: paymentDate,
      amountMinor: amountMinor,
      paymentAccountId: paymentAccountId,
      paymentMethod: paymentMethod,
      reference: reference,
      currency: currency,
      createdAt: createdAt,
    );
  }

  SyncOperation enqueueVendorPayment({
    required String billId,
    required String paymentNumber,
    required DateTime paymentDate,
    required int amountMinor,
    required String paymentAccountId,
    String paymentMethod = '',
    String reference = '',
    String currency = 'INR',
    DateTime? createdAt,
  }) {
    return _enqueuePayment(
      module: 'payments',
      action: 'record_vendor',
      idPrefix: 'vendor-payment',
      documentKey: 'bill_id',
      documentId: billId,
      paymentNumber: paymentNumber,
      paymentDate: paymentDate,
      amountMinor: amountMinor,
      paymentAccountId: paymentAccountId,
      paymentMethod: paymentMethod,
      reference: reference,
      currency: currency,
      createdAt: createdAt,
    );
  }

  SyncOperation enqueueEstimateStatusUpdate({
    required String estimateId,
    required String status,
    DateTime? createdAt,
  }) {
    return _enqueueStatusUpdate(
      action: 'update_estimate_status',
      idPrefix: 'estimate-status',
      documentKey: 'estimate_id',
      documentId: estimateId,
      status: status,
      createdAt: createdAt,
    );
  }

  SyncOperation enqueuePurchaseOrderStatusUpdate({
    required String purchaseOrderId,
    required String status,
    DateTime? createdAt,
  }) {
    return _enqueueStatusUpdate(
      action: 'update_purchase_order_status',
      idPrefix: 'purchase-order-status',
      documentKey: 'purchase_order_id',
      documentId: purchaseOrderId,
      status: status,
      createdAt: createdAt,
    );
  }

  SyncOperation enqueueEstimateConversion({
    required String estimateId,
    required String invoiceNumber,
    required DateTime issueDate,
    required DateTime dueDate,
    required String accountsReceivableId,
    String? pdfAttachmentId,
    DateTime? createdAt,
  }) {
    final timestamp = createdAt ?? DateTime.now().toUtc();
    final operation = SyncOperation(
      id: 'estimate-conversion-${timestamp.microsecondsSinceEpoch}',
      module: 'commercial_documents',
      action: 'convert_estimate_to_invoice',
      createdAt: timestamp,
      payload: {
        'estimate_id': estimateId,
        'invoice_number': invoiceNumber,
        'issue_date': dateOnlyString(issueDate),
        'due_date': dateOnlyString(dueDate),
        'accounts_receivable_id': accountsReceivableId,
        'pdf_attachment_id': ?normalizedOptional(pdfAttachmentId),
      },
    );
    enqueue(operation);
    return operation;
  }

  SyncOperation enqueuePurchaseOrderConversion({
    required String purchaseOrderId,
    required String billNumber,
    required DateTime issueDate,
    required DateTime dueDate,
    required String accountsPayableId,
    String? documentAttachmentId,
    DateTime? createdAt,
  }) {
    final timestamp = createdAt ?? DateTime.now().toUtc();
    final operation = SyncOperation(
      id: 'purchase-order-conversion-${timestamp.microsecondsSinceEpoch}',
      module: 'commercial_documents',
      action: 'convert_purchase_order_to_bill',
      createdAt: timestamp,
      payload: {
        'purchase_order_id': purchaseOrderId,
        'bill_number': billNumber,
        'issue_date': dateOnlyString(issueDate),
        'due_date': dateOnlyString(dueDate),
        'accounts_payable_id': accountsPayableId,
        'document_attachment_id': ?normalizedOptional(documentAttachmentId),
      },
    );
    enqueue(operation);
    return operation;
  }

  SyncOperation enqueueInvoicePost({
    required String invoiceId,
    DateTime? createdAt,
  }) {
    return _enqueuePostAction(
      action: 'post_invoice',
      idPrefix: 'post-invoice',
      documentKey: 'invoice_id',
      documentId: invoiceId,
      createdAt: createdAt,
    );
  }

  SyncOperation enqueueExpensePost({
    required String expenseId,
    DateTime? createdAt,
  }) {
    return _enqueuePostAction(
      action: 'post_expense',
      idPrefix: 'post-expense',
      documentKey: 'expense_id',
      documentId: expenseId,
      createdAt: createdAt,
    );
  }

  SyncOperation enqueueBillPost({required String billId, DateTime? createdAt}) {
    return _enqueuePostAction(
      action: 'post_bill',
      idPrefix: 'post-bill',
      documentKey: 'bill_id',
      documentId: billId,
      createdAt: createdAt,
    );
  }

  SyncOperation enqueueCreditNotePost({
    required String creditNoteId,
    DateTime? createdAt,
  }) {
    return _enqueuePostAction(
      action: 'post_credit_note',
      idPrefix: 'post-credit-note',
      documentKey: 'credit_note_id',
      documentId: creditNoteId,
      createdAt: createdAt,
    );
  }

  SyncOperation _enqueuePostAction({
    required String action,
    required String idPrefix,
    required String documentKey,
    required String documentId,
    DateTime? createdAt,
  }) {
    final timestamp = createdAt ?? DateTime.now().toUtc();
    final operation = SyncOperation(
      id: '$idPrefix-${timestamp.microsecondsSinceEpoch}',
      module: 'ledger',
      action: action,
      createdAt: timestamp,
      payload: {documentKey: documentId},
    );
    enqueue(operation);
    return operation;
  }

  SyncOperation enqueueExpenseDraftUpdate({
    required String expenseId,
    required String merchantName,
    required int amountMinor,
    required String expenseAccountId,
    required String paymentAccountId,
    String? receiptAttachmentId,
    String? taxRateId,
    String? taxGroupId,
    bool taxInclusive = false,
    bool reimbursable = false,
    DateTime? createdAt,
  }) {
    final operation = enqueueExpenseDraft(
      merchantName: merchantName,
      amountMinor: amountMinor,
      expenseAccountId: expenseAccountId,
      paymentAccountId: paymentAccountId,
      receiptAttachmentId: receiptAttachmentId,
      taxRateId: taxRateId,
      taxGroupId: taxGroupId,
      taxInclusive: taxInclusive,
      reimbursable: reimbursable,
      createdAt: createdAt,
    );
    final payload = Map<String, Object?>.from(operation.payload)
      ..['expense_id'] = expenseId;
    final updated = operation.copyWith(
      id: 'expense-update-${operation.createdAt.microsecondsSinceEpoch}',
      action: 'update_draft',
      payload: payload,
    );
    _operations[_operations.length - 1] = updated;
    return updated;
  }

  SyncOperation _enqueueRawBankStatementImport({
    required String action,
    required String idPrefix,
    required String accountId,
    required String contentKey,
    required String content,
    required String fileName,
    DateTime? createdAt,
  }) {
    final timestamp = createdAt ?? DateTime.now().toUtc();
    final operation = SyncOperation(
      id: '$idPrefix-${timestamp.microsecondsSinceEpoch}',
      module: 'imports',
      action: action,
      createdAt: timestamp,
      payload: {
        'account_id': accountId,
        'file_name': ?normalizedOptional(fileName),
        contentKey: content,
      },
    );
    enqueue(operation);
    return operation;
  }

  SyncOperation _enqueueStatusUpdate({
    required String action,
    required String idPrefix,
    required String documentKey,
    required String documentId,
    required String status,
    DateTime? createdAt,
  }) {
    final timestamp = createdAt ?? DateTime.now().toUtc();
    final operation = SyncOperation(
      id: '$idPrefix-${timestamp.microsecondsSinceEpoch}',
      module: 'commercial_documents',
      action: action,
      createdAt: timestamp,
      payload: {documentKey: documentId, 'status': status},
    );
    enqueue(operation);
    return operation;
  }

  SyncOperation _enqueuePayment({
    required String module,
    required String action,
    required String idPrefix,
    required String documentKey,
    required String documentId,
    required String paymentNumber,
    required DateTime paymentDate,
    required int amountMinor,
    required String paymentAccountId,
    required String paymentMethod,
    required String reference,
    required String currency,
    DateTime? createdAt,
  }) {
    final timestamp = createdAt ?? DateTime.now().toUtc();
    final operation = SyncOperation(
      id: '$idPrefix-${timestamp.microsecondsSinceEpoch}',
      module: module,
      action: action,
      createdAt: timestamp,
      payload: {
        documentKey: documentId,
        'payment_number': paymentNumber,
        'payment_date': dateOnlyString(paymentDate),
        'payment_method': ?normalizedOptional(paymentMethod),
        'reference': ?normalizedOptional(reference),
        'currency': currency,
        'amount_minor': amountMinor,
        'payment_account_id': paymentAccountId,
      },
    );
    enqueue(operation);
    return operation;
  }

  void updateExpenseDraft({
    required String id,
    required String merchantName,
    required int amountMinor,
    String? receiptAttachmentId,
    String? taxRateId,
    String? taxGroupId,
    required bool taxInclusive,
    required bool reimbursable,
  }) {
    final index = _operations.indexWhere((operation) => operation.id == id);
    if (index == -1) {
      return;
    }

    final operation = _operations[index];
    final selectedTaxGroupId = normalizedOptional(taxGroupId);
    final selectedTaxRateId = selectedTaxGroupId == null
        ? normalizedOptional(taxRateId)
        : null;
    final nextPayload = Map<String, Object?>.from(operation.payload)
      ..['merchant_name'] = merchantName
      ..['amount_minor'] = amountMinor
      ..['receipt_attachment_id'] = receiptAttachmentId
      ..['tax_rate_id'] = selectedTaxRateId
      ..['tax_group_id'] = selectedTaxGroupId
      ..['tax_inclusive'] = taxInclusive
      ..['reimbursable'] = reimbursable;
    nextPayload.removeWhere((_, value) => value == null);

    _operations[index] = operation
        .copyWith(payload: nextPayload)
        .clearSyncState();
  }

  void updateOperation(SyncOperation operation) {
    final index = _operations.indexWhere(
      (current) => current.id == operation.id,
    );
    if (index == -1) {
      return;
    }
    _operations[index] = operation;
  }

  void markSynced(String id) {
    remove(id);
  }

  void remove(String id) {
    _operations.removeWhere((operation) => operation.id == id);
  }
}

String? normalizedOptional(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

String dateOnlyString(DateTime date) {
  final normalized = date.toUtc();
  final month = normalized.month.toString().padLeft(2, '0');
  final day = normalized.day.toString().padLeft(2, '0');
  return '${normalized.year}-$month-$day';
}
