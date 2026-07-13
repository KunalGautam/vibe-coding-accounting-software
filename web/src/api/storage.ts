import type { Account, AccountInput, ApiConfig, APAgingReport, APAgingRow, ARAgingReport, ARAgingRow, Attachment, AuditLog, BalanceSheetReport, BankStatementLine, Bill, Budget, BudgetLine, BudgetVsActualReport, BudgetVsActualReportRow, CashFlowReport, CashFlowRow, CreditNote, Customer, Employee, Estimate, ExchangeRate, Expense, FiscalClose, InvestmentDisposition, InvestmentLot, Invoice, JournalTransaction, JournalTransactionInput, OrganizationUser, PayrollComponent, PayrollRun, PayslipPreview, ProfitAndLossReport, PurchaseOrder, RealizedGainsReport, RecurringInvoiceTemplate, ReportRow, TaxAuthority, TaxGroup, TaxLiabilityReport, TaxRate, TaxReportRow, TaxSummaryReport, TrialBalanceReport, Vendor } from "./client";

const key = "accounting-web-config";
const accountDraftKey = "accounting-web-account-drafts";
const journalDraftKey = "accounting-web-journal-drafts";
const accountingSnapshotKey = "accounting-web-snapshot";
const reportSnapshotKey = "accounting-web-report-snapshot";

export type QueuedAccountDraft = {
  id: string;
  createdAt: string;
  input: AccountInput;
  lastError?: string;
};

export type QueuedJournalDraft = {
  id: string;
  createdAt: string;
  input: JournalTransactionInput;
  lastError?: string;
};

export type AccountingSnapshot = {
  savedAt: string;
  accounts: Account[];
  transactions: JournalTransaction[];
  accountRegisterAccountId?: string;
  accountRegisterSplits?: JournalTransaction["splits"];
  taxAuthorities?: TaxAuthority[];
  taxRates?: TaxRate[];
  taxGroups?: TaxGroup[];
  payrollRuns?: PayrollRun[];
  employees?: Employee[];
  lastPayslipPreview?: PayslipPreview;
  customers?: Customer[];
  invoices?: Invoice[];
  recurringInvoices?: RecurringInvoiceTemplate[];
  estimates?: Estimate[];
  creditNotes?: CreditNote[];
  vendors?: Vendor[];
  expenses?: Expense[];
  bills?: Bill[];
  purchaseOrders?: PurchaseOrder[];
  bankStatementLines?: BankStatementLine[];
  exchangeRates?: ExchangeRate[];
  fiscalCloses?: FiscalClose[];
  auditLogs?: AuditLog[];
  organizationUsers?: OrganizationUser[];
  attachments?: Attachment[];
  budgets?: Budget[];
  investmentLots?: InvestmentLot[];
};

export type ReportSnapshot = {
  savedAt: string;
  trialBalance?: TrialBalanceReport;
  profitAndLoss?: ProfitAndLossReport;
  balanceSheet?: BalanceSheetReport;
  cashFlow?: CashFlowReport;
  arAging?: ARAgingReport;
  apAging?: APAgingReport;
  taxLiability?: TaxLiabilityReport;
  taxSummary?: TaxSummaryReport;
  budgetVsActual?: BudgetVsActualReport;
  realizedGains?: RealizedGainsReport;
};

export function loadConfig(): ApiConfig {
  const stored = window.localStorage.getItem(key);
  if (!stored) {
    return defaultConfig();
  }
  try {
    const parsed = JSON.parse(stored) as Partial<ApiConfig>;
    return {
      ...defaultConfig(),
      ...parsed
    };
  } catch {
    return defaultConfig();
  }
}

export function saveConfig(config: ApiConfig) {
  window.localStorage.setItem(key, JSON.stringify(config));
}

export function loadAccountDrafts(): QueuedAccountDraft[] {
  const stored = window.localStorage.getItem(accountDraftKey);
  if (!stored) {
    return [];
  }
  try {
    const parsed = JSON.parse(stored);
    if (!Array.isArray(parsed)) {
      return [];
    }
    return parsed.filter(isQueuedAccountDraft);
  } catch {
    return [];
  }
}

export function saveAccountDrafts(drafts: QueuedAccountDraft[]) {
  window.localStorage.setItem(accountDraftKey, JSON.stringify(drafts));
}

export function loadJournalDrafts(): QueuedJournalDraft[] {
  const stored = window.localStorage.getItem(journalDraftKey);
  if (!stored) {
    return [];
  }
  try {
    const parsed = JSON.parse(stored);
    if (!Array.isArray(parsed)) {
      return [];
    }
    return parsed.filter(isQueuedJournalDraft);
  } catch {
    return [];
  }
}

export function saveJournalDrafts(drafts: QueuedJournalDraft[]) {
  window.localStorage.setItem(journalDraftKey, JSON.stringify(drafts));
}

export function loadAccountingSnapshot(): AccountingSnapshot | null {
  const stored = window.localStorage.getItem(accountingSnapshotKey);
  if (!stored) {
    return null;
  }
  try {
    const parsed = JSON.parse(stored);
    if (!isAccountingSnapshot(parsed)) {
      return null;
    }
    return parsed;
  } catch {
    return null;
  }
}

export function saveAccountingSnapshot(snapshot: AccountingSnapshot) {
  window.localStorage.setItem(accountingSnapshotKey, JSON.stringify(snapshot));
}

