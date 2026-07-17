import 'dart:convert';
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
import 'reports/report_csv_exporter.dart';
import 'reports/report_cache_repository.dart';
import 'reports/report_export_repository.dart';
import 'reports/report_share_service.dart';
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
typedef TaxLiabilityReportLoader =
    Future<TaxLiabilityReport> Function(
      SyncSettings settings,
      DateTime from,
      DateTime to,
    );
typedef TaxSummaryReportLoader =
    Future<TaxSummaryReport> Function(
      SyncSettings settings,
      DateTime from,
      DateTime to,
    );
typedef BudgetLoader =
    Future<List<BudgetSummary>> Function(SyncSettings settings);
typedef BudgetVsActualLoader =
    Future<BudgetVsActualReport> Function(
      SyncSettings settings,
      String budgetId,
    );
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
typedef TextFilePicker = Future<PickedTextFile?> Function();
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
  final reportExportRepository = await createDefaultReportExportRepository();
  final reportShareService = createDefaultReportShareService();
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
      reportExportRepository: reportExportRepository,
      reportShareService: reportShareService,
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
    this.reportExportRepository,
    this.reportShareService,
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
    this.taxLiabilityReportLoader,
    this.taxSummaryReportLoader,
    this.budgetLoader,
    this.budgetVsActualLoader,
    this.taxRateLoader,
    this.taxGroupLoader,
    this.attachmentLoader,
    this.investmentLotLoader,
    this.realizedGainsLoader,
    this.investmentValuationLoader,
    this.attachmentUploader,
    this.attachmentDownloader,
    this.attachmentPicker,
    this.textFilePicker,
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
  final ReportExportRepository? reportExportRepository;
  final ReportShareService? reportShareService;
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
  final TaxLiabilityReportLoader? taxLiabilityReportLoader;
  final TaxSummaryReportLoader? taxSummaryReportLoader;
  final BudgetLoader? budgetLoader;
  final BudgetVsActualLoader? budgetVsActualLoader;
  final TaxRateLoader? taxRateLoader;
  final TaxGroupLoader? taxGroupLoader;
  final AttachmentLoader? attachmentLoader;
  final InvestmentLotLoader? investmentLotLoader;
  final RealizedGainsLoader? realizedGainsLoader;
  final InvestmentValuationLoader? investmentValuationLoader;
  final AttachmentUploader? attachmentUploader;
  final AttachmentDownloader? attachmentDownloader;
  final AttachmentPicker? attachmentPicker;
  final TextFilePicker? textFilePicker;
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
        reportExportRepository: reportExportRepository,
        reportShareService: reportShareService,
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
        taxLiabilityReportLoader: taxLiabilityReportLoader,
        taxSummaryReportLoader: taxSummaryReportLoader,
        budgetLoader: budgetLoader,
        budgetVsActualLoader: budgetVsActualLoader,
        taxRateLoader: taxRateLoader,
        taxGroupLoader: taxGroupLoader,
        attachmentLoader: attachmentLoader,
        investmentLotLoader: investmentLotLoader,
        realizedGainsLoader: realizedGainsLoader,
        investmentValuationLoader: investmentValuationLoader,
        attachmentUploader: attachmentUploader,
        attachmentDownloader: attachmentDownloader,
        attachmentPicker: attachmentPicker,
        textFilePicker: textFilePicker,
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
    this.reportExportRepository,
    this.reportShareService,
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
    this.taxLiabilityReportLoader,
    this.taxSummaryReportLoader,
    this.budgetLoader,
    this.budgetVsActualLoader,
    this.taxRateLoader,
    this.taxGroupLoader,
    this.attachmentLoader,
    this.investmentLotLoader,
    this.realizedGainsLoader,
    this.investmentValuationLoader,
    this.attachmentUploader,
    this.attachmentDownloader,
    this.attachmentPicker,
    this.textFilePicker,
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
  final ReportExportRepository? reportExportRepository;
  final ReportShareService? reportShareService;
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
  final TaxLiabilityReportLoader? taxLiabilityReportLoader;
  final TaxSummaryReportLoader? taxSummaryReportLoader;
  final BudgetLoader? budgetLoader;
  final BudgetVsActualLoader? budgetVsActualLoader;
  final TaxRateLoader? taxRateLoader;
  final TaxGroupLoader? taxGroupLoader;
  final AttachmentLoader? attachmentLoader;
  final InvestmentLotLoader? investmentLotLoader;
  final RealizedGainsLoader? realizedGainsLoader;
  final InvestmentValuationLoader? investmentValuationLoader;
  final AttachmentUploader? attachmentUploader;
  final AttachmentDownloader? attachmentDownloader;
  final AttachmentPicker? attachmentPicker;
  final TextFilePicker? textFilePicker;
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
  late final ReportExportRepository reportExportRepository;
  late final ReportShareService reportShareService;
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
  InvoiceSummary? editingInvoiceDraft;
  List<CustomerSummary> cachedCustomers = const [];
  List<VendorSummary> cachedVendors = const [];
  TrialBalanceReport? cachedTrialBalanceReport;
  ProfitAndLossReport? cachedProfitAndLossReport;
  ProfitAndLossReport? priorProfitAndLossReport;
  BalanceSheetReport? cachedBalanceSheetReport;
  BalanceSheetReport? priorBalanceSheetReport;
  CashFlowReport? cachedCashFlowReport;
  CashFlowReport? priorCashFlowReport;
  ARAgingReport? cachedARAgingReport;
  ARAgingReport? priorARAgingReport;
  APAgingReport? cachedAPAgingReport;
  APAgingReport? priorAPAgingReport;
  TaxLiabilityReport? cachedTaxLiabilityReport;
  TaxLiabilityReport? priorTaxLiabilityReport;
  TaxSummaryReport? cachedTaxSummaryReport;
  TaxSummaryReport? priorTaxSummaryReport;
  List<BudgetSummary> cachedBudgets = const [];
  BudgetVsActualReport? cachedBudgetVsActualReport;
  BudgetVsActualReport? priorBudgetVsActualReport;
  String? lastReportExportDirectory;
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
    reportExportRepository =
        widget.reportExportRepository ?? MemoryReportExportRepository();
    reportShareService =
        widget.reportShareService ?? MemoryReportShareService();
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
      cachedTaxLiabilityReport = snapshot.taxLiability;
      cachedTaxSummaryReport = snapshot.taxSummary;
      cachedBudgets = snapshot.budgets;
      cachedBudgetVsActualReport = snapshot.budgetVsActual;
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

  Future<void> queueInvoiceDraft(InvoiceDraftInput input) async {
    final operation = syncQueue.enqueueInvoiceDraft(
      customerId: input.customerId.trim(),
      invoiceNumber: input.invoiceNumber.trim().isEmpty
          ? 'INV-MOB-${DateTime.now().millisecondsSinceEpoch}'
          : input.invoiceNumber.trim(),
      accountsReceivableId: input.accountsReceivableId.trim(),
      description: input.description.trim().isEmpty
          ? 'Mobile invoice line'
          : input.description.trim(),
      unitPriceMinor: input.unitPriceMinor,
      incomeAccountId: input.incomeAccountId.trim(),
      issueDate: input.issueDate,
      dueDate: input.dueDate,
      quantityMillis: input.quantityMillis,
      pdfAttachmentId: input.pdfAttachmentId.trim().isEmpty
          ? null
          : input.pdfAttachmentId.trim(),
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
    );
    await repository.savePending(syncQueue.pending);
    setState(() {
      syncNotice = 'Draft invoice queued for sync: ${operation.id}';
    });
  }

  Future<void> queueInvoiceDraftUpdate(
    String invoiceId,
    InvoiceDraftInput input,
  ) async {
    final operation = syncQueue.enqueueInvoiceDraftUpdate(
      invoiceId: invoiceId,
      customerId: input.customerId.trim(),
      invoiceNumber: input.invoiceNumber.trim().isEmpty
          ? 'INV-MOB-${DateTime.now().millisecondsSinceEpoch}'
          : input.invoiceNumber.trim(),
      accountsReceivableId: input.accountsReceivableId.trim(),
      description: input.description.trim().isEmpty
          ? 'Mobile invoice line'
          : input.description.trim(),
      unitPriceMinor: input.unitPriceMinor,
      incomeAccountId: input.incomeAccountId.trim(),
      issueDate: input.issueDate,
      dueDate: input.dueDate,
      quantityMillis: input.quantityMillis,
      pdfAttachmentId: input.pdfAttachmentId.trim().isEmpty
          ? null
          : input.pdfAttachmentId.trim(),
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
    );
    await repository.savePending(syncQueue.pending);
    setState(() {
      editingInvoiceDraft = null;
      syncNotice = 'Draft invoice update queued for sync: ${operation.id}';
    });
  }

  void editInvoiceDraft(InvoiceSummary invoice) {
    setState(() {
      editingInvoiceDraft = invoice;
    });
  }

  void cancelInvoiceDraftEdit() {
    setState(() {
      editingInvoiceDraft = null;
    });
  }

  Future<void> queueInvoicePost(String invoiceId) async {
    final operation = syncQueue.enqueueInvoicePost(invoiceId: invoiceId.trim());
    await repository.savePending(syncQueue.pending);
    setState(() {
      syncNotice = 'Invoice posting queued for sync: ${operation.id}';
    });
  }

  Future<void> queueCustomerPayment(CustomerPaymentInput input) async {
    final operation = syncQueue.enqueueCustomerPayment(
      invoiceId: input.invoiceId.trim(),
      paymentNumber: input.paymentNumber.trim().isEmpty
          ? 'PAY-MOB-${DateTime.now().millisecondsSinceEpoch}'
          : input.paymentNumber.trim(),
      paymentDate: input.paymentDate,
      amountMinor: input.amountMinor,
      paymentAccountId: input.paymentAccountId.trim(),
      paymentMethod: input.paymentMethod.trim(),
      reference: input.reference.trim(),
    );
    await repository.savePending(syncQueue.pending);
    setState(() {
      syncNotice = 'Customer payment queued for sync: ${operation.id}';
    });
  }

  Future<void> queueBillPost(String billId) async {
    final operation = syncQueue.enqueueBillPost(billId: billId.trim());
    await repository.savePending(syncQueue.pending);
    setState(() {
      syncNotice = 'Bill posting queued for sync: ${operation.id}';
    });
  }

  Future<void> queueVendorPayment(VendorPaymentInput input) async {
    final operation = syncQueue.enqueueVendorPayment(
      billId: input.billId.trim(),
      paymentNumber: input.paymentNumber.trim().isEmpty
          ? 'VPAY-MOB-${DateTime.now().millisecondsSinceEpoch}'
          : input.paymentNumber.trim(),
      paymentDate: input.paymentDate,
      amountMinor: input.amountMinor,
      paymentAccountId: input.paymentAccountId.trim(),
      paymentMethod: input.paymentMethod.trim(),
      reference: input.reference.trim(),
    );
    await repository.savePending(syncQueue.pending);
    setState(() {
      syncNotice = 'Vendor payment queued for sync: ${operation.id}';
    });
  }

  Future<void> queueBrokerHoldingsImport(String csv, String source) async {
    final operation = syncQueue.enqueueBrokerHoldingsPriceImport(
      csv: csv,
      source: source,
    );
    await repository.savePending(syncQueue.pending);
    setState(() {
      syncNotice = 'Broker holdings import queued for sync: ${operation.id}';
    });
  }

  Future<void> queueInvestmentPrice({
    required String symbol,
    required DateTime priceDate,
    required int priceMinor,
    required String source,
  }) async {
    final operation = syncQueue.enqueueInvestmentPrice(
      symbol: symbol,
      priceDate: priceDate,
      priceMinor: priceMinor,
      source: source,
    );
    await repository.savePending(syncQueue.pending);
    setState(() {
      syncNotice = 'Investment price queued for sync: ${operation.id}';
    });
  }

  Future<void> queueInvestmentLot({
    required String accountId,
    required String symbol,
    required String securityName,
    required DateTime acquisitionDate,
    required int quantityMillis,
    required int costBasisMinor,
    required String costMethod,
    required String notes,
  }) async {
    final operation = syncQueue.enqueueInvestmentLot(
      accountId: accountId,
      symbol: symbol,
      securityName: securityName,
      acquisitionDate: acquisitionDate,
      quantityMillis: quantityMillis,
      costBasisMinor: costBasisMinor,
      costMethod: costMethod,
      notes: notes,
    );
    await repository.savePending(syncQueue.pending);
    setState(() {
      syncNotice = 'Investment lot queued for sync: ${operation.id}';
    });
  }

  Future<void> queueAverageCostSale({
    required String accountId,
    required String symbol,
    required DateTime saleDate,
    required int quantityMillis,
    required int proceedsMinor,
    required String proceedsAccountId,
    required String gainLossAccountId,
    required String notes,
  }) async {
    final operation = syncQueue.enqueueAverageCostSale(
      accountId: accountId,
      symbol: symbol,
      saleDate: saleDate,
      quantityMillis: quantityMillis,
      proceedsMinor: proceedsMinor,
      proceedsAccountId: proceedsAccountId,
      gainLossAccountId: gainLossAccountId,
      notes: notes,
    );
    await repository.savePending(syncQueue.pending);
    setState(() {
      syncNotice = 'Average-cost sale queued for sync: ${operation.id}';
    });
  }

  Future<void> queueInvestmentLotSale({
    required String lotId,
    required DateTime saleDate,
    required int quantityMillis,
    required int proceedsMinor,
    required String proceedsAccountId,
    required String gainLossAccountId,
    required String notes,
  }) async {
    final operation = syncQueue.enqueueInvestmentLotSale(
      lotId: lotId,
      saleDate: saleDate,
      quantityMillis: quantityMillis,
      proceedsMinor: proceedsMinor,
      proceedsAccountId: proceedsAccountId,
      gainLossAccountId: gainLossAccountId,
      notes: notes,
    );
    await repository.savePending(syncQueue.pending);
    setState(() {
      syncNotice = 'Specific-lot sale queued for sync: ${operation.id}';
    });
  }

  Future<void> queueInvestmentDividend({
    required String accountId,
    required String symbol,
    required DateTime dividendDate,
    required int amountMinor,
    required String cashAccountId,
    required String incomeAccountId,
    required String notes,
  }) async {
    final operation = syncQueue.enqueueInvestmentDividend(
      accountId: accountId,
      symbol: symbol,
      dividendDate: dividendDate,
      amountMinor: amountMinor,
      cashAccountId: cashAccountId,
      incomeAccountId: incomeAccountId,
      notes: notes,
    );
    await repository.savePending(syncQueue.pending);
    setState(() {
      syncNotice = 'Investment dividend queued for sync: ${operation.id}';
    });
  }

  Future<void> queueInvestmentCorporateAction({
    required String accountId,
    required String symbol,
    required String actionType,
    required DateTime actionDate,
    required int ratioNumerator,
    required int ratioDenominator,
    required String notes,
  }) async {
    final operation = syncQueue.enqueueInvestmentCorporateAction(
      accountId: accountId,
      symbol: symbol,
      actionType: actionType,
      actionDate: actionDate,
      ratioNumerator: ratioNumerator,
      ratioDenominator: ratioDenominator,
      notes: notes,
    );
    await repository.savePending(syncQueue.pending);
    setState(() {
      syncNotice = 'Corporate action queued for sync: ${operation.id}';
    });
  }

  Future<PickedTextFile?> pickBrokerHoldingsCSV() {
    final picker = widget.textFilePicker ?? pickTextFile;
    return picker();
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

  Future<void> fetchProfitAndLossComparison(DateTime from, DateTime to) async {
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
      final current = await loader(settings, from, to);
      final previousFrom = DateTime.utc(from.year - 1, from.month, from.day);
      final previousTo = DateTime.utc(to.year - 1, to.month, to.day);
      final previous = await loader(settings, previousFrom, previousTo);
      final snapshot = await reportCacheRepository.loadCached();
      await reportCacheRepository.saveCached(
        snapshot.copyWith(profitAndLoss: current),
      );
      setState(() {
        cachedProfitAndLossReport = current;
        priorProfitAndLossReport = previous;
        syncNotice =
            'Fetched P&L comparison for ${formatDateOnly(current.fromDate)} to ${formatDateOnly(current.toDate)}.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'P&L comparison fetch failed: $error';
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

  Future<void> fetchBalanceSheetComparison(DateTime asOf) async {
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
      final current = await loader(settings, asOf);
      final previous = await loader(
        settings,
        DateTime.utc(asOf.year - 1, asOf.month, asOf.day),
      );
      final snapshot = await reportCacheRepository.loadCached();
      await reportCacheRepository.saveCached(
        snapshot.copyWith(balanceSheet: current),
      );
      setState(() {
        cachedBalanceSheetReport = current;
        priorBalanceSheetReport = previous;
        syncNotice =
            'Fetched balance sheet comparison as of ${formatDateOnly(current.asOfDate)}.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Balance sheet comparison fetch failed: $error';
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

  Future<void> fetchCashFlowComparison(DateTime from, DateTime to) async {
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
      final current = await loader(settings, from, to);
      final previousFrom = DateTime.utc(from.year - 1, from.month, from.day);
      final previousTo = DateTime.utc(to.year - 1, to.month, to.day);
      final previous = await loader(settings, previousFrom, previousTo);
      final snapshot = await reportCacheRepository.loadCached();
      await reportCacheRepository.saveCached(
        snapshot.copyWith(cashFlow: current),
      );
      setState(() {
        cachedCashFlowReport = current;
        priorCashFlowReport = previous;
        syncNotice =
            'Fetched cash flow comparison for ${formatDateOnly(current.fromDate)} to ${formatDateOnly(current.toDate)}.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Cash flow comparison fetch failed: $error';
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

  Future<void> fetchARAgingComparison(DateTime asOf) async {
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
      final current = await loader(settings, asOf);
      final previous = await loader(
        settings,
        DateTime.utc(asOf.year - 1, asOf.month, asOf.day),
      );
      final snapshot = await reportCacheRepository.loadCached();
      await reportCacheRepository.saveCached(
        snapshot.copyWith(arAging: current),
      );
      setState(() {
        cachedARAgingReport = current;
        priorARAgingReport = previous;
        syncNotice =
            'Fetched AR aging comparison as of ${formatDateOnly(current.asOfDate)}.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'AR aging comparison fetch failed: $error';
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

  Future<void> fetchAPAgingComparison(DateTime asOf) async {
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
      final current = await loader(settings, asOf);
      final previous = await loader(
        settings,
        DateTime.utc(asOf.year - 1, asOf.month, asOf.day),
      );
      final snapshot = await reportCacheRepository.loadCached();
      await reportCacheRepository.saveCached(
        snapshot.copyWith(apAging: current),
      );
      setState(() {
        cachedAPAgingReport = current;
        priorAPAgingReport = previous;
        syncNotice =
            'Fetched AP aging comparison as of ${formatDateOnly(current.asOfDate)}.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'AP aging comparison fetch failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingReports = false;
        });
      }
    }
  }

  Future<void> fetchTaxLiabilityReport(DateTime from, DateTime to) async {
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
          widget.taxLiabilityReportLoader ??
          (settings, from, to) => AccountingApiClient(
            config: settings.toApiConfig(),
          ).getTaxLiability(from: from, to: to);
      final report = await loader(settings, from, to);
      final snapshot = await reportCacheRepository.loadCached();
      await reportCacheRepository.saveCached(
        snapshot.copyWith(taxLiability: report),
      );
      setState(() {
        cachedTaxLiabilityReport = report;
        syncNotice =
            'Fetched tax liability from ${formatDateOnly(report.fromDate)} to ${formatDateOnly(report.toDate)}.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Tax liability fetch failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingReports = false;
        });
      }
    }
  }

  Future<void> fetchTaxSummaryReport(DateTime from, DateTime to) async {
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
          widget.taxSummaryReportLoader ??
          (settings, from, to) => AccountingApiClient(
            config: settings.toApiConfig(),
          ).getTaxSummary(from: from, to: to);
      final report = await loader(settings, from, to);
      final snapshot = await reportCacheRepository.loadCached();
      await reportCacheRepository.saveCached(
        snapshot.copyWith(taxSummary: report),
      );
      setState(() {
        cachedTaxSummaryReport = report;
        syncNotice =
            'Fetched tax summary from ${formatDateOnly(report.fromDate)} to ${formatDateOnly(report.toDate)}.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Tax summary fetch failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingReports = false;
        });
      }
    }
  }

  Future<void> fetchTaxLiabilityComparison(DateTime from, DateTime to) async {
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
          widget.taxLiabilityReportLoader ??
          (settings, from, to) => AccountingApiClient(
            config: settings.toApiConfig(),
          ).getTaxLiability(from: from, to: to);
      final current = await loader(settings, from, to);
      final previous = await loader(
        settings,
        DateTime.utc(from.year - 1, from.month, from.day),
        DateTime.utc(to.year - 1, to.month, to.day),
      );
      final snapshot = await reportCacheRepository.loadCached();
      await reportCacheRepository.saveCached(
        snapshot.copyWith(taxLiability: current),
      );
      setState(() {
        cachedTaxLiabilityReport = current;
        priorTaxLiabilityReport = previous;
        syncNotice =
            'Fetched tax liability comparison from ${formatDateOnly(current.fromDate)} to ${formatDateOnly(current.toDate)}.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Tax liability comparison fetch failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingReports = false;
        });
      }
    }
  }

  Future<void> fetchTaxSummaryComparison(DateTime from, DateTime to) async {
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
          widget.taxSummaryReportLoader ??
          (settings, from, to) => AccountingApiClient(
            config: settings.toApiConfig(),
          ).getTaxSummary(from: from, to: to);
      final current = await loader(settings, from, to);
      final previous = await loader(
        settings,
        DateTime.utc(from.year - 1, from.month, from.day),
        DateTime.utc(to.year - 1, to.month, to.day),
      );
      final snapshot = await reportCacheRepository.loadCached();
      await reportCacheRepository.saveCached(
        snapshot.copyWith(taxSummary: current),
      );
      setState(() {
        cachedTaxSummaryReport = current;
        priorTaxSummaryReport = previous;
        syncNotice =
            'Fetched tax summary comparison from ${formatDateOnly(current.fromDate)} to ${formatDateOnly(current.toDate)}.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Tax summary comparison fetch failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingReports = false;
        });
      }
    }
  }

  Future<void> fetchBudgets() async {
    if (!settings.canFetchAccounts) {
      setState(() {
        syncNotice =
            'Add API credentials and organization ID before fetching budgets.';
      });
      return;
    }

    setState(() {
      isLoadingReports = true;
      syncNotice = null;
    });

    try {
      final loader =
          widget.budgetLoader ??
          (settings) =>
              AccountingApiClient(config: settings.toApiConfig()).listBudgets();
      final budgets = await loader(settings);
      final snapshot = await reportCacheRepository.loadCached();
      await reportCacheRepository.saveCached(
        snapshot.copyWith(budgets: budgets),
      );
      setState(() {
        cachedBudgets = budgets;
        syncNotice = 'Fetched ${budgets.length} budgets.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Budget fetch failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingReports = false;
        });
      }
    }
  }

  Future<void> fetchBudgetVsActual(String budgetId) async {
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
          widget.budgetVsActualLoader ??
          (settings, budgetId) => AccountingApiClient(
            config: settings.toApiConfig(),
          ).getBudgetVsActual(budgetId: budgetId);
      final report = await loader(settings, budgetId);
      final snapshot = await reportCacheRepository.loadCached();
      await reportCacheRepository.saveCached(
        snapshot.copyWith(budgetVsActual: report),
      );
      setState(() {
        cachedBudgetVsActualReport = report;
        syncNotice = 'Fetched budget vs actual report.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Budget vs actual fetch failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingReports = false;
        });
      }
    }
  }

  Future<void> fetchBudgetVsActualComparison(
    String budgetId,
    String previousBudgetId,
  ) async {
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
          widget.budgetVsActualLoader ??
          (settings, budgetId) => AccountingApiClient(
            config: settings.toApiConfig(),
          ).getBudgetVsActual(budgetId: budgetId);
      final current = await loader(settings, budgetId);
      final previous = await loader(settings, previousBudgetId);
      final snapshot = await reportCacheRepository.loadCached();
      await reportCacheRepository.saveCached(
        snapshot.copyWith(budgetVsActual: current),
      );
      setState(() {
        cachedBudgetVsActualReport = current;
        priorBudgetVsActualReport = previous;
        syncNotice = 'Fetched budget comparison.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Budget comparison fetch failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingReports = false;
        });
      }
    }
  }

  Future<void> saveReportCsvExports(
    List<ReportCsvExport> exports, {
    bool toDownloads = false,
  }) async {
    if (exports.isEmpty) {
      setState(() {
        syncNotice = 'No cached reports available for CSV export yet.';
      });
      return;
    }

    setState(() {
      isLoadingReports = true;
      syncNotice = null;
    });

    try {
      final result = toDownloads
          ? await reportExportRepository.saveExportsToDownloads(exports)
          : await reportExportRepository.saveExports(exports);
      setState(() {
        lastReportExportDirectory = result.directoryPath;
        syncNotice =
            'Saved ${result.fileCount} report CSV files to ${result.directoryPath}.';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Report CSV export failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingReports = false;
        });
      }
    }
  }

  Future<void> shareReportCsvExports(List<ReportCsvExport> exports) async {
    if (exports.isEmpty) {
      setState(() {
        syncNotice = 'No cached reports available for CSV export yet.';
      });
      return;
    }

    setState(() {
      isLoadingReports = true;
      syncNotice = null;
    });

    try {
      final exportResult = await reportExportRepository.saveExports(exports);
      final shareResult = await reportShareService.shareExports(exportResult);
      setState(() {
        lastReportExportDirectory = exportResult.directoryPath;
        syncNotice =
            'Shared ${shareResult.fileCount} report CSV files (${shareResult.status}).';
      });
    } on Object catch (error) {
      setState(() {
        syncNotice = 'Report CSV share failed: $error';
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
        customers: cachedCustomers,
        attachments: discoveredAttachments,
        editingInvoiceDraft: editingInvoiceDraft,
        cachedBinaryAttachmentIds: cachedAttachmentBinaryIds,
        isLoading: isLoadingInvoices,
        notice: syncNotice,
        onFetchInvoices: fetchInvoices,
        onQueueInvoiceDraft: queueInvoiceDraft,
        onQueueInvoiceDraftUpdate: queueInvoiceDraftUpdate,
        onQueueInvoicePost: queueInvoicePost,
        onQueueCustomerPayment: queueCustomerPayment,
        onEditInvoiceDraft: editInvoiceDraft,
        onCancelInvoiceDraftEdit: cancelInvoiceDraftEdit,
        onDownloadAttachment: downloadAttachment,
        onInspectCachedAttachment: inspectCachedAttachment,
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
        onQueueInvestmentLot: queueInvestmentLot,
        onQueueInvestmentPrice: queueInvestmentPrice,
        onQueueAverageCostSale: queueAverageCostSale,
        onQueueInvestmentLotSale: queueInvestmentLotSale,
        onQueueInvestmentDividend: queueInvestmentDividend,
        onQueueInvestmentCorporateAction: queueInvestmentCorporateAction,
        onQueueBrokerHoldingsImport: queueBrokerHoldingsImport,
        onPickBrokerHoldingsCSV: pickBrokerHoldingsCSV,
      ),
      ReportsPage(
        trialBalance: cachedTrialBalanceReport,
        profitAndLoss: cachedProfitAndLossReport,
        priorProfitAndLoss: priorProfitAndLossReport,
        balanceSheet: cachedBalanceSheetReport,
        priorBalanceSheet: priorBalanceSheetReport,
        cashFlow: cachedCashFlowReport,
        priorCashFlow: priorCashFlowReport,
        arAging: cachedARAgingReport,
        priorARAging: priorARAgingReport,
        apAging: cachedAPAgingReport,
        priorAPAging: priorAPAgingReport,
        taxLiability: cachedTaxLiabilityReport,
        priorTaxLiability: priorTaxLiabilityReport,
        taxSummary: cachedTaxSummaryReport,
        priorTaxSummary: priorTaxSummaryReport,
        budgets: cachedBudgets,
        budgetVsActual: cachedBudgetVsActualReport,
        priorBudgetVsActual: priorBudgetVsActualReport,
        isLoading: isLoadingReports,
        notice: syncNotice,
        lastExportDirectory: lastReportExportDirectory,
        onFetchTrialBalance: fetchTrialBalance,
        onFetchProfitAndLoss: fetchProfitAndLoss,
        onFetchProfitAndLossComparison: fetchProfitAndLossComparison,
        onFetchBalanceSheet: fetchBalanceSheet,
        onFetchBalanceSheetComparison: fetchBalanceSheetComparison,
        onFetchCashFlow: fetchCashFlow,
        onFetchCashFlowComparison: fetchCashFlowComparison,
        onFetchARAging: fetchARAging,
        onFetchARAgingComparison: fetchARAgingComparison,
        onFetchAPAging: fetchAPAging,
        onFetchAPAgingComparison: fetchAPAgingComparison,
        onQueueBillPost: queueBillPost,
        onQueueVendorPayment: queueVendorPayment,
        onFetchTaxLiability: fetchTaxLiabilityReport,
        onFetchTaxLiabilityComparison: fetchTaxLiabilityComparison,
        onFetchTaxSummary: fetchTaxSummaryReport,
        onFetchTaxSummaryComparison: fetchTaxSummaryComparison,
        onFetchBudgets: fetchBudgets,
        onFetchBudgetVsActual: fetchBudgetVsActual,
        onFetchBudgetVsActualComparison: fetchBudgetVsActualComparison,
        onSaveCsvExports: saveReportCsvExports,
        onShareCsvExports: shareReportCsvExports,
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

class PickedTextFile {
  const PickedTextFile({required this.fileName, required this.text});

  final String fileName;
  final String text;
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

Future<PickedTextFile?> pickTextFile() async {
  final result = await FilePicker.pickFiles(
    allowMultiple: false,
    type: FileType.custom,
    allowedExtensions: const ['csv', 'txt'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) {
    return null;
  }
  final file = result.files.single;
  final bytes = file.bytes ?? await File(file.path!).readAsBytes();
  return PickedTextFile(fileName: file.name, text: utf8.decode(bytes));
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

class InvoiceDraftInput {
  const InvoiceDraftInput({
    required this.customerId,
    required this.invoiceNumber,
    required this.issueDate,
    required this.dueDate,
    required this.accountsReceivableId,
    required this.description,
    required this.quantityMillis,
    required this.unitPriceMinor,
    required this.incomeAccountId,
    this.pdfAttachmentId = '',
    this.taxRateId = '',
    this.taxGroupId = '',
    this.taxInclusive = false,
  });

  final String customerId;
  final String invoiceNumber;
  final DateTime issueDate;
  final DateTime dueDate;
  final String accountsReceivableId;
  final String description;
  final int quantityMillis;
  final int unitPriceMinor;
  final String incomeAccountId;
  final String pdfAttachmentId;
  final String taxRateId;
  final String taxGroupId;
  final bool taxInclusive;
}

class CustomerPaymentInput {
  const CustomerPaymentInput({
    required this.invoiceId,
    required this.paymentNumber,
    required this.paymentDate,
    required this.amountMinor,
    required this.paymentAccountId,
    this.paymentMethod = '',
    this.reference = '',
  });

  final String invoiceId;
  final String paymentNumber;
  final DateTime paymentDate;
  final int amountMinor;
  final String paymentAccountId;
  final String paymentMethod;
  final String reference;
}

class VendorPaymentInput {
  const VendorPaymentInput({
    required this.billId,
    required this.paymentNumber,
    required this.paymentDate,
    required this.amountMinor,
    required this.paymentAccountId,
    this.paymentMethod = '',
    this.reference = '',
  });

  final String billId;
  final String paymentNumber;
  final DateTime paymentDate;
  final int amountMinor;
  final String paymentAccountId;
  final String paymentMethod;
  final String reference;
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

DateTime? parseIsoDateOnlyUtc(String value) {
  final parts = value.split('-');
  if (parts.length != 3) {
    return null;
  }
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) {
    return null;
  }
  return DateTime.utc(year, month, day);
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
    required this.customers,
    required this.attachments,
    required this.editingInvoiceDraft,
    required this.cachedBinaryAttachmentIds,
    required this.isLoading,
    required this.notice,
    required this.onFetchInvoices,
    required this.onQueueInvoiceDraft,
    required this.onQueueInvoiceDraftUpdate,
    required this.onQueueInvoicePost,
    required this.onQueueCustomerPayment,
    required this.onEditInvoiceDraft,
    required this.onCancelInvoiceDraftEdit,
    required this.onDownloadAttachment,
    required this.onInspectCachedAttachment,
    super.key,
  });

  final List<InvoiceSummary> invoices;
  final List<CustomerSummary> customers;
  final List<AttachmentSummary> attachments;
  final InvoiceSummary? editingInvoiceDraft;
  final Set<String> cachedBinaryAttachmentIds;
  final bool isLoading;
  final String? notice;
  final Future<void> Function() onFetchInvoices;
  final Future<void> Function(InvoiceDraftInput input) onQueueInvoiceDraft;
  final Future<void> Function(String invoiceId, InvoiceDraftInput input)
  onQueueInvoiceDraftUpdate;
  final Future<void> Function(String invoiceId) onQueueInvoicePost;
  final Future<void> Function(CustomerPaymentInput input)
  onQueueCustomerPayment;
  final ValueChanged<InvoiceSummary> onEditInvoiceDraft;
  final VoidCallback onCancelInvoiceDraftEdit;
  final Future<void> Function(AttachmentSummary attachment)
  onDownloadAttachment;
  final Future<void> Function(AttachmentSummary attachment)
  onInspectCachedAttachment;

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
        InvoiceDraftForm(
          customers: customers,
          attachments: attachments,
          editingInvoice: editingInvoiceDraft,
          onSubmit: onQueueInvoiceDraft,
          onUpdate: onQueueInvoiceDraftUpdate,
          onCancelEdit: onCancelInvoiceDraftEdit,
        ),
        InvoiceActionsCard(
          invoices: invoices,
          onQueueInvoicePost: onQueueInvoicePost,
          onQueueCustomerPayment: onQueueCustomerPayment,
        ),
        InvoiceCachePanel(
          invoices: invoices,
          attachments: attachments,
          cachedBinaryAttachmentIds: cachedBinaryAttachmentIds,
          onEditInvoiceDraft: onEditInvoiceDraft,
          onDownloadAttachment: onDownloadAttachment,
          onInspectCachedAttachment: onInspectCachedAttachment,
        ),
        if (notice != null) Text(notice!),
        const InfoList(
          items: [
            'Target API: GET /invoices',
            'Cached locally for read-only offline review',
            'New one-line invoice drafts queue offline through invoices.create_draft',
            'Cached draft invoices can prefill the form and queue updates through invoices.update_draft',
            'Cached invoice rows can queue posting and customer-payment actions for offline replay',
            'PDF attachment bytes can be downloaded and inspected from the invoice row when attachment metadata is present',
          ],
        ),
      ],
    );
  }
}

class InvoiceDraftForm extends StatefulWidget {
  const InvoiceDraftForm({
    required this.customers,
    required this.attachments,
    required this.editingInvoice,
    required this.onSubmit,
    required this.onUpdate,
    required this.onCancelEdit,
    super.key,
  });

  final List<CustomerSummary> customers;
  final List<AttachmentSummary> attachments;
  final InvoiceSummary? editingInvoice;
  final Future<void> Function(InvoiceDraftInput input) onSubmit;
  final Future<void> Function(String invoiceId, InvoiceDraftInput input)
  onUpdate;
  final VoidCallback onCancelEdit;

  @override
  State<InvoiceDraftForm> createState() => _InvoiceDraftFormState();
}

class _InvoiceDraftFormState extends State<InvoiceDraftForm> {
  late final TextEditingController customerIdController;
  late final TextEditingController invoiceNumberController;
  late final TextEditingController issueDateController;
  late final TextEditingController dueDateController;
  late final TextEditingController accountsReceivableController;
  late final TextEditingController descriptionController;
  late final TextEditingController quantityMillisController;
  late final TextEditingController unitPriceController;
  late final TextEditingController incomeAccountController;
  late final TextEditingController pdfAttachmentController;
  late final TextEditingController taxRateController;
  late final TextEditingController taxGroupController;
  bool taxInclusive = false;
  bool isQueueing = false;
  String? validationMessage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    customerIdController = TextEditingController();
    invoiceNumberController = TextEditingController(
      text: 'INV-MOB-${now.millisecondsSinceEpoch}',
    );
    issueDateController = TextEditingController(text: formatDateOnly(now));
    dueDateController = TextEditingController(
      text: formatDateOnly(now.add(const Duration(days: 30))),
    );
    accountsReceivableController = TextEditingController();
    descriptionController = TextEditingController(text: 'Mobile invoice line');
    quantityMillisController = TextEditingController(text: '1000');
    unitPriceController = TextEditingController(text: '0.00');
    incomeAccountController = TextEditingController();
    pdfAttachmentController = TextEditingController();
    taxRateController = TextEditingController();
    taxGroupController = TextEditingController();
    applyInvoice(widget.editingInvoice);
  }

  @override
  void didUpdateWidget(covariant InvoiceDraftForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editingInvoice?.id != widget.editingInvoice?.id) {
      applyInvoice(widget.editingInvoice);
    }
  }

  @override
  void dispose() {
    customerIdController.dispose();
    invoiceNumberController.dispose();
    issueDateController.dispose();
    dueDateController.dispose();
    accountsReceivableController.dispose();
    descriptionController.dispose();
    quantityMillisController.dispose();
    unitPriceController.dispose();
    incomeAccountController.dispose();
    pdfAttachmentController.dispose();
    taxRateController.dispose();
    taxGroupController.dispose();
    super.dispose();
  }

  int parseRupeesToPaise(String value) {
    final normalized = value.trim().replaceAll(',', '');
    if (normalized.isEmpty) {
      return 0;
    }
    final rupees = double.tryParse(normalized) ?? 0;
    return (rupees * 100).round();
  }

  void onTaxRateChanged(String value) {
    if (value.trim().isEmpty || taxGroupController.text.isEmpty) {
      return;
    }
    taxGroupController.clear();
    setState(() {
      validationMessage = 'Using tax rate; tax group cleared.';
    });
  }

  void onTaxGroupChanged(String value) {
    if (value.trim().isEmpty || taxRateController.text.isEmpty) {
      return;
    }
    taxRateController.clear();
    setState(() {
      validationMessage = 'Using tax group; tax rate cleared.';
    });
  }

  void applyInvoice(InvoiceSummary? invoice) {
    if (invoice == null) {
      final now = DateTime.now();
      customerIdController.clear();
      invoiceNumberController.text = 'INV-MOB-${now.millisecondsSinceEpoch}';
      issueDateController.text = formatDateOnly(now);
      dueDateController.text = formatDateOnly(
        now.add(const Duration(days: 30)),
      );
      accountsReceivableController.clear();
      descriptionController.text = 'Mobile invoice line';
      quantityMillisController.text = '1000';
      unitPriceController.text = '0.00';
      incomeAccountController.clear();
      pdfAttachmentController.clear();
      taxRateController.clear();
      taxGroupController.clear();
      setState(() {
        taxInclusive = false;
        validationMessage = null;
      });
      return;
    }

    final firstLine = invoice.lines.isEmpty ? null : invoice.lines.first;
    invoiceNumberController.text = invoice.invoiceNumber;
    descriptionController.text =
        firstLine?.description ?? 'Mobile invoice line';
    quantityMillisController.text = (firstLine?.quantityMillis ?? 1000)
        .toString();
    unitPriceController.text = formatMinorAsInput(
      firstLine?.unitPriceMinor ?? invoice.subtotalMinor,
    );
    incomeAccountController.text = firstLine?.incomeAccountId ?? '';
    pdfAttachmentController.text = invoice.pdfAttachmentId ?? '';
    taxGroupController.text = firstLine?.taxGroupId ?? '';
    taxRateController.text = firstLine?.taxGroupId == null
        ? firstLine?.taxRateId ?? ''
        : '';
    setState(() {
      taxInclusive = false;
      validationMessage =
          'Editing ${invoice.invoiceNumber}. Add customer and AR account IDs before queueing.';
    });
  }

  Future<void> queueDraft() async {
    if (isQueueing) {
      return;
    }
    final issueDate = parseIsoDateOnlyUtc(issueDateController.text.trim());
    final dueDate = parseIsoDateOnlyUtc(dueDateController.text.trim());
    final quantityMillis = int.tryParse(quantityMillisController.text.trim());
    final unitPriceMinor = parseRupeesToPaise(unitPriceController.text);
    final taxRateId = taxRateController.text.trim();
    final taxGroupId = taxGroupController.text.trim();

    if (customerIdController.text.trim().isEmpty ||
        accountsReceivableController.text.trim().isEmpty ||
        incomeAccountController.text.trim().isEmpty ||
        issueDate == null ||
        dueDate == null ||
        quantityMillis == null ||
        quantityMillis <= 0 ||
        unitPriceMinor <= 0) {
      setState(() {
        validationMessage =
            'Enter customer ID, AR account, income account, valid dates, quantity, and unit price.';
      });
      return;
    }
    if (taxRateId.isNotEmpty && taxGroupId.isNotEmpty) {
      setState(() {
        validationMessage = 'Use either tax rate ID or tax group ID, not both.';
      });
      return;
    }

    setState(() {
      isQueueing = true;
      validationMessage = null;
    });
    try {
      final input = InvoiceDraftInput(
        customerId: customerIdController.text.trim(),
        invoiceNumber: invoiceNumberController.text.trim(),
        issueDate: issueDate,
        dueDate: dueDate,
        accountsReceivableId: accountsReceivableController.text.trim(),
        description: descriptionController.text.trim(),
        quantityMillis: quantityMillis,
        unitPriceMinor: unitPriceMinor,
        incomeAccountId: incomeAccountController.text.trim(),
        pdfAttachmentId: pdfAttachmentController.text.trim(),
        taxRateId: taxRateId,
        taxGroupId: taxGroupId,
        taxInclusive: taxInclusive,
      );
      final editingInvoice = widget.editingInvoice;
      if (editingInvoice == null) {
        await widget.onSubmit(input);
      } else {
        await widget.onUpdate(editingInvoice.id, input);
      }
    } finally {
      if (mounted) {
        setState(() {
          isQueueing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pdfAttachments = widget.attachments
        .where((attachment) => attachment.contentType == 'application/pdf')
        .take(5)
        .toList(growable: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.editingInvoice == null
                  ? 'Draft invoice'
                  : 'Edit draft invoice',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Queue a one-line invoice draft offline. It will sync to the shared Go API when credentials are available.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: customerIdController,
              decoration: const InputDecoration(
                labelText: 'Invoice customer ID',
              ),
            ),
            if (widget.customers.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Cached customers',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final customer in widget.customers.take(6))
                    ActionChip(
                      label: Text('${customer.displayName} · ${customer.id}'),
                      onPressed: () {
                        customerIdController.text = customer.id;
                      },
                    ),
                ],
              ),
            ],
            TextField(
              controller: invoiceNumberController,
              decoration: const InputDecoration(labelText: 'Invoice number'),
            ),
            TextField(
              controller: issueDateController,
              decoration: const InputDecoration(
                labelText: 'Issue date',
                hintText: '2026-07-16',
              ),
            ),
            TextField(
              controller: dueDateController,
              decoration: const InputDecoration(
                labelText: 'Due date',
                hintText: '2026-08-15',
              ),
            ),
            TextField(
              controller: accountsReceivableController,
              decoration: const InputDecoration(
                labelText: 'Accounts receivable account ID',
              ),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Line description'),
            ),
            TextField(
              controller: quantityMillisController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity millis',
                helperText: '1000 = 1 unit',
              ),
            ),
            TextField(
              controller: unitPriceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Unit price in INR'),
            ),
            TextField(
              controller: incomeAccountController,
              decoration: const InputDecoration(labelText: 'Income account ID'),
            ),
            TextField(
              controller: pdfAttachmentController,
              decoration: const InputDecoration(
                labelText: 'PDF attachment ID',
                helperText: 'Optional cached PDF metadata ID.',
              ),
            ),
            if (pdfAttachments.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Cached PDF attachments',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final attachment in pdfAttachments)
                    ActionChip(
                      label: Text('${attachment.fileName} · ${attachment.id}'),
                      onPressed: () {
                        pdfAttachmentController.text = attachment.id;
                      },
                    ),
                ],
              ),
            ],
            TextField(
              controller: taxRateController,
              onChanged: onTaxRateChanged,
              decoration: const InputDecoration(labelText: 'Tax rate ID'),
            ),
            TextField(
              controller: taxGroupController,
              onChanged: onTaxGroupChanged,
              decoration: const InputDecoration(labelText: 'Tax group ID'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tax inclusive invoice line'),
              value: taxInclusive,
              onChanged: (value) {
                setState(() {
                  taxInclusive = value;
                });
              },
            ),
            if (validationMessage != null) Text(validationMessage!),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isQueueing ? null : queueDraft,
              icon: const Icon(Icons.note_add_outlined),
              label: Text(
                isQueueing
                    ? 'Queueing invoice...'
                    : widget.editingInvoice == null
                    ? 'Queue invoice draft'
                    : 'Queue invoice update',
              ),
            ),
            if (widget.editingInvoice != null)
              TextButton.icon(
                onPressed: widget.onCancelEdit,
                icon: const Icon(Icons.close),
                label: const Text('Cancel invoice edit'),
              ),
          ],
        ),
      ),
    );
  }
}

