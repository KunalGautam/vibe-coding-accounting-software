import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accounting_app/accounts/account_cache_repository.dart';
import 'package:accounting_app/api/accounting_api_client.dart';
import 'package:accounting_app/attachments/attachment_cache_repository.dart';
import 'package:accounting_app/invoices/invoice_cache_repository.dart';
import 'package:accounting_app/investments/investment_cache_repository.dart';
import 'package:accounting_app/main.dart';
import 'package:accounting_app/parties/party_cache_repository.dart';
import 'package:accounting_app/reports/report_cache_repository.dart';
import 'package:accounting_app/settings/sync_settings.dart';
import 'package:accounting_app/sync/offline_sync_queue.dart';
import 'package:accounting_app/sync/sync_operation_repository.dart';
import 'package:accounting_app/tax/tax_catalog_cache_repository.dart';

void main() {
  void useTallTestViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('shows the mobile and desktop accounting shell', (tester) async {
    await tester.pumpWidget(const AccountingApp());

    expect(find.text('Mobile and desktop cockpit'), findsOneWidget);
    expect(find.text('Offline mode'), findsOneWidget);
    expect(find.text('Queued changes'), findsOneWidget);
  });

  testWidgets('capture expense action queues another offline draft', (
    tester,
  ) async {
    final syncRepository = MemorySyncOperationRepository();

    await tester.pumpWidget(AccountingApp(syncRepository: syncRepository));

    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.text('Capture draft expense'));
    await tester.pumpAndSettle();

    expect(find.text('Receipts and reimbursables'), findsOneWidget);
    expect((await syncRepository.loadPending()).length, 4);
  });

  testWidgets('queues custom draft expense form values offline', (
    tester,
  ) async {
    useTallTestViewport(tester);
    final syncRepository = MemorySyncOperationRepository();

    await tester.pumpWidget(AccountingApp(syncRepository: syncRepository));
    await tester.tap(find.text('Expenses'));
    await tester.pump();

    await tester.enterText(find.byType(EditableText).at(0), 'Metro Taxi');
    await tester.enterText(find.byType(EditableText).at(1), '845.50');
    await tester.enterText(find.byType(EditableText).at(2), 'attachment-1');
    await tester.enterText(find.byType(EditableText).at(4), 'tax-group-1');
    await tester.tap(find.text('Tax inclusive'));
    await tester.tap(find.text('Reimbursable'));
    await tester.pump();
    await tester.tap(find.text('Queue draft expense'));
    await tester.pumpAndSettle();

    final pending = await syncRepository.loadPending();
    expect(pending.last.payload['merchant_name'], 'Metro Taxi');
    expect(pending.last.payload['amount_minor'], 84550);
    expect(pending.last.payload['receipt_attachment_id'], 'attachment-1');
    expect(pending.last.payload['tax_rate_id'], isNull);
    expect(pending.last.payload['tax_group_id'], 'tax-group-1');
    expect(pending.last.payload['tax_inclusive'], true);
    expect(pending.last.payload['reimbursable'], true);
  });

  testWidgets('selects a cached attachment for an expense receipt', (
    tester,
  ) async {
    useTallTestViewport(tester);
    final syncRepository = MemorySyncOperationRepository();
    final attachmentCacheRepository = MemoryAttachmentCacheRepository([
      const AttachmentSummary(
        id: 'attachment-cached',
        fileName: 'receipt.jpg',
        contentType: 'image/jpeg',
        storageDriver: 'local',
        storageKey: 'org-1/attachment-cached/receipt.jpg',
        sizeBytes: 2048,
      ),
    ]);

    await tester.pumpWidget(
      AccountingApp(
        syncRepository: syncRepository,
        attachmentCacheRepository: attachmentCacheRepository,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Expenses'));
    await tester.pump();

    expect(find.text('receipt.jpg · attachment-cached'), findsOneWidget);
    await tester.tap(find.text('Use receipt'));
    await tester.pump();
    expect(find.widgetWithText(TextField, 'attachment-cached'), findsOneWidget);

    await tester.tap(find.text('Queue draft expense'));
    await tester.pumpAndSettle();

    final pending = await syncRepository.loadPending();
    expect(pending.last.payload['receipt_attachment_id'], 'attachment-cached');
  });

  testWidgets('clears the opposite tax target while drafting expenses', (
    tester,
  ) async {
    useTallTestViewport(tester);
    final syncRepository = MemorySyncOperationRepository();

    await tester.pumpWidget(AccountingApp(syncRepository: syncRepository));
    await tester.tap(find.text('Expenses'));
    await tester.pump();

    await tester.enterText(find.byType(EditableText).at(3), 'tax-rate-1');
    expect(find.widgetWithText(TextField, 'tax-rate-1'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).at(4), 'tax-group-1');
    await tester.pump();
    expect(find.widgetWithText(TextField, 'tax-rate-1'), findsNothing);
    expect(find.text('Using tax group; tax rate cleared.'), findsOneWidget);
    await tester.tap(find.text('Queue draft expense'));
    await tester.pumpAndSettle();

    final pending = await syncRepository.loadPending();
    expect(pending.last.payload['tax_rate_id'], isNull);
    expect(pending.last.payload['tax_group_id'], 'tax-group-1');
  });

  testWidgets('shows pending draft details on the expenses page', (
    tester,
  ) async {
    useTallTestViewport(tester);
    final syncRepository = MemorySyncOperationRepository([
      SyncOperation(
        id: 'expense-pending-1',
        module: 'expenses',
        action: 'create_draft',
        createdAt: DateTime.utc(2026, 7, 12),
        payload: const {
          'merchant_name': 'Metro Taxi',
          'amount_minor': 84550,
          'receipt_attachment_id': 'attachment-1',
          'tax_rate_id': 'tax-rate-1',
          'tax_group_id': 'tax-group-1',
          'tax_inclusive': true,
          'reimbursable': true,
          'expense_account_id': 'expense-account',
          'payment_account_id': 'cash-account',
        },
      ),
      SyncOperation(
        id: 'expense-pending-2',
        module: 'expenses',
        action: 'create_draft',
        createdAt: DateTime.utc(2026, 7, 12),
        payload: const {
          'merchant_name': 'Tea Stall',
          'amount_minor': 3000,
          'reimbursable': false,
        },
      ),
    ]);

    await tester.pumpWidget(AccountingApp(syncRepository: syncRepository));
    await tester.pump();
    await tester.tap(find.text('Expenses'));
    await tester.pump();

    expect(find.text('Pending drafts'), findsOneWidget);
    expect(find.text('Metro Taxi'), findsOneWidget);
    expect(find.text('INR 845.50 · Ready to sync · Waiting'), findsOneWidget);
    expect(find.text('Receipt attachment: attachment-1'), findsOneWidget);
    expect(find.text('Tax rate: tax-rate-1'), findsOneWidget);
    expect(find.text('Tax group: tax-group-1'), findsOneWidget);
    expect(find.text('Tax inclusive'), findsWidgets);
    expect(find.text('Reimbursable'), findsWidgets);
    expect(find.text('Tea Stall'), findsOneWidget);
    expect(
      find.text('INR 30.00 · Needs posting accounts · Waiting'),
      findsOneWidget,
    );
  });

  testWidgets('previews configured tax before queuing a draft expense', (
    tester,
  ) async {
    useTallTestViewport(tester);
    final settingsRepository = MemorySyncSettingsRepository(
      const SyncSettings(accessToken: 'token-1', organizationId: 'org-1'),
    );

    await tester.pumpWidget(
      AccountingApp(
        settingsRepository: settingsRepository,
        taxCalculator: (_, request) async {
          expect(request.baseAmountMinor, 100000);
          expect(request.taxInclusive, false);
          expect(request.taxGroupId, 'tax-group-1');
          return const TaxCalculationResult(
            baseAmountMinor: 100000,
            taxAmountMinor: 18000,
            totalAmountMinor: 118000,
            components: [
              TaxCalculationComponent(
                taxRateId: 'cgst-9',
                name: 'CGST 9%',
                percentageBasis: 90000,
                taxAmountMinor: 9000,
              ),
              TaxCalculationComponent(
                taxRateId: 'sgst-9',
                name: 'SGST 9%',
                percentageBasis: 90000,
                taxAmountMinor: 9000,
              ),
            ],
          );
        },
      ),
    );
    await tester.tap(find.text('Expenses'));
    await tester.pump();

    await tester.enterText(find.byType(EditableText).at(1), '1000.00');
    await tester.enterText(find.byType(EditableText).at(4), 'tax-group-1');
    await tester.tap(find.text('Preview tax'));
    await tester.pumpAndSettle();

    expect(find.text('Tax preview'), findsOneWidget);
    expect(find.text('Base: INR 1000.00'), findsOneWidget);
    expect(find.text('Tax: INR 180.00'), findsOneWidget);
    expect(find.text('Total: INR 1180.00'), findsOneWidget);
    expect(find.text('CGST 9%: INR 90.00'), findsOneWidget);
    expect(find.text('SGST 9%: INR 90.00'), findsOneWidget);
  });

  testWidgets('deletes pending expense drafts from the expenses page', (
    tester,
  ) async {
    useTallTestViewport(tester);
    final syncRepository = MemorySyncOperationRepository([
      SyncOperation(
        id: 'expense-pending-1',
        module: 'expenses',
        action: 'create_draft',
        createdAt: DateTime.utc(2026, 7, 12),
        payload: const {'merchant_name': 'Metro Taxi', 'amount_minor': 84550},
      ),
    ]);

    await tester.pumpWidget(AccountingApp(syncRepository: syncRepository));
    await tester.pump();
    await tester.tap(find.text('Expenses'));
    await tester.pump();

    expect(find.text('Metro Taxi'), findsOneWidget);
    await tester.tap(find.text('Delete draft'));
    await tester.pumpAndSettle();

    expect(await syncRepository.loadPending(), isEmpty);
    expect(find.text('Metro Taxi'), findsNothing);
    expect(find.text('No expense drafts are waiting to sync.'), findsOneWidget);
  });

  testWidgets('edits pending expense drafts from the expenses page', (
    tester,
  ) async {
    useTallTestViewport(tester);
    final syncRepository = MemorySyncOperationRepository([
      SyncOperation(
        id: 'expense-pending-1',
        module: 'expenses',
        action: 'create_draft',
        createdAt: DateTime.utc(2026, 7, 12),
        payload: const {
          'merchant_name': 'Metro Taxi',
          'amount_minor': 84550,
          'receipt_attachment_id': 'attachment-1',
          'tax_rate_id': 'tax-rate-1',
          'tax_group_id': 'tax-group-1',
          'tax_inclusive': false,
          'reimbursable': false,
          'expense_account_id': 'expense-account',
          'payment_account_id': 'cash-account',
        },
      ),
    ]);

    await tester.pumpWidget(AccountingApp(syncRepository: syncRepository));
    await tester.pump();
    await tester.tap(find.text('Expenses'));
    await tester.pump();

    await tester.tap(find.text('Edit draft'));
    await tester.pump();

    expect(find.text('Edit draft expense'), findsOneWidget);
    expect(find.text('Save draft changes'), findsOneWidget);
    expect(find.text('Cancel edit'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Metro Taxi'), findsOneWidget);
    expect(find.widgetWithText(TextField, '845.50'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'attachment-1'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'tax-rate-1'), findsNothing);
    expect(find.widgetWithText(TextField, 'tax-group-1'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).at(0), 'Airport Taxi');
    await tester.enterText(find.byType(EditableText).at(1), '950.00');
    await tester.enterText(find.byType(EditableText).at(2), 'attachment-2');
    await tester.enterText(find.byType(EditableText).at(4), 'tax-group-2');
    await tester.tap(find.text('Tax inclusive').first);
    await tester.tap(find.text('Reimbursable').first);
    await tester.pump();
    await tester.tap(find.text('Save draft changes'));
    await tester.pumpAndSettle();

    final pending = await syncRepository.loadPending();
    expect(pending.single.id, 'expense-pending-1');
    expect(pending.single.payload['merchant_name'], 'Airport Taxi');
    expect(pending.single.payload['amount_minor'], 95000);
    expect(pending.single.payload['receipt_attachment_id'], 'attachment-2');
    expect(pending.single.payload['tax_rate_id'], isNull);
    expect(pending.single.payload['tax_group_id'], 'tax-group-2');
    expect(pending.single.payload['tax_inclusive'], true);
    expect(pending.single.payload['reimbursable'], true);
    expect(pending.single.payload['expense_account_id'], 'expense-account');
    expect(find.text('Airport Taxi'), findsOneWidget);
    expect(find.text('INR 950.00 · Ready to sync · Waiting'), findsOneWidget);
    expect(find.text('Receipt attachment: attachment-2'), findsOneWidget);
    expect(find.text('Tax group: tax-group-2'), findsOneWidget);
  });

  test('formats minor currency as INR', () {
    expect(formatMinorAsInr(84550), 'INR 845.50');
    expect(formatMinorAsInr(-125), '-INR 1.25');
  });

  test('extracts file names from local attachment paths', () {
    expect(fileNameFromPath('/tmp/receipt.jpg'), 'receipt.jpg');
    expect(fileNameFromPath(r'C:\receipts\bill.pdf'), 'bill.pdf');
    expect(fileNameFromPath(''), 'receipt-upload');
  });

  test('reads local attachment file bytes', () async {
    final receiptFile = File(
      '${Directory.systemTemp.path}/ledger-works-local-receipt.txt',
    );
    await receiptFile.writeAsString('local receipt bytes');
    addTearDown(() {
      if (receiptFile.existsSync()) {
        receiptFile.deleteSync();
      }
    });

    final localFile = await readLocalAttachmentFile(receiptFile.path);

    expect(localFile.fileName, 'ledger-works-local-receipt.txt');
    expect(String.fromCharCodes(localFile.bytes), 'local receipt bytes');
  });

  testWidgets('sync page reports pending drafts need credentials', (
    tester,
  ) async {
    useTallTestViewport(tester);
    await tester.pumpWidget(const AccountingApp());

    await tester.tap(find.text('Sync'));
    await tester.pump();

    expect(find.text('API and sync'), findsOneWidget);
    expect(find.text('Pending local operations: 3'), findsOneWidget);

    await tester.tap(find.text('Sync pending drafts'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Add API credentials and organization ID before syncing queued offline changes.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Last sync: 0 synced, 3 waiting, 0 failed, 0 need review.'),
      findsOneWidget,
    );
  });

  testWidgets('hydrates persisted pending operations into the shell', (
    tester,
  ) async {
    final repository = MemorySyncOperationRepository([
      SyncOperation(
        id: 'persisted-expense-1',
        module: 'expenses',
        action: 'create_draft',
        createdAt: DateTime.utc(2026, 7, 12),
      ),
    ]);

    await tester.pumpWidget(AccountingApp(syncRepository: repository));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.text('Sync'));
    await tester.pump();
    expect(find.text('Pending local operations: 1'), findsOneWidget);
  });

  testWidgets('saves sync settings locally from the sync page', (tester) async {
    useTallTestViewport(tester);
    final settingsRepository = MemorySyncSettingsRepository();

    await tester.pumpWidget(
      AccountingApp(settingsRepository: settingsRepository),
    );

    await tester.tap(find.text('Sync'));
    await tester.pump();

    await tester.enterText(find.byType(EditableText).at(1), 'token-1');
    await tester.enterText(find.byType(EditableText).at(2), 'org-1');
    await tester.enterText(find.byType(EditableText).at(3), 'expense-account');
    await tester.enterText(find.byType(EditableText).at(4), 'cash-account');
    await tester.enterText(find.byType(EditableText).at(5), 'tax-rate-1');
    await tester.enterText(find.byType(EditableText).at(6), 'tax-group-1');
    await tester.tap(find.text('Save sync settings'));
    await tester.pumpAndSettle();

    final saved = await settingsRepository.load();
    expect(saved.canSyncExpenses, true);
    expect(saved.defaultTaxRateId, 'tax-rate-1');
    expect(saved.defaultTaxGroupId, 'tax-group-1');
    expect(find.text('Sync settings saved locally.'), findsOneWidget);
  });

  testWidgets('captured expense drafts include configured account IDs', (
    tester,
  ) async {
    final syncRepository = MemorySyncOperationRepository();
    final settingsRepository = MemorySyncSettingsRepository(
      const SyncSettings(
        accessToken: 'token-1',
        organizationId: 'org-1',
        defaultExpenseAccountId: 'expense-account',
        defaultPaymentAccountId: 'cash-account',
        defaultTaxRateId: 'tax-rate-default',
        defaultTaxGroupId: 'tax-group-default',
      ),
    );

    await tester.pumpWidget(
      AccountingApp(
        syncRepository: syncRepository,
        settingsRepository: settingsRepository,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Capture draft expense'));
    await tester.pumpAndSettle();

    final pending = await syncRepository.loadPending();
    expect(pending.last.payload['expense_account_id'], 'expense-account');
    expect(pending.last.payload['payment_account_id'], 'cash-account');
    expect(pending.last.payload['tax_rate_id'], isNull);
    expect(pending.last.payload['tax_group_id'], 'tax-group-default');
  });

  testWidgets('fetches and displays account IDs from saved settings', (
    tester,
  ) async {
    useTallTestViewport(tester);
    final settingsRepository = MemorySyncSettingsRepository(
      const SyncSettings(accessToken: 'token-1', organizationId: 'org-1'),
    );
    final accountCacheRepository = MemoryAccountCacheRepository();

    await tester.pumpWidget(
      AccountingApp(
        settingsRepository: settingsRepository,
        accountCacheRepository: accountCacheRepository,
        accountLoader: (_) async => const [
          AccountSummary(
            id: 'acct-expense',
            code: '5000',
            name: 'Office Supplies',
            type: 'expense',
            currency: 'INR',
            isActive: true,
          ),
          AccountSummary(
            id: 'acct-cash',
            code: '1000',
            name: 'Cash',
            type: 'asset',
            currency: 'INR',
            isActive: true,
          ),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Sync'));
    await tester.pump();

    await tester.tap(find.text('Fetch accounts'));
    await tester.pumpAndSettle();

    expect(find.text('Fetched 2 accounts.'), findsOneWidget);
    expect((await accountCacheRepository.loadCached()), hasLength(2));
    expect(
      find.text('5000 · Office Supplies · expense · acct-expense'),
      findsOneWidget,
    );
    expect(find.text('1000 · Cash · asset · acct-cash'), findsOneWidget);
  });

  testWidgets('hydrates cached accounts into the sync page', (tester) async {
    useTallTestViewport(tester);
    final settingsRepository = MemorySyncSettingsRepository(
      const SyncSettings(
        defaultExpenseAccountId: 'acct-cached',
        defaultPaymentAccountId: 'acct-cached',
      ),
    );
    final accountCacheRepository = MemoryAccountCacheRepository([
      const AccountSummary(
        id: 'acct-cached',
        code: '6000',
        name: 'Travel Expenses',
        type: 'expense',
        currency: 'INR',
        isActive: true,
      ),
    ]);

    await tester.pumpWidget(
      AccountingApp(
        settingsRepository: settingsRepository,
        accountCacheRepository: accountCacheRepository,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Sync'));
    await tester.pump();

    expect(
      find.text('6000 · Travel Expenses · expense · acct-cached'),
      findsOneWidget,
    );
    expect(
      find.text('Resolved expense account: 6000 · Travel Expenses'),
      findsOneWidget,
    );
    expect(
      find.text('Resolved payment account: 6000 · Travel Expenses'),
      findsOneWidget,
    );
  });

  testWidgets('selects fetched accounts as expense and payment defaults', (
    tester,
  ) async {
    useTallTestViewport(tester);
    final settingsRepository = MemorySyncSettingsRepository(
      const SyncSettings(accessToken: 'token-1', organizationId: 'org-1'),
    );

    await tester.pumpWidget(
      AccountingApp(
        settingsRepository: settingsRepository,
        accountLoader: (_) async => const [
          AccountSummary(
            id: 'acct-expense',
            code: '5000',
            name: 'Office Supplies',
            type: 'expense',
            currency: 'INR',
            isActive: true,
          ),
          AccountSummary(
            id: 'acct-cash',
            code: '1000',
            name: 'Cash',
            type: 'asset',
            currency: 'INR',
            isActive: true,
          ),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Sync'));
    await tester.pump();
    await tester.tap(find.text('Fetch accounts'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use as expense').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use as payment').last);
    await tester.pumpAndSettle();

    final saved = await settingsRepository.load();
    expect(saved.defaultExpenseAccountId, 'acct-expense');
    expect(saved.defaultPaymentAccountId, 'acct-cash');
    expect(saved.canSyncExpenses, true);
    expect(find.text('Default payment account set to 1000.'), findsOneWidget);
  });

  testWidgets('fetches and caches customers and vendors from saved settings', (
    tester,
  ) async {
    useTallTestViewport(tester);
    final settingsRepository = MemorySyncSettingsRepository(
      const SyncSettings(accessToken: 'token-1', organizationId: 'org-1'),
    );
    final partyCacheRepository = MemoryPartyCacheRepository();

    await tester.pumpWidget(
      AccountingApp(
        settingsRepository: settingsRepository,
        partyCacheRepository: partyCacheRepository,
        customerLoader: (_) async => const [
          CustomerSummary(
            id: 'customer-1',
            organizationId: 'org-1',
            displayName: 'Acme Exports',
            email: 'billing@acme.test',
            phone: '+91-99999-00001',
            gstin: '27ABCDE1234F1Z5',
            isActive: true,
          ),
        ],
        vendorLoader: (_) async => const [
          VendorSummary(
            id: 'vendor-1',
            organizationId: 'org-1',
            displayName: 'Stationery House',
            email: 'ap@stationery.test',
            phone: '+91-99999-00002',
            gstin: '27ABCDE1234F1Z6',
            isActive: true,
          ),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Sync'));
    await tester.pump();
    await tester.tap(find.text('Fetch customers/vendors'));
    await tester.pumpAndSettle();

    final cached = await partyCacheRepository.loadCached();
    expect(cached.customers.single.displayName, 'Acme Exports');
    expect(cached.vendors.single.displayName, 'Stationery House');
    expect(find.text('Fetched 1 customers and 1 vendors.'), findsOneWidget);
    expect(find.text('Customers (1)'), findsOneWidget);
    expect(find.text('Acme Exports'), findsOneWidget);
    expect(
      find.text('billing@acme.test · +91-99999-00001 · GSTIN 27ABCDE1234F1Z5'),
      findsOneWidget,
    );
    expect(find.text('Party ID: customer-1'), findsOneWidget);
    expect(find.text('Vendors (1)'), findsOneWidget);
    expect(find.text('Stationery House'), findsOneWidget);
    expect(find.text('Party ID: vendor-1'), findsOneWidget);
  });

  testWidgets('fetches and selects tax defaults from saved settings', (
    tester,
  ) async {
    useTallTestViewport(tester);
    final settingsRepository = MemorySyncSettingsRepository(
      const SyncSettings(accessToken: 'token-1', organizationId: 'org-1'),
    );
    final taxCatalogCacheRepository = MemoryTaxCatalogCacheRepository();

    await tester.pumpWidget(
      AccountingApp(
        settingsRepository: settingsRepository,
        taxCatalogCacheRepository: taxCatalogCacheRepository,
        taxRateLoader: (_) async => const [
          TaxRateSummary(
            id: 'tax-rate-1',
            name: 'GST 18%',
            type: 'GST',
            percentageBasis: 180000,
            isActive: true,
          ),
        ],
        taxGroupLoader: (_) async => const [
          TaxGroupSummary(
            id: 'tax-group-1',
            name: 'CGST + SGST 18%',
            isActive: true,
            description: 'Split GST',
          ),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Sync'));
    await tester.pump();
    await tester.tap(find.text('Fetch tax config'));
    await tester.pumpAndSettle();

    expect(find.text('Fetched 1 tax rates and 1 tax groups.'), findsOneWidget);
    expect(find.text('GST 18% · 18.00% · GST · tax-rate-1'), findsOneWidget);
    expect(find.text('CGST + SGST 18% · tax-group-1'), findsOneWidget);

    await tester.tap(find.text('Use as tax rate'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Use as tax group'));
    await tester.tap(find.text('Use as tax group'));
    await tester.pumpAndSettle();

    final saved = await settingsRepository.load();
    final cached = await taxCatalogCacheRepository.loadCached();
    expect(saved.defaultTaxRateId, '');
    expect(saved.defaultTaxGroupId, 'tax-group-1');
    expect(cached.rates.single.id, 'tax-rate-1');
    expect(cached.groups.single.id, 'tax-group-1');
    expect(
      find.text('Default tax group set to CGST + SGST 18%.'),
      findsOneWidget,
    );
  });

  testWidgets('hydrates cached tax config into the sync page', (tester) async {
    useTallTestViewport(tester);
    final settingsRepository = MemorySyncSettingsRepository(
      const SyncSettings(
        defaultTaxRateId: 'tax-rate-cached',
        defaultTaxGroupId: 'tax-group-cached',
      ),
    );
    final taxCatalogCacheRepository = MemoryTaxCatalogCacheRepository(
      const TaxCatalogSnapshot(
        rates: [
          TaxRateSummary(
            id: 'tax-rate-cached',
            name: 'GST 5%',
            type: 'GST',
            percentageBasis: 50000,
            isActive: true,
          ),
        ],
        groups: [
          TaxGroupSummary(
            id: 'tax-group-cached',
            name: 'CGST + SGST 5%',
            isActive: true,
            description: 'Cached split GST',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      AccountingApp(
        settingsRepository: settingsRepository,
        taxCatalogCacheRepository: taxCatalogCacheRepository,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Sync'));
    await tester.pump();

    expect(find.text('GST 5% · 5.00% · GST · tax-rate-cached'), findsOneWidget);
    expect(find.text('CGST + SGST 5% · tax-group-cached'), findsOneWidget);
    expect(find.text('Resolved tax rate: GST 5% · 5.00%'), findsOneWidget);
    expect(find.text('Resolved tax group: CGST + SGST 5%'), findsOneWidget);
  });

  testWidgets('fetches and displays attachment metadata from saved settings', (
    tester,
  ) async {
    useTallTestViewport(tester);
    final settingsRepository = MemorySyncSettingsRepository(
      const SyncSettings(accessToken: 'token-1', organizationId: 'org-1'),
    );
    final attachmentCacheRepository = MemoryAttachmentCacheRepository();

    await tester.pumpWidget(
      AccountingApp(
        settingsRepository: settingsRepository,
        attachmentCacheRepository: attachmentCacheRepository,
        attachmentLoader: (_) async => const [
          AttachmentSummary(
            id: 'attachment-1',
            fileName: 'receipt.jpg',
            contentType: 'image/jpeg',
            storageDriver: 'local',
            storageKey: 'org-1/attachment-1/receipt.jpg',
            sizeBytes: 2048,
          ),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Sync'));
    await tester.pump();
    await tester.tap(find.text('Fetch attachments'));
    await tester.pumpAndSettle();

    expect(find.text('Fetched 1 attachments.'), findsOneWidget);
    expect((await attachmentCacheRepository.loadCached()), hasLength(1));
    expect(find.text('receipt.jpg · image/jpeg · 2048 bytes'), findsOneWidget);
    expect(find.text('Attachment ID: attachment-1'), findsOneWidget);
    expect(find.text('Not downloaded'), findsOneWidget);
    expect(
      find.text('Storage: local · org-1/attachment-1/receipt.jpg'),
      findsOneWidget,
    );
  });

  testWidgets('uploads sample attachment bytes from the sync page', (
    tester,
  ) async {
    useTallTestViewport(tester);
    final settingsRepository = MemorySyncSettingsRepository(
      const SyncSettings(accessToken: 'token-1', organizationId: 'org-1'),
    );
    final attachmentCacheRepository = MemoryAttachmentCacheRepository();
    final attachmentBinaryCacheRepository =
        MemoryAttachmentBinaryCacheRepository();

    await tester.pumpWidget(
      AccountingApp(
        settingsRepository: settingsRepository,
        attachmentCacheRepository: attachmentCacheRepository,
        attachmentBinaryCacheRepository: attachmentBinaryCacheRepository,
        attachmentUploader: (_, fileName, bytes) async {
          expect(fileName, 'sample-receipt.txt');
          expect(
            String.fromCharCodes(bytes),
            'Sample receipt captured offline-first',
          );
          return const AttachmentSummary(
            id: 'attachment-uploaded',
            fileName: 'sample-receipt.txt',
            contentType: 'text/plain',
            storageDriver: 'local',
            storageKey: 'org-1/attachment-uploaded/sample-receipt.txt',
            sizeBytes: 37,
          );
        },
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Sync'));
    await tester.pump();
    await tester.tap(find.text('Upload sample receipt'));
    await tester.pumpAndSettle();

    expect(
      find.text('Uploaded attachment sample-receipt.txt.'),
      findsOneWidget,
    );
    expect((await attachmentCacheRepository.loadCached()), hasLength(1));
    final uploadedBinary = await attachmentBinaryCacheRepository.loadDownloaded(
      'attachment-uploaded',
    );
    expect(uploadedBinary, isNotNull);
    expect(
      find.text('sample-receipt.txt · text/plain · 37 bytes'),
      findsOneWidget,
    );
    expect(find.text('Attachment ID: attachment-uploaded'), findsOneWidget);
    expect(find.text('Available offline'), findsOneWidget);
  });

  testWidgets('uploads a picked receipt file from the sync page', (
    tester,
  ) async {
    useTallTestViewport(tester);
    final settingsRepository = MemorySyncSettingsRepository(
      const SyncSettings(accessToken: 'token-1', organizationId: 'org-1'),
    );
    final attachmentCacheRepository = MemoryAttachmentCacheRepository();
    final attachmentBinaryCacheRepository =
        MemoryAttachmentBinaryCacheRepository();

    await tester.pumpWidget(
      AccountingApp(
        settingsRepository: settingsRepository,
        attachmentCacheRepository: attachmentCacheRepository,
        attachmentBinaryCacheRepository: attachmentBinaryCacheRepository,
        attachmentPicker: (source) async {
          expect(source, AttachmentPickSource.file);
          return const PickedAttachmentFile(
            fileName: 'picked-receipt.pdf',
            bytes: [1, 2, 3, 4],
            localFilePath: '/tmp/picked-receipt.pdf',
            contentType: 'application/pdf',
          );
        },
        attachmentUploader: (_, fileName, bytes) async {
          expect(fileName, 'picked-receipt.pdf');
          expect(bytes, [1, 2, 3, 4]);
          return const AttachmentSummary(
            id: 'attachment-picked',
            fileName: 'picked-receipt.pdf',
            contentType: 'application/pdf',
            storageDriver: 'local',
            storageKey: 'org-1/attachment-picked/picked-receipt.pdf',
            sizeBytes: 4,
          );
        },
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Sync'));
    await tester.pump();
    await tester.tap(find.text('Choose receipt/PDF'));
    await tester.pumpAndSettle();

    expect(
      find.text('Uploaded attachment picked-receipt.pdf.'),
      findsOneWidget,
    );
    expect((await attachmentCacheRepository.loadCached()), hasLength(1));
    expect(
      await attachmentBinaryCacheRepository.loadDownloaded('attachment-picked'),
      isNotNull,
    );
    expect(
      find.text('picked-receipt.pdf · application/pdf · 4 bytes'),
      findsOneWidget,
    );
  });

  testWidgets(
    'queues picked camera receipts offline when credentials are absent',
    (tester) async {
      useTallTestViewport(tester);
      final syncRepository = MemorySyncOperationRepository();
      final uploadManifestRepository =
          MemoryAttachmentUploadManifestRepository();

      await tester.pumpWidget(
        AccountingApp(
          syncRepository: syncRepository,
          attachmentUploadManifestRepository: uploadManifestRepository,
          attachmentPicker: (source) async {
            expect(source, AttachmentPickSource.camera);
            return const PickedAttachmentFile(
              fileName: 'camera-receipt.jpg',
              bytes: [9, 8, 7],
              localFilePath: '/tmp/camera-receipt.jpg',
              contentType: 'image/jpeg',
            );
          },
          attachmentUploader: (_, _, _) async {
            fail('offline picked receipts should queue instead of uploading');
          },
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Sync'));
      await tester.pump();
      await tester.tap(find.text('Camera receipt'));
      await tester.pumpAndSettle();

      final pending = await syncRepository.loadPending();
      expect(pending, hasLength(4));
      final upload = pending.last;
      expect(upload.module, 'attachments');
      expect(upload.action, 'upload_binary');
      expect(upload.payload['file_name'], 'camera-receipt.jpg');
      expect(upload.payload['local_file_path'], '/tmp/camera-receipt.jpg');
      final manifest = await uploadManifestRepository.loadPending();
      expect(manifest.single.fileName, 'camera-receipt.jpg');
      expect(manifest.single.contentType, 'image/jpeg');
      expect(
        find.text('Attachment upload queued for sync: camera-receipt.jpg'),
        findsOneWidget,
      );
    },
  );

  testWidgets('hydrates cached attachments into the sync page', (tester) async {
    useTallTestViewport(tester);
    final attachmentCacheRepository = MemoryAttachmentCacheRepository([
      const AttachmentSummary(
        id: 'attachment-cached',
        fileName: 'invoice.pdf',
        contentType: 'application/pdf',
        storageDriver: 'local',
        storageKey: 'org-1/attachment-cached/invoice.pdf',
        sizeBytes: 4096,
      ),
    ]);
    final attachmentBinaryCacheRepository =
        MemoryAttachmentBinaryCacheRepository();
    await attachmentBinaryCacheRepository.saveDownloaded(
      'attachment-cached',
      AttachmentDownload(
        bytes: Uint8List.fromList('cached pdf'.codeUnits),
        contentType: 'application/pdf',
        fileName: 'invoice.pdf',
      ),
    );

    await tester.pumpWidget(
      AccountingApp(
        attachmentCacheRepository: attachmentCacheRepository,
        attachmentBinaryCacheRepository: attachmentBinaryCacheRepository,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Sync'));
    await tester.pump();

    expect(
      find.text('invoice.pdf · application/pdf · 4096 bytes'),
      findsOneWidget,
    );
    expect(find.text('Attachment ID: attachment-cached'), findsOneWidget);
    expect(find.text('Available offline'), findsOneWidget);

    await tester.tap(find.text('Inspect cached'));
    await tester.pumpAndSettle();

    expect(
      find.text('Cached invoice.pdf: application/pdf, 10 bytes.'),
      findsOneWidget,
    );
  });

  testWidgets('downloads cached attachment bytes from the sync page', (
    tester,
  ) async {
    useTallTestViewport(tester);
    final settingsRepository = MemorySyncSettingsRepository(
      const SyncSettings(accessToken: 'token-1', organizationId: 'org-1'),
    );
    final attachmentCacheRepository = MemoryAttachmentCacheRepository([
      const AttachmentSummary(
        id: 'attachment-cached',
        fileName: 'receipt.txt',
        contentType: 'text/plain',
        storageDriver: 'local',
        storageKey: 'org-1/attachment-cached/receipt.txt',
        sizeBytes: 13,
      ),
    ]);
    final attachmentBinaryCacheRepository =
        MemoryAttachmentBinaryCacheRepository();

    await tester.pumpWidget(
      AccountingApp(
        settingsRepository: settingsRepository,
        attachmentCacheRepository: attachmentCacheRepository,
        attachmentBinaryCacheRepository: attachmentBinaryCacheRepository,
        attachmentDownloader: (_, attachment) async {
          expect(attachment.id, 'attachment-cached');
          return AttachmentDownload(
            bytes: Uint8List.fromList('hello receipt'.codeUnits),
            contentType: 'text/plain',
            fileName: 'receipt.txt',
          );
        },
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Sync'));
    await tester.pump();
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();

    expect(find.text('Downloaded receipt.txt (13 bytes).'), findsOneWidget);
    expect(find.text('Available offline'), findsOneWidget);
    final cached = await attachmentBinaryCacheRepository.loadDownloaded(
      'attachment-cached',
    );
    expect(cached, isNotNull);
    expect(String.fromCharCodes(cached!.bytes), 'hello receipt');

    await tester.tap(find.text('Inspect cached'));
    await tester.pumpAndSettle();

    expect(
      find.text('Cached receipt.txt: text/plain, 13 bytes.'),
      findsOneWidget,
    );
  });

  testWidgets('hydrates cached invoices into the invoices page', (
    tester,
  ) async {
    final invoiceCacheRepository = MemoryInvoiceCacheRepository([
      const InvoiceSummary(
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
      ),
    ]);

    await tester.pumpWidget(
      AccountingApp(invoiceCacheRepository: invoiceCacheRepository),
    );
    await tester.pump();

    await tester.tap(find.text('Invoices'));
    await tester.pump();

    expect(find.text('Cached invoices'), findsOneWidget);
    expect(find.text('INV-001'), findsOneWidget);
    expect(find.text('INR 1180.00 · sent'), findsOneWidget);
    expect(find.text('Subtotal: INR 1000.00'), findsOneWidget);
    expect(find.text('Tax: INR 180.00'), findsOneWidget);
    expect(find.text('PDF attachment: pdf-1'), findsOneWidget);
    expect(find.text('Line items'), findsOneWidget);
    expect(find.text('Implementation'), findsOneWidget);
    expect(find.text('Line subtotal: INR 1000.00'), findsOneWidget);
    expect(find.text('Line tax: INR 180.00'), findsOneWidget);
    expect(find.text('Line total: INR 1180.00'), findsOneWidget);
    expect(find.text('Tax config: gst-18'), findsOneWidget);
    expect(find.text('inv-1'), findsOneWidget);
  });

  testWidgets('fetches invoices and saves them for offline viewing', (
    tester,
  ) async {
    final settingsRepository = MemorySyncSettingsRepository(
      const SyncSettings(accessToken: 'token-1', organizationId: 'org-1'),
    );
    final invoiceCacheRepository = MemoryInvoiceCacheRepository();

    await tester.pumpWidget(
      AccountingApp(
        settingsRepository: settingsRepository,
        invoiceCacheRepository: invoiceCacheRepository,
        invoiceLoader: (_) async => const [
          InvoiceSummary(
            id: 'inv-2',
            invoiceNumber: 'INV-002',
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
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Invoices'));
    await tester.pump();
    await tester.tap(find.text('Refresh cache'));
    await tester.pumpAndSettle();

    final cached = await invoiceCacheRepository.loadCached();
    expect(cached.single.id, 'inv-2');
    expect(find.text('INV-002'), findsOneWidget);
    expect(find.text('INR 2360.00 · paid'), findsOneWidget);
    expect(find.text('Subtotal: INR 2000.00'), findsOneWidget);
    expect(find.text('Tax: INR 360.00'), findsOneWidget);
    expect(find.text('PDF attachment: pdf-2'), findsOneWidget);
    expect(find.text('Annual support'), findsOneWidget);
    expect(find.text('Tax config: gst-rate-18'), findsOneWidget);
  });

  testWidgets('fetches and caches core financial reports', (tester) async {
    useTallTestViewport(tester);
    final settingsRepository = MemorySyncSettingsRepository(
      const SyncSettings(accessToken: 'token-1', organizationId: 'org-1'),
    );
    final reportCacheRepository = MemoryReportCacheRepository();

    await tester.pumpWidget(
      AccountingApp(
        settingsRepository: settingsRepository,
        reportCacheRepository: reportCacheRepository,
        trialBalanceLoader: (_, asOf) async => TrialBalanceReport(
          asOfDate: asOf,
          rows: const [
            ReportRowSummary(
              accountId: 'acct-cash',
              accountCode: '1000',
              accountName: 'Cash',
              accountType: 'asset',
              debitMinor: 125000,
              creditMinor: 0,
              balanceMinor: 125000,
            ),
            ReportRowSummary(
              accountId: 'acct-equity',
              accountCode: '3000',
              accountName: 'Owner Equity',
              accountType: 'equity',
              debitMinor: 0,
              creditMinor: 125000,
              balanceMinor: -125000,
            ),
          ],
          totalDebitMinor: 125000,
          totalCreditMinor: 125000,
          balanced: true,
        ),
        profitAndLossLoader: (_, from, to) async => ProfitAndLossReport(
          fromDate: from,
          toDate: to,
          incomeRows: const [
            ReportRowSummary(
              accountId: 'acct-sales',
              accountCode: '4000',
              accountName: 'Sales',
              accountType: 'income',
              debitMinor: 0,
              creditMinor: 500000,
              balanceMinor: -500000,
            ),
          ],
          expenseRows: const [
            ReportRowSummary(
              accountId: 'acct-rent',
              accountCode: '5000',
              accountName: 'Rent',
              accountType: 'expense',
              debitMinor: 150000,
              creditMinor: 0,
              balanceMinor: 150000,
            ),
          ],
          totalIncomeMinor: 500000,
          totalExpenseMinor: 150000,
          netIncomeMinor: 350000,
        ),
        balanceSheetLoader: (_, asOf) async => BalanceSheetReport(
          asOfDate: asOf,
          assetRows: const [
            ReportRowSummary(
              accountId: 'acct-bank',
              accountCode: '1010',
              accountName: 'Bank',
              accountType: 'asset',
              debitMinor: 350000,
              creditMinor: 0,
              balanceMinor: 350000,
            ),
          ],
          liabilityRows: const [],
          equityRows: const [
            ReportRowSummary(
              accountId: 'acct-retained',
              accountCode: '3100',
              accountName: 'Retained Earnings',
              accountType: 'equity',
              debitMinor: 0,
              creditMinor: 350000,
              balanceMinor: -350000,
            ),
          ],
          totalAssetsMinor: 350000,
          totalLiabilitiesMinor: 0,
          totalEquityMinor: 350000,
          balanced: true,
        ),
        cashFlowLoader: (_, from, to) async => CashFlowReport(
          fromDate: from,
          toDate: to,
          rows: const [
            CashFlowRow(
              accountId: 'acct-bank',
              accountCode: '1010',
              accountName: 'Bank',
              sourceModule: 'invoice',
              inflowMinor: 500000,
              outflowMinor: 150000,
              netCashFlowMinor: 350000,
            ),
          ],
          totalInflowsMinor: 500000,
          totalOutflowsMinor: 150000,
          netCashFlowMinor: 350000,
          openingCashMinor: 250000,
          closingCashMinor: 600000,
          generatedFromSubtypes: const ['bank', 'cash'],
        ),
        arAgingLoader: (_, asOf) async => ARAgingReport(
          asOfDate: asOf,
          rows: [
            ARAgingRow(
              customerId: 'cust-1',
              customerName: 'Acme',
              invoiceId: 'inv-1',
              invoiceNumber: 'INV-001',
              dueDate: DateTime.utc(2026, 7, 1),
              daysOverdue: 30,
              outstandingMinor: 118000,
              currentMinor: 0,
              oneToThirtyMinor: 118000,
              thirtyOneToSixtyMinor: 0,
              sixtyOneToNinetyMinor: 0,
              overNinetyMinor: 0,
            ),
          ],
          totalCurrentMinor: 0,
          totalOneToThirtyMinor: 118000,
          totalThirtyOneToSixtyMinor: 0,
          totalSixtyOneToNinetyMinor: 0,
          totalOverNinetyMinor: 0,
          totalOutstandingMinor: 118000,
        ),
        apAgingLoader: (_, asOf) async => APAgingReport(
          asOfDate: asOf,
          rows: [
            APAgingRow(
              vendorId: 'vendor-1',
              vendorName: 'Office Supplies Co',
              billId: 'bill-1',
              billNumber: 'BILL-001',
              dueDate: DateTime.utc(2026, 6, 30),
              daysOverdue: 31,
              outstandingMinor: 59000,
              currentMinor: 0,
              oneToThirtyMinor: 0,
              thirtyOneToSixtyMinor: 59000,
              sixtyOneToNinetyMinor: 0,
              overNinetyMinor: 0,
            ),
          ],
          totalCurrentMinor: 0,
          totalOneToThirtyMinor: 0,
          totalThirtyOneToSixtyMinor: 59000,
          totalSixtyOneToNinetyMinor: 0,
          totalOverNinetyMinor: 0,
          totalOutstandingMinor: 59000,
        ),
        taxLiabilityReportLoader: (_, from, to) async => TaxLiabilityReport(
          fromDate: from,
          toDate: to,
          outputTaxMinor: 90000,
          inputTaxMinor: 27000,
          netPayableMinor: 63000,
          rows: const [
            TaxReportRowSummary(
              taxRateId: 'gst-18',
              taxGroupId: '',
              name: 'GST 18%',
              outputTaxMinor: 90000,
              inputTaxMinor: 27000,
              netPayableMinor: 63000,
            ),
          ],
        ),
        taxSummaryReportLoader: (_, from, to) async => TaxSummaryReport(
          fromDate: from,
          toDate: to,
          rows: const [
            TaxReportRowSummary(
              taxRateId: 'gst-18',
              taxGroupId: 'gst-group-18',
              name: 'GST 18%',
              outputTaxMinor: 90000,
              inputTaxMinor: 27000,
              netPayableMinor: 63000,
            ),
          ],
        ),
        budgetLoader: (_) async => [
          BudgetSummary(
            id: 'budget-1',
            organizationId: 'org-1',
            name: 'FY 2026 Operating Budget',
            startDate: DateTime.utc(2026, 4),
            endDate: DateTime.utc(2027, 3, 31),
            status: 'active',
            lines: [
              BudgetLineSummary(
                id: 'budget-line-1',
                accountId: 'acct-rent',
                periodStart: DateTime.utc(2026, 4),
                periodEnd: DateTime.utc(2026, 4, 30),
                amountMinor: 150000,
              ),
            ],
          ),
        ],
        budgetVsActualLoader: (_, budgetId) async => BudgetVsActualReport(
          budgetId: budgetId,
          rows: [
            BudgetVsActualReportRow(
              accountId: 'acct-rent',
              accountCode: '5000',
              accountName: 'Rent',
              periodStart: DateTime.utc(2026, 4),
              periodEnd: DateTime.utc(2026, 4, 30),
              budgetMinor: 150000,
              actualMinor: 125000,
              varianceMinor: 25000,
              variancePercentBasis: 1667,
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Reports'));
    await tester.pump();
    await tester.tap(find.text('Fetch trial balance'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Fetch P&L'));
    await tester.tap(find.text('Fetch P&L'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Fetch balance sheet'));
    await tester.tap(find.text('Fetch balance sheet'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Fetch cash flow'));
    await tester.tap(find.text('Fetch cash flow'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Fetch AR aging'));
    await tester.tap(find.text('Fetch AR aging'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Fetch AP aging'));
    await tester.tap(find.text('Fetch AP aging'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Fetch tax liability'));
    await tester.tap(find.text('Fetch tax liability'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Fetch tax summary'));
    await tester.tap(find.text('Fetch tax summary'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Fetch budgets'));
    await tester.tap(find.text('Fetch budgets'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Fetch budget vs actual'));
    await tester.tap(find.text('Fetch budget vs actual'));
    await tester.pumpAndSettle();

    final cached = await reportCacheRepository.loadCached();
    expect(cached.trialBalance?.balanced, true);
    expect(cached.trialBalance?.rows, hasLength(2));
    expect(cached.profitAndLoss?.netIncomeMinor, 350000);
    expect(cached.balanceSheet?.balanced, true);
    expect(cached.cashFlow?.closingCashMinor, 600000);
    expect(cached.arAging?.totalOutstandingMinor, 118000);
    expect(cached.apAging?.totalOutstandingMinor, 59000);
    expect(cached.taxLiability?.netPayableMinor, 63000);
    expect(cached.taxSummary?.rows.single.taxGroupId, 'gst-group-18');
    expect(cached.budgets.single.name, 'FY 2026 Operating Budget');
    expect(cached.budgetVsActual?.totalVarianceMinor, 25000);
    expect(find.text('Net payable INR 630.00'), findsOneWidget);
    expect(
      find.text(
        'GST 18% · Output INR 900.00 · Input INR 270.00 · Net INR 630.00',
      ),
      findsNWidgets(2),
    );
    expect(find.text('Variance INR 250.00'), findsOneWidget);
    expect(
      find.text(
        '5000 · Rent · Budget INR 1500.00 · Actual INR 1250.00 · Var INR 250.00',
      ),
      findsOneWidget,
    );
    expect(find.text('10 CSV exports ready from cache.'), findsOneWidget);
    expect(find.textContaining('trial_balance_'), findsWidgets);
  });

  testWidgets('fetches and caches investment valuation reports', (
    tester,
  ) async {
    useTallTestViewport(tester);
    final settingsRepository = MemorySyncSettingsRepository(
      const SyncSettings(accessToken: 'token-1', organizationId: 'org-1'),
    );
    final investmentCacheRepository = MemoryInvestmentCacheRepository();

    await tester.pumpWidget(
      AccountingApp(
        settingsRepository: settingsRepository,
        investmentCacheRepository: investmentCacheRepository,
        investmentValuationLoader: (_, asOf) async => InvestmentValuationReport(
          asOfDate: asOf,
          rows: [
            InvestmentValuationRow(
              lotId: 'lot-1',
              accountId: 'brokerage-1',
              symbol: 'NIFTYBEES',
              securityName: 'Nippon India ETF Nifty BeES',
              acquisitionDate: DateTime.utc(2026, 4),
              remainingQuantityMillis: 60000,
              remainingCostBasisMinor: 600000,
              marketPriceMinor: 14000,
              marketValueMinor: 840000,
              unrealizedGainLossMinor: 240000,
              currency: 'INR',
              priceDate: asOf,
            ),
          ],
          totalCostBasisMinor: 600000,
          totalMarketValueMinor: 840000,
          totalUnrealizedGainLossMinor: 240000,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Investments'));
    await tester.pump();
    await tester.ensureVisible(find.text('Fetch valuation'));
    await tester.tap(find.text('Fetch valuation'));
    await tester.pumpAndSettle();

    final cached = await investmentCacheRepository.loadCached();
    expect(cached.valuationReport?.totalMarketValueMinor, 840000);
    expect(find.text('Market value: INR 8400.00'), findsOneWidget);
    expect(find.textContaining('NIFTYBEES'), findsWidgets);
    expect(find.textContaining('INR 2400.00 unrealized'), findsOneWidget);
  });
}
