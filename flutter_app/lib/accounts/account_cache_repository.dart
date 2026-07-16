import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../api/accounting_api_client.dart';
import '../storage/offline_sqlite.dart';

Future<AccountCacheRepository> createDefaultAccountCacheRepository() async {
  final database = await openOfflineDatabase(
    fileName: 'offline-accounts.sqlite',
    version: 1,
    onCreate: (database, _) => createAccountCacheTables(database),
  );
  return SqliteAccountCacheRepository(database);
}

abstract interface class AccountCacheRepository {
  Future<List<AccountSummary>> loadCached();

  Future<void> saveCached(List<AccountSummary> accounts);
}

class MemoryAccountCacheRepository implements AccountCacheRepository {
  MemoryAccountCacheRepository([List<AccountSummary>? seed])
    : _accounts = [...?seed];

  final List<AccountSummary> _accounts;

  @override
  Future<List<AccountSummary>> loadCached() async {
    return List.unmodifiable(_accounts);
  }

  @override
  Future<void> saveCached(List<AccountSummary> accounts) async {
    _accounts
      ..clear()
      ..addAll(accounts);
  }
}

class FileAccountCacheRepository implements AccountCacheRepository {
  const FileAccountCacheRepository(this.file);

  final File file;

  @override
  Future<List<AccountSummary>> loadCached() async {
    if (!await file.exists()) {
      return [];
    }

    final contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      return [];
    }

    final decoded = jsonDecode(contents);
    if (decoded is! List) {
      throw const FormatException('Expected account cache JSON array');
    }

    return decoded
        .cast<Map<String, Object?>>()
        .map(AccountSummary.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> saveCached(List<AccountSummary> accounts) async {
    await file.parent.create(recursive: true);
    final tempFile = File('${file.path}.tmp');
    final encoded = jsonEncode(
      accounts.map((account) => account.toJson()).toList(growable: false),
    );

    await tempFile.writeAsString(encoded, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }
}

class SqliteAccountCacheRepository implements AccountCacheRepository {
  const SqliteAccountCacheRepository(this.database);

  final Database database;

  @override
  Future<List<AccountSummary>> loadCached() async {
    final rows = await database.query(
      'cached_accounts',
      orderBy: 'code ASC, name ASC, id ASC',
    );
    return rows.map(_accountFromRow).toList(growable: false);
  }

  @override
  Future<void> saveCached(List<AccountSummary> accounts) async {
    await database.transaction((transaction) async {
      await transaction.delete('cached_accounts');
      for (final account in accounts) {
        await transaction.insert(
          'cached_accounts',
          _accountToRow(account),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}

Future<void> createAccountCacheTables(DatabaseExecutor database) async {
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_accounts (
  id TEXT PRIMARY KEY,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  currency TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1
)
''');
  await database.execute('''
CREATE INDEX IF NOT EXISTS idx_cached_accounts_code_name
ON cached_accounts (code, name, id)
''');
}

Map<String, Object?> _accountToRow(AccountSummary account) {
  return {
    'id': account.id,
    'code': account.code,
    'name': account.name,
    'type': account.type,
    'currency': account.currency,
    'is_active': account.isActive ? 1 : 0,
  };
}

AccountSummary _accountFromRow(Map<String, Object?> row) {
  return AccountSummary(
    id: row['id']! as String,
    code: row['code']! as String,
    name: row['name']! as String,
    type: row['type']! as String,
    currency: row['currency'] as String? ?? 'INR',
    isActive: (row['is_active'] as int? ?? 1) == 1,
  );
}
