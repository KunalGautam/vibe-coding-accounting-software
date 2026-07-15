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
