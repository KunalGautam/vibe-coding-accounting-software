export type Account = {
  id: string;
  code: string;
  name: string;
  type: "asset" | "liability" | "equity" | "income" | "expense";
  subtype?: string;
  currency: string;
  is_active: boolean;
};

export type Organization = {
  id: string;
  name: string;
  base_currency: string;
  country_code?: string;
  created_at?: string;
};

export type CreateOrganizationInput = {
  name: string;
  base_currency: string;
  country_code?: string;
};

export type JournalTransaction = {
  id: string;
  transaction_date: string;
  memo?: string;
  source_module: string;
  status: string;
  splits: LedgerSplit[];
};

export type ReportRow = {
  account_id: string;
  account_code: string;
  account_name: string;
  account_type: Account["type"];
  debit_minor: number;
  credit_minor: number;
  balance_minor: number;
};

export type TrialBalanceReport = {
  as_of_date: string;
  rows: ReportRow[];
  total_debit_minor: number;
  total_credit_minor: number;
  balanced: boolean;
};

export type ProfitAndLossReport = {
  from_date: string;
  to_date: string;
  income_rows: ReportRow[];
  expense_rows: ReportRow[];
  total_income_minor: number;
  total_expense_minor: number;
  net_income_minor: number;
};

export type BalanceSheetReport = {
  as_of_date: string;
  asset_rows: ReportRow[];
  liability_rows: ReportRow[];
  equity_rows: ReportRow[];
  total_assets_minor: number;
  total_liabilities_minor: number;
  total_equity_minor: number;
  balanced: boolean;
};

export type CashFlowRow = {
  account_id: string;
  account_code: string;
  account_name: string;
  source_module: string;
  inflow_minor: number;
  outflow_minor: number;
  net_cash_flow_minor: number;
};

export type CashFlowReport = {
  from_date: string;
  to_date: string;
  rows: CashFlowRow[];
  total_inflows_minor: number;
  total_outflows_minor: number;
  net_cash_flow_minor: number;
  opening_cash_minor: number;
  closing_cash_minor: number;
  generated_from_subtypes: string[];
};

export type AccountDrilldownRow = {
  ledger_split_id: string;
  journal_transaction_id: string;
  transaction_date: string;
  source_module: string;
  source_document_type?: string;
  source_document_id?: string;
  source_document_number?: string;
  transaction_memo?: string;
  split_memo?: string;
  debit_minor: number;
  credit_minor: number;
  balance_minor: number;
  cleared: boolean;
  reconciled: boolean;
};

export type AccountDrilldownReport = {
  account_id: string;
  account_code: string;
  account_name: string;
  account_type: Account["type"];
  from_date: string;
  to_date: string;
  opening_balance_minor: number;
  closing_balance_minor: number;
  total_debit_minor: number;
  total_credit_minor: number;
  rows: AccountDrilldownRow[];
};

export type ARAgingRow = {
  customer_id: string;
  customer_name: string;
  invoice_id: string;
  invoice_number: string;
  due_date: string;
  days_overdue: number;
  outstanding_minor: number;
  current_minor: number;
  one_to_thirty_minor: number;
  thirty_one_to_sixty_minor: number;
  sixty_one_to_ninety_minor: number;
  over_ninety_minor: number;
};

export type ARAgingReport = {
  as_of_date: string;
  rows: ARAgingRow[];
  total_current_minor: number;
  total_one_to_thirty_minor: number;
  total_thirty_one_to_sixty_minor: number;
  total_sixty_one_to_ninety_minor: number;
  total_over_ninety_minor: number;
  total_outstanding_minor: number;
};

export type APAgingRow = {
  vendor_id: string;
  vendor_name: string;
  bill_id: string;
  bill_number: string;
  due_date: string;
  days_overdue: number;
  outstanding_minor: number;
  current_minor: number;
  one_to_thirty_minor: number;
  thirty_one_to_sixty_minor: number;
  sixty_one_to_ninety_minor: number;
  over_ninety_minor: number;
};

export type APAgingReport = {
  as_of_date: string;
  rows: APAgingRow[];
  total_current_minor: number;
  total_one_to_thirty_minor: number;
  total_thirty_one_to_sixty_minor: number;
  total_sixty_one_to_ninety_minor: number;
  total_over_ninety_minor: number;
  total_outstanding_minor: number;
};

export type Attachment = {
  id: string;
  organization_id: string;
  file_name: string;
  content_type?: string;
  storage_driver: string;
  storage_key: string;
  size_bytes: number;
};

export type CreateAttachmentInput = {
  file_name: string;
  content_type?: string;
  storage_driver?: string;
  storage_key: string;
  size_bytes?: number;
};

export type TaxReportRow = {
  tax_rate_id?: string;
  tax_group_id?: string;
  name: string;
  output_tax_minor: number;
  input_tax_minor: number;
  net_payable_minor: number;
};

export type TaxLiabilityReport = {
  from_date: string;
  to_date: string;
  output_tax_minor: number;
  input_tax_minor: number;
  net_payable_minor: number;
  rows: TaxReportRow[];
};

export type TaxSummaryReport = {
  from_date: string;
  to_date: string;
  rows: TaxReportRow[];
};

export type PayrollSummaryReport = {
  from_date: string;
  to_date: string;
  rows: PayrollSummaryRow[];
  total_runs: number;
  total_employees: number;
  total_gross_pay_minor: number;
  total_deductions_minor: number;
  total_net_pay_minor: number;
  total_employer_contributions_minor: number;
  total_payroll_cost_minor: number;
};

export type PayrollSummaryRow = {
  payroll_run_id: string;
  run_number: string;
  period_start: string;
  period_end: string;
  pay_date: string;
  currency: string;
  employee_count: number;
  gross_pay_minor: number;
  deductions_minor: number;
  net_pay_minor: number;
  employer_contributions_minor: number;
  payroll_cost_minor: number;
  journal_transaction_id?: string;
};

export type ScheduledReportType = "trial_balance" | "profit_and_loss" | "balance_sheet";

export type ScheduledReportFrequency = "daily" | "weekly" | "monthly";

export type ScheduledReport = {
  id: string;
  organization_id: string;
  name: string;
  report_type: ScheduledReportType;
  frequency: ScheduledReportFrequency;
  parameters_json?: string;
  email_recipients?: string;
  next_run_at: string;
  last_run_at?: string;
  is_active: boolean;
};

export type ScheduledReportRun = {
  id: string;
  organization_id: string;
  scheduled_report_id: string;
  report_type: ScheduledReportType;
  status: "completed" | "failed";
  period_start?: string;
  period_end?: string;
  as_of_date?: string;
  report_json?: string;
  error_message?: string;
  created_at?: string;
};

export type CreateScheduledReportInput = {
  name: string;
  report_type: ScheduledReportType;
  frequency: ScheduledReportFrequency;
  parameters_json?: string;
  email_recipients?: string;
  next_run_at: string;
};

export type Budget = {
  id: string;
  organization_id: string;
  name: string;
  start_date: string;
  end_date: string;
  status: "draft" | "active" | "closed";
  lines?: BudgetLine[];
};

export type BudgetLine = {
  id: string;
  account_id: string;
  period_start: string;
  period_end: string;
  amount_minor: number;
};

export type CreateBudgetInput = {
  name: string;
  start_date: string;
  end_date: string;
  status?: Budget["status"];
  lines: CreateBudgetLineInput[];
};

export type CreateBudgetLineInput = {
  account_id: string;
  period_start: string;
  period_end: string;
  amount_minor?: number;
};

export type BudgetVsActualReport = {
  budget_id: string;
  rows: BudgetVsActualReportRow[];
};

export type BudgetVsActualReportRow = {
  account_id: string;
  account_code: string;
  account_name: string;
  period_start: string;
  period_end: string;
  budget_minor: number;
  actual_minor: number;
  variance_minor: number;
  variance_percent_basis: number;
};

export type InvestmentLot = {
  id: string;
  organization_id: string;
  account_id: string;
  symbol: string;
  security_name?: string;
  acquisition_date: string;
  quantity_millis: number;
  remaining_quantity_millis: number;
  cost_basis_minor: number;
  currency: string;
  cost_method: "specific_lot" | "average_cost";
  notes?: string;
};

export type CreateInvestmentLotInput = {
  account_id: string;
  symbol: string;
  security_name?: string;
  acquisition_date: string;
  quantity_millis: number;
  cost_basis_minor: number;
  currency?: string;
  cost_method?: InvestmentLot["cost_method"];
  notes?: string;
};

