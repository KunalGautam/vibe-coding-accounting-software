import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../sync/offline_sync_queue.dart';

String _dateOnly(DateTime date) {
  final normalized = date.toUtc();
  final month = normalized.month.toString().padLeft(2, '0');
  final day = normalized.day.toString().padLeft(2, '0');
  return '${normalized.year}-$month-$day';
}

DateTime _parseDateOnlyUtc(String value) {
  final parts = value.split('-').map(int.parse).toList(growable: false);
  if (parts.length != 3) {
    return DateTime.parse(value).toUtc();
  }
  return DateTime.utc(parts[0], parts[1], parts[2]);
}

class AccountingApiConfig {
  const AccountingApiConfig({
    required this.baseUrl,
    required this.accessToken,
    required this.organizationId,
  });

  final String baseUrl;
  final String accessToken;
  final String organizationId;
}

class AccountingApiException implements Exception {
  const AccountingApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'AccountingApiException($statusCode): $message';
}

class AccountingApiClient {
  AccountingApiClient({required this.config, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final AccountingApiConfig config;
  final http.Client _httpClient;

  Future<List<AccountSummary>> listAccounts() async {
    final response = await _send('GET', '/accounts');
    return _decodeList(response, AccountSummary.fromJson);
  }

  Future<List<CustomerSummary>> listCustomers() async {
    final response = await _send('GET', '/customers');
    return _decodeList(response, CustomerSummary.fromJson);
  }

  Future<List<VendorSummary>> listVendors() async {
    final response = await _send('GET', '/vendors');
    return _decodeList(response, VendorSummary.fromJson);
  }

  Future<List<InvoiceSummary>> listInvoices() async {
    final response = await _send('GET', '/invoices');
    return _decodeList(response, InvoiceSummary.fromJson);
  }

  Future<List<ExpenseSummary>> listExpenses() async {
    final response = await _send('GET', '/expenses');
    return _decodeList(response, ExpenseSummary.fromJson);
  }

  Future<List<AttachmentSummary>> listAttachments() async {
    final response = await _send('GET', '/attachments');
    return _decodeList(response, AttachmentSummary.fromJson);
  }

  Future<AttachmentSummary> createAttachment(
    CreateAttachmentMetadata metadata,
  ) async {
    final response = await _send(
      'POST',
      '/attachments',
      body: metadata.toJson(),
    );
    return AttachmentSummary.fromJson(_decodeObject(response));
  }

  Future<AttachmentSummary> uploadAttachmentBytes({
    required String fileName,
    required List<int> bytes,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _organizationUri('/attachments/upload'),
    );
    request.headers.addAll(_requestHeaders());
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );

    final streamed = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamed);
    return AttachmentSummary.fromJson(_decodeObject(response));
  }

