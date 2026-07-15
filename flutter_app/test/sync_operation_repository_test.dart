import 'dart:io';

import 'package:accounting_app/sync/offline_sync_queue.dart';
import 'package:accounting_app/sync/sync_operation_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'file repository returns an empty list before the file exists',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ledger-sync-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final repository = FileSyncOperationRepository(
        File('${directory.path}/pending-sync.json'),
      );

      expect(await repository.loadPending(), isEmpty);
    },
  );

  test('file repository persists and hydrates pending operations', () async {
    final directory = await Directory.systemTemp.createTemp('ledger-sync-test');
    addTearDown(() => directory.delete(recursive: true));
    final repository = FileSyncOperationRepository(
      File('${directory.path}/pending-sync.json'),
    );
    final operation = SyncOperation(
      id: 'expense-1',
      module: 'expenses',
      action: 'create_draft',
      createdAt: DateTime.utc(2026, 7, 12, 9),
      payload: const {
        'expense_number': 'EXP-001',
        'amount_minor': 250000,
        'expense_account_id': 'acct-expense',
        'payment_account_id': 'acct-cash',
      },
    );

    await repository.savePending([operation]);

    final pending = await repository.loadPending();
    expect(pending, hasLength(1));
    expect(pending.single.id, 'expense-1');
    expect(pending.single.payload['amount_minor'], 250000);
  });

  test('file repository persists retry and conflict metadata', () async {
    final directory = await Directory.systemTemp.createTemp('ledger-sync-test');
    addTearDown(() => directory.delete(recursive: true));
    final repository = FileSyncOperationRepository(
      File('${directory.path}/pending-sync.json'),
    );
    final operation = SyncOperation(
      id: 'expense-conflict',
      module: 'expenses',
      action: 'create_draft',
      createdAt: DateTime.utc(2026, 7, 12, 9),
      retryCount: 2,
      lastAttemptAt: DateTime.utc(2026, 7, 12, 10),
      lastError: 'duplicate expense number',
      conflictReason: 'duplicate expense number',
    );

    await repository.savePending([operation]);

    final pending = await repository.loadPending();
    expect(pending.single.retryCount, 2);
    expect(pending.single.lastAttemptAt, DateTime.utc(2026, 7, 12, 10));
    expect(pending.single.lastError, 'duplicate expense number');
    expect(pending.single.conflictReason, 'duplicate expense number');
    expect(pending.single.hasConflict, true);
  });

  test('file repository overwrites stale pending operations', () async {
    final directory = await Directory.systemTemp.createTemp('ledger-sync-test');
    addTearDown(() => directory.delete(recursive: true));
    final repository = FileSyncOperationRepository(
      File('${directory.path}/pending-sync.json'),
    );

    await repository.savePending([
      SyncOperation(
        id: 'old',
        module: 'expenses',
        action: 'create_draft',
        createdAt: DateTime.utc(2026, 7, 12, 9),
      ),
    ]);
    await repository.savePending([
      SyncOperation(
        id: 'new',
        module: 'invoices',
        action: 'cache_view',
        createdAt: DateTime.utc(2026, 7, 12, 10),
      ),
    ]);

    final pending = await repository.loadPending();
    expect(pending, hasLength(1));
    expect(pending.single.id, 'new');
  });
}
