import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../api/accounting_api_client.dart';
import '../storage/offline_sqlite.dart';

Future<InvoiceCacheRepository> createDefaultInvoiceCacheRepository() async {
  final database = await openOfflineDatabase(
    fileName: 'offline-invoices.sqlite',
    version: 1,
    onCreate: (database, _) => createInvoiceCacheTables(database),
  );
  return SqliteInvoiceCacheRepository(database);
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

class SqliteInvoiceCacheRepository implements InvoiceCacheRepository {
  const SqliteInvoiceCacheRepository(this.database);

  final Database database;

  @override
  Future<List<InvoiceSummary>> loadCached() async {
    final invoiceRows = await database.query(
      'cached_invoices',
      orderBy: 'invoice_number ASC, id ASC',
    );
    final lineRows = await database.query(
      'cached_invoice_lines',
      orderBy: 'invoice_id ASC, line_index ASC, id ASC',
    );
    final linesByInvoice = <String, List<InvoiceLineSummary>>{};
    for (final row in lineRows) {
      final invoiceId = row['invoice_id']! as String;
      linesByInvoice
          .putIfAbsent(invoiceId, () => [])
          .add(_invoiceLineFromRow(row));
    }
    return invoiceRows
        .map(
          (row) => _invoiceFromRow(
            row,
            linesByInvoice[row['id']! as String] ?? const [],
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> saveCached(List<InvoiceSummary> invoices) async {
    await database.transaction((transaction) async {
      await transaction.delete('cached_invoice_lines');
      await transaction.delete('cached_invoices');
      for (final invoice in invoices) {
        await transaction.insert(
          'cached_invoices',
          _invoiceToRow(invoice),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        for (var index = 0; index < invoice.lines.length; index += 1) {
          await transaction.insert(
            'cached_invoice_lines',
            _invoiceLineToRow(invoice.id, index, invoice.lines[index]),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }
}

Future<void> createInvoiceCacheTables(DatabaseExecutor database) async {
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_invoices (
  id TEXT PRIMARY KEY,
  invoice_number TEXT NOT NULL,
  status TEXT NOT NULL,
  subtotal_minor INTEGER NOT NULL DEFAULT 0,
  tax_total_minor INTEGER NOT NULL DEFAULT 0,
  total_minor INTEGER NOT NULL DEFAULT 0,
  currency TEXT NOT NULL,
  pdf_attachment_id TEXT
)
''');
  await database.execute('''
CREATE INDEX IF NOT EXISTS idx_cached_invoices_number
ON cached_invoices (invoice_number, id)
''');
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_invoice_lines (
  invoice_id TEXT NOT NULL,
  line_index INTEGER NOT NULL,
  id TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  quantity_millis INTEGER NOT NULL DEFAULT 1000,
  unit_price_minor INTEGER NOT NULL DEFAULT 0,
  line_subtotal_minor INTEGER NOT NULL DEFAULT 0,
  tax_amount_minor INTEGER NOT NULL DEFAULT 0,
  line_total_minor INTEGER NOT NULL DEFAULT 0,
  income_account_id TEXT NOT NULL DEFAULT '',
  tax_rate_id TEXT,
  tax_group_id TEXT,
  PRIMARY KEY (invoice_id, line_index, id)
)
''');
  await database.execute('''
CREATE INDEX IF NOT EXISTS idx_cached_invoice_lines_invoice
ON cached_invoice_lines (invoice_id, line_index, id)
''');
}

Map<String, Object?> _invoiceToRow(InvoiceSummary invoice) {
  return {
    'id': invoice.id,
    'invoice_number': invoice.invoiceNumber,
    'status': invoice.status,
    'subtotal_minor': invoice.subtotalMinor,
    'tax_total_minor': invoice.taxTotalMinor,
    'total_minor': invoice.totalMinor,
    'currency': invoice.currency,
    'pdf_attachment_id': invoice.pdfAttachmentId,
  };
}

InvoiceSummary _invoiceFromRow(
  Map<String, Object?> row,
  List<InvoiceLineSummary> lines,
) {
  return InvoiceSummary(
    id: row['id']! as String,
    invoiceNumber: row['invoice_number']! as String,
    status: row['status']! as String,
    subtotalMinor: row['subtotal_minor'] as int? ?? 0,
    taxTotalMinor: row['tax_total_minor'] as int? ?? 0,
    totalMinor: row['total_minor'] as int? ?? 0,
    currency: row['currency'] as String? ?? 'INR',
    pdfAttachmentId: row['pdf_attachment_id'] as String?,
    lines: lines,
  );
}

Map<String, Object?> _invoiceLineToRow(
  String invoiceId,
  int index,
  InvoiceLineSummary line,
) {
  return {
    'invoice_id': invoiceId,
    'line_index': index,
    'id': line.id,
    'description': line.description,
    'quantity_millis': line.quantityMillis,
    'unit_price_minor': line.unitPriceMinor,
    'line_subtotal_minor': line.lineSubtotalMinor,
    'tax_amount_minor': line.taxAmountMinor,
    'line_total_minor': line.lineTotalMinor,
    'income_account_id': line.incomeAccountId,
    'tax_rate_id': line.taxRateId,
    'tax_group_id': line.taxGroupId,
  };
}

InvoiceLineSummary _invoiceLineFromRow(Map<String, Object?> row) {
  return InvoiceLineSummary(
    id: row['id']! as String,
    description: row['description'] as String? ?? '',
    quantityMillis: row['quantity_millis'] as int? ?? 1000,
    unitPriceMinor: row['unit_price_minor'] as int? ?? 0,
    lineSubtotalMinor: row['line_subtotal_minor'] as int? ?? 0,
    taxAmountMinor: row['tax_amount_minor'] as int? ?? 0,
    lineTotalMinor: row['line_total_minor'] as int? ?? 0,
    incomeAccountId: row['income_account_id'] as String? ?? '',
    taxRateId: row['tax_rate_id'] as String?,
    taxGroupId: row['tax_group_id'] as String?,
  );
}
