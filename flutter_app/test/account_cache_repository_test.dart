import 'dart:io';

import 'package:accounting_app/accounts/account_cache_repository.dart';
import 'package:accounting_app/api/accounting_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  const accounts = [
    AccountSummary(
      id: 'acct-expense',
      code: '5000',
      name: 'Office Supplies',
      type: 'expense',
      currency: 'INR',
      isActive: true,
    ),
  ];

  test('memory account cache stores account summaries', () async {
    final repository = MemoryAccountCacheRepository();

    await repository.saveCached(accounts);

    final cached = await repository.loadCached();
    expect(cached.single.id, 'acct-expense');
    expect(cached.single.name, 'Office Supplies');
  });

  test('file account cache persists and hydrates account summaries', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ledger-account-cache-test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = FileAccountCacheRepository(
      File('${directory.path}/accounts.json'),
    );

    await repository.saveCached(accounts);

    final cached = await repository.loadCached();
    expect(cached, hasLength(1));
    expect(cached.single.code, '5000');
    expect(cached.single.currency, 'INR');
  });

  test('sqlite account cache persists and orders account summaries', () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) => createAccountCacheTables(database),
      ),
    );
    addTearDown(database.close);
    final repository = SqliteAccountCacheRepository(database);

    await repository.saveCached([
      const AccountSummary(
        id: 'acct-cash',
        code: '1000',
        name: 'Cash',
        type: 'asset',
        currency: 'INR',
        isActive: true,
      ),
      const AccountSummary(
        id: 'acct-expense',
        code: '5000',
        name: 'Office Supplies',
        type: 'expense',
        currency: 'INR',
        isActive: false,
      ),
    ]);

    final cached = await repository.loadCached();
    expect(cached.map((account) => account.id), ['acct-cash', 'acct-expense']);
    expect(cached.last.isActive, false);
    expect(cached.last.type, 'expense');
  });

  test('sqlite account cache overwrites stale account snapshots', () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) => createAccountCacheTables(database),
      ),
    );
    addTearDown(database.close);
    final repository = SqliteAccountCacheRepository(database);

    await repository.saveCached(accounts);
    await repository.saveCached([
      const AccountSummary(
        id: 'acct-bank',
        code: '1010',
        name: 'Bank',
        type: 'asset',
        currency: 'INR',
        isActive: true,
      ),
    ]);

    final cached = await repository.loadCached();
    expect(cached, hasLength(1));
    expect(cached.single.id, 'acct-bank');
  });
}
