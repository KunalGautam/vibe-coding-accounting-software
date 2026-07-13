import 'dart:io';

import 'package:accounting_app/settings/sync_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects whether expense sync settings are complete', () {
    expect(const SyncSettings().canSyncExpenses, false);

    const complete = SyncSettings(
      accessToken: 'token',
      organizationId: 'org-1',
      defaultExpenseAccountId: 'expense-account',
      defaultPaymentAccountId: 'cash-account',
      defaultTaxRateId: 'tax-rate-1',
      defaultTaxGroupId: 'tax-group-1',
    );

    expect(complete.canSyncExpenses, true);
    expect(complete.toApiConfig().organizationId, 'org-1');
  });

  test(
    'allows account lookup before default posting accounts are selected',
    () {
      const lookupReady = SyncSettings(
        accessToken: 'token',
        organizationId: 'org-1',
      );

      expect(lookupReady.canFetchAccounts, true);
      expect(lookupReady.canSyncExpenses, false);
    },
  );

  test('serializes and hydrates sync settings', () {
    const settings = SyncSettings(
      apiBaseUrl: 'http://api.test/api/v1',
      accessToken: 'token',
      organizationId: 'org-1',
      defaultExpenseAccountId: 'expense-account',
      defaultPaymentAccountId: 'cash-account',
      defaultTaxRateId: 'tax-rate-1',
      defaultTaxGroupId: 'tax-group-1',
    );

    final hydrated = SyncSettings.fromJson(settings.toJson());

    expect(hydrated.apiBaseUrl, settings.apiBaseUrl);
    expect(hydrated.accessToken, settings.accessToken);
    expect(hydrated.defaultPaymentAccountId, 'cash-account');
    expect(hydrated.defaultTaxRateId, 'tax-rate-1');
    expect(hydrated.defaultTaxGroupId, 'tax-group-1');
  });

  test('file repository persists settings', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ledger-settings-test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = FileSyncSettingsRepository(
      File('${directory.path}/sync-settings.json'),
    );

    await repository.save(
      const SyncSettings(
        accessToken: 'token',
        organizationId: 'org-1',
        defaultExpenseAccountId: 'expense-account',
        defaultPaymentAccountId: 'cash-account',
      ),
    );

    final loaded = await repository.load();
    expect(loaded.accessToken, 'token');
    expect(loaded.canSyncExpenses, true);
  });
}
