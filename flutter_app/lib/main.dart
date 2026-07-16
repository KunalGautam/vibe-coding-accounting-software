import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'accounts/account_cache_repository.dart';
import 'api/accounting_api_client.dart';
import 'attachments/attachment_cache_repository.dart';
import 'invoices/invoice_cache_repository.dart';
import 'investments/investment_cache_repository.dart';
import 'parties/party_cache_repository.dart';
import 'reports/report_cache_repository.dart';
import 'settings/sync_settings.dart';
import 'sync/offline_sync_queue.dart';
import 'sync/sync_coordinator.dart';
import 'sync/sync_operation_repository.dart';
import 'tax/tax_catalog_cache_repository.dart';

typedef AccountLoader =
    Future<List<AccountSummary>> Function(SyncSettings settings);
typedef InvoiceLoader =
    Future<List<InvoiceSummary>> Function(SyncSettings settings);
typedef CustomerLoader =
    Future<List<CustomerSummary>> Function(SyncSettings settings);
typedef VendorLoader =
    Future<List<VendorSummary>> Function(SyncSettings settings);
typedef TrialBalanceLoader =
    Future<TrialBalanceReport> Function(SyncSettings settings, DateTime asOf);
typedef ProfitAndLossLoader =
    Future<ProfitAndLossReport> Function(
      SyncSettings settings,
      DateTime from,
      DateTime to,
    );
typedef BalanceSheetLoader =
    Future<BalanceSheetReport> Function(SyncSettings settings, DateTime asOf);
typedef CashFlowLoader =
    Future<CashFlowReport> Function(
      SyncSettings settings,
      DateTime from,
      DateTime to,
    );
typedef ARAgingLoader =
    Future<ARAgingReport> Function(SyncSettings settings, DateTime asOf);
typedef APAgingLoader =
    Future<APAgingReport> Function(SyncSettings settings, DateTime asOf);
typedef TaxRateLoader =
    Future<List<TaxRateSummary>> Function(SyncSettings settings);
typedef TaxGroupLoader =
    Future<List<TaxGroupSummary>> Function(SyncSettings settings);
typedef AttachmentLoader =
    Future<List<AttachmentSummary>> Function(SyncSettings settings);
typedef InvestmentLotLoader =
    Future<List<InvestmentLotSummary>> Function(SyncSettings settings);
typedef RealizedGainsLoader =
    Future<RealizedGainsReport> Function(
      SyncSettings settings,
      DateTime from,
      DateTime to,
    );
typedef InvestmentValuationLoader =
    Future<InvestmentValuationReport> Function(
      SyncSettings settings,
      DateTime asOf,
    );
typedef AttachmentUploader =
    Future<AttachmentSummary> Function(
      SyncSettings settings,
      String fileName,
      List<int> bytes,
    );
typedef AttachmentDownloader =
    Future<AttachmentDownload> Function(
      SyncSettings settings,
      AttachmentSummary attachment,
    );
typedef AttachmentPicker =
    Future<PickedAttachmentFile?> Function(AttachmentPickSource source);
typedef TaxCalculator =
    Future<TaxCalculationResult> Function(
      SyncSettings settings,
      CalculateTaxRequest request,
    );

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final syncRepository = await createDefaultSyncOperationRepository();
  final settingsRepository = await createDefaultSyncSettingsRepository();
  final accountCacheRepository = await createDefaultAccountCacheRepository();
  final invoiceCacheRepository = await createDefaultInvoiceCacheRepository();
  final investmentCacheRepository =
      await createDefaultInvestmentCacheRepository();
  final partyCacheRepository = await createDefaultPartyCacheRepository();
  final reportCacheRepository = await createDefaultReportCacheRepository();
  final attachmentCacheRepository =
      await createDefaultAttachmentCacheRepository();
  final attachmentBinaryCacheRepository =
      await createDefaultAttachmentBinaryCacheRepository();
  final attachmentUploadManifestRepository =
      await createDefaultAttachmentUploadManifestRepository();
  final taxCatalogCacheRepository =
      await createDefaultTaxCatalogCacheRepository();
  runApp(
    AccountingApp(
      syncRepository: syncRepository,
      settingsRepository: settingsRepository,
      accountCacheRepository: accountCacheRepository,
      invoiceCacheRepository: invoiceCacheRepository,
      investmentCacheRepository: investmentCacheRepository,
      partyCacheRepository: partyCacheRepository,
      reportCacheRepository: reportCacheRepository,
      attachmentCacheRepository: attachmentCacheRepository,
      attachmentBinaryCacheRepository: attachmentBinaryCacheRepository,
      attachmentUploadManifestRepository: attachmentUploadManifestRepository,
      taxCatalogCacheRepository: taxCatalogCacheRepository,
    ),
  );
}

class AccountingApp extends StatelessWidget {
  const AccountingApp({
    this.syncRepository,
    this.settingsRepository,
    this.accountCacheRepository,
    this.invoiceCacheRepository,
    this.investmentCacheRepository,
    this.partyCacheRepository,
    this.reportCacheRepository,
    this.attachmentCacheRepository,
    this.attachmentBinaryCacheRepository,
    this.attachmentUploadManifestRepository,
    this.taxCatalogCacheRepository,
    this.accountLoader,
    this.invoiceLoader,
    this.customerLoader,
    this.vendorLoader,
    this.trialBalanceLoader,
    this.profitAndLossLoader,
    this.balanceSheetLoader,
    this.cashFlowLoader,
    this.arAgingLoader,
    this.apAgingLoader,
    this.taxRateLoader,
    this.taxGroupLoader,
    this.attachmentLoader,
    this.investmentLotLoader,
    this.realizedGainsLoader,
    this.investmentValuationLoader,
    this.attachmentUploader,
    this.attachmentDownloader,
    this.attachmentPicker,
    this.taxCalculator,
    super.key,
  });

  final SyncOperationRepository? syncRepository;
  final SyncSettingsRepository? settingsRepository;
  final AccountCacheRepository? accountCacheRepository;
  final InvoiceCacheRepository? invoiceCacheRepository;
  final InvestmentCacheRepository? investmentCacheRepository;
  final PartyCacheRepository? partyCacheRepository;
  final ReportCacheRepository? reportCacheRepository;
  final AttachmentCacheRepository? attachmentCacheRepository;
  final AttachmentBinaryCacheRepository? attachmentBinaryCacheRepository;
  final AttachmentUploadManifestRepository? attachmentUploadManifestRepository;
  final TaxCatalogCacheRepository? taxCatalogCacheRepository;
  final AccountLoader? accountLoader;
  final InvoiceLoader? invoiceLoader;
  final CustomerLoader? customerLoader;
  final VendorLoader? vendorLoader;
  final TrialBalanceLoader? trialBalanceLoader;
  final ProfitAndLossLoader? profitAndLossLoader;
  final BalanceSheetLoader? balanceSheetLoader;
  final CashFlowLoader? cashFlowLoader;
  final ARAgingLoader? arAgingLoader;
  final APAgingLoader? apAgingLoader;
  final TaxRateLoader? taxRateLoader;
  final TaxGroupLoader? taxGroupLoader;
  final AttachmentLoader? attachmentLoader;
  final InvestmentLotLoader? investmentLotLoader;
  final RealizedGainsLoader? realizedGainsLoader;
  final InvestmentValuationLoader? investmentValuationLoader;
  final AttachmentUploader? attachmentUploader;
  final AttachmentDownloader? attachmentDownloader;
  final AttachmentPicker? attachmentPicker;
  final TaxCalculator? taxCalculator;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ledger Works',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E6B4E),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4EFE4),
        useMaterial3: true,
      ),
      home: MobileDeskShell(
        syncRepository: syncRepository,
        settingsRepository: settingsRepository,
        accountCacheRepository: accountCacheRepository,
        invoiceCacheRepository: invoiceCacheRepository,
        investmentCacheRepository: investmentCacheRepository,
        partyCacheRepository: partyCacheRepository,
        reportCacheRepository: reportCacheRepository,
        attachmentCacheRepository: attachmentCacheRepository,
        attachmentBinaryCacheRepository: attachmentBinaryCacheRepository,
        attachmentUploadManifestRepository: attachmentUploadManifestRepository,
        taxCatalogCacheRepository: taxCatalogCacheRepository,
        accountLoader: accountLoader,
        invoiceLoader: invoiceLoader,
        customerLoader: customerLoader,
        vendorLoader: vendorLoader,
        trialBalanceLoader: trialBalanceLoader,
        profitAndLossLoader: profitAndLossLoader,
        balanceSheetLoader: balanceSheetLoader,
        cashFlowLoader: cashFlowLoader,
        arAgingLoader: arAgingLoader,
        apAgingLoader: apAgingLoader,
        taxRateLoader: taxRateLoader,
        taxGroupLoader: taxGroupLoader,
        attachmentLoader: attachmentLoader,
        investmentLotLoader: investmentLotLoader,
        realizedGainsLoader: realizedGainsLoader,
        investmentValuationLoader: investmentValuationLoader,
        attachmentUploader: attachmentUploader,
        attachmentDownloader: attachmentDownloader,
        attachmentPicker: attachmentPicker,
        taxCalculator: taxCalculator,
      ),
    );
  }
}

class MobileDeskShell extends StatefulWidget {
  const MobileDeskShell({
    this.syncRepository,
    this.settingsRepository,
    this.accountCacheRepository,
    this.invoiceCacheRepository,
    this.investmentCacheRepository,
    this.partyCacheRepository,
    this.reportCacheRepository,
    this.attachmentCacheRepository,
    this.attachmentBinaryCacheRepository,
    this.attachmentUploadManifestRepository,
    this.taxCatalogCacheRepository,
    this.accountLoader,
    this.invoiceLoader,
    this.customerLoader,
    this.vendorLoader,
    this.trialBalanceLoader,
    this.profitAndLossLoader,
    this.balanceSheetLoader,
    this.cashFlowLoader,
    this.arAgingLoader,
    this.apAgingLoader,
    this.taxRateLoader,
    this.taxGroupLoader,
    this.attachmentLoader,
    this.investmentLotLoader,
    this.realizedGainsLoader,
    this.investmentValuationLoader,
    this.attachmentUploader,
    this.attachmentDownloader,
    this.attachmentPicker,
    this.taxCalculator,
    super.key,
  });

  final SyncOperationRepository? syncRepository;
  final SyncSettingsRepository? settingsRepository;
  final AccountCacheRepository? accountCacheRepository;
  final InvoiceCacheRepository? invoiceCacheRepository;
  final InvestmentCacheRepository? investmentCacheRepository;
  final PartyCacheRepository? partyCacheRepository;
  final ReportCacheRepository? reportCacheRepository;
  final AttachmentCacheRepository? attachmentCacheRepository;
  final AttachmentBinaryCacheRepository? attachmentBinaryCacheRepository;
  final AttachmentUploadManifestRepository? attachmentUploadManifestRepository;
  final TaxCatalogCacheRepository? taxCatalogCacheRepository;
  final AccountLoader? accountLoader;
  final InvoiceLoader? invoiceLoader;
  final CustomerLoader? customerLoader;
  final VendorLoader? vendorLoader;
  final TrialBalanceLoader? trialBalanceLoader;
  final ProfitAndLossLoader? profitAndLossLoader;
  final BalanceSheetLoader? balanceSheetLoader;
  final CashFlowLoader? cashFlowLoader;
  final ARAgingLoader? arAgingLoader;
  final APAgingLoader? apAgingLoader;
  final TaxRateLoader? taxRateLoader;
  final TaxGroupLoader? taxGroupLoader;
  final AttachmentLoader? attachmentLoader;
  final InvestmentLotLoader? investmentLotLoader;
  final RealizedGainsLoader? realizedGainsLoader;
  final InvestmentValuationLoader? investmentValuationLoader;
  final AttachmentUploader? attachmentUploader;
  final AttachmentDownloader? attachmentDownloader;
  final AttachmentPicker? attachmentPicker;
  final TaxCalculator? taxCalculator;

  @override
  State<MobileDeskShell> createState() => _MobileDeskShellState();
}

class _MobileDeskShellState extends State<MobileDeskShell> {
  late final SyncOperationRepository repository;
  late final SyncSettingsRepository settingsRepository;
  late final AccountCacheRepository accountCacheRepository;
  late final InvoiceCacheRepository invoiceCacheRepository;
  late final InvestmentCacheRepository investmentCacheRepository;
  late final PartyCacheRepository partyCacheRepository;
  late final ReportCacheRepository reportCacheRepository;
  late final AttachmentCacheRepository attachmentCacheRepository;
  late final AttachmentBinaryCacheRepository attachmentBinaryCacheRepository;
  late final AttachmentUploadManifestRepository
  attachmentUploadManifestRepository;
  late final TaxCatalogCacheRepository taxCatalogCacheRepository;
  SyncSettings settings = const SyncSettings();
  final syncQueue = OfflineSyncQueue([
    SyncOperation(
      id: 'expense-seed-1',
      module: 'expenses',
      action: 'create_draft',
      createdAt: DateTime.utc(2026, 7, 11, 9),
    ),
    SyncOperation(
      id: 'invoice-seed-1',
      module: 'invoices',
      action: 'cache_view',
      createdAt: DateTime.utc(2026, 7, 11, 10),
    ),
    SyncOperation(
      id: 'expense-seed-2',
      module: 'expenses',
      action: 'create_draft',
      createdAt: DateTime.utc(2026, 7, 11, 11),
    ),
  ]);
  int selectedIndex = 0;
  bool offlineMode = true;
  SyncResult? lastSyncResult;
  String? syncNotice;
  SyncOperation? editingDraft;
  List<AccountSummary> discoveredAccounts = const [];
  List<InvoiceSummary> cachedInvoices = const [];
  List<CustomerSummary> cachedCustomers = const [];
  List<VendorSummary> cachedVendors = const [];
  TrialBalanceReport? cachedTrialBalanceReport;
  ProfitAndLossReport? cachedProfitAndLossReport;
  BalanceSheetReport? cachedBalanceSheetReport;
  CashFlowReport? cachedCashFlowReport;
  ARAgingReport? cachedARAgingReport;
  APAgingReport? cachedAPAgingReport;
  List<InvestmentLotSummary> cachedInvestmentLots = const [];
  RealizedGainsReport? cachedRealizedGainsReport;
  List<InvestmentPriceSummary> cachedInvestmentPrices = const [];
  InvestmentValuationReport? cachedInvestmentValuationReport;
  List<TaxRateSummary> discoveredTaxRates = const [];
  List<TaxGroupSummary> discoveredTaxGroups = const [];
  List<AttachmentSummary> discoveredAttachments = const [];
  Set<String> cachedAttachmentBinaryIds = const {};
  bool isLoadingAccounts = false;
  bool isLoadingParties = false;
  bool isLoadingReports = false;
  bool isLoadingInvoices = false;
  bool isLoadingInvestments = false;
  bool isLoadingTaxCatalog = false;
  bool isLoadingAttachments = false;