export type InvestmentDisposition = {
  id: string;
  organization_id: string;
  investment_lot_id: string;
  sale_date: string;
  quantity_millis: number;
  proceeds_minor: number;
  allocated_cost_basis_minor: number;
  realized_gain_loss_minor: number;
  currency: string;
  journal_transaction_id?: string | null;
  notes?: string;
};

export type InvestmentDividend = {
  id: string;
  organization_id: string;
  account_id: string;
  symbol: string;
  dividend_date: string;
  amount_minor: number;
  currency: string;
  cash_account_id?: string;
  income_account_id?: string;
  journal_transaction_id?: string | null;
  notes?: string;
};

export type CreateInvestmentDividendInput = {
  account_id: string;
  symbol: string;
  dividend_date: string;
  amount_minor: number;
  currency?: string;
  cash_account_id?: string;
  income_account_id?: string;
  notes?: string;
};

export type InvestmentCorporateAction = {
  id: string;
  organization_id: string;
  account_id: string;
  symbol: string;
  action_type: "split" | "bonus";
  action_date: string;
  ratio_numerator: number;
  ratio_denominator: number;
  affected_lots: number;
  quantity_delta_millis: number;
  cost_basis_delta_minor: number;
  notes?: string;
};

export type CreateInvestmentCorporateActionInput = {
  account_id: string;
  symbol: string;
  action_type: InvestmentCorporateAction["action_type"];
  action_date: string;
  ratio_numerator: number;
  ratio_denominator: number;
  notes?: string;
};

export type SellInvestmentLotInput = {
  sale_date: string;
  quantity_millis: number;
  proceeds_minor: number;
  proceeds_account_id?: string;
  gain_loss_account_id?: string;
  notes?: string;
};

export type SellAverageCostInput = {
  account_id: string;
  symbol: string;
  currency?: string;
  sale_date: string;
  quantity_millis: number;
  proceeds_minor: number;
  proceeds_account_id?: string;
  gain_loss_account_id?: string;
  notes?: string;
};

export type AverageCostSaleResult = {
  dispositions: InvestmentDisposition[];
  quantity_millis: number;
  proceeds_minor: number;
  allocated_cost_basis_minor: number;
  realized_gain_loss_minor: number;
  journal_transaction_id?: string | null;
};

export type RealizedGainsReport = {
  from_date: string;
  to_date: string;
  rows: InvestmentDisposition[];
  total_proceeds_minor: number;
  total_cost_basis_minor: number;
  total_gain_loss_minor: number;
};

export type InvestmentDividendReport = {
  from_date: string;
  to_date: string;
  rows: InvestmentDividend[];
  total_amount_minor: number;
};

export type InvestmentCorporateActionReport = {
  from_date: string;
  to_date: string;
  rows: InvestmentCorporateAction[];
  total_actions: number;
  total_affected_lots: number;
  total_quantity_delta_millis: number;
  total_cost_basis_delta_minor: number;
};

export type InvestmentTaxLotRow = {
  lot_id: string;
  account_id: string;
  symbol: string;
  security_name?: string;
  acquisition_date: string;
  quantity_millis: number;
  remaining_quantity_millis: number;
  disposed_quantity_millis: number;
  cost_basis_minor: number;
  remaining_cost_basis_minor: number;
  disposed_cost_basis_minor: number;
  proceeds_minor: number;
  realized_gain_loss_minor: number;
  unit_cost_minor: number;
  currency: string;
  cost_method: InvestmentLot["cost_method"];
};

export type InvestmentTaxLotReport = {
  as_of_date: string;
  rows: InvestmentTaxLotRow[];
  total_quantity_millis: number;
  total_remaining_quantity_millis: number;
  total_cost_basis_minor: number;
  total_remaining_cost_basis_minor: number;
  total_proceeds_minor: number;
  total_realized_gain_loss_minor: number;
};

export type InvestmentTaxAdjustmentRow = {
  disposition_id: string;
  lot_id: string;
  account_id: string;
  symbol: string;
  sale_date: string;
  quantity_millis: number;
  proceeds_minor: number;
  allocated_cost_basis_minor: number;
  realized_loss_minor: number;
  replacement_quantity_millis: number;
  deferred_loss_minor: number;
  replacement_lot_ids: string[];
  window_start: string;
  window_end: string;
  currency: string;
  notes?: string;
};

export type InvestmentTaxAdjustmentReport = {
  from_date: string;
  to_date: string;
  rule: string;
  window_days: number;
  rows: InvestmentTaxAdjustmentRow[];
  total_loss_minor: number;
  total_deferred_loss_minor: number;
  total_replacement_quantity_millis: number;
};

export type InvestmentPrice = {
  id: string;
  organization_id: string;
  symbol: string;
  price_date: string;
  price_minor: number;
  currency: string;
  source?: string;
};

export type CreateInvestmentPriceInput = {
  symbol: string;
  price_date: string;
  price_minor: number;
  currency?: string;
  source?: string;
};

export type ImportInvestmentPricesInput = {
  csv: string;
  source?: string;
  symbol?: string;
};

export type ImportAMFINAVInput = {
  text: string;
  symbol_mode?: "scheme_code" | "isin_growth" | "scheme_name";
};

export type InvestmentPriceImportResult = {
  imported: number;
  skipped: number;
  errors: string[];
  prices: InvestmentPrice[];
};

export type InvestmentValuationRow = {
  lot_id: string;
  account_id: string;
  symbol: string;
  security_name?: string;
  acquisition_date: string;
  remaining_quantity_millis: number;
  remaining_cost_basis_minor: number;
  market_price_minor: number;
  market_value_minor: number;
  unrealized_gain_loss_minor: number;
  currency: string;
  price_date: string;
};

export type InvestmentValuationReport = {
  as_of_date: string;
  rows: InvestmentValuationRow[];
  total_cost_basis_minor: number;
  total_market_value_minor: number;
  total_unrealized_gain_loss_minor: number;
};

export type PayrollRun = {
  id: string;
  organization_id: string;
  run_number: string;
  period_start: string;
  period_end: string;
  pay_date: string;
  status: "draft" | "posted" | "void";
  currency?: string;
  payroll_expense_account_id?: string;
  payroll_liability_account_id?: string;
  deduction_liability_account_id?: string;
  employer_expense_account_id?: string;
  employer_liability_account_id?: string;
  gross_pay_minor: number;
  deductions_minor: number;
  net_pay_minor: number;
  employer_contributions_minor?: number;
  payroll_cost_minor?: number;
  journal_transaction_id?: string | null;
  items?: PayrollItem[];
};

export type PayrollItem = {
  id?: string;
  employee_id?: string;
  gross_pay_minor?: number;
  deductions_minor?: number;
  net_pay_minor?: number;
  payslip_key?: string;
  components?: PayrollComponent[];
};

export type PayrollComponent = {
  code: string;
  name: string;
  type: "earning" | "deduction";
  amount_minor: number;
  is_statutory: boolean;
};

export type Employee = {
  id: string;
  organization_id: string;
  display_name: string;
  email?: string;
  phone?: string;
  employee_code?: string;
  pan?: string;
  uan?: string;
  is_active: boolean;
};

export type EmployeeInput = {
  display_name: string;
  email?: string;
  phone?: string;
  employee_code?: string;
  pan?: string;
  uan?: string;
};

export type Customer = {
  id: string;
  organization_id: string;
  display_name: string;
  email?: string;
  phone?: string;
  billing_address?: string;
  gstin?: string;
  is_active: boolean;
};

export type CustomerInput = {
  display_name: string;
  email?: string;
  phone?: string;
  billing_address?: string;
  gstin?: string;
};

export type Invoice = {
  id: string;
  organization_id: string;
  customer_id?: string;
  invoice_number: string;
  issue_date?: string;
  due_date?: string;
  status: "draft" | "posted" | "paid" | "void";
  currency?: string;
  tax_inclusive?: boolean;
  subtotal_minor: number;
  tax_total_minor: number;
  total_minor: number;
  accounts_receivable_id?: string;
  pdf_attachment_id?: string | null;
  journal_transaction_id?: string | null;
  lines?: InvoiceLine[];
};

export type InvoiceLine = {
  id?: string;
  description?: string;
  quantity_millis?: number;
  unit_price_minor?: number;
  line_subtotal_minor?: number;
  tax_amount_minor?: number;
  line_total_minor?: number;
  income_account_id?: string;
  tax_rate_id?: string | null;
  tax_group_id?: string | null;
};

