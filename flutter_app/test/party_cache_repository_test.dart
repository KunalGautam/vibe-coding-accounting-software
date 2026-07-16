import 'dart:io';

import 'package:accounting_app/api/accounting_api_client.dart';
import 'package:accounting_app/parties/party_cache_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  const snapshot = PartySnapshot(
    customers: [
      CustomerSummary(
        id: 'customer-1',
        organizationId: 'org-1',
        displayName: 'Acme Exports',
        email: 'billing@acme.test',
        phone: '+91-99999-00001',
        billingAddress: 'Mumbai',
        gstin: '27ABCDE1234F1Z5',
        isActive: true,
      ),
    ],
    vendors: [
      VendorSummary(
        id: 'vendor-1',
        organizationId: 'org-1',
        displayName: 'Stationery House',
        email: 'ap@stationery.test',
        phone: '+91-99999-00002',
        billingAddress: 'Pune',
        gstin: '27ABCDE1234F1Z6',
        isActive: true,
      ),
    ],
  );

  test('memory party cache stores customers and vendors', () async {
    final repository = MemoryPartyCacheRepository();

    await repository.saveCached(snapshot);

    final cached = await repository.loadCached();
    expect(cached.customers.single.displayName, 'Acme Exports');
    expect(cached.vendors.single.displayName, 'Stationery House');
  });

  test('file party cache persists customers and vendors', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ledger-party-cache-test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = FilePartyCacheRepository(
      File('${directory.path}/parties.json'),
    );

    await repository.saveCached(snapshot);

    final cached = await repository.loadCached();
    expect(cached.customers.single.gstin, '27ABCDE1234F1Z5');
    expect(cached.vendors.single.email, 'ap@stationery.test');
  });

  test('sqlite party cache persists and orders party snapshots', () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) => createPartyCacheTables(database),
      ),
    );
    addTearDown(database.close);
    final repository = SqlitePartyCacheRepository(database);

    await repository.saveCached(
      const PartySnapshot(
        customers: [
          CustomerSummary(
            id: 'customer-z',
            organizationId: 'org-1',
            displayName: 'Zenith Retail',
            isActive: true,
          ),
          CustomerSummary(
            id: 'customer-a',
            organizationId: 'org-1',
            displayName: 'Acme Exports',
            isActive: false,
          ),
        ],
        vendors: [
          VendorSummary(
            id: 'vendor-z',
            organizationId: 'org-1',
            displayName: 'Zenith Supplies',
            isActive: true,
          ),
          VendorSummary(
            id: 'vendor-a',
            organizationId: 'org-1',
            displayName: 'Alpha Logistics',
            isActive: false,
          ),
        ],
      ),
    );

    final cached = await repository.loadCached();
    expect(cached.customers.map((party) => party.id), [
      'customer-a',
      'customer-z',
    ]);
    expect(cached.customers.first.isActive, false);
    expect(cached.vendors.map((party) => party.id), ['vendor-a', 'vendor-z']);
    expect(cached.vendors.first.isActive, false);
  });
}