  @override
  void initState() {
    super.initState();
    repository = widget.syncRepository ?? MemorySyncOperationRepository();
    settingsRepository =
        widget.settingsRepository ?? MemorySyncSettingsRepository();
    accountCacheRepository =
        widget.accountCacheRepository ?? MemoryAccountCacheRepository();
    invoiceCacheRepository =
        widget.invoiceCacheRepository ?? MemoryInvoiceCacheRepository();
    investmentCacheRepository =
        widget.investmentCacheRepository ?? MemoryInvestmentCacheRepository();
    partyCacheRepository =
        widget.partyCacheRepository ?? MemoryPartyCacheRepository();
    reportCacheRepository =
        widget.reportCacheRepository ?? MemoryReportCacheRepository();
    attachmentCacheRepository =
        widget.attachmentCacheRepository ?? MemoryAttachmentCacheRepository();
    attachmentBinaryCacheRepository =
        widget.attachmentBinaryCacheRepository ??
        MemoryAttachmentBinaryCacheRepository();
    attachmentUploadManifestRepository =
        widget.attachmentUploadManifestRepository ??
        MemoryAttachmentUploadManifestRepository();
    taxCatalogCacheRepository =
        widget.taxCatalogCacheRepository ?? MemoryTaxCatalogCacheRepository();
    hydratePendingOperations();
    hydrateSettings();
    hydrateAccounts();
    hydrateParties();
    hydrateReports();
    hydrateInvoices();
    hydrateInvestments();
    hydrateAttachments();
    hydrateTaxCatalog();
  }

  Future<void> hydratePendingOperations() async {
    final pending = await repository.loadPending();
    if (!mounted || pending.isEmpty) {
      return;
    }
    setState(() {
      syncQueue.replaceAll(pending);
    });
  }

  Future<void> hydrateSettings() async {
    final loaded = await settingsRepository.load();
    if (!mounted) {
      return;
    }
    setState(() {
      settings = loaded;
    });
  }

  Future<void> hydrateAccounts() async {
    final accounts = await accountCacheRepository.loadCached();
    if (!mounted) {
      return;
    }
    setState(() {
      discoveredAccounts = accounts;
    });
  }

  Future<void> hydrateParties() async {
    final snapshot = await partyCacheRepository.loadCached();
    if (!mounted) {
      return;
    }
    setState(() {
      cachedCustomers = snapshot.customers;
      cachedVendors = snapshot.vendors;
    });
  }

  Future<void> hydrateReports() async {
    final snapshot = await reportCacheRepository.loadCached();
    if (!mounted) {
      return;
    }
    setState(() {
      cachedTrialBalanceReport = snapshot.trialBalance;
      cachedProfitAndLossReport = snapshot.profitAndLoss;
      cachedBalanceSheetReport = snapshot.balanceSheet;
      cachedCashFlowReport = snapshot.cashFlow;
      cachedARAgingReport = snapshot.arAging;
      cachedAPAgingReport = snapshot.apAging;
    });
  }

  Future<void> hydrateInvoices() async {
    final invoices = await invoiceCacheRepository.loadCached();
    if (!mounted) {
      return;
    }
    setState(() {
      cachedInvoices = invoices;
    });
  }

  Future<void> hydrateInvestments() async {
    final snapshot = await investmentCacheRepository.loadCached();
    if (!mounted) {
      return;
    }
    setState(() {
      cachedInvestmentLots = snapshot.lots;
      cachedRealizedGainsReport = snapshot.realizedGainsReport;
      cachedInvestmentPrices = snapshot.prices;
      cachedInvestmentValuationReport = snapshot.valuationReport;
    });
  }

  Future<void> hydrateAttachments() async {
    final attachments = await attachmentCacheRepository.loadCached();
    final binaryIds = await cachedBinaryIdsFor(attachments);
    if (!mounted) {
      return;
    }
    setState(() {
      discoveredAttachments = attachments;
      cachedAttachmentBinaryIds = binaryIds;
    });
  }

  Future<Set<String>> cachedBinaryIdsFor(
    List<AttachmentSummary> attachments,
  ) async {
    final cachedIds = <String>{};
    for (final attachment in attachments) {
      final cached = await attachmentBinaryCacheRepository.loadDownloaded(
        attachment.id,
      );
      if (cached != null) {
        cachedIds.add(attachment.id);
      }
    }
    return cachedIds;
  }

  Future<void> hydrateTaxCatalog() async {
    final snapshot = await taxCatalogCacheRepository.loadCached();
    if (!mounted) {
      return;
    }
    setState(() {
      discoveredTaxRates = snapshot.rates;
      discoveredTaxGroups = snapshot.groups;
    });
  }

  Future<void> recordDraftExpense([
    DraftExpenseInput input = const DraftExpenseInput(),
  ]) async {
    final operation = syncQueue.enqueueExpenseDraft(
      merchantName: input.merchantName,
      amountMinor: input.amountMinor,
      expenseAccountId: settings.defaultExpenseAccountId.trim().isEmpty
          ? null
          : settings.defaultExpenseAccountId.trim(),
      paymentAccountId: settings.defaultPaymentAccountId.trim().isEmpty
          ? null
          : settings.defaultPaymentAccountId.trim(),
      receiptAttachmentId: input.receiptAttachmentId.trim().isEmpty
          ? null
          : input.receiptAttachmentId.trim(),
      taxRateId: input.taxRateId.trim().isEmpty
          ? settings.defaultTaxRateId.trim().isEmpty
                ? null
                : settings.defaultTaxRateId.trim()
          : input.taxRateId.trim(),
      taxGroupId: input.taxGroupId.trim().isEmpty
          ? settings.defaultTaxGroupId.trim().isEmpty
                ? null
                : settings.defaultTaxGroupId.trim()
          : input.taxGroupId.trim(),
      taxInclusive: input.taxInclusive,
      reimbursable: input.reimbursable,
    );
    await repository.savePending(syncQueue.pending);
    setState(() {
      syncNotice = 'Draft expense queued for sync: ${operation.id}';
      selectedIndex = 1;
    });
  }

  Future<void> deletePendingDraft(String operationId) async {
    syncQueue.remove(operationId);
    await repository.savePending(syncQueue.pending);
    setState(() {
      if (editingDraft?.id == operationId) {
        editingDraft = null;
      }
      syncNotice = 'Draft removed from the offline queue.';
    });
  }

  Future<void> updatePendingDraft(
    String operationId,
    DraftExpenseInput input,
  ) async {
    syncQueue.updateExpenseDraft(
      id: operationId,
      merchantName: input.merchantName,
      amountMinor: input.amountMinor,
      receiptAttachmentId: input.receiptAttachmentId.trim().isEmpty
          ? null
          : input.receiptAttachmentId.trim(),
      taxRateId: input.taxRateId.trim().isEmpty ? null : input.taxRateId.trim(),
      taxGroupId: input.taxGroupId.trim().isEmpty
          ? null
          : input.taxGroupId.trim(),
      taxInclusive: input.taxInclusive,
      reimbursable: input.reimbursable,
    );
    await repository.savePending(syncQueue.pending);
    setState(() {
      editingDraft = null;
      syncNotice = 'Draft expense updated.';
    });
  }

  void editPendingDraft(SyncOperation operation) {
    setState(() {
      editingDraft = operation;
    });
  }

  void cancelDraftEdit() {
    setState(() {
      editingDraft = null;
    });
  }

  Future<void> syncPending() async {
    if (!settings.canFetchAccounts) {
      final result = SyncResult(
        synced: 0,
        skipped: syncQueue.pendingCount,
        failed: const [],
      );
      setState(() {
        lastSyncResult = result;
        syncNotice =
            'Add API credentials and organization ID before syncing queued offline changes.';
      });
      return;
    }

    try {
      final result = await SyncCoordinator(
        queue: syncQueue,
        apiClient: AccountingApiClient(config: settings.toApiConfig()),
        repository: repository,
      ).syncPending();
      setState(() {
        lastSyncResult = result;
        syncNotice = result.hasFailures
            ? 'Some drafts could not sync. They remain queued for retry.'
            : 'Sync complete.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Sync failed: $error';
      });
    }
  }

  Future<void> saveSettings(SyncSettings next) async {
    await settingsRepository.save(next);
    setState(() {
      settings = next;
      syncNotice = 'Sync settings saved locally.';
    });
  }

  Future<void> selectExpenseAccount(AccountSummary account) async {
    await saveSettings(settings.copyWith(defaultExpenseAccountId: account.id));
    setState(() {
      syncNotice = 'Default expense account set to ${account.code}.';
    });
  }

  Future<void> selectPaymentAccount(AccountSummary account) async {
    await saveSettings(settings.copyWith(defaultPaymentAccountId: account.id));
    setState(() {
      syncNotice = 'Default payment account set to ${account.code}.';
    });
  }

  Future<void> selectTaxRate(TaxRateSummary taxRate) async {
    await saveSettings(
      settings.copyWith(defaultTaxRateId: taxRate.id, defaultTaxGroupId: ''),
    );
    setState(() {
      syncNotice = 'Default tax rate set to ${taxRate.name}.';
    });
  }

  Future<void> selectTaxGroup(TaxGroupSummary taxGroup) async {
    await saveSettings(
      settings.copyWith(defaultTaxRateId: '', defaultTaxGroupId: taxGroup.id),
    );
    setState(() {
      syncNotice = 'Default tax group set to ${taxGroup.name}.';
    });
  }

