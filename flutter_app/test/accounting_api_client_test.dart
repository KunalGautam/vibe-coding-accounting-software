import 'dart:convert';

import 'package:accounting_app/api/accounting_api_client.dart';
import 'package:accounting_app/sync/offline_sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const config = AccountingApiConfig(
    baseUrl: 'http://localhost:8080/api/v1',
    accessToken: 'access-token',
    organizationId: 'org-1',
  );

  test('lists accounts with organization path and bearer token', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.toString(),
          'http://localhost:8080/api/v1/organizations/org-1/accounts',
        );
        expect(request.headers['Authorization'], 'Bearer access-token');
        return http.Response(
          jsonEncode([
            {
              'id': 'acct-1',
              'code': '1000',
              'name': 'Cash',
              'type': 'asset',
              'currency': 'INR',
              'is_active': true,
            },
          ]),
          200,
        );
      }),
    );

    final accounts = await client.listAccounts();

    expect(accounts, hasLength(1));
    expect(accounts.single.name, 'Cash');
  });

  test('lists invoice and expense summaries', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/invoices')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'inv-1',
                'invoice_number': 'INV-001',
                'status': 'draft',
                'subtotal_minor': 100000,
                'tax_total_minor': 18000,
                'total_minor': 118000,
                'currency': 'INR',
                'pdf_attachment_id': 'pdf-1',
                'lines': [
                  {
                    'id': 'line-1',
                    'description': 'Consulting services',
                    'quantity_millis': 1000,
                    'unit_price_minor': 100000,
                    'line_subtotal_minor': 100000,
                    'tax_amount_minor': 18000,
                    'line_total_minor': 118000,
                    'income_account_id': 'income-1',
                    'tax_group_id': 'gst-18',
                  },
                ],
              },
            ]),
            200,
          );
        }
        return http.Response(
          jsonEncode([
            {
              'id': 'exp-1',
              'expense_number': 'EXP-001',
              'status': 'draft',
              'total_minor': 59000,
              'currency': 'INR',
            },
          ]),
          200,
        );
      }),
    );

    final invoices = await client.listInvoices();
    final expenses = await client.listExpenses();

    expect(invoices.single.invoiceNumber, 'INV-001');
    expect(invoices.single.subtotalMinor, 100000);
    expect(invoices.single.taxTotalMinor, 18000);
    expect(invoices.single.pdfAttachmentId, 'pdf-1');
    expect(invoices.single.lines.single.description, 'Consulting services');
    expect(invoices.single.lines.single.taxGroupId, 'gst-18');
    expect(expenses.single.expenseNumber, 'EXP-001');
  });

  test('lists tax rates and groups', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/tax/rates')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'tax-rate-1',
                'name': 'GST 18%',
                'type': 'GST',
                'percentage_basis': 180000,
                'is_active': true,
              },
            ]),
            200,
          );
        }
        return http.Response(
          jsonEncode([
            {
              'id': 'tax-group-1',
              'name': 'CGST + SGST 18%',
              'description': 'Split GST',
              'is_active': true,
            },
          ]),
          200,
        );
      }),
    );

    final rates = await client.listTaxRates();
    final groups = await client.listTaxGroups();

    expect(rates.single.name, 'GST 18%');
    expect(rates.single.percentageBasis, 180000);
    expect(groups.single.description, 'Split GST');
  });

  test('lists investment lots and realized gains', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/investments/lots')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'lot-1',
                'account_id': 'brokerage-1',
                'symbol': 'NIFTYBEES',
                'security_name': 'Nippon India ETF Nifty BeES',
                'acquisition_date': '2026-04-01T00:00:00Z',
                'quantity_millis': 100000,
                'remaining_quantity_millis': 60000,
                'cost_basis_minor': 1000000,
                'currency': 'INR',
                'cost_method': 'specific_lot',
              },
            ]),
            200,
          );
        }

        expect(request.url.path.endsWith('/reports/realized-gains'), isTrue);
        expect(request.url.queryParameters['from'], '2026-04-01');
        expect(request.url.queryParameters['to'], '2026-07-31');
        return http.Response(
          jsonEncode({
            'from_date': '2026-04-01T00:00:00Z',
            'to_date': '2026-07-31T00:00:00Z',
            'total_proceeds_minor': 520000,
            'total_cost_basis_minor': 400000,
            'total_gain_loss_minor': 120000,
            'rows': [
              {
                'id': 'disp-1',
                'investment_lot_id': 'lot-1',
                'sale_date': '2026-07-12T00:00:00Z',
                'quantity_millis': 40000,
                'proceeds_minor': 520000,
                'allocated_cost_basis_minor': 400000,
                'realized_gain_loss_minor': 120000,
                'currency': 'INR',
              },
            ],
          }),
          200,
        );
      }),
    );

    final lots = await client.listInvestmentLots();
    final report = await client.getRealizedGains(
      from: DateTime.utc(2026, 4),
      to: DateTime.utc(2026, 7, 31),
    );

    expect(lots.single.symbol, 'NIFTYBEES');
    expect(lots.single.remainingQuantityMillis, 60000);
    expect(report.totalGainLossMinor, 120000);
    expect(report.rows.single.investmentLotId, 'lot-1');
  });

  test(
    'handles investment prices, valuation, and average-cost sales',
    () async {
      final client = AccountingApiClient(
        config: config,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/investments/prices')) {
            if (request.method == 'GET') {
              return http.Response(
                jsonEncode([
                  {
                    'id': 'price-1',
                    'symbol': 'LIQUIDFUND',
                    'price_date': '2026-07-31T00:00:00Z',
                    'price_minor': 14000,
                    'currency': 'INR',
                    'source': 'manual',
                  },
                ]),
                200,
              );
            }
            final body = jsonDecode(request.body) as Map<String, Object?>;
            expect(body['symbol'], 'LIQUIDFUND');
            expect(body['price_date'], '2026-07-31');
            return http.Response(
              jsonEncode({
                'id': 'price-2',
                ...body,
                'price_date': '2026-07-31T00:00:00Z',
              }),
              201,
            );
          }

          if (request.url.path.endsWith('/reports/investment-valuation')) {
            expect(request.url.queryParameters['as_of'], '2026-07-31');
            return http.Response(
              jsonEncode({
                'as_of_date': '2026-07-31T00:00:00Z',
                'total_cost_basis_minor': 2250000,
                'total_market_value_minor': 2400000,
                'total_unrealized_gain_loss_minor': 150000,
                'rows': [
                  {
                    'lot_id': 'lot-1',
                    'account_id': 'brokerage-1',
                    'symbol': 'LIQUIDFUND',
                    'security_name': 'Liquid Fund',
                    'acquisition_date': '2026-04-01T00:00:00Z',
                    'remaining_quantity_millis': 150000,
                    'remaining_cost_basis_minor': 2250000,
                    'market_price_minor': 16000,
                    'market_value_minor': 2400000,
                    'unrealized_gain_loss_minor': 150000,
                    'currency': 'INR',
                    'price_date': '2026-07-31T00:00:00Z',
                  },
                ],
              }),
              200,
            );
          }

          expect(
            request.url.path.endsWith('/investments/average-cost-sales'),
            isTrue,
          );
          final body = jsonDecode(request.body) as Map<String, Object?>;
          expect(body['account_id'], 'brokerage-1');
          expect(body['symbol'], 'LIQUIDFUND');
          expect(body['quantity_millis'], 150000);
          return http.Response(
            jsonEncode({
              'quantity_millis': 150000,
              'proceeds_minor': 2400000,
              'allocated_cost_basis_minor': 2250000,
              'realized_gain_loss_minor': 150000,
              'journal_transaction_id': 'journal-1',
              'dispositions': [
                {
                  'id': 'disp-avg-1',
                  'investment_lot_id': 'lot-1',
                  'sale_date': '2026-07-31T00:00:00Z',
                  'quantity_millis': 150000,
                  'proceeds_minor': 2400000,
                  'allocated_cost_basis_minor': 2250000,
                  'realized_gain_loss_minor': 150000,
                  'currency': 'INR',
                },
              ],
            }),
            201,
          );
        }),
      );

      final prices = await client.listInvestmentPrices();
      final createdPrice = await client.createInvestmentPrice(
        CreateInvestmentPriceRequest(
          symbol: 'LIQUIDFUND',
          priceDate: DateTime.utc(2026, 7, 31),
          priceMinor: 14000,
        ),
      );
      final valuation = await client.getInvestmentValuation(
        asOf: DateTime.utc(2026, 7, 31),
      );
      final sale = await client.sellAverageCost(
        SellAverageCostRequest(
          accountId: 'brokerage-1',
          symbol: 'LIQUIDFUND',
          saleDate: DateTime.utc(2026, 7, 31),
          quantityMillis: 150000,
          proceedsMinor: 2400000,
        ),
      );

      expect(prices.single.priceMinor, 14000);
      expect(createdPrice.id, 'price-2');
      expect(valuation.totalUnrealizedGainLossMinor, 150000);
      expect(valuation.rows.single.marketValueMinor, 2400000);
      expect(sale.journalTransactionId, 'journal-1');
      expect(sale.dispositions.single.realizedGainLossMinor, 150000);
    },
  );

  test('imports structured bank statement lines', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/bank-statements/import',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['account_id'], 'acct-bank');
        expect(body['file_name'], 'july-bank.csv');
        expect(body['format'], 'csv');
        final lines = body['lines']! as List;
        final line = lines.single as Map<String, Object?>;
        expect(line['posted_date'], '2026-07-15');
        expect(line['description'], 'UPI receipt');
        expect(line['amount_minor'], 125000);
        expect(line['reference'], 'UPI123');
        return http.Response(
          jsonEncode({
            'id': 'bank-import-1',
            'organization_id': 'org-1',
            'account_id': 'acct-bank',
            'file_name': 'july-bank.csv',
            'format': 'csv',
            'status': 'completed',
            'line_count': 1,
            'lines': [
              {
                'id': 'bank-line-1',
                'organization_id': 'org-1',
                'account_id': 'acct-bank',
                'posted_date': '2026-07-15T00:00:00Z',
                'description': 'UPI receipt',
                'amount_minor': 125000,
                'reference': 'UPI123',
                'is_duplicate': false,
              },
            ],
          }),
          201,
        );
      }),
    );

    final imported = await client.importStructuredBankStatement(
      ImportBankStatementRequest(
        accountId: 'acct-bank',
        fileName: 'july-bank.csv',
        lines: [
          ImportBankStatementLineRequest(
            postedDate: DateTime.utc(2026, 7, 15),
            description: 'UPI receipt',
            amountMinor: 125000,
            reference: 'UPI123',
          ),
        ],
      ),
    );

    expect(imported.id, 'bank-import-1');
    expect(imported.lineCount, 1);
    expect(imported.lines.single.description, 'UPI receipt');
    expect(imported.lines.single.isDuplicate, false);
  });

  test('imports QIF and OFX bank statement content', () async {
    final requestedPaths = <String>[];
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        requestedPaths.add(request.url.path);
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['account_id'], 'acct-bank');

        if (request.url.path.endsWith('/bank-statements/import/qif')) {
          expect(body['file_name'], 'july-bank.qif');
          expect(body['qif_content'], contains('!Type:Bank'));
          return _bankImportResponse(fileName: 'july-bank.qif', format: 'qif');
        }

        expect(request.url.path.endsWith('/bank-statements/import/ofx'), true);
        expect(body['file_name'], 'july-bank.ofx');
        expect(body['ofx_content'], contains('<OFX>'));
        return _bankImportResponse(fileName: 'july-bank.ofx', format: 'ofx');
      }),
    );

    final qif = await client.importQifBankStatement(
      const ImportQifBankStatementRequest(
        accountId: 'acct-bank',
        fileName: 'july-bank.qif',
        qifContent: '!Type:Bank\nD13/07/2026\nT1250.00\n^',
      ),
    );
    final ofx = await client.importOfxBankStatement(
      const ImportOfxBankStatementRequest(
        accountId: 'acct-bank',
        fileName: 'july-bank.ofx',
        ofxContent: '<OFX><STMTTRN><TRNAMT>1250.00',
      ),
    );

    expect(qif.format, 'qif');
    expect(ofx.format, 'ofx');
    expect(requestedPaths, [
      '/api/v1/organizations/org-1/bank-statements/import/qif',
      '/api/v1/organizations/org-1/bank-statements/import/ofx',
    ]);
  });

  test('lists and creates attachment metadata', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/organizations/org-1/attachments');
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {
                'id': 'attachment-1',
                'file_name': 'receipt.jpg',
                'content_type': 'image/jpeg',
                'storage_driver': 'local',
                'storage_key': 'receipts/receipt.jpg',
                'size_bytes': 2048,
              },
            ]),
            200,
          );
        }

        expect(request.method, 'POST');
        expect(request.headers['Content-Type'], contains('application/json'));
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['file_name'], 'invoice.pdf');
        expect(body['content_type'], 'application/pdf');
        expect(body['storage_driver'], 'local');
        expect(body['storage_key'], 'invoices/invoice.pdf');
        expect(body['size_bytes'], 4096);

        return http.Response(
          jsonEncode({
            'id': 'attachment-2',
            'file_name': 'invoice.pdf',
            'content_type': 'application/pdf',
            'storage_driver': 'local',
            'storage_key': 'invoices/invoice.pdf',
            'size_bytes': 4096,
          }),
          201,
        );
      }),
    );

    final attachments = await client.listAttachments();
    expect(attachments.single.fileName, 'receipt.jpg');
    expect(attachments.single.sizeBytes, 2048);

    final created = await client.createAttachment(
      const CreateAttachmentMetadata(
        fileName: 'invoice.pdf',
        contentType: 'application/pdf',
        storageKey: 'invoices/invoice.pdf',
        sizeBytes: 4096,
      ),
    );
    expect(created.id, 'attachment-2');
    expect(created.contentType, 'application/pdf');
  });

  test('uploads and downloads attachment binaries', () async {
    final seenMethods = <String>[];
    final client = AccountingApiClient(
      config: config,
      httpClient: _StreamingMockClient((request) async {
        seenMethods.add(request.method);
        expect(request.headers['Authorization'], 'Bearer access-token');

        if (request.method == 'POST') {
          expect(
            request.url.path,
            '/api/v1/organizations/org-1/attachments/upload',
          );
          expect(request, isA<http.MultipartRequest>());
          final multipart = request as http.MultipartRequest;
          expect(multipart.files.single.field, 'file');
          expect(multipart.files.single.filename, 'receipt.txt');
          return http.StreamedResponse(
            Stream.value(
              utf8.encode(
                jsonEncode({
                  'id': 'attachment-uploaded',
                  'file_name': 'receipt.txt',
                  'content_type': 'text/plain',
                  'storage_driver': 'local',
                  'storage_key': 'org-1/attachment-uploaded/receipt.txt',
                  'size_bytes': 13,
                }),
              ),
            ),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        expect(request.method, 'GET');
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/attachments/attachment-uploaded/download',
        );
        return http.StreamedResponse(
          Stream.value(utf8.encode('hello receipt')),
          200,
          headers: {
            'content-type': 'text/plain',
            'content-disposition': 'attachment; filename="receipt.txt"',
          },
        );
      }),
    );

    final uploaded = await client.uploadAttachmentBytes(
      fileName: 'receipt.txt',
      bytes: utf8.encode('hello receipt'),
    );
    expect(uploaded.id, 'attachment-uploaded');
    expect(uploaded.storageKey, 'org-1/attachment-uploaded/receipt.txt');

    final downloaded = await client.downloadAttachment(uploaded.id);
    expect(utf8.decode(downloaded.bytes), 'hello receipt');
    expect(downloaded.contentType, 'text/plain');
    expect(downloaded.fileName, 'receipt.txt');
    expect(seenMethods, ['POST', 'GET']);
  });

  test('calculates tax for configured rates or groups', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/organizations/org-1/tax/calculate');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['base_amount_minor'], 100000);
        expect(body['tax_inclusive'], false);
        expect(body['tax_group_id'], 'tax-group-1');

        return http.Response(
          jsonEncode({
            'base_amount_minor': 100000,
            'tax_amount_minor': 18000,
            'total_amount_minor': 118000,
            'components': [
              {
                'tax_rate_id': 'cgst-9',
                'name': 'CGST 9%',
                'percentage_basis': 90000,
                'tax_amount_minor': 9000,
              },
              {
                'tax_rate_id': 'sgst-9',
                'name': 'SGST 9%',
                'percentage_basis': 90000,
                'tax_amount_minor': 9000,
              },
            ],
          }),
          200,
        );
      }),
    );

    final result = await client.calculateTax(
      const CalculateTaxRequest(
        baseAmountMinor: 100000,
        taxInclusive: false,
        taxGroupId: 'tax-group-1',
      ),
    );

    expect(result.taxAmountMinor, 18000);
    expect(result.components, hasLength(2));
    expect(result.components.first.name, 'CGST 9%');
  });

  test('syncs queued expense draft to create expense endpoint', () async {
    final createdAt = DateTime.utc(2026, 7, 11);
    final operation = SyncOperation(
      id: 'expense-local-1',
      module: 'expenses',
      action: 'create_draft',
      createdAt: createdAt,
      payload: const {
        'expense_number': 'EXP-MOB-001',
        'amount_minor': 125000,
        'expense_account_id': 'acct-expense',
        'payment_account_id': 'acct-cash',
        'receipt_attachment_id': 'attachment-1',
        'tax_rate_id': 'tax-rate-1',
        'tax_group_id': 'tax-group-1',
        'tax_inclusive': true,
        'reimbursable': true,
      },
    );
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/organizations/org-1/expenses');
        expect(request.headers['Content-Type'], contains('application/json'));

        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['expense_number'], 'EXP-MOB-001');
        expect(body['expense_date'], '2026-07-11');
        expect(body['amount_minor'], 125000);
        expect(body['expense_account_id'], 'acct-expense');
        expect(body['payment_account_id'], 'acct-cash');
        expect(body['receipt_attachment_id'], 'attachment-1');
        expect(body['tax_rate_id'], 'tax-rate-1');
        expect(body['tax_group_id'], 'tax-group-1');
        expect(body['tax_inclusive'], true);
        expect(body['reimbursable'], true);

        return http.Response(
          jsonEncode({
            'id': 'exp-1',
            'expense_number': 'EXP-MOB-001',
            'status': 'draft',
            'total_minor': 125000,
            'currency': 'INR',
          }),
          201,
        );
      }),
    );

    final expense = await client.syncExpenseDraft(operation);

    expect(expense.id, 'exp-1');
    expect(expense.totalMinor, 125000);
  });

  test('throws API exception with backend error message', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'code': 'invalid_request', 'message': 'bad payload'},
          }),
          400,
        );
      }),
    );

    expect(
      client.listAccounts,
      throwsA(
        isA<AccountingApiException>()
            .having((error) => error.statusCode, 'statusCode', 400)
            .having((error) => error.message, 'message', 'bad payload'),
      ),
    );
  });
}

class _StreamingMockClient extends http.BaseClient {
  _StreamingMockClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return handler(request);
  }
}

http.Response _bankImportResponse({
  required String fileName,
  required String format,
}) {
  return http.Response(jsonEncode(_bankImportJson(fileName, format)), 201);
}

Map<String, Object?> _bankImportJson(String fileName, String format) {
  return {
    'id': 'bank-import-$format',
    'organization_id': 'org-1',
    'account_id': 'acct-bank',
    'file_name': fileName,
    'format': format,
    'status': 'completed',
    'line_count': 1,
    'lines': [
      {
        'id': 'bank-line-$format',
        'organization_id': 'org-1',
        'account_id': 'acct-bank',
        'posted_date': '2026-07-15T00:00:00Z',
        'description': 'Imported line',
        'amount_minor': 125000,
        'reference': 'BANK-123',
        'is_duplicate': false,
      },
    ],
  };
}
