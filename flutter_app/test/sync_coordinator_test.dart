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

    expect(result.synced, 1);
    expect(result.hasFailures, false);
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
}
