import 'dart:io';

import 'package:accounting_app/api/accounting_api_client.dart';
import 'package:accounting_app/invoices/invoice_cache_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