export type CreateInvoiceInput = {
  customer_id: string;
  invoice_number: string;
  issue_date: string;
  due_date: string;
  currency?: string;
  tax_inclusive: boolean;
  accounts_receivable_id: string;
  pdf_attachment_id?: string | null;
  lines: CreateInvoiceLineInput[];
};

export type CreateInvoiceLineInput = {
  description: string;
  quantity_millis?: number;
  unit_price_minor: number;
  income_account_id: string;
  tax_rate_id?: string | null;
  tax_group_id?: string | null;
};

export type RecurringInvoiceTemplate = {
  id: string;
  organization_id: string;
  customer_id: string;
  name: string;
  invoice_number_prefix: string;
  start_date: string;
  next_run_date: string;
  frequency: "weekly" | "monthly" | "yearly";
  due_days: number;
  currency: string;
  tax_inclusive: boolean;
  subtotal_minor: number;
  tax_total_minor: number;
  total_minor: number;
  accounts_receivable_id: string;
  is_active: boolean;
  last_generated_at?: string | null;
  lines?: RecurringInvoiceLine[];
};

export type RecurringInvoiceLine = {
  id?: string;
  description?: string;
  quantity_millis?: number;
  unit_price_minor?: number;
  line_subtotal_minor?: number;
  tax_amount_minor?: number;
  line_total_minor?: number;
  income_account_id?: string;
  tax_rate_id?: string | null;
  tax_group_id?: string | null;
};

export type CreateRecurringInvoiceTemplateInput = {
  customer_id: string;
  name: string;
  invoice_number_prefix: string;
  start_date: string;
  next_run_date?: string;
  frequency: RecurringInvoiceTemplate["frequency"];
  due_days?: number;
  currency?: string;
  tax_inclusive: boolean;
  accounts_receivable_id: string;
  lines: CreateInvoiceLineInput[];
};

export type GenerateDueRecurringInvoicesResult = {
  generated_invoices: Invoice[];
  generated_count: number;
};

export type Estimate = {
  id: string;
  organization_id: string;
  customer_id: string;
  estimate_number: string;
  issue_date: string;
  expiry_date: string;
  status: "draft" | "sent" | "accepted" | "converted" | "void";
  currency: string;
  tax_inclusive: boolean;
  subtotal_minor: number;
  tax_total_minor: number;
  total_minor: number;
  lines?: EstimateLine[];
};

export type EstimateLine = {
  id?: string;
  description?: string;
  quantity_millis?: number;
  unit_price_minor?: number;
  line_subtotal_minor?: number;
  tax_amount_minor?: number;
  line_total_minor?: number;
  income_account_id?: string;
  tax_rate_id?: string | null;
  tax_group_id?: string | null;
};

export type CreateEstimateInput = {
  customer_id: string;
  estimate_number: string;
  issue_date: string;
  expiry_date: string;
  currency?: string;
  tax_inclusive: boolean;
  lines: CreateInvoiceLineInput[];
};

export type ConvertEstimateToInvoiceInput = {
  invoice_number: string;
  issue_date: string;
  due_date: string;
  accounts_receivable_id: string;
  pdf_attachment_id?: string | null;
};

export type CreditNote = {
  id: string;
  organization_id: string;
  customer_id: string;
  invoice_id?: string | null;
  credit_note_number: string;
  issue_date: string;
  status: "draft" | "posted" | "void";
  currency: string;
  tax_inclusive: boolean;
  subtotal_minor: number;
  tax_total_minor: number;
  total_minor: number;
  accounts_receivable_id: string;
  journal_transaction_id?: string | null;
  lines?: CreditNoteLine[];
};

export type CreditNoteLine = EstimateLine;

export type CreateCreditNoteInput = {
  customer_id: string;
  invoice_id?: string | null;
  credit_note_number: string;
  issue_date: string;
  currency?: string;
  tax_inclusive: boolean;
  accounts_receivable_id: string;
  lines: CreateInvoiceLineInput[];
};

export type CustomerPayment = {
  id: string;
  organization_id: string;
  invoice_id: string;
  payment_number: string;
  payment_date: string;
  payment_method?: string;
  reference?: string;
  currency: string;
  amount_minor: number;
  payment_account_id: string;
  journal_transaction_id: string;
};

export type RecordPaymentInput = {
  payment_number: string;
  payment_date: string;
  payment_method?: string;
  reference?: string;
  currency?: string;
  amount_minor: number;
  payment_account_id: string;
};

export type Vendor = {
  id: string;
  organization_id: string;
  display_name: string;
  email?: string;
  phone?: string;
  billing_address?: string;
  gstin?: string;
  is_active: boolean;
};

export type VendorInput = {
  display_name: string;
  email?: string;
  phone?: string;
  billing_address?: string;
  gstin?: string;
};

export type Bill = {
  id: string;
  organization_id: string;
  vendor_id: string;
  vendor?: Vendor;
  bill_number: string;
  issue_date: string;
  due_date: string;
  status: "draft" | "posted" | "paid" | "void";
  currency: string;
  tax_inclusive: boolean;
  subtotal_minor: number;
  tax_total_minor: number;
  total_minor: number;
  accounts_payable_id: string;
  document_attachment_id?: string | null;
  journal_transaction_id?: string | null;
  lines?: BillLine[];
};

export type BillLine = {
  id: string;
  organization_id: string;
  bill_id: string;
  description: string;
  quantity_millis: number;
  unit_price_minor: number;
  line_subtotal_minor: number;
  tax_amount_minor: number;
  line_total_minor: number;
  expense_account_id: string;
  tax_rate_id?: string | null;
  tax_group_id?: string | null;
};

export type CreateBillInput = {
  vendor_id: string;
  bill_number: string;
  issue_date: string;
  due_date: string;
  currency?: string;
  tax_inclusive: boolean;
  accounts_payable_id: string;
  document_attachment_id?: string | null;
  lines: CreateBillLineInput[];
};

export type CreateBillLineInput = {
  description: string;
  quantity_millis?: number;
  unit_price_minor: number;
  expense_account_id: string;
  tax_rate_id?: string | null;
  tax_group_id?: string | null;
};

export type PurchaseOrder = {
  id: string;
  organization_id: string;
  vendor_id: string;
  purchase_order_number: string;
  issue_date: string;
  expected_date?: string | null;
  status: "draft" | "sent" | "approved" | "converted" | "void";
  currency: string;
  tax_inclusive: boolean;
  subtotal_minor: number;
  tax_total_minor: number;
  total_minor: number;
  lines?: PurchaseOrderLine[];
};

export type PurchaseOrderLine = {
  id?: string;
  description?: string;
  quantity_millis?: number;
  unit_price_minor?: number;
  line_subtotal_minor?: number;
  tax_amount_minor?: number;
  line_total_minor?: number;
  expense_account_id?: string;
  tax_rate_id?: string | null;
  tax_group_id?: string | null;
};

export type CreatePurchaseOrderInput = {
  vendor_id: string;
  purchase_order_number: string;
  issue_date: string;
  expected_date?: string;
  currency?: string;
  tax_inclusive: boolean;
  lines: CreateBillLineInput[];
};

export type ConvertPurchaseOrderToBillInput = {
  bill_number: string;
  issue_date: string;
  due_date: string;
  accounts_payable_id: string;
  document_attachment_id?: string | null;
};

export type VendorPayment = {
  id: string;
  organization_id: string;
  bill_id: string;
  payment_number: string;
  payment_date: string;
  payment_method?: string;
  reference?: string;
  currency: string;
  amount_minor: number;
  payment_account_id: string;
  journal_transaction_id: string;
};

export type Expense = {
  id: string;
  organization_id: string;
  vendor_id?: string | null;
  expense_number: string;
  expense_date: string;
  status: "draft" | "posted" | "void";
  currency?: string;
  tax_inclusive?: boolean;
  subtotal_minor: number;
  tax_total_minor: number;
  total_minor: number;
  expense_account_id?: string;
  payment_account_id?: string;
  receipt_attachment_id?: string | null;
  journal_transaction_id?: string | null;
  reimbursable?: boolean;
};

export type CreateExpenseInput = {
  vendor_id?: string | null;
  expense_number: string;
  expense_date: string;
  currency?: string;
  tax_inclusive: boolean;
  amount_minor: number;
  expense_account_id: string;
  payment_account_id: string;
  receipt_attachment_id?: string | null;
  tax_rate_id?: string | null;
  tax_group_id?: string | null;
  reimbursable: boolean;
};

export type BankStatementImport = {
  id: string;
  organization_id: string;
  account_id: string;
  file_name?: string;
  format: string;
  status: "pending" | "completed" | "failed";
  line_count: number;
  error_message?: string;
  lines?: BankStatementLine[];
};