  Future<void> fetchAccounts() async {
    if (!settings.canFetchAccounts) {
      setState(() {
        syncNotice =
            'Add API credentials and organization ID before fetching accounts.';
      });
      return;
    }

    setState(() {
      isLoadingAccounts = true;
      syncNotice = null;
    });

    try {
      final loader =
          widget.accountLoader ??
          (settings) => AccountingApiClient(
            config: settings.toApiConfig(),
          ).listAccounts();
      final accounts = await loader(settings);
      await accountCacheRepository.saveCached(accounts);
      setState(() {
        discoveredAccounts = accounts;
        syncNotice = 'Fetched ${accounts.length} accounts.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Account fetch failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingAccounts = false;
        });
      }
    }
  }

  Future<void> fetchParties() async {
    if (!settings.canFetchAccounts) {
      setState(() {
        syncNotice =
            'Add API credentials and organization ID before fetching customers and vendors.';
      });
      return;
    }

    setState(() {
      isLoadingParties = true;
      syncNotice = null;
    });

    try {
      final customerLoader =
          widget.customerLoader ??
          (settings) => AccountingApiClient(
            config: settings.toApiConfig(),
          ).listCustomers();
      final vendorLoader =
          widget.vendorLoader ??
          (settings) =>
              AccountingApiClient(config: settings.toApiConfig()).listVendors();
      final customers = await customerLoader(settings);
      final vendors = await vendorLoader(settings);
      await partyCacheRepository.saveCached(
        PartySnapshot(customers: customers, vendors: vendors),
      );
      setState(() {
        cachedCustomers = customers;
        cachedVendors = vendors;
        syncNotice =
            'Fetched ${customers.length} customers and ${vendors.length} vendors.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Customer/vendor fetch failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingParties = false;
        });
      }
    }
  }

  Future<void> fetchTrialBalance(DateTime asOf) async {
    if (!settings.canFetchAccounts) {
      setState(() {
        syncNotice =
            'Add API credentials and organization ID before fetching reports.';
      });
      return;
    }

    setState(() {
      isLoadingReports = true;
      syncNotice = null;
    });

    try {
      final loader =
          widget.trialBalanceLoader ??
          (settings, asOf) => AccountingApiClient(
            config: settings.toApiConfig(),
          ).getTrialBalance(asOf: asOf);
      final report = await loader(settings, asOf);
      final snapshot = await reportCacheRepository.loadCached();
      await reportCacheRepository.saveCached(
        snapshot.copyWith(trialBalance: report),
      );
      setState(() {
        cachedTrialBalanceReport = report;
        syncNotice =
            'Fetched trial balance as of ${formatDateOnly(report.asOfDate)}.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Trial balance fetch failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingReports = false;
        });
      }
    }
  }

  Future<void> fetchProfitAndLoss(DateTime from, DateTime to) async {
    if (!settings.canFetchAccounts) {
      setState(() {
        syncNotice =
            'Add API credentials and organization ID before fetching reports.';
      });
      return;
    }

    setState(() {
      isLoadingReports = true;
      syncNotice = null;
    });

    try {
      final loader =
          widget.profitAndLossLoader ??
          (settings, from, to) => AccountingApiClient(
            config: settings.toApiConfig(),
          ).getProfitAndLoss(from: from, to: to);
      final report = await loader(settings, from, to);
      final snapshot = await reportCacheRepository.loadCached();
      await reportCacheRepository.saveCached(
        snapshot.copyWith(profitAndLoss: report),
      );
      setState(() {
        cachedProfitAndLossReport = report;
        syncNotice =
            'Fetched P&L from ${formatDateOnly(report.fromDate)} to ${formatDateOnly(report.toDate)}.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'P&L fetch failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingReports = false;
        });
      }
    }
  }

  Future<void> fetchBalanceSheet(DateTime asOf) async {
    if (!settings.canFetchAccounts) {
      setState(() {
        syncNotice =
            'Add API credentials and organization ID before fetching reports.';
      });
      return;
    }

    setState(() {
      isLoadingReports = true;
      syncNotice = null;
    });

    try {
      final loader =
          widget.balanceSheetLoader ??
          (settings, asOf) => AccountingApiClient(
            config: settings.toApiConfig(),
          ).getBalanceSheet(asOf: asOf);
      final report = await loader(settings, asOf);
      final snapshot = await reportCacheRepository.loadCached();
      await reportCacheRepository.saveCached(
        snapshot.copyWith(balanceSheet: report),
      );
      setState(() {
        cachedBalanceSheetReport = report;
        syncNotice =
            'Fetched balance sheet as of ${formatDateOnly(report.asOfDate)}.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Balance sheet fetch failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingReports = false;
        });
      }
    }
  }

  Future<void> fetchCashFlow(DateTime from, DateTime to) async {
    if (!settings.canFetchAccounts) {
      setState(() {
        syncNotice =
            'Add API credentials and organization ID before fetching reports.';
      });
      return;
    }

    setState(() {
      isLoadingReports = true;
      syncNotice = null;
    });

    try {
      final loader =
          widget.cashFlowLoader ??
          (settings, from, to) => AccountingApiClient(
            config: settings.toApiConfig(),
          ).getCashFlow(from: from, to: to);
      final report = await loader(settings, from, to);
      final snapshot = await reportCacheRepository.loadCached();
      await reportCacheRepository.saveCached(
        snapshot.copyWith(cashFlow: report),
      );
      setState(() {
        cachedCashFlowReport = report;
        syncNotice =
            'Fetched cash flow from ${formatDateOnly(report.fromDate)} to ${formatDateOnly(report.toDate)}.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Cash flow fetch failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingReports = false;
        });
      }
    }
  }

  Future<void> fetchARAging(DateTime asOf) async {
    if (!settings.canFetchAccounts) {
      setState(() {
        syncNotice =
            'Add API credentials and organization ID before fetching reports.';
      });
      return;
    }

    setState(() {
      isLoadingReports = true;
      syncNotice = null;
    });

    try {
      final loader =
          widget.arAgingLoader ??
          (settings, asOf) => AccountingApiClient(
            config: settings.toApiConfig(),
          ).getARAging(asOf: asOf);
      final report = await loader(settings, asOf);
      final snapshot = await reportCacheRepository.loadCached();
      await reportCacheRepository.saveCached(
        snapshot.copyWith(arAging: report),
      );
      setState(() {
        cachedARAgingReport = report;
        syncNotice = 'Fetched AR aging as of ${formatDateOnly(asOf)}.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'AR aging fetch failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingReports = false;
        });
      }
    }
  }

  Future<void> fetchAPAging(DateTime asOf) async {
    if (!settings.canFetchAccounts) {
      setState(() {
        syncNotice =
            'Add API credentials and organization ID before fetching reports.';
      });
      return;
    }

    setState(() {
      isLoadingReports = true;
      syncNotice = null;
    });

    try {
      final loader =
          widget.apAgingLoader ??
          (settings, asOf) => AccountingApiClient(
            config: settings.toApiConfig(),
          ).getAPAging(asOf: asOf);
      final report = await loader(settings, asOf);
      final snapshot = await reportCacheRepository.loadCached();
      await reportCacheRepository.saveCached(
        snapshot.copyWith(apAging: report),
      );
      setState(() {
        cachedAPAgingReport = report;
        syncNotice = 'Fetched AP aging as of ${formatDateOnly(asOf)}.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'AP aging fetch failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingReports = false;
        });
      }
    }
  }

  Future<void> fetchTaxCatalog() async {
    if (!settings.canFetchAccounts) {
      setState(() {
        syncNotice =
            'Add API credentials and organization ID before fetching tax configuration.';
      });
      return;
    }

    setState(() {
      isLoadingTaxCatalog = true;
      syncNotice = null;
    });

    try {
      final rateLoader =
          widget.taxRateLoader ??
          (settings) => AccountingApiClient(
            config: settings.toApiConfig(),
          ).listTaxRates();
      final groupLoader =
          widget.taxGroupLoader ??
          (settings) => AccountingApiClient(
            config: settings.toApiConfig(),
          ).listTaxGroups();
      final rates = await rateLoader(settings);
      final groups = await groupLoader(settings);
      await taxCatalogCacheRepository.saveCached(
        TaxCatalogSnapshot(rates: rates, groups: groups),
      );
      setState(() {
        discoveredTaxRates = rates;
        discoveredTaxGroups = groups;
        syncNotice =
            'Fetched ${rates.length} tax rates and ${groups.length} tax groups.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Tax fetch failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingTaxCatalog = false;
        });
      }
    }
  }

  Future<TaxCalculationResult> calculateDraftTax(
    CalculateTaxRequest request,
  ) async {
    if (!settings.canFetchAccounts) {
      throw StateError(
        'Add API credentials and organization ID before previewing tax.',
      );
    }

    final calculator =
        widget.taxCalculator ??
        (settings, request) => AccountingApiClient(
          config: settings.toApiConfig(),
        ).calculateTax(request);
    return calculator(settings, request);
  }

  Future<void> fetchInvoices() async {
    if (!settings.canFetchAccounts) {
      setState(() {
        syncNotice =
            'Add API credentials and organization ID before fetching invoices.';
      });
      return;
    }

    setState(() {
      isLoadingInvoices = true;
      syncNotice = null;
    });

    try {
      final loader =
          widget.invoiceLoader ??
          (settings) => AccountingApiClient(
            config: settings.toApiConfig(),
          ).listInvoices();
      final invoices = await loader(settings);
      await invoiceCacheRepository.saveCached(invoices);
      setState(() {
        cachedInvoices = invoices;
        syncNotice = 'Cached ${invoices.length} invoices for offline viewing.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Invoice fetch failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingInvoices = false;
        });
      }
    }
  }

  Future<void> fetchInvestmentLots() async {
    if (!settings.canFetchAccounts) {
      setState(() {
        syncNotice =
            'Add API credentials and organization ID before fetching investment lots.';
      });
      return;
    }

    setState(() {
      isLoadingInvestments = true;
      syncNotice = null;
    });

    try {
      final loader =
          widget.investmentLotLoader ??
          (settings) => AccountingApiClient(
            config: settings.toApiConfig(),
          ).listInvestmentLots();
      final lots = await loader(settings);
      await investmentCacheRepository.saveCached(
        InvestmentCacheSnapshot(
          lots: lots,
          realizedGainsReport: cachedRealizedGainsReport,
          prices: cachedInvestmentPrices,
          valuationReport: cachedInvestmentValuationReport,
        ),
      );
      setState(() {
        cachedInvestmentLots = lots;
        syncNotice = 'Cached ${lots.length} investment lots.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Investment lot fetch failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingInvestments = false;
        });
      }
    }
  }

  Future<void> fetchRealizedGains(DateTime from, DateTime to) async {
    if (!settings.canFetchAccounts) {
      setState(() {
        syncNotice =
            'Add API credentials and organization ID before fetching realized gains.';
      });
      return;
    }

    setState(() {
      isLoadingInvestments = true;
      syncNotice = null;
    });

    try {
      final loader =
          widget.realizedGainsLoader ??
          (settings, from, to) => AccountingApiClient(
            config: settings.toApiConfig(),
          ).getRealizedGains(from: from, to: to);
      final report = await loader(settings, from, to);
      await investmentCacheRepository.saveCached(
        InvestmentCacheSnapshot(
          lots: cachedInvestmentLots,
          realizedGainsReport: report,
          prices: cachedInvestmentPrices,
          valuationReport: cachedInvestmentValuationReport,
        ),
      );
      setState(() {
        cachedRealizedGainsReport = report;
        syncNotice =
            'Cached realized gains report with ${report.rows.length} rows.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Realized gains fetch failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingInvestments = false;
        });
      }
    }
  }

  Future<void> fetchInvestmentValuation(DateTime asOf) async {
    if (!settings.canFetchAccounts) {
      setState(() {
        syncNotice =
            'Add API credentials and organization ID before fetching valuation.';
      });
      return;
    }

    setState(() {
      isLoadingInvestments = true;
      syncNotice = null;
    });

    try {
      final loader =
          widget.investmentValuationLoader ??
          (settings, asOf) => AccountingApiClient(
            config: settings.toApiConfig(),
          ).getInvestmentValuation(asOf: asOf);
      final report = await loader(settings, asOf);
      await investmentCacheRepository.saveCached(
        InvestmentCacheSnapshot(
          lots: cachedInvestmentLots,
          realizedGainsReport: cachedRealizedGainsReport,
          prices: cachedInvestmentPrices,
          valuationReport: report,
        ),
      );
      setState(() {
        cachedInvestmentValuationReport = report;
        syncNotice =
            'Cached investment valuation with ${report.rows.length} rows.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Investment valuation fetch failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingInvestments = false;
        });
      }
    }
  }

  Future<void> fetchAttachments() async {
    if (!settings.canFetchAccounts) {
      setState(() {
        syncNotice =
            'Add API credentials and organization ID before fetching attachments.';
      });
      return;
    }

    setState(() {
      isLoadingAttachments = true;
      syncNotice = null;
    });

    try {
      final loader =
          widget.attachmentLoader ??
          (settings) => AccountingApiClient(
            config: settings.toApiConfig(),
          ).listAttachments();
      final attachments = await loader(settings);
      await attachmentCacheRepository.saveCached(attachments);
      final binaryIds = await cachedBinaryIdsFor(attachments);
      setState(() {
        discoveredAttachments = attachments;
        cachedAttachmentBinaryIds = binaryIds;
        syncNotice = 'Fetched ${attachments.length} attachments.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Attachment fetch failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingAttachments = false;
        });
      }
    }
  }

  Future<void> uploadSampleAttachment() async {
    await uploadAttachmentBytes(
      'sample-receipt.txt',
      'Sample receipt captured offline-first'.codeUnits,
    );
  }

  Future<void> uploadLocalAttachment(String path) async {
    final trimmedPath = path.trim();
    if (trimmedPath.isEmpty) {
      setState(() {
        syncNotice = 'Add a local receipt file path before uploading.';
      });
      return;
    }

    try {
      final localFile = await readLocalAttachmentFile(trimmedPath);
      if (!settings.canFetchAccounts) {
        final operation = syncQueue.enqueueAttachmentUpload(
          fileName: localFile.fileName,
          localFilePath: trimmedPath,
        );
        await attachmentUploadManifestRepository.upsert(
          AttachmentUploadManifestEntry(
            operationId: operation.id,
            fileName: localFile.fileName,
            localFilePath: trimmedPath,
            sizeBytes: localFile.bytes.length,
            createdAt: operation.createdAt,
            contentType: 'application/octet-stream',
          ),
        );
        await repository.savePending(syncQueue.pending);
        setState(() {
          syncNotice =
              'Attachment upload queued for sync: ${operation.payload['file_name']}';
          selectedIndex = 5;
        });
        return;
      }
      await uploadAttachmentBytes(localFile.fileName, localFile.bytes);
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Local receipt read failed: $error';
      });
    }
  }

  Future<void> pickAndUploadAttachment(AttachmentPickSource source) async {
    try {
      final picker = widget.attachmentPicker ?? pickAttachmentFile;
      final picked = await picker(source);
      if (picked == null) {
        setState(() {
          syncNotice = 'Attachment selection cancelled.';
        });
        return;
      }
      await uploadPickedAttachment(picked);
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Attachment selection failed: $error';
      });
    }
  }

  Future<void> uploadPickedAttachment(PickedAttachmentFile picked) async {
    if (!settings.canFetchAccounts) {
      final localFilePath = picked.localFilePath;
      if (localFilePath == null || localFilePath.trim().isEmpty) {
        setState(() {
          syncNotice =
              'Selected attachment cannot be queued offline because no local file path was provided.';
        });
        return;
      }
      final operation = syncQueue.enqueueAttachmentUpload(
        fileName: picked.fileName,
        localFilePath: localFilePath,
      );
      await attachmentUploadManifestRepository.upsert(
        AttachmentUploadManifestEntry(
          operationId: operation.id,
          fileName: picked.fileName,
          localFilePath: localFilePath,
          sizeBytes: picked.bytes.length,
          createdAt: operation.createdAt,
          contentType: picked.contentType ?? 'application/octet-stream',
        ),
      );
      await repository.savePending(syncQueue.pending);
      setState(() {
        syncNotice = 'Attachment upload queued for sync: ${picked.fileName}';
        selectedIndex = 5;
      });
      return;
    }

    await uploadAttachmentBytes(picked.fileName, picked.bytes);
  }

  Future<void> uploadAttachmentBytes(String fileName, List<int> bytes) async {
    if (!settings.canFetchAccounts) {
      setState(() {
        syncNotice =
            'Add API credentials and organization ID before uploading attachments.';
      });
      return;
    }

    setState(() {
      isLoadingAttachments = true;
      syncNotice = null;
    });

    try {
      final uploader =
          widget.attachmentUploader ??
          (settings, fileName, bytes) => AccountingApiClient(
            config: settings.toApiConfig(),
          ).uploadAttachmentBytes(fileName: fileName, bytes: bytes);
      final attachment = await uploader(settings, fileName, bytes);
      final updated = [attachment, ...discoveredAttachments];
      await attachmentCacheRepository.saveCached(updated);
      await attachmentBinaryCacheRepository.saveDownloaded(
        attachment.id,
        AttachmentDownload(
          bytes: Uint8List.fromList(bytes),
          contentType: attachment.contentType.isEmpty
              ? 'text/plain'
              : attachment.contentType,
          fileName: attachment.fileName,
        ),
      );
      setState(() {
        discoveredAttachments = updated;
        cachedAttachmentBinaryIds = {
          ...cachedAttachmentBinaryIds,
          attachment.id,
        };
        syncNotice = 'Uploaded attachment ${attachment.fileName}.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Attachment upload failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingAttachments = false;
        });
      }
    }
  }

  Future<void> downloadAttachment(AttachmentSummary attachment) async {
    if (!settings.canFetchAccounts) {
      setState(() {
        syncNotice =
            'Add API credentials and organization ID before downloading attachments.';
      });
      return;
    }

    setState(() {
      isLoadingAttachments = true;
      syncNotice = null;
    });

    try {
      final downloader =
          widget.attachmentDownloader ??
          (settings, attachment) => AccountingApiClient(
            config: settings.toApiConfig(),
          ).downloadAttachment(attachment.id);
      final download = await downloader(settings, attachment);
      await attachmentBinaryCacheRepository.saveDownloaded(
        attachment.id,
        download,
      );
      setState(() {
        cachedAttachmentBinaryIds = {
          ...cachedAttachmentBinaryIds,
          attachment.id,
        };
        syncNotice =
            'Downloaded ${download.fileName ?? attachment.fileName} (${download.bytes.length} bytes).';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Attachment download failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingAttachments = false;
        });
      }
    }
  }

  Future<void> inspectCachedAttachment(AttachmentSummary attachment) async {
    final cached = await attachmentBinaryCacheRepository.loadDownloaded(
      attachment.id,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      if (cached == null) {
        syncNotice = 'Attachment ${attachment.fileName} is not cached offline.';
        return;
      }
      syncNotice =
          'Cached ${cached.fileName ?? attachment.fileName}: ${cached.contentType}, ${cached.bytes.length} bytes.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      OverviewPage(
        offlineMode: offlineMode,
        queuedChanges: syncQueue.pendingCount,
        onCaptureExpense: () => recordDraftExpense(),
      ),
      ExpensesPage(
        queuedChanges: syncQueue.pendingCount,
        pendingOperations: syncQueue.pending,
        attachments: discoveredAttachments,
        editingDraft: editingDraft,
        onQueueDraftExpense: recordDraftExpense,
        onUpdateDraft: updatePendingDraft,
        onDeleteDraft: deletePendingDraft,
        onEditDraft: editPendingDraft,
        onCancelEdit: cancelDraftEdit,
        onCalculateTax: calculateDraftTax,
      ),
      InvoicesPage(
        invoices: cachedInvoices,
        isLoading: isLoadingInvoices,
        notice: syncNotice,
        onFetchInvoices: fetchInvoices,
      ),
      InvestmentsPage(
        lots: cachedInvestmentLots,
        realizedGainsReport: cachedRealizedGainsReport,
        valuationReport: cachedInvestmentValuationReport,
        isLoading: isLoadingInvestments,
        notice: syncNotice,
        onFetchLots: fetchInvestmentLots,
        onFetchRealizedGains: fetchRealizedGains,
        onFetchValuation: fetchInvestmentValuation,
      ),
      ReportsPage(
        trialBalance: cachedTrialBalanceReport,
        profitAndLoss: cachedProfitAndLossReport,
        balanceSheet: cachedBalanceSheetReport,
        cashFlow: cachedCashFlowReport,
        arAging: cachedARAgingReport,
        apAging: cachedAPAgingReport,
        isLoading: isLoadingReports,
        notice: syncNotice,
        onFetchTrialBalance: fetchTrialBalance,
        onFetchProfitAndLoss: fetchProfitAndLoss,
        onFetchBalanceSheet: fetchBalanceSheet,
        onFetchCashFlow: fetchCashFlow,
        onFetchARAging: fetchARAging,
        onFetchAPAging: fetchAPAging,
      ),
      SyncPage(
        settings: settings,
        offlineMode: offlineMode,
        queuedChanges: syncQueue.pendingCount,
        lastSyncResult: lastSyncResult,
        notice: syncNotice,
        onOfflineModeChanged: (value) => setState(() => offlineMode = value),
        onSyncPressed: syncPending,
        onSettingsChanged: saveSettings,
        onFetchAccounts: fetchAccounts,
        discoveredAccounts: discoveredAccounts,
        isLoadingAccounts: isLoadingAccounts,
        onSelectExpenseAccount: selectExpenseAccount,
        onSelectPaymentAccount: selectPaymentAccount,
        customers: cachedCustomers,
        vendors: cachedVendors,
        isLoadingParties: isLoadingParties,
        onFetchParties: fetchParties,
        onFetchTaxCatalog: fetchTaxCatalog,
        discoveredTaxRates: discoveredTaxRates,
        discoveredTaxGroups: discoveredTaxGroups,
        isLoadingTaxCatalog: isLoadingTaxCatalog,
        onSelectTaxRate: selectTaxRate,
        onSelectTaxGroup: selectTaxGroup,
        attachments: discoveredAttachments,
        isLoadingAttachments: isLoadingAttachments,
        onFetchAttachments: fetchAttachments,
        onUploadSampleAttachment: uploadSampleAttachment,
        onUploadLocalAttachment: uploadLocalAttachment,
        onPickAttachment: pickAndUploadAttachment,
        onDownloadAttachment: downloadAttachment,
        onInspectCachedAttachment: inspectCachedAttachment,
        cachedBinaryAttachmentIds: cachedAttachmentBinaryIds,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final navigation = AppNavigation(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) =>
                  setState(() => selectedIndex = index),
              extended: isWide,
            );

            if (isWide) {
              return Row(
                children: [
                  navigation,
                  Expanded(child: pages[selectedIndex]),
                ],
              );
            }

            return pages[selectedIndex];
          },
        ),
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            return const SizedBox.shrink();
          }

          return NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => selectedIndex = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                label: 'Expenses',
              ),
              NavigationDestination(
                icon: Icon(Icons.description_outlined),
                label: 'Invoices',
              ),
              NavigationDestination(
                icon: Icon(Icons.show_chart_outlined),
                label: 'Invest',
              ),
              NavigationDestination(
                icon: Icon(Icons.assessment_outlined),
                label: 'Reports',
              ),
              NavigationDestination(
                icon: Icon(Icons.sync_outlined),
                label: 'Sync',
              ),
            ],
          );
        },
      ),
    );
  }
}