class InvoiceActionsCard extends StatefulWidget {
  const InvoiceActionsCard({
    required this.invoices,
    required this.onQueueInvoicePost,
    required this.onQueueCustomerPayment,
    super.key,
  });

  final List<InvoiceSummary> invoices;
  final Future<void> Function(String invoiceId) onQueueInvoicePost;
  final Future<void> Function(CustomerPaymentInput input)
  onQueueCustomerPayment;

  @override
  State<InvoiceActionsCard> createState() => _InvoiceActionsCardState();
}

class _InvoiceActionsCardState extends State<InvoiceActionsCard> {
  late final TextEditingController invoiceIdController;
  late final TextEditingController paymentNumberController;
  late final TextEditingController paymentDateController;
  late final TextEditingController amountController;
  late final TextEditingController paymentAccountController;
  late final TextEditingController paymentMethodController;
  late final TextEditingController referenceController;
  String? validationMessage;
  bool isQueueing = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    invoiceIdController = TextEditingController();
    paymentNumberController = TextEditingController(
      text: 'PAY-MOB-${now.millisecondsSinceEpoch}',
    );
    paymentDateController = TextEditingController(text: formatDateOnly(now));
    amountController = TextEditingController(text: '0.00');
    paymentAccountController = TextEditingController();
    paymentMethodController = TextEditingController(text: 'upi');
    referenceController = TextEditingController();
  }

  @override
  void dispose() {
    invoiceIdController.dispose();
    paymentNumberController.dispose();
    paymentDateController.dispose();
    amountController.dispose();
    paymentAccountController.dispose();
    paymentMethodController.dispose();
    referenceController.dispose();
    super.dispose();
  }

  int parseRupeesToPaise(String value) {
    final normalized = value.trim().replaceAll(',', '');
    if (normalized.isEmpty) {
      return 0;
    }
    final rupees = double.tryParse(normalized) ?? 0;
    return (rupees * 100).round();
  }

  void applyInvoice(InvoiceSummary invoice) {
    invoiceIdController.text = invoice.id;
    amountController.text = formatMinorAsInput(invoice.totalMinor);
    setState(() {
      validationMessage = 'Selected ${invoice.invoiceNumber}.';
    });
  }

  Future<void> queueInvoicePost() async {
    final invoiceId = invoiceIdController.text.trim();
    if (invoiceId.isEmpty) {
      setState(() {
        validationMessage = 'Select or enter an invoice ID before posting.';
      });
      return;
    }
    await widget.onQueueInvoicePost(invoiceId);
  }

  Future<void> queuePayment() async {
    if (isQueueing) {
      return;
    }
    final paymentDate = parseIsoDateOnlyUtc(paymentDateController.text.trim());
    final amountMinor = parseRupeesToPaise(amountController.text);
    if (invoiceIdController.text.trim().isEmpty ||
        paymentNumberController.text.trim().isEmpty ||
        paymentAccountController.text.trim().isEmpty ||
        paymentDate == null ||
        amountMinor <= 0) {
      setState(() {
        validationMessage =
            'Enter invoice ID, payment number, payment date, amount, and payment account ID.';
      });
      return;
    }

    setState(() {
      isQueueing = true;
      validationMessage = null;
    });
    try {
      await widget.onQueueCustomerPayment(
        CustomerPaymentInput(
          invoiceId: invoiceIdController.text.trim(),
          paymentNumber: paymentNumberController.text.trim(),
          paymentDate: paymentDate,
          amountMinor: amountMinor,
          paymentAccountId: paymentAccountController.text.trim(),
          paymentMethod: paymentMethodController.text.trim(),
          reference: referenceController.text.trim(),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isQueueing = false;
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
              'Invoice actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Queue posting or customer-payment actions against cached invoices while offline.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: invoiceIdController,
              decoration: const InputDecoration(labelText: 'Action invoice ID'),
            ),
            if (widget.invoices.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Cached invoice actions',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final invoice in widget.invoices.take(6))
                    ActionChip(
                      label: Text('${invoice.invoiceNumber} · ${invoice.id}'),
                      onPressed: () => applyInvoice(invoice),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: queueInvoicePost,
              icon: const Icon(Icons.publish_outlined),
              label: const Text('Queue invoice posting'),
            ),
            const Divider(height: 28),
            TextField(
              controller: paymentNumberController,
              decoration: const InputDecoration(labelText: 'Payment number'),
            ),
            TextField(
              controller: paymentDateController,
              decoration: const InputDecoration(
                labelText: 'Payment date',
                hintText: '2026-07-17',
              ),
            ),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Payment amount in INR',
              ),
            ),
            TextField(
              controller: paymentAccountController,
              decoration: const InputDecoration(
                labelText: 'Payment account ID',
              ),
            ),
            TextField(
              controller: paymentMethodController,
              decoration: const InputDecoration(
                labelText: 'Payment method',
                helperText: 'Optional, for example upi, bank_transfer, cash.',
              ),
            ),
            TextField(
              controller: referenceController,
              decoration: const InputDecoration(labelText: 'Payment reference'),
            ),
            if (validationMessage != null) Text(validationMessage!),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isQueueing ? null : queuePayment,
              icon: const Icon(Icons.payments_outlined),
              label: Text(
                isQueueing ? 'Queueing payment...' : 'Queue customer payment',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InvoiceCachePanel extends StatelessWidget {
  const InvoiceCachePanel({
    required this.invoices,
    required this.attachments,
    required this.cachedBinaryAttachmentIds,
    required this.onEditInvoiceDraft,
    required this.onDownloadAttachment,
    required this.onInspectCachedAttachment,
    super.key,
  });

  final List<InvoiceSummary> invoices;
  final List<AttachmentSummary> attachments;
  final Set<String> cachedBinaryAttachmentIds;
  final ValueChanged<InvoiceSummary> onEditInvoiceDraft;
  final Future<void> Function(AttachmentSummary attachment)
  onDownloadAttachment;
  final Future<void> Function(AttachmentSummary attachment)
  onInspectCachedAttachment;

  AttachmentSummary _invoicePdfAttachment(InvoiceSummary invoice) {
    final pdfAttachmentId = invoice.pdfAttachmentId;
    for (final attachment in attachments) {
      if (attachment.id == pdfAttachmentId) {
        return attachment;
      }
    }
    return AttachmentSummary(
      id: pdfAttachmentId ?? '',
      fileName: '${invoice.invoiceNumber}.pdf',
      contentType: 'application/pdf',
      storageDriver: 'local',
      storageKey: 'invoice-pdf/${invoice.id}',
      sizeBytes: 0,
    );
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
                          if (invoice.pdfAttachmentId != null) ...[
                            const SizedBox(height: 8),
                            SelectableText(
                              'PDF attachment: ${invoice.pdfAttachmentId}',
                            ),
                            Text(
                              cachedBinaryAttachmentIds.contains(
                                    invoice.pdfAttachmentId,
                                  )
                                  ? 'Invoice PDF: available offline'
                                  : 'Invoice PDF: not downloaded',
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => onDownloadAttachment(
                                    _invoicePdfAttachment(invoice),
                                  ),
                                  icon: const Icon(Icons.picture_as_pdf),
                                  label: const Text('Download PDF'),
                                ),
                                if (cachedBinaryAttachmentIds.contains(
                                  invoice.pdfAttachmentId,
                                ))
                                  TextButton.icon(
                                    onPressed: () => onInspectCachedAttachment(
                                      _invoicePdfAttachment(invoice),
                                    ),
                                    icon: const Icon(Icons.visibility),
                                    label: const Text('Inspect PDF'),
                                  ),
                              ],
                            ),
                          ],
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
                          if (invoice.status == 'draft') ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => onEditInvoiceDraft(invoice),
                              icon: const Icon(Icons.edit_note_outlined),
                              label: const Text('Edit draft invoice'),
                            ),
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
    required this.onQueueInvestmentLot,
    required this.onQueueInvestmentPrice,
    required this.onQueueAverageCostSale,
    required this.onQueueInvestmentLotSale,
    required this.onQueueInvestmentDividend,
    required this.onQueueInvestmentCorporateAction,
    required this.onQueueBrokerHoldingsImport,
    required this.onPickBrokerHoldingsCSV,
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
  final Future<void> Function({
    required String accountId,
    required String symbol,
    required String securityName,
    required DateTime acquisitionDate,
    required int quantityMillis,
    required int costBasisMinor,
    required String costMethod,
    required String notes,
  })
  onQueueInvestmentLot;
  final Future<void> Function({
    required String symbol,
    required DateTime priceDate,
    required int priceMinor,
    required String source,
  })
  onQueueInvestmentPrice;
  final Future<void> Function({
    required String accountId,
    required String symbol,
    required DateTime saleDate,
    required int quantityMillis,
    required int proceedsMinor,
    required String proceedsAccountId,
    required String gainLossAccountId,
    required String notes,
  })
  onQueueAverageCostSale;
  final Future<void> Function({
    required String lotId,
    required DateTime saleDate,
    required int quantityMillis,
    required int proceedsMinor,
    required String proceedsAccountId,
    required String gainLossAccountId,
    required String notes,
  })
  onQueueInvestmentLotSale;
  final Future<void> Function({
    required String accountId,
    required String symbol,
    required DateTime dividendDate,
    required int amountMinor,
    required String cashAccountId,
    required String incomeAccountId,
    required String notes,
  })
  onQueueInvestmentDividend;
  final Future<void> Function({
    required String accountId,
    required String symbol,
    required String actionType,
    required DateTime actionDate,
    required int ratioNumerator,
    required int ratioDenominator,
    required String notes,
  })
  onQueueInvestmentCorporateAction;
  final Future<void> Function(String csv, String source)
  onQueueBrokerHoldingsImport;
  final Future<PickedTextFile?> Function() onPickBrokerHoldingsCSV;

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
              'Review cached investment lots, queue broker holdings price imports, and fetch reports for tax-season checks while offline-first.',
          actionLabel: isLoading ? 'Refreshing investments...' : 'Refresh lots',
          onPressed: isLoading ? null : () => onFetchLots(),
        ),
        InvestmentLotCreateCard(onQueueLot: onQueueInvestmentLot),
        ManualInvestmentPriceCard(onQueuePrice: onQueueInvestmentPrice),
        InvestmentDividendCard(onQueueDividend: onQueueInvestmentDividend),
        InvestmentCorporateActionCard(
          onQueueAction: onQueueInvestmentCorporateAction,
        ),
        SpecificLotSaleCard(onQueueSale: onQueueInvestmentLotSale),
        AverageCostSaleCard(onQueueSale: onQueueAverageCostSale),
        BrokerHoldingsImportCard(
          onQueueImport: onQueueBrokerHoldingsImport,
          onPickCSV: onPickBrokerHoldingsCSV,
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
            'Target APIs: GET /investments/lots, POST /investments/prices/import/broker-holdings, GET /reports/realized-gains, and GET /reports/investment-valuation',
            'Lots, manual market prices, dividends, corporate actions, specific-lot sales, average-cost sales, and broker holdings CSV imports queue offline and replay through the shared sync coordinator',
          ],
        ),
      ],
    );
  }
}