export function loadReportSnapshot(): ReportSnapshot | null {
  const stored = window.localStorage.getItem(reportSnapshotKey);
  if (!stored) {
    return null;
  }
  try {
    const parsed = JSON.parse(stored);
    if (!isReportSnapshot(parsed)) {
      return null;
    }
    return parsed;
  } catch {
    return null;
  }
}

export function saveReportSnapshot(snapshot: ReportSnapshot) {
  window.localStorage.setItem(reportSnapshotKey, JSON.stringify(snapshot));
}

export function clearReportSnapshot() {
  window.localStorage.removeItem(reportSnapshotKey);
}

function defaultConfig(): ApiConfig {
  return {
    baseUrl: "http://localhost:8080/api/v1",
    accessToken: "",
    refreshToken: "",
    organizationId: ""
  };
}

function isQueuedJournalDraft(value: unknown): value is QueuedJournalDraft {
  if (!value || typeof value !== "object") {
    return false;
  }
  const draft = value as QueuedJournalDraft;
  return (
    typeof draft.id === "string" &&
    typeof draft.createdAt === "string" &&
    isJournalTransactionInput(draft.input) &&
    (draft.lastError === undefined || typeof draft.lastError === "string")
  );
}

function isQueuedAccountDraft(value: unknown): value is QueuedAccountDraft {
  if (!value || typeof value !== "object") {
    return false;
  }
  const draft = value as QueuedAccountDraft;
  return (
    typeof draft.id === "string" &&
    typeof draft.createdAt === "string" &&
    isAccountInput(draft.input) &&
    (draft.lastError === undefined || typeof draft.lastError === "string")
  );
}

function isAccountInput(value: unknown): value is AccountInput {
  if (!value || typeof value !== "object") {
    return false;
  }
  const input = value as AccountInput;
  return (
    typeof input.code === "string" &&
    typeof input.name === "string" &&
    ["asset", "liability", "equity", "income", "expense"].includes(input.type) &&
    (input.subtype === undefined || typeof input.subtype === "string") &&
    (input.currency === undefined || typeof input.currency === "string")
  );
}

function isJournalTransactionInput(value: unknown): value is JournalTransactionInput {
  if (!value || typeof value !== "object") {
    return false;
  }
  const input = value as JournalTransactionInput;
  return (
    typeof input.transaction_date === "string" &&
    Array.isArray(input.splits) &&
    input.splits.every((split) => (
      split &&
      typeof split === "object" &&
      typeof split.account_id === "string" &&
      typeof split.debit_minor === "number" &&
      typeof split.credit_minor === "number" &&
      typeof split.currency === "string"
    ))
  );
}

function isAccountingSnapshot(value: unknown): value is AccountingSnapshot {
  if (!value || typeof value !== "object") {
    return false;
  }
  const snapshot = value as AccountingSnapshot;
  return (
    typeof snapshot.savedAt === "string" &&
    Array.isArray(snapshot.accounts) &&
    Array.isArray(snapshot.transactions) &&
    snapshot.accounts.every(isAccount) &&
    snapshot.transactions.every(isJournalTransaction) &&
    (snapshot.accountRegisterAccountId === undefined || typeof snapshot.accountRegisterAccountId === "string") &&
    (snapshot.accountRegisterSplits === undefined || (Array.isArray(snapshot.accountRegisterSplits) && snapshot.accountRegisterSplits.every(isLedgerSplit))) &&
    (snapshot.taxAuthorities === undefined || (Array.isArray(snapshot.taxAuthorities) && snapshot.taxAuthorities.every(isTaxAuthority))) &&
    (snapshot.taxRates === undefined || (Array.isArray(snapshot.taxRates) && snapshot.taxRates.every(isTaxRate))) &&
    (snapshot.taxGroups === undefined || (Array.isArray(snapshot.taxGroups) && snapshot.taxGroups.every(isTaxGroup))) &&
    (snapshot.payrollRuns === undefined || (Array.isArray(snapshot.payrollRuns) && snapshot.payrollRuns.every(isPayrollRun))) &&
    (snapshot.employees === undefined || (Array.isArray(snapshot.employees) && snapshot.employees.every(isEmployee))) &&
    (snapshot.lastPayslipPreview === undefined || isPayslipPreview(snapshot.lastPayslipPreview)) &&
    (snapshot.customers === undefined || (Array.isArray(snapshot.customers) && snapshot.customers.every(isCustomer))) &&
    (snapshot.invoices === undefined || (Array.isArray(snapshot.invoices) && snapshot.invoices.every(isInvoice))) &&
    (snapshot.recurringInvoices === undefined || (Array.isArray(snapshot.recurringInvoices) && snapshot.recurringInvoices.every(isRecurringInvoiceTemplate))) &&
    (snapshot.estimates === undefined || (Array.isArray(snapshot.estimates) && snapshot.estimates.every(isEstimate))) &&
    (snapshot.creditNotes === undefined || (Array.isArray(snapshot.creditNotes) && snapshot.creditNotes.every(isCreditNote))) &&
    (snapshot.vendors === undefined || (Array.isArray(snapshot.vendors) && snapshot.vendors.every(isVendor))) &&
    (snapshot.expenses === undefined || (Array.isArray(snapshot.expenses) && snapshot.expenses.every(isExpense))) &&
    (snapshot.bills === undefined || (Array.isArray(snapshot.bills) && snapshot.bills.every(isBill))) &&
    (snapshot.purchaseOrders === undefined || (Array.isArray(snapshot.purchaseOrders) && snapshot.purchaseOrders.every(isPurchaseOrder))) &&
    (snapshot.bankStatementLines === undefined || (Array.isArray(snapshot.bankStatementLines) && snapshot.bankStatementLines.every(isBankStatementLine))) &&
    (snapshot.exchangeRates === undefined || (Array.isArray(snapshot.exchangeRates) && snapshot.exchangeRates.every(isExchangeRate))) &&
    (snapshot.fiscalCloses === undefined || (Array.isArray(snapshot.fiscalCloses) && snapshot.fiscalCloses.every(isFiscalClose))) &&
    (snapshot.auditLogs === undefined || (Array.isArray(snapshot.auditLogs) && snapshot.auditLogs.every(isAuditLog))) &&
    (snapshot.organizationUsers === undefined || (Array.isArray(snapshot.organizationUsers) && snapshot.organizationUsers.every(isOrganizationUser))) &&
    (snapshot.attachments === undefined || (Array.isArray(snapshot.attachments) && snapshot.attachments.every(isAttachment))) &&
    (snapshot.budgets === undefined || (Array.isArray(snapshot.budgets) && snapshot.budgets.every(isBudget))) &&
    (snapshot.investmentLots === undefined || (Array.isArray(snapshot.investmentLots) && snapshot.investmentLots.every(isInvestmentLot)))
  );
}

