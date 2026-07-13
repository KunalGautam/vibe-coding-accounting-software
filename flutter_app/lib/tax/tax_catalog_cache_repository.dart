import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../api/accounting_api_client.dart';

Future<TaxCatalogCacheRepository>
createDefaultTaxCatalogCacheRepository() async {
  final directory = await getApplicationSupportDirectory();
  return FileTaxCatalogCacheRepository(
    File('${directory.path}/cached-tax-catalog.json'),
  );
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