class InvestmentLotCreateCard extends StatefulWidget {
  const InvestmentLotCreateCard({required this.onQueueLot, super.key});

  final Future<void> Function({
    required String accountId,
    required String symbol,
    required String securityName,
    required DateTime acquisitionDate,
    required int quantityMillis,
    required int costBasisMinor,
    required String costMethod,
    required String notes,
  })
  onQueueLot;

  @override
  State<InvestmentLotCreateCard> createState() =>
      _InvestmentLotCreateCardState();
}

class _InvestmentLotCreateCardState extends State<InvestmentLotCreateCard> {
  late final TextEditingController accountIdController;
  late final TextEditingController symbolController;
  late final TextEditingController securityNameController;
  late final TextEditingController acquisitionDateController;
  late final TextEditingController quantityMillisController;
  late final TextEditingController costBasisMinorController;
  late final TextEditingController notesController;
  String costMethod = 'specific_lot';
  bool isQueueing = false;
  String? validationError;

  @override
  void initState() {
    super.initState();
    accountIdController = TextEditingController(text: 'brokerage-account-id');
    symbolController = TextEditingController(text: 'NIFTYBEES');
    securityNameController = TextEditingController(text: 'Nifty BeES');
    acquisitionDateController = TextEditingController(
      text: formatDateOnly(DateTime.now()),
    );
    quantityMillisController = TextEditingController(text: '1000');
    costBasisMinorController = TextEditingController(text: '14000');
    notesController = TextEditingController(text: 'Offline lot capture');
  }