function isAccount(value: unknown): value is Account {
  if (!value || typeof value !== "object") {
    return false;
  }
  const account = value as Account;
  return (
    typeof account.id === "string" &&
    typeof account.code === "string" &&
    typeof account.name === "string" &&
    ["asset", "liability", "equity", "income", "expense"].includes(account.type) &&
    typeof account.currency === "string" &&
    typeof account.is_active === "boolean"
  );
}

function isJournalTransaction(value: unknown): value is JournalTransaction {
  if (!value || typeof value !== "object") {
    return false;
  }
  const transaction = value as JournalTransaction;
  return (
    typeof transaction.id === "string" &&
    typeof transaction.transaction_date === "string" &&
    typeof transaction.source_module === "string" &&
    typeof transaction.status === "string" &&
    Array.isArray(transaction.splits) &&
    transaction.splits.every(isLedgerSplit)
  );
}

function isLedgerSplit(value: unknown) {
  if (!value || typeof value !== "object") {
    return false;
  }
  const split = value as JournalTransaction["splits"][number];
  return (
    typeof split.id === "string" &&
    typeof split.account_id === "string" &&
    typeof split.debit_minor === "number" &&
    typeof split.credit_minor === "number" &&
    typeof split.currency === "string" &&
    typeof split.cleared === "boolean" &&
    typeof split.reconciled === "boolean"
  );
}

function isTaxRate(value: unknown): value is TaxRate {
  if (!value || typeof value !== "object") {
    return false;
  }
  const rate = value as TaxRate;
  return (
    typeof rate.id === "string" &&
    typeof rate.tax_authority_id === "string" &&
    typeof rate.name === "string" &&
    typeof rate.percentage_basis === "number" &&
    ["VAT", "GST", "Sales Tax", "Withholding"].includes(rate.type) &&
    typeof rate.effective_from === "string" &&
    (rate.effective_to === undefined || rate.effective_to === null || typeof rate.effective_to === "string") &&
    typeof rate.is_compound === "boolean" &&
    typeof rate.is_active === "boolean"
  );
}

function isTaxAuthority(value: unknown): value is TaxAuthority {
  if (!value || typeof value !== "object") {
    return false;
  }
  const authority = value as TaxAuthority;
  return (
    typeof authority.id === "string" &&
    typeof authority.organization_id === "string" &&
    typeof authority.name === "string" &&
    (authority.country_code === undefined || typeof authority.country_code === "string") &&
    (authority.region_code === undefined || typeof authority.region_code === "string") &&
    typeof authority.is_active === "boolean"
  );
}

function isTaxGroup(value: unknown): value is TaxGroup {
  if (!value || typeof value !== "object") {
    return false;
  }
  const group = value as TaxGroup;
  return (
    typeof group.id === "string" &&
    typeof group.organization_id === "string" &&
    typeof group.name === "string" &&
    (group.description === undefined || typeof group.description === "string") &&
    typeof group.is_active === "boolean" &&
    Array.isArray(group.components) &&
    group.components.every(isTaxGroupComponent)
  );
}

function isTaxGroupComponent(value: unknown) {
  if (!value || typeof value !== "object") {
    return false;
  }
  const component = value as TaxGroup["components"][number];
  return (
    typeof component.id === "string" &&
    typeof component.tax_group_id === "string" &&
    typeof component.tax_rate_id === "string" &&
    typeof component.sort_order === "number" &&
    (component.tax_rate === undefined || isTaxRate(component.tax_rate))
  );
}

function isPayrollRun(value: unknown): value is PayrollRun {
  if (!value || typeof value !== "object") {
    return false;
  }
  const run = value as PayrollRun;
  return (
    typeof run.id === "string" &&
    typeof run.organization_id === "string" &&
    typeof run.run_number === "string" &&
    typeof run.period_start === "string" &&
    typeof run.period_end === "string" &&
    typeof run.pay_date === "string" &&
    ["draft", "posted", "void"].includes(run.status) &&
    (run.currency === undefined || typeof run.currency === "string") &&
    typeof run.gross_pay_minor === "number" &&
    typeof run.deductions_minor === "number" &&
    typeof run.net_pay_minor === "number" &&
    (run.journal_transaction_id === undefined || run.journal_transaction_id === null || typeof run.journal_transaction_id === "string") &&
    (run.items === undefined || Array.isArray(run.items))
  );
}

