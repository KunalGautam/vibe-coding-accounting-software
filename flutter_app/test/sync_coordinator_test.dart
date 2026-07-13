import 'dart:convert';

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
    expect(queue.pendingCount, 1);
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
}
