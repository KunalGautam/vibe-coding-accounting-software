import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../api/accounting_api_client.dart';

Future<InvoiceCacheRepository> createDefaultInvoiceCacheRepository() async {
  final directory = await getApplicationSupportDirectory();
  return FileInvoiceCacheRepository(
    File('${directory.path}/cached-invoices.json'),
  );
}

abstract interface class InvoiceCacheRepository {
  Future<List<InvoiceSummary>> loadCached();

  Future<void> saveCached(List<InvoiceSummary> invoices);
}

class MemoryInvoiceCacheRepository implements InvoiceCacheRepository {
  MemoryInvoiceCacheRepository([List<InvoiceSummary>? seed])
    : _invoices = [...?seed];

  final List<InvoiceSummary> _invoices;

  @override
  Future<List<InvoiceSummary>> loadCached() async {
    return List.unmodifiable(_invoices);
  }

  @override
  Future<void> saveCached(List<InvoiceSummary> invoices) async {
    _invoices
      ..clear()
      ..addAll(invoices);
  }
}

class FileInvoiceCacheRepository implements InvoiceCacheRepository {
  const FileInvoiceCacheRepository(this.file);

  final File file;

  @override
  Future<List<InvoiceSummary>> loadCached() async {
    if (!await file.exists()) {
      return [];
    }

    final contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      return [];
    }

    final decoded = jsonDecode(contents);
    if (decoded is! List) {
      throw const FormatException('Expected invoice cache JSON array');
    }

    return decoded
        .cast<Map<String, Object?>>()
        .map(InvoiceSummary.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> saveCached(List<InvoiceSummary> invoices) async {
    await file.parent.create(recursive: true);
    final tempFile = File('${file.path}.tmp');
    final encoded = jsonEncode(
      invoices.map((invoice) => invoice.toJson()).toList(growable: false),
    );

    await tempFile.writeAsString(encoded, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }
}