function isEmployee(value: unknown): value is Employee {
  if (!value || typeof value !== "object") {
    return false;
  }
  const employee = value as Employee;
  return (
    typeof employee.id === "string" &&
    typeof employee.organization_id === "string" &&
    typeof employee.display_name === "string" &&
    (employee.email === undefined || typeof employee.email === "string") &&
    (employee.phone === undefined || typeof employee.phone === "string") &&
    (employee.employee_code === undefined || typeof employee.employee_code === "string") &&
    (employee.pan === undefined || typeof employee.pan === "string") &&
    (employee.uan === undefined || typeof employee.uan === "string") &&
    typeof employee.is_active === "boolean"
  );
}

function isPayrollComponent(value: unknown): value is PayrollComponent {
  if (!value || typeof value !== "object") {
    return false;
  }
  const component = value as PayrollComponent;
  return (
    typeof component.code === "string" &&
    typeof component.name === "string" &&
    ["earning", "deduction"].includes(component.type) &&
    typeof component.amount_minor === "number" &&
    typeof component.is_statutory === "boolean"
  );
}

function isPayslipPreview(value: unknown): value is PayslipPreview {
  if (!value || typeof value !== "object") {
    return false;
  }
  const preview = value as PayslipPreview;
  return (
    typeof preview.organization_id === "string" &&
    typeof preview.payroll_run_id === "string" &&
    typeof preview.payroll_item_id === "string" &&
    typeof preview.run_number === "string" &&
    typeof preview.period_start === "string" &&
    typeof preview.period_end === "string" &&
    typeof preview.pay_date === "string" &&
    ["draft", "posted", "void"].includes(preview.status) &&
    typeof preview.currency === "string" &&
    isEmployee(preview.employee) &&
    typeof preview.gross_pay_minor === "number" &&
    typeof preview.deductions_minor === "number" &&
    typeof preview.net_pay_minor === "number" &&
    (preview.payslip_key === undefined || typeof preview.payslip_key === "string") &&
    Array.isArray(preview.earnings) &&
    preview.earnings.every(isPayrollComponent) &&
    Array.isArray(preview.deductions) &&
    preview.deductions.every(isPayrollComponent) &&
    Array.isArray(preview.components) &&
    preview.components.every(isPayrollComponent)
  );
}

function isCustomer(value: unknown): value is Customer {
  if (!value || typeof value !== "object") {
    return false;
  }
  const customer = value as Customer;
  return (
    typeof customer.id === "string" &&
    typeof customer.organization_id === "string" &&
    typeof customer.display_name === "string" &&
    (customer.email === undefined || typeof customer.email === "string") &&
    (customer.phone === undefined || typeof customer.phone === "string") &&
    (customer.billing_address === undefined || typeof customer.billing_address === "string") &&
    (customer.gstin === undefined || typeof customer.gstin === "string") &&
    typeof customer.is_active === "boolean"
  );
}

function isInvoice(value: unknown): value is Invoice {
  if (!value || typeof value !== "object") {
    return false;
  }
  const invoice = value as Invoice;
  return (
    typeof invoice.id === "string" &&
    typeof invoice.organization_id === "string" &&
    (invoice.customer_id === undefined || typeof invoice.customer_id === "string") &&
    typeof invoice.invoice_number === "string" &&
    ["draft", "posted", "paid", "void"].includes(invoice.status) &&
    typeof invoice.subtotal_minor === "number" &&
    typeof invoice.tax_total_minor === "number" &&
    typeof invoice.total_minor === "number" &&
    (invoice.issue_date === undefined || typeof invoice.issue_date === "string") &&
    (invoice.due_date === undefined || typeof invoice.due_date === "string") &&
    (invoice.currency === undefined || typeof invoice.currency === "string") &&
    (invoice.journal_transaction_id === undefined || invoice.journal_transaction_id === null || typeof invoice.journal_transaction_id === "string") &&
    (invoice.lines === undefined || Array.isArray(invoice.lines))
  );
}

function isRecurringInvoiceTemplate(value: unknown): value is RecurringInvoiceTemplate {
  if (!value || typeof value !== "object") {
    return false;
  }
  const template = value as RecurringInvoiceTemplate;
  return (
    typeof template.id === "string" &&
    typeof template.organization_id === "string" &&
    typeof template.customer_id === "string" &&
    typeof template.name === "string" &&
    typeof template.invoice_number_prefix === "string" &&
    typeof template.start_date === "string" &&
    typeof template.next_run_date === "string" &&
    ["weekly", "monthly", "yearly"].includes(template.frequency) &&
    typeof template.due_days === "number" &&
    typeof template.subtotal_minor === "number" &&
    typeof template.tax_total_minor === "number" &&
    typeof template.total_minor === "number" &&
    typeof template.accounts_receivable_id === "string" &&
    typeof template.is_active === "boolean" &&
    (template.lines === undefined || Array.isArray(template.lines))
  );
}

function isEstimate(value: unknown): value is Estimate {
  if (!value || typeof value !== "object") {
    return false;
  }
  const estimate = value as Estimate;
  return (
    typeof estimate.id === "string" &&
    typeof estimate.organization_id === "string" &&
    typeof estimate.customer_id === "string" &&
    typeof estimate.estimate_number === "string" &&
    typeof estimate.issue_date === "string" &&
    typeof estimate.expiry_date === "string" &&
    ["draft", "sent", "accepted", "converted", "void"].includes(estimate.status) &&
    typeof estimate.subtotal_minor === "number" &&
    typeof estimate.tax_total_minor === "number" &&
    typeof estimate.total_minor === "number" &&
    (estimate.lines === undefined || Array.isArray(estimate.lines))
  );
}

