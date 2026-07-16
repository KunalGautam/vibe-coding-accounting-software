import 'dart:io';

import 'package:accounting_app/api/accounting_api_client.dart';
import 'package:accounting_app/investments/investment_cache_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  final lot = InvestmentLotSummary(
    id: 'lot-1',
    accountId: 'brokerage-1',
    symbol: 'NIFTYBEES',
    securityName: 'Nippon India ETF Nifty BeES',
    acquisitionDate: DateTime.utc(2026, 4),
    quantityMillis: 100000,
    remainingQuantityMillis: 60000,
    costBasisMinor: 1000000,
    currency: 'INR',
    costMethod: 'specific_lot',
  );

  final report = RealizedGainsReport(
    fromDate: DateTime.utc(2026, 4),
    toDate: DateTime.utc(2026, 7, 31),
    rows: [
      InvestmentDispositionSummary(
        id: 'disp-1',
        investmentLotId: 'lot-1',
        saleDate: DateTime.utc(2026, 7, 12),
        quantityMillis: 40000,
        proceedsMinor: 520000,
        allocatedCostBasisMinor: 400000,
        realizedGainLossMinor: 120000,
        currency: 'INR',
      ),
    ],
    totalProceedsMinor: 520000,
    totalCostBasisMinor: 400000,
    totalGainLossMinor: 120000,
  );
  final price = InvestmentPriceSummary(
    id: 'price-1',
    symbol: 'NIFTYBEES',
    priceDate: DateTime.utc(2026, 7, 31),
    priceMinor: 14000,
    currency: 'INR',
    source: 'manual',
  );
  final valuation = InvestmentValuationReport(
    asOfDate: DateTime.utc(2026, 7, 31),
    rows: [
      InvestmentValuationRow(
        lotId: 'lot-1',
        accountId: 'brokerage-1',
        symbol: 'NIFTYBEES',
        securityName: 'Nippon India ETF Nifty BeES',
        acquisitionDate: DateTime.utc(2026, 4),
        remainingQuantityMillis: 60000,
        remainingCostBasisMinor: 600000,
        marketPriceMinor: 14000,
        marketValueMinor: 840000,
        unrealizedGainLossMinor: 240000,
        currency: 'INR',
        priceDate: DateTime.utc(2026, 7, 31),
      ),
    ],
    totalCostBasisMinor: 600000,
    totalMarketValueMinor: 840000,
    totalUnrealizedGainLossMinor: 240000,
  );

  test('memory investment cache stores investment reports', () async {
    final repository = MemoryInvestmentCacheRepository();

    await repository.saveCached(
      InvestmentCacheSnapshot(
        lots: [lot],
        realizedGainsReport: report,
        prices: [price],
        valuationReport: valuation,
      ),
    );

    final cached = await repository.loadCached();
    expect(cached.lots.single.symbol, 'NIFTYBEES');
    expect(cached.realizedGainsReport?.totalGainLossMinor, 120000);
    expect(cached.prices.single.priceMinor, 14000);
    expect(cached.valuationReport?.totalUnrealizedGainLossMinor, 240000);
  });

  test('file investment cache persists and hydrates snapshot', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ledger-investment-cache-test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = FileInvestmentCacheRepository(
      File('${directory.path}/investments.json'),
    );

    await repository.saveCached(
      InvestmentCacheSnapshot(
        lots: [lot],
        realizedGainsReport: report,
        prices: [price],
        valuationReport: valuation,
      ),
    );

    final cached = await repository.loadCached();
    expect(cached.lots, hasLength(1));
    expect(cached.lots.single.remainingQuantityMillis, 60000);
    expect(
      cached.realizedGainsReport?.rows.single.realizedGainLossMinor,
      120000,
    );
    expect(cached.prices.single.symbol, 'NIFTYBEES');
    expect(cached.valuationReport?.rows.single.marketValueMinor, 840000);
  });

  test('sqlite investment cache persists full investment snapshot', () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) => createInvestmentCacheTables(database),
      ),
    );
    addTearDown(database.close);
    final repository = SqliteInvestmentCacheRepository(database);

    await repository.saveCached(
      InvestmentCacheSnapshot(
        lots: [lot],
        realizedGainsReport: report,
        prices: [price],
        valuationReport: valuation,
      ),
    );

    final cached = await repository.loadCached();
    expect(cached.lots.single.id, 'lot-1');
    expect(cached.lots.single.securityName, 'Nippon India ETF Nifty BeES');
    expect(cached.realizedGainsReport?.rows.single.investmentLotId, 'lot-1');
    expect(cached.realizedGainsReport?.totalGainLossMinor, 120000);
    expect(cached.prices.single.priceMinor, 14000);
    expect(cached.valuationReport?.rows.single.marketValueMinor, 840000);
    expect(cached.valuationReport?.totalUnrealizedGainLossMinor, 240000);
  });

  test(
    'sqlite investment cache orders lots and replaces stale snapshots',
    () async {
      final database = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (database, _) => createInvestmentCacheTables(database),
        ),
      );
      addTearDown(database.close);
      final repository = SqliteInvestmentCacheRepository(database);

      await repository.saveCached(InvestmentCacheSnapshot(lots: [lot]));
      await repository.saveCached(
        InvestmentCacheSnapshot(
          lots: [
            InvestmentLotSummary(
              id: 'lot-z',
              accountId: 'brokerage-1',
              symbol: 'ZZZ',
              acquisitionDate: DateTime.utc(2026, 5),
              quantityMillis: 1000,
              remainingQuantityMillis: 1000,
              costBasisMinor: 10000,
              currency: 'INR',
              costMethod: 'specific_lot',
            ),
            InvestmentLotSummary(
              id: 'lot-a',
              accountId: 'brokerage-1',
              symbol: 'AAA',
              acquisitionDate: DateTime.utc(2026, 5),
              quantityMillis: 1000,
              remainingQuantityMillis: 1000,
              costBasisMinor: 10000,
              currency: 'INR',
              costMethod: 'specific_lot',
            ),
          ],
        ),
      );

      final cached = await repository.loadCached();
      expect(cached.lots.map((cachedLot) => cachedLot.id), ['lot-a', 'lot-z']);
      expect(cached.realizedGainsReport, isNull);
      expect(cached.valuationReport, isNull);
      expect(cached.lots.any((cachedLot) => cachedLot.id == 'lot-1'), false);
    },
  );
}
