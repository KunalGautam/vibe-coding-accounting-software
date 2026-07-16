import 'dart:io';

import 'package:accounting_app/api/accounting_api_client.dart';
import 'package:accounting_app/tax/tax_catalog_cache_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  const snapshot = TaxCatalogSnapshot(
    rates: [
      TaxRateSummary(
        id: 'tax-rate-1',
        name: 'GST 18%',
        type: 'GST',
        percentageBasis: 180000,
        isActive: true,
      ),
    ],
    groups: [
      TaxGroupSummary(
        id: 'tax-group-1',
        name: 'CGST + SGST 18%',
        isActive: true,
        description: 'Split GST',
      ),
    ],
  );

  test('memory tax catalog cache stores rates and groups', () async {
    final repository = MemoryTaxCatalogCacheRepository();

    await repository.saveCached(snapshot);

    final cached = await repository.loadCached();
    expect(cached.rates.single.name, 'GST 18%');
    expect(cached.groups.single.description, 'Split GST');
  });

  test(
    'file tax catalog cache persists and hydrates rates and groups',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ledger-tax-catalog-cache-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final repository = FileTaxCatalogCacheRepository(
        File('${directory.path}/tax-catalog.json'),
      );

      await repository.saveCached(snapshot);

      final cached = await repository.loadCached();
      expect(cached.rates.single.id, 'tax-rate-1');
      expect(cached.rates.single.percentageBasis, 180000);
      expect(cached.groups.single.id, 'tax-group-1');
    },
  );

  test('sqlite tax catalog cache persists rates and groups', () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) => createTaxCatalogCacheTables(database),
      ),
    );
    addTearDown(database.close);
    final repository = SqliteTaxCatalogCacheRepository(database);

    await repository.saveCached(snapshot);

    final cached = await repository.loadCached();
    expect(cached.rates.single.id, 'tax-rate-1');
    expect(cached.rates.single.percentageBasis, 180000);
    expect(cached.groups.single.name, 'CGST + SGST 18%');
    expect(cached.groups.single.description, 'Split GST');
  });

  test('sqlite tax catalog cache orders and overwrites snapshots', () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) => createTaxCatalogCacheTables(database),
      ),
    );
    addTearDown(database.close);
    final repository = SqliteTaxCatalogCacheRepository(database);

    await repository.saveCached(snapshot);
    await repository.saveCached(
      const TaxCatalogSnapshot(
        rates: [
          TaxRateSummary(
            id: 'tax-rate-b',
            name: 'GST 18%',
            type: 'GST',
            percentageBasis: 180000,
            isActive: true,
          ),
          TaxRateSummary(
            id: 'tax-rate-a',
            name: 'GST 5%',
            type: 'GST',
            percentageBasis: 50000,
            isActive: false,
          ),
        ],
        groups: [
          TaxGroupSummary(
            id: 'tax-group-b',
            name: 'Split GST 18%',
            isActive: true,
          ),
          TaxGroupSummary(
            id: 'tax-group-a',
            name: 'Composition',
            isActive: false,
            description: 'Composition scheme',
          ),
        ],
      ),
    );

    final cached = await repository.loadCached();
    expect(cached.rates.map((rate) => rate.id), ['tax-rate-b', 'tax-rate-a']);
    expect(cached.rates.last.isActive, false);
    expect(cached.groups.map((group) => group.id), [
      'tax-group-a',
      'tax-group-b',
    ]);
    expect(cached.groups.first.description, 'Composition scheme');
    expect(cached.groups.first.isActive, false);
  });
}