function isCreditNote(value: unknown): value is CreditNote {
  if (!value || typeof value !== "object") {
    return false;
  }
  const creditNote = value as CreditNote;
  return (
    typeof creditNote.id === "string" &&
    typeof creditNote.organization_id === "string" &&
    typeof creditNote.customer_id === "string" &&
    typeof creditNote.credit_note_number === "string" &&
    typeof creditNote.issue_date === "string" &&
    ["draft", "posted", "void"].includes(creditNote.status) &&
    typeof creditNote.subtotal_minor === "number" &&
    typeof creditNote.tax_total_minor === "number" &&
    typeof creditNote.total_minor === "number" &&
    typeof creditNote.accounts_receivable_id === "string" &&
    (creditNote.invoice_id === undefined || creditNote.invoice_id === null || typeof creditNote.invoice_id === "string") &&
    (creditNote.journal_transaction_id === undefined || creditNote.journal_transaction_id === null || typeof creditNote.journal_transaction_id === "string") &&
    (creditNote.lines === undefined || Array.isArray(creditNote.lines))
  );
}

function isVendor(value: unknown): value is Vendor {
  if (!value || typeof value !== "object") {
    return false;
  }
  const vendor = value as Vendor;
  return (
    typeof vendor.id === "string" &&
    typeof vendor.organization_id === "string" &&
    typeof vendor.display_name === "string" &&
    (vendor.email === undefined || typeof vendor.email === "string") &&
    (vendor.phone === undefined || typeof vendor.phone === "string") &&
    (vendor.billing_address === undefined || typeof vendor.billing_address === "string") &&
    (vendor.gstin === undefined || typeof vendor.gstin === "string") &&
    typeof vendor.is_active === "boolean"
  );
}

function isExpense(value: unknown): value is Expense {
  if (!value || typeof value !== "object") {
    return false;
  }
  const expense = value as Expense;
  return (
    typeof expense.id === "string" &&
    typeof expense.organization_id === "string" &&
    (expense.vendor_id === undefined || expense.vendor_id === null || typeof expense.vendor_id === "string") &&
    typeof expense.expense_number === "string" &&
    typeof expense.expense_date === "string" &&
    ["draft", "posted", "void"].includes(expense.status) &&
    typeof expense.subtotal_minor === "number" &&
    typeof expense.tax_total_minor === "number" &&
    typeof expense.total_minor === "number" &&
    (expense.currency === undefined || typeof expense.currency === "string") &&
    (expense.journal_transaction_id === undefined || expense.journal_transaction_id === null || typeof expense.journal_transaction_id === "string") &&
    (expense.reimbursable === undefined || typeof expense.reimbursable === "boolean")
  );
}

function isBill(value: unknown): value is Bill {
  if (!value || typeof value !== "object") {
    return false;
  }
  const bill = value as Bill;
  return (
    typeof bill.id === "string" &&
    typeof bill.organization_id === "string" &&
    typeof bill.vendor_id === "string" &&
    typeof bill.bill_number === "string" &&
    typeof bill.issue_date === "string" &&
    typeof bill.due_date === "string" &&
    ["draft", "posted", "paid", "void"].includes(bill.status) &&
    typeof bill.subtotal_minor === "number" &&
    typeof bill.tax_total_minor === "number" &&
    typeof bill.total_minor === "number" &&
    typeof bill.accounts_payable_id === "string" &&
    (bill.currency === undefined || typeof bill.currency === "string") &&
    (bill.journal_transaction_id === undefined || bill.journal_transaction_id === null || typeof bill.journal_transaction_id === "string") &&
    (bill.lines === undefined || Array.isArray(bill.lines))
  );
}

function isPurchaseOrder(value: unknown): value is PurchaseOrder {
  if (!value || typeof value !== "object") {
    return false;
  }
  const purchaseOrder = value as PurchaseOrder;
  return (
    typeof purchaseOrder.id === "string" &&
    typeof purchaseOrder.organization_id === "string" &&
    typeof purchaseOrder.vendor_id === "string" &&
    typeof purchaseOrder.purchase_order_number === "string" &&
    typeof purchaseOrder.issue_date === "string" &&
    ["draft", "sent", "approved", "converted", "void"].includes(purchaseOrder.status) &&
    typeof purchaseOrder.subtotal_minor === "number" &&
    typeof purchaseOrder.tax_total_minor === "number" &&
    typeof purchaseOrder.total_minor === "number" &&
    (purchaseOrder.expected_date === undefined || purchaseOrder.expected_date === null || typeof purchaseOrder.expected_date === "string") &&
    (purchaseOrder.lines === undefined || Array.isArray(purchaseOrder.lines))
  );
}

function isBankStatementLine(value: unknown): value is BankStatementLine {
  if (!value || typeof value !== "object") {
    return false;
  }
  const line = value as BankStatementLine;
  return (
    typeof line.id === "string" &&
    typeof line.organization_id === "string" &&
    typeof line.import_id === "string" &&
    typeof line.account_id === "string" &&
    typeof line.posted_date === "string" &&
    typeof line.amount_minor === "number" &&
    (line.description === undefined || typeof line.description === "string") &&
    (line.reference === undefined || typeof line.reference === "string") &&
    (line.matched_split_id === undefined || line.matched_split_id === null || typeof line.matched_split_id === "string") &&
    (line.matched_at === undefined || line.matched_at === null || typeof line.matched_at === "string")
  );
}

