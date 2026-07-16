import 'dart:io';

import 'package:accounting_app/api/accounting_api_client.dart';
import 'package:accounting_app/invoices/invoice_cache_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('memory invoice cache stores offline invoice summaries', () async {
    final repository = MemoryInvoiceCacheRepository();
    const invoice = InvoiceSummary(
      id: 'inv-1',
      invoiceNumber: 'INV-001',
      status: 'sent',
      subtotalMinor: 100000,
      taxTotalMinor: 18000,
      totalMinor: 118000,
      currency: 'INR',
      pdfAttachmentId: 'pdf-1',
      lines: [
        InvoiceLineSummary(
          id: 'line-1',
          description: 'Implementation',
          quantityMillis: 1000,
          unitPriceMinor: 100000,
          lineSubtotalMinor: 100000,
          taxAmountMinor: 18000,
          lineTotalMinor: 118000,
          incomeAccountId: 'income-1',
          taxGroupId: 'gst-18',
        ),
      ],
    );

    await repository.saveCached([invoice]);

    final cached = await repository.loadCached();
    expect(cached.single.invoiceNumber, 'INV-001');
    expect(cached.single.subtotalMinor, 100000);
    expect(cached.single.taxTotalMinor, 18000);
    expect(cached.single.totalMinor, 118000);
    expect(cached.single.pdfAttachmentId, 'pdf-1');
    expect(cached.single.lines.single.description, 'Implementation');
  });

  test('file invoice cache persists and hydrates invoice summaries', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ledger-invoice-cache-test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = FileInvoiceCacheRepository(
      File('${directory.path}/invoices.json'),
    );

    await repository.saveCached([
      const InvoiceSummary(
        id: 'inv-1',
        invoiceNumber: 'INV-001',
        status: 'paid',
        subtotalMinor: 200000,
        taxTotalMinor: 36000,
        totalMinor: 236000,
        currency: 'INR',
        pdfAttachmentId: 'pdf-2',
        lines: [
          InvoiceLineSummary(
            id: 'line-2',
            description: 'Annual support',
            quantityMillis: 1000,
            unitPriceMinor: 200000,
            lineSubtotalMinor: 200000,
            taxAmountMinor: 36000,
            lineTotalMinor: 236000,
            incomeAccountId: 'income-2',
            taxRateId: 'gst-rate-18',
          ),
        ],
      ),
    ]);

    final cached = await repository.loadCached();
    expect(cached, hasLength(1));
    expect(cached.single.id, 'inv-1');
    expect(cached.single.status, 'paid');
    expect(cached.single.taxTotalMinor, 36000);
    expect(cached.single.pdfAttachmentId, 'pdf-2');
    expect(cached.single.lines.single.taxRateId, 'gst-rate-18');
  });

  test('sqlite invoice cache persists invoices with lines', () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) => createInvoiceCacheTables(database),
      ),
    );
    addTearDown(database.close);
    final repository = SqliteInvoiceCacheRepository(database);

    await repository.saveCached([
      const InvoiceSummary(
        id: 'inv-1',
        invoiceNumber: 'INV-001',
        status: 'paid',
        subtotalMinor: 200000,
        taxTotalMinor: 36000,
        totalMinor: 236000,
        currency: 'INR',
        pdfAttachmentId: 'pdf-2',
        lines: [
          InvoiceLineSummary(
            id: 'line-1',
            description: 'Annual support',
            quantityMillis: 1000,
            unitPriceMinor: 200000,
            lineSubtotalMinor: 200000,
            taxAmountMinor: 36000,
            lineTotalMinor: 236000,
            incomeAccountId: 'income-2',
            taxRateId: 'gst-rate-18',
          ),
          InvoiceLineSummary(
            id: 'line-2',
            description: 'Implementation',
            quantityMillis: 500,
            unitPriceMinor: 100000,
            lineSubtotalMinor: 50000,
            taxAmountMinor: 9000,
            lineTotalMinor: 59000,
            incomeAccountId: 'income-3',
            taxGroupId: 'gst-group-18',
          ),
        ],
      ),
    ]);

    final cached = await repository.loadCached();
    expect(cached, hasLength(1));
    expect(cached.single.status, 'paid');
    expect(cached.single.pdfAttachmentId, 'pdf-2');
    expect(cached.single.lines.map((line) => line.id), ['line-1', 'line-2']);
    expect(cached.single.lines.first.taxRateId, 'gst-rate-18');
    expect(cached.single.lines.last.taxGroupId, 'gst-group-18');
  });

  test('sqlite invoice cache orders and overwrites snapshots', () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) => createInvoiceCacheTables(database),
      ),
    );
    addTearDown(database.close);
    final repository = SqliteInvoiceCacheRepository(database);

    await repository.saveCached([
      const InvoiceSummary(
        id: 'old',
        invoiceNumber: 'INV-OLD',
        status: 'draft',
        subtotalMinor: 100,
        taxTotalMinor: 0,
        totalMinor: 100,
        currency: 'INR',
      ),
    ]);
    await repository.saveCached([
      const InvoiceSummary(
        id: 'inv-2',
        invoiceNumber: 'INV-002',
        status: 'sent',
        subtotalMinor: 200,
        taxTotalMinor: 20,
        totalMinor: 220,
        currency: 'INR',
      ),
      const InvoiceSummary(
        id: 'inv-1',
        invoiceNumber: 'INV-001',
        status: 'paid',
        subtotalMinor: 100,
        taxTotalMinor: 10,
        totalMinor: 110,
        currency: 'INR',
      ),
    ]);

    final cached = await repository.loadCached();
    expect(cached.map((invoice) => invoice.id), ['inv-1', 'inv-2']);
    expect(cached.any((invoice) => invoice.id == 'old'), false);
  });
}
