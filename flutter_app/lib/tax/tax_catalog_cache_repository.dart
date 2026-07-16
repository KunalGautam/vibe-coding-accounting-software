import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../api/accounting_api_client.dart';
import '../storage/offline_sqlite.dart';

Future<TaxCatalogCacheRepository>
createDefaultTaxCatalogCacheRepository() async {
  final database = await openOfflineDatabase(
    fileName: 'offline-tax-catalog.sqlite',
    version: 1,
    onCreate: (database, _) => createTaxCatalogCacheTables(database),
  );
  return SqliteTaxCatalogCacheRepository(database);
}

class TaxCatalogSnapshot {
  const TaxCatalogSnapshot({this.rates = const [], this.groups = const []});

  final List<TaxRateSummary> rates;
  final List<TaxGroupSummary> groups;

  Map<String, Object?> toJson() {
    return {
      'rates': rates.map((rate) => rate.toJson()).toList(growable: false),
      'groups': groups.map((group) => group.toJson()).toList(growable: false),
    };
  }

  factory TaxCatalogSnapshot.fromJson(Map<String, Object?> json) {
    final rates = json['rates'];
    final groups = json['groups'];
    return TaxCatalogSnapshot(
      rates: rates is List
          ? rates
                .cast<Map<String, Object?>>()
                .map(TaxRateSummary.fromJson)
                .toList(growable: false)
          : const [],
      groups: groups is List
          ? groups
                .cast<Map<String, Object?>>()
                .map(TaxGroupSummary.fromJson)
                .toList(growable: false)
          : const [],
    );
  }
}

abstract interface class TaxCatalogCacheRepository {
  Future<TaxCatalogSnapshot> loadCached();

  Future<void> saveCached(TaxCatalogSnapshot snapshot);
}

class MemoryTaxCatalogCacheRepository implements TaxCatalogCacheRepository {
  MemoryTaxCatalogCacheRepository([TaxCatalogSnapshot? seed])
    : _snapshot = seed ?? const TaxCatalogSnapshot();

  TaxCatalogSnapshot _snapshot;

  @override
  Future<TaxCatalogSnapshot> loadCached() async => _snapshot;

  @override
  Future<void> saveCached(TaxCatalogSnapshot snapshot) async {
    _snapshot = snapshot;
  }
}

class FileTaxCatalogCacheRepository implements TaxCatalogCacheRepository {
  const FileTaxCatalogCacheRepository(this.file);

  final File file;

  @override
  Future<TaxCatalogSnapshot> loadCached() async {
    if (!await file.exists()) {
      return const TaxCatalogSnapshot();
    }

    final contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      return const TaxCatalogSnapshot();
    }

    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Expected tax catalog cache JSON object');
    }
    return TaxCatalogSnapshot.fromJson(decoded);
  }

  @override
  Future<void> saveCached(TaxCatalogSnapshot snapshot) async {
    await file.parent.create(recursive: true);
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(jsonEncode(snapshot.toJson()), flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }
}

class SqliteTaxCatalogCacheRepository implements TaxCatalogCacheRepository {
  const SqliteTaxCatalogCacheRepository(this.database);

  final Database database;

  @override
  Future<TaxCatalogSnapshot> loadCached() async {
    final rateRows = await database.query(
      'cached_tax_rates',
      orderBy: 'name ASC, id ASC',
    );
    final groupRows = await database.query(
      'cached_tax_groups',
      orderBy: 'name ASC, id ASC',
    );
    return TaxCatalogSnapshot(
      rates: rateRows.map(_rateFromRow).toList(growable: false),
      groups: groupRows.map(_groupFromRow).toList(growable: false),
    );
  }

  @override
  Future<void> saveCached(TaxCatalogSnapshot snapshot) async {
    await database.transaction((transaction) async {
      await transaction.delete('cached_tax_rates');
      await transaction.delete('cached_tax_groups');
      for (final rate in snapshot.rates) {
        await transaction.insert(
          'cached_tax_rates',
          _rateToRow(rate),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final group in snapshot.groups) {
        await transaction.insert(
          'cached_tax_groups',
          _groupToRow(group),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}

Future<void> createTaxCatalogCacheTables(DatabaseExecutor database) async {
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_tax_rates (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  percentage_basis INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1
)
''');
  await database.execute('''
CREATE INDEX IF NOT EXISTS idx_cached_tax_rates_name
ON cached_tax_rates (name, id)
''');
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_tax_groups (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  is_active INTEGER NOT NULL DEFAULT 1
)
''');
  await database.execute('''
CREATE INDEX IF NOT EXISTS idx_cached_tax_groups_name
ON cached_tax_groups (name, id)
''');
}

Map<String, Object?> _rateToRow(TaxRateSummary rate) {
  return {
    'id': rate.id,
    'name': rate.name,
    'type': rate.type,
    'percentage_basis': rate.percentageBasis,
    'is_active': rate.isActive ? 1 : 0,
  };
}

TaxRateSummary _rateFromRow(Map<String, Object?> row) {
  return TaxRateSummary(
    id: row['id']! as String,
    name: row['name']! as String,
    type: row['type'] as String? ?? 'GST',
    percentageBasis: row['percentage_basis'] as int? ?? 0,
    isActive: (row['is_active'] as int? ?? 1) == 1,
  );
}

Map<String, Object?> _groupToRow(TaxGroupSummary group) {
  return {
    'id': group.id,
    'name': group.name,
    'description': group.description,
    'is_active': group.isActive ? 1 : 0,
  };
}

TaxGroupSummary _groupFromRow(Map<String, Object?> row) {
  return TaxGroupSummary(
    id: row['id']! as String,
    name: row['name']! as String,
    description: row['description'] as String? ?? '',
    isActive: (row['is_active'] as int? ?? 1) == 1,
  );
}
