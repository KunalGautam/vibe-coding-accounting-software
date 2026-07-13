import 'dart:io';

import 'package:accounting_app/accounts/account_cache_repository.dart';
import 'package:accounting_app/api/accounting_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
