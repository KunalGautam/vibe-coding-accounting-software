import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../api/accounting_api_client.dart';
import '../storage/offline_sqlite.dart';

Future<PartyCacheRepository> createDefaultPartyCacheRepository() async {
  final database = await openOfflineDatabase(
    fileName: 'offline-parties.sqlite',
    version: 1,
    onCreate: (database, _) => createPartyCacheTables(database),
  );
  return SqlitePartyCacheRepository(database);
}

class PartySnapshot {
  const PartySnapshot({this.customers = const [], this.vendors = const []});

  final List<CustomerSummary> customers;
  final List<VendorSummary> vendors;
}

abstract interface class PartyCacheRepository {
  Future<PartySnapshot> loadCached();

  Future<void> saveCached(PartySnapshot snapshot);
}

class MemoryPartyCacheRepository implements PartyCacheRepository {
  MemoryPartyCacheRepository([PartySnapshot? seed])
    : _snapshot = seed ?? const PartySnapshot();

  PartySnapshot _snapshot;

  @override
  Future<PartySnapshot> loadCached() async {
    return PartySnapshot(
      customers: List.unmodifiable(_snapshot.customers),
      vendors: List.unmodifiable(_snapshot.vendors),
    );
  }

  @override
  Future<void> saveCached(PartySnapshot snapshot) async {
    _snapshot = PartySnapshot(
      customers: [...snapshot.customers],
      vendors: [...snapshot.vendors],
    );
  }
}

class FilePartyCacheRepository implements PartyCacheRepository {
  const FilePartyCacheRepository(this.file);

  final File file;

  @override
  Future<PartySnapshot> loadCached() async {
    if (!await file.exists()) {
      return const PartySnapshot();
    }
    final contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      return const PartySnapshot();
    }
    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Expected party cache JSON object');
    }
    return PartySnapshot(
      customers: (decoded['customers'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .map(CustomerSummary.fromJson)
          .toList(growable: false),
      vendors: (decoded['vendors'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .map(VendorSummary.fromJson)
          .toList(growable: false),
    );
  }

  @override
  Future<void> saveCached(PartySnapshot snapshot) async {
    await file.parent.create(recursive: true);
    final tempFile = File('${file.path}.tmp');
    final encoded = jsonEncode({
      'customers': snapshot.customers
          .map((customer) => customer.toJson())
          .toList(growable: false),
      'vendors': snapshot.vendors
          .map((vendor) => vendor.toJson())
          .toList(growable: false),
    });
    await tempFile.writeAsString(encoded, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }
}

class SqlitePartyCacheRepository implements PartyCacheRepository {
  const SqlitePartyCacheRepository(this.database);

  final Database database;

  @override
  Future<PartySnapshot> loadCached() async {
    final customerRows = await database.query(
      'cached_customers',
      orderBy: 'display_name ASC, id ASC',
    );
    final vendorRows = await database.query(
      'cached_vendors',
      orderBy: 'display_name ASC, id ASC',
    );
    return PartySnapshot(
      customers: customerRows.map(_customerFromRow).toList(growable: false),
      vendors: vendorRows.map(_vendorFromRow).toList(growable: false),
    );
  }

  @override
  Future<void> saveCached(PartySnapshot snapshot) async {
    await database.transaction((transaction) async {
      await transaction.delete('cached_customers');
      await transaction.delete('cached_vendors');
      for (final customer in snapshot.customers) {
        await transaction.insert(
          'cached_customers',
          _customerToRow(customer),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final vendor in snapshot.vendors) {
        await transaction.insert(
          'cached_vendors',
          _vendorToRow(vendor),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}

Future<void> createPartyCacheTables(DatabaseExecutor database) async {
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_customers (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL DEFAULT '',
  display_name TEXT NOT NULL,
  email TEXT NOT NULL DEFAULT '',
  phone TEXT NOT NULL DEFAULT '',
  billing_address TEXT NOT NULL DEFAULT '',
  gstin TEXT NOT NULL DEFAULT '',
  is_active INTEGER NOT NULL DEFAULT 1
)
''');
  await database.execute('''
CREATE INDEX IF NOT EXISTS idx_cached_customers_display_name
ON cached_customers (display_name, id)
''');
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_vendors (
  id TEXT PRIMARY KEY,
  organization_id TEXT NOT NULL DEFAULT '',
  display_name TEXT NOT NULL,
  email TEXT NOT NULL DEFAULT '',
  phone TEXT NOT NULL DEFAULT '',
  billing_address TEXT NOT NULL DEFAULT '',
  gstin TEXT NOT NULL DEFAULT '',
  is_active INTEGER NOT NULL DEFAULT 1
)
''');
  await database.execute('''
CREATE INDEX IF NOT EXISTS idx_cached_vendors_display_name
ON cached_vendors (display_name, id)
''');
}

Map<String, Object?> _customerToRow(CustomerSummary customer) {
  return {
    'id': customer.id,
    'organization_id': customer.organizationId,
    'display_name': customer.displayName,
    'email': customer.email,
    'phone': customer.phone,
    'billing_address': customer.billingAddress,
    'gstin': customer.gstin,
    'is_active': customer.isActive ? 1 : 0,
  };
}

CustomerSummary _customerFromRow(Map<String, Object?> row) {
  return CustomerSummary(
    id: row['id']! as String,
    organizationId: row['organization_id'] as String? ?? '',
    displayName: row['display_name']! as String,
    email: row['email'] as String? ?? '',
    phone: row['phone'] as String? ?? '',
    billingAddress: row['billing_address'] as String? ?? '',
    gstin: row['gstin'] as String? ?? '',
    isActive: (row['is_active'] as int? ?? 1) == 1,
  );
}

Map<String, Object?> _vendorToRow(VendorSummary vendor) {
  return {
    'id': vendor.id,
    'organization_id': vendor.organizationId,
    'display_name': vendor.displayName,
    'email': vendor.email,
    'phone': vendor.phone,
    'billing_address': vendor.billingAddress,
    'gstin': vendor.gstin,
    'is_active': vendor.isActive ? 1 : 0,
  };
}

VendorSummary _vendorFromRow(Map<String, Object?> row) {
  return VendorSummary(
    id: row['id']! as String,
    organizationId: row['organization_id'] as String? ?? '',
    displayName: row['display_name']! as String,
    email: row['email'] as String? ?? '',
    phone: row['phone'] as String? ?? '',
    billingAddress: row['billing_address'] as String? ?? '',
    gstin: row['gstin'] as String? ?? '',
    isActive: (row['is_active'] as int? ?? 1) == 1,
  );
}