function isExchangeRate(value: unknown): value is ExchangeRate {
  if (!value || typeof value !== "object") {
    return false;
  }
  const rate = value as ExchangeRate;
  return (
    typeof rate.id === "string" &&
    typeof rate.organization_id === "string" &&
    typeof rate.from_currency === "string" &&
    typeof rate.to_currency === "string" &&
    typeof rate.rate_date === "string" &&
    typeof rate.numerator === "number" &&
    typeof rate.denominator === "number" &&
    (rate.source === undefined || typeof rate.source === "string")
  );
}

function isFiscalClose(value: unknown): value is FiscalClose {
  if (!value || typeof value !== "object") {
    return false;
  }
  const close = value as FiscalClose;
  return (
    typeof close.id === "string" &&
    typeof close.organization_id === "string" &&
    typeof close.fiscal_year_start === "string" &&
    typeof close.fiscal_year_end === "string" &&
    typeof close.retained_earnings_account_id === "string" &&
    typeof close.net_income_minor === "number" &&
    ["posted", "reversed"].includes(close.status) &&
    typeof close.journal_transaction_id === "string"
  );
}

function isAuditLog(value: unknown): value is AuditLog {
  if (!value || typeof value !== "object") {
    return false;
  }
  const log = value as AuditLog;
  return (
    typeof log.id === "string" &&
    (log.organization_id === undefined || typeof log.organization_id === "string") &&
    (log.actor_user_id === undefined || typeof log.actor_user_id === "string") &&
    typeof log.entity_type === "string" &&
    typeof log.entity_id === "string" &&
    typeof log.action === "string" &&
    (log.before_json === undefined || typeof log.before_json === "string") &&
    (log.after_json === undefined || typeof log.after_json === "string") &&
    (log.ip_address === undefined || typeof log.ip_address === "string") &&
    (log.user_agent === undefined || typeof log.user_agent === "string") &&
    typeof log.created_at === "string"
  );
}

function isOrganizationUser(value: unknown): value is OrganizationUser {
  if (!value || typeof value !== "object") {
    return false;
  }
  const user = value as OrganizationUser;
  return (
    typeof user.user_id === "string" &&
    typeof user.organization_id === "string" &&
    typeof user.name === "string" &&
    typeof user.email === "string" &&
    ["admin", "accountant", "bookkeeper", "payroll_manager", "viewer", "employee_self_service"].includes(user.role) &&
    typeof user.is_active === "boolean"
  );
}

function isAttachment(value: unknown): value is Attachment {
  if (!value || typeof value !== "object") {
    return false;
  }
  const attachment = value as Attachment;
  return (
    typeof attachment.id === "string" &&
    typeof attachment.organization_id === "string" &&
    typeof attachment.file_name === "string" &&
    (attachment.content_type === undefined || typeof attachment.content_type === "string") &&
    typeof attachment.storage_driver === "string" &&
    typeof attachment.storage_key === "string" &&
    typeof attachment.size_bytes === "number"
  );
}

function isBudget(value: unknown): value is Budget {
  if (!value || typeof value !== "object") {
    return false;
  }
  const budget = value as Budget;
  return (
    typeof budget.id === "string" &&
    typeof budget.organization_id === "string" &&
    typeof budget.name === "string" &&
    typeof budget.start_date === "string" &&
    typeof budget.end_date === "string" &&
    ["draft", "active", "closed"].includes(budget.status) &&
    (budget.lines === undefined || (Array.isArray(budget.lines) && budget.lines.every(isBudgetLine)))
  );
}

function isBudgetLine(value: unknown) {
  if (!value || typeof value !== "object") {
    return false;
  }
  const line = value as BudgetLine;
  return (
    typeof line.id === "string" &&
    typeof line.account_id === "string" &&
    typeof line.period_start === "string" &&
    typeof line.period_end === "string" &&
    typeof line.amount_minor === "number"
  );
}

function isInvestmentLot(value: unknown): value is InvestmentLot {
  if (!value || typeof value !== "object") {
    return false;
  }
  const lot = value as InvestmentLot;
  return (
    typeof lot.id === "string" &&
    typeof lot.organization_id === "string" &&
    typeof lot.account_id === "string" &&
    typeof lot.symbol === "string" &&
    (lot.security_name === undefined || typeof lot.security_name === "string") &&
    typeof lot.acquisition_date === "string" &&
    typeof lot.quantity_millis === "number" &&
    typeof lot.remaining_quantity_millis === "number" &&
    typeof lot.cost_basis_minor === "number" &&
    typeof lot.currency === "string" &&
    ["specific_lot", "average_cost"].includes(lot.cost_method) &&
    (lot.notes === undefined || typeof lot.notes === "string")
  );
}