export type BankStatementLine = {
  id: string;
  organization_id: string;
  import_id: string;
  account_id: string;
  posted_date: string;
  description?: string;
  amount_minor: number;
  reference?: string;
  is_duplicate: boolean;
  duplicate_of_id?: string | null;
  matched_split_id?: string | null;
  matched_at?: string | null;
};

export type ImportBankStatementInput = {
  account_id: string;
  file_name?: string;
  format?: string;
  lines: ImportBankStatementLineInput[];
};

export type ImportQIFBankStatementInput = {
  account_id: string;
  file_name?: string;
  qif_content: string;
};

export type ImportOFXBankStatementInput = {
  account_id: string;
  file_name?: string;
  ofx_content: string;
};

export type ImportBankStatementLineInput = {
  posted_date: string;
  description?: string;
  amount_minor: number;
  reference?: string;
};

export type BackupSnapshot = {
  id: string;
  organization_id: string;
  file_name: string;
  storage_path: string;
  size_bytes: number;
  sha256: string;
  status: string;
  completed_at?: string | null;
};

export type CreateBackupSnapshotInput = {
  storage_path?: string;
  retention_count?: number;
};

export type ExchangeRate = {
  id: string;
  organization_id: string;
  from_currency: string;
  to_currency: string;
  rate_date: string;
  numerator: number;
  denominator: number;
  source?: string;
};

export type CreateExchangeRateInput = {
  from_currency: string;
  to_currency: string;
  rate_date: string;
  numerator: number;
  denominator: number;
  source?: string;
};

export type RevaluationRow = {
  account_id: string;
  account_code: string;
  account_name: string;
  currency: string;
  foreign_balance_minor: number;
  carrying_base_minor: number;
  revalued_base_minor: number;
  adjustment_minor: number;
  exchange_rate_numerator: number;
  exchange_rate_denominator: number;
};

export type RevaluationPreview = {
  as_of_date: string;
  base_currency: string;
  rows: RevaluationRow[];
  total_adjustment_minor: number;
};

export type PostRevaluationInput = {
  as_of_date: string;
  gain_loss_account_id: string;
};

export type FiscalClose = {
  id: string;
  organization_id: string;
  fiscal_year_start: string;
  fiscal_year_end: string;
  retained_earnings_account_id: string;
  net_income_minor: number;
  status: "posted" | "reversed";
  journal_transaction_id: string;
};

export type CloseFiscalYearInput = {
  fiscal_year_start: string;
  fiscal_year_end: string;
  retained_earnings_account_id: string;
};

export type AuditLog = {
  id: string;
  organization_id?: string;
  actor_user_id?: string;
  entity_type: string;
  entity_id: string;
  action: string;
  before_json?: string;
  after_json?: string;
  ip_address?: string;
  user_agent?: string;
  created_at: string;
};

export type OrganizationUser = {
  user_id: string;
  organization_id: string;
  name: string;
  email: string;
  role: Role;
  is_active: boolean;
  invite_email_sent?: boolean;
  invite_email_error?: string;
};

export type Role = "admin" | "accountant" | "bookkeeper" | "payroll_manager" | "viewer" | "employee_self_service";

export type CreateOrganizationUserInput = {
  name: string;
  email: string;
  password: string;
  role: Role;
};

export type UpdateOrganizationUserInput = {
  name?: string;
  role?: Role;
  is_active?: boolean;
};

export type CreatePayrollRunInput = {
  run_number: string;
  period_start: string;
  period_end: string;
  pay_date: string;
  currency?: string;
  payroll_expense_account_id: string;
  payroll_liability_account_id: string;
  deduction_liability_account_id: string;
  employer_expense_account_id?: string;
  employer_liability_account_id?: string;
  employer_contributions_minor?: number;
  items: CreatePayrollItemInput[];
};

export type CreatePayrollItemInput = {
  employee_id: string;
  gross_pay_minor: number;
  deductions_minor?: number;
  payslip_key?: string;
  components?: CreatePayrollComponentInput[];
};

export type CreatePayrollComponentInput = {
  code: string;
  name: string;
  type: "earning" | "deduction";
  amount_minor: number;
  is_statutory?: boolean;
};

export type PreviewIndiaPayrollInput = {
  basic_minor?: number;
  hra_minor?: number;
  special_minor?: number;
  bonus_minor?: number;
  reimbursement_minor?: number;
  employee_pf_enabled?: boolean;
  employee_pf_rate_bps?: number;
  pf_wage_ceiling_minor?: number;
  employer_pf_enabled?: boolean;
  employer_pf_rate_bps?: number;
  employee_esi_enabled?: boolean;
  employee_esi_rate_bps?: number;
  employer_esi_enabled?: boolean;
  employer_esi_rate_bps?: number;
  esi_gross_limit_minor?: number;
  professional_tax_minor?: number;
  tds_rate_bps?: number;
  tds_minor?: number;
  tds_annual_income_minor?: number;
  tds_periods_in_year?: number;
  tds_slabs?: IndiaTDSSlabInput[];
};

export type IndiaPayrollPreview = {
  gross_pay_minor: number;
  deductions_minor: number;
  net_pay_minor: number;
  employer_contributions_minor: number;
  payroll_cost_minor: number;
  components: CreatePayrollComponentInput[];
  employer_contributions: IndiaPayrollEmployerContribution[];
  rule_summary: IndiaPayrollRuleSummary;
};

export type IndiaPayrollEmployerContribution = {
  code: string;
  name: string;
  amount_minor: number;
  is_statutory: boolean;
};

export type IndiaTDSSlabInput = {
  from_minor: number;
  to_minor?: number;
  rate_bps: number;
};

export type IndiaProfessionalTaxPreset = {
  state_code: string;
  state_name: string;
  monthly_amount_minor: number;
  notes: string;
};

export type IndiaPayrollRuleSummary = {
  employee_pf_enabled: boolean;
  employee_pf_rate_bps: number;
  pf_wage_ceiling_minor: number;
  employer_pf_enabled: boolean;
  employer_pf_rate_bps: number;
  employee_esi_enabled: boolean;
  employee_esi_rate_bps: number;
  employer_esi_enabled: boolean;
  employer_esi_rate_bps: number;
  esi_gross_limit_minor: number;
  professional_tax_minor: number;
  tds_rate_bps: number;
  tds_minor: number;
  tds_annual_income_minor: number;
  tds_annual_tax_minor: number;
  tds_periods_in_year: number;
  tds_slab_count: number;
};

export type PayslipPreview = {
  organization_id: string;
  payroll_run_id: string;
  payroll_item_id: string;
  run_number: string;
  period_start: string;
  period_end: string;
  pay_date: string;
  status: "draft" | "posted" | "void";
  currency: string;
  employee: Employee;
  gross_pay_minor: number;
  deductions_minor: number;
  net_pay_minor: number;
  payslip_key?: string;
  earnings: PayrollComponent[];
  deductions: PayrollComponent[];
  components: PayrollComponent[];
};

export type BinaryDownload = {
  blob: Blob;
  filename: string;
};

export type LedgerSplit = {
  id: string;
  account_id: string;
  memo?: string;
  debit_minor: number;
  credit_minor: number;
  base_debit_minor?: number;
  base_credit_minor?: number;
  currency: string;
  exchange_rate_numerator?: number;
  exchange_rate_denominator?: number;
  cleared: boolean;
  reconciled: boolean;
  reconciled_at?: string | null;
};

export type TaxAuthority = {
  id: string;
  organization_id: string;
  name: string;
  country_code?: string;
  region_code?: string;
  is_active: boolean;
};

export type CreateTaxAuthorityInput = {
  name: string;
  country_code?: string;
  region_code?: string;
};

export type TaxRate = {
  id: string;
  tax_authority_id: string;
  name: string;
  percentage_basis: number;
  type: "VAT" | "GST" | "Sales Tax" | "Withholding";
  effective_from: string;
  effective_to?: string | null;
  is_compound: boolean;
  is_active: boolean;
};

export type CreateTaxRateInput = {
  tax_authority_id: string;
  name: string;
  percentage_basis: number;
  type: TaxRate["type"];
  output_account_id?: string | null;
  input_account_id?: string | null;
  effective_from: string;
  effective_to?: string | null;
  is_compound: boolean;
};

export type TaxGroup = {
  id: string;
  organization_id: string;
  name: string;
  description?: string;
  is_active: boolean;
  components: TaxGroupComponent[];
};