  @override
  void dispose() {
    accountIdController.dispose();
    symbolController.dispose();
    securityNameController.dispose();
    acquisitionDateController.dispose();
    quantityMillisController.dispose();
    costBasisMinorController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> queueLot() async {
    if (isQueueing) {
      return;
    }
    final accountId = accountIdController.text.trim();
    final symbol = symbolController.text.trim().toUpperCase();
    final acquisitionDate = parseIsoDateOnlyUtc(
      acquisitionDateController.text.trim(),
    );
    final quantityMillis = int.tryParse(quantityMillisController.text.trim());
    final costBasisMinor = int.tryParse(costBasisMinorController.text.trim());

    if (accountId.isEmpty ||
        symbol.isEmpty ||
        acquisitionDate == null ||
        quantityMillis == null ||
        costBasisMinor == null) {
      setState(() {
        validationError =
            'Enter account ID, symbol, ISO date, quantity millis, and cost basis minor.';
      });
      return;
    }
    if (quantityMillis <= 0 || costBasisMinor <= 0) {
      setState(() {
        validationError =
            'Quantity millis and cost basis minor must be greater than zero.';
      });
      return;
    }

    setState(() {
      isQueueing = true;
      validationError = null;
    });
    try {
      await widget.onQueueLot(
        accountId: accountId,
        symbol: symbol,
        securityName: securityNameController.text.trim(),
        acquisitionDate: acquisitionDate,
        quantityMillis: quantityMillis,
        costBasisMinor: costBasisMinor,
        costMethod: costMethod,
        notes: notesController.text.trim(),
      );
    } finally {
      if (mounted) {
        setState(() {
          isQueueing = false;
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
              'Investment lot',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a holding lot while offline. Quantity uses millis, so 2.5 units is entered as 2500.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: accountIdController,
              decoration: const InputDecoration(
                labelText: 'Lot account ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: symbolController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Lot symbol',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: securityNameController,
              decoration: const InputDecoration(
                labelText: 'Lot security name optional',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: acquisitionDateController,
              decoration: const InputDecoration(
                labelText: 'Lot acquisition date',
                hintText: '2026-07-31',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: quantityMillisController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Lot quantity millis',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: costBasisMinorController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Lot cost basis minor',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: costMethod,
              decoration: const InputDecoration(
                labelText: 'Lot cost method',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'specific_lot',
                  child: Text('Specific lot'),
                ),
                DropdownMenuItem(
                  value: 'average_cost',
                  child: Text('Average cost'),
                ),
              ],
              onChanged: isQueueing
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          costMethod = value;
                        });
                      }
                    },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Lot notes optional',
                border: OutlineInputBorder(),
              ),
            ),
            if (validationError != null) ...[
              const SizedBox(height: 8),
              Text(
                validationError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isQueueing ? null : queueLot,
              icon: const Icon(Icons.add_chart_outlined),
              label: Text(
                isQueueing
                    ? 'Queueing investment lot...'
                    : 'Queue investment lot',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ManualInvestmentPriceCard extends StatefulWidget {
  const ManualInvestmentPriceCard({required this.onQueuePrice, super.key});

  final Future<void> Function({
    required String symbol,
    required DateTime priceDate,
    required int priceMinor,
    required String source,
  })
  onQueuePrice;

  @override
  State<ManualInvestmentPriceCard> createState() =>
      _ManualInvestmentPriceCardState();
}

class _ManualInvestmentPriceCardState extends State<ManualInvestmentPriceCard> {
  late final TextEditingController symbolController;
  late final TextEditingController priceDateController;
  late final TextEditingController priceMinorController;
  late final TextEditingController sourceController;
  bool isQueueing = false;
  String? validationError;

  @override
  void initState() {
    super.initState();
    symbolController = TextEditingController(text: 'NIFTYBEES');
    priceDateController = TextEditingController(
      text: formatDateOnly(DateTime.now()),
    );
    priceMinorController = TextEditingController(text: '14000');
    sourceController = TextEditingController(text: 'mobile-offline');
  }

  @override
  void dispose() {
    symbolController.dispose();
    priceDateController.dispose();
    priceMinorController.dispose();
    sourceController.dispose();
    super.dispose();
  }

  Future<void> queuePrice() async {
    if (isQueueing) {
      return;
    }
    final symbol = symbolController.text.trim().toUpperCase();
    final priceDate = parseIsoDateOnlyUtc(priceDateController.text.trim());
    final priceMinor = int.tryParse(priceMinorController.text.trim());
    final source = sourceController.text.trim().isEmpty
        ? 'mobile-offline'
        : sourceController.text.trim();

    if (symbol.isEmpty || priceDate == null || priceMinor == null) {
      setState(() {
        validationError =
            'Enter a symbol, ISO date like 2026-07-31, and price in minor units.';
      });
      return;
    }
    if (priceMinor <= 0) {
      setState(() {
        validationError = 'Price minor must be greater than zero.';
      });
      return;
    }

    setState(() {
      isQueueing = true;
      validationError = null;
    });
    try {
      await widget.onQueuePrice(
        symbol: symbol,
        priceDate: priceDate,
        priceMinor: priceMinor,
        source: source,
      );
    } finally {
      if (mounted) {
        setState(() {
          isQueueing = false;
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
              'Manual investment price',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Capture a single security price while offline. Values use minor currency units so INR 1720.35 is entered as 172035.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: symbolController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Price symbol',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceDateController,
              decoration: const InputDecoration(
                labelText: 'Price date',
                hintText: '2026-07-31',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceMinorController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Price minor',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: sourceController,
              decoration: const InputDecoration(
                labelText: 'Price source',
                border: OutlineInputBorder(),
              ),
            ),
            if (validationError != null) ...[
              const SizedBox(height: 8),
              Text(
                validationError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isQueueing ? null : queuePrice,
              icon: const Icon(Icons.price_change_outlined),
              label: Text(
                isQueueing
                    ? 'Queueing investment price...'
                    : 'Queue investment price',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InvestmentDividendCard extends StatefulWidget {
  const InvestmentDividendCard({required this.onQueueDividend, super.key});

  final Future<void> Function({
    required String accountId,
    required String symbol,
    required DateTime dividendDate,
    required int amountMinor,
    required String cashAccountId,
    required String incomeAccountId,
    required String notes,
  })
  onQueueDividend;

  @override
  State<InvestmentDividendCard> createState() => _InvestmentDividendCardState();
}

class _InvestmentDividendCardState extends State<InvestmentDividendCard> {
  late final TextEditingController accountIdController;
  late final TextEditingController symbolController;
  late final TextEditingController dividendDateController;
  late final TextEditingController amountMinorController;
  late final TextEditingController cashAccountIdController;
  late final TextEditingController incomeAccountIdController;
  late final TextEditingController notesController;
  bool isQueueing = false;
  String? validationError;

  @override
  void initState() {
    super.initState();
    accountIdController = TextEditingController(text: 'brokerage-account-id');
    symbolController = TextEditingController(text: 'NIFTYBEES');
    dividendDateController = TextEditingController(
      text: formatDateOnly(DateTime.now()),
    );
    amountMinorController = TextEditingController(text: '2500');
    cashAccountIdController = TextEditingController();
    incomeAccountIdController = TextEditingController();
    notesController = TextEditingController(text: 'Offline dividend capture');
  }

  @override
  void dispose() {
    accountIdController.dispose();
    symbolController.dispose();
    dividendDateController.dispose();
    amountMinorController.dispose();
    cashAccountIdController.dispose();
    incomeAccountIdController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> queueDividend() async {
    if (isQueueing) {
      return;
    }
    final accountId = accountIdController.text.trim();
    final symbol = symbolController.text.trim().toUpperCase();
    final dividendDate = parseIsoDateOnlyUtc(
      dividendDateController.text.trim(),
    );
    final amountMinor = int.tryParse(amountMinorController.text.trim());

    if (accountId.isEmpty ||
        symbol.isEmpty ||
        dividendDate == null ||
        amountMinor == null) {
      setState(() {
        validationError =
            'Enter account ID, symbol, ISO date, and dividend amount in minor units.';
      });
      return;
    }
    if (amountMinor <= 0) {
      setState(() {
        validationError = 'Dividend amount minor must be greater than zero.';
      });
      return;
    }

    setState(() {
      isQueueing = true;
      validationError = null;
    });
    try {
      await widget.onQueueDividend(
        accountId: accountId,
        symbol: symbol,
        dividendDate: dividendDate,
        amountMinor: amountMinor,
        cashAccountId: cashAccountIdController.text.trim(),
        incomeAccountId: incomeAccountIdController.text.trim(),
        notes: notesController.text.trim(),
      );
    } finally {
      if (mounted) {
        setState(() {
          isQueueing = false;
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
              'Investment dividend',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Capture dividend income while offline. Optional cash and income account IDs let the API post the GL entry when synced.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: accountIdController,
              decoration: const InputDecoration(
                labelText: 'Dividend account ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: symbolController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Dividend symbol',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dividendDateController,
              decoration: const InputDecoration(
                labelText: 'Dividend date',
                hintText: '2026-07-31',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountMinorController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Dividend amount minor',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cashAccountIdController,
              decoration: const InputDecoration(
                labelText: 'Dividend cash account ID optional',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: incomeAccountIdController,
              decoration: const InputDecoration(
                labelText: 'Dividend income account ID optional',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Dividend notes optional',
                border: OutlineInputBorder(),
              ),
            ),
            if (validationError != null) ...[
              const SizedBox(height: 8),
              Text(
                validationError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isQueueing ? null : queueDividend,
              icon: const Icon(Icons.payments_outlined),
              label: Text(
                isQueueing
                    ? 'Queueing investment dividend...'
                    : 'Queue investment dividend',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InvestmentCorporateActionCard extends StatefulWidget {
  const InvestmentCorporateActionCard({required this.onQueueAction, super.key});

  final Future<void> Function({
    required String accountId,
    required String symbol,
    required String actionType,
    required DateTime actionDate,
    required int ratioNumerator,
    required int ratioDenominator,
    required String notes,
  })
  onQueueAction;

  @override
  State<InvestmentCorporateActionCard> createState() =>
      _InvestmentCorporateActionCardState();
}

class _InvestmentCorporateActionCardState
    extends State<InvestmentCorporateActionCard> {
  late final TextEditingController accountIdController;
  late final TextEditingController symbolController;
  late final TextEditingController actionDateController;
  late final TextEditingController ratioNumeratorController;
  late final TextEditingController ratioDenominatorController;
  late final TextEditingController notesController;
  String actionType = 'split';
  bool isQueueing = false;
  String? validationError;

  @override
  void initState() {
    super.initState();
    accountIdController = TextEditingController(text: 'brokerage-account-id');
    symbolController = TextEditingController(text: 'NIFTYBEES');
    actionDateController = TextEditingController(
      text: formatDateOnly(DateTime.now()),
    );
    ratioNumeratorController = TextEditingController(text: '2');
    ratioDenominatorController = TextEditingController(text: '1');
    notesController = TextEditingController(text: 'Offline split capture');
  }

  @override
  void dispose() {
    accountIdController.dispose();
    symbolController.dispose();
    actionDateController.dispose();
    ratioNumeratorController.dispose();
    ratioDenominatorController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> queueAction() async {
    if (isQueueing) {
      return;
    }
    final accountId = accountIdController.text.trim();
    final symbol = symbolController.text.trim().toUpperCase();
    final actionDate = parseIsoDateOnlyUtc(actionDateController.text.trim());
    final ratioNumerator = int.tryParse(ratioNumeratorController.text.trim());
    final ratioDenominator = int.tryParse(
      ratioDenominatorController.text.trim(),
    );

    if (accountId.isEmpty ||
        symbol.isEmpty ||
        actionDate == null ||
        ratioNumerator == null ||
        ratioDenominator == null) {
      setState(() {
        validationError =
            'Enter account ID, symbol, ISO date, numerator, and denominator.';
      });
      return;
    }
    if (ratioNumerator <= 0 || ratioDenominator <= 0) {
      setState(() {
        validationError = 'Ratio numerator and denominator must be positive.';
      });
      return;
    }

    setState(() {
      isQueueing = true;
      validationError = null;
    });
    try {
      await widget.onQueueAction(
        accountId: accountId,
        symbol: symbol,
        actionType: actionType,
        actionDate: actionDate,
        ratioNumerator: ratioNumerator,
        ratioDenominator: ratioDenominator,
        notes: notesController.text.trim(),
      );
    } finally {
      if (mounted) {
        setState(() {
          isQueueing = false;
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
              'Corporate action',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Queue split or bonus actions while offline. The API applies the ratio across matching lots when synced.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: accountIdController,
              decoration: const InputDecoration(
                labelText: 'Corporate action account ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: symbolController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Corporate action symbol',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: actionType,
              decoration: const InputDecoration(
                labelText: 'Corporate action type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'split', child: Text('Split')),
                DropdownMenuItem(value: 'bonus', child: Text('Bonus')),
              ],
              onChanged: isQueueing
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          actionType = value;
                        });
                      }
                    },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: actionDateController,
              decoration: const InputDecoration(
                labelText: 'Corporate action date',
                hintText: '2026-07-31',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ratioNumeratorController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Corporate action ratio numerator',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ratioDenominatorController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Corporate action ratio denominator',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Corporate action notes optional',
                border: OutlineInputBorder(),
              ),
            ),
            if (validationError != null) ...[
              const SizedBox(height: 8),
              Text(
                validationError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isQueueing ? null : queueAction,
              icon: const Icon(Icons.call_split_outlined),
              label: Text(
                isQueueing
                    ? 'Queueing corporate action...'
                    : 'Queue corporate action',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SpecificLotSaleCard extends StatefulWidget {
  const SpecificLotSaleCard({required this.onQueueSale, super.key});

  final Future<void> Function({
    required String lotId,
    required DateTime saleDate,
    required int quantityMillis,
    required int proceedsMinor,
    required String proceedsAccountId,
    required String gainLossAccountId,
    required String notes,
  })
  onQueueSale;

  @override
  State<SpecificLotSaleCard> createState() => _SpecificLotSaleCardState();
}

class _SpecificLotSaleCardState extends State<SpecificLotSaleCard> {
  late final TextEditingController lotIdController;
  late final TextEditingController saleDateController;
  late final TextEditingController quantityMillisController;
  late final TextEditingController proceedsMinorController;
  late final TextEditingController proceedsAccountIdController;
  late final TextEditingController gainLossAccountIdController;
  late final TextEditingController notesController;
  bool isQueueing = false;
  String? validationError;

  @override
  void initState() {
    super.initState();
    lotIdController = TextEditingController(text: 'investment-lot-id');
    saleDateController = TextEditingController(
      text: formatDateOnly(DateTime.now()),
    );
    quantityMillisController = TextEditingController(text: '1000');
    proceedsMinorController = TextEditingController(text: '14000');
    proceedsAccountIdController = TextEditingController();
    gainLossAccountIdController = TextEditingController();
    notesController = TextEditingController(text: 'Offline specific-lot sale');
  }

  @override
  void dispose() {
    lotIdController.dispose();
    saleDateController.dispose();
    quantityMillisController.dispose();
    proceedsMinorController.dispose();
    proceedsAccountIdController.dispose();
    gainLossAccountIdController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> queueSale() async {
    if (isQueueing) {
      return;
    }
    final lotId = lotIdController.text.trim();
    final saleDate = parseIsoDateOnlyUtc(saleDateController.text.trim());
    final quantityMillis = int.tryParse(quantityMillisController.text.trim());
    final proceedsMinor = int.tryParse(proceedsMinorController.text.trim());

    if (lotId.isEmpty ||
        saleDate == null ||
        quantityMillis == null ||
        proceedsMinor == null) {
      setState(() {
        validationError =
            'Enter lot ID, ISO date, quantity millis, and proceeds minor.';
      });
      return;
    }
    if (quantityMillis <= 0 || proceedsMinor <= 0) {
      setState(() {
        validationError =
            'Quantity millis and proceeds minor must be greater than zero.';
      });
      return;
    }

    setState(() {
      isQueueing = true;
      validationError = null;
    });
    try {
      await widget.onQueueSale(
        lotId: lotId,
        saleDate: saleDate,
        quantityMillis: quantityMillis,
        proceedsMinor: proceedsMinor,
        proceedsAccountId: proceedsAccountIdController.text.trim(),
        gainLossAccountId: gainLossAccountIdController.text.trim(),
        notes: notesController.text.trim(),
      );
    } finally {
      if (mounted) {
        setState(() {
          isQueueing = false;
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
              'Specific-lot sale',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Queue a sale against one known lot while offline. Use average-cost sale when disposing from pooled holdings.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lotIdController,
              decoration: const InputDecoration(
                labelText: 'Specific sale lot ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: saleDateController,
              decoration: const InputDecoration(
                labelText: 'Specific sale date',
                hintText: '2026-07-31',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: quantityMillisController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Specific sale quantity millis',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: proceedsMinorController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Specific sale proceeds minor',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: proceedsAccountIdController,
              decoration: const InputDecoration(
                labelText: 'Specific sale proceeds account ID optional',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: gainLossAccountIdController,
              decoration: const InputDecoration(
                labelText: 'Specific sale gain/loss account ID optional',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Specific sale notes optional',
                border: OutlineInputBorder(),
              ),
            ),
            if (validationError != null) ...[
              const SizedBox(height: 8),
              Text(
                validationError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isQueueing ? null : queueSale,
              icon: const Icon(Icons.sell_outlined),
              label: Text(
                isQueueing
                    ? 'Queueing specific-lot sale...'
                    : 'Queue specific-lot sale',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AverageCostSaleCard extends StatefulWidget {
  const AverageCostSaleCard({required this.onQueueSale, super.key});

  final Future<void> Function({
    required String accountId,
    required String symbol,
    required DateTime saleDate,
    required int quantityMillis,
    required int proceedsMinor,
    required String proceedsAccountId,
    required String gainLossAccountId,
    required String notes,
  })
  onQueueSale;

  @override
  State<AverageCostSaleCard> createState() => _AverageCostSaleCardState();
}

class _AverageCostSaleCardState extends State<AverageCostSaleCard> {
  late final TextEditingController accountIdController;
  late final TextEditingController symbolController;
  late final TextEditingController saleDateController;
  late final TextEditingController quantityMillisController;
  late final TextEditingController proceedsMinorController;
  late final TextEditingController proceedsAccountIdController;
  late final TextEditingController gainLossAccountIdController;
  late final TextEditingController notesController;
  bool isQueueing = false;
  String? validationError;

  @override
  void initState() {
    super.initState();
    accountIdController = TextEditingController(text: 'brokerage-account-id');
    symbolController = TextEditingController(text: 'NIFTYBEES');
    saleDateController = TextEditingController(
      text: formatDateOnly(DateTime.now()),
    );
    quantityMillisController = TextEditingController(text: '1000');
    proceedsMinorController = TextEditingController(text: '14000');
    proceedsAccountIdController = TextEditingController();
    gainLossAccountIdController = TextEditingController();
    notesController = TextEditingController(text: 'Offline average-cost sale');
  }

  @override
  void dispose() {
    accountIdController.dispose();
    symbolController.dispose();
    saleDateController.dispose();
    quantityMillisController.dispose();
    proceedsMinorController.dispose();
    proceedsAccountIdController.dispose();
    gainLossAccountIdController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> queueSale() async {
    if (isQueueing) {
      return;
    }
    final accountId = accountIdController.text.trim();
    final symbol = symbolController.text.trim().toUpperCase();
    final saleDate = parseIsoDateOnlyUtc(saleDateController.text.trim());
    final quantityMillis = int.tryParse(quantityMillisController.text.trim());
    final proceedsMinor = int.tryParse(proceedsMinorController.text.trim());

    if (accountId.isEmpty ||
        symbol.isEmpty ||
        saleDate == null ||
        quantityMillis == null ||
        proceedsMinor == null) {
      setState(() {
        validationError =
            'Enter account ID, symbol, ISO date, quantity millis, and proceeds minor.';
      });
      return;
    }
    if (quantityMillis <= 0 || proceedsMinor <= 0) {
      setState(() {
        validationError =
            'Quantity millis and proceeds minor must be greater than zero.';
      });
      return;
    }

    setState(() {
      isQueueing = true;
      validationError = null;
    });
    try {
      await widget.onQueueSale(
        accountId: accountId,
        symbol: symbol,
        saleDate: saleDate,
        quantityMillis: quantityMillis,
        proceedsMinor: proceedsMinor,
        proceedsAccountId: proceedsAccountIdController.text.trim(),
        gainLossAccountId: gainLossAccountIdController.text.trim(),
        notes: notesController.text.trim(),
      );
    } finally {
      if (mounted) {
        setState(() {
          isQueueing = false;
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
              'Average-cost sale',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Queue a pooled average-cost disposal while offline. Quantity uses millis, so 2.5 units is entered as 2500.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: accountIdController,
              decoration: const InputDecoration(
                labelText: 'Sale account ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: symbolController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Sale symbol',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: saleDateController,
              decoration: const InputDecoration(
                labelText: 'Sale date',
                hintText: '2026-07-31',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: quantityMillisController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Sale quantity millis',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: proceedsMinorController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Sale proceeds minor',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: proceedsAccountIdController,
              decoration: const InputDecoration(
                labelText: 'Proceeds account ID optional',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: gainLossAccountIdController,
              decoration: const InputDecoration(
                labelText: 'Gain/loss account ID optional',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Sale notes optional',
                border: OutlineInputBorder(),
              ),
            ),
            if (validationError != null) ...[
              const SizedBox(height: 8),
              Text(
                validationError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isQueueing ? null : queueSale,
              icon: const Icon(Icons.trending_down_outlined),
              label: Text(
                isQueueing
                    ? 'Queueing average-cost sale...'
                    : 'Queue average-cost sale',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BrokerHoldingsImportCard extends StatefulWidget {
  const BrokerHoldingsImportCard({
    required this.onQueueImport,
    required this.onPickCSV,
    super.key,
  });

  final Future<void> Function(String csv, String source) onQueueImport;
  final Future<PickedTextFile?> Function() onPickCSV;

  @override
  State<BrokerHoldingsImportCard> createState() =>
      _BrokerHoldingsImportCardState();
}

class _BrokerHoldingsImportCardState extends State<BrokerHoldingsImportCard> {
  final controller = TextEditingController(
    text:
        'Symbol,ISIN,As of Date,Last Traded Price,Quantity\nTCS,INE467B01029,31-Jul-2026,3450.75,10',
  );
  String source = 'broker_holdings_csv';
  bool isQueueing = false;
  bool isPicking = false;
  String? pickedFileName;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> queueImport() async {
    final csv = controller.text.trim();
    if (csv.isEmpty || isQueueing) {
      return;
    }
    setState(() {
      isQueueing = true;
    });
    try {
      await widget.onQueueImport(csv, source);
    } finally {
      if (mounted) {
        setState(() {
          isQueueing = false;
        });
      }
    }
  }

  Future<void> pickCSV() async {
    if (isPicking) {
      return;
    }
    setState(() {
      isPicking = true;
    });
    try {
      final picked = await widget.onPickCSV();
      if (picked != null) {
        controller.text = picked.text;
        pickedFileName = picked.fileName;
      }
    } finally {
      if (mounted) {
        setState(() {
          isPicking = false;
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
              'Broker holdings import',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Paste a broker holdings CSV with Symbol/ISIN, date, and LTP/current price columns. It will queue offline and sync when credentials are available.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: source,
              decoration: const InputDecoration(
                labelText: 'Provider route',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'broker_holdings_csv',
                  child: Text('Generic broker holdings CSV'),
                ),
                DropdownMenuItem(
                  value: 'zerodha_holdings_csv',
                  child: Text('Zerodha holdings CSV'),
                ),
                DropdownMenuItem(
                  value: 'groww_holdings_csv',
                  child: Text('Groww holdings CSV'),
                ),
                DropdownMenuItem(
                  value: 'upstox_holdings_csv',
                  child: Text('Upstox holdings CSV'),
                ),
                DropdownMenuItem(
                  value: 'angelone_holdings_csv',
                  child: Text('Angel One holdings CSV'),
                ),
                DropdownMenuItem(
                  value: 'dhan_holdings_csv',
                  child: Text('Dhan holdings CSV'),
                ),
                DropdownMenuItem(
                  value: 'icicidirect_holdings_csv',
                  child: Text('ICICI Direct holdings CSV'),
                ),
                DropdownMenuItem(
                  value: 'hdfcsky_holdings_csv',
                  child: Text('HDFC Sky holdings CSV'),
                ),
                DropdownMenuItem(
                  value: 'kotakneo_holdings_csv',
                  child: Text('Kotak Neo holdings CSV'),
                ),
                DropdownMenuItem(
                  value: 'paytmmoney_holdings_csv',
                  child: Text('Paytm Money holdings CSV'),
                ),
                DropdownMenuItem(
                  value: 'motilaloswal_holdings_csv',
                  child: Text('Motilal Oswal holdings CSV'),
                ),
                DropdownMenuItem(
                  value: 'sharekhan_holdings_csv',
                  child: Text('Sharekhan holdings CSV'),
                ),
                DropdownMenuItem(
                  value: 'fivepaisa_holdings_csv',
                  child: Text('5paisa holdings CSV'),
                ),
                DropdownMenuItem(
                  value: 'axisdirect_holdings_csv',
                  child: Text('Axis Direct holdings CSV'),
                ),
                DropdownMenuItem(
                  value: 'sbisecurities_holdings_csv',
                  child: Text('SBI Securities holdings CSV'),
                ),
                DropdownMenuItem(
                  value: 'nuvama_holdings_csv',
                  child: Text('Nuvama holdings CSV'),
                ),
                DropdownMenuItem(
                  value: 'geojit_holdings_csv',
                  child: Text('Geojit holdings CSV'),
                ),
                DropdownMenuItem(
                  value: 'iiflsecurities_holdings_csv',
                  child: Text('IIFL Securities holdings CSV'),
                ),
                DropdownMenuItem(
                  value: 'fyers_holdings_csv',
                  child: Text('FYERS holdings CSV'),
                ),
                DropdownMenuItem(
                  value: 'edelweiss_holdings_csv',
                  child: Text('Edelweiss holdings CSV'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  source = value;
                  if (value == 'zerodha_holdings_csv') {
                    controller.text =
                        'Instrument,ISIN,Date,LTP,Qty.\nHDFCBANK,INE040A01034,2026-07-31,1575.20,4';
                  } else if (value == 'groww_holdings_csv') {
                    controller.text =
                        'Company Name,ISIN,Date,LTP,Quantity\nReliance Industries,INE002A01018,2026-07-31,1410.55,3';
                  } else if (value == 'upstox_holdings_csv') {
                    controller.text =
                        'Symbol,ISIN,Date,Current Price,Quantity\nSBIN,INE062A01020,2026-07-31,615.25,12';
                  } else if (value == 'angelone_holdings_csv') {
                    controller.text =
                        'Scrip,ISIN,Date,LTP,Quantity\nICICIBANK,INE090A01021,2026-07-31,1245.30,5';
                  } else if (value == 'dhan_holdings_csv') {
                    controller.text =
                        'Trading Symbol,ISIN,Date,LTP,Quantity\nAXISBANK,INE238A01034,2026-07-31,1188.40,8';
                  } else if (value == 'icicidirect_holdings_csv') {
                    controller.text =
                        'Symbol,ISIN,Date,Market Price,Quantity\nLT,INE018A01030,2026-07-31,3620.80,2';
                  } else if (value == 'hdfcsky_holdings_csv') {
                    controller.text =
                        'Symbol,ISIN,Date,LTP,Quantity\nMARUTI,INE585B01010,2026-07-31,12875.65,1';
                  } else if (value == 'kotakneo_holdings_csv') {
                    controller.text =
                        'Trading Symbol,ISIN,Date,LTP,Quantity\nBAJFINANCE,INE296A01024,2026-07-31,9342.10,2';
                  } else if (value == 'paytmmoney_holdings_csv') {
                    controller.text =
                        'Symbol,ISIN,Date,LTP,Quantity\nTATAMOTORS,INE155A01022,2026-07-31,1098.45,5';
                  } else if (value == 'motilaloswal_holdings_csv') {
                    controller.text =
                        'Symbol,ISIN,Date,LTP,Quantity\nASIANPAINT,INE021A01026,2026-07-31,2987.60,3';
                  } else if (value == 'sharekhan_holdings_csv') {
                    controller.text =
                        'Symbol,ISIN,Date,LTP,Quantity\nHINDUNILVR,INE030A01027,2026-07-31,2567.35,4';
                  } else if (value == 'fivepaisa_holdings_csv') {
                    controller.text =
                        'Symbol,ISIN,Date,LTP,Quantity\nSBIN,INE062A01020,2026-07-31,845.70,10';
                  } else if (value == 'axisdirect_holdings_csv') {
                    controller.text =
                        'Symbol,ISIN,Date,LTP,Quantity\nTECHM,INE669C01036,2026-07-31,1543.25,6';
                  } else if (value == 'sbisecurities_holdings_csv') {
                    controller.text =
                        'Symbol,ISIN,Date,LTP,Quantity\nINFY,INE009A01021,2026-07-31,1499.95,9';
                  } else if (value == 'nuvama_holdings_csv') {
                    controller.text =
                        'Symbol,ISIN,Date,LTP,Quantity\nWIPRO,INE075A01022,2026-07-31,512.40,11';
                  } else if (value == 'geojit_holdings_csv') {
                    controller.text =
                        'Symbol,ISIN,Date,LTP,Quantity\nHCLTECH,INE860A01027,2026-07-31,1444.80,7';
                  } else if (value == 'iiflsecurities_holdings_csv') {
                    controller.text =
                        'Symbol,ISIN,Date,LTP,Quantity\nTITAN,INE280A01028,2026-07-31,3520.15,2';
                  } else if (value == 'fyers_holdings_csv') {
                    controller.text =
                        'Symbol,ISIN,Date,LTP,Quantity\nSBIN,INE062A01020,2026-07-31,820.45,8';
                  } else if (value == 'edelweiss_holdings_csv') {
                    controller.text =
                        'Symbol,ISIN,Date,LTP,Quantity\nEDELWEISS,INE532F01054,2026-07-31,910.25,4';
                  }
                });
              },
            ),
            if (pickedFileName != null) ...[
              const SizedBox(height: 8),
              Text('Selected file: $pickedFileName'),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Holdings CSV',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: isPicking ? null : pickCSV,
                  icon: const Icon(Icons.attach_file_outlined),
                  label: Text(
                    isPicking ? 'Choosing CSV...' : 'Choose holdings CSV',
                  ),
                ),
                FilledButton.icon(
                  onPressed: isQueueing || controller.text.trim().isEmpty
                      ? null
                      : queueImport,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(
                    isQueueing
                        ? 'Queueing broker import...'
                        : 'Queue broker holdings import',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({
    required this.trialBalance,
    required this.profitAndLoss,
    required this.priorProfitAndLoss,
    required this.balanceSheet,
    required this.priorBalanceSheet,
    required this.cashFlow,
    required this.priorCashFlow,
    required this.arAging,
    required this.priorARAging,
    required this.apAging,
    required this.priorAPAging,
    required this.taxLiability,
    required this.priorTaxLiability,
    required this.taxSummary,
    required this.priorTaxSummary,
    required this.budgets,
    required this.budgetVsActual,
    required this.priorBudgetVsActual,
    required this.isLoading,
    required this.onFetchTrialBalance,
    required this.onFetchProfitAndLoss,
    required this.onFetchProfitAndLossComparison,
    required this.onFetchBalanceSheet,
    required this.onFetchBalanceSheetComparison,
    required this.onFetchCashFlow,
    required this.onFetchCashFlowComparison,
    required this.onFetchARAging,
    required this.onFetchARAgingComparison,
    required this.onFetchAPAging,
    required this.onFetchAPAgingComparison,
    required this.onQueueBillPost,
    required this.onQueueVendorPayment,
    required this.onFetchTaxLiability,
    required this.onFetchTaxLiabilityComparison,
    required this.onFetchTaxSummary,
    required this.onFetchTaxSummaryComparison,
    required this.onFetchBudgets,
    required this.onFetchBudgetVsActual,
    required this.onFetchBudgetVsActualComparison,
    required this.onSaveCsvExports,
    required this.onShareCsvExports,
    this.notice,
    this.lastExportDirectory,
    super.key,
  });

  final TrialBalanceReport? trialBalance;
  final ProfitAndLossReport? profitAndLoss;
  final ProfitAndLossReport? priorProfitAndLoss;
  final BalanceSheetReport? balanceSheet;
  final BalanceSheetReport? priorBalanceSheet;
  final CashFlowReport? cashFlow;
  final CashFlowReport? priorCashFlow;
  final ARAgingReport? arAging;
  final ARAgingReport? priorARAging;
  final APAgingReport? apAging;
  final APAgingReport? priorAPAging;
  final TaxLiabilityReport? taxLiability;
  final TaxLiabilityReport? priorTaxLiability;
  final TaxSummaryReport? taxSummary;
  final TaxSummaryReport? priorTaxSummary;
  final List<BudgetSummary> budgets;
  final BudgetVsActualReport? budgetVsActual;
  final BudgetVsActualReport? priorBudgetVsActual;
  final bool isLoading;
  final String? notice;
  final String? lastExportDirectory;
  final Future<void> Function(DateTime asOf) onFetchTrialBalance;
  final Future<void> Function(DateTime from, DateTime to) onFetchProfitAndLoss;
  final Future<void> Function(DateTime from, DateTime to)
  onFetchProfitAndLossComparison;
  final Future<void> Function(DateTime asOf) onFetchBalanceSheet;
  final Future<void> Function(DateTime asOf) onFetchBalanceSheetComparison;
  final Future<void> Function(DateTime from, DateTime to) onFetchCashFlow;
  final Future<void> Function(DateTime from, DateTime to)
  onFetchCashFlowComparison;
  final Future<void> Function(DateTime asOf) onFetchARAging;
  final Future<void> Function(DateTime asOf) onFetchARAgingComparison;
  final Future<void> Function(DateTime asOf) onFetchAPAging;
  final Future<void> Function(DateTime asOf) onFetchAPAgingComparison;
  final Future<void> Function(String billId) onQueueBillPost;
  final Future<void> Function(VendorPaymentInput input) onQueueVendorPayment;
  final Future<void> Function(DateTime from, DateTime to) onFetchTaxLiability;
  final Future<void> Function(DateTime from, DateTime to)
  onFetchTaxLiabilityComparison;
  final Future<void> Function(DateTime from, DateTime to) onFetchTaxSummary;
  final Future<void> Function(DateTime from, DateTime to)
  onFetchTaxSummaryComparison;
  final Future<void> Function() onFetchBudgets;
  final Future<void> Function(String budgetId) onFetchBudgetVsActual;
  final Future<void> Function(String budgetId, String previousBudgetId)
  onFetchBudgetVsActualComparison;
  final Future<void> Function(List<ReportCsvExport> exports, {bool toDownloads})
  onSaveCsvExports;
  final Future<void> Function(List<ReportCsvExport> exports) onShareCsvExports;

  @override
  Widget build(BuildContext context) {
    final asOf = DateTime.now().toUtc();
    final fiscalStart = asOf.month >= 4
        ? DateTime.utc(asOf.year, 4)
        : DateTime.utc(asOf.year - 1, 4);
    final selectedBudget = _selectedBudget(budgets, budgetVsActual?.budgetId);
    final comparisonBudget = _comparisonBudget(budgets, selectedBudget);
    final exports = buildReportCsvExports(
      ReportCacheSnapshot(
        trialBalance: trialBalance,
        profitAndLoss: profitAndLoss,
        balanceSheet: balanceSheet,
        cashFlow: cashFlow,
        arAging: arAging,
        apAging: apAging,
        taxLiability: taxLiability,
        taxSummary: taxSummary,
        budgets: budgets,
        budgetVsActual: budgetVsActual,
      ),
    );
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
              OutlinedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => onFetchProfitAndLossComparison(fiscalStart, asOf),
                icon: const Icon(Icons.compare_outlined),
                label: const Text('Fetch P&L comparison'),
              ),
              if (priorProfitAndLoss != null) ...[
                const SizedBox(height: 8),
                _ProfitAndLossComparison(
                  current: profitAndLoss!,
                  previous: priorProfitAndLoss!,
                ),
              ],
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
              OutlinedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => onFetchBalanceSheetComparison(asOf),
                icon: const Icon(Icons.compare_outlined),
                label: const Text('Fetch balance sheet comparison'),
              ),
              if (priorBalanceSheet != null) ...[
                const SizedBox(height: 8),
                _BalanceSheetComparison(
                  current: balanceSheet!,
                  previous: priorBalanceSheet!,
                ),
              ],
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
              OutlinedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => onFetchCashFlowComparison(fiscalStart, asOf),
                icon: const Icon(Icons.compare_outlined),
                label: const Text('Fetch cash flow comparison'),
              ),
              if (priorCashFlow != null) ...[
                const SizedBox(height: 8),
                _CashFlowComparison(
                  current: cashFlow!,
                  previous: priorCashFlow!,
                ),
              ],
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
              OutlinedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => onFetchARAgingComparison(asOf),
                icon: const Icon(Icons.compare_outlined),
                label: const Text('Fetch AR aging comparison'),
              ),
              if (priorARAging != null) ...[
                const SizedBox(height: 8),
                _AgingComparison(
                  title: 'AR aging prior',
                  current: arAging!.totals,
                  previous: priorARAging!.totals,
                  previousDate: priorARAging!.asOfDate,
                ),
              ],
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
              OutlinedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => onFetchAPAgingComparison(asOf),
                icon: const Icon(Icons.compare_outlined),
                label: const Text('Fetch AP aging comparison'),
              ),
              if (priorAPAging != null) ...[
                const SizedBox(height: 8),
                _AgingComparison(
                  title: 'AP aging prior',
                  current: apAging!.totals,
                  previous: priorAPAging!.totals,
                  previousDate: priorAPAging!.asOfDate,
                ),
              ],
              const SizedBox(height: 8),
              _APAgingRows(rows: apAging!.rows),
              const SizedBox(height: 8),
              APAgingActionsCard(
                rows: apAging!.rows,
                onQueueBillPost: onQueueBillPost,
                onQueueVendorPayment: onQueueVendorPayment,
              ),
            ],
          ],
        ),
        _ReportCard(
          title: 'Tax liability',
          description:
              'Summarizes output tax minus input tax from ${formatDateOnly(fiscalStart)} to ${formatDateOnly(asOf)}.',
          buttonLabel: isLoading ? 'Loading reports...' : 'Fetch tax liability',
          icon: Icons.account_balance_wallet_outlined,
          isLoading: isLoading,
          onPressed: () => onFetchTaxLiability(fiscalStart, asOf),
          children: [
            if (taxLiability == null)
              const Text('No cached tax liability report yet.')
            else ...[
              Text(
                '${formatDateOnly(taxLiability!.fromDate)} to ${formatDateOnly(taxLiability!.toDate)}',
              ),
              Text(
                'Output ${formatMinorAsInr(taxLiability!.outputTaxMinor)} · Input ${formatMinorAsInr(taxLiability!.inputTaxMinor)}',
              ),
              Text(
                'Net payable ${formatMinorAsInr(taxLiability!.netPayableMinor)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => onFetchTaxLiabilityComparison(fiscalStart, asOf),
                icon: const Icon(Icons.compare_outlined),
                label: const Text('Fetch tax liability comparison'),
              ),
              if (priorTaxLiability != null) ...[
                const SizedBox(height: 8),
                _TaxLiabilityComparison(
                  current: taxLiability!,
                  previous: priorTaxLiability!,
                ),
              ],
              const SizedBox(height: 8),
              _TaxReportRows(rows: taxLiability!.rows),
            ],
          ],
        ),
        _ReportCard(
          title: 'Tax summary',
          description:
              'Breaks tax activity down by configured rate/group for filing support.',
          buttonLabel: isLoading ? 'Loading reports...' : 'Fetch tax summary',
          icon: Icons.summarize_outlined,
          isLoading: isLoading,
          onPressed: () => onFetchTaxSummary(fiscalStart, asOf),
          children: [
            if (taxSummary == null)
              const Text('No cached tax summary report yet.')
            else ...[
              Text(
                '${formatDateOnly(taxSummary!.fromDate)} to ${formatDateOnly(taxSummary!.toDate)}',
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => onFetchTaxSummaryComparison(fiscalStart, asOf),
                icon: const Icon(Icons.compare_outlined),
                label: const Text('Fetch tax summary comparison'),
              ),
              if (priorTaxSummary != null) ...[
                const SizedBox(height: 8),
                _TaxSummaryComparison(
                  current: taxSummary!,
                  previous: priorTaxSummary!,
                ),
              ],
              const SizedBox(height: 8),
              _TaxReportRows(rows: taxSummary!.rows),
            ],
          ],
        ),
        _ReportCard(
          title: 'Budget vs actual',
          description:
              'Refreshes the budget catalog and compares the latest cached budget against ledger actuals.',
          buttonLabel: isLoading ? 'Loading reports...' : 'Fetch budgets',
          icon: Icons.fact_check_outlined,
          isLoading: isLoading,
          onPressed: onFetchBudgets,
          children: [
            if (budgets.isEmpty)
              const Text('No cached budgets yet.')
            else ...[
              Text(
                'Selected budget: ${selectedBudget!.name} · ${selectedBudget.status}',
              ),
              Text(
                '${formatDateOnly(selectedBudget.startDate)} to ${formatDateOnly(selectedBudget.endDate)} · ${selectedBudget.lines.length} lines',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => onFetchBudgetVsActual(selectedBudget.id),
                icon: const Icon(Icons.compare_arrows_outlined),
                label: const Text('Fetch budget vs actual'),
              ),
              if (comparisonBudget != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => onFetchBudgetVsActualComparison(
                          selectedBudget.id,
                          comparisonBudget.id,
                        ),
                  icon: const Icon(Icons.compare_outlined),
                  label: Text('Compare with ${comparisonBudget.name}'),
                ),
              ],
              if (budgetVsActual != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Budget ${formatMinorAsInr(budgetVsActual!.totalBudgetMinor)} · Actual ${formatMinorAsInr(budgetVsActual!.totalActualMinor)}',
                ),
                Text(
                  'Variance ${formatMinorAsInr(budgetVsActual!.totalVarianceMinor)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (priorBudgetVsActual != null) ...[
                  const SizedBox(height: 8),
                  _BudgetVsActualComparison(
                    current: budgetVsActual!,
                    previous: priorBudgetVsActual!,
                    previousName: comparisonBudget?.name ?? 'previous budget',
                  ),
                ],
                const SizedBox(height: 8),
                _BudgetVsActualRows(rows: budgetVsActual!.rows),
              ],
            ],
          ],
        ),
        _ReportExportCard(
          exports: exports,
          isLoading: isLoading,
          lastExportDirectory: lastExportDirectory,
          onSave: () => onSaveCsvExports(exports),
          onSaveToDownloads: () => onSaveCsvExports(exports, toDownloads: true),
          onShare: () => onShareCsvExports(exports),
        ),
        if (notice != null) Text(notice!),
        const InfoList(
          items: [
            'Target APIs: financial statements, aging, tax liability, and tax summary reports',
            'Latest financial report snapshots are cached locally for offline review',
            'CSV export files can be saved locally from cached reports',
            'Comparisons are available for statements, aging, tax, and budget-vs-actual snapshots',
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

class _ProfitAndLossComparison extends StatelessWidget {
  const _ProfitAndLossComparison({
    required this.current,
    required this.previous,
  });

  final ProfitAndLossReport current;
  final ProfitAndLossReport previous;

  @override
  Widget build(BuildContext context) {
    final variance = current.netIncomeMinor - previous.netIncomeMinor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prior period ${formatDateOnly(previous.fromDate)} to ${formatDateOnly(previous.toDate)}',
        ),
        Text('Prior net income ${formatMinorAsInr(previous.netIncomeMinor)}'),
        Text(
          'Variance ${formatMinorAsInr(variance)} (${_formatPercentBasis(_percentBasis(variance, previous.netIncomeMinor))})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _BalanceSheetComparison extends StatelessWidget {
  const _BalanceSheetComparison({
    required this.current,
    required this.previous,
  });

  final BalanceSheetReport current;
  final BalanceSheetReport previous;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Prior as of ${formatDateOnly(previous.asOfDate)}'),
        _BalanceSheetComparisonLine(
          label: 'Assets',
          currentMinor: current.totalAssetsMinor,
          previousMinor: previous.totalAssetsMinor,
        ),
        _BalanceSheetComparisonLine(
          label: 'Liabilities',
          currentMinor: current.totalLiabilitiesMinor,
          previousMinor: previous.totalLiabilitiesMinor,
        ),
        _BalanceSheetComparisonLine(
          label: 'Equity',
          currentMinor: current.totalEquityMinor,
          previousMinor: previous.totalEquityMinor,
        ),
      ],
    );
  }
}

class _BalanceSheetComparisonLine extends StatelessWidget {
  const _BalanceSheetComparisonLine({
    required this.label,
    required this.currentMinor,
    required this.previousMinor,
  });

  final String label;
  final int currentMinor;
  final int previousMinor;

  @override
  Widget build(BuildContext context) {
    final variance = currentMinor - previousMinor;
    return Text(
      '$label prior ${formatMinorAsInr(previousMinor)} · Var ${formatMinorAsInr(variance)} (${_formatPercentBasis(_percentBasis(variance, previousMinor))})',
    );
  }
}

class _CashFlowComparison extends StatelessWidget {
  const _CashFlowComparison({required this.current, required this.previous});

  final CashFlowReport current;
  final CashFlowReport previous;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prior period ${formatDateOnly(previous.fromDate)} to ${formatDateOnly(previous.toDate)}',
        ),
        _CashFlowComparisonLine(
          label: 'Inflows',
          currentMinor: current.totalInflowsMinor,
          previousMinor: previous.totalInflowsMinor,
        ),
        _CashFlowComparisonLine(
          label: 'Outflows',
          currentMinor: current.totalOutflowsMinor,
          previousMinor: previous.totalOutflowsMinor,
        ),
        _CashFlowComparisonLine(
          label: 'Net cash flow',
          currentMinor: current.netCashFlowMinor,
          previousMinor: previous.netCashFlowMinor,
        ),
        _CashFlowComparisonLine(
          label: 'Closing cash',
          currentMinor: current.closingCashMinor,
          previousMinor: previous.closingCashMinor,
        ),
      ],
    );
  }
}

class _CashFlowComparisonLine extends StatelessWidget {
  const _CashFlowComparisonLine({
    required this.label,
    required this.currentMinor,
    required this.previousMinor,
  });

  final String label;
  final int currentMinor;
  final int previousMinor;

  @override
  Widget build(BuildContext context) {
    final variance = currentMinor - previousMinor;
    return Text(
      '$label prior ${formatMinorAsInr(previousMinor)} · Var ${formatMinorAsInr(variance)} (${_formatPercentBasis(_percentBasis(variance, previousMinor))})',
    );
  }
}

class _ReportExportCard extends StatelessWidget {
  const _ReportExportCard({
    required this.exports,
    required this.isLoading,
    required this.onSave,
    required this.onSaveToDownloads,
    required this.onShare,
    this.lastExportDirectory,
  });

  final List<ReportCsvExport> exports;
  final bool isLoading;
  final VoidCallback onSave;
  final VoidCallback onSaveToDownloads;
  final VoidCallback onShare;
  final String? lastExportDirectory;

  @override
  Widget build(BuildContext context) {
    final firstExport = exports.isEmpty ? null : exports.first;
    final previewLines = firstExport?.contents.split('\n').take(4).join('\n');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CSV export preview',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Generated locally from the offline report cache and saveable to app storage or Downloads when available.',
            ),
            const SizedBox(height: 12),
            if (exports.isEmpty)
              const Text('No cached reports available for CSV export yet.')
            else ...[
              Text('${exports.length} CSV exports ready from cache.'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: isLoading ? null : onSave,
                    icon: const Icon(Icons.save_alt_outlined),
                    label: Text(
                      isLoading ? 'Saving CSV files...' : 'Save CSV files',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : onSaveToDownloads,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Save to Downloads'),
                  ),
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : onShare,
                    icon: const Icon(Icons.ios_share_outlined),
                    label: const Text('Share CSV files'),
                  ),
                ],
              ),
              if (lastExportDirectory != null) ...[
                const SizedBox(height: 8),
                Text('Last saved to $lastExportDirectory'),
              ],
              const SizedBox(height: 8),
              for (final export in exports.take(8))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('${export.fileName} · ${export.rowCount} rows'),
                ),
              if (previewLines != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Preview: ${firstExport!.fileName}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SelectableText(previewLines),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

int? _percentBasis(int numerator, int denominator) {
  if (denominator == 0) {
    return null;
  }
  return ((numerator * 10000) / denominator.abs()).round();
}

String _formatPercentBasis(int? basis) {
  if (basis == null) {
    return 'n/a';
  }
  final sign = basis > 0 ? '+' : '';
  return '$sign${(basis / 100).toStringAsFixed(2)}%';
}

BudgetSummary? _selectedBudget(List<BudgetSummary> budgets, String? budgetId) {
  if (budgets.isEmpty) {
    return null;
  }
  if (budgetId == null) {
    return budgets.first;
  }
  for (final budget in budgets) {
    if (budget.id == budgetId) {
      return budget;
    }
  }
  return budgets.first;
}

BudgetSummary? _comparisonBudget(
  List<BudgetSummary> budgets,
  BudgetSummary? selected,
) {
  if (selected == null) {
    return null;
  }
  final earlier =
      budgets
          .where((budget) => budget.id != selected.id)
          .where((budget) => !budget.endDate.isAfter(selected.startDate))
          .toList()
        ..sort((left, right) => right.endDate.compareTo(left.endDate));
  if (earlier.isNotEmpty) {
    return earlier.first;
  }
  for (final budget in budgets) {
    if (budget.id != selected.id) {
      return budget;
    }
  }
  return null;
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

class _AgingComparison extends StatelessWidget {
  const _AgingComparison({
    required this.title,
    required this.current,
    required this.previous,
    required this.previousDate,
  });

  final String title;
  final AgingBucketTotals current;
  final AgingBucketTotals previous;
  final DateTime previousDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title as of ${formatDateOnly(previousDate)}'),
        _AgingComparisonLine(
          label: 'Outstanding',
          currentMinor: current.outstandingMinor,
          previousMinor: previous.outstandingMinor,
        ),
        _AgingComparisonLine(
          label: 'Current',
          currentMinor: current.currentMinor,
          previousMinor: previous.currentMinor,
        ),
        _AgingComparisonLine(
          label: '1-30',
          currentMinor: current.oneToThirtyMinor,
          previousMinor: previous.oneToThirtyMinor,
        ),
        _AgingComparisonLine(
          label: '31-60',
          currentMinor: current.thirtyOneToSixtyMinor,
          previousMinor: previous.thirtyOneToSixtyMinor,
        ),
        _AgingComparisonLine(
          label: '61-90',
          currentMinor: current.sixtyOneToNinetyMinor,
          previousMinor: previous.sixtyOneToNinetyMinor,
        ),
        _AgingComparisonLine(
          label: '90+',
          currentMinor: current.overNinetyMinor,
          previousMinor: previous.overNinetyMinor,
        ),
      ],
    );
  }
}

class _AgingComparisonLine extends StatelessWidget {
  const _AgingComparisonLine({
    required this.label,
    required this.currentMinor,
    required this.previousMinor,
  });

  final String label;
  final int currentMinor;
  final int previousMinor;

  @override
  Widget build(BuildContext context) {
    final variance = currentMinor - previousMinor;
    final percent = _formatPercentBasis(_percentBasis(variance, previousMinor));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '$label prior ${formatMinorAsInr(previousMinor)} · Var ${formatMinorAsInr(variance)} ($percent)',
      ),
    );
  }
}

class _TaxLiabilityComparison extends StatelessWidget {
  const _TaxLiabilityComparison({
    required this.current,
    required this.previous,
  });

  final TaxLiabilityReport current;
  final TaxLiabilityReport previous;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prior tax liability ${formatDateOnly(previous.fromDate)} to ${formatDateOnly(previous.toDate)}',
        ),
        _AmountComparisonLine(
          label: 'Output tax',
          currentMinor: current.outputTaxMinor,
          previousMinor: previous.outputTaxMinor,
        ),
        _AmountComparisonLine(
          label: 'Input tax',
          currentMinor: current.inputTaxMinor,
          previousMinor: previous.inputTaxMinor,
        ),
        _AmountComparisonLine(
          label: 'Net payable',
          currentMinor: current.netPayableMinor,
          previousMinor: previous.netPayableMinor,
        ),
      ],
    );
  }
}

class _TaxSummaryComparison extends StatelessWidget {
  const _TaxSummaryComparison({required this.current, required this.previous});

  final TaxSummaryReport current;
  final TaxSummaryReport previous;

  @override
  Widget build(BuildContext context) {
    final currentTotals = _taxReportTotals(current.rows);
    final previousTotals = _taxReportTotals(previous.rows);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prior tax summary ${formatDateOnly(previous.fromDate)} to ${formatDateOnly(previous.toDate)}',
        ),
        _AmountComparisonLine(
          label: 'Output tax',
          currentMinor: currentTotals.outputTaxMinor,
          previousMinor: previousTotals.outputTaxMinor,
        ),
        _AmountComparisonLine(
          label: 'Input tax',
          currentMinor: currentTotals.inputTaxMinor,
          previousMinor: previousTotals.inputTaxMinor,
        ),
        _AmountComparisonLine(
          label: 'Net payable',
          currentMinor: currentTotals.netPayableMinor,
          previousMinor: previousTotals.netPayableMinor,
        ),
      ],
    );
  }
}

class _BudgetVsActualComparison extends StatelessWidget {
  const _BudgetVsActualComparison({
    required this.current,
    required this.previous,
    required this.previousName,
  });

  final BudgetVsActualReport current;
  final BudgetVsActualReport previous;
  final String previousName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Prior budget: $previousName'),
        _AmountComparisonLine(
          label: 'Budget',
          currentMinor: current.totalBudgetMinor,
          previousMinor: previous.totalBudgetMinor,
        ),
        _AmountComparisonLine(
          label: 'Actual',
          currentMinor: current.totalActualMinor,
          previousMinor: previous.totalActualMinor,
        ),
        _AmountComparisonLine(
          label: 'Variance',
          currentMinor: current.totalVarianceMinor,
          previousMinor: previous.totalVarianceMinor,
        ),
      ],
    );
  }
}

class _AmountComparisonLine extends StatelessWidget {
  const _AmountComparisonLine({
    required this.label,
    required this.currentMinor,
    required this.previousMinor,
  });

  final String label;
  final int currentMinor;
  final int previousMinor;

  @override
  Widget build(BuildContext context) {
    final variance = currentMinor - previousMinor;
    final percent = _formatPercentBasis(_percentBasis(variance, previousMinor));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '$label prior ${formatMinorAsInr(previousMinor)} · Var ${formatMinorAsInr(variance)} ($percent)',
      ),
    );
  }
}

class _TaxReportTotals {
  const _TaxReportTotals({
    required this.outputTaxMinor,
    required this.inputTaxMinor,
    required this.netPayableMinor,
  });

  final int outputTaxMinor;
  final int inputTaxMinor;
  final int netPayableMinor;
}

_TaxReportTotals _taxReportTotals(List<TaxReportRowSummary> rows) {
  return _TaxReportTotals(
    outputTaxMinor: rows.fold(0, (total, row) => total + row.outputTaxMinor),
    inputTaxMinor: rows.fold(0, (total, row) => total + row.inputTaxMinor),
    netPayableMinor: rows.fold(0, (total, row) => total + row.netPayableMinor),
  );
}

class _BudgetVsActualRows extends StatelessWidget {
  const _BudgetVsActualRows({required this.rows});

  final List<BudgetVsActualReportRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Text('No budget lines in this report.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows.take(12))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${row.accountCode} · ${row.accountName} · Budget ${formatMinorAsInr(row.budgetMinor)} · Actual ${formatMinorAsInr(row.actualMinor)} · Var ${formatMinorAsInr(row.varianceMinor)}',
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

class APAgingActionsCard extends StatefulWidget {
  const APAgingActionsCard({
    required this.rows,
    required this.onQueueBillPost,
    required this.onQueueVendorPayment,
    super.key,
  });

  final List<APAgingRow> rows;
  final Future<void> Function(String billId) onQueueBillPost;
  final Future<void> Function(VendorPaymentInput input) onQueueVendorPayment;

  @override
  State<APAgingActionsCard> createState() => _APAgingActionsCardState();
}

class _APAgingActionsCardState extends State<APAgingActionsCard> {
  late final TextEditingController billIdController;
  late final TextEditingController paymentNumberController;
  late final TextEditingController paymentDateController;
  late final TextEditingController amountController;
  late final TextEditingController paymentAccountController;
  late final TextEditingController paymentMethodController;
  late final TextEditingController referenceController;
  String? validationMessage;
  bool isQueueing = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    billIdController = TextEditingController();
    paymentNumberController = TextEditingController(
      text: 'VPAY-MOB-${now.millisecondsSinceEpoch}',
    );
    paymentDateController = TextEditingController(text: formatDateOnly(now));
    amountController = TextEditingController(text: '0.00');
    paymentAccountController = TextEditingController();
    paymentMethodController = TextEditingController(text: 'bank_transfer');
    referenceController = TextEditingController();
  }

  @override
  void dispose() {
    billIdController.dispose();
    paymentNumberController.dispose();
    paymentDateController.dispose();
    amountController.dispose();
    paymentAccountController.dispose();
    paymentMethodController.dispose();
    referenceController.dispose();
    super.dispose();
  }

  int parseRupeesToPaise(String value) {
    final normalized = value.trim().replaceAll(',', '');
    if (normalized.isEmpty) {
      return 0;
    }
    final rupees = double.tryParse(normalized) ?? 0;
    return (rupees * 100).round();
  }

  void applyRow(APAgingRow row) {
    billIdController.text = row.billId;
    amountController.text = formatMinorAsInput(row.outstandingMinor);
    setState(() {
      validationMessage = 'Selected ${row.billNumber}.';
    });
  }

  Future<void> queueBillPost() async {
    final billId = billIdController.text.trim();
    if (billId.isEmpty) {
      setState(() {
        validationMessage = 'Select or enter a bill ID before posting.';
      });
      return;
    }
    await widget.onQueueBillPost(billId);
  }

  Future<void> queueVendorPayment() async {
    if (isQueueing) {
      return;
    }
    final paymentDate = parseIsoDateOnlyUtc(paymentDateController.text.trim());
    final amountMinor = parseRupeesToPaise(amountController.text);
    if (billIdController.text.trim().isEmpty ||
        paymentNumberController.text.trim().isEmpty ||
        paymentAccountController.text.trim().isEmpty ||
        paymentDate == null ||
        amountMinor <= 0) {
      setState(() {
        validationMessage =
            'Enter bill ID, payment number, payment date, amount, and payment account ID.';
      });
      return;
    }
    setState(() {
      isQueueing = true;
      validationMessage = null;
    });
    try {
      await widget.onQueueVendorPayment(
        VendorPaymentInput(
          billId: billIdController.text.trim(),
          paymentNumber: paymentNumberController.text.trim(),
          paymentDate: paymentDate,
          amountMinor: amountMinor,
          paymentAccountId: paymentAccountController.text.trim(),
          paymentMethod: paymentMethodController.text.trim(),
          reference: referenceController.text.trim(),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isQueueing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Text('AP actions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Queue bill posting or vendor payments from cached AP aging rows.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: billIdController,
              decoration: const InputDecoration(labelText: 'Action bill ID'),
            ),
            if (widget.rows.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final row in widget.rows.take(6))
                    ActionChip(
                      label: Text('${row.billNumber} · ${row.billId}'),
                      onPressed: () => applyRow(row),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: queueBillPost,
              icon: const Icon(Icons.publish_outlined),
              label: const Text('Queue bill posting'),
            ),
            const Divider(height: 28),
            TextField(
              controller: paymentNumberController,
              decoration: const InputDecoration(
                labelText: 'Vendor payment number',
              ),
            ),
            TextField(
              controller: paymentDateController,
              decoration: const InputDecoration(
                labelText: 'Vendor payment date',
                hintText: '2026-07-17',
              ),
            ),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Vendor payment amount in INR',
              ),
            ),
            TextField(
              controller: paymentAccountController,
              decoration: const InputDecoration(
                labelText: 'Vendor payment account ID',
              ),
            ),
            TextField(
              controller: paymentMethodController,
              decoration: const InputDecoration(
                labelText: 'Vendor payment method',
                helperText: 'Optional, for example bank_transfer, upi, cash.',
              ),
            ),
            TextField(
              controller: referenceController,
              decoration: const InputDecoration(
                labelText: 'Vendor payment reference',
              ),
            ),
            if (validationMessage != null) Text(validationMessage!),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isQueueing ? null : queueVendorPayment,
              icon: const Icon(Icons.payments_outlined),
              label: Text(
                isQueueing
                    ? 'Queueing vendor payment...'
                    : 'Queue vendor payment',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaxReportRows extends StatelessWidget {
  const _TaxReportRows({required this.rows});

  final List<TaxReportRowSummary> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Text('No tax activity in this period.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows.take(12))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${row.name} · Output ${formatMinorAsInr(row.outputTaxMinor)} · Input ${formatMinorAsInr(row.inputTaxMinor)} · Net ${formatMinorAsInr(row.netPayableMinor)}',
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
