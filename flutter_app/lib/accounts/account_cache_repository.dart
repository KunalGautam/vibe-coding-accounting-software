import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../api/accounting_api_client.dart';

Future<AccountCacheRepository> createDefaultAccountCacheRepository() async {
  final directory = await getApplicationSupportDirectory();
  return FileAccountCacheRepository(
    File('${directory.path}/cached-accounts.json'),
  );
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