  Future<AttachmentDownload> downloadAttachment(String attachmentId) async {
    final response = await _send('GET', '/attachments/$attachmentId/download');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decodeJson(response);
    }
    return AttachmentDownload(
      bytes: response.bodyBytes,
      contentType:
          response.headers['content-type'] ?? 'application/octet-stream',
      fileName: _extractFileName(response.headers['content-disposition']),
    );
  }

  Future<List<TaxRateSummary>> listTaxRates() async {
    final response = await _send('GET', '/tax/rates');
    return _decodeList(response, TaxRateSummary.fromJson);
  }

  Future<List<TaxGroupSummary>> listTaxGroups() async {
    final response = await _send('GET', '/tax/groups');
    return _decodeList(response, TaxGroupSummary.fromJson);
  }

  Future<TaxCalculationResult> calculateTax(CalculateTaxRequest request) async {
    final response = await _send(
      'POST',
      '/tax/calculate',
      body: request.toJson(),
    );
    return TaxCalculationResult.fromJson(_decodeObject(response));
  }

  Future<ExpenseSummary> createExpense(CreateExpenseDraft draft) async {
    final response = await _send('POST', '/expenses', body: draft.toJson());
    return ExpenseSummary.fromJson(_decodeObject(response));
  }

  Future<ExpenseSummary> syncExpenseDraft(SyncOperation operation) {
    return createExpense(CreateExpenseDraft.fromSyncOperation(operation));
  }

  Future<ExpenseSummary> updateExpense(
    String expenseId,
    CreateExpenseDraft draft,
  ) async {
    final response = await _send(
      'PUT',
      '/expenses/$expenseId',
      body: draft.toJson(),
    );
    return ExpenseSummary.fromJson(_decodeObject(response));
  }

  Future<ExpenseSummary> syncExpenseDraftUpdate(SyncOperation operation) {
    final payload = operation.payload;
    return updateExpense(
      payload['expense_id']! as String,
      CreateExpenseDraft.fromSyncOperation(operation),
    );
  }

  Future<InvoiceSummary> postInvoice(String invoiceId) async {
    final response = await _send('POST', '/invoices/$invoiceId/post');
    return InvoiceSummary.fromJson(_decodeObject(response));
  }

  Future<InvoiceSummary> syncInvoicePost(SyncOperation operation) {
    return postInvoice(operation.payload['invoice_id']! as String);
  }

  Future<ExpenseSummary> postExpense(String expenseId) async {
    final response = await _send('POST', '/expenses/$expenseId/post');
    return ExpenseSummary.fromJson(_decodeObject(response));
  }

  Future<ExpenseSummary> syncExpensePost(SyncOperation operation) {
    return postExpense(operation.payload['expense_id']! as String);
  }

  Future<InvoiceSummary> createInvoice(CreateInvoiceDraft draft) async {
    final response = await _send('POST', '/invoices', body: draft.toJson());
    return InvoiceSummary.fromJson(_decodeObject(response));
  }

  Future<InvoiceSummary> syncInvoiceDraft(SyncOperation operation) {
    return createInvoice(CreateInvoiceDraft.fromSyncOperation(operation));
  }

  Future<InvoiceSummary> updateInvoice(
    String invoiceId,
    CreateInvoiceDraft draft,
  ) async {
    final response = await _send(
      'PUT',
      '/invoices/$invoiceId',
      body: draft.toJson(),
    );
    return InvoiceSummary.fromJson(_decodeObject(response));
  }

  Future<InvoiceSummary> syncInvoiceDraftUpdate(SyncOperation operation) {
    final payload = operation.payload;
    return updateInvoice(
      payload['invoice_id']! as String,
      CreateInvoiceDraft.fromSyncOperation(operation),
    );
  }

  Future<AttachmentSummary> syncAttachmentMetadata(SyncOperation operation) {
    return createAttachment(
      CreateAttachmentMetadata.fromSyncOperation(operation),
    );
  }

  Future<AttachmentSummary> syncAttachmentUpload(
    SyncOperation operation,
  ) async {
    final payload = operation.payload;
    final fileName = payload['file_name'] as String?;
    final localFilePath = payload['local_file_path']! as String;
    final file = File(localFilePath);
    return uploadAttachmentBytes(
      fileName: fileName ?? file.uri.pathSegments.last,
      bytes: await file.readAsBytes(),
    );
  }

  Future<List<InvestmentLotSummary>> listInvestmentLots() async {
    final response = await _send('GET', '/investments/lots');
    return _decodeList(response, InvestmentLotSummary.fromJson);
  }

  Future<InvestmentLotSummary> createInvestmentLot(
    CreateInvestmentLotRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/investments/lots',
      body: request.toJson(),
    );
    return InvestmentLotSummary.fromJson(_decodeObject(response));
  }

  Future<InvestmentLotSummary> syncInvestmentLot(SyncOperation operation) {
    return createInvestmentLot(
      CreateInvestmentLotRequest.fromSyncOperation(operation),
    );
  }

  Future<RealizedGainsReport> getRealizedGains({
    required DateTime from,
    required DateTime to,
  }) async {
    final params = Uri(
      queryParameters: {'from': _dateOnly(from), 'to': _dateOnly(to)},
    ).query;
    final response = await _send('GET', '/reports/realized-gains?$params');
    return RealizedGainsReport.fromJson(_decodeObject(response));
  }

  Future<TrialBalanceReport> getTrialBalance({required DateTime asOf}) async {
    final params = Uri(queryParameters: {'as_of': _dateOnly(asOf)}).query;
    final response = await _send('GET', '/reports/trial-balance?$params');
    return TrialBalanceReport.fromJson(_decodeObject(response));
  }

  Future<ProfitAndLossReport> getProfitAndLoss({
    required DateTime from,
    required DateTime to,
  }) async {
    final params = Uri(
      queryParameters: {'from': _dateOnly(from), 'to': _dateOnly(to)},
    ).query;
    final response = await _send('GET', '/reports/profit-and-loss?$params');
    return ProfitAndLossReport.fromJson(_decodeObject(response));
  }

  Future<BalanceSheetReport> getBalanceSheet({required DateTime asOf}) async {
    final params = Uri(queryParameters: {'as_of': _dateOnly(asOf)}).query;
    final response = await _send('GET', '/reports/balance-sheet?$params');
    return BalanceSheetReport.fromJson(_decodeObject(response));
  }

  Future<CashFlowReport> getCashFlow({
    required DateTime from,
    required DateTime to,
  }) async {
    final params = Uri(
      queryParameters: {'from': _dateOnly(from), 'to': _dateOnly(to)},
    ).query;
    final response = await _send('GET', '/reports/cash-flow?$params');
    return CashFlowReport.fromJson(_decodeObject(response));
  }

  Future<ARAgingReport> getARAging({required DateTime asOf}) async {
    final params = Uri(queryParameters: {'as_of': _dateOnly(asOf)}).query;
    final response = await _send('GET', '/reports/ar-aging?$params');
    return ARAgingReport.fromJson(_decodeObject(response));
  }

  Future<APAgingReport> getAPAging({required DateTime asOf}) async {
    final params = Uri(queryParameters: {'as_of': _dateOnly(asOf)}).query;
    final response = await _send('GET', '/reports/ap-aging?$params');
    return APAgingReport.fromJson(_decodeObject(response));
  }

  Future<TaxLiabilityReport> getTaxLiability({
    required DateTime from,
    required DateTime to,
  }) async {
    final params = Uri(
      queryParameters: {'from': _dateOnly(from), 'to': _dateOnly(to)},
    ).query;
    final response = await _send('GET', '/reports/tax-liability?$params');
    return TaxLiabilityReport.fromJson(_decodeObject(response));
  }

  Future<TaxSummaryReport> getTaxSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    final params = Uri(
      queryParameters: {'from': _dateOnly(from), 'to': _dateOnly(to)},
    ).query;
    final response = await _send('GET', '/reports/tax-summary?$params');
    return TaxSummaryReport.fromJson(_decodeObject(response));
  }

  Future<List<BudgetSummary>> listBudgets() async {
    final response = await _send('GET', '/budgets');
    return _decodeList(response, BudgetSummary.fromJson);
  }

  Future<BudgetVsActualReport> getBudgetVsActual({
    required String budgetId,
  }) async {
    final response = await _send('GET', '/budgets/$budgetId/vs-actual');
    return BudgetVsActualReport.fromJson(_decodeObject(response));
  }

  Future<List<InvestmentPriceSummary>> listInvestmentPrices() async {
    final response = await _send('GET', '/investments/prices');
    return _decodeList(response, InvestmentPriceSummary.fromJson);
  }

  Future<InvestmentPriceSummary> createInvestmentPrice(
    CreateInvestmentPriceRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/investments/prices',
      body: request.toJson(),
    );
    return InvestmentPriceSummary.fromJson(_decodeObject(response));
  }

  Future<InvestmentPriceSummary> syncInvestmentPrice(SyncOperation operation) {
    return createInvestmentPrice(
      CreateInvestmentPriceRequest.fromSyncOperation(operation),
    );
  }

  Future<List<InvestmentDividendSummary>> listInvestmentDividends() async {
    final response = await _send('GET', '/investments/dividends');
    return _decodeList(response, InvestmentDividendSummary.fromJson);
  }

  Future<InvestmentDividendSummary> createInvestmentDividend(
    CreateInvestmentDividendRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/investments/dividends',
      body: request.toJson(),
    );
    return InvestmentDividendSummary.fromJson(_decodeObject(response));
  }

  Future<InvestmentDividendSummary> syncInvestmentDividend(
    SyncOperation operation,
  ) {
    return createInvestmentDividend(
      CreateInvestmentDividendRequest.fromSyncOperation(operation),
    );
  }

  Future<List<InvestmentCorporateActionSummary>>
  listInvestmentCorporateActions() async {
    final response = await _send('GET', '/investments/corporate-actions');
    return _decodeList(response, InvestmentCorporateActionSummary.fromJson);
  }

  Future<InvestmentCorporateActionSummary> createInvestmentCorporateAction(
    CreateInvestmentCorporateActionRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/investments/corporate-actions',
      body: request.toJson(),
    );
    return InvestmentCorporateActionSummary.fromJson(_decodeObject(response));
  }

  Future<InvestmentCorporateActionSummary> syncInvestmentCorporateAction(
    SyncOperation operation,
  ) {
    return createInvestmentCorporateAction(
      CreateInvestmentCorporateActionRequest.fromSyncOperation(operation),
    );
  }

  Future<InvestmentPriceImportResult> importBrokerHoldingsPrices(
    ImportInvestmentPricesRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/investments/prices/import/broker-holdings',
      body: request.toJson(),
    );
    return InvestmentPriceImportResult.fromJson(_decodeObject(response));
  }

  Future<InvestmentPriceImportResult> importZerodhaHoldingsPrices(
    ImportInvestmentPricesRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/investments/prices/import/zerodha-holdings',
      body: request.toJson(),
    );
    return InvestmentPriceImportResult.fromJson(_decodeObject(response));
  }

  Future<InvestmentPriceImportResult> importGrowwHoldingsPrices(
    ImportInvestmentPricesRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/investments/prices/import/groww-holdings',
      body: request.toJson(),
    );
    return InvestmentPriceImportResult.fromJson(_decodeObject(response));
  }

  Future<InvestmentPriceImportResult> importUpstoxHoldingsPrices(
    ImportInvestmentPricesRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/investments/prices/import/upstox-holdings',
      body: request.toJson(),
    );
    return InvestmentPriceImportResult.fromJson(_decodeObject(response));
  }

  Future<InvestmentPriceImportResult> importAngelOneHoldingsPrices(
    ImportInvestmentPricesRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/investments/prices/import/angelone-holdings',
      body: request.toJson(),
    );
    return InvestmentPriceImportResult.fromJson(_decodeObject(response));
  }

  Future<InvestmentPriceImportResult> importDhanHoldingsPrices(
    ImportInvestmentPricesRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/investments/prices/import/dhan-holdings',
      body: request.toJson(),
    );
    return InvestmentPriceImportResult.fromJson(_decodeObject(response));
  }

  Future<InvestmentPriceImportResult> importICICIDirectHoldingsPrices(
    ImportInvestmentPricesRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/investments/prices/import/icicidirect-holdings',
      body: request.toJson(),
    );
    return InvestmentPriceImportResult.fromJson(_decodeObject(response));
  }

  Future<InvestmentPriceImportResult> importHDFCSkyHoldingsPrices(
    ImportInvestmentPricesRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/investments/prices/import/hdfcsky-holdings',
      body: request.toJson(),
    );
    return InvestmentPriceImportResult.fromJson(_decodeObject(response));
  }

  Future<InvestmentPriceImportResult> importKotakNeoHoldingsPrices(
    ImportInvestmentPricesRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/investments/prices/import/kotakneo-holdings',
      body: request.toJson(),
    );
    return InvestmentPriceImportResult.fromJson(_decodeObject(response));
  }

  Future<InvestmentPriceImportResult> importPaytmMoneyHoldingsPrices(
    ImportInvestmentPricesRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/investments/prices/import/paytmmoney-holdings',
      body: request.toJson(),
    );
    return InvestmentPriceImportResult.fromJson(_decodeObject(response));
  }

  Future<InvestmentPriceImportResult> importMotilalOswalHoldingsPrices(
    ImportInvestmentPricesRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/investments/prices/import/motilaloswal-holdings',
      body: request.toJson(),
    );
    return InvestmentPriceImportResult.fromJson(_decodeObject(response));
  }

  Future<InvestmentPriceImportResult> importSharekhanHoldingsPrices(
    ImportInvestmentPricesRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/investments/prices/import/sharekhan-holdings',
      body: request.toJson(),
    );
    return InvestmentPriceImportResult.fromJson(_decodeObject(response));
  }

  Future<InvestmentPriceImportResult> importFivePaisaHoldingsPrices(
    ImportInvestmentPricesRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/investments/prices/import/fivepaisa-holdings',
      body: request.toJson(),
    );
    return InvestmentPriceImportResult.fromJson(_decodeObject(response));
  }

  Future<InvestmentPriceImportResult> importAxisDirectHoldingsPrices(
    ImportInvestmentPricesRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/investments/prices/import/axisdirect-holdings',
      body: request.toJson(),
    );
    return InvestmentPriceImportResult.fromJson(_decodeObject(response));
  }

  Future<InvestmentPriceImportResult> syncBrokerHoldingsPriceImport(
    SyncOperation operation,
  ) {
    final request = ImportInvestmentPricesRequest.fromSyncOperation(operation);
    if (request.source == 'zerodha_holdings_csv') {
      return importZerodhaHoldingsPrices(request);
    }
    if (request.source == 'groww_holdings_csv') {
      return importGrowwHoldingsPrices(request);
    }
    if (request.source == 'upstox_holdings_csv') {
      return importUpstoxHoldingsPrices(request);
    }
    if (request.source == 'angelone_holdings_csv') {
      return importAngelOneHoldingsPrices(request);
    }
    if (request.source == 'dhan_holdings_csv') {
      return importDhanHoldingsPrices(request);
    }
    if (request.source == 'icicidirect_holdings_csv') {
      return importICICIDirectHoldingsPrices(request);
    }
    if (request.source == 'hdfcsky_holdings_csv') {
      return importHDFCSkyHoldingsPrices(request);
    }
    if (request.source == 'kotakneo_holdings_csv') {
      return importKotakNeoHoldingsPrices(request);
    }
    if (request.source == 'paytmmoney_holdings_csv') {
      return importPaytmMoneyHoldingsPrices(request);
    }
    if (request.source == 'motilaloswal_holdings_csv') {
      return importMotilalOswalHoldingsPrices(request);
    }
    if (request.source == 'sharekhan_holdings_csv') {
      return importSharekhanHoldingsPrices(request);
    }
    if (request.source == 'fivepaisa_holdings_csv') {
      return importFivePaisaHoldingsPrices(request);
    }
    if (request.source == 'axisdirect_holdings_csv') {
      return importAxisDirectHoldingsPrices(request);
    }
    return importBrokerHoldingsPrices(request);
  }

  Future<CustomerPaymentSummary> recordCustomerPayment(
    String invoiceId,
    RecordPaymentRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/invoices/$invoiceId/payments',
      body: request.toJson(),
    );
    return CustomerPaymentSummary.fromJson(_decodeObject(response));
  }

  Future<CustomerPaymentSummary> syncCustomerPayment(SyncOperation operation) {
    final payload = operation.payload;
    return recordCustomerPayment(
      payload['invoice_id']! as String,
      RecordPaymentRequest.fromSyncOperation(operation),
    );
  }

  Future<VendorPaymentSummary> recordVendorPayment(
    String billId,
    RecordPaymentRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/bills/$billId/payments',
      body: request.toJson(),
    );
    return VendorPaymentSummary.fromJson(_decodeObject(response));
  }

  Future<VendorPaymentSummary> syncVendorPayment(SyncOperation operation) {
    final payload = operation.payload;
    return recordVendorPayment(
      payload['bill_id']! as String,
      RecordPaymentRequest.fromSyncOperation(operation),
    );
  }

  Future<EstimateSummary> updateEstimateStatus(
    String estimateId,
    UpdateStatusRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/estimates/$estimateId/status',
      body: request.toJson(),
    );
    return EstimateSummary.fromJson(_decodeObject(response));
  }

  Future<EstimateSummary> syncEstimateStatusUpdate(SyncOperation operation) {
    final payload = operation.payload;
    return updateEstimateStatus(
      payload['estimate_id']! as String,
      UpdateStatusRequest.fromSyncOperation(operation),
    );
  }

  Future<PurchaseOrderSummary> updatePurchaseOrderStatus(
    String purchaseOrderId,
    UpdateStatusRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/purchase-orders/$purchaseOrderId/status',
      body: request.toJson(),
    );
    return PurchaseOrderSummary.fromJson(_decodeObject(response));
  }

  Future<PurchaseOrderSummary> syncPurchaseOrderStatusUpdate(
    SyncOperation operation,
  ) {
    final payload = operation.payload;
    return updatePurchaseOrderStatus(
      payload['purchase_order_id']! as String,
      UpdateStatusRequest.fromSyncOperation(operation),
    );
  }

  Future<InvoiceSummary> convertEstimateToInvoice(
    String estimateId,
    ConvertEstimateToInvoiceRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/estimates/$estimateId/convert-to-invoice',
      body: request.toJson(),
    );
    return InvoiceSummary.fromJson(_decodeObject(response));
  }

  Future<InvoiceSummary> syncEstimateConversion(SyncOperation operation) {
    final payload = operation.payload;
    return convertEstimateToInvoice(
      payload['estimate_id']! as String,
      ConvertEstimateToInvoiceRequest.fromSyncOperation(operation),
    );
  }

  Future<BillSummary> convertPurchaseOrderToBill(
    String purchaseOrderId,
    ConvertPurchaseOrderToBillRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/purchase-orders/$purchaseOrderId/convert-to-bill',
      body: request.toJson(),
    );
    return BillSummary.fromJson(_decodeObject(response));
  }

  Future<BillSummary> syncPurchaseOrderConversion(SyncOperation operation) {
    final payload = operation.payload;
    return convertPurchaseOrderToBill(
      payload['purchase_order_id']! as String,
      ConvertPurchaseOrderToBillRequest.fromSyncOperation(operation),
    );
  }

  Future<BillSummary> postBill(String billId) async {
    final response = await _send('POST', '/bills/$billId/post');
    return BillSummary.fromJson(_decodeObject(response));
  }

  Future<BillSummary> syncBillPost(SyncOperation operation) {
    return postBill(operation.payload['bill_id']! as String);
  }

  Future<CreditNoteSummary> postCreditNote(String creditNoteId) async {
    final response = await _send('POST', '/credit-notes/$creditNoteId/post');
    return CreditNoteSummary.fromJson(_decodeObject(response));
  }

  Future<CreditNoteSummary> syncCreditNotePost(SyncOperation operation) {
    return postCreditNote(operation.payload['credit_note_id']! as String);
  }

  Future<InvestmentValuationReport> getInvestmentValuation({
    required DateTime asOf,
  }) async {
    final params = Uri(queryParameters: {'as_of': _dateOnly(asOf)}).query;
    final response = await _send(
      'GET',
      '/reports/investment-valuation?$params',
    );
    return InvestmentValuationReport.fromJson(_decodeObject(response));
  }

  Future<AverageCostSaleResult> sellAverageCost(
    SellAverageCostRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/investments/average-cost-sales',
      body: request.toJson(),
    );
    return AverageCostSaleResult.fromJson(_decodeObject(response));
  }

  Future<AverageCostSaleResult> syncAverageCostSale(SyncOperation operation) {
    return sellAverageCost(SellAverageCostRequest.fromSyncOperation(operation));
  }

  Future<InvestmentDispositionSummary> sellInvestmentLot(
    String lotId,
    SellInvestmentLotRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/investments/lots/$lotId/sell',
      body: request.toJson(),
    );
    return InvestmentDispositionSummary.fromJson(_decodeObject(response));
  }

  Future<InvestmentDispositionSummary> syncInvestmentLotSale(
    SyncOperation operation,
  ) {
    final payload = operation.payload;
    return sellInvestmentLot(
      payload['lot_id']! as String,
      SellInvestmentLotRequest.fromSyncOperation(operation),
    );
  }

  Future<BankStatementImportSummary> importStructuredBankStatement(
    ImportBankStatementRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/bank-statements/import',
      body: request.toJson(),
    );
    return BankStatementImportSummary.fromJson(_decodeObject(response));
  }

  Future<BankStatementImportSummary> syncStructuredBankStatementImport(
    SyncOperation operation,
  ) {
    return importStructuredBankStatement(
      ImportBankStatementRequest.fromSyncOperation(operation),
    );
  }

  Future<BankStatementImportSummary> importQifBankStatement(
    ImportQifBankStatementRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/bank-statements/import/qif',
      body: request.toJson(),
    );
    return BankStatementImportSummary.fromJson(_decodeObject(response));
  }

  Future<BankStatementImportSummary> syncQifBankStatementImport(
    SyncOperation operation,
  ) {
    return importQifBankStatement(
      ImportQifBankStatementRequest.fromSyncOperation(operation),
    );
  }

  Future<BankStatementImportSummary> importOfxBankStatement(
    ImportOfxBankStatementRequest request,
  ) async {
    final response = await _send(
      'POST',
      '/bank-statements/import/ofx',
      body: request.toJson(),
    );
    return BankStatementImportSummary.fromJson(_decodeObject(response));
  }

  Future<BankStatementImportSummary> syncOfxBankStatementImport(
    SyncOperation operation,
  ) {
    return importOfxBankStatement(
      ImportOfxBankStatementRequest.fromSyncOperation(operation),
    );
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) {
    final uri = _organizationUri(path);
    final headers = _requestHeaders(jsonBody: body != null);

    if (method == 'GET') {
      return _httpClient.get(uri, headers: headers);
    }
    if (method == 'POST') {
      return _httpClient.post(uri, headers: headers, body: jsonEncode(body));
    }
    if (method == 'PUT') {
      return _httpClient.put(uri, headers: headers, body: jsonEncode(body));
    }
    throw UnsupportedError('Unsupported API method: $method');
  }

  Uri _organizationUri(String path) {
    return Uri.parse(
      '${config.baseUrl}/organizations/${config.organizationId}$path',
    );
  }

  Map<String, String> _requestHeaders({bool jsonBody = false}) {
    return {
      'Authorization': 'Bearer ${config.accessToken}',
      'Accept': 'application/json',
      if (jsonBody) 'Content-Type': 'application/json',
    };
  }

  List<T> _decodeList<T>(
    http.Response response,
    T Function(Map<String, Object?> json) decoder,
  ) {
    final value = _decodeJson(response);
    if (value is! List) {
      throw const FormatException('Expected a JSON array response');
    }
    return value
        .cast<Map<String, Object?>>()
        .map(decoder)
        .toList(growable: false);
  }

  Map<String, Object?> _decodeObject(http.Response response) {
    final value = _decodeJson(response);
    if (value is! Map<String, Object?>) {
      throw const FormatException('Expected a JSON object response');
    }
    return value;
  }

  Object? _decodeJson(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AccountingApiException(
        response.statusCode,
        _extractErrorMessage(response.body),
      );
    }
    if (response.body.isEmpty) {
      return null;
    }
    return jsonDecode(response.body) as Object?;
  }

  String _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) {
        final error = decoded['error'];
        if (error is Map<String, Object?> && error['message'] is String) {
          return error['message']! as String;
        }
      }
    } on FormatException {
      return body;
    }
    return body.isEmpty ? 'API request failed' : body;
  }

  String? _extractFileName(String? contentDisposition) {
    if (contentDisposition == null) {
      return null;
    }
    final match = RegExp(
      r'filename="?([^";]+)"?',
    ).firstMatch(contentDisposition);
    return match?.group(1);
  }
}

