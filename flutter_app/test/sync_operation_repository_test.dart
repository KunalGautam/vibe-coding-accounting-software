import 'dart:io';

import 'package:accounting_app/sync/offline_sync_queue.dart';
import 'package:accounting_app/sync/sync_operation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

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

  test('sqlite repository persists and orders pending operations', () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) => createOfflineSyncTables(database),
      ),
    );
    addTearDown(database.close);
    final repository = SqliteSyncOperationRepository(database);

    await repository.savePending([
      SyncOperation(
        id: 'invoice-2',
        module: 'invoices',
        action: 'create_draft',
        createdAt: DateTime.utc(2026, 7, 12, 10),
        payload: const {'invoice_number': 'INV-002'},
      ),
      SyncOperation(
        id: 'expense-1',
        module: 'expenses',
        action: 'create_draft',
        createdAt: DateTime.utc(2026, 7, 12, 9),
        payload: const {'expense_number': 'EXP-001'},
      ),
    ]);

    final pending = await repository.loadPending();
    expect(pending.map((operation) => operation.id), [
      'expense-1',
      'invoice-2',
    ]);
    expect(pending.first.payload['expense_number'], 'EXP-001');
  });

  test('sqlite repository persists retry and conflict metadata', () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) => createOfflineSyncTables(database),
      ),
    );
    addTearDown(database.close);
    final repository = SqliteSyncOperationRepository(database);

    await repository.savePending([
      SyncOperation(
        id: 'payment-conflict',
        module: 'payments',
        action: 'record_customer',
        createdAt: DateTime.utc(2026, 7, 12, 9),
        retryCount: 3,
        lastAttemptAt: DateTime.utc(2026, 7, 12, 10),
        lastError: 'invoice already paid',
        conflictReason: 'invoice already paid',
      ),
    ]);

    final pending = await repository.loadPending();
    expect(pending.single.retryCount, 3);
    expect(pending.single.lastAttemptAt, DateTime.utc(2026, 7, 12, 10));
    expect(pending.single.lastError, 'invoice already paid');
    expect(pending.single.conflictReason, 'invoice already paid');
    expect(pending.single.hasConflict, true);
  });

  test('sqlite repository persists conflict triage updates', () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) => createOfflineSyncTables(database),
      ),
    );
    addTearDown(database.close);
    final repository = SqliteSyncOperationRepository(database);

    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'lot-conflict',
        module: 'investments',
        action: 'create_lot',
        createdAt: DateTime.utc(2026, 7, 12, 9),
        retryCount: 1,
        lastAttemptAt: DateTime.utc(2026, 7, 12, 10),
        lastError: 'lot already exists',
        conflictReason: 'lot already exists',
      ),
    ]);
    queue.clearSyncState('lot-conflict');

    await repository.savePending(queue.pending);

    final pending = await repository.loadPending();
    expect(pending.single.id, 'lot-conflict');
    expect(pending.single.retryCount, 0);
    expect(pending.single.lastAttemptAt, isNull);
    expect(pending.single.lastError, isNull);
    expect(pending.single.conflictReason, isNull);
  });
}