export type TaxGroupComponent = {
  id: string;
  tax_group_id: string;
  tax_rate_id: string;
  sort_order: number;
  tax_rate?: TaxRate;
};

export type CreateTaxGroupInput = {
  name: string;
  description?: string;
  tax_rate_ids: string[];
};

export type CalculateTaxInput = {
  base_amount_minor: number;
  tax_inclusive: boolean;
  tax_rate_id?: string;
  tax_group_id?: string;
};

export type TaxCalculation = {
  base_amount_minor: number;
  tax_amount_minor: number;
  total_amount_minor: number;
  components: TaxCalculationComponent[];
};

export type TaxCalculationComponent = {
  tax_rate_id: string;
  name: string;
  percentage_basis: number;
  tax_amount_minor: number;
};

export type IndiaSeedResult = {
  accounts_created: number;
  tax_rates_created: number;
  tax_groups_created: number;
  tax_authority_created: boolean;
};

export type ApiConfig = {
  baseUrl: string;
  accessToken: string;
  refreshToken?: string;
  organizationId: string;
};

export type AuthTokenResponse = {
  access_token: string;
  refresh_token: string;
  token_type: string;
  expires_in: number;
};

export type RevokeAllSessionsResponse = {
  revoked: boolean;
  revoked_count: number;
};

export type CurrentUserProfile = {
  id: string;
  email: string;
  name: string;
  mfa_enabled: boolean;
  is_active: boolean;
  organization_roles: Record<string, Role>;
};

export type LoginInput = {
  email: string;
  password: string;
  mfa_code?: string;
};

export type MFASetupResponse = {
  secret: string;
  otpauth_url: string;
  mfa_enabled: boolean;
};

export type MFAStatusResponse = {
  mfa_enabled: boolean;
  recovery_codes?: string[];
};

export type RequestPasswordResetInput = {
  email: string;
};

export type RequestPasswordResetResponse = {
  requested: boolean;
  email_sent: boolean;
  reset_token?: string;
  reset_token_expires_at?: string;
};

export type ConfirmPasswordResetInput = {
  reset_token: string;
  new_password: string;
};

export type ChangePasswordInput = {
  current_password: string;
  new_password: string;
};

export type BootstrapFirstAdminInput = {
  organization_name: string;
  admin_name: string;
  admin_email: string;
  admin_password: string;
  base_currency?: string;
  country_code?: string;
  seed_india_defaults?: boolean;
};

export type BootstrapFirstAdminResponse = {
  organization?: Organization;
  user?: {
    id?: string;
    email?: string;
    name?: string;
    is_active?: boolean;
  };
  membership?: {
    organization_id?: string;
    user_id?: string;
    role?: string;
  };
  india_seed?: IndiaSeedResult;
};

export type RegisterOrganizationInput = BootstrapFirstAdminInput;
export type RegisterOrganizationResponse = BootstrapFirstAdminResponse;

export type AccountInput = {
  code: string;
  name: string;
  type: Account["type"];
  subtype?: string;
  currency?: string;
};

export type JournalTransactionInput = {
  transaction_date: string;
  memo?: string;
  splits: Array<{
    account_id: string;
    debit_minor: number;
    credit_minor: number;
    currency: string;
  }>;
};

export class ApiClient {
  constructor(private readonly config: ApiConfig) {}