String fileNameFromPath(String path) {
  final parts = path.trim().split(RegExp(r'[\\/]'));
  return parts.isEmpty || parts.last.isEmpty ? 'receipt-upload' : parts.last;
}

class LocalAttachmentFile {
  const LocalAttachmentFile({required this.fileName, required this.bytes});

  final String fileName;
  final List<int> bytes;
}

enum AttachmentPickSource { file, camera, gallery }

class PickedAttachmentFile {
  const PickedAttachmentFile({
    required this.fileName,
    required this.bytes,
    this.localFilePath,
    this.contentType,
  });

  final String fileName;
  final List<int> bytes;
  final String? localFilePath;
  final String? contentType;
}

Future<LocalAttachmentFile> readLocalAttachmentFile(String path) async {
  final trimmedPath = path.trim();
  return LocalAttachmentFile(
    fileName: fileNameFromPath(trimmedPath),
    bytes: await File(trimmedPath).readAsBytes(),
  );
}

Future<PickedAttachmentFile?> pickAttachmentFile(
  AttachmentPickSource source,
) async {
  if (source == AttachmentPickSource.file) {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final file = result.files.single;
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();
    return PickedAttachmentFile(
      fileName: file.name,
      bytes: bytes,
      localFilePath: file.path,
      contentType: contentTypeForFileName(file.name),
    );
  }

  final picker = ImagePicker();
  final image = await picker.pickImage(
    source: source == AttachmentPickSource.camera
        ? ImageSource.camera
        : ImageSource.gallery,
    imageQuality: 85,
  );
  if (image == null) {
    return null;
  }
  return PickedAttachmentFile(
    fileName: fileNameFromPath(image.path),
    bytes: await image.readAsBytes(),
    localFilePath: image.path,
    contentType: image.mimeType ?? contentTypeForFileName(image.name),
  );
}

String contentTypeForFileName(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  if (lower.endsWith('.pdf')) {
    return 'application/pdf';
  }
  if (lower.endsWith('.txt')) {
    return 'text/plain';
  }
  return 'application/octet-stream';
}

class AppNavigation extends StatelessWidget {
  const AppNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.extended,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      extended: extended,
      minExtendedWidth: 220,
      onDestinationSelected: onDestinationSelected,
      backgroundColor: const Color(0xFFE8DDC8),
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: CircleAvatar(
          backgroundColor: const Color(0xFF1E6B4E),
          child: Text(
            'LW',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: Colors.white),
          ),
        ),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: Text('Expenses'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.description_outlined),
          label: Text('Invoices'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.show_chart_outlined),
          label: Text('Investments'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.assessment_outlined),
          label: Text('Reports'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.sync_outlined),
          label: Text('Sync'),
        ),
      ],
    );
  }
}

class OverviewPage extends StatelessWidget {
  const OverviewPage({
    required this.offlineMode,
    required this.queuedChanges,
    required this.onCaptureExpense,
    super.key,
  });

  final bool offlineMode;
  final int queuedChanges;
  final VoidCallback onCaptureExpense;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      eyebrow: 'India-first SMB accounting',
      title: 'Mobile and desktop cockpit',
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            StatusCard(
              label: 'Offline mode',
              value: offlineMode ? 'Ready' : 'API only',
              icon: Icons.offline_bolt_outlined,
            ),
            StatusCard(
              label: 'Queued changes',
              value: queuedChanges.toString(),
              icon: Icons.pending_actions_outlined,
            ),
            const StatusCard(
              label: 'Default currency',
              value: 'INR',
              icon: Icons.currency_rupee_outlined,
            ),
          ],
        ),
        FeaturePanel(
          title: 'First field workflows',
          description:
              'Capture expenses on mobile, review invoices offline, and sync drafts back to the Go API when the connection returns.',
          actionLabel: 'Capture draft expense',
          onPressed: onCaptureExpense,
        ),
        const PlatformPanel(),
      ],
    );
  }
}

class DraftExpenseInput {
  const DraftExpenseInput({
    this.merchantName = 'Field expense',
    this.amountMinor = 0,
    this.receiptAttachmentId = '',
    this.taxRateId = '',
    this.taxGroupId = '',
    this.taxInclusive = false,
    this.reimbursable = false,
  });

  final String merchantName;
  final int amountMinor;
  final String receiptAttachmentId;
  final String taxRateId;
  final String taxGroupId;
  final bool taxInclusive;
  final bool reimbursable;
}

class ExpensesPage extends StatelessWidget {
  const ExpensesPage({
    required this.queuedChanges,
    required this.pendingOperations,
    required this.attachments,
    required this.editingDraft,
    required this.onQueueDraftExpense,
    required this.onUpdateDraft,
    required this.onDeleteDraft,
    required this.onEditDraft,
    required this.onCancelEdit,
    required this.onCalculateTax,
    super.key,
  });

  final int queuedChanges;
  final List<SyncOperation> pendingOperations;
  final List<AttachmentSummary> attachments;
  final SyncOperation? editingDraft;
  final Future<void> Function(DraftExpenseInput input) onQueueDraftExpense;
  final Future<void> Function(String operationId, DraftExpenseInput input)
  onUpdateDraft;
  final Future<void> Function(String operationId) onDeleteDraft;
  final ValueChanged<SyncOperation> onEditDraft;
  final VoidCallback onCancelEdit;
  final Future<TaxCalculationResult> Function(CalculateTaxRequest request)
  onCalculateTax;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      eyebrow: 'Expense capture',
      title: 'Receipts and reimbursables',
      children: [
        DraftExpenseForm(
          attachments: attachments,
          editingDraft: editingDraft,
          onSubmit: onQueueDraftExpense,
          onUpdate: onUpdateDraft,
          onCancelEdit: onCancelEdit,
          onCalculateTax: onCalculateTax,
        ),
        PendingDraftList(
          operations: pendingOperations,
          onDeleteDraft: onDeleteDraft,
          onEditDraft: onEditDraft,
        ),
        InfoList(
          items: [
            'Draft expenses queued locally: $queuedChanges',
            'Target API: POST /expenses',
            'Receipt IDs can be selected from cached attachment metadata',
          ],
        ),
      ],
    );
  }
}

class PendingDraftList extends StatelessWidget {
  const PendingDraftList({
    required this.operations,
    required this.onDeleteDraft,
    required this.onEditDraft,
    super.key,
  });

  final List<SyncOperation> operations;
  final Future<void> Function(String operationId) onDeleteDraft;
  final ValueChanged<SyncOperation> onEditDraft;