class AccountSummary {
  const AccountSummary({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.currency,
    required this.isActive,
  });

  final String id;
  final String code;
  final String name;
  final String type;
  final String currency;
  final bool isActive;

  factory AccountSummary.fromJson(Map<String, Object?> json) {
    return AccountSummary(
      id: json['id']! as String,
      code: json['code']! as String,
      name: json['name']! as String,
      type: json['type']! as String,
      currency: json['currency'] as String? ?? 'INR',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'type': type,
      'currency': currency,
      'is_active': isActive,
    };
  }
}

class CustomerSummary {
  const CustomerSummary({
    required this.id,
    required this.organizationId,
    required this.displayName,
    required this.isActive,
    this.email = '',
    this.phone = '',
    this.billingAddress = '',
    this.gstin = '',
  });

  final String id;
  final String organizationId;
  final String displayName;
  final String email;
  final String phone;
  final String billingAddress;
  final String gstin;
  final bool isActive;

  factory CustomerSummary.fromJson(Map<String, Object?> json) {
    return CustomerSummary(
      id: json['id']! as String,
      organizationId: json['organization_id'] as String? ?? '',
      displayName: json['display_name']! as String,
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      billingAddress: json['billing_address'] as String? ?? '',
      gstin: json['gstin'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'display_name': displayName,
      'email': email,
      'phone': phone,
      'billing_address': billingAddress,
      'gstin': gstin,
      'is_active': isActive,
    };
  }
}

class VendorSummary {
  const VendorSummary({
    required this.id,
    required this.organizationId,
    required this.displayName,
    required this.isActive,
    this.email = '',
    this.phone = '',
    this.billingAddress = '',
    this.gstin = '',
  });

  final String id;
  final String organizationId;
  final String displayName;
  final String email;
  final String phone;
  final String billingAddress;
  final String gstin;
  final bool isActive;

  factory VendorSummary.fromJson(Map<String, Object?> json) {
    return VendorSummary(
      id: json['id']! as String,
      organizationId: json['organization_id'] as String? ?? '',
      displayName: json['display_name']! as String,
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      billingAddress: json['billing_address'] as String? ?? '',
      gstin: json['gstin'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'display_name': displayName,
      'email': email,
      'phone': phone,
      'billing_address': billingAddress,
      'gstin': gstin,
      'is_active': isActive,
    };
  }
}

class InvoiceSummary {
  const InvoiceSummary({
    required this.id,
    required this.invoiceNumber,
    required this.status,
    required this.subtotalMinor,
    required this.taxTotalMinor,
    required this.totalMinor,
    required this.currency,
    this.pdfAttachmentId,
    this.lines = const [],
  });

  final String id;
  final String invoiceNumber;
  final String status;
  final int subtotalMinor;
  final int taxTotalMinor;
  final int totalMinor;
  final String currency;
  final String? pdfAttachmentId;
  final List<InvoiceLineSummary> lines;