  async bootstrapFirstAdmin(input: BootstrapFirstAdminInput): Promise<BootstrapFirstAdminResponse> {
    return this.publicRequest("/bootstrap/first-admin", {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async registerOrganization(input: RegisterOrganizationInput): Promise<RegisterOrganizationResponse> {
    return this.publicRequest("/auth/register", {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async login(input: LoginInput): Promise<AuthTokenResponse> {
    return this.publicRequest("/auth/login", {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async refreshToken(refreshToken: string): Promise<AuthTokenResponse> {
    return this.publicRequest("/auth/refresh", {
      method: "POST",
      body: JSON.stringify({ refresh_token: refreshToken })
    });
  }

  async logout(refreshToken: string): Promise<{ revoked: boolean }> {
    return this.publicRequest("/auth/logout", {
      method: "POST",
      body: JSON.stringify({ refresh_token: refreshToken })
    });
  }

  async revokeAllSessions(): Promise<RevokeAllSessionsResponse> {
    return this.request("/auth/sessions/revoke-all", {
      method: "POST"
    });
  }

  async currentUser(): Promise<CurrentUserProfile> {
    return this.request("/auth/me");
  }

  async updateCurrentUser(input: { name: string }): Promise<CurrentUserProfile> {
    return this.request("/auth/me", {
      method: "PATCH",
      body: JSON.stringify(input)
    });
  }

  async changePassword(input: ChangePasswordInput): Promise<{ changed: boolean; sessions_revoked: boolean }> {
    return this.request("/auth/password/change", {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async setupMFA(): Promise<MFASetupResponse> {
    return this.request("/auth/mfa/setup", {
      method: "POST"
    });
  }

  async enableMFA(code: string): Promise<MFAStatusResponse> {
    return this.request("/auth/mfa/enable", {
      method: "POST",
      body: JSON.stringify({ code })
    });
  }

  async disableMFA(code: string): Promise<MFAStatusResponse> {
    return this.request("/auth/mfa/disable", {
      method: "POST",
      body: JSON.stringify({ code })
    });
  }

  async regenerateMFARecoveryCodes(code: string): Promise<MFAStatusResponse> {
    return this.request("/auth/mfa/recovery-codes/regenerate", {
      method: "POST",
      body: JSON.stringify({ code })
    });
  }

  async requestPasswordReset(input: RequestPasswordResetInput): Promise<RequestPasswordResetResponse> {
    return this.publicRequest("/auth/password-reset/request", {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async confirmPasswordReset(input: ConfirmPasswordResetInput): Promise<{ reset: boolean }> {
    return this.publicRequest("/auth/password-reset/confirm", {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async listOrganizations(): Promise<Organization[]> {
    return this.request("/organizations");
  }

  async createOrganization(input: CreateOrganizationInput): Promise<Organization> {
    return this.request("/organizations", {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async listAccounts(): Promise<Account[]> {
    return this.request(`/organizations/${this.config.organizationId}/accounts`);
  }

  async createAccount(input: AccountInput): Promise<Account> {
    return this.request(`/organizations/${this.config.organizationId}/accounts`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async listJournalTransactions(): Promise<JournalTransaction[]> {
    return this.request(`/organizations/${this.config.organizationId}/ledger/transactions`);
  }

  async postJournalTransaction(input: JournalTransactionInput): Promise<JournalTransaction> {
    return this.request(`/organizations/${this.config.organizationId}/ledger/transactions`, {
      method: "POST",
      body: JSON.stringify({ ...input, source_module: "manual" })
    });
  }

  async getAccountRegister(accountId: string): Promise<LedgerSplit[]> {
    return this.request(`/organizations/${this.config.organizationId}/ledger/accounts/${accountId}/register`);
  }

  async listTaxRates(): Promise<TaxRate[]> {
    return this.request(`/organizations/${this.config.organizationId}/tax/rates`);
  }

  async createTaxRate(input: CreateTaxRateInput): Promise<TaxRate> {
    return this.request(`/organizations/${this.config.organizationId}/tax/rates`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async listTaxAuthorities(): Promise<TaxAuthority[]> {
    return this.request(`/organizations/${this.config.organizationId}/tax/authorities`);
  }

  async createTaxAuthority(input: CreateTaxAuthorityInput): Promise<TaxAuthority> {
    return this.request(`/organizations/${this.config.organizationId}/tax/authorities`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async listTaxGroups(): Promise<TaxGroup[]> {
    return this.request(`/organizations/${this.config.organizationId}/tax/groups`);
  }

  async createTaxGroup(input: CreateTaxGroupInput): Promise<TaxGroup> {
    return this.request(`/organizations/${this.config.organizationId}/tax/groups`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async calculateTax(input: CalculateTaxInput): Promise<TaxCalculation> {
    return this.request(`/organizations/${this.config.organizationId}/tax/calculate`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async seedIndiaDefaults(): Promise<IndiaSeedResult> {
    return this.request(`/organizations/${this.config.organizationId}/seed/india-defaults`, {
      method: "POST"
    });
  }

  async getTrialBalance(asOf: string): Promise<TrialBalanceReport> {
    return this.request(`/organizations/${this.config.organizationId}/reports/trial-balance?as_of=${encodeURIComponent(asOf)}`);
  }

  async downloadTrialBalancePDF(asOf: string): Promise<BinaryDownload> {
    return this.downloadBinary(`/organizations/${this.config.organizationId}/reports/trial-balance.pdf?as_of=${encodeURIComponent(asOf)}`, `trial-balance-${asOf}.pdf`);
  }

  async getProfitAndLoss(from: string, to: string): Promise<ProfitAndLossReport> {
    const params = new URLSearchParams({ from, to });
    return this.request(`/organizations/${this.config.organizationId}/reports/profit-and-loss?${params.toString()}`);
  }

  async downloadProfitAndLossPDF(from: string, to: string): Promise<BinaryDownload> {
    const params = new URLSearchParams({ from, to });
    return this.downloadBinary(`/organizations/${this.config.organizationId}/reports/profit-and-loss.pdf?${params.toString()}`, `profit-and-loss-${from}-to-${to}.pdf`);
  }

  async getBalanceSheet(asOf: string): Promise<BalanceSheetReport> {
    return this.request(`/organizations/${this.config.organizationId}/reports/balance-sheet?as_of=${encodeURIComponent(asOf)}`);
  }

  async downloadBalanceSheetPDF(asOf: string): Promise<BinaryDownload> {
    return this.downloadBinary(`/organizations/${this.config.organizationId}/reports/balance-sheet.pdf?as_of=${encodeURIComponent(asOf)}`, `balance-sheet-${asOf}.pdf`);
  }

  async getCashFlow(from: string, to: string): Promise<CashFlowReport> {
    const params = new URLSearchParams({ from, to });
    return this.request(`/organizations/${this.config.organizationId}/reports/cash-flow?${params.toString()}`);
  }

  async getAccountDrilldown(accountId: string, from: string, to: string): Promise<AccountDrilldownReport> {
    const params = new URLSearchParams({ account_id: accountId, from, to });
    return this.request(`/organizations/${this.config.organizationId}/reports/account-drilldown?${params.toString()}`);
  }

  async getARAging(asOf: string): Promise<ARAgingReport> {
    return this.request(`/organizations/${this.config.organizationId}/reports/ar-aging?as_of=${encodeURIComponent(asOf)}`);
  }

  async getAPAging(asOf: string): Promise<APAgingReport> {
    return this.request(`/organizations/${this.config.organizationId}/reports/ap-aging?as_of=${encodeURIComponent(asOf)}`);
  }

  async getTaxLiability(from: string, to: string): Promise<TaxLiabilityReport> {
    const params = new URLSearchParams({ from, to });
    return this.request(`/organizations/${this.config.organizationId}/reports/tax-liability?${params.toString()}`);
  }

  async getTaxSummary(from: string, to: string): Promise<TaxSummaryReport> {
    const params = new URLSearchParams({ from, to });
    return this.request(`/organizations/${this.config.organizationId}/reports/tax-summary?${params.toString()}`);
  }

  async getPayrollSummary(from: string, to: string): Promise<PayrollSummaryReport> {
    const params = new URLSearchParams({ from, to });
    return this.request(`/organizations/${this.config.organizationId}/reports/payroll-summary?${params.toString()}`);
  }

  async downloadPayrollSummaryCSV(from: string, to: string): Promise<BinaryDownload> {
    const params = new URLSearchParams({ from, to });
    const response = await fetch(`${this.config.baseUrl}/organizations/${this.config.organizationId}/reports/payroll-summary.csv?${params.toString()}`, {
      headers: {
        Authorization: `Bearer ${this.config.accessToken}`
      }
    });
    if (!response.ok) {
      const errorBody = await response.json().catch(() => undefined);
      const message = errorBody?.error?.message ?? `Request failed with ${response.status}`;
      throw new Error(message);
    }
    return {
      blob: await response.blob(),
      filename: filenameFromContentDisposition(response.headers.get("Content-Disposition")) ?? `payroll-summary-${from}-to-${to}.csv`
    };
  }

  async downloadPayrollStatutoryComponentCSV(from: string, to: string, component: string): Promise<BinaryDownload> {
    const params = new URLSearchParams({ from, to, component });
    const response = await fetch(`${this.config.baseUrl}/organizations/${this.config.organizationId}/reports/payroll-statutory-components.csv?${params.toString()}`, {
      headers: {
        Authorization: `Bearer ${this.config.accessToken}`
      }
    });
    if (!response.ok) {
      const errorBody = await response.json().catch(() => undefined);
      const message = errorBody?.error?.message ?? `Request failed with ${response.status}`;
      throw new Error(message);
    }
    return {
      blob: await response.blob(),
      filename: filenameFromContentDisposition(response.headers.get("Content-Disposition")) ?? `payroll-${component.toLowerCase()}-statutory-${from}-to-${to}.csv`
    };
  }

  async listScheduledReports(): Promise<ScheduledReport[]> {
    return this.request(`/organizations/${this.config.organizationId}/reports/scheduled`);
  }

  async createScheduledReport(input: CreateScheduledReportInput): Promise<ScheduledReport> {
    return this.request(`/organizations/${this.config.organizationId}/reports/scheduled`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async listScheduledReportRuns(scheduledReportId: string): Promise<ScheduledReportRun[]> {
    return this.request(`/organizations/${this.config.organizationId}/reports/scheduled/${scheduledReportId}/runs`);
  }

  async listBudgets(): Promise<Budget[]> {
    return this.request(`/organizations/${this.config.organizationId}/budgets`);
  }

  async createBudget(input: CreateBudgetInput): Promise<Budget> {
    return this.request(`/organizations/${this.config.organizationId}/budgets`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async getBudgetVsActual(budgetId: string): Promise<BudgetVsActualReport> {
    return this.request(`/organizations/${this.config.organizationId}/budgets/${budgetId}/vs-actual`);
  }

  async listInvestmentLots(): Promise<InvestmentLot[]> {
    return this.request(`/organizations/${this.config.organizationId}/investments/lots`);
  }

  async createInvestmentLot(input: CreateInvestmentLotInput): Promise<InvestmentLot> {
    return this.request(`/organizations/${this.config.organizationId}/investments/lots`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async listInvestmentDividends(): Promise<InvestmentDividend[]> {
    return this.request(`/organizations/${this.config.organizationId}/investments/dividends`);
  }

  async createInvestmentDividend(input: CreateInvestmentDividendInput): Promise<InvestmentDividend> {
    return this.request(`/organizations/${this.config.organizationId}/investments/dividends`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async listInvestmentCorporateActions(): Promise<InvestmentCorporateAction[]> {
    return this.request(`/organizations/${this.config.organizationId}/investments/corporate-actions`);
  }

  async createInvestmentCorporateAction(input: CreateInvestmentCorporateActionInput): Promise<InvestmentCorporateAction> {
    return this.request(`/organizations/${this.config.organizationId}/investments/corporate-actions`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async sellInvestmentLot(lotId: string, input: SellInvestmentLotInput): Promise<InvestmentDisposition> {
    return this.request(`/organizations/${this.config.organizationId}/investments/lots/${lotId}/sell`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async sellAverageCost(input: SellAverageCostInput): Promise<AverageCostSaleResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/average-cost-sales`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async listInvestmentPrices(): Promise<InvestmentPrice[]> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices`);
  }

  async createInvestmentPrice(input: CreateInvestmentPriceInput): Promise<InvestmentPrice> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importInvestmentPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importAMFINAV(input: ImportAMFINAVInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/amfi`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importNSEEquityPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/nse`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importBSEEquityPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/bse`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importYahooFinancePrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/yahoo`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importAlphaVantagePrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/alphavantage`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importBrokerHoldingsPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/broker-holdings`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importZerodhaHoldingsPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/zerodha-holdings`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importGrowwHoldingsPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/groww-holdings`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importUpstoxHoldingsPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/upstox-holdings`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importAngelOneHoldingsPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/angelone-holdings`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importDhanHoldingsPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/dhan-holdings`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importICICIDirectHoldingsPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/icicidirect-holdings`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importHDFCSkyHoldingsPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/hdfcsky-holdings`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importKotakNeoHoldingsPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/kotakneo-holdings`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importPaytmMoneyHoldingsPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/paytmmoney-holdings`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importMotilalOswalHoldingsPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/motilaloswal-holdings`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importSharekhanHoldingsPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/sharekhan-holdings`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importFivePaisaHoldingsPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/fivepaisa-holdings`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importAxisDirectHoldingsPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/axisdirect-holdings`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importSBISecuritiesHoldingsPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/sbisecurities-holdings`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importNuvamaHoldingsPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/nuvama-holdings`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importGeojitHoldingsPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/geojit-holdings`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importIIFLSecuritiesHoldingsPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/iiflsecurities-holdings`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importFYERSHoldingsPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/fyers-holdings`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importEdelweissHoldingsPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/edelweiss-holdings`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importAliceBlueHoldingsPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/aliceblue-holdings`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importSamcoHoldingsPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/samco-holdings`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importChoiceHoldingsPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/choice-holdings`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importReligareHoldingsPrices(input: ImportInvestmentPricesInput): Promise<InvestmentPriceImportResult> {
    return this.request(`/organizations/${this.config.organizationId}/investments/prices/import/religare-holdings`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async getRealizedGains(from: string, to: string): Promise<RealizedGainsReport> {
    const params = new URLSearchParams({ from, to });
    return this.request(`/organizations/${this.config.organizationId}/reports/realized-gains?${params.toString()}`);
  }

  async getInvestmentDividends(from: string, to: string): Promise<InvestmentDividendReport> {
    const params = new URLSearchParams({ from, to });
    return this.request(`/organizations/${this.config.organizationId}/reports/investment-dividends?${params.toString()}`);
  }

  async getInvestmentCorporateActions(from: string, to: string): Promise<InvestmentCorporateActionReport> {
    const params = new URLSearchParams({ from, to });
    return this.request(`/organizations/${this.config.organizationId}/reports/investment-corporate-actions?${params.toString()}`);
  }

  async downloadInvestmentCorporateActionsCSV(from: string, to: string): Promise<BinaryDownload> {
    const params = new URLSearchParams({ from, to });
    const response = await fetch(`${this.config.baseUrl}/organizations/${this.config.organizationId}/reports/investment-corporate-actions.csv?${params.toString()}`, {
      headers: {
        Authorization: `Bearer ${this.config.accessToken}`
      }
    });
    if (!response.ok) {
      const errorBody = await response.json().catch(() => undefined);
      const message = errorBody?.error?.message ?? `Request failed with ${response.status}`;
      throw new Error(message);
    }
    return {
      blob: await response.blob(),
      filename: filenameFromContentDisposition(response.headers.get("Content-Disposition")) ?? `investment-corporate-actions-${from}-to-${to}.csv`
    };
  }

  async getInvestmentTaxLots(asOf: string): Promise<InvestmentTaxLotReport> {
    const params = new URLSearchParams({ as_of: asOf });
    return this.request(`/organizations/${this.config.organizationId}/reports/investment-tax-lots?${params.toString()}`);
  }

  async getInvestmentTaxAdjustments(from: string, to: string, windowDays = 30): Promise<InvestmentTaxAdjustmentReport> {
    const params = new URLSearchParams({ from, to, window_days: String(windowDays) });
    return this.request(`/organizations/${this.config.organizationId}/reports/investment-tax-adjustments?${params.toString()}`);
  }

  async getInvestmentValuation(asOf: string): Promise<InvestmentValuationReport> {
    const params = new URLSearchParams({ as_of: asOf });
    return this.request(`/organizations/${this.config.organizationId}/reports/investment-valuation?${params.toString()}`);
  }

  async listPayrollRuns(): Promise<PayrollRun[]> {
    return this.request(`/organizations/${this.config.organizationId}/payroll/runs`);
  }

  async createPayrollRun(input: CreatePayrollRunInput): Promise<PayrollRun> {
    return this.request(`/organizations/${this.config.organizationId}/payroll/runs`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async previewIndiaPayroll(input: PreviewIndiaPayrollInput): Promise<IndiaPayrollPreview> {
    return this.request(`/organizations/${this.config.organizationId}/payroll/india-preview`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async listIndiaProfessionalTaxPresets(): Promise<IndiaProfessionalTaxPreset[]> {
    return this.request(`/organizations/${this.config.organizationId}/payroll/india-professional-tax-presets`);
  }

  async getPayslipPreview(payrollRunId: string, payrollItemId: string): Promise<PayslipPreview> {
    return this.request(`/organizations/${this.config.organizationId}/payroll/runs/${payrollRunId}/items/${payrollItemId}/payslip`);
  }

  async downloadPayslipPDF(payrollRunId: string, payrollItemId: string): Promise<BinaryDownload> {
    const response = await fetch(`${this.config.baseUrl}/organizations/${this.config.organizationId}/payroll/runs/${payrollRunId}/items/${payrollItemId}/payslip.pdf`, {
      headers: {
        Authorization: `Bearer ${this.config.accessToken}`
      }
    });
    if (!response.ok) {
      const errorBody = await response.json().catch(() => undefined);
      const message = errorBody?.error?.message ?? `Request failed with ${response.status}`;
      throw new Error(message);
    }
    return {
      blob: await response.blob(),
      filename: filenameFromContentDisposition(response.headers.get("Content-Disposition")) ?? `payslip-${payrollRunId}.pdf`
    };
  }

  async postPayrollRun(payrollRunId: string): Promise<PayrollRun> {
    return this.request(`/organizations/${this.config.organizationId}/payroll/runs/${payrollRunId}/post`, {
      method: "POST"
    });
  }

  async listEmployees(): Promise<Employee[]> {
    return this.request(`/organizations/${this.config.organizationId}/employees`);
  }

  async createEmployee(input: EmployeeInput): Promise<Employee> {
    return this.request(`/organizations/${this.config.organizationId}/employees`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async listCustomers(): Promise<Customer[]> {
    return this.request(`/organizations/${this.config.organizationId}/customers`);
  }

  async createCustomer(input: CustomerInput): Promise<Customer> {
    return this.request(`/organizations/${this.config.organizationId}/customers`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async listInvoices(): Promise<Invoice[]> {
    return this.request(`/organizations/${this.config.organizationId}/invoices`);
  }

  async createInvoice(input: CreateInvoiceInput): Promise<Invoice> {
    return this.request(`/organizations/${this.config.organizationId}/invoices`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async postInvoice(invoiceId: string): Promise<Invoice> {
    return this.request(`/organizations/${this.config.organizationId}/invoices/${invoiceId}/post`, {
      method: "POST"
    });
  }

  async listRecurringInvoices(): Promise<RecurringInvoiceTemplate[]> {
    return this.request(`/organizations/${this.config.organizationId}/recurring-invoices`);
  }

  async createRecurringInvoice(input: CreateRecurringInvoiceTemplateInput): Promise<RecurringInvoiceTemplate> {
    return this.request(`/organizations/${this.config.organizationId}/recurring-invoices`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async generateDueRecurringInvoices(asOf?: string): Promise<GenerateDueRecurringInvoicesResult> {
    const suffix = asOf ? `?as_of=${encodeURIComponent(asOf)}` : "";
    return this.request(`/organizations/${this.config.organizationId}/recurring-invoices/generate-due${suffix}`, {
      method: "POST"
    });
  }

  async listEstimates(): Promise<Estimate[]> {
    return this.request(`/organizations/${this.config.organizationId}/estimates`);
  }

  async createEstimate(input: CreateEstimateInput): Promise<Estimate> {
    return this.request(`/organizations/${this.config.organizationId}/estimates`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async convertEstimateToInvoice(estimateId: string, input: ConvertEstimateToInvoiceInput): Promise<Invoice> {
    return this.request(`/organizations/${this.config.organizationId}/estimates/${estimateId}/convert-to-invoice`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async updateEstimateStatus(estimateId: string, status: Estimate["status"]): Promise<Estimate> {
    return this.request(`/organizations/${this.config.organizationId}/estimates/${estimateId}/status`, {
      method: "POST",
      body: JSON.stringify({ status })
    });
  }

  async listCreditNotes(): Promise<CreditNote[]> {
    return this.request(`/organizations/${this.config.organizationId}/credit-notes`);
  }

  async createCreditNote(input: CreateCreditNoteInput): Promise<CreditNote> {
    return this.request(`/organizations/${this.config.organizationId}/credit-notes`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async postCreditNote(creditNoteId: string): Promise<CreditNote> {
    return this.request(`/organizations/${this.config.organizationId}/credit-notes/${creditNoteId}/post`, {
      method: "POST"
    });
  }

  async listCustomerPayments(invoiceId: string): Promise<CustomerPayment[]> {
    return this.request(`/organizations/${this.config.organizationId}/invoices/${invoiceId}/payments`);
  }

  async recordCustomerPayment(invoiceId: string, input: RecordPaymentInput): Promise<CustomerPayment> {
    return this.request(`/organizations/${this.config.organizationId}/invoices/${invoiceId}/payments`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async listVendors(): Promise<Vendor[]> {
    return this.request(`/organizations/${this.config.organizationId}/vendors`);
  }

  async createVendor(input: VendorInput): Promise<Vendor> {
    return this.request(`/organizations/${this.config.organizationId}/vendors`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async listExpenses(): Promise<Expense[]> {
    return this.request(`/organizations/${this.config.organizationId}/expenses`);
  }

  async createExpense(input: CreateExpenseInput): Promise<Expense> {
    return this.request(`/organizations/${this.config.organizationId}/expenses`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async postExpense(expenseId: string): Promise<Expense> {
    return this.request(`/organizations/${this.config.organizationId}/expenses/${expenseId}/post`, {
      method: "POST"
    });
  }

  async listBills(): Promise<Bill[]> {
    return this.request(`/organizations/${this.config.organizationId}/bills`);
  }

  async createBill(input: CreateBillInput): Promise<Bill> {
    return this.request(`/organizations/${this.config.organizationId}/bills`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async postBill(billId: string): Promise<Bill> {
    return this.request(`/organizations/${this.config.organizationId}/bills/${billId}/post`, {
      method: "POST"
    });
  }

  async listPurchaseOrders(): Promise<PurchaseOrder[]> {
    return this.request(`/organizations/${this.config.organizationId}/purchase-orders`);
  }

  async createPurchaseOrder(input: CreatePurchaseOrderInput): Promise<PurchaseOrder> {
    return this.request(`/organizations/${this.config.organizationId}/purchase-orders`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async convertPurchaseOrderToBill(purchaseOrderId: string, input: ConvertPurchaseOrderToBillInput): Promise<Bill> {
    return this.request(`/organizations/${this.config.organizationId}/purchase-orders/${purchaseOrderId}/convert-to-bill`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async updatePurchaseOrderStatus(purchaseOrderId: string, status: PurchaseOrder["status"]): Promise<PurchaseOrder> {
    return this.request(`/organizations/${this.config.organizationId}/purchase-orders/${purchaseOrderId}/status`, {
      method: "POST",
      body: JSON.stringify({ status })
    });
  }

  async listVendorPayments(billId: string): Promise<VendorPayment[]> {
    return this.request(`/organizations/${this.config.organizationId}/bills/${billId}/payments`);
  }

  async recordVendorPayment(billId: string, input: RecordPaymentInput): Promise<VendorPayment> {
    return this.request(`/organizations/${this.config.organizationId}/bills/${billId}/payments`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importBankStatement(input: ImportBankStatementInput): Promise<BankStatementImport> {
    return this.request(`/organizations/${this.config.organizationId}/bank-statements/import`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importQIFBankStatement(input: ImportQIFBankStatementInput): Promise<BankStatementImport> {
    return this.request(`/organizations/${this.config.organizationId}/bank-statements/import/qif`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async importOFXBankStatement(input: ImportOFXBankStatementInput): Promise<BankStatementImport> {
    return this.request(`/organizations/${this.config.organizationId}/bank-statements/import/ofx`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async listBankStatementLines(accountId: string): Promise<BankStatementLine[]> {
    const params = new URLSearchParams({ account_id: accountId });
    return this.request(`/organizations/${this.config.organizationId}/bank-statement-lines?${params.toString()}`);
  }

  async matchBankStatementLine(statementLineId: string, ledgerSplitId: string): Promise<BankStatementLine> {
    return this.request(`/organizations/${this.config.organizationId}/bank-statement-lines/${statementLineId}/match`, {
      method: "POST",
      body: JSON.stringify({ ledger_split_id: ledgerSplitId })
    });
  }

  async reconcileLedgerSplit(splitId: string): Promise<LedgerSplit> {
    return this.request(`/organizations/${this.config.organizationId}/ledger/splits/${splitId}/reconcile`, {
      method: "POST"
    });
  }

  async listBackups(): Promise<BackupSnapshot[]> {
    return this.request(`/organizations/${this.config.organizationId}/data/backups`);
  }

  async createBackup(input: CreateBackupSnapshotInput): Promise<BackupSnapshot> {
    return this.request(`/organizations/${this.config.organizationId}/data/backups`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async listExchangeRates(): Promise<ExchangeRate[]> {
    return this.request(`/organizations/${this.config.organizationId}/exchange-rates`);
  }

  async createExchangeRate(input: CreateExchangeRateInput): Promise<ExchangeRate> {
    return this.request(`/organizations/${this.config.organizationId}/exchange-rates`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async previewRevaluation(asOf: string): Promise<RevaluationPreview> {
    return this.request(`/organizations/${this.config.organizationId}/revaluations/preview?as_of=${encodeURIComponent(asOf)}`);
  }

  async postRevaluation(input: PostRevaluationInput): Promise<JournalTransaction> {
    return this.request(`/organizations/${this.config.organizationId}/revaluations`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async listFiscalCloses(): Promise<FiscalClose[]> {
    return this.request(`/organizations/${this.config.organizationId}/closing/fiscal-years`);
  }

  async closeFiscalYear(input: CloseFiscalYearInput): Promise<FiscalClose> {
    return this.request(`/organizations/${this.config.organizationId}/closing/fiscal-years`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async listAuditLogs(): Promise<AuditLog[]> {
    return this.request(`/organizations/${this.config.organizationId}/audit-logs`);
  }

  async listOrganizationUsers(): Promise<OrganizationUser[]> {
    return this.request(`/organizations/${this.config.organizationId}/users`);
  }

  async createOrganizationUser(input: CreateOrganizationUserInput): Promise<OrganizationUser> {
    return this.request(`/organizations/${this.config.organizationId}/users`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async updateOrganizationUser(userId: string, input: UpdateOrganizationUserInput): Promise<OrganizationUser> {
    return this.request(`/organizations/${this.config.organizationId}/users/${userId}`, {
      method: "PATCH",
      body: JSON.stringify(input)
    });
  }

  async listAttachments(): Promise<Attachment[]> {
    return this.request(`/organizations/${this.config.organizationId}/attachments`);
  }

  async createAttachment(input: CreateAttachmentInput): Promise<Attachment> {
    return this.request(`/organizations/${this.config.organizationId}/attachments`, {
      method: "POST",
      body: JSON.stringify(input)
    });
  }

  async uploadAttachment(file: File): Promise<Attachment> {
    const body = new FormData();
    body.append("file", file);
    const response = await fetch(`${this.config.baseUrl}/organizations/${this.config.organizationId}/attachments/upload`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${this.config.accessToken}`
      },
      body
    });
    if (!response.ok) {
      const errorBody = await response.json().catch(() => undefined);
      const message = errorBody?.error?.message ?? `Request failed with ${response.status}`;
      throw new Error(message);
    }
    return response.json();
  }

  attachmentDownloadUrl(attachmentId: string): string {
    return `${this.config.baseUrl}/organizations/${this.config.organizationId}/attachments/${attachmentId}/download`;
  }

  private async downloadBinary(path: string, fallbackFilename: string): Promise<BinaryDownload> {
    const response = await fetch(`${this.config.baseUrl}${path}`, {
      headers: {
        Authorization: `Bearer ${this.config.accessToken}`
      }
    });
    if (!response.ok) {
      const errorBody = await response.json().catch(() => undefined);
      const message = errorBody?.error?.message ?? `Request failed with ${response.status}`;
      throw new Error(message);
    }
    return {
      blob: await response.blob(),
      filename: filenameFromContentDisposition(response.headers.get("Content-Disposition")) ?? fallbackFilename
    };
  }

  private async request<T>(path: string, init: RequestInit = {}): Promise<T> {
    const response = await fetch(`${this.config.baseUrl}${path}`, {
      ...init,
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${this.config.accessToken}`,
        ...init.headers
      }
    });

    if (!response.ok) {
      const body = await response.json().catch(() => undefined);
      const message = body?.error?.message ?? `Request failed with ${response.status}`;
      throw new Error(message);
    }
    return response.json();
  }

  private async publicRequest<T>(path: string, init: RequestInit = {}): Promise<T> {
    const response = await fetch(`${this.config.baseUrl}${path}`, {
      ...init,
      headers: {
        "Content-Type": "application/json",
        ...init.headers
      }
    });

    if (!response.ok) {
      const body = await response.json().catch(() => undefined);
      const message = body?.error?.message ?? `Request failed with ${response.status}`;
      throw new Error(message);
    }
    return response.json();
  }
}

function filenameFromContentDisposition(value: string | null): string | null {
  if (!value) {
    return null;
  }
  const match = /filename="?([^";]+)"?/i.exec(value);
  return match?.[1] ?? null;
}
