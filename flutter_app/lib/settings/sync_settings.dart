import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../api/accounting_api_client.dart';
import '../storage/offline_sqlite.dart';

class SyncSettings {
  const SyncSettings({
    this.apiBaseUrl = 'http://localhost:8080/api/v1',
    this.accessToken = '',
    this.organizationId = '',
    this.defaultExpenseAccountId = '',
    this.defaultPaymentAccountId = '',
    this.defaultTaxRateId = '',
    this.defaultTaxGroupId = '',
  });

  final String apiBaseUrl;
  final String accessToken;
  final String organizationId;
  final String defaultExpenseAccountId;
  final String defaultPaymentAccountId;
  final String defaultTaxRateId;
  final String defaultTaxGroupId;

  bool get canSyncExpenses {
    return canFetchAccounts &&
        defaultExpenseAccountId.trim().isNotEmpty &&
        defaultPaymentAccountId.trim().isNotEmpty;
  }

  bool get canFetchAccounts {
    return apiBaseUrl.trim().isNotEmpty &&
        accessToken.trim().isNotEmpty &&
        organizationId.trim().isNotEmpty;
  }

  AccountingApiConfig toApiConfig() {
    return AccountingApiConfig(
      baseUrl: apiBaseUrl.trim(),
      accessToken: accessToken.trim(),
      organizationId: organizationId.trim(),
    );
  }

  SyncSettings copyWith({
    String? apiBaseUrl,
    String? accessToken,
    String? organizationId,
    String? defaultExpenseAccountId,
    String? defaultPaymentAccountId,
    String? defaultTaxRateId,
    String? defaultTaxGroupId,
  }) {
    return SyncSettings(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      accessToken: accessToken ?? this.accessToken,
      organizationId: organizationId ?? this.organizationId,
      defaultExpenseAccountId:
          defaultExpenseAccountId ?? this.defaultExpenseAccountId,
      defaultPaymentAccountId:
          defaultPaymentAccountId ?? this.defaultPaymentAccountId,
      defaultTaxRateId: defaultTaxRateId ?? this.defaultTaxRateId,
      defaultTaxGroupId: defaultTaxGroupId ?? this.defaultTaxGroupId,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'api_base_url': apiBaseUrl,
      'access_token': accessToken,
      'organization_id': organizationId,
      'default_expense_account_id': defaultExpenseAccountId,
      'default_payment_account_id': defaultPaymentAccountId,
      'default_tax_rate_id': defaultTaxRateId,
      'default_tax_group_id': defaultTaxGroupId,
    };
  }

  factory SyncSettings.fromJson(Map<String, Object?> json) {
    return SyncSettings(
      apiBaseUrl:
          json['api_base_url'] as String? ?? const SyncSettings().apiBaseUrl,
      accessToken: json['access_token'] as String? ?? '',
      organizationId: json['organization_id'] as String? ?? '',
      defaultExpenseAccountId:
          json['default_expense_account_id'] as String? ?? '',
      defaultPaymentAccountId:
          json['default_payment_account_id'] as String? ?? '',
      defaultTaxRateId: json['default_tax_rate_id'] as String? ?? '',
      defaultTaxGroupId: json['default_tax_group_id'] as String? ?? '',
    );
  }
}

abstract interface class SyncSettingsRepository {
  Future<SyncSettings> load();

  Future<void> save(SyncSettings settings);
}

class MemorySyncSettingsRepository implements SyncSettingsRepository {
  MemorySyncSettingsRepository([SyncSettings? seed])
    : _settings = seed ?? const SyncSettings();

  SyncSettings _settings;

  @override
  Future<SyncSettings> load() async => _settings;

  @override
  Future<void> save(SyncSettings settings) async {
    _settings = settings;
  }
}

class FileSyncSettingsRepository implements SyncSettingsRepository {
  const FileSyncSettingsRepository(this.file);

  final File file;

  @override
  Future<SyncSettings> load() async {
    if (!await file.exists()) {
      return const SyncSettings();
    }

    final contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      return const SyncSettings();
    }

    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Expected sync settings JSON object');
    }
    return SyncSettings.fromJson(decoded);
  }

  @override
  Future<void> save(SyncSettings settings) async {
    await file.parent.create(recursive: true);
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(jsonEncode(settings.toJson()), flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }
}

class SqliteSyncSettingsRepository implements SyncSettingsRepository {
  const SqliteSyncSettingsRepository(this.database);

  final Database database;

  @override
  Future<SyncSettings> load() async {
    final rows = await database.query(
      'sync_settings',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isEmpty) {
      return const SyncSettings();
    }
    return _settingsFromRow(rows.single);
  }

  @override
  Future<void> save(SyncSettings settings) async {
    await database.insert(
      'sync_settings',
      _settingsToRow(settings),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

Future<void> createSyncSettingsTables(DatabaseExecutor database) async {
  await database.execute('''
CREATE TABLE IF NOT EXISTS sync_settings (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  api_base_url TEXT NOT NULL,
  access_token TEXT NOT NULL DEFAULT '',
  organization_id TEXT NOT NULL DEFAULT '',
  default_expense_account_id TEXT NOT NULL DEFAULT '',
  default_payment_account_id TEXT NOT NULL DEFAULT '',
  default_tax_rate_id TEXT NOT NULL DEFAULT '',
  default_tax_group_id TEXT NOT NULL DEFAULT ''
)
''');
}

Map<String, Object?> _settingsToRow(SyncSettings settings) {
  return {'id': 1, ...settings.toJson()};
}

SyncSettings _settingsFromRow(Map<String, Object?> row) {
  return SyncSettings.fromJson(row);
}

Future<SyncSettingsRepository> createDefaultSyncSettingsRepository() async {
  final database = await openOfflineDatabase(
    fileName: 'offline-settings.sqlite',
    version: 1,
    onCreate: (database, _) => createSyncSettingsTables(database),
  );
  return SqliteSyncSettingsRepository(database);
}
