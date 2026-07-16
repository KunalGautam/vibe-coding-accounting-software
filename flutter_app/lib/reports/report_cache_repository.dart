import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../api/accounting_api_client.dart';
import '../storage/offline_sqlite.dart';

Future<ReportCacheRepository> createDefaultReportCacheRepository() async {
  final database = await openOfflineDatabase(
    fileName: 'offline-reports.sqlite',
    version: 1,
    onCreate: (database, _) => createReportCacheTables(database),
  );
  return SqliteReportCacheRepository(database);
}

class ReportCacheSnapshot {
  const ReportCacheSnapshot({this.trialBalance});

  final TrialBalanceReport? trialBalance;

  factory ReportCacheSnapshot.fromJson(Map<String, Object?> json) {
    return ReportCacheSnapshot(
      trialBalance: json['trial_balance'] is Map<String, Object?>
          ? TrialBalanceReport.fromJson(
              json['trial_balance']! as Map<String, Object?>,
            )
          : null,
    );
  }

  Map<String, Object?> toJson() {
    return {if (trialBalance != null) 'trial_balance': trialBalance!.toJson()};
  }
}

abstract interface class ReportCacheRepository {
  Future<ReportCacheSnapshot> loadCached();

  Future<void> saveCached(ReportCacheSnapshot snapshot);
}

class MemoryReportCacheRepository implements ReportCacheRepository {
  MemoryReportCacheRepository([ReportCacheSnapshot? seed])
    : _snapshot = seed ?? const ReportCacheSnapshot();

  ReportCacheSnapshot _snapshot;

  @override
  Future<ReportCacheSnapshot> loadCached() async => _snapshot;

  @override
  Future<void> saveCached(ReportCacheSnapshot snapshot) async {
    _snapshot = snapshot;
  }
}

class FileReportCacheRepository implements ReportCacheRepository {
  const FileReportCacheRepository(this.file);

  final File file;

  @override
  Future<ReportCacheSnapshot> loadCached() async {
    if (!await file.exists()) {
      return const ReportCacheSnapshot();
    }
    final contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      return const ReportCacheSnapshot();
    }
    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Expected report cache JSON object');
    }
    return ReportCacheSnapshot.fromJson(decoded);
  }

  @override
  Future<void> saveCached(ReportCacheSnapshot snapshot) async {
    await file.parent.create(recursive: true);
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(jsonEncode(snapshot.toJson()), flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }
}

class SqliteReportCacheRepository implements ReportCacheRepository {
  const SqliteReportCacheRepository(this.database);

  final Database database;

  @override
  Future<ReportCacheSnapshot> loadCached() async {
    final reportRows = await database.query(
      'cached_trial_balance_report',
      limit: 1,
    );
    if (reportRows.isEmpty) {
      return const ReportCacheSnapshot();
    }
    final rowRows = await database.query(
      'cached_trial_balance_rows',
      orderBy: 'row_index ASC, account_code ASC, account_id ASC',
    );
    return ReportCacheSnapshot(
      trialBalance: _trialBalanceFromRows(reportRows.single, rowRows),
    );
  }

  @override
  Future<void> saveCached(ReportCacheSnapshot snapshot) async {
    await database.transaction((transaction) async {
      await transaction.delete('cached_trial_balance_report');
      await transaction.delete('cached_trial_balance_rows');

      final report = snapshot.trialBalance;
      if (report == null) {
        return;
      }
      await transaction.insert(
        'cached_trial_balance_report',
        _trialBalanceToRow(report),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (var index = 0; index < report.rows.length; index += 1) {
        await transaction.insert(
          'cached_trial_balance_rows',
          _reportRowToRow(index, report.rows[index]),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}

Future<void> createReportCacheTables(DatabaseExecutor database) async {
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_trial_balance_report (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  as_of_date TEXT NOT NULL,
  total_debit_minor INTEGER NOT NULL DEFAULT 0,
  total_credit_minor INTEGER NOT NULL DEFAULT 0,
  balanced INTEGER NOT NULL DEFAULT 0
)
''');
  await database.execute('''
CREATE TABLE IF NOT EXISTS cached_trial_balance_rows (
  row_index INTEGER NOT NULL,
  account_id TEXT NOT NULL,
  account_code TEXT NOT NULL DEFAULT '',
  account_name TEXT NOT NULL DEFAULT '',
  account_type TEXT NOT NULL DEFAULT '',
  debit_minor INTEGER NOT NULL DEFAULT 0,
  credit_minor INTEGER NOT NULL DEFAULT 0,
  balance_minor INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (row_index, account_id)
)
''');
}

Map<String, Object?> _trialBalanceToRow(TrialBalanceReport report) {
  return {
    'id': 1,
    'as_of_date': _dateOnly(report.asOfDate),
    'total_debit_minor': report.totalDebitMinor,
    'total_credit_minor': report.totalCreditMinor,
    'balanced': report.balanced ? 1 : 0,
  };
}

Map<String, Object?> _reportRowToRow(int index, ReportRowSummary row) {
  return {
    'row_index': index,
    'account_id': row.accountId,
    'account_code': row.accountCode,
    'account_name': row.accountName,
    'account_type': row.accountType,
    'debit_minor': row.debitMinor,
    'credit_minor': row.creditMinor,
    'balance_minor': row.balanceMinor,
  };
}

TrialBalanceReport _trialBalanceFromRows(
  Map<String, Object?> report,
  List<Map<String, Object?>> rows,
) {
  return TrialBalanceReport(
    asOfDate: DateTime.parse(report['as_of_date']! as String),
    rows: rows.map(_reportRowFromRow).toList(growable: false),
    totalDebitMinor: report['total_debit_minor'] as int? ?? 0,
    totalCreditMinor: report['total_credit_minor'] as int? ?? 0,
    balanced: (report['balanced'] as int? ?? 0) == 1,
  );
}

ReportRowSummary _reportRowFromRow(Map<String, Object?> row) {
  return ReportRowSummary(
    accountId: row['account_id']! as String,
    accountCode: row['account_code'] as String? ?? '',
    accountName: row['account_name'] as String? ?? '',
    accountType: row['account_type'] as String? ?? '',
    debitMinor: row['debit_minor'] as int? ?? 0,
    creditMinor: row['credit_minor'] as int? ?? 0,
    balanceMinor: row['balance_minor'] as int? ?? 0,
  );
}

String _dateOnly(DateTime date) {
  final normalized = date.toUtc();
  final month = normalized.month.toString().padLeft(2, '0');
  final day = normalized.day.toString().padLeft(2, '0');
  return '${normalized.year}-$month-$day';
}
