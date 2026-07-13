class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.module,
    required this.action,
    required this.createdAt,
    this.payload = const {},
  });

  final String id;
  final String module;
  final String action;
  final DateTime createdAt;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'module': module,
      'action': action,
      'created_at': createdAt.toIso8601String(),
      'payload': payload,
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

    _operations[index] = SyncOperation(
      id: operation.id,
      module: operation.module,
      action: operation.action,
      createdAt: operation.createdAt,
      payload: nextPayload,
    );
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
