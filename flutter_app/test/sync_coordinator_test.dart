import 'dart:convert';
import 'dart:io';

import 'package:accounting_app/api/accounting_api_client.dart';
import 'package:accounting_app/sync/offline_sync_queue.dart';
import 'package:accounting_app/sync/sync_coordinator.dart';
import 'package:accounting_app/sync/sync_operation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const config = AccountingApiConfig(
    baseUrl: 'http://localhost:8080/api/v1',
    accessToken: 'access-token',
    organizationId: 'org-1',
  );

  test(
    'syncs queued expense drafts and removes successful operations',
    () async {
      final queue = OfflineSyncQueue([
        SyncOperation(
          id: 'expense-local-1',
          module: 'expenses',
          action: 'create_draft',
          createdAt: DateTime.utc(2026, 7, 11),
          payload: const {
            'expense_number': 'EXP-MOB-001',
            'amount_minor': 125000,
            'expense_account_id': 'acct-expense',
            'payment_account_id': 'acct-cash',
          },
        ),
      ]);
      final apiClient = AccountingApiClient(
        config: config,
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'id': 'expense-server-1',
              'expense_number': 'EXP-MOB-001',
              'status': 'draft',
              'total_minor': 125000,
              'currency': 'INR',
            }),
            201,
          );
        }),
      );

      final result = await SyncCoordinator(
        queue: queue,
        apiClient: apiClient,
      ).syncPending();

      expect(result.synced, 1);
      expect(result.skipped, 0);
      expect(result.hasFailures, false);
      expect(queue.pendingCount, 0);
    },
  );

  test('keeps failed operations queued for retry', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'expense-local-1',
        module: 'expenses',
        action: 'create_draft',
        createdAt: DateTime.utc(2026, 7, 11),
        payload: const {
          'expense_number': 'EXP-MOB-001',
          'amount_minor': 125000,
          'expense_account_id': 'acct-expense',
          'payment_account_id': 'acct-cash',
        },
      ),
    ]);
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'message': 'account missing'},
          }),
          400,
        );
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(result.synced, 0);
    expect(result.skipped, 0);
    expect(result.failed.single.operationId, 'expense-local-1');
    expect(result.conflicts, 0);
    expect(queue.pendingCount, 1);
    expect(queue.pending.single.retryCount, 1);
    expect(queue.pending.single.lastError, contains('account missing'));
    expect(queue.pending.single.hasConflict, false);
  });

  test('marks conflict failures for manual review', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'expense-local-1',
        module: 'expenses',
        action: 'create_draft',
        createdAt: DateTime.utc(2026, 7, 11),
        payload: const {
          'expense_number': 'EXP-MOB-001',
          'amount_minor': 125000,
          'expense_account_id': 'acct-expense',
          'payment_account_id': 'acct-cash',
        },
      ),
    ]);
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'message': 'duplicate expense number'},
          }),
          409,
        );
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(result.synced, 0);
    expect(result.failed.single.isConflict, true);
    expect(result.conflicts, 1);
    expect(queue.pending.single.retryCount, 1);
    expect(queue.pending.single.conflictReason, contains('duplicate expense'));
    expect(queue.pending.single.hasConflict, true);
  });

  test('hydrates and saves pending operations through repository', () async {
    final repository = MemorySyncOperationRepository([
      SyncOperation(
        id: 'expense-local-1',
        module: 'expenses',
        action: 'create_draft',
        createdAt: DateTime.utc(2026, 7, 11),
        payload: const {
          'expense_number': 'EXP-MOB-001',
          'amount_minor': 125000,
          'expense_account_id': 'acct-expense',
          'payment_account_id': 'acct-cash',
        },
      ),
    ]);
    final queue = OfflineSyncQueue();
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 'expense-server-1',
            'expense_number': 'EXP-MOB-001',
            'status': 'draft',
            'total_minor': 125000,
            'currency': 'INR',
          }),
          201,
        );
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
      repository: repository,
    ).syncPending();

    expect(result.synced, 1);
    expect(queue.pendingCount, 0);
    expect(await repository.loadPending(), isEmpty);
  });

  test('reports unsupported operations as skipped', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'invoice-view-1',
        module: 'invoices',
        action: 'cache_view',
        createdAt: DateTime.utc(2026, 7, 11),
      ),
    ]);
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        fail('unsupported operations should not call the API');
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(result.synced, 0);
    expect(result.skipped, 1);
    expect(result.hasFailures, false);
    expect(queue.pendingCount, 1);
  });

  test('syncs broader offline writes across supported modules', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'invoice-local-1',
        module: 'invoices',
        action: 'create_draft',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {
          'customer_id': 'customer-1',
          'invoice_number': 'INV-MOB-001',
          'issue_date': '2026-07-15',
          'due_date': '2026-08-14',
          'currency': 'INR',
          'tax_inclusive': false,
          'accounts_receivable_id': 'acct-ar',
          'lines': [
            {
              'description': 'Field service',
              'quantity_millis': 1000,
              'unit_price_minor': 125000,
              'income_account_id': 'acct-income',
            },
          ],
        },
      ),
      SyncOperation(
        id: 'attachment-local-1',
        module: 'attachments',
        action: 'create_metadata',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {
          'file_name': 'receipt.jpg',
          'content_type': 'image/jpeg',
          'storage_driver': 'local',
          'storage_key': 'offline/receipt.jpg',
          'size_bytes': 42,
        },
      ),
      SyncOperation(
        id: 'price-local-1',
        module: 'investments',
        action: 'create_price',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {
          'symbol': 'INFY',
          'price_date': '2026-07-14',
          'price_minor': 158900,
          'currency': 'INR',
          'source': 'mobile-offline',
        },
      ),
    ]);
    final requestedPaths = <String>[];
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        requestedPaths.add(request.url.path);
        final body = jsonDecode(request.body) as Map<String, Object?>;

        if (request.url.path.endsWith('/invoices')) {
          expect(body['invoice_number'], 'INV-MOB-001');
          return http.Response(
            jsonEncode({
              'id': 'invoice-server-1',
              'invoice_number': 'INV-MOB-001',
              'status': 'draft',
              'subtotal_minor': 125000,
              'tax_total_minor': 0,
              'total_minor': 125000,
              'currency': 'INR',
              'lines': [],
            }),
            201,
          );
        }

        if (request.url.path.endsWith('/attachments')) {
          expect(body['storage_key'], 'offline/receipt.jpg');
          return http.Response(
            jsonEncode({
              'id': 'attachment-server-1',
              'file_name': 'receipt.jpg',
              'content_type': 'image/jpeg',
              'storage_driver': 'local',
              'storage_key': 'offline/receipt.jpg',
              'size_bytes': 42,
            }),
            201,
          );
        }

        if (request.url.path.endsWith('/investments/prices')) {
          expect(body['symbol'], 'INFY');
          return http.Response(
            jsonEncode({
              'id': 'price-server-1',
              'symbol': 'INFY',
              'price_date': '2026-07-14T00:00:00Z',
              'price_minor': 158900,
              'currency': 'INR',
              'source': 'mobile-offline',
            }),
            201,
          );
        }

        fail('unexpected path: ${request.url.path}');
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(result.synced, 3);
    expect(result.skipped, 0);
    expect(result.hasFailures, false);
    expect(queue.pendingCount, 0);
    expect(
      requestedPaths,
      containsAll([
        '/api/v1/organizations/org-1/invoices',
        '/api/v1/organizations/org-1/attachments',
        '/api/v1/organizations/org-1/investments/prices',
      ]),
    );
  });

  test('syncs queued draft invoice and expense edits', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'invoice-edit-local-1',
        module: 'invoices',
        action: 'update_draft',
        createdAt: DateTime.utc(2026, 7, 16),
        payload: const {
          'invoice_id': 'invoice-1',
          'customer_id': 'customer-1',
          'invoice_number': 'INV-MOB-001-EDIT',
          'issue_date': '2026-07-16',
          'due_date': '2026-08-15',
          'currency': 'INR',
          'tax_inclusive': false,
          'accounts_receivable_id': 'acct-ar',
          'lines': [
            {
              'description': 'Updated field service',
              'quantity_millis': 1000,
              'unit_price_minor': 175000,
              'income_account_id': 'acct-income',
            },
          ],
        },
      ),
      SyncOperation(
        id: 'expense-edit-local-1',
        module: 'expenses',
        action: 'update_draft',
        createdAt: DateTime.utc(2026, 7, 16),
        payload: const {
          'expense_id': 'expense-1',
          'expense_number': 'EXP-MOB-001-EDIT',
          'amount_minor': 99000,
          'expense_account_id': 'acct-expense',
          'payment_account_id': 'acct-bank',
          'tax_inclusive': true,
          'reimbursable': true,
        },
      ),
    ]);
    final requested = <String, String>{};
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        requested[request.url.path] = request.method;
        final body = jsonDecode(request.body) as Map<String, Object?>;

        if (request.url.path.endsWith('/invoices/invoice-1')) {
          expect(request.method, 'PUT');
          expect(body['invoice_number'], 'INV-MOB-001-EDIT');
          return http.Response(
            jsonEncode({
              'id': 'invoice-1',
              'invoice_number': 'INV-MOB-001-EDIT',
              'status': 'draft',
              'subtotal_minor': 175000,
              'tax_total_minor': 0,
              'total_minor': 175000,
              'currency': 'INR',
              'lines': [],
            }),
            200,
          );
        }

        if (request.url.path.endsWith('/expenses/expense-1')) {
          expect(request.method, 'PUT');
          expect(body['expense_number'], 'EXP-MOB-001-EDIT');
          return http.Response(
            jsonEncode({
              'id': 'expense-1',
              'expense_number': 'EXP-MOB-001-EDIT',
              'status': 'draft',
              'total_minor': 99000,
              'currency': 'INR',
            }),
            200,
          );
        }

        fail('unexpected path: ${request.url.path}');
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(result.synced, 2);
    expect(result.hasFailures, false);
    expect(queue.pendingCount, 0);
    expect(requested, {
      '/api/v1/organizations/org-1/invoices/invoice-1': 'PUT',
      '/api/v1/organizations/org-1/expenses/expense-1': 'PUT',
    });
  });

  test('syncs queued attachment binary uploads', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ledger-upload-sync-test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final receipt = File('${directory.path}/receipt.txt');
    await receipt.writeAsString('offline receipt bytes');
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'attachment-upload-local-1',
        module: 'attachments',
        action: 'upload_binary',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: {'file_name': 'receipt.txt', 'local_file_path': receipt.path},
      ),
    ]);
    final requestedPaths = <String>[];
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        requestedPaths.add(request.url.path);
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/attachments/upload',
        );
        return http.Response(
          jsonEncode({
            'id': 'attachment-uploaded-1',
            'file_name': 'receipt.txt',
            'content_type': 'text/plain',
            'storage_driver': 'local',
            'storage_key': 'org-1/attachment-uploaded-1/receipt.txt',
            'size_bytes': 21,
          }),
          201,
        );
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(
      result.failed,
      isEmpty,
      reason: result.failed.map((failure) => failure.error).join('\n'),
    );
    expect(result.synced, 1);
    expect(queue.pendingCount, 0);
    expect(requestedPaths, ['/api/v1/organizations/org-1/attachments/upload']);
  });

  test('syncs queued customer and vendor payments', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'customer-payment-local-1',
        module: 'payments',
        action: 'record_customer',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {
          'invoice_id': 'invoice-1',
          'payment_number': 'RCPT-MOB-001',
          'payment_date': '2026-07-15',
          'payment_method': 'upi',
          'reference': 'UPI123',
          'currency': 'INR',
          'amount_minor': 118000,
          'payment_account_id': 'acct-bank',
        },
      ),
      SyncOperation(
        id: 'vendor-payment-local-1',
        module: 'payments',
        action: 'record_vendor',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {
          'bill_id': 'bill-1',
          'payment_number': 'VPAY-MOB-001',
          'payment_date': '2026-07-16',
          'currency': 'INR',
          'amount_minor': 59000,
          'payment_account_id': 'acct-bank',
        },
      ),
    ]);
    final requestedPaths = <String>[];
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        requestedPaths.add(request.url.path);
        final body = jsonDecode(request.body) as Map<String, Object?>;

        if (request.url.path.endsWith('/invoices/invoice-1/payments')) {
          expect(body['payment_number'], 'RCPT-MOB-001');
          expect(body['payment_method'], 'upi');
          expect(body['reference'], 'UPI123');
          return http.Response(
            jsonEncode({
              'id': 'customer-payment-1',
              'organization_id': 'org-1',
              'invoice_id': 'invoice-1',
              'payment_number': 'RCPT-MOB-001',
              'payment_date': '2026-07-15T00:00:00Z',
              'payment_method': 'upi',
              'reference': 'UPI123',
              'currency': 'INR',
              'amount_minor': 118000,
              'payment_account_id': 'acct-bank',
              'journal_transaction_id': 'journal-1',
            }),
            201,
          );
        }

        if (request.url.path.endsWith('/bills/bill-1/payments')) {
          expect(body['payment_number'], 'VPAY-MOB-001');
          expect(body.containsKey('payment_method'), false);
          return http.Response(
            jsonEncode({
              'id': 'vendor-payment-1',
              'organization_id': 'org-1',
              'bill_id': 'bill-1',
              'payment_number': 'VPAY-MOB-001',
              'payment_date': '2026-07-16T00:00:00Z',
              'currency': 'INR',
              'amount_minor': 59000,
              'payment_account_id': 'acct-bank',
              'journal_transaction_id': 'journal-2',
            }),
            201,
          );
        }

        fail('unexpected path: ${request.url.path}');
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(result.synced, 2);
    expect(result.hasFailures, false);
    expect(queue.pendingCount, 0);
    expect(requestedPaths, [
      '/api/v1/organizations/org-1/invoices/invoice-1/payments',
      '/api/v1/organizations/org-1/bills/bill-1/payments',
    ]);
  });

  test('syncs queued structured bank statement imports', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'bank-import-local-1',
        module: 'imports',
        action: 'bank_statement_structured',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {
          'account_id': 'acct-bank',
          'file_name': 'july-bank.csv',
          'format': 'csv',
          'lines': [
            {
              'posted_date': '2026-07-15',
              'description': 'UPI receipt',
              'amount_minor': 125000,
              'reference': 'UPI123',
            },
          ],
        },
      ),
    ]);
    final requestedPaths = <String>[];
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        requestedPaths.add(request.url.path);
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['account_id'], 'acct-bank');
        expect(body['file_name'], 'july-bank.csv');
        final lines = body['lines']! as List;
        final line = lines.single as Map<String, Object?>;
        expect(line['posted_date'], '2026-07-15');
        expect(line['amount_minor'], 125000);
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
                'id': 'line-1',
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

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(result.synced, 1);
    expect(result.hasFailures, false);
    expect(queue.pendingCount, 0);
    expect(requestedPaths, [
      '/api/v1/organizations/org-1/bank-statements/import',
    ]);
  });

  test('syncs queued QIF and OFX bank statement imports', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'qif-import-local-1',
        module: 'imports',
        action: 'bank_statement_qif',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {
          'account_id': 'acct-bank',
          'file_name': 'july-bank.qif',
          'qif_content': '!Type:Bank\nD13/07/2026\nT1250.00\n^',
        },
      ),
      SyncOperation(
        id: 'ofx-import-local-1',
        module: 'imports',
        action: 'bank_statement_ofx',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {
          'account_id': 'acct-bank',
          'file_name': 'july-bank.ofx',
          'ofx_content': '<OFX><STMTTRN><TRNAMT>1250.00',
        },
      ),
    ]);
    final requestedPaths = <String>[];
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        requestedPaths.add(request.url.path);
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['account_id'], 'acct-bank');

        if (request.url.path.endsWith('/bank-statements/import/qif')) {
          expect(body['qif_content'], contains('!Type:Bank'));
          return http.Response(
            jsonEncode(
              _bankImportJson(fileName: 'july-bank.qif', format: 'qif'),
            ),
            201,
          );
        }

        expect(request.url.path.endsWith('/bank-statements/import/ofx'), true);
        expect(body['ofx_content'], contains('<OFX>'));
        return http.Response(
          jsonEncode(_bankImportJson(fileName: 'july-bank.ofx', format: 'ofx')),
          201,
        );
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(result.synced, 2);
    expect(result.hasFailures, false);
    expect(queue.pendingCount, 0);
    expect(requestedPaths, [
      '/api/v1/organizations/org-1/bank-statements/import/qif',
      '/api/v1/organizations/org-1/bank-statements/import/ofx',
    ]);
  });

  test('syncs queued commercial document status updates', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'estimate-status-local-1',
        module: 'commercial_documents',
        action: 'update_estimate_status',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {'estimate_id': 'estimate-1', 'status': 'accepted'},
      ),
      SyncOperation(
        id: 'purchase-order-status-local-1',
        module: 'commercial_documents',
        action: 'update_purchase_order_status',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {'purchase_order_id': 'po-1', 'status': 'approved'},
      ),
    ]);
    final requestedPaths = <String>[];
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        requestedPaths.add(request.url.path);
        final body = jsonDecode(request.body) as Map<String, Object?>;

        if (request.url.path.endsWith('/estimates/estimate-1/status')) {
          expect(body['status'], 'accepted');
          return http.Response(
            jsonEncode({
              'id': 'estimate-1',
              'organization_id': 'org-1',
              'customer_id': 'customer-1',
              'estimate_number': 'EST-001',
              'issue_date': '2026-07-01T00:00:00Z',
              'expiry_date': '2026-07-31T00:00:00Z',
              'status': 'accepted',
              'currency': 'INR',
              'subtotal_minor': 100000,
              'tax_total_minor': 18000,
              'total_minor': 118000,
              'lines': [],
            }),
            200,
          );
        }

        if (request.url.path.endsWith('/purchase-orders/po-1/status')) {
          expect(body['status'], 'approved');
          return http.Response(
            jsonEncode({
              'id': 'po-1',
              'organization_id': 'org-1',
              'vendor_id': 'vendor-1',
              'purchase_order_number': 'PO-001',
              'issue_date': '2026-07-01T00:00:00Z',
              'status': 'approved',
              'currency': 'INR',
              'subtotal_minor': 50000,
              'tax_total_minor': 9000,
              'total_minor': 59000,
              'lines': [],
            }),
            200,
          );
        }

        fail('unexpected path: ${request.url.path}');
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(result.synced, 2);
    expect(result.hasFailures, false);
    expect(queue.pendingCount, 0);
    expect(requestedPaths, [
      '/api/v1/organizations/org-1/estimates/estimate-1/status',
      '/api/v1/organizations/org-1/purchase-orders/po-1/status',
    ]);
  });

  test('syncs queued commercial document conversions', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'estimate-conversion-local-1',
        module: 'commercial_documents',
        action: 'convert_estimate_to_invoice',
        createdAt: DateTime.utc(2026, 7, 18),
        payload: const {
          'estimate_id': 'estimate-1',
          'invoice_number': 'INV-MOB-002',
          'issue_date': '2026-07-18',
          'due_date': '2026-08-17',
          'accounts_receivable_id': 'acct-ar',
          'pdf_attachment_id': 'attachment-pdf',
        },
      ),
      SyncOperation(
        id: 'purchase-order-conversion-local-1',
        module: 'commercial_documents',
        action: 'convert_purchase_order_to_bill',
        createdAt: DateTime.utc(2026, 7, 18),
        payload: const {
          'purchase_order_id': 'po-1',
          'bill_number': 'BILL-MOB-002',
          'issue_date': '2026-07-19',
          'due_date': '2026-08-18',
          'accounts_payable_id': 'acct-ap',
          'document_attachment_id': 'attachment-bill',
        },
      ),
    ]);
    final requestedPaths = <String>[];
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        requestedPaths.add(request.url.path);
        final body = jsonDecode(request.body) as Map<String, Object?>;

        if (request.url.path.endsWith(
          '/estimates/estimate-1/convert-to-invoice',
        )) {
          expect(body['invoice_number'], 'INV-MOB-002');
          expect(body['accounts_receivable_id'], 'acct-ar');
          return http.Response(
            jsonEncode({
              'id': 'invoice-2',
              'invoice_number': 'INV-MOB-002',
              'status': 'draft',
              'subtotal_minor': 100000,
              'tax_total_minor': 18000,
              'total_minor': 118000,
              'currency': 'INR',
              'lines': [],
            }),
            201,
          );
        }

        expect(
          request.url.path.endsWith('/purchase-orders/po-1/convert-to-bill'),
          true,
        );
        expect(body['bill_number'], 'BILL-MOB-002');
        expect(body['accounts_payable_id'], 'acct-ap');
        return http.Response(
          jsonEncode({
            'id': 'bill-2',
            'bill_number': 'BILL-MOB-002',
            'status': 'draft',
            'total_minor': 59000,
            'currency': 'INR',
          }),
          201,
        );
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(result.synced, 2);
    expect(result.hasFailures, false);
    expect(queue.pendingCount, 0);
    expect(requestedPaths, [
      '/api/v1/organizations/org-1/estimates/estimate-1/convert-to-invoice',
      '/api/v1/organizations/org-1/purchase-orders/po-1/convert-to-bill',
    ]);
  });

  test('syncs queued ledger posting actions', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'invoice-post-local-1',
        module: 'ledger',
        action: 'post_invoice',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {'invoice_id': 'invoice-1'},
      ),
      SyncOperation(
        id: 'expense-post-local-1',
        module: 'ledger',
        action: 'post_expense',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {'expense_id': 'expense-1'},
      ),
      SyncOperation(
        id: 'bill-post-local-1',
        module: 'ledger',
        action: 'post_bill',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {'bill_id': 'bill-1'},
      ),
      SyncOperation(
        id: 'credit-note-post-local-1',
        module: 'ledger',
        action: 'post_credit_note',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {'credit_note_id': 'credit-note-1'},
      ),
    ]);
    final requestedPaths = <String>[];
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        requestedPaths.add(request.url.path);
        expect(request.method, 'POST');

        if (request.url.path.endsWith('/invoices/invoice-1/post')) {
          return http.Response(
            jsonEncode({
              'id': 'invoice-1',
              'invoice_number': 'INV-001',
              'status': 'posted',
              'subtotal_minor': 100000,
              'tax_total_minor': 18000,
              'total_minor': 118000,
              'currency': 'INR',
              'lines': [],
            }),
            200,
          );
        }

        if (request.url.path.endsWith('/expenses/expense-1/post')) {
          return http.Response(
            jsonEncode({
              'id': 'expense-1',
              'expense_number': 'EXP-001',
              'status': 'posted',
              'total_minor': 59000,
              'currency': 'INR',
            }),
            200,
          );
        }

        if (request.url.path.endsWith('/bills/bill-1/post')) {
          return http.Response(
            jsonEncode({
              'id': 'bill-1',
              'bill_number': 'BILL-001',
              'status': 'posted',
              'total_minor': 59000,
              'currency': 'INR',
            }),
            200,
          );
        }

        if (request.url.path.endsWith('/credit-notes/credit-note-1/post')) {
          return http.Response(
            jsonEncode({
              'id': 'credit-note-1',
              'credit_note_number': 'CN-001',
              'status': 'posted',
              'total_minor': 11800,
              'currency': 'INR',
            }),
            200,
          );
        }

        fail('unexpected path: ${request.url.path}');
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(result.synced, 4);
    expect(result.hasFailures, false);
    expect(queue.pendingCount, 0);
    expect(requestedPaths, [
      '/api/v1/organizations/org-1/invoices/invoice-1/post',
      '/api/v1/organizations/org-1/expenses/expense-1/post',
      '/api/v1/organizations/org-1/bills/bill-1/post',
      '/api/v1/organizations/org-1/credit-notes/credit-note-1/post',
    ]);
  });

  test('syncs queued investment lots', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'investment-lot-local-1',
        module: 'investments',
        action: 'create_lot',
        createdAt: DateTime.utc(2026, 7, 31),
        payload: const {
          'account_id': 'acct-invest',
          'symbol': 'INFY',
          'security_name': 'Infosys',
          'acquisition_date': '2026-07-31',
          'quantity_millis': 2500,
          'cost_basis_minor': 375000,
          'currency': 'INR',
          'cost_method': 'average_cost',
          'notes': 'Initial mobile lot',
        },
      ),
    ]);
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/lots',
        );
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['account_id'], 'acct-invest');
        expect(body['symbol'], 'INFY');
        expect(body['security_name'], 'Infosys');
        expect(body['acquisition_date'], '2026-07-31');
        expect(body['quantity_millis'], 2500);
        expect(body['cost_basis_minor'], 375000);
        expect(body['cost_method'], 'average_cost');
        return http.Response(
          jsonEncode({
            'id': 'lot-1',
            ...body,
            'acquisition_date': '2026-07-31T00:00:00Z',
            'remaining_quantity_millis': 2500,
          }),
          201,
        );
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(
      result.failed,
      isEmpty,
      reason: result.failed.map((failure) => failure.error).join('\n'),
    );
    expect(result.skipped, 0);
    expect(result.synced, 1);
    expect(queue.pendingCount, 0);
  });

  test('syncs queued average-cost investment sales', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'average-cost-sale-local-1',
        module: 'investments',
        action: 'sell_average_cost',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {
          'account_id': 'acct-invest',
          'symbol': 'INFY',
          'currency': 'INR',
          'sale_date': '2026-07-15',
          'quantity_millis': 2500,
          'proceeds_minor': 375000,
          'proceeds_account_id': 'acct-bank',
          'gain_loss_account_id': 'acct-gain-loss',
          'notes': 'Partial sale from mobile',
        },
      ),
    ]);
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/average-cost-sales',
        );
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['account_id'], 'acct-invest');
        expect(body['symbol'], 'INFY');
        expect(body['sale_date'], '2026-07-15');
        expect(body['quantity_millis'], 2500);
        expect(body['proceeds_minor'], 375000);
        expect(body['proceeds_account_id'], 'acct-bank');
        expect(body['gain_loss_account_id'], 'acct-gain-loss');
        return http.Response(
          jsonEncode({
            'quantity_millis': 2500,
            'proceeds_minor': 375000,
            'allocated_cost_basis_minor': 300000,
            'realized_gain_loss_minor': 75000,
            'journal_transaction_id': 'journal-invest-sale-1',
            'dispositions': [
              {
                'id': 'disposition-1',
                'investment_lot_id': 'lot-1',
                'sale_date': '2026-07-15T00:00:00Z',
                'quantity_millis': 2500,
                'proceeds_minor': 375000,
                'allocated_cost_basis_minor': 300000,
                'realized_gain_loss_minor': 75000,
                'currency': 'INR',
                'notes': 'Partial sale from mobile',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(
      result.failed,
      isEmpty,
      reason: result.failed.map((failure) => failure.error).join('\n'),
    );
    expect(result.skipped, 0);
    expect(result.synced, 1);
    expect(queue.pendingCount, 0);
  });

  test('syncs queued specific-lot investment sales', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'investment-lot-sale-local-1',
        module: 'investments',
        action: 'sell_lot',
        createdAt: DateTime.utc(2026, 7, 31),
        payload: const {
          'lot_id': 'lot-1',
          'sale_date': '2026-07-31',
          'quantity_millis': 1000,
          'proceeds_minor': 150000,
          'proceeds_account_id': 'acct-bank',
          'gain_loss_account_id': 'acct-gain-loss',
          'notes': 'Specific sale from mobile',
        },
      ),
    ]);
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/lots/lot-1/sell',
        );
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['sale_date'], '2026-07-31');
        expect(body['quantity_millis'], 1000);
        expect(body['proceeds_minor'], 150000);
        expect(body['proceeds_account_id'], 'acct-bank');
        expect(body['gain_loss_account_id'], 'acct-gain-loss');
        return http.Response(
          jsonEncode({
            'id': 'disposition-specific-1',
            'investment_lot_id': 'lot-1',
            'sale_date': '2026-07-31T00:00:00Z',
            'quantity_millis': 1000,
            'proceeds_minor': 150000,
            'allocated_cost_basis_minor': 120000,
            'realized_gain_loss_minor': 30000,
            'currency': 'INR',
            'notes': 'Specific sale from mobile',
          }),
          201,
        );
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(
      result.failed,
      isEmpty,
      reason: result.failed.map((failure) => failure.error).join('\n'),
    );
    expect(result.skipped, 0);
    expect(result.synced, 1);
    expect(queue.pendingCount, 0);
  });

  test('syncs queued investment dividends', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'investment-dividend-local-1',
        module: 'investments',
        action: 'create_dividend',
        createdAt: DateTime.utc(2026, 7, 31),
        payload: const {
          'account_id': 'acct-invest',
          'symbol': 'INFY',
          'currency': 'INR',
          'dividend_date': '2026-07-31',
          'amount_minor': 12500,
          'cash_account_id': 'acct-bank',
          'income_account_id': 'acct-dividend-income',
          'notes': 'Quarterly dividend',
        },
      ),
    ]);
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/dividends',
        );
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['account_id'], 'acct-invest');
        expect(body['symbol'], 'INFY');
        expect(body['dividend_date'], '2026-07-31');
        expect(body['amount_minor'], 12500);
        expect(body['cash_account_id'], 'acct-bank');
        expect(body['income_account_id'], 'acct-dividend-income');
        return http.Response(
          jsonEncode({
            'id': 'dividend-1',
            ...body,
            'dividend_date': '2026-07-31T00:00:00Z',
            'journal_transaction_id': 'journal-dividend-1',
          }),
          201,
        );
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(
      result.failed,
      isEmpty,
      reason: result.failed.map((failure) => failure.error).join('\n'),
    );
    expect(result.skipped, 0);
    expect(result.synced, 1);
    expect(queue.pendingCount, 0);
  });

  test('syncs queued investment corporate actions', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'investment-corporate-action-local-1',
        module: 'investments',
        action: 'create_corporate_action',
        createdAt: DateTime.utc(2026, 8, 1),
        payload: const {
          'account_id': 'acct-invest',
          'symbol': 'INFY',
          'action_type': 'split',
          'action_date': '2026-08-01',
          'ratio_numerator': 2,
          'ratio_denominator': 1,
          'notes': 'Two-for-one split',
        },
      ),
    ]);
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/corporate-actions',
        );
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['account_id'], 'acct-invest');
        expect(body['symbol'], 'INFY');
        expect(body['action_type'], 'split');
        expect(body['action_date'], '2026-08-01');
        expect(body['ratio_numerator'], 2);
        expect(body['ratio_denominator'], 1);
        return http.Response(
          jsonEncode({
            'id': 'corporate-action-1',
            ...body,
            'action_date': '2026-08-01T00:00:00Z',
            'affected_lots': 2,
            'quantity_delta_millis': 5000,
            'cost_basis_delta_minor': 0,
          }),
          201,
        );
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(
      result.failed,
      isEmpty,
      reason: result.failed.map((failure) => failure.error).join('\n'),
    );
    expect(result.skipped, 0);
    expect(result.synced, 1);
    expect(queue.pendingCount, 0);
  });

  test('syncs queued broker holdings price imports', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'broker-holdings-import-local-1',
        module: 'investments',
        action: 'import_broker_holdings',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {
          'csv': 'Symbol,As of Date,Last Traded Price\nTCS,31-Jul-2026,3450.75',
          'source': 'broker_holdings_csv',
        },
      ),
    ]);
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/broker-holdings',
        );
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'broker_holdings_csv');
        expect(body['csv'], contains('Last Traded Price'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-broker-1',
                'symbol': 'TCS',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 345075,
                'currency': 'INR',
                'source': 'broker_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(result.synced, 1);
    expect(result.hasFailures, false);
    expect(queue.pendingCount, 0);
  });

  test('syncs queued Zerodha holdings price imports', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'zerodha-holdings-import-local-1',
        module: 'investments',
        action: 'import_broker_holdings',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {
          'csv':
              'Instrument,ISIN,Date,LTP,Qty.\nHDFCBANK,INE040A01034,2026-07-31,1575.20,4',
          'source': 'zerodha_holdings_csv',
        },
      ),
    ]);
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/zerodha-holdings',
        );
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'zerodha_holdings_csv');
        expect(body['csv'], contains('Instrument'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-zerodha-1',
                'symbol': 'HDFCBANK',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 157520,
                'currency': 'INR',
                'source': 'zerodha_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(result.synced, 1);
    expect(result.hasFailures, false);
    expect(queue.pendingCount, 0);
  });

  test('syncs queued Groww holdings price imports', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'groww-holdings-import-local-1',
        module: 'investments',
        action: 'import_broker_holdings',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {
          'csv':
              'Company Name,ISIN,Date,LTP,Quantity\nReliance Industries,INE002A01018,2026-07-31,1410.55,3',
          'source': 'groww_holdings_csv',
        },
      ),
    ]);
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/groww-holdings',
        );
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'groww_holdings_csv');
        expect(body['csv'], contains('Company Name'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-groww-1',
                'symbol': 'INE002A01018',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 141055,
                'currency': 'INR',
                'source': 'groww_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(result.synced, 1);
    expect(result.hasFailures, false);
    expect(queue.pendingCount, 0);
  });

  test('syncs queued Upstox holdings price imports', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'upstox-holdings-import-local-1',
        module: 'investments',
        action: 'import_broker_holdings',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {
          'csv':
              'Symbol,ISIN,Date,Current Price,Quantity\nSBIN,INE062A01020,2026-07-31,615.25,12',
          'source': 'upstox_holdings_csv',
        },
      ),
    ]);
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/upstox-holdings',
        );
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'upstox_holdings_csv');
        expect(body['csv'], contains('Current Price'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-upstox-1',
                'symbol': 'SBIN',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 61525,
                'currency': 'INR',
                'source': 'upstox_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(result.synced, 1);
    expect(result.hasFailures, false);
    expect(queue.pendingCount, 0);
  });

  test('syncs queued Angel One holdings price imports', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'angelone-holdings-import-local-1',
        module: 'investments',
        action: 'import_broker_holdings',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {
          'csv':
              'Scrip,ISIN,Date,LTP,Quantity\nICICIBANK,INE090A01021,2026-07-31,1245.30,5',
          'source': 'angelone_holdings_csv',
        },
      ),
    ]);
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/angelone-holdings',
        );
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'angelone_holdings_csv');
        expect(body['csv'], contains('Scrip'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-angelone-1',
                'symbol': 'ICICIBANK',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 124530,
                'currency': 'INR',
                'source': 'angelone_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(result.synced, 1);
    expect(result.hasFailures, false);
    expect(queue.pendingCount, 0);
  });

  test('syncs queued Dhan holdings price imports', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'dhan-holdings-import-local-1',
        module: 'investments',
        action: 'import_broker_holdings',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {
          'csv':
              'Trading Symbol,ISIN,Date,LTP,Quantity\nAXISBANK,INE238A01034,2026-07-31,1188.40,8',
          'source': 'dhan_holdings_csv',
        },
      ),
    ]);
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/dhan-holdings',
        );
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'dhan_holdings_csv');
        expect(body['csv'], contains('Trading Symbol'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-dhan-1',
                'symbol': 'AXISBANK',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 118840,
                'currency': 'INR',
                'source': 'dhan_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(result.synced, 1);
    expect(result.hasFailures, false);
    expect(queue.pendingCount, 0);
  });

  test('syncs queued ICICI Direct holdings price imports', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'icicidirect-holdings-import-local-1',
        module: 'investments',
        action: 'import_broker_holdings',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {
          'csv':
              'Symbol,ISIN,Date,Market Price,Quantity\nLT,INE018A01030,2026-07-31,3620.80,2',
          'source': 'icicidirect_holdings_csv',
        },
      ),
    ]);
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/icicidirect-holdings',
        );
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'icicidirect_holdings_csv');
        expect(body['csv'], contains('Market Price'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-icicidirect-1',
                'symbol': 'LT',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 362080,
                'currency': 'INR',
                'source': 'icicidirect_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(result.synced, 1);
    expect(result.hasFailures, false);
    expect(queue.pendingCount, 0);
  });

  test('syncs queued HDFC Sky holdings price imports', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'hdfcsky-holdings-import-local-1',
        module: 'investments',
        action: 'import_broker_holdings',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {
          'csv':
              'Symbol,ISIN,Date,LTP,Quantity\nMARUTI,INE585B01010,2026-07-31,12875.65,1',
          'source': 'hdfcsky_holdings_csv',
        },
      ),
    ]);
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/hdfcsky-holdings',
        );
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'hdfcsky_holdings_csv');
        expect(body['csv'], contains('MARUTI'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-hdfcsky-1',
                'symbol': 'MARUTI',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 1287565,
                'currency': 'INR',
                'source': 'hdfcsky_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(result.synced, 1);
    expect(result.hasFailures, false);
    expect(queue.pendingCount, 0);
  });

  test('syncs queued Kotak Neo holdings price imports', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'kotakneo-holdings-import-local-1',
        module: 'investments',
        action: 'import_broker_holdings',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {
          'csv':
              'Trading Symbol,ISIN,Date,LTP,Quantity\nBAJFINANCE,INE296A01024,2026-07-31,9342.10,2',
          'source': 'kotakneo_holdings_csv',
        },
      ),
    ]);
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/kotakneo-holdings',
        );
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'kotakneo_holdings_csv');
        expect(body['csv'], contains('BAJFINANCE'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-kotakneo-1',
                'symbol': 'BAJFINANCE',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 934210,
                'currency': 'INR',
                'source': 'kotakneo_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(result.synced, 1);
    expect(result.hasFailures, false);
    expect(queue.pendingCount, 0);
  });

  test('syncs queued Paytm Money holdings price imports', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'paytmmoney-holdings-import-local-1',
        module: 'investments',
        action: 'import_broker_holdings',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {
          'csv':
              'Symbol,ISIN,Date,LTP,Quantity\nTATAMOTORS,INE155A01022,2026-07-31,1098.45,5',
          'source': 'paytmmoney_holdings_csv',
        },
      ),
    ]);
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/paytmmoney-holdings',
        );
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'paytmmoney_holdings_csv');
        expect(body['csv'], contains('TATAMOTORS'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-paytmmoney-1',
                'symbol': 'TATAMOTORS',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 109845,
                'currency': 'INR',
                'source': 'paytmmoney_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(result.synced, 1);
    expect(result.hasFailures, false);
    expect(queue.pendingCount, 0);
  });

  test('syncs queued Motilal Oswal holdings price imports', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'motilaloswal-holdings-import-local-1',
        module: 'investments',
        action: 'import_broker_holdings',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {
          'csv':
              'Symbol,ISIN,Date,LTP,Quantity\nASIANPAINT,INE021A01026,2026-07-31,2987.60,3',
          'source': 'motilaloswal_holdings_csv',
        },
      ),
    ]);
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/motilaloswal-holdings',
        );
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'motilaloswal_holdings_csv');
        expect(body['csv'], contains('ASIANPAINT'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-motilaloswal-1',
                'symbol': 'ASIANPAINT',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 298760,
                'currency': 'INR',
                'source': 'motilaloswal_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(result.synced, 1);
    expect(result.hasFailures, false);
    expect(queue.pendingCount, 0);
  });

  test('syncs queued Sharekhan holdings price imports', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'sharekhan-holdings-import-local-1',
        module: 'investments',
        action: 'import_broker_holdings',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {
          'csv':
              'Symbol,ISIN,Date,LTP,Quantity\nHINDUNILVR,INE030A01027,2026-07-31,2567.35,4',
          'source': 'sharekhan_holdings_csv',
        },
      ),
    ]);
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/sharekhan-holdings',
        );
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'sharekhan_holdings_csv');
        expect(body['csv'], contains('HINDUNILVR'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-sharekhan-1',
                'symbol': 'HINDUNILVR',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 256735,
                'currency': 'INR',
                'source': 'sharekhan_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(result.synced, 1);
    expect(result.hasFailures, false);
    expect(queue.pendingCount, 0);
  });

  test('syncs queued 5paisa holdings price imports', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'fivepaisa-holdings-import-local-1',
        module: 'investments',
        action: 'import_broker_holdings',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {
          'csv':
              'Symbol,ISIN,Date,LTP,Quantity\nSBIN,INE062A01020,2026-07-31,845.70,10',
          'source': 'fivepaisa_holdings_csv',
        },
      ),
    ]);
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/fivepaisa-holdings',
        );
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'fivepaisa_holdings_csv');
        expect(body['csv'], contains('SBIN'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-fivepaisa-1',
                'symbol': 'SBIN',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 84570,
                'currency': 'INR',
                'source': 'fivepaisa_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(result.synced, 1);
    expect(result.hasFailures, false);
    expect(queue.pendingCount, 0);
  });

  test('syncs queued Axis Direct holdings price imports', () async {
    final queue = OfflineSyncQueue([
      SyncOperation(
        id: 'axisdirect-holdings-import-local-1',
        module: 'investments',
        action: 'import_broker_holdings',
        createdAt: DateTime.utc(2026, 7, 15),
        payload: const {
          'csv':
              'Symbol,ISIN,Date,LTP,Quantity\nTECHM,INE669C01036,2026-07-31,1543.25,6',
          'source': 'axisdirect_holdings_csv',
        },
      ),
    ]);
    final apiClient = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/axisdirect-holdings',
        );
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'axisdirect_holdings_csv');
        expect(body['csv'], contains('TECHM'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-axisdirect-1',
                'symbol': 'TECHM',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 154325,
                'currency': 'INR',
                'source': 'axisdirect_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await SyncCoordinator(
      queue: queue,
      apiClient: apiClient,
    ).syncPending();

    expect(result.synced, 1);
    expect(result.hasFailures, false);
    expect(queue.pendingCount, 0);
  });
}

Map<String, Object?> _bankImportJson({
  required String fileName,
  required String format,
}) {
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