function isReportSnapshot(value: unknown): value is ReportSnapshot {
  if (!value || typeof value !== "object") {
    return false;
  }
  const snapshot = value as ReportSnapshot;
  return (
    typeof snapshot.savedAt === "string" &&
    (snapshot.trialBalance === undefined || isTrialBalanceReport(snapshot.trialBalance)) &&
    (snapshot.profitAndLoss === undefined || isProfitAndLossReport(snapshot.profitAndLoss)) &&
    (snapshot.balanceSheet === undefined || isBalanceSheetReport(snapshot.balanceSheet)) &&
    (snapshot.cashFlow === undefined || isCashFlowReport(snapshot.cashFlow)) &&
    (snapshot.arAging === undefined || isARAgingReport(snapshot.arAging)) &&
    (snapshot.apAging === undefined || isAPAgingReport(snapshot.apAging)) &&
    (snapshot.taxLiability === undefined || isTaxLiabilityReport(snapshot.taxLiability)) &&
    (snapshot.taxSummary === undefined || isTaxSummaryReport(snapshot.taxSummary)) &&
    (snapshot.budgetVsActual === undefined || isBudgetVsActualReport(snapshot.budgetVsActual)) &&
    (snapshot.realizedGains === undefined || isRealizedGainsReport(snapshot.realizedGains))
  );
}

function isTrialBalanceReport(value: unknown): value is TrialBalanceReport {
  if (!value || typeof value !== "object") {
    return false;
  }
  const report = value as TrialBalanceReport;
  return (
    typeof report.as_of_date === "string" &&
    Array.isArray(report.rows) &&
    report.rows.every(isReportRow) &&
    typeof report.total_debit_minor === "number" &&
    typeof report.total_credit_minor === "number" &&
    typeof report.balanced === "boolean"
  );
}

function isProfitAndLossReport(value: unknown): value is ProfitAndLossReport {
  if (!value || typeof value !== "object") {
    return false;
  }
  const report = value as ProfitAndLossReport;
  return (
    typeof report.from_date === "string" &&
    typeof report.to_date === "string" &&
    Array.isArray(report.income_rows) &&
    Array.isArray(report.expense_rows) &&
    report.income_rows.every(isReportRow) &&
    report.expense_rows.every(isReportRow) &&
    typeof report.total_income_minor === "number" &&
    typeof report.total_expense_minor === "number" &&
    typeof report.net_income_minor === "number"
  );
}

function isBalanceSheetReport(value: unknown): value is BalanceSheetReport {
  if (!value || typeof value !== "object") {
    return false;
  }
  const report = value as BalanceSheetReport;
  return (
    typeof report.as_of_date === "string" &&
    Array.isArray(report.asset_rows) &&
    Array.isArray(report.liability_rows) &&
    Array.isArray(report.equity_rows) &&
    report.asset_rows.every(isReportRow) &&
    report.liability_rows.every(isReportRow) &&
    report.equity_rows.every(isReportRow) &&
    typeof report.total_assets_minor === "number" &&
    typeof report.total_liabilities_minor === "number" &&
    typeof report.total_equity_minor === "number" &&
    typeof report.balanced === "boolean"
  );
}

function isCashFlowReport(value: unknown): value is CashFlowReport {
  if (!value || typeof value !== "object") {
    return false;
  }
  const report = value as CashFlowReport;
  return (
    typeof report.from_date === "string" &&
    typeof report.to_date === "string" &&
    Array.isArray(report.rows) &&
    report.rows.every(isCashFlowRow) &&
    typeof report.total_inflows_minor === "number" &&
    typeof report.total_outflows_minor === "number" &&
    typeof report.net_cash_flow_minor === "number" &&
    typeof report.opening_cash_minor === "number" &&
    typeof report.closing_cash_minor === "number" &&
    Array.isArray(report.generated_from_subtypes) &&
    report.generated_from_subtypes.every((subtype) => typeof subtype === "string")
  );
}

function isCashFlowRow(value: unknown): value is CashFlowRow {
  if (!value || typeof value !== "object") {
    return false;
  }
  const row = value as CashFlowRow;
  return (
    typeof row.account_id === "string" &&
    typeof row.account_code === "string" &&
    typeof row.account_name === "string" &&
    typeof row.source_module === "string" &&
    typeof row.inflow_minor === "number" &&
    typeof row.outflow_minor === "number" &&
    typeof row.net_cash_flow_minor === "number"
  );
}

function isARAgingReport(value: unknown): value is ARAgingReport {
  if (!value || typeof value !== "object") {
    return false;
  }
  const report = value as ARAgingReport;
  return (
    typeof report.as_of_date === "string" &&
    Array.isArray(report.rows) &&
    report.rows.every(isARAgingRow) &&
    typeof report.total_current_minor === "number" &&
    typeof report.total_one_to_thirty_minor === "number" &&
    typeof report.total_thirty_one_to_sixty_minor === "number" &&
    typeof report.total_sixty_one_to_ninety_minor === "number" &&
    typeof report.total_over_ninety_minor === "number" &&
    typeof report.total_outstanding_minor === "number"
  );
}

function isARAgingRow(value: unknown): value is ARAgingRow {
  if (!value || typeof value !== "object") {
    return false;
  }
  const row = value as ARAgingRow;
  return (
    typeof row.customer_id === "string" &&
    typeof row.customer_name === "string" &&
    typeof row.invoice_id === "string" &&
    typeof row.invoice_number === "string" &&
    typeof row.due_date === "string" &&
    typeof row.days_overdue === "number" &&
    typeof row.outstanding_minor === "number" &&
    typeof row.current_minor === "number" &&
    typeof row.one_to_thirty_minor === "number" &&
    typeof row.thirty_one_to_sixty_minor === "number" &&
    typeof row.sixty_one_to_ninety_minor === "number" &&
    typeof row.over_ninety_minor === "number"
  );
}