  factory InvoiceSummary.fromJson(Map<String, Object?> json) {
    return InvoiceSummary(
      id: json['id']! as String,
      invoiceNumber: json['invoice_number']! as String,
      status: json['status']! as String,
      subtotalMinor: json['subtotal_minor'] as int? ?? 0,
      taxTotalMinor: json['tax_total_minor'] as int? ?? 0,
      totalMinor: json['total_minor']! as int,
      currency: json['currency'] as String? ?? 'INR',
      pdfAttachmentId: json['pdf_attachment_id'] as String?,
      lines: (json['lines'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .map(InvoiceLineSummary.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'status': status,
      'subtotal_minor': subtotalMinor,
      'tax_total_minor': taxTotalMinor,
      'total_minor': totalMinor,
      'currency': currency,
      if (pdfAttachmentId != null) 'pdf_attachment_id': pdfAttachmentId,
      'lines': lines.map((line) => line.toJson()).toList(growable: false),
    };
  }
}

class InvoiceLineSummary {
  const InvoiceLineSummary({
    required this.id,
    required this.description,
    required this.quantityMillis,
    required this.unitPriceMinor,
    required this.lineSubtotalMinor,
    required this.taxAmountMinor,
    required this.lineTotalMinor,
    required this.incomeAccountId,
    this.taxRateId,
    this.taxGroupId,
  });

  final String id;
  final String description;
  final int quantityMillis;
  final int unitPriceMinor;
  final int lineSubtotalMinor;
  final int taxAmountMinor;
  final int lineTotalMinor;
  final String incomeAccountId;
  final String? taxRateId;
  final String? taxGroupId;

  factory InvoiceLineSummary.fromJson(Map<String, Object?> json) {
    return InvoiceLineSummary(
      id: json['id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      quantityMillis: json['quantity_millis'] as int? ?? 1000,
      unitPriceMinor: json['unit_price_minor'] as int? ?? 0,
      lineSubtotalMinor: json['line_subtotal_minor'] as int? ?? 0,
      taxAmountMinor: json['tax_amount_minor'] as int? ?? 0,
      lineTotalMinor: json['line_total_minor'] as int? ?? 0,
      incomeAccountId: json['income_account_id'] as String? ?? '',
      taxRateId: json['tax_rate_id'] as String?,
      taxGroupId: json['tax_group_id'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'description': description,
      'quantity_millis': quantityMillis,
      'unit_price_minor': unitPriceMinor,
      'line_subtotal_minor': lineSubtotalMinor,
      'tax_amount_minor': taxAmountMinor,
      'line_total_minor': lineTotalMinor,
      'income_account_id': incomeAccountId,
      if (taxRateId != null) 'tax_rate_id': taxRateId,
      if (taxGroupId != null) 'tax_group_id': taxGroupId,
    };
  }
}

class ExpenseSummary {
  const ExpenseSummary({
    required this.id,
    required this.expenseNumber,
    required this.status,
    required this.totalMinor,
    required this.currency,
  });

  final String id;
  final String expenseNumber;
  final String status;
  final int totalMinor;
  final String currency;

  factory ExpenseSummary.fromJson(Map<String, Object?> json) {
    return ExpenseSummary(
      id: json['id']! as String,
      expenseNumber: json['expense_number']! as String,
      status: json['status']! as String,
      totalMinor: json['total_minor']! as int,
      currency: json['currency'] as String? ?? 'INR',
    );
  }
}

class BillSummary {
  const BillSummary({
    required this.id,
    required this.billNumber,
    required this.status,
    required this.totalMinor,
    required this.currency,
  });

  final String id;
  final String billNumber;
  final String status;
  final int totalMinor;
  final String currency;

  factory BillSummary.fromJson(Map<String, Object?> json) {
    return BillSummary(
      id: json['id']! as String,
      billNumber: json['bill_number']! as String,
      status: json['status']! as String,
      totalMinor: json['total_minor']! as int,
      currency: json['currency'] as String? ?? 'INR',
    );
  }
}

class CreditNoteSummary {
  const CreditNoteSummary({
    required this.id,
    required this.creditNoteNumber,
    required this.status,
    required this.totalMinor,
    required this.currency,
  });

  final String id;
  final String creditNoteNumber;
  final String status;
  final int totalMinor;
  final String currency;

  factory CreditNoteSummary.fromJson(Map<String, Object?> json) {
    return CreditNoteSummary(
      id: json['id']! as String,
      creditNoteNumber: json['credit_note_number']! as String,
      status: json['status']! as String,
      totalMinor: json['total_minor']! as int,
      currency: json['currency'] as String? ?? 'INR',
    );
  }
}

class BankStatementImportSummary {
  const BankStatementImportSummary({
    required this.id,
    required this.accountId,
    required this.format,
    required this.status,
    required this.lineCount,
    this.fileName = '',
    this.errorMessage,
    this.lines = const [],
  });

  final String id;
  final String accountId;
  final String fileName;
  final String format;
  final String status;
  final int lineCount;
  final String? errorMessage;
  final List<BankStatementLineSummary> lines;

  factory BankStatementImportSummary.fromJson(Map<String, Object?> json) {
    return BankStatementImportSummary(
      id: json['id']! as String,
      accountId: json['account_id']! as String,
      fileName: json['file_name'] as String? ?? '',
      format: json['format'] as String? ?? 'csv',
      status: json['status'] as String? ?? 'completed',
      lineCount: json['line_count'] as int? ?? 0,
      errorMessage: json['error_message'] as String?,
      lines: (json['lines'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .map(BankStatementLineSummary.fromJson)
          .toList(growable: false),
    );
  }
}

class BankStatementLineSummary {
  const BankStatementLineSummary({
    required this.id,
    required this.accountId,
    required this.postedDate,
    required this.amountMinor,
    required this.isDuplicate,
    this.description = '',
    this.reference = '',
    this.matchedSplitId,
    this.duplicateOfId,
  });

  final String id;
  final String accountId;
  final DateTime postedDate;
  final int amountMinor;
  final bool isDuplicate;
  final String description;
  final String reference;
  final String? matchedSplitId;
  final String? duplicateOfId;

  factory BankStatementLineSummary.fromJson(Map<String, Object?> json) {
    return BankStatementLineSummary(
      id: json['id']! as String,
      accountId: json['account_id']! as String,
      postedDate: DateTime.parse(json['posted_date']! as String),
      amountMinor: json['amount_minor'] as int? ?? 0,
      isDuplicate: json['is_duplicate'] as bool? ?? false,
      description: json['description'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      matchedSplitId: json['matched_split_id'] as String?,
      duplicateOfId: json['duplicate_of_id'] as String?,
    );
  }
}

class InvestmentLotSummary {
  const InvestmentLotSummary({
    required this.id,
    required this.accountId,
    required this.symbol,
    required this.acquisitionDate,
    required this.quantityMillis,
    required this.remainingQuantityMillis,
    required this.costBasisMinor,
    required this.currency,
    required this.costMethod,
    this.securityName = '',
    this.notes = '',
  });

  final String id;
  final String accountId;
  final String symbol;
  final String securityName;
  final DateTime acquisitionDate;
  final int quantityMillis;
  final int remainingQuantityMillis;
  final int costBasisMinor;
  final String currency;
  final String costMethod;
  final String notes;

  factory InvestmentLotSummary.fromJson(Map<String, Object?> json) {
    return InvestmentLotSummary(
      id: json['id']! as String,
      accountId: json['account_id']! as String,
      symbol: json['symbol']! as String,
      securityName: json['security_name'] as String? ?? '',
      acquisitionDate: DateTime.parse(json['acquisition_date']! as String),
      quantityMillis: json['quantity_millis'] as int? ?? 0,
      remainingQuantityMillis: json['remaining_quantity_millis'] as int? ?? 0,
      costBasisMinor: json['cost_basis_minor'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      costMethod: json['cost_method'] as String? ?? 'specific_lot',
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'symbol': symbol,
      'security_name': securityName,
      'acquisition_date': _dateOnly(acquisitionDate),
      'quantity_millis': quantityMillis,
      'remaining_quantity_millis': remainingQuantityMillis,
      'cost_basis_minor': costBasisMinor,
      'currency': currency,
      'cost_method': costMethod,
      'notes': notes,
    };
  }
}

class CreateInvestmentLotRequest {
  const CreateInvestmentLotRequest({
    required this.accountId,
    required this.symbol,
    required this.acquisitionDate,
    required this.quantityMillis,
    required this.costBasisMinor,
    this.securityName = '',
    this.currency = 'INR',
    this.costMethod = 'specific_lot',
    this.notes = '',
  });

  final String accountId;
  final String symbol;
  final String securityName;
  final DateTime acquisitionDate;
  final int quantityMillis;
  final int costBasisMinor;
  final String currency;
  final String costMethod;
  final String notes;

  factory CreateInvestmentLotRequest.fromSyncOperation(
    SyncOperation operation,
  ) {
    final payload = operation.payload;
    return CreateInvestmentLotRequest(
      accountId: payload['account_id']! as String,
      symbol: payload['symbol']! as String,
      securityName: payload['security_name'] as String? ?? '',
      acquisitionDate: _parseDateOnlyUtc(
        payload['acquisition_date']! as String,
      ),
      quantityMillis: payload['quantity_millis']! as int,
      costBasisMinor: payload['cost_basis_minor']! as int,
      currency: payload['currency'] as String? ?? 'INR',
      costMethod: payload['cost_method'] as String? ?? 'specific_lot',
      notes: payload['notes'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'account_id': accountId,
      'symbol': symbol,
      if (securityName.isNotEmpty) 'security_name': securityName,
      'acquisition_date': _dateOnly(acquisitionDate),
      'quantity_millis': quantityMillis,
      'cost_basis_minor': costBasisMinor,
      'currency': currency,
      'cost_method': costMethod,
      if (notes.isNotEmpty) 'notes': notes,
    };
  }
}

class InvestmentDispositionSummary {
  const InvestmentDispositionSummary({
    required this.id,
    required this.investmentLotId,
    required this.saleDate,
    required this.quantityMillis,
    required this.proceedsMinor,
    required this.allocatedCostBasisMinor,
    required this.realizedGainLossMinor,
    required this.currency,
    this.notes = '',
  });

  final String id;
  final String investmentLotId;
  final DateTime saleDate;
  final int quantityMillis;
  final int proceedsMinor;
  final int allocatedCostBasisMinor;
  final int realizedGainLossMinor;
  final String currency;
  final String notes;

  factory InvestmentDispositionSummary.fromJson(Map<String, Object?> json) {
    return InvestmentDispositionSummary(
      id: json['id']! as String,
      investmentLotId: json['investment_lot_id']! as String,
      saleDate: DateTime.parse(json['sale_date']! as String),
      quantityMillis: json['quantity_millis'] as int? ?? 0,
      proceedsMinor: json['proceeds_minor'] as int? ?? 0,
      allocatedCostBasisMinor: json['allocated_cost_basis_minor'] as int? ?? 0,
      realizedGainLossMinor: json['realized_gain_loss_minor'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'investment_lot_id': investmentLotId,
      'sale_date': _dateOnly(saleDate),
      'quantity_millis': quantityMillis,
      'proceeds_minor': proceedsMinor,
      'allocated_cost_basis_minor': allocatedCostBasisMinor,
      'realized_gain_loss_minor': realizedGainLossMinor,
      'currency': currency,
      'notes': notes,
    };
  }
}

class InvestmentDividendSummary {
  const InvestmentDividendSummary({
    required this.id,
    required this.accountId,
    required this.symbol,
    required this.dividendDate,
    required this.amountMinor,
    required this.currency,
    this.cashAccountId,
    this.incomeAccountId,
    this.journalTransactionId,
    this.notes = '',
  });

  final String id;
  final String accountId;
  final String symbol;
  final DateTime dividendDate;
  final int amountMinor;
  final String currency;
  final String? cashAccountId;
  final String? incomeAccountId;
  final String? journalTransactionId;
  final String notes;

  factory InvestmentDividendSummary.fromJson(Map<String, Object?> json) {
    return InvestmentDividendSummary(
      id: json['id']! as String,
      accountId: json['account_id']! as String,
      symbol: json['symbol']! as String,
      dividendDate: DateTime.parse(json['dividend_date']! as String),
      amountMinor: json['amount_minor'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      cashAccountId: json['cash_account_id'] as String?,
      incomeAccountId: json['income_account_id'] as String?,
      journalTransactionId: json['journal_transaction_id'] as String?,
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'symbol': symbol,
      'dividend_date': _dateOnly(dividendDate),
      'amount_minor': amountMinor,
      'currency': currency,
      if (cashAccountId != null) 'cash_account_id': cashAccountId,
      if (incomeAccountId != null) 'income_account_id': incomeAccountId,
      if (journalTransactionId != null)
        'journal_transaction_id': journalTransactionId,
      'notes': notes,
    };
  }
}

class CreateInvestmentDividendRequest {
  const CreateInvestmentDividendRequest({
    required this.accountId,
    required this.symbol,
    required this.dividendDate,
    required this.amountMinor,
    this.currency = 'INR',
    this.cashAccountId,
    this.incomeAccountId,
    this.notes = '',
  });

  final String accountId;
  final String symbol;
  final DateTime dividendDate;
  final int amountMinor;
  final String currency;
  final String? cashAccountId;
  final String? incomeAccountId;
  final String notes;

  factory CreateInvestmentDividendRequest.fromSyncOperation(
    SyncOperation operation,
  ) {
    final payload = operation.payload;
    return CreateInvestmentDividendRequest(
      accountId: payload['account_id']! as String,
      symbol: payload['symbol']! as String,
      dividendDate: _parseDateOnlyUtc(payload['dividend_date']! as String),
      amountMinor: payload['amount_minor']! as int,
      currency: payload['currency'] as String? ?? 'INR',
      cashAccountId: payload['cash_account_id'] as String?,
      incomeAccountId: payload['income_account_id'] as String?,
      notes: payload['notes'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'account_id': accountId,
      'symbol': symbol,
      'dividend_date': _dateOnly(dividendDate),
      'amount_minor': amountMinor,
      'currency': currency,
      if (cashAccountId != null) 'cash_account_id': cashAccountId,
      if (incomeAccountId != null) 'income_account_id': incomeAccountId,
      if (notes.isNotEmpty) 'notes': notes,
    };
  }
}

class InvestmentCorporateActionSummary {
  const InvestmentCorporateActionSummary({
    required this.id,
    required this.accountId,
    required this.symbol,
    required this.actionType,
    required this.actionDate,
    required this.ratioNumerator,
    required this.ratioDenominator,
    required this.affectedLots,
    required this.quantityDeltaMillis,
    required this.costBasisDeltaMinor,
    this.notes = '',
  });

  final String id;
  final String accountId;
  final String symbol;
  final String actionType;
  final DateTime actionDate;
  final int ratioNumerator;
  final int ratioDenominator;
  final int affectedLots;
  final int quantityDeltaMillis;
  final int costBasisDeltaMinor;
  final String notes;

  factory InvestmentCorporateActionSummary.fromJson(Map<String, Object?> json) {
    return InvestmentCorporateActionSummary(
      id: json['id']! as String,
      accountId: json['account_id']! as String,
      symbol: json['symbol']! as String,
      actionType: json['action_type']! as String,
      actionDate: DateTime.parse(json['action_date']! as String),
      ratioNumerator: json['ratio_numerator'] as int? ?? 0,
      ratioDenominator: json['ratio_denominator'] as int? ?? 0,
      affectedLots: json['affected_lots'] as int? ?? 0,
      quantityDeltaMillis: json['quantity_delta_millis'] as int? ?? 0,
      costBasisDeltaMinor: json['cost_basis_delta_minor'] as int? ?? 0,
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'symbol': symbol,
      'action_type': actionType,
      'action_date': _dateOnly(actionDate),
      'ratio_numerator': ratioNumerator,
      'ratio_denominator': ratioDenominator,
      'affected_lots': affectedLots,
      'quantity_delta_millis': quantityDeltaMillis,
      'cost_basis_delta_minor': costBasisDeltaMinor,
      'notes': notes,
    };
  }
}

class CreateInvestmentCorporateActionRequest {
  const CreateInvestmentCorporateActionRequest({
    required this.accountId,
    required this.symbol,
    required this.actionType,
    required this.actionDate,
    required this.ratioNumerator,
    required this.ratioDenominator,
    this.notes = '',
  });

  final String accountId;
  final String symbol;
  final String actionType;
  final DateTime actionDate;
  final int ratioNumerator;
  final int ratioDenominator;
  final String notes;

  factory CreateInvestmentCorporateActionRequest.fromSyncOperation(
    SyncOperation operation,
  ) {
    final payload = operation.payload;
    return CreateInvestmentCorporateActionRequest(
      accountId: payload['account_id']! as String,
      symbol: payload['symbol']! as String,
      actionType: payload['action_type']! as String,
      actionDate: _parseDateOnlyUtc(payload['action_date']! as String),
      ratioNumerator: payload['ratio_numerator']! as int,
      ratioDenominator: payload['ratio_denominator']! as int,
      notes: payload['notes'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'account_id': accountId,
      'symbol': symbol,
      'action_type': actionType,
      'action_date': _dateOnly(actionDate),
      'ratio_numerator': ratioNumerator,
      'ratio_denominator': ratioDenominator,
      if (notes.isNotEmpty) 'notes': notes,
    };
  }
}

class RealizedGainsReport {
  const RealizedGainsReport({
    required this.fromDate,
    required this.toDate,
    required this.rows,
    required this.totalProceedsMinor,
    required this.totalCostBasisMinor,
    required this.totalGainLossMinor,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final List<InvestmentDispositionSummary> rows;
  final int totalProceedsMinor;
  final int totalCostBasisMinor;
  final int totalGainLossMinor;

  factory RealizedGainsReport.fromJson(Map<String, Object?> json) {
    return RealizedGainsReport(
      fromDate: DateTime.parse(json['from_date']! as String),
      toDate: DateTime.parse(json['to_date']! as String),
      rows: (json['rows'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .map(InvestmentDispositionSummary.fromJson)
          .toList(growable: false),
      totalProceedsMinor: json['total_proceeds_minor'] as int? ?? 0,
      totalCostBasisMinor: json['total_cost_basis_minor'] as int? ?? 0,
      totalGainLossMinor: json['total_gain_loss_minor'] as int? ?? 0,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'from_date': _dateOnly(fromDate),
      'to_date': _dateOnly(toDate),
      'rows': rows.map((row) => row.toJson()).toList(growable: false),
      'total_proceeds_minor': totalProceedsMinor,
      'total_cost_basis_minor': totalCostBasisMinor,
      'total_gain_loss_minor': totalGainLossMinor,
    };
  }
}

class ReportRowSummary {
  const ReportRowSummary({
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    required this.debitMinor,
    required this.creditMinor,
    required this.balanceMinor,
  });

  final String accountId;
  final String accountCode;
  final String accountName;
  final String accountType;
  final int debitMinor;
  final int creditMinor;
  final int balanceMinor;

  factory ReportRowSummary.fromJson(Map<String, Object?> json) {
    return ReportRowSummary(
      accountId: json['account_id']! as String,
      accountCode: json['account_code'] as String? ?? '',
      accountName: json['account_name'] as String? ?? '',
      accountType: json['account_type'] as String? ?? '',
      debitMinor: json['debit_minor'] as int? ?? 0,
      creditMinor: json['credit_minor'] as int? ?? 0,
      balanceMinor: json['balance_minor'] as int? ?? 0,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'account_id': accountId,
      'account_code': accountCode,
      'account_name': accountName,
      'account_type': accountType,
      'debit_minor': debitMinor,
      'credit_minor': creditMinor,
      'balance_minor': balanceMinor,
    };
  }
}

class TrialBalanceReport {
  const TrialBalanceReport({
    required this.asOfDate,
    required this.rows,
    required this.totalDebitMinor,
    required this.totalCreditMinor,
    required this.balanced,
  });

  final DateTime asOfDate;
  final List<ReportRowSummary> rows;
  final int totalDebitMinor;
  final int totalCreditMinor;
  final bool balanced;

  factory TrialBalanceReport.fromJson(Map<String, Object?> json) {
    return TrialBalanceReport(
      asOfDate: DateTime.parse(json['as_of_date']! as String),
      rows: (json['rows'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .map(ReportRowSummary.fromJson)
          .toList(growable: false),
      totalDebitMinor: json['total_debit_minor'] as int? ?? 0,
      totalCreditMinor: json['total_credit_minor'] as int? ?? 0,
      balanced: json['balanced'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'as_of_date': _dateOnly(asOfDate),
      'rows': rows.map((row) => row.toJson()).toList(growable: false),
      'total_debit_minor': totalDebitMinor,
      'total_credit_minor': totalCreditMinor,
      'balanced': balanced,
    };
  }
}

class ProfitAndLossReport {
  const ProfitAndLossReport({
    required this.fromDate,
    required this.toDate,
    required this.incomeRows,
    required this.expenseRows,
    required this.totalIncomeMinor,
    required this.totalExpenseMinor,
    required this.netIncomeMinor,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final List<ReportRowSummary> incomeRows;
  final List<ReportRowSummary> expenseRows;
  final int totalIncomeMinor;
  final int totalExpenseMinor;
  final int netIncomeMinor;

  factory ProfitAndLossReport.fromJson(Map<String, Object?> json) {
    return ProfitAndLossReport(
      fromDate: DateTime.parse(json['from_date']! as String),
      toDate: DateTime.parse(json['to_date']! as String),
      incomeRows: (json['income_rows'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .map(ReportRowSummary.fromJson)
          .toList(growable: false),
      expenseRows: (json['expense_rows'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .map(ReportRowSummary.fromJson)
          .toList(growable: false),
      totalIncomeMinor: json['total_income_minor'] as int? ?? 0,
      totalExpenseMinor: json['total_expense_minor'] as int? ?? 0,
      netIncomeMinor: json['net_income_minor'] as int? ?? 0,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'from_date': _dateOnly(fromDate),
      'to_date': _dateOnly(toDate),
      'income_rows': incomeRows
          .map((row) => row.toJson())
          .toList(growable: false),
      'expense_rows': expenseRows
          .map((row) => row.toJson())
          .toList(growable: false),
      'total_income_minor': totalIncomeMinor,
      'total_expense_minor': totalExpenseMinor,
      'net_income_minor': netIncomeMinor,
    };
  }
}

class BalanceSheetReport {
  const BalanceSheetReport({
    required this.asOfDate,
    required this.assetRows,
    required this.liabilityRows,
    required this.equityRows,
    required this.totalAssetsMinor,
    required this.totalLiabilitiesMinor,
    required this.totalEquityMinor,
    required this.balanced,
  });

  final DateTime asOfDate;
  final List<ReportRowSummary> assetRows;
  final List<ReportRowSummary> liabilityRows;
  final List<ReportRowSummary> equityRows;
  final int totalAssetsMinor;
  final int totalLiabilitiesMinor;
  final int totalEquityMinor;
  final bool balanced;

  factory BalanceSheetReport.fromJson(Map<String, Object?> json) {
    return BalanceSheetReport(
      asOfDate: DateTime.parse(json['as_of_date']! as String),
      assetRows: (json['asset_rows'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .map(ReportRowSummary.fromJson)
          .toList(growable: false),
      liabilityRows: (json['liability_rows'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .map(ReportRowSummary.fromJson)
          .toList(growable: false),
      equityRows: (json['equity_rows'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .map(ReportRowSummary.fromJson)
          .toList(growable: false),
      totalAssetsMinor: json['total_assets_minor'] as int? ?? 0,
      totalLiabilitiesMinor: json['total_liabilities_minor'] as int? ?? 0,
      totalEquityMinor: json['total_equity_minor'] as int? ?? 0,
      balanced: json['balanced'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'as_of_date': _dateOnly(asOfDate),
      'asset_rows': assetRows
          .map((row) => row.toJson())
          .toList(growable: false),
      'liability_rows': liabilityRows
          .map((row) => row.toJson())
          .toList(growable: false),
      'equity_rows': equityRows
          .map((row) => row.toJson())
          .toList(growable: false),
      'total_assets_minor': totalAssetsMinor,
      'total_liabilities_minor': totalLiabilitiesMinor,
      'total_equity_minor': totalEquityMinor,
      'balanced': balanced,
    };
  }
}

class CashFlowRow {
  const CashFlowRow({
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.sourceModule,
    required this.inflowMinor,
    required this.outflowMinor,
    required this.netCashFlowMinor,
  });

  final String accountId;
  final String accountCode;
  final String accountName;
  final String sourceModule;
  final int inflowMinor;
  final int outflowMinor;
  final int netCashFlowMinor;

  factory CashFlowRow.fromJson(Map<String, Object?> json) {
    return CashFlowRow(
      accountId: json['account_id']! as String,
      accountCode: json['account_code'] as String? ?? '',
      accountName: json['account_name'] as String? ?? '',
      sourceModule: json['source_module'] as String? ?? '',
      inflowMinor: json['inflow_minor'] as int? ?? 0,
      outflowMinor: json['outflow_minor'] as int? ?? 0,
      netCashFlowMinor: json['net_cash_flow_minor'] as int? ?? 0,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'account_id': accountId,
      'account_code': accountCode,
      'account_name': accountName,
      'source_module': sourceModule,
      'inflow_minor': inflowMinor,
      'outflow_minor': outflowMinor,
      'net_cash_flow_minor': netCashFlowMinor,
    };
  }
}

class CashFlowReport {
  const CashFlowReport({
    required this.fromDate,
    required this.toDate,
    required this.rows,
    required this.totalInflowsMinor,
    required this.totalOutflowsMinor,
    required this.netCashFlowMinor,
    required this.openingCashMinor,
    required this.closingCashMinor,
    required this.generatedFromSubtypes,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final List<CashFlowRow> rows;
  final int totalInflowsMinor;
  final int totalOutflowsMinor;
  final int netCashFlowMinor;
  final int openingCashMinor;
  final int closingCashMinor;
  final List<String> generatedFromSubtypes;

  factory CashFlowReport.fromJson(Map<String, Object?> json) {
    return CashFlowReport(
      fromDate: DateTime.parse(json['from_date']! as String),
      toDate: DateTime.parse(json['to_date']! as String),
      rows: (json['rows'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .map(CashFlowRow.fromJson)
          .toList(growable: false),
      totalInflowsMinor: json['total_inflows_minor'] as int? ?? 0,
      totalOutflowsMinor: json['total_outflows_minor'] as int? ?? 0,
      netCashFlowMinor: json['net_cash_flow_minor'] as int? ?? 0,
      openingCashMinor: json['opening_cash_minor'] as int? ?? 0,
      closingCashMinor: json['closing_cash_minor'] as int? ?? 0,
      generatedFromSubtypes:
          (json['generated_from_subtypes'] as List? ?? const [])
              .cast<String>()
              .toList(growable: false),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'from_date': _dateOnly(fromDate),
      'to_date': _dateOnly(toDate),
      'rows': rows.map((row) => row.toJson()).toList(growable: false),
      'total_inflows_minor': totalInflowsMinor,
      'total_outflows_minor': totalOutflowsMinor,
      'net_cash_flow_minor': netCashFlowMinor,
      'opening_cash_minor': openingCashMinor,
      'closing_cash_minor': closingCashMinor,
      'generated_from_subtypes': generatedFromSubtypes,
    };
  }
}

class AgingBucketTotals {
  const AgingBucketTotals({
    required this.currentMinor,
    required this.oneToThirtyMinor,
    required this.thirtyOneToSixtyMinor,
    required this.sixtyOneToNinetyMinor,
    required this.overNinetyMinor,
    required this.outstandingMinor,
  });

  final int currentMinor;
  final int oneToThirtyMinor;
  final int thirtyOneToSixtyMinor;
  final int sixtyOneToNinetyMinor;
  final int overNinetyMinor;
  final int outstandingMinor;
}

class ARAgingRow {
  const ARAgingRow({
    required this.customerId,
    required this.customerName,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.dueDate,
    required this.daysOverdue,
    required this.outstandingMinor,
    required this.currentMinor,
    required this.oneToThirtyMinor,
    required this.thirtyOneToSixtyMinor,
    required this.sixtyOneToNinetyMinor,
    required this.overNinetyMinor,
  });

  final String customerId;
  final String customerName;
  final String invoiceId;
  final String invoiceNumber;
  final DateTime dueDate;
  final int daysOverdue;
  final int outstandingMinor;
  final int currentMinor;
  final int oneToThirtyMinor;
  final int thirtyOneToSixtyMinor;
  final int sixtyOneToNinetyMinor;
  final int overNinetyMinor;

  factory ARAgingRow.fromJson(Map<String, Object?> json) {
    return ARAgingRow(
      customerId: json['customer_id']! as String,
      customerName: json['customer_name'] as String? ?? '',
      invoiceId: json['invoice_id']! as String,
      invoiceNumber: json['invoice_number'] as String? ?? '',
      dueDate: DateTime.parse(json['due_date']! as String),
      daysOverdue: json['days_overdue'] as int? ?? 0,
      outstandingMinor: json['outstanding_minor'] as int? ?? 0,
      currentMinor: json['current_minor'] as int? ?? 0,
      oneToThirtyMinor: json['one_to_thirty_minor'] as int? ?? 0,
      thirtyOneToSixtyMinor: json['thirty_one_to_sixty_minor'] as int? ?? 0,
      sixtyOneToNinetyMinor: json['sixty_one_to_ninety_minor'] as int? ?? 0,
      overNinetyMinor: json['over_ninety_minor'] as int? ?? 0,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'customer_id': customerId,
      'customer_name': customerName,
      'invoice_id': invoiceId,
      'invoice_number': invoiceNumber,
      'due_date': _dateOnly(dueDate),
      'days_overdue': daysOverdue,
      'outstanding_minor': outstandingMinor,
      'current_minor': currentMinor,
      'one_to_thirty_minor': oneToThirtyMinor,
      'thirty_one_to_sixty_minor': thirtyOneToSixtyMinor,
      'sixty_one_to_ninety_minor': sixtyOneToNinetyMinor,
      'over_ninety_minor': overNinetyMinor,
    };
  }
}

class ARAgingReport {
  const ARAgingReport({
    required this.asOfDate,
    required this.rows,
    required this.totalCurrentMinor,
    required this.totalOneToThirtyMinor,
    required this.totalThirtyOneToSixtyMinor,
    required this.totalSixtyOneToNinetyMinor,
    required this.totalOverNinetyMinor,
    required this.totalOutstandingMinor,
  });

  final DateTime asOfDate;
  final List<ARAgingRow> rows;
  final int totalCurrentMinor;
  final int totalOneToThirtyMinor;
  final int totalThirtyOneToSixtyMinor;
  final int totalSixtyOneToNinetyMinor;
  final int totalOverNinetyMinor;
  final int totalOutstandingMinor;

  factory ARAgingReport.fromJson(Map<String, Object?> json) {
    return ARAgingReport(
      asOfDate: DateTime.parse(json['as_of_date']! as String),
      rows: (json['rows'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .map(ARAgingRow.fromJson)
          .toList(growable: false),
      totalCurrentMinor: json['total_current_minor'] as int? ?? 0,
      totalOneToThirtyMinor: json['total_one_to_thirty_minor'] as int? ?? 0,
      totalThirtyOneToSixtyMinor:
          json['total_thirty_one_to_sixty_minor'] as int? ?? 0,
      totalSixtyOneToNinetyMinor:
          json['total_sixty_one_to_ninety_minor'] as int? ?? 0,
      totalOverNinetyMinor: json['total_over_ninety_minor'] as int? ?? 0,
      totalOutstandingMinor: json['total_outstanding_minor'] as int? ?? 0,
    );
  }

  AgingBucketTotals get totals => AgingBucketTotals(
    currentMinor: totalCurrentMinor,
    oneToThirtyMinor: totalOneToThirtyMinor,
    thirtyOneToSixtyMinor: totalThirtyOneToSixtyMinor,
    sixtyOneToNinetyMinor: totalSixtyOneToNinetyMinor,
    overNinetyMinor: totalOverNinetyMinor,
    outstandingMinor: totalOutstandingMinor,
  );

  Map<String, Object?> toJson() {
    return {
      'as_of_date': _dateOnly(asOfDate),
      'rows': rows.map((row) => row.toJson()).toList(growable: false),
      'total_current_minor': totalCurrentMinor,
      'total_one_to_thirty_minor': totalOneToThirtyMinor,
      'total_thirty_one_to_sixty_minor': totalThirtyOneToSixtyMinor,
      'total_sixty_one_to_ninety_minor': totalSixtyOneToNinetyMinor,
      'total_over_ninety_minor': totalOverNinetyMinor,
      'total_outstanding_minor': totalOutstandingMinor,
    };
  }
}

class APAgingRow {
  const APAgingRow({
    required this.vendorId,
    required this.vendorName,
    required this.billId,
    required this.billNumber,
    required this.dueDate,
    required this.daysOverdue,
    required this.outstandingMinor,
    required this.currentMinor,
    required this.oneToThirtyMinor,
    required this.thirtyOneToSixtyMinor,
    required this.sixtyOneToNinetyMinor,
    required this.overNinetyMinor,
  });

  final String vendorId;
  final String vendorName;
  final String billId;
  final String billNumber;
  final DateTime dueDate;
  final int daysOverdue;
  final int outstandingMinor;
  final int currentMinor;
  final int oneToThirtyMinor;
  final int thirtyOneToSixtyMinor;
  final int sixtyOneToNinetyMinor;
  final int overNinetyMinor;

  factory APAgingRow.fromJson(Map<String, Object?> json) {
    return APAgingRow(
      vendorId: json['vendor_id']! as String,
      vendorName: json['vendor_name'] as String? ?? '',
      billId: json['bill_id']! as String,
      billNumber: json['bill_number'] as String? ?? '',
      dueDate: DateTime.parse(json['due_date']! as String),
      daysOverdue: json['days_overdue'] as int? ?? 0,
      outstandingMinor: json['outstanding_minor'] as int? ?? 0,
      currentMinor: json['current_minor'] as int? ?? 0,
      oneToThirtyMinor: json['one_to_thirty_minor'] as int? ?? 0,
      thirtyOneToSixtyMinor: json['thirty_one_to_sixty_minor'] as int? ?? 0,
      sixtyOneToNinetyMinor: json['sixty_one_to_ninety_minor'] as int? ?? 0,
      overNinetyMinor: json['over_ninety_minor'] as int? ?? 0,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'vendor_id': vendorId,
      'vendor_name': vendorName,
      'bill_id': billId,
      'bill_number': billNumber,
      'due_date': _dateOnly(dueDate),
      'days_overdue': daysOverdue,
      'outstanding_minor': outstandingMinor,
      'current_minor': currentMinor,
      'one_to_thirty_minor': oneToThirtyMinor,
      'thirty_one_to_sixty_minor': thirtyOneToSixtyMinor,
      'sixty_one_to_ninety_minor': sixtyOneToNinetyMinor,
      'over_ninety_minor': overNinetyMinor,
    };
  }
}

class APAgingReport {
  const APAgingReport({
    required this.asOfDate,
    required this.rows,
    required this.totalCurrentMinor,
    required this.totalOneToThirtyMinor,
    required this.totalThirtyOneToSixtyMinor,
    required this.totalSixtyOneToNinetyMinor,
    required this.totalOverNinetyMinor,
    required this.totalOutstandingMinor,
  });

  final DateTime asOfDate;
  final List<APAgingRow> rows;
  final int totalCurrentMinor;
  final int totalOneToThirtyMinor;
  final int totalThirtyOneToSixtyMinor;
  final int totalSixtyOneToNinetyMinor;
  final int totalOverNinetyMinor;
  final int totalOutstandingMinor;

  factory APAgingReport.fromJson(Map<String, Object?> json) {
    return APAgingReport(
      asOfDate: DateTime.parse(json['as_of_date']! as String),
      rows: (json['rows'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .map(APAgingRow.fromJson)
          .toList(growable: false),
      totalCurrentMinor: json['total_current_minor'] as int? ?? 0,
      totalOneToThirtyMinor: json['total_one_to_thirty_minor'] as int? ?? 0,
      totalThirtyOneToSixtyMinor:
          json['total_thirty_one_to_sixty_minor'] as int? ?? 0,
      totalSixtyOneToNinetyMinor:
          json['total_sixty_one_to_ninety_minor'] as int? ?? 0,
      totalOverNinetyMinor: json['total_over_ninety_minor'] as int? ?? 0,
      totalOutstandingMinor: json['total_outstanding_minor'] as int? ?? 0,
    );
  }

  AgingBucketTotals get totals => AgingBucketTotals(
    currentMinor: totalCurrentMinor,
    oneToThirtyMinor: totalOneToThirtyMinor,
    thirtyOneToSixtyMinor: totalThirtyOneToSixtyMinor,
    sixtyOneToNinetyMinor: totalSixtyOneToNinetyMinor,
    overNinetyMinor: totalOverNinetyMinor,
    outstandingMinor: totalOutstandingMinor,
  );

  Map<String, Object?> toJson() {
    return {
      'as_of_date': _dateOnly(asOfDate),
      'rows': rows.map((row) => row.toJson()).toList(growable: false),
      'total_current_minor': totalCurrentMinor,
      'total_one_to_thirty_minor': totalOneToThirtyMinor,
      'total_thirty_one_to_sixty_minor': totalThirtyOneToSixtyMinor,
      'total_sixty_one_to_ninety_minor': totalSixtyOneToNinetyMinor,
      'total_over_ninety_minor': totalOverNinetyMinor,
      'total_outstanding_minor': totalOutstandingMinor,
    };
  }
}

class TaxReportRowSummary {
  const TaxReportRowSummary({
    required this.taxRateId,
    required this.taxGroupId,
    required this.name,
    required this.outputTaxMinor,
    required this.inputTaxMinor,
    required this.netPayableMinor,
  });

  final String taxRateId;
  final String taxGroupId;
  final String name;
  final int outputTaxMinor;
  final int inputTaxMinor;
  final int netPayableMinor;

  factory TaxReportRowSummary.fromJson(Map<String, Object?> json) {
    return TaxReportRowSummary(
      taxRateId: json['tax_rate_id'] as String? ?? '',
      taxGroupId: json['tax_group_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      outputTaxMinor: json['output_tax_minor'] as int? ?? 0,
      inputTaxMinor: json['input_tax_minor'] as int? ?? 0,
      netPayableMinor: json['net_payable_minor'] as int? ?? 0,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'tax_rate_id': taxRateId,
      if (taxGroupId.isNotEmpty) 'tax_group_id': taxGroupId,
      'name': name,
      'output_tax_minor': outputTaxMinor,
      'input_tax_minor': inputTaxMinor,
      'net_payable_minor': netPayableMinor,
    };
  }
}

class TaxLiabilityReport {
  const TaxLiabilityReport({
    required this.fromDate,
    required this.toDate,
    required this.outputTaxMinor,
    required this.inputTaxMinor,
    required this.netPayableMinor,
    required this.rows,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final int outputTaxMinor;
  final int inputTaxMinor;
  final int netPayableMinor;
  final List<TaxReportRowSummary> rows;

  factory TaxLiabilityReport.fromJson(Map<String, Object?> json) {
    return TaxLiabilityReport(
      fromDate: DateTime.parse(json['from_date']! as String),
      toDate: DateTime.parse(json['to_date']! as String),
      outputTaxMinor: json['output_tax_minor'] as int? ?? 0,
      inputTaxMinor: json['input_tax_minor'] as int? ?? 0,
      netPayableMinor: json['net_payable_minor'] as int? ?? 0,
      rows: (json['rows'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .map(TaxReportRowSummary.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'from_date': _dateOnly(fromDate),
      'to_date': _dateOnly(toDate),
      'output_tax_minor': outputTaxMinor,
      'input_tax_minor': inputTaxMinor,
      'net_payable_minor': netPayableMinor,
      'rows': rows.map((row) => row.toJson()).toList(growable: false),
    };
  }
}

class TaxSummaryReport {
  const TaxSummaryReport({
    required this.fromDate,
    required this.toDate,
    required this.rows,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final List<TaxReportRowSummary> rows;

  factory TaxSummaryReport.fromJson(Map<String, Object?> json) {
    return TaxSummaryReport(
      fromDate: DateTime.parse(json['from_date']! as String),
      toDate: DateTime.parse(json['to_date']! as String),
      rows: (json['rows'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .map(TaxReportRowSummary.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'from_date': _dateOnly(fromDate),
      'to_date': _dateOnly(toDate),
      'rows': rows.map((row) => row.toJson()).toList(growable: false),
    };
  }
}

class BudgetLineSummary {
  const BudgetLineSummary({
    required this.id,
    required this.accountId,
    required this.periodStart,
    required this.periodEnd,
    required this.amountMinor,
  });

  final String id;
  final String accountId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int amountMinor;

  factory BudgetLineSummary.fromJson(Map<String, Object?> json) {
    return BudgetLineSummary(
      id: json['id']! as String,
      accountId: json['account_id']! as String,
      periodStart: DateTime.parse(json['period_start']! as String),
      periodEnd: DateTime.parse(json['period_end']! as String),
      amountMinor: json['amount_minor'] as int? ?? 0,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'period_start': _dateOnly(periodStart),
      'period_end': _dateOnly(periodEnd),
      'amount_minor': amountMinor,
    };
  }
}

class BudgetSummary {
  const BudgetSummary({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.lines,
  });

  final String id;
  final String organizationId;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final List<BudgetLineSummary> lines;

  factory BudgetSummary.fromJson(Map<String, Object?> json) {
    return BudgetSummary(
      id: json['id']! as String,
      organizationId: json['organization_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      startDate: DateTime.parse(json['start_date']! as String),
      endDate: DateTime.parse(json['end_date']! as String),
      status: json['status'] as String? ?? 'draft',
      lines: (json['lines'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .map(BudgetLineSummary.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'name': name,
      'start_date': _dateOnly(startDate),
      'end_date': _dateOnly(endDate),
      'status': status,
      'lines': lines.map((line) => line.toJson()).toList(growable: false),
    };
  }
}

class BudgetVsActualReportRow {
  const BudgetVsActualReportRow({
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.periodStart,
    required this.periodEnd,
    required this.budgetMinor,
    required this.actualMinor,
    required this.varianceMinor,
    required this.variancePercentBasis,
  });

  final String accountId;
  final String accountCode;
  final String accountName;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int budgetMinor;
  final int actualMinor;
  final int varianceMinor;
  final int variancePercentBasis;

  factory BudgetVsActualReportRow.fromJson(Map<String, Object?> json) {
    return BudgetVsActualReportRow(
      accountId: json['account_id']! as String,
      accountCode: json['account_code'] as String? ?? '',
      accountName: json['account_name'] as String? ?? '',
      periodStart: DateTime.parse(json['period_start']! as String),
      periodEnd: DateTime.parse(json['period_end']! as String),
      budgetMinor: json['budget_minor'] as int? ?? 0,
      actualMinor: json['actual_minor'] as int? ?? 0,
      varianceMinor: json['variance_minor'] as int? ?? 0,
      variancePercentBasis: json['variance_percent_basis'] as int? ?? 0,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'account_id': accountId,
      'account_code': accountCode,
      'account_name': accountName,
      'period_start': _dateOnly(periodStart),
      'period_end': _dateOnly(periodEnd),
      'budget_minor': budgetMinor,
      'actual_minor': actualMinor,
      'variance_minor': varianceMinor,
      'variance_percent_basis': variancePercentBasis,
    };
  }
}

class BudgetVsActualReport {
  const BudgetVsActualReport({required this.budgetId, required this.rows});

  final String budgetId;
  final List<BudgetVsActualReportRow> rows;

  factory BudgetVsActualReport.fromJson(Map<String, Object?> json) {
    return BudgetVsActualReport(
      budgetId: json['budget_id']! as String,
      rows: (json['rows'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .map(BudgetVsActualReportRow.fromJson)
          .toList(growable: false),
    );
  }

  int get totalBudgetMinor {
    return rows.fold(0, (total, row) => total + row.budgetMinor);
  }

  int get totalActualMinor {
    return rows.fold(0, (total, row) => total + row.actualMinor);
  }

  int get totalVarianceMinor {
    return rows.fold(0, (total, row) => total + row.varianceMinor);
  }

  Map<String, Object?> toJson() {
    return {
      'budget_id': budgetId,
      'rows': rows.map((row) => row.toJson()).toList(growable: false),
    };
  }
}

class InvestmentPriceSummary {
  const InvestmentPriceSummary({
    required this.id,
    required this.symbol,
    required this.priceDate,
    required this.priceMinor,
    required this.currency,
    this.source = '',
  });

  final String id;
  final String symbol;
  final DateTime priceDate;
  final int priceMinor;
  final String currency;
  final String source;

  factory InvestmentPriceSummary.fromJson(Map<String, Object?> json) {
    return InvestmentPriceSummary(
      id: json['id']! as String,
      symbol: json['symbol']! as String,
      priceDate: DateTime.parse(json['price_date']! as String),
      priceMinor: json['price_minor'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      source: json['source'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'price_date': _dateOnly(priceDate),
      'price_minor': priceMinor,
      'currency': currency,
      'source': source,
    };
  }
}

class CreateInvestmentPriceRequest {
  const CreateInvestmentPriceRequest({
    required this.symbol,
    required this.priceDate,
    required this.priceMinor,
    this.currency = 'INR',
    this.source = 'manual',
  });

  final String symbol;
  final DateTime priceDate;
  final int priceMinor;
  final String currency;
  final String source;

  factory CreateInvestmentPriceRequest.fromSyncOperation(
    SyncOperation operation,
  ) {
    final payload = operation.payload;
    return CreateInvestmentPriceRequest(
      symbol: payload['symbol']! as String,
      priceDate: _parseDateOnlyUtc(payload['price_date']! as String),
      priceMinor: payload['price_minor']! as int,
      currency: payload['currency'] as String? ?? 'INR',
      source: payload['source'] as String? ?? 'mobile-offline',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'symbol': symbol,
      'price_date': _dateOnly(priceDate),
      'price_minor': priceMinor,
      'currency': currency,
      'source': source,
    };
  }
}

class ImportInvestmentPricesRequest {
  const ImportInvestmentPricesRequest({
    required this.csv,
    this.source = 'broker_holdings_csv',
    this.symbol,
  });

  final String csv;
  final String source;
  final String? symbol;

  factory ImportInvestmentPricesRequest.fromSyncOperation(
    SyncOperation operation,
  ) {
    final payload = operation.payload;
    return ImportInvestmentPricesRequest(
      csv: payload['csv']! as String,
      source: payload['source'] as String? ?? 'broker_holdings_csv',
      symbol: payload['symbol'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'csv': csv,
      'source': source,
      if (symbol != null && symbol!.trim().isNotEmpty) 'symbol': symbol,
    };
  }
}

class InvestmentPriceImportResult {
  const InvestmentPriceImportResult({
    required this.imported,
    required this.skipped,
    required this.errors,
    required this.prices,
  });

  final int imported;
  final int skipped;
  final List<String> errors;
  final List<InvestmentPriceSummary> prices;

  factory InvestmentPriceImportResult.fromJson(Map<String, Object?> json) {
    final errors = json['errors'] as List? ?? const [];
    final prices = json['prices'] as List? ?? const [];
    return InvestmentPriceImportResult(
      imported: json['imported'] as int? ?? 0,
      skipped: json['skipped'] as int? ?? 0,
      errors: errors.cast<String>(),
      prices: prices
          .cast<Map<String, Object?>>()
          .map(InvestmentPriceSummary.fromJson)
          .toList(growable: false),
    );
  }
}

class InvestmentValuationReport {
  const InvestmentValuationReport({
    required this.asOfDate,
    required this.rows,
    required this.totalCostBasisMinor,
    required this.totalMarketValueMinor,
    required this.totalUnrealizedGainLossMinor,
  });

  final DateTime asOfDate;
  final List<InvestmentValuationRow> rows;
  final int totalCostBasisMinor;
  final int totalMarketValueMinor;
  final int totalUnrealizedGainLossMinor;

  factory InvestmentValuationReport.fromJson(Map<String, Object?> json) {
    return InvestmentValuationReport(
      asOfDate: DateTime.parse(json['as_of_date']! as String),
      rows: (json['rows'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .map(InvestmentValuationRow.fromJson)
          .toList(growable: false),
      totalCostBasisMinor: json['total_cost_basis_minor'] as int? ?? 0,
      totalMarketValueMinor: json['total_market_value_minor'] as int? ?? 0,
      totalUnrealizedGainLossMinor:
          json['total_unrealized_gain_loss_minor'] as int? ?? 0,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'as_of_date': _dateOnly(asOfDate),
      'rows': rows.map((row) => row.toJson()).toList(growable: false),
      'total_cost_basis_minor': totalCostBasisMinor,
      'total_market_value_minor': totalMarketValueMinor,
      'total_unrealized_gain_loss_minor': totalUnrealizedGainLossMinor,
    };
  }
}

class InvestmentValuationRow {
  const InvestmentValuationRow({
    required this.lotId,
    required this.accountId,
    required this.symbol,
    required this.acquisitionDate,
    required this.remainingQuantityMillis,
    required this.remainingCostBasisMinor,
    required this.marketPriceMinor,
    required this.marketValueMinor,
    required this.unrealizedGainLossMinor,
    required this.currency,
    required this.priceDate,
    this.securityName = '',
  });

  final String lotId;
  final String accountId;
  final String symbol;
  final String securityName;
  final DateTime acquisitionDate;
  final int remainingQuantityMillis;
  final int remainingCostBasisMinor;
  final int marketPriceMinor;
  final int marketValueMinor;
  final int unrealizedGainLossMinor;
  final String currency;
  final DateTime priceDate;

  factory InvestmentValuationRow.fromJson(Map<String, Object?> json) {
    return InvestmentValuationRow(
      lotId: json['lot_id']! as String,
      accountId: json['account_id']! as String,
      symbol: json['symbol']! as String,
      securityName: json['security_name'] as String? ?? '',
      acquisitionDate: DateTime.parse(json['acquisition_date']! as String),
      remainingQuantityMillis: json['remaining_quantity_millis'] as int? ?? 0,
      remainingCostBasisMinor: json['remaining_cost_basis_minor'] as int? ?? 0,
      marketPriceMinor: json['market_price_minor'] as int? ?? 0,
      marketValueMinor: json['market_value_minor'] as int? ?? 0,
      unrealizedGainLossMinor: json['unrealized_gain_loss_minor'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      priceDate: DateTime.parse(json['price_date']! as String),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'lot_id': lotId,
      'account_id': accountId,
      'symbol': symbol,
      'security_name': securityName,
      'acquisition_date': _dateOnly(acquisitionDate),
      'remaining_quantity_millis': remainingQuantityMillis,
      'remaining_cost_basis_minor': remainingCostBasisMinor,
      'market_price_minor': marketPriceMinor,
      'market_value_minor': marketValueMinor,
      'unrealized_gain_loss_minor': unrealizedGainLossMinor,
      'currency': currency,
      'price_date': _dateOnly(priceDate),
    };
  }
}

class CustomerPaymentSummary {
  const CustomerPaymentSummary({
    required this.id,
    required this.invoiceId,
    required this.paymentNumber,
    required this.paymentDate,
    required this.amountMinor,
    required this.paymentAccountId,
    required this.journalTransactionId,
    this.currency = 'INR',
    this.paymentMethod = '',
    this.reference = '',
  });

  final String id;
  final String invoiceId;
  final String paymentNumber;
  final DateTime paymentDate;
  final int amountMinor;
  final String paymentAccountId;
  final String journalTransactionId;
  final String currency;
  final String paymentMethod;
  final String reference;

  factory CustomerPaymentSummary.fromJson(Map<String, Object?> json) {
    return CustomerPaymentSummary(
      id: json['id']! as String,
      invoiceId: json['invoice_id']! as String,
      paymentNumber: json['payment_number']! as String,
      paymentDate: DateTime.parse(json['payment_date']! as String),
      amountMinor: json['amount_minor']! as int,
      paymentAccountId: json['payment_account_id']! as String,
      journalTransactionId: json['journal_transaction_id']! as String,
      currency: json['currency'] as String? ?? 'INR',
      paymentMethod: json['payment_method'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
    );
  }
}

class VendorPaymentSummary {
  const VendorPaymentSummary({
    required this.id,
    required this.billId,
    required this.paymentNumber,
    required this.paymentDate,
    required this.amountMinor,
    required this.paymentAccountId,
    required this.journalTransactionId,
    this.currency = 'INR',
    this.paymentMethod = '',
    this.reference = '',
  });

  final String id;
  final String billId;
  final String paymentNumber;
  final DateTime paymentDate;
  final int amountMinor;
  final String paymentAccountId;
  final String journalTransactionId;
  final String currency;
  final String paymentMethod;
  final String reference;

  factory VendorPaymentSummary.fromJson(Map<String, Object?> json) {
    return VendorPaymentSummary(
      id: json['id']! as String,
      billId: json['bill_id']! as String,
      paymentNumber: json['payment_number']! as String,
      paymentDate: DateTime.parse(json['payment_date']! as String),
      amountMinor: json['amount_minor']! as int,
      paymentAccountId: json['payment_account_id']! as String,
      journalTransactionId: json['journal_transaction_id']! as String,
      currency: json['currency'] as String? ?? 'INR',
      paymentMethod: json['payment_method'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
    );
  }
}

class RecordPaymentRequest {
  const RecordPaymentRequest({
    required this.paymentNumber,
    required this.paymentDate,
    required this.amountMinor,
    required this.paymentAccountId,
    this.paymentMethod = '',
    this.reference = '',
    this.currency = 'INR',
  });

  final String paymentNumber;
  final DateTime paymentDate;
  final int amountMinor;
  final String paymentAccountId;
  final String paymentMethod;
  final String reference;
  final String currency;

  factory RecordPaymentRequest.fromSyncOperation(SyncOperation operation) {
    final payload = operation.payload;
    return RecordPaymentRequest(
      paymentNumber: payload['payment_number']! as String,
      paymentDate: _parseDateOnlyUtc(payload['payment_date']! as String),
      amountMinor: payload['amount_minor']! as int,
      paymentAccountId: payload['payment_account_id']! as String,
      paymentMethod: payload['payment_method'] as String? ?? '',
      reference: payload['reference'] as String? ?? '',
      currency: payload['currency'] as String? ?? 'INR',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'payment_number': paymentNumber,
      'payment_date': _dateOnly(paymentDate),
      'payment_method': paymentMethod.isEmpty ? null : paymentMethod,
      'reference': reference.isEmpty ? null : reference,
      'currency': currency,
      'amount_minor': amountMinor,
      'payment_account_id': paymentAccountId,
    }..removeWhere((_, value) => value == null);
  }
}

class EstimateSummary {
  const EstimateSummary({
    required this.id,
    required this.estimateNumber,
    required this.status,
    required this.totalMinor,
    this.currency = 'INR',
  });

  final String id;
  final String estimateNumber;
  final String status;
  final int totalMinor;
  final String currency;

  factory EstimateSummary.fromJson(Map<String, Object?> json) {
    return EstimateSummary(
      id: json['id']! as String,
      estimateNumber: json['estimate_number']! as String,
      status: json['status']! as String,
      totalMinor: json['total_minor'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'INR',
    );
  }
}

class PurchaseOrderSummary {
  const PurchaseOrderSummary({
    required this.id,
    required this.purchaseOrderNumber,
    required this.status,
    required this.totalMinor,
    this.currency = 'INR',
  });

  final String id;
  final String purchaseOrderNumber;
  final String status;
  final int totalMinor;
  final String currency;

  factory PurchaseOrderSummary.fromJson(Map<String, Object?> json) {
    return PurchaseOrderSummary(
      id: json['id']! as String,
      purchaseOrderNumber: json['purchase_order_number']! as String,
      status: json['status']! as String,
      totalMinor: json['total_minor'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'INR',
    );
  }
}

class UpdateStatusRequest {
  const UpdateStatusRequest({required this.status});

  final String status;

  factory UpdateStatusRequest.fromSyncOperation(SyncOperation operation) {
    return UpdateStatusRequest(status: operation.payload['status']! as String);
  }

  Map<String, Object?> toJson() {
    return {'status': status};
  }
}

class ConvertEstimateToInvoiceRequest {
  const ConvertEstimateToInvoiceRequest({
    required this.invoiceNumber,
    required this.issueDate,
    required this.dueDate,
    required this.accountsReceivableId,
    this.pdfAttachmentId,
  });

  final String invoiceNumber;
  final DateTime issueDate;
  final DateTime dueDate;
  final String accountsReceivableId;
  final String? pdfAttachmentId;

  factory ConvertEstimateToInvoiceRequest.fromSyncOperation(
    SyncOperation operation,
  ) {
    final payload = operation.payload;
    return ConvertEstimateToInvoiceRequest(
      invoiceNumber: payload['invoice_number']! as String,
      issueDate: _parseDateOnlyUtc(payload['issue_date']! as String),
      dueDate: _parseDateOnlyUtc(payload['due_date']! as String),
      accountsReceivableId: payload['accounts_receivable_id']! as String,
      pdfAttachmentId: payload['pdf_attachment_id'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'invoice_number': invoiceNumber,
      'issue_date': _dateOnly(issueDate),
      'due_date': _dateOnly(dueDate),
      'accounts_receivable_id': accountsReceivableId,
      'pdf_attachment_id': pdfAttachmentId,
    }..removeWhere((_, value) => value == null);
  }
}

class ConvertPurchaseOrderToBillRequest {
  const ConvertPurchaseOrderToBillRequest({
    required this.billNumber,
    required this.issueDate,
    required this.dueDate,
    required this.accountsPayableId,
    this.documentAttachmentId,
  });

  final String billNumber;
  final DateTime issueDate;
  final DateTime dueDate;
  final String accountsPayableId;
  final String? documentAttachmentId;

  factory ConvertPurchaseOrderToBillRequest.fromSyncOperation(
    SyncOperation operation,
  ) {
    final payload = operation.payload;
    return ConvertPurchaseOrderToBillRequest(
      billNumber: payload['bill_number']! as String,
      issueDate: _parseDateOnlyUtc(payload['issue_date']! as String),
      dueDate: _parseDateOnlyUtc(payload['due_date']! as String),
      accountsPayableId: payload['accounts_payable_id']! as String,
      documentAttachmentId: payload['document_attachment_id'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'bill_number': billNumber,
      'issue_date': _dateOnly(issueDate),
      'due_date': _dateOnly(dueDate),
      'accounts_payable_id': accountsPayableId,
      'document_attachment_id': documentAttachmentId,
    }..removeWhere((_, value) => value == null);
  }
}

class SellAverageCostRequest {
  const SellAverageCostRequest({
    required this.accountId,
    required this.symbol,
    required this.saleDate,
    required this.quantityMillis,
    required this.proceedsMinor,
    this.currency = 'INR',
    this.proceedsAccountId,
    this.gainLossAccountId,
    this.notes = '',
  });

  final String accountId;
  final String symbol;
  final String currency;
  final DateTime saleDate;
  final int quantityMillis;
  final int proceedsMinor;
  final String? proceedsAccountId;
  final String? gainLossAccountId;
  final String notes;

  factory SellAverageCostRequest.fromSyncOperation(SyncOperation operation) {
    final payload = operation.payload;
    return SellAverageCostRequest(
      accountId: payload['account_id']! as String,
      symbol: payload['symbol']! as String,
      saleDate: _parseDateOnlyUtc(payload['sale_date']! as String),
      quantityMillis: payload['quantity_millis']! as int,
      proceedsMinor: payload['proceeds_minor']! as int,
      currency: payload['currency'] as String? ?? 'INR',
      proceedsAccountId: payload['proceeds_account_id'] as String?,
      gainLossAccountId: payload['gain_loss_account_id'] as String?,
      notes: payload['notes'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'account_id': accountId,
      'symbol': symbol,
      'currency': currency,
      'sale_date': _dateOnly(saleDate),
      'quantity_millis': quantityMillis,
      'proceeds_minor': proceedsMinor,
      if (proceedsAccountId != null) 'proceeds_account_id': proceedsAccountId,
      if (gainLossAccountId != null) 'gain_loss_account_id': gainLossAccountId,
      if (notes.isNotEmpty) 'notes': notes,
    };
  }
}

class SellInvestmentLotRequest {
  const SellInvestmentLotRequest({
    required this.saleDate,
    required this.quantityMillis,
    required this.proceedsMinor,
    this.proceedsAccountId,
    this.gainLossAccountId,
    this.notes = '',
  });

  final DateTime saleDate;
  final int quantityMillis;
  final int proceedsMinor;
  final String? proceedsAccountId;
  final String? gainLossAccountId;
  final String notes;

  factory SellInvestmentLotRequest.fromSyncOperation(SyncOperation operation) {
    final payload = operation.payload;
    return SellInvestmentLotRequest(
      saleDate: _parseDateOnlyUtc(payload['sale_date']! as String),
      quantityMillis: payload['quantity_millis']! as int,
      proceedsMinor: payload['proceeds_minor']! as int,
      proceedsAccountId: payload['proceeds_account_id'] as String?,
      gainLossAccountId: payload['gain_loss_account_id'] as String?,
      notes: payload['notes'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'sale_date': _dateOnly(saleDate),
      'quantity_millis': quantityMillis,
      'proceeds_minor': proceedsMinor,
      if (proceedsAccountId != null) 'proceeds_account_id': proceedsAccountId,
      if (gainLossAccountId != null) 'gain_loss_account_id': gainLossAccountId,
      if (notes.isNotEmpty) 'notes': notes,
    };
  }
}

class ImportBankStatementRequest {
  const ImportBankStatementRequest({
    required this.accountId,
    required this.lines,
    this.fileName = '',
    this.format = 'csv',
  });

  final String accountId;
  final String fileName;
  final String format;
  final List<ImportBankStatementLineRequest> lines;

  factory ImportBankStatementRequest.fromSyncOperation(
    SyncOperation operation,
  ) {
    final payload = operation.payload;
    return ImportBankStatementRequest(
      accountId: payload['account_id']! as String,
      fileName: payload['file_name'] as String? ?? '',
      format: payload['format'] as String? ?? 'csv',
      lines: (payload['lines']! as List)
          .cast<Map<String, Object?>>()
          .map(ImportBankStatementLineRequest.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'account_id': accountId,
      'file_name': fileName.isEmpty ? null : fileName,
      'format': format.isEmpty ? null : format,
      'lines': lines.map((line) => line.toJson()).toList(growable: false),
    }..removeWhere((_, value) => value == null);
  }
}

class ImportBankStatementLineRequest {
  const ImportBankStatementLineRequest({
    required this.postedDate,
    required this.amountMinor,
    this.description = '',
    this.reference = '',
  });

  final DateTime postedDate;
  final int amountMinor;
  final String description;
  final String reference;

  factory ImportBankStatementLineRequest.fromJson(Map<String, Object?> json) {
    final postedDate = json['posted_date'];
    return ImportBankStatementLineRequest(
      postedDate: postedDate is DateTime
          ? postedDate
          : _parseDateOnlyUtc(postedDate! as String),
      amountMinor: json['amount_minor'] as int? ?? 0,
      description: json['description'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'posted_date': _dateOnly(postedDate),
      'description': description.isEmpty ? null : description,
      'amount_minor': amountMinor,
      'reference': reference.isEmpty ? null : reference,
    }..removeWhere((_, value) => value == null);
  }
}

class ImportQifBankStatementRequest {
  const ImportQifBankStatementRequest({
    required this.accountId,
    required this.qifContent,
    this.fileName = '',
  });

  final String accountId;
  final String qifContent;
  final String fileName;

  factory ImportQifBankStatementRequest.fromSyncOperation(
    SyncOperation operation,
  ) {
    final payload = operation.payload;
    return ImportQifBankStatementRequest(
      accountId: payload['account_id']! as String,
      qifContent: payload['qif_content']! as String,
      fileName: payload['file_name'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'account_id': accountId,
      'file_name': fileName.isEmpty ? null : fileName,
      'qif_content': qifContent,
    }..removeWhere((_, value) => value == null);
  }
}

class ImportOfxBankStatementRequest {
  const ImportOfxBankStatementRequest({
    required this.accountId,
    required this.ofxContent,
    this.fileName = '',
  });

  final String accountId;
  final String ofxContent;
  final String fileName;

  factory ImportOfxBankStatementRequest.fromSyncOperation(
    SyncOperation operation,
  ) {
    final payload = operation.payload;
    return ImportOfxBankStatementRequest(
      accountId: payload['account_id']! as String,
      ofxContent: payload['ofx_content']! as String,
      fileName: payload['file_name'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'account_id': accountId,
      'file_name': fileName.isEmpty ? null : fileName,
      'ofx_content': ofxContent,
    }..removeWhere((_, value) => value == null);
  }
}

class AverageCostSaleResult {
  const AverageCostSaleResult({
    required this.dispositions,
    required this.quantityMillis,
    required this.proceedsMinor,
    required this.allocatedCostBasisMinor,
    required this.realizedGainLossMinor,
    this.journalTransactionId,
  });

  final List<InvestmentDispositionSummary> dispositions;
  final int quantityMillis;
  final int proceedsMinor;
  final int allocatedCostBasisMinor;
  final int realizedGainLossMinor;
  final String? journalTransactionId;

  factory AverageCostSaleResult.fromJson(Map<String, Object?> json) {
    return AverageCostSaleResult(
      dispositions: (json['dispositions'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .map(InvestmentDispositionSummary.fromJson)
          .toList(growable: false),
      quantityMillis: json['quantity_millis'] as int? ?? 0,
      proceedsMinor: json['proceeds_minor'] as int? ?? 0,
      allocatedCostBasisMinor: json['allocated_cost_basis_minor'] as int? ?? 0,
      realizedGainLossMinor: json['realized_gain_loss_minor'] as int? ?? 0,
      journalTransactionId: json['journal_transaction_id'] as String?,
    );
  }
}

class AttachmentSummary {
  const AttachmentSummary({
    required this.id,
    required this.fileName,
    required this.contentType,
    required this.storageDriver,
    required this.storageKey,
    required this.sizeBytes,
  });

  final String id;
  final String fileName;
  final String contentType;
  final String storageDriver;
  final String storageKey;
  final int sizeBytes;

  factory AttachmentSummary.fromJson(Map<String, Object?> json) {
    return AttachmentSummary(
      id: json['id']! as String,
      fileName: json['file_name']! as String,
      contentType: json['content_type'] as String? ?? '',
      storageDriver: json['storage_driver'] as String? ?? 'local',
      storageKey: json['storage_key']! as String,
      sizeBytes: json['size_bytes'] as int? ?? 0,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'file_name': fileName,
      'content_type': contentType,
      'storage_driver': storageDriver,
      'storage_key': storageKey,
      'size_bytes': sizeBytes,
    };
  }
}

class CreateAttachmentMetadata {
  const CreateAttachmentMetadata({
    required this.fileName,
    required this.storageKey,
    this.contentType = '',
    this.storageDriver = 'local',
    this.sizeBytes = 0,
  });

  final String fileName;
  final String storageKey;
  final String contentType;
  final String storageDriver;
  final int sizeBytes;

  factory CreateAttachmentMetadata.fromSyncOperation(SyncOperation operation) {
    final payload = operation.payload;
    return CreateAttachmentMetadata(
      fileName: payload['file_name']! as String,
      storageKey: payload['storage_key']! as String,
      contentType: payload['content_type'] as String? ?? '',
      storageDriver: payload['storage_driver'] as String? ?? 'local',
      sizeBytes: payload['size_bytes'] as int? ?? 0,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'file_name': fileName,
      'content_type': contentType,
      'storage_driver': storageDriver,
      'storage_key': storageKey,
      'size_bytes': sizeBytes,
    };
  }
}

class AttachmentDownload {
  const AttachmentDownload({
    required this.bytes,
    required this.contentType,
    this.fileName,
  });

  final Uint8List bytes;
  final String contentType;
  final String? fileName;
}

class TaxRateSummary {
  const TaxRateSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.percentageBasis,
    required this.isActive,
  });

  final String id;
  final String name;
  final String type;
  final int percentageBasis;
  final bool isActive;

  factory TaxRateSummary.fromJson(Map<String, Object?> json) {
    return TaxRateSummary(
      id: json['id']! as String,
      name: json['name']! as String,
      type: json['type'] as String? ?? 'GST',
      percentageBasis: json['percentage_basis'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'percentage_basis': percentageBasis,
      'is_active': isActive,
    };
  }
}

class TaxGroupSummary {
  const TaxGroupSummary({
    required this.id,
    required this.name,
    required this.isActive,
    this.description = '',
  });

  final String id;
  final String name;
  final bool isActive;
  final String description;

  factory TaxGroupSummary.fromJson(Map<String, Object?> json) {
    return TaxGroupSummary(
      id: json['id']! as String,
      name: json['name']! as String,
      isActive: json['is_active'] as bool? ?? true,
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'is_active': isActive,
      'description': description,
    };
  }
}

class CalculateTaxRequest {
  const CalculateTaxRequest({
    required this.baseAmountMinor,
    required this.taxInclusive,
    this.taxRateId,
    this.taxGroupId,
  });

  final int baseAmountMinor;
  final bool taxInclusive;
  final String? taxRateId;
  final String? taxGroupId;

  Map<String, Object?> toJson() {
    return {
      'base_amount_minor': baseAmountMinor,
      'tax_inclusive': taxInclusive,
      'tax_rate_id': taxRateId,
      'tax_group_id': taxGroupId,
    }..removeWhere((_, value) => value == null);
  }
}

class TaxCalculationResult {
  const TaxCalculationResult({
    required this.baseAmountMinor,
    required this.taxAmountMinor,
    required this.totalAmountMinor,
    required this.components,
  });

  final int baseAmountMinor;
  final int taxAmountMinor;
  final int totalAmountMinor;
  final List<TaxCalculationComponent> components;

  factory TaxCalculationResult.fromJson(Map<String, Object?> json) {
    final components = json['components'];
    return TaxCalculationResult(
      baseAmountMinor: json['base_amount_minor']! as int,
      taxAmountMinor: json['tax_amount_minor']! as int,
      totalAmountMinor: json['total_amount_minor']! as int,
      components: components is List
          ? components
                .cast<Map<String, Object?>>()
                .map(TaxCalculationComponent.fromJson)
                .toList(growable: false)
          : const [],
    );
  }
}

class TaxCalculationComponent {
  const TaxCalculationComponent({
    required this.taxRateId,
    required this.name,
    required this.percentageBasis,
    required this.taxAmountMinor,
  });

  final String taxRateId;
  final String name;
  final int percentageBasis;
  final int taxAmountMinor;

  factory TaxCalculationComponent.fromJson(Map<String, Object?> json) {
    return TaxCalculationComponent(
      taxRateId: json['tax_rate_id']! as String,
      name: json['name']! as String,
      percentageBasis: json['percentage_basis'] as int? ?? 0,
      taxAmountMinor: json['tax_amount_minor'] as int? ?? 0,
    );
  }
}

class CreateInvoiceDraft {
  const CreateInvoiceDraft({
    required this.customerId,
    required this.invoiceNumber,
    required this.issueDate,
    required this.dueDate,
    required this.accountsReceivableId,
    required this.lines,
    this.currency = 'INR',
    this.taxInclusive = false,
    this.pdfAttachmentId,
  });

  final String customerId;
  final String invoiceNumber;
  final DateTime issueDate;
  final DateTime dueDate;
  final String accountsReceivableId;
  final List<CreateInvoiceLineDraft> lines;
  final String currency;
  final bool taxInclusive;
  final String? pdfAttachmentId;

  factory CreateInvoiceDraft.fromSyncOperation(SyncOperation operation) {
    final payload = operation.payload;
    final lines = (payload['lines'] as List? ?? const [])
        .cast<Map<String, Object?>>()
        .map(CreateInvoiceLineDraft.fromJson)
        .toList(growable: false);
    return CreateInvoiceDraft(
      customerId: payload['customer_id']! as String,
      invoiceNumber: payload['invoice_number'] as String? ?? operation.id,
      issueDate: _parseDateOnlyUtc(payload['issue_date']! as String),
      dueDate: _parseDateOnlyUtc(payload['due_date']! as String),
      currency: payload['currency'] as String? ?? 'INR',
      taxInclusive: payload['tax_inclusive'] as bool? ?? false,
      accountsReceivableId: payload['accounts_receivable_id']! as String,
      pdfAttachmentId: payload['pdf_attachment_id'] as String?,
      lines: lines,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'customer_id': customerId,
      'invoice_number': invoiceNumber,
      'issue_date': _dateOnly(issueDate),
      'due_date': _dateOnly(dueDate),
      'currency': currency,
      'tax_inclusive': taxInclusive,
      'accounts_receivable_id': accountsReceivableId,
      'pdf_attachment_id': pdfAttachmentId,
      'lines': lines.map((line) => line.toJson()).toList(growable: false),
    }..removeWhere((_, value) => value == null);
  }
}

class CreateInvoiceLineDraft {
  const CreateInvoiceLineDraft({
    required this.description,
    required this.quantityMillis,
    required this.unitPriceMinor,
    required this.incomeAccountId,
    this.taxRateId,
    this.taxGroupId,
  });

  final String description;
  final int quantityMillis;
  final int unitPriceMinor;
  final String incomeAccountId;
  final String? taxRateId;
  final String? taxGroupId;

  factory CreateInvoiceLineDraft.fromJson(Map<String, Object?> json) {
    return CreateInvoiceLineDraft(
      description: json['description']! as String,
      quantityMillis: json['quantity_millis'] as int? ?? 1000,
      unitPriceMinor: json['unit_price_minor']! as int,
      incomeAccountId: json['income_account_id']! as String,
      taxRateId: json['tax_rate_id'] as String?,
      taxGroupId: json['tax_group_id'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'description': description,
      'quantity_millis': quantityMillis,
      'unit_price_minor': unitPriceMinor,
      'income_account_id': incomeAccountId,
      'tax_rate_id': taxRateId,
      'tax_group_id': taxGroupId,
    }..removeWhere((_, value) => value == null);
  }
}

class CreateExpenseDraft {
  const CreateExpenseDraft({
    required this.expenseNumber,
    required this.expenseDate,
    required this.amountMinor,
    required this.expenseAccountId,
    required this.paymentAccountId,
    this.currency = 'INR',
    this.vendorId,
    this.taxInclusive = false,
    this.taxRateId,
    this.taxGroupId,
    this.receiptAttachmentId,
    this.reimbursable = false,
  });

  final String expenseNumber;
  final DateTime expenseDate;
  final int amountMinor;
  final String expenseAccountId;
  final String paymentAccountId;
  final String currency;
  final String? vendorId;
  final bool taxInclusive;
  final String? taxRateId;
  final String? taxGroupId;
  final String? receiptAttachmentId;
  final bool reimbursable;

  factory CreateExpenseDraft.fromSyncOperation(SyncOperation operation) {
    final payload = operation.payload;
    return CreateExpenseDraft(
      expenseNumber: payload['expense_number'] as String? ?? operation.id,
      expenseDate: operation.createdAt,
      amountMinor: payload['amount_minor'] as int? ?? 0,
      expenseAccountId: payload['expense_account_id']! as String,
      paymentAccountId: payload['payment_account_id']! as String,
      currency: payload['currency'] as String? ?? 'INR',
      vendorId: payload['vendor_id'] as String?,
      taxInclusive: payload['tax_inclusive'] as bool? ?? false,
      taxRateId: payload['tax_rate_id'] as String?,
      taxGroupId: payload['tax_group_id'] as String?,
      receiptAttachmentId: payload['receipt_attachment_id'] as String?,
      reimbursable: payload['reimbursable'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'vendor_id': vendorId,
      'expense_number': expenseNumber,
      'expense_date': _dateOnly(expenseDate),
      'currency': currency,
      'tax_inclusive': taxInclusive,
      'amount_minor': amountMinor,
      'expense_account_id': expenseAccountId,
      'payment_account_id': paymentAccountId,
      'receipt_attachment_id': receiptAttachmentId,
      'tax_rate_id': taxRateId,
      'tax_group_id': taxGroupId,
      'reimbursable': reimbursable,
    }..removeWhere((_, value) => value == null);
  }
}
