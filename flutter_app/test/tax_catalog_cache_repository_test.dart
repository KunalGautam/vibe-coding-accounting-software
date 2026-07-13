import 'dart:io';

import 'package:accounting_app/api/accounting_api_client.dart';
import 'package:accounting_app/tax/tax_catalog_cache_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