  @override
  Widget build(BuildContext context) {
    final expenseDrafts = operations
        .where(
          (operation) =>
              operation.module == 'expenses' &&
              operation.action == 'create_draft',
        )
        .toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pending drafts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (expenseDrafts.isEmpty)
              const Text('No expense drafts are waiting to sync.')
            else
              for (final operation in expenseDrafts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: PendingDraftTile(
                    operation: operation,
                    onEdit: () => onEditDraft(operation),
                    onDelete: () => onDeleteDraft(operation.id),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class PendingDraftTile extends StatelessWidget {
  const PendingDraftTile({
    required this.operation,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final SyncOperation operation;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final payload = operation.payload;
    final merchantName = payload['merchant_name'] as String? ?? 'Expense draft';
    final amountMinor = payload['amount_minor'] as int? ?? 0;
    final reimbursable = payload['reimbursable'] as bool? ?? false;
    final receiptAttachmentId = payload['receipt_attachment_id'] as String?;
    final taxRateId = payload['tax_rate_id'] as String?;
    final taxGroupId = payload['tax_group_id'] as String?;
    final taxInclusive = payload['tax_inclusive'] as bool? ?? false;
    final hasExpenseAccount =
        (payload['expense_account_id'] as String?)?.trim().isNotEmpty ?? false;
    final hasPaymentAccount =
        (payload['payment_account_id'] as String?)?.trim().isNotEmpty ?? false;
    final accountStatus = hasExpenseAccount && hasPaymentAccount
        ? 'Ready to sync'
        : 'Needs posting accounts';
    final syncStatus = operation.hasConflict
        ? 'Needs review'
        : operation.lastError == null
        ? 'Waiting'
        : 'Retry queued';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(merchantName, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '${formatMinorAsInr(amountMinor)} · $accountStatus · $syncStatus',
            ),
            Text(reimbursable ? 'Reimbursable' : 'Not reimbursable'),
            if (operation.retryCount > 0)
              Text('Attempts: ${operation.retryCount}'),
            if (operation.lastAttemptAt != null)
              Text(
                'Last attempted: ${formatDateTime(operation.lastAttemptAt!)}',
              ),
            if (operation.conflictReason?.trim().isNotEmpty ?? false)
              Text('Conflict: ${operation.conflictReason}'),
            if (!operation.hasConflict &&
                (operation.lastError?.trim().isNotEmpty ?? false))
              Text('Last error: ${operation.lastError}'),
            if (receiptAttachmentId?.trim().isNotEmpty ?? false)
              Text('Receipt attachment: $receiptAttachmentId'),
            if (taxRateId?.trim().isNotEmpty ?? false)
              Text('Tax rate: $taxRateId'),
            if (taxGroupId?.trim().isNotEmpty ?? false)
              Text('Tax group: $taxGroupId'),
            Text(taxInclusive ? 'Tax inclusive' : 'Tax exclusive'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit draft'),
                ),
                TextButton.icon(
                  onPressed: () => onDelete(),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete draft'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String formatMinorAsInr(int amountMinor) {
  final sign = amountMinor < 0 ? '-' : '';
  final absolute = amountMinor.abs();
  final rupees = absolute ~/ 100;
  final paise = (absolute % 100).toString().padLeft(2, '0');
  return '${sign}INR $rupees.$paise';
}

String formatMinorAsInput(int amountMinor) {
  final sign = amountMinor < 0 ? '-' : '';
  final absolute = amountMinor.abs();
  final rupees = absolute ~/ 100;
  final paise = (absolute % 100).toString().padLeft(2, '0');
  return '$sign$rupees.$paise';
}

String formatDateOnly(DateTime date) {
  final normalized = date.toLocal();
  final month = normalized.month.toString().padLeft(2, '0');
  final day = normalized.day.toString().padLeft(2, '0');
  return '${normalized.year}-$month-$day';
}

String formatDateTime(DateTime date) {
  final normalized = date.toLocal();
  final month = normalized.month.toString().padLeft(2, '0');
  final day = normalized.day.toString().padLeft(2, '0');
  final hour = normalized.hour.toString().padLeft(2, '0');
  final minute = normalized.minute.toString().padLeft(2, '0');
  return '${normalized.year}-$month-$day $hour:$minute';
}

String formatQuantityMillis(int quantityMillis) {
  final whole = quantityMillis ~/ 1000;
  final fraction = (quantityMillis.abs() % 1000).toString().padLeft(3, '0');
  return fraction == '000' ? '$whole' : '$whole.$fraction';
}

class DraftExpenseForm extends StatefulWidget {
  const DraftExpenseForm({
    required this.attachments,
    required this.editingDraft,
    required this.onSubmit,
    required this.onUpdate,
    required this.onCancelEdit,
    required this.onCalculateTax,
    super.key,
  });

  final List<AttachmentSummary> attachments;
  final SyncOperation? editingDraft;
  final Future<void> Function(DraftExpenseInput input) onSubmit;
  final Future<void> Function(String operationId, DraftExpenseInput input)
  onUpdate;
  final VoidCallback onCancelEdit;
  final Future<TaxCalculationResult> Function(CalculateTaxRequest request)
  onCalculateTax;

  @override
  State<DraftExpenseForm> createState() => _DraftExpenseFormState();
}

class _DraftExpenseFormState extends State<DraftExpenseForm> {
  final merchantController = TextEditingController(text: 'Field expense');
  final amountController = TextEditingController(text: '0.00');
  final receiptAttachmentController = TextEditingController();
  final taxRateController = TextEditingController();
  final taxGroupController = TextEditingController();
  bool taxInclusive = false;
  bool reimbursable = false;
  TaxCalculationResult? taxPreview;
  String? taxPreviewMessage;
  bool isPreviewingTax = false;

  @override
  void didUpdateWidget(covariant DraftExpenseForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editingDraft?.id != widget.editingDraft?.id) {
      applyDraft(widget.editingDraft);
    }
  }

  @override
  void dispose() {
    merchantController.dispose();
    amountController.dispose();
    receiptAttachmentController.dispose();
    taxRateController.dispose();
    taxGroupController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final amountMinor = parseRupeesToPaise(amountController.text);
    final taxRateId = taxRateController.text.trim();
    final taxGroupId = taxGroupController.text.trim();
    if (taxRateId.isNotEmpty && taxGroupId.isNotEmpty) {
      setState(() {
        taxPreview = null;
        taxPreviewMessage =
            'Use either a tax rate ID or a tax group ID, not both.';
      });
      return;
    }
    final input = DraftExpenseInput(
      merchantName: merchantController.text.trim().isEmpty
          ? 'Field expense'
          : merchantController.text.trim(),
      amountMinor: amountMinor,
      receiptAttachmentId: receiptAttachmentController.text.trim(),
      taxRateId: taxRateId,
      taxGroupId: taxGroupId,
      taxInclusive: taxInclusive,
      reimbursable: reimbursable,
    );

    final editingDraft = widget.editingDraft;
    if (editingDraft == null) {
      await widget.onSubmit(input);
    } else {
      await widget.onUpdate(editingDraft.id, input);
    }
  }

  int parseRupeesToPaise(String value) {
    final normalized = value.trim().replaceAll(',', '');
    if (normalized.isEmpty) {
      return 0;
    }
    final rupees = double.tryParse(normalized) ?? 0;
    return (rupees * 100).round();
  }

  void applyDraft(SyncOperation? operation) {
    if (operation == null) {
      merchantController.text = 'Field expense';
      amountController.text = '0.00';
      receiptAttachmentController.clear();
      taxRateController.clear();
      taxGroupController.clear();
      setState(() {
        taxInclusive = false;
        reimbursable = false;
        taxPreview = null;
        taxPreviewMessage = null;
      });
      return;
    }

    final payload = operation.payload;
    merchantController.text =
        payload['merchant_name'] as String? ?? 'Field expense';
    amountController.text = formatMinorAsInput(
      payload['amount_minor'] as int? ?? 0,
    );
    receiptAttachmentController.text =
        payload['receipt_attachment_id'] as String? ?? '';
    final taxGroupId = payload['tax_group_id'] as String? ?? '';
    taxGroupController.text = taxGroupId;
    taxRateController.text = taxGroupId.trim().isEmpty
        ? payload['tax_rate_id'] as String? ?? ''
        : '';
    setState(() {
      taxInclusive = payload['tax_inclusive'] as bool? ?? false;
      reimbursable = payload['reimbursable'] as bool? ?? false;
      taxPreview = null;
      taxPreviewMessage = null;
    });
  }

  void onTaxRateChanged(String value) {
    if (value.trim().isEmpty) {
      return;
    }
    if (taxGroupController.text.isNotEmpty) {
      taxGroupController.clear();
    }
    setState(() {
      taxPreview = null;
      taxPreviewMessage = 'Using tax rate; tax group cleared.';
    });
  }

  void onTaxGroupChanged(String value) {
    if (value.trim().isEmpty) {
      return;
    }
    if (taxRateController.text.isNotEmpty) {
      taxRateController.clear();
    }
    setState(() {
      taxPreview = null;
      taxPreviewMessage = 'Using tax group; tax rate cleared.';
    });
  }

  Future<void> previewTax() async {
    final amountMinor = parseRupeesToPaise(amountController.text);
    final taxRateId = taxRateController.text.trim();
    final taxGroupId = taxGroupController.text.trim();
    if (taxRateId.isEmpty && taxGroupId.isEmpty) {
      setState(() {
        taxPreview = null;
        taxPreviewMessage =
            'Add a tax rate ID or tax group ID before previewing tax.';
      });
      return;
    }
    if (taxRateId.isNotEmpty && taxGroupId.isNotEmpty) {
      setState(() {
        taxPreview = null;
        taxPreviewMessage =
            'Use either a tax rate ID or a tax group ID, not both.';
      });
      return;
    }

    setState(() {
      isPreviewingTax = true;
      taxPreviewMessage = null;
    });

    try {
      final result = await widget.onCalculateTax(
        CalculateTaxRequest(
          baseAmountMinor: amountMinor,
          taxInclusive: taxInclusive,
          taxRateId: taxRateId.isEmpty ? null : taxRateId,
          taxGroupId: taxGroupId.isEmpty ? null : taxGroupId,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        taxPreview = result;
        taxPreviewMessage = 'Tax preview ready.';
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        taxPreview = null;
        taxPreviewMessage = 'Tax preview failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isPreviewingTax = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.editingDraft == null
                  ? 'Draft expense'
                  : 'Edit draft expense',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Queue a local expense draft now; it will post to the API when sync credentials and accounts are ready.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: merchantController,
              decoration: const InputDecoration(labelText: 'Merchant or memo'),
            ),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Amount in INR'),
            ),
            TextField(
              controller: receiptAttachmentController,
              decoration: const InputDecoration(
                labelText: 'Receipt attachment ID',
                helperText:
                    'Optional; pick a cached upload below or paste an ID.',
              ),
            ),
            if (widget.attachments.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Cached receipt attachments',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              for (final attachment in widget.attachments.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${attachment.fileName} · ${attachment.id}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${attachment.contentType} · ${attachment.sizeBytes} bytes',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              receiptAttachmentController.text = attachment.id;
                            },
                            child: const Text('Use receipt'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
            TextField(
              controller: taxRateController,
              onChanged: onTaxRateChanged,
              decoration: const InputDecoration(
                labelText: 'Tax rate ID',
                helperText:
                    'Optional; use for single configured VAT/GST rates.',
              ),
            ),
            TextField(
              controller: taxGroupController,
              onChanged: onTaxGroupChanged,
              decoration: const InputDecoration(
                labelText: 'Tax group ID',
                helperText:
                    'Optional; use for configured split taxes like CGST + SGST.',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tax inclusive'),
              value: taxInclusive,
              onChanged: (value) => setState(() => taxInclusive = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reimbursable'),
              value: reimbursable,
              onChanged: (value) => setState(() => reimbursable = value),
            ),
            if (taxPreview != null) TaxPreviewPanel(result: taxPreview!),
            if (taxPreviewMessage != null) Text(taxPreviewMessage!),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: isPreviewingTax ? null : () => previewTax(),
                  icon: isPreviewingTax
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.calculate_outlined),
                  label: Text(
                    isPreviewingTax ? 'Previewing tax...' : 'Preview tax',
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => submit(),
                  icon: Icon(
                    widget.editingDraft == null
                        ? Icons.add_task_outlined
                        : Icons.save_outlined,
                  ),
                  label: Text(
                    widget.editingDraft == null
                        ? 'Queue draft expense'
                        : 'Save draft changes',
                  ),
                ),
                if (widget.editingDraft != null)
                  OutlinedButton.icon(
                    onPressed: widget.onCancelEdit,
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel edit'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TaxPreviewPanel extends StatelessWidget {
  const TaxPreviewPanel({required this.result, super.key});

  final TaxCalculationResult result;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tax preview', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('Base: ${formatMinorAsInr(result.baseAmountMinor)}'),
            Text('Tax: ${formatMinorAsInr(result.taxAmountMinor)}'),
            Text('Total: ${formatMinorAsInr(result.totalAmountMinor)}'),
            if (result.components.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final component in result.components)
                Text(
                  '${component.name}: ${formatMinorAsInr(component.taxAmountMinor)}',
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class InvoicesPage extends StatelessWidget {
  const InvoicesPage({
    required this.invoices,
    required this.isLoading,
    required this.notice,
    required this.onFetchInvoices,
    super.key,
  });

  final List<InvoiceSummary> invoices;
  final bool isLoading;
  final String? notice;
  final Future<void> Function() onFetchInvoices;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      eyebrow: 'Invoice viewer',
      title: 'AR snapshots anywhere',
      children: [
        FeaturePanel(
          title: 'Offline invoice packet',
          description:
              'The mobile-first path is invoice viewing before full invoice editing: customer, totals, GST split, payment status, and PDF link metadata.',
          actionLabel: isLoading ? 'Refreshing invoices...' : 'Refresh cache',
          onPressed: isLoading ? null : () => onFetchInvoices(),
        ),
        InvoiceCachePanel(invoices: invoices),
        if (notice != null) Text(notice!),
        const InfoList(
          items: [
            'Target API: GET /invoices',
            'Cached locally for read-only offline review',
            'PDF generation and download/viewing are still pending',
          ],
        ),
      ],
    );
  }
}

class InvoiceCachePanel extends StatelessWidget {
  const InvoiceCachePanel({required this.invoices, super.key});

  final List<InvoiceSummary> invoices;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cached invoices',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (invoices.isEmpty)
              const Text('No invoices are cached for offline viewing yet.')
            else
              for (final invoice in invoices)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest.withAlpha(90),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice.invoiceNumber,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${formatMinorAsInr(invoice.totalMinor)} · ${invoice.status}',
                          ),
                          Text(
                            'Subtotal: ${formatMinorAsInr(invoice.subtotalMinor)}',
                          ),
                          Text(
                            'Tax: ${formatMinorAsInr(invoice.taxTotalMinor)}',
                          ),
                          if (invoice.pdfAttachmentId != null)
                            SelectableText(
                              'PDF attachment: ${invoice.pdfAttachmentId}',
                            ),
                          if (invoice.lines.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Line items',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 4),
                            for (final line in invoice.lines)
                              _InvoiceLineSummaryRow(line: line),
                          ],
                          SelectableText(invoice.id),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceLineSummaryRow extends StatelessWidget {
  const _InvoiceLineSummaryRow({required this.line});

  final InvoiceLineSummary line;

  @override
  Widget build(BuildContext context) {
    final taxTarget = line.taxGroupId ?? line.taxRateId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withAlpha(180),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.description),
              Text(
                'Line subtotal: ${formatMinorAsInr(line.lineSubtotalMinor)}',
              ),
              Text('Line tax: ${formatMinorAsInr(line.taxAmountMinor)}'),
              Text('Line total: ${formatMinorAsInr(line.lineTotalMinor)}'),
              if (taxTarget != null) SelectableText('Tax config: $taxTarget'),
            ],
          ),
        ),
      ),
    );
  }
}

class InvestmentsPage extends StatelessWidget {
  const InvestmentsPage({
    required this.lots,
    required this.realizedGainsReport,
    required this.valuationReport,
    required this.isLoading,
    required this.notice,
    required this.onFetchLots,
    required this.onFetchRealizedGains,
    required this.onFetchValuation,
    super.key,
  });

  final List<InvestmentLotSummary> lots;
  final RealizedGainsReport? realizedGainsReport;
  final InvestmentValuationReport? valuationReport;
  final bool isLoading;
  final String? notice;
  final Future<void> Function() onFetchLots;
  final Future<void> Function(DateTime from, DateTime to) onFetchRealizedGains;
  final Future<void> Function(DateTime asOf) onFetchValuation;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final fiscalStart = DateTime(now.year, 4);
    final report = realizedGainsReport;
    final valuation = valuationReport;

    return AppPage(
      eyebrow: 'Investments',
      title: 'Lots and realized gains',
      children: [
        FeaturePanel(
          title: 'Offline investment packet',
          description:
              'Review cached investment lots and fetch a realized gains report for tax-season checks while keeping the mobile workflow read-focused.',
          actionLabel: isLoading ? 'Refreshing investments...' : 'Refresh lots',
          onPressed: isLoading ? null : () => onFetchLots(),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cached lots',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (lots.isEmpty)
                  const Text('No investment lots are cached yet.')
                else
                  for (final lot in lots)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest.withAlpha(90),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lot.symbol,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (lot.securityName.trim().isNotEmpty)
                                Text(lot.securityName),
                              Text(
                                'Acquired ${formatDateOnly(lot.acquisitionDate)} · ${lot.costMethod}',
                              ),
                              Text(
                                'Quantity ${formatQuantityMillis(lot.quantityMillis)} · Remaining ${formatQuantityMillis(lot.remainingQuantityMillis)}',
                              ),
                              Text(
                                'Cost basis ${formatMinorAsInr(lot.costBasisMinor)} · ${lot.currency}',
                              ),
                              SelectableText('Lot ID: ${lot.id}'),
                            ],
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Valuation',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('Fetches market valuation as of ${formatDateOnly(now)}.'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: isLoading ? null : () => onFetchValuation(now),
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: Text(
                    isLoading ? 'Loading valuation...' : 'Fetch valuation',
                  ),
                ),
                if (valuation != null) ...[
                  const SizedBox(height: 16),
                  Text('As of ${formatDateOnly(valuation.asOfDate)}'),
                  Text(
                    'Market value: ${formatMinorAsInr(valuation.totalMarketValueMinor)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Unrealized gain/loss: ${formatMinorAsInr(valuation.totalUnrealizedGainLossMinor)}',
                  ),
                  Text(
                    'Cost basis: ${formatMinorAsInr(valuation.totalCostBasisMinor)}',
                  ),
                  const SizedBox(height: 8),
                  for (final row in valuation.rows)
                    Text(
                      '${row.symbol} · ${formatQuantityMillis(row.remainingQuantityMillis)} units · ${formatMinorAsInr(row.marketValueMinor)} value · ${formatMinorAsInr(row.unrealizedGainLossMinor)} unrealized',
                    ),
                ],
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Realized gains',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Fetches ${formatDateOnly(fiscalStart)} to ${formatDateOnly(now)}.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => onFetchRealizedGains(fiscalStart, now),
                  icon: const Icon(Icons.show_chart_outlined),
                  label: Text(
                    isLoading ? 'Loading report...' : 'Fetch realized gains',
                  ),
                ),
                if (report != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${formatDateOnly(report.fromDate)} to ${formatDateOnly(report.toDate)}',
                  ),
                  Text(
                    'Gain/loss: ${formatMinorAsInr(report.totalGainLossMinor)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Proceeds ${formatMinorAsInr(report.totalProceedsMinor)} less cost ${formatMinorAsInr(report.totalCostBasisMinor)}',
                  ),
                  const SizedBox(height: 8),
                  for (final row in report.rows)
                    Text(
                      '${formatDateOnly(row.saleDate)} · ${formatQuantityMillis(row.quantityMillis)} units · ${formatMinorAsInr(row.realizedGainLossMinor)}',
                    ),
                ],
              ],
            ),
          ),
        ),
        if (notice != null) Text(notice!),
        const InfoList(
          items: [
            'Target APIs: GET /investments/lots, GET /reports/realized-gains, and GET /reports/investment-valuation',
            'Cached locally for read-only offline investment review',
            'Create/sell lot and price maintenance workflows are currently available in the web app/API',
          ],
        ),
      ],
    );
  }
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({
    required this.trialBalance,
    required this.profitAndLoss,
    required this.balanceSheet,
    required this.cashFlow,
    required this.arAging,
    required this.apAging,
    required this.isLoading,
    required this.onFetchTrialBalance,
    required this.onFetchProfitAndLoss,
    required this.onFetchBalanceSheet,
    required this.onFetchCashFlow,
    required this.onFetchARAging,
    required this.onFetchAPAging,
    this.notice,
    super.key,
  });

  final TrialBalanceReport? trialBalance;
  final ProfitAndLossReport? profitAndLoss;
  final BalanceSheetReport? balanceSheet;
  final CashFlowReport? cashFlow;
  final ARAgingReport? arAging;
  final APAgingReport? apAging;
  final bool isLoading;
  final String? notice;
  final Future<void> Function(DateTime asOf) onFetchTrialBalance;
  final Future<void> Function(DateTime from, DateTime to) onFetchProfitAndLoss;
  final Future<void> Function(DateTime asOf) onFetchBalanceSheet;
  final Future<void> Function(DateTime from, DateTime to) onFetchCashFlow;
  final Future<void> Function(DateTime asOf) onFetchARAging;
  final Future<void> Function(DateTime asOf) onFetchAPAging;

  @override
  Widget build(BuildContext context) {
    final asOf = DateTime.now().toUtc();
    final fiscalStart = asOf.month >= 4
        ? DateTime.utc(asOf.year, 4)
        : DateTime.utc(asOf.year - 1, 4);
    return AppPage(
      eyebrow: 'Reports',
      title: 'Financial snapshots',
      children: [
        const Text(
          'Refresh core statements from the API and keep the latest report available offline.',
        ),
        _ReportCard(
          title: 'Trial balance',
          description:
              'Fetches account balances as of ${formatDateOnly(asOf)}.',
          buttonLabel: isLoading ? 'Loading reports...' : 'Fetch trial balance',
          icon: Icons.assessment_outlined,
          isLoading: isLoading,
          onPressed: () => onFetchTrialBalance(asOf),
          children: [
            if (trialBalance == null)
              const Text('No cached trial balance yet.')
            else ...[
              Text('As of ${formatDateOnly(trialBalance!.asOfDate)}'),
              Text(
                trialBalance!.balanced ? 'Balanced' : 'Out of balance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: trialBalance!.balanced
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
              ),
              Text(
                'Debits ${formatMinorAsInr(trialBalance!.totalDebitMinor)} · Credits ${formatMinorAsInr(trialBalance!.totalCreditMinor)}',
              ),
              const SizedBox(height: 8),
              _ReportRows(rows: trialBalance!.rows),
            ],
          ],
        ),
        _ReportCard(
          title: 'Profit and loss',
          description:
              'Uses the Indian fiscal year window ${formatDateOnly(fiscalStart)} to ${formatDateOnly(asOf)}.',
          buttonLabel: isLoading ? 'Loading reports...' : 'Fetch P&L',
          icon: Icons.trending_up,
          isLoading: isLoading,
          onPressed: () => onFetchProfitAndLoss(fiscalStart, asOf),
          children: [
            if (profitAndLoss == null)
              const Text('No cached P&L yet.')
            else ...[
              Text(
                '${formatDateOnly(profitAndLoss!.fromDate)} to ${formatDateOnly(profitAndLoss!.toDate)}',
              ),
              Text(
                'Income ${formatMinorAsInr(profitAndLoss!.totalIncomeMinor)} · Expenses ${formatMinorAsInr(profitAndLoss!.totalExpenseMinor)}',
              ),
              Text(
                'Net income ${formatMinorAsInr(profitAndLoss!.netIncomeMinor)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text('Income'),
              _ReportRows(rows: profitAndLoss!.incomeRows),
              const SizedBox(height: 8),
              const Text('Expenses'),
              _ReportRows(rows: profitAndLoss!.expenseRows),
            ],
          ],
        ),
        _ReportCard(
          title: 'Balance sheet',
          description:
              'Fetches assets, liabilities, and equity as of ${formatDateOnly(asOf)}.',
          buttonLabel: isLoading ? 'Loading reports...' : 'Fetch balance sheet',
          icon: Icons.account_balance,
          isLoading: isLoading,
          onPressed: () => onFetchBalanceSheet(asOf),
          children: [
            if (balanceSheet == null)
              const Text('No cached balance sheet yet.')
            else ...[
              Text('As of ${formatDateOnly(balanceSheet!.asOfDate)}'),
              Text(
                balanceSheet!.balanced ? 'Balanced' : 'Out of balance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: balanceSheet!.balanced
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
              ),
              Text(
                'Assets ${formatMinorAsInr(balanceSheet!.totalAssetsMinor)} · Liabilities ${formatMinorAsInr(balanceSheet!.totalLiabilitiesMinor)} · Equity ${formatMinorAsInr(balanceSheet!.totalEquityMinor)}',
              ),
              const SizedBox(height: 8),
              const Text('Assets'),
              _ReportRows(rows: balanceSheet!.assetRows),
              const SizedBox(height: 8),
              const Text('Liabilities'),
              _ReportRows(rows: balanceSheet!.liabilityRows),
              const SizedBox(height: 8),
              const Text('Equity'),
              _ReportRows(rows: balanceSheet!.equityRows),
            ],
          ],
        ),
        _ReportCard(
          title: 'Cash flow',
          description:
              'Uses the Indian fiscal year window ${formatDateOnly(fiscalStart)} to ${formatDateOnly(asOf)}.',
          buttonLabel: isLoading ? 'Loading reports...' : 'Fetch cash flow',
          icon: Icons.waterfall_chart,
          isLoading: isLoading,
          onPressed: () => onFetchCashFlow(fiscalStart, asOf),
          children: [
            if (cashFlow == null)
              const Text('No cached cash flow yet.')
            else ...[
              Text(
                '${formatDateOnly(cashFlow!.fromDate)} to ${formatDateOnly(cashFlow!.toDate)}',
              ),
              Text(
                'Inflows ${formatMinorAsInr(cashFlow!.totalInflowsMinor)} · Outflows ${formatMinorAsInr(cashFlow!.totalOutflowsMinor)}',
              ),
              Text(
                'Net cash flow ${formatMinorAsInr(cashFlow!.netCashFlowMinor)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                'Opening ${formatMinorAsInr(cashFlow!.openingCashMinor)} · Closing ${formatMinorAsInr(cashFlow!.closingCashMinor)}',
              ),
              if (cashFlow!.generatedFromSubtypes.isNotEmpty)
                Text(
                  'Cash accounts: ${cashFlow!.generatedFromSubtypes.join(', ')}',
                ),
              const SizedBox(height: 8),
              _CashFlowRows(rows: cashFlow!.rows),
            ],
          ],
        ),
        _ReportCard(
          title: 'AR aging',
          description:
              'Fetches customer receivables aging as of ${formatDateOnly(asOf)}.',
          buttonLabel: isLoading ? 'Loading reports...' : 'Fetch AR aging',
          icon: Icons.request_quote_outlined,
          isLoading: isLoading,
          onPressed: () => onFetchARAging(asOf),
          children: [
            if (arAging == null)
              const Text('No cached AR aging yet.')
            else ...[
              Text('As of ${formatDateOnly(arAging!.asOfDate)}'),
              _AgingTotalsText(totals: arAging!.totals),
              const SizedBox(height: 8),
              _ARAgingRows(rows: arAging!.rows),
            ],
          ],
        ),
        _ReportCard(
          title: 'AP aging',
          description:
              'Fetches vendor payables aging as of ${formatDateOnly(asOf)}.',
          buttonLabel: isLoading ? 'Loading reports...' : 'Fetch AP aging',
          icon: Icons.receipt_long_outlined,
          isLoading: isLoading,
          onPressed: () => onFetchAPAging(asOf),
          children: [
            if (apAging == null)
              const Text('No cached AP aging yet.')
            else ...[
              Text('As of ${formatDateOnly(apAging!.asOfDate)}'),
              _AgingTotalsText(totals: apAging!.totals),
              const SizedBox(height: 8),
              _APAgingRows(rows: apAging!.rows),
            ],
          ],
        ),
        if (notice != null) Text(notice!),
        const InfoList(
          items: [
            'Target APIs: trial balance, P&L, balance sheet, cash flow, AR aging, and AP aging',
            'Latest financial report snapshots are cached locally for offline review',
            'Tax, budget, comparative, and export polish remain next reporting parity targets',
          ],
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
    required this.children,
  });

  final String title;
  final String description;
  final String buttonLabel;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onPressed;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon: Icon(icon),
              label: Text(buttonLabel),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ReportRows extends StatelessWidget {
  const _ReportRows({required this.rows});

  final List<ReportRowSummary> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Text('No account activity in this section.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows.take(12))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${row.accountCode} · ${row.accountName} · ${row.accountType} · Dr ${formatMinorAsInr(row.debitMinor)} · Cr ${formatMinorAsInr(row.creditMinor)} · Bal ${formatMinorAsInr(row.balanceMinor)}',
            ),
          ),
      ],
    );
  }
}

