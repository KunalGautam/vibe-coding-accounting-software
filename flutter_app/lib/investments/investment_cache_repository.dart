import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../api/accounting_api_client.dart';

Future<InvestmentCacheRepository>
createDefaultInvestmentCacheRepository() async {
  final directory = await getApplicationSupportDirectory();
  return FileInvestmentCacheRepository(
    File('${directory.path}/cached-investments.json'),
  );
}

class InvestmentCacheSnapshot {
  const InvestmentCacheSnapshot({
    this.lots = const [],
    this.realizedGainsReport,
    this.prices = const [],
    this.valuationReport,
  });

  final List<InvestmentLotSummary> lots;
  final RealizedGainsReport? realizedGainsReport;
  final List<InvestmentPriceSummary> prices;
  final InvestmentValuationReport? valuationReport;

  factory InvestmentCacheSnapshot.fromJson(Map<String, Object?> json) {
    return InvestmentCacheSnapshot(
      lots: (json['lots'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .map(InvestmentLotSummary.fromJson)
          .toList(growable: false),
      realizedGainsReport: json['realized_gains_report'] is Map<String, Object?>
          ? RealizedGainsReport.fromJson(
              json['realized_gains_report']! as Map<String, Object?>,
            )
          : null,
      prices: (json['prices'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .map(InvestmentPriceSummary.fromJson)
          .toList(growable: false),
      valuationReport: json['valuation_report'] is Map<String, Object?>
          ? InvestmentValuationReport.fromJson(
              json['valuation_report']! as Map<String, Object?>,
            )
          : null,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'lots': lots.map((lot) => lot.toJson()).toList(growable: false),
      if (realizedGainsReport != null)
        'realized_gains_report': realizedGainsReport!.toJson(),
      'prices': prices.map((price) => price.toJson()).toList(growable: false),
      if (valuationReport != null)
        'valuation_report': valuationReport!.toJson(),
    };
  }

  InvestmentCacheSnapshot copyWith({
    List<InvestmentLotSummary>? lots,
    RealizedGainsReport? realizedGainsReport,
    List<InvestmentPriceSummary>? prices,
    InvestmentValuationReport? valuationReport,
  }) {
    return InvestmentCacheSnapshot(
      lots: lots ?? this.lots,
      realizedGainsReport: realizedGainsReport ?? this.realizedGainsReport,
      prices: prices ?? this.prices,
      valuationReport: valuationReport ?? this.valuationReport,
    );
  }
}

abstract interface class InvestmentCacheRepository {
  Future<InvestmentCacheSnapshot> loadCached();

  Future<void> saveCached(InvestmentCacheSnapshot snapshot);
}

class MemoryInvestmentCacheRepository implements InvestmentCacheRepository {
  MemoryInvestmentCacheRepository([InvestmentCacheSnapshot? seed])
    : _snapshot = seed ?? const InvestmentCacheSnapshot();

  InvestmentCacheSnapshot _snapshot;

  @override
  Future<InvestmentCacheSnapshot> loadCached() async => _snapshot;

  @override
  Future<void> saveCached(InvestmentCacheSnapshot snapshot) async {
    _snapshot = snapshot;
  }
}

class FileInvestmentCacheRepository implements InvestmentCacheRepository {
  const FileInvestmentCacheRepository(this.file);

  final File file;

  @override
  Future<InvestmentCacheSnapshot> loadCached() async {
    if (!await file.exists()) {
      return const InvestmentCacheSnapshot();
    }

    final contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      return const InvestmentCacheSnapshot();
    }

    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Expected investment cache JSON object');
    }

    return InvestmentCacheSnapshot.fromJson(decoded);
  }

  @override
  Future<void> saveCached(InvestmentCacheSnapshot snapshot) async {
    await file.parent.create(recursive: true);
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(jsonEncode(snapshot.toJson()), flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }
}