function isAPAgingReport(value: unknown): value is APAgingReport {
  if (!value || typeof value !== "object") {
    return false;
  }
  const report = value as APAgingReport;
  return (
    typeof report.as_of_date === "string" &&
    Array.isArray(report.rows) &&
    report.rows.every(isAPAgingRow) &&
    typeof report.total_current_minor === "number" &&
    typeof report.total_one_to_thirty_minor === "number" &&
    typeof report.total_thirty_one_to_sixty_minor === "number" &&
    typeof report.total_sixty_one_to_ninety_minor === "number" &&
    typeof report.total_over_ninety_minor === "number" &&
    typeof report.total_outstanding_minor === "number"
  );
}

function isAPAgingRow(value: unknown): value is APAgingRow {
  if (!value || typeof value !== "object") {
    return false;
  }
  const row = value as APAgingRow;
  return (
    typeof row.vendor_id === "string" &&
    typeof row.vendor_name === "string" &&
    typeof row.bill_id === "string" &&
    typeof row.bill_number === "string" &&
    typeof row.due_date === "string" &&
    typeof row.days_overdue === "number" &&
    typeof row.outstanding_minor === "number" &&
    typeof row.current_minor === "number" &&
    typeof row.one_to_thirty_minor === "number" &&
    typeof row.thirty_one_to_sixty_minor === "number" &&
    typeof row.sixty_one_to_ninety_minor === "number" &&
    typeof row.over_ninety_minor === "number"
  );
}

function isTaxLiabilityReport(value: unknown): value is TaxLiabilityReport {
  if (!value || typeof value !== "object") {
    return false;
  }
  const report = value as TaxLiabilityReport;
  return (
    typeof report.from_date === "string" &&
    typeof report.to_date === "string" &&
    typeof report.output_tax_minor === "number" &&
    typeof report.input_tax_minor === "number" &&
    typeof report.net_payable_minor === "number" &&
    Array.isArray(report.rows) &&
    report.rows.every(isTaxReportRow)
  );
}

function isTaxSummaryReport(value: unknown): value is TaxSummaryReport {
  if (!value || typeof value !== "object") {
    return false;
  }
  const report = value as TaxSummaryReport;
  return (
    typeof report.from_date === "string" &&
    typeof report.to_date === "string" &&
    Array.isArray(report.rows) &&
    report.rows.every(isTaxReportRow)
  );
}

function isReportRow(value: unknown): value is ReportRow {
  if (!value || typeof value !== "object") {
    return false;
  }
  const row = value as ReportRow;
  return (
    typeof row.account_id === "string" &&
    typeof row.account_code === "string" &&
    typeof row.account_name === "string" &&
    ["asset", "liability", "equity", "income", "expense"].includes(row.account_type) &&
    typeof row.debit_minor === "number" &&
    typeof row.credit_minor === "number" &&
    typeof row.balance_minor === "number"
  );
}

function isTaxReportRow(value: unknown): value is TaxReportRow {
  if (!value || typeof value !== "object") {
    return false;
  }
  const row = value as TaxReportRow;
  return (
    (row.tax_rate_id === undefined || typeof row.tax_rate_id === "string") &&
    (row.tax_group_id === undefined || typeof row.tax_group_id === "string") &&
    typeof row.name === "string" &&
    typeof row.output_tax_minor === "number" &&
    typeof row.input_tax_minor === "number" &&
    typeof row.net_payable_minor === "number"
  );
}

function isBudgetVsActualReport(value: unknown): value is BudgetVsActualReport {
  if (!value || typeof value !== "object") {
    return false;
  }
  const report = value as BudgetVsActualReport;
  return (
    typeof report.budget_id === "string" &&
    Array.isArray(report.rows) &&
    report.rows.every(isBudgetVsActualReportRow)
  );
}

function isBudgetVsActualReportRow(value: unknown): value is BudgetVsActualReportRow {
  if (!value || typeof value !== "object") {
    return false;
  }
  const row = value as BudgetVsActualReportRow;
  return (
    typeof row.account_id === "string" &&
    typeof row.account_code === "string" &&
    typeof row.account_name === "string" &&
    typeof row.period_start === "string" &&
    typeof row.period_end === "string" &&
    typeof row.budget_minor === "number" &&
    typeof row.actual_minor === "number" &&
    typeof row.variance_minor === "number" &&
    typeof row.variance_percent_basis === "number"
  );
}

function isRealizedGainsReport(value: unknown): value is RealizedGainsReport {
  if (!value || typeof value !== "object") {
    return false;
  }
  const report = value as RealizedGainsReport;
  return (
    typeof report.from_date === "string" &&
    typeof report.to_date === "string" &&
    Array.isArray(report.rows) &&
    report.rows.every(isInvestmentDisposition) &&
    typeof report.total_proceeds_minor === "number" &&
    typeof report.total_cost_basis_minor === "number" &&
    typeof report.total_gain_loss_minor === "number"
  );
}

function isInvestmentDisposition(value: unknown): value is InvestmentDisposition {
  if (!value || typeof value !== "object") {
    return false;
  }
  const disposition = value as InvestmentDisposition;
  return (
    typeof disposition.id === "string" &&
    typeof disposition.organization_id === "string" &&
    typeof disposition.investment_lot_id === "string" &&
    typeof disposition.sale_date === "string" &&
    typeof disposition.quantity_millis === "number" &&
    typeof disposition.proceeds_minor === "number" &&
    typeof disposition.allocated_cost_basis_minor === "number" &&
    typeof disposition.realized_gain_loss_minor === "number" &&
    typeof disposition.currency === "string" &&
    (disposition.notes === undefined || typeof disposition.notes === "string")
  );
}