class _CashFlowRows extends StatelessWidget {
  const _CashFlowRows({required this.rows});

  final List<CashFlowRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Text('No cash movement in this period.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows.take(12))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${row.accountCode} · ${row.accountName} · ${row.sourceModule} · In ${formatMinorAsInr(row.inflowMinor)} · Out ${formatMinorAsInr(row.outflowMinor)} · Net ${formatMinorAsInr(row.netCashFlowMinor)}',
            ),
          ),
      ],
    );
  }
}

class _AgingTotalsText extends StatelessWidget {
  const _AgingTotalsText({required this.totals});

  final AgingBucketTotals totals;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Outstanding ${formatMinorAsInr(totals.outstandingMinor)} · Current ${formatMinorAsInr(totals.currentMinor)} · 1-30 ${formatMinorAsInr(totals.oneToThirtyMinor)} · 31-60 ${formatMinorAsInr(totals.thirtyOneToSixtyMinor)} · 61-90 ${formatMinorAsInr(totals.sixtyOneToNinetyMinor)} · 90+ ${formatMinorAsInr(totals.overNinetyMinor)}',
    );
  }
}

class _ARAgingRows extends StatelessWidget {
  const _ARAgingRows({required this.rows});

  final List<ARAgingRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Text('No outstanding customer invoices.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows.take(12))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${row.invoiceNumber} · ${row.customerName} · due ${formatDateOnly(row.dueDate)} · ${row.daysOverdue} days · ${formatMinorAsInr(row.outstandingMinor)}',
            ),
          ),
      ],
    );
  }
}

class _APAgingRows extends StatelessWidget {
  const _APAgingRows({required this.rows});

  final List<APAgingRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Text('No outstanding vendor bills.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows.take(12))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${row.billNumber} · ${row.vendorName} · due ${formatDateOnly(row.dueDate)} · ${row.daysOverdue} days · ${formatMinorAsInr(row.outstandingMinor)}',
            ),
          ),
      ],
    );
  }
}

class SyncPage extends StatelessWidget {
  const SyncPage({
    required this.settings,
    required this.offlineMode,
    required this.queuedChanges,
    required this.lastSyncResult,
    required this.notice,
    required this.onOfflineModeChanged,
    required this.onSyncPressed,
    required this.onSettingsChanged,
    required this.onFetchAccounts,
    required this.discoveredAccounts,
    required this.isLoadingAccounts,
    required this.onSelectExpenseAccount,
    required this.onSelectPaymentAccount,
    required this.customers,
    required this.vendors,
    required this.isLoadingParties,
    required this.onFetchParties,
    required this.onFetchTaxCatalog,
    required this.discoveredTaxRates,
    required this.discoveredTaxGroups,
    required this.isLoadingTaxCatalog,
    required this.onSelectTaxRate,
    required this.onSelectTaxGroup,
    required this.attachments,
    required this.isLoadingAttachments,
    required this.onFetchAttachments,
    required this.onUploadSampleAttachment,
    required this.onUploadLocalAttachment,
    required this.onPickAttachment,
    required this.onDownloadAttachment,
    required this.onInspectCachedAttachment,
    required this.cachedBinaryAttachmentIds,
    super.key,
  });

  final SyncSettings settings;
  final bool offlineMode;
  final int queuedChanges;
  final SyncResult? lastSyncResult;
  final String? notice;
  final ValueChanged<bool> onOfflineModeChanged;
  final Future<void> Function() onSyncPressed;
  final Future<void> Function(SyncSettings settings) onSettingsChanged;
  final Future<void> Function() onFetchAccounts;
  final List<AccountSummary> discoveredAccounts;
  final bool isLoadingAccounts;
  final Future<void> Function(AccountSummary account) onSelectExpenseAccount;
  final Future<void> Function(AccountSummary account) onSelectPaymentAccount;
  final List<CustomerSummary> customers;
  final List<VendorSummary> vendors;
  final bool isLoadingParties;
  final Future<void> Function() onFetchParties;
  final Future<void> Function() onFetchTaxCatalog;
  final List<TaxRateSummary> discoveredTaxRates;
  final List<TaxGroupSummary> discoveredTaxGroups;
  final bool isLoadingTaxCatalog;
  final Future<void> Function(TaxRateSummary taxRate) onSelectTaxRate;
  final Future<void> Function(TaxGroupSummary taxGroup) onSelectTaxGroup;
  final List<AttachmentSummary> attachments;
  final bool isLoadingAttachments;
  final Future<void> Function() onFetchAttachments;
  final Future<void> Function() onUploadSampleAttachment;
  final Future<void> Function(String path) onUploadLocalAttachment;
  final Future<void> Function(AttachmentPickSource source) onPickAttachment;
  final Future<void> Function(AttachmentSummary attachment)
  onDownloadAttachment;
  final Future<void> Function(AttachmentSummary attachment)
  onInspectCachedAttachment;
  final Set<String> cachedBinaryAttachmentIds;

  @override
  Widget build(BuildContext context) {
    final tokenStatus = settings.accessToken.trim().isEmpty
        ? 'not set'
        : 'saved locally';
    final defaultExpenseAccount = resolveAccountLabel(
      settings.defaultExpenseAccountId,
      discoveredAccounts,
    );
    final defaultPaymentAccount = resolveAccountLabel(
      settings.defaultPaymentAccountId,
      discoveredAccounts,
    );
    final defaultTaxRate = resolveTaxRateLabel(
      settings.defaultTaxRateId,
      discoveredTaxRates,
    );
    final defaultTaxGroup = resolveTaxGroupLabel(
      settings.defaultTaxGroupId,
      discoveredTaxGroups,
    );
    return AppPage(
      eyebrow: 'Connection settings',
      title: 'API and sync',
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Local defaults',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Text('API base URL: ${settings.apiBaseUrl}'),
                Text(
                  'Organization ID: ${settings.organizationId.trim().isEmpty ? 'not set' : settings.organizationId}',
                ),
                Text('Access token: $tokenStatus'),
                Text(
                  'Default expense account: ${settings.defaultExpenseAccountId.trim().isEmpty ? 'not set' : settings.defaultExpenseAccountId}',
                ),
                if (defaultExpenseAccount != null)
                  Text('Resolved expense account: $defaultExpenseAccount'),
                Text(
                  'Default payment account: ${settings.defaultPaymentAccountId.trim().isEmpty ? 'not set' : settings.defaultPaymentAccountId}',
                ),
                if (defaultPaymentAccount != null)
                  Text('Resolved payment account: $defaultPaymentAccount'),
                Text(
                  'Default tax rate: ${settings.defaultTaxRateId.trim().isEmpty ? 'not set' : settings.defaultTaxRateId}',
                ),
                if (defaultTaxRate != null)
                  Text('Resolved tax rate: $defaultTaxRate'),
                Text(
                  'Default tax group: ${settings.defaultTaxGroupId.trim().isEmpty ? 'not set' : settings.defaultTaxGroupId}',
                ),
                if (defaultTaxGroup != null)
                  Text('Resolved tax group: $defaultTaxGroup'),
                Text('Pending local operations: $queuedChanges'),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow offline drafts'),
                  subtitle: const Text(
                    'Queue expense and invoice view changes until reconnect.',
                  ),
                  value: offlineMode,
                  onChanged: onOfflineModeChanged,
                ),
                SyncSettingsForm(settings: settings, onSave: onSettingsChanged),
                const SizedBox(height: 12),
                AccountDiscoveryPanel(
                  accounts: discoveredAccounts,
                  isLoading: isLoadingAccounts,
                  onFetchAccounts: onFetchAccounts,
                  onSelectExpenseAccount: onSelectExpenseAccount,
                  onSelectPaymentAccount: onSelectPaymentAccount,
                ),
                const SizedBox(height: 12),
                PartyDiscoveryPanel(
                  customers: customers,
                  vendors: vendors,
                  isLoading: isLoadingParties,
                  onFetchParties: onFetchParties,
                ),
                const SizedBox(height: 12),
                TaxDiscoveryPanel(
                  taxRates: discoveredTaxRates,
                  taxGroups: discoveredTaxGroups,
                  isLoading: isLoadingTaxCatalog,
                  onFetchTaxCatalog: onFetchTaxCatalog,
                  onSelectTaxRate: onSelectTaxRate,
                  onSelectTaxGroup: onSelectTaxGroup,
                ),
                const SizedBox(height: 12),
                AttachmentDiscoveryPanel(
                  attachments: attachments,
                  isLoading: isLoadingAttachments,
                  onFetchAttachments: onFetchAttachments,
                  onUploadSampleAttachment: onUploadSampleAttachment,
                  onUploadLocalAttachment: onUploadLocalAttachment,
                  onPickAttachment: onPickAttachment,
                  onDownloadAttachment: onDownloadAttachment,
                  onInspectCachedAttachment: onInspectCachedAttachment,
                  cachedBinaryAttachmentIds: cachedBinaryAttachmentIds,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => onSyncPressed(),
                  icon: const Icon(Icons.sync),
                  label: const Text('Sync pending drafts'),
                ),
                if (notice != null) ...[
                  const SizedBox(height: 12),
                  Text(notice!),
                ],
                if (lastSyncResult != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Last sync: ${lastSyncResult!.synced} synced, '
                    '${lastSyncResult!.skipped} waiting, '
                    '${lastSyncResult!.failed.length} failed, '
                    '${lastSyncResult!.conflicts} need review.',
                  ),
                ],
              ],
            ),
          ),
        ),
        const FeaturePanel(
          title: 'Desktop file workflows',
          description:
              'Desktop builds will expose CSV, OFX/QIF, and export actions once the import adapters are wired into the API.',
          actionLabel: 'Import/export pending',
          onPressed: null,
        ),
      ],
    );
  }
}

class AttachmentDiscoveryPanel extends StatelessWidget {
  const AttachmentDiscoveryPanel({
    required this.attachments,
    required this.isLoading,
    required this.onFetchAttachments,
    required this.onUploadSampleAttachment,
    required this.onUploadLocalAttachment,
    required this.onPickAttachment,
    required this.onDownloadAttachment,
    required this.onInspectCachedAttachment,
    required this.cachedBinaryAttachmentIds,
    super.key,
  });

  final List<AttachmentSummary> attachments;
  final bool isLoading;
  final Future<void> Function() onFetchAttachments;
  final Future<void> Function() onUploadSampleAttachment;
  final Future<void> Function(String path) onUploadLocalAttachment;
  final Future<void> Function(AttachmentPickSource source) onPickAttachment;
  final Future<void> Function(AttachmentSummary attachment)
  onDownloadAttachment;
  final Future<void> Function(AttachmentSummary attachment)
  onInspectCachedAttachment;
  final Set<String> cachedBinaryAttachmentIds;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attachment transport',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload receipt/PDF bytes, cache them offline, and inspect attachment IDs for expense and invoice references.',
            ),
            const SizedBox(height: 12),
            LocalAttachmentUploadForm(
              isLoading: isLoading,
              onUploadLocalAttachment: onUploadLocalAttachment,
              onPickAttachment: onPickAttachment,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: isLoading ? null : () => onFetchAttachments(),
                  icon: isLoading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file_outlined),
                  label: Text(isLoading ? 'Working...' : 'Fetch attachments'),
                ),
                OutlinedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => onUploadSampleAttachment(),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Upload sample receipt'),
                ),
              ],
            ),
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final attachment in attachments)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest.withAlpha(90),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            '${attachment.fileName} · ${attachment.contentType} · ${attachment.sizeBytes} bytes',
                          ),
                          SelectableText('Attachment ID: ${attachment.id}'),
                          SelectableText(
                            'Storage: ${attachment.storageDriver} · ${attachment.storageKey}',
                          ),
                          Text(
                            cachedBinaryAttachmentIds.contains(attachment.id)
                                ? 'Available offline'
                                : 'Not downloaded',
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: isLoading
                                    ? null
                                    : () => onDownloadAttachment(attachment),
                                icon: const Icon(Icons.download_outlined),
                                label: const Text('Download'),
                              ),
                              if (cachedBinaryAttachmentIds.contains(
                                attachment.id,
                              ))
                                OutlinedButton.icon(
                                  onPressed: isLoading
                                      ? null
                                      : () => onInspectCachedAttachment(
                                          attachment,
                                        ),
                                  icon: const Icon(Icons.inventory_2_outlined),
                                  label: const Text('Inspect cached'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class LocalAttachmentUploadForm extends StatefulWidget {
  const LocalAttachmentUploadForm({
    required this.isLoading,
    required this.onUploadLocalAttachment,
    required this.onPickAttachment,
    super.key,
  });

  final bool isLoading;
  final Future<void> Function(String path) onUploadLocalAttachment;
  final Future<void> Function(AttachmentPickSource source) onPickAttachment;

  @override
  State<LocalAttachmentUploadForm> createState() =>
      _LocalAttachmentUploadFormState();
}

class _LocalAttachmentUploadFormState extends State<LocalAttachmentUploadForm> {
  final pathController = TextEditingController();

  @override
  void dispose() {
    pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: pathController,
          decoration: const InputDecoration(
            labelText: 'Local receipt file path',
            helperText:
                'Optional fallback. Prefer the picker buttons below when available.',
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: widget.isLoading
                  ? null
                  : () => widget.onPickAttachment(AttachmentPickSource.file),
              icon: const Icon(Icons.attach_file_outlined),
              label: const Text('Choose receipt/PDF'),
            ),
            OutlinedButton.icon(
              onPressed: widget.isLoading
                  ? null
                  : () => widget.onPickAttachment(AttachmentPickSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Camera receipt'),
            ),
            OutlinedButton.icon(
              onPressed: widget.isLoading
                  ? null
                  : () => widget.onPickAttachment(AttachmentPickSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Gallery image'),
            ),
            OutlinedButton.icon(
              onPressed: widget.isLoading
                  ? null
                  : () => widget.onUploadLocalAttachment(pathController.text),
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Upload path'),
            ),
          ],
        ),
      ],
    );
  }
}

class AccountDiscoveryPanel extends StatelessWidget {
  const AccountDiscoveryPanel({
    required this.accounts,
    required this.isLoading,
    required this.onFetchAccounts,
    required this.onSelectExpenseAccount,
    required this.onSelectPaymentAccount,
    super.key,
  });

  final List<AccountSummary> accounts;
  final bool isLoading;
  final Future<void> Function() onFetchAccounts;
  final Future<void> Function(AccountSummary account) onSelectExpenseAccount;
  final Future<void> Function(AccountSummary account) onSelectPaymentAccount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account lookup',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Fetch chart-of-account IDs, then choose defaults for expense draft posting.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: isLoading ? null : () => onFetchAccounts(),
              icon: isLoading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.manage_search_outlined),
              label: Text(
                isLoading ? 'Fetching accounts...' : 'Fetch accounts',
              ),
            ),
            if (accounts.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final account in accounts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest.withAlpha(90),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            '${account.code} · ${account.name} · ${account.type} · ${account.id}',
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () =>
                                    onSelectExpenseAccount(account),
                                child: const Text('Use as expense'),
                              ),
                              OutlinedButton(
                                onPressed: () =>
                                    onSelectPaymentAccount(account),
                                child: const Text('Use as payment'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class PartyDiscoveryPanel extends StatelessWidget {
  const PartyDiscoveryPanel({
    required this.customers,
    required this.vendors,
    required this.isLoading,
    required this.onFetchParties,
    super.key,
  });

  final List<CustomerSummary> customers;
  final List<VendorSummary> vendors;
  final bool isLoading;
  final Future<void> Function() onFetchParties;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customers and vendors',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Refresh AR/AP party records for offline invoice, bill, and payment reference.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: isLoading ? null : () => onFetchParties(),
              icon: isLoading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.groups_2_outlined),
              label: Text(
                isLoading ? 'Loading parties...' : 'Fetch customers/vendors',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Customers (${customers.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (customers.isEmpty)
              const Text('No customers cached yet.')
            else
              for (final customer in customers.take(6))
                _PartyTile(
                  name: customer.displayName,
                  id: customer.id,
                  email: customer.email,
                  phone: customer.phone,
                  gstin: customer.gstin,
                ),
            const SizedBox(height: 12),
            Text(
              'Vendors (${vendors.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (vendors.isEmpty)
              const Text('No vendors cached yet.')
            else
              for (final vendor in vendors.take(6))
                _PartyTile(
                  name: vendor.displayName,
                  id: vendor.id,
                  email: vendor.email,
                  phone: vendor.phone,
                  gstin: vendor.gstin,
                ),
          ],
        ),
      ),
    );
  }
}

class _PartyTile extends StatelessWidget {
  const _PartyTile({
    required this.name,
    required this.id,
    required this.email,
    required this.phone,
    required this.gstin,
  });

  final String name;
  final String id;
  final String email;
  final String phone;
  final String gstin;

  @override
  Widget build(BuildContext context) {
    final contact = [
      if (email.trim().isNotEmpty) email,
      if (phone.trim().isNotEmpty) phone,
      if (gstin.trim().isNotEmpty) 'GSTIN $gstin',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withAlpha(90),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleSmall),
              if (contact.isNotEmpty) Text(contact),
              SelectableText('Party ID: $id'),
            ],
          ),
        ),
      ),
    );
  }
}

class TaxDiscoveryPanel extends StatelessWidget {
  const TaxDiscoveryPanel({
    required this.taxRates,
    required this.taxGroups,
    required this.isLoading,
    required this.onFetchTaxCatalog,
    required this.onSelectTaxRate,
    required this.onSelectTaxGroup,
    super.key,
  });

  final List<TaxRateSummary> taxRates;
  final List<TaxGroupSummary> taxGroups;
  final bool isLoading;
  final Future<void> Function() onFetchTaxCatalog;
  final Future<void> Function(TaxRateSummary taxRate) onSelectTaxRate;
  final Future<void> Function(TaxGroupSummary taxGroup) onSelectTaxGroup;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tax lookup', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Fetch configured VAT/GST rates and groups, then choose defaults for expense drafts.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: isLoading ? null : () => onFetchTaxCatalog(),
              icon: isLoading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.percent_outlined),
              label: Text(
                isLoading ? 'Fetching tax config...' : 'Fetch tax config',
              ),
            ),
            if (taxRates.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Rates', style: Theme.of(context).textTheme.labelLarge),
              for (final taxRate in taxRates)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest.withAlpha(90),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            '${taxRate.name} · ${formatBasisPointsAsPercent(taxRate.percentageBasis)} · ${taxRate.type} · ${taxRate.id}',
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () => onSelectTaxRate(taxRate),
                            child: const Text('Use as tax rate'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
            if (taxGroups.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Groups', style: Theme.of(context).textTheme.labelLarge),
              for (final taxGroup in taxGroups)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest.withAlpha(90),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText('${taxGroup.name} · ${taxGroup.id}'),
                          if (taxGroup.description.trim().isNotEmpty)
                            Text(taxGroup.description),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () => onSelectTaxGroup(taxGroup),
                            child: const Text('Use as tax group'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

String formatBasisPointsAsPercent(int percentageBasis) {
  final whole = percentageBasis ~/ 10000;
  final fraction = (percentageBasis % 10000).toString().padLeft(4, '0');
  return '$whole.${fraction.substring(0, 2)}%';
}

String? resolveAccountLabel(String accountId, List<AccountSummary> accounts) {
  final normalized = accountId.trim();
  if (normalized.isEmpty) {
    return null;
  }
  for (final account in accounts) {
    if (account.id == normalized) {
      return '${account.code} · ${account.name}';
    }
  }
  return null;
}

String? resolveTaxRateLabel(String taxRateId, List<TaxRateSummary> rates) {
  final normalized = taxRateId.trim();
  if (normalized.isEmpty) {
    return null;
  }
  for (final rate in rates) {
    if (rate.id == normalized) {
      return '${rate.name} · ${formatBasisPointsAsPercent(rate.percentageBasis)}';
    }
  }
  return null;
}

String? resolveTaxGroupLabel(String taxGroupId, List<TaxGroupSummary> groups) {
  final normalized = taxGroupId.trim();
  if (normalized.isEmpty) {
    return null;
  }
  for (final group in groups) {
    if (group.id == normalized) {
      return group.name;
    }
  }
  return null;
}

class SyncSettingsForm extends StatefulWidget {
  const SyncSettingsForm({
    required this.settings,
    required this.onSave,
    super.key,
  });

  final SyncSettings settings;
  final Future<void> Function(SyncSettings settings) onSave;

  @override
  State<SyncSettingsForm> createState() => _SyncSettingsFormState();
}

class _SyncSettingsFormState extends State<SyncSettingsForm> {
  late final TextEditingController apiBaseUrlController;
  late final TextEditingController accessTokenController;
  late final TextEditingController organizationIdController;
  late final TextEditingController expenseAccountController;
  late final TextEditingController paymentAccountController;
  late final TextEditingController taxRateController;
  late final TextEditingController taxGroupController;

  @override
  void initState() {
    super.initState();
    apiBaseUrlController = TextEditingController(
      text: widget.settings.apiBaseUrl,
    );
    accessTokenController = TextEditingController(
      text: widget.settings.accessToken,
    );
    organizationIdController = TextEditingController(
      text: widget.settings.organizationId,
    );
    expenseAccountController = TextEditingController(
      text: widget.settings.defaultExpenseAccountId,
    );
    paymentAccountController = TextEditingController(
      text: widget.settings.defaultPaymentAccountId,
    );
    taxRateController = TextEditingController(
      text: widget.settings.defaultTaxRateId,
    );
    taxGroupController = TextEditingController(
      text: widget.settings.defaultTaxGroupId,
    );
  }

  @override
  void didUpdateWidget(covariant SyncSettingsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      apiBaseUrlController.text = widget.settings.apiBaseUrl;
      accessTokenController.text = widget.settings.accessToken;
      organizationIdController.text = widget.settings.organizationId;
      expenseAccountController.text = widget.settings.defaultExpenseAccountId;
      paymentAccountController.text = widget.settings.defaultPaymentAccountId;
      taxRateController.text = widget.settings.defaultTaxRateId;
      taxGroupController.text = widget.settings.defaultTaxGroupId;
    }
  }

  @override
  void dispose() {
    apiBaseUrlController.dispose();
    accessTokenController.dispose();
    organizationIdController.dispose();
    expenseAccountController.dispose();
    paymentAccountController.dispose();
    taxRateController.dispose();
    taxGroupController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    await widget.onSave(
      SyncSettings(
        apiBaseUrl: apiBaseUrlController.text,
        accessToken: accessTokenController.text,
        organizationId: organizationIdController.text,
        defaultExpenseAccountId: expenseAccountController.text,
        defaultPaymentAccountId: paymentAccountController.text,
        defaultTaxRateId: taxRateController.text,
        defaultTaxGroupId: taxGroupController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: apiBaseUrlController,
          decoration: const InputDecoration(labelText: 'API base URL'),
        ),
        TextField(
          controller: accessTokenController,
          decoration: const InputDecoration(labelText: 'JWT access token'),
          obscureText: true,
        ),
        TextField(
          controller: organizationIdController,
          decoration: const InputDecoration(labelText: 'Organization ID'),
        ),
        TextField(
          controller: expenseAccountController,
          decoration: const InputDecoration(
            labelText: 'Default expense account ID',
          ),
        ),
        TextField(
          controller: paymentAccountController,
          decoration: const InputDecoration(
            labelText: 'Default payment account ID',
          ),
        ),
        TextField(
          controller: taxRateController,
          decoration: const InputDecoration(labelText: 'Default tax rate ID'),
        ),
        TextField(
          controller: taxGroupController,
          decoration: const InputDecoration(labelText: 'Default tax group ID'),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => save(),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save sync settings'),
          ),
        ),
      ],
    );
  }
}

class AppPage extends StatelessWidget {
  const AppPage({
    required this.eyebrow,
    required this.title,
    required this.children,
    super.key,
  });

  final String eyebrow;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7F1E5), Color(0xFFE4F0E7)],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF7A5A22),
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 24),
          ...children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusCard extends StatelessWidget {
  const StatusCard({
    required this.label,
    required this.value,
    required this.icon,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF1E6B4E)),
              const SizedBox(height: 18),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Text(value, style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class FeaturePanel extends StatelessWidget {
  const FeaturePanel({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onPressed,
    super.key,
  });

  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 18),
            FilledButton.tonal(onPressed: onPressed, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class PlatformPanel extends StatelessWidget {
  const PlatformPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoList(
      items: [
        'Mobile: receipt camera capture and field expense entry.',
        'Desktop: file-based bank import, exports, and fuller ledger review.',
        'Shared Dart layer: one API client and sync queue for every platform.',
      ],
    );
  }
}

class InfoList extends StatelessWidget {
  const InfoList({required this.items, super.key});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
