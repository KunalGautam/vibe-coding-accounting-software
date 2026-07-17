import { FormEvent, type ReactNode, useEffect, useMemo, useState } from "react";
import { ApiClient, type Account, type AccountDrilldownReport, type AccountInput, type ApiConfig, type APAgingReport, type ARAgingReport, type Attachment, type AuditLog, type BalanceSheetReport, type BankStatementLine, type Bill, type BillLine, type BootstrapFirstAdminInput, type Budget, type BudgetVsActualReport, type BudgetVsActualReportRow, type CashFlowReport, type ChangePasswordInput, type CloseFiscalYearInput, type CreateAttachmentInput, type CreateBillInput, type CreateBudgetInput, type CreateCreditNoteInput, type CreateEstimateInput, type CreateExchangeRateInput, type CreateExpenseInput, type CreateInvestmentCorporateActionInput, type CreateInvestmentDividendInput, type CreateInvestmentLotInput, type CreateInvoiceInput, type CreateOrganizationInput, type CreateOrganizationUserInput, type CreatePayrollComponentInput, type CreatePayrollRunInput, type CreatePurchaseOrderInput, type CreateRecurringInvoiceTemplateInput, type CreateScheduledReportInput, type CreateTaxAuthorityInput, type CreateTaxGroupInput, type CreateTaxRateInput, type CreditNote, type CurrentUserProfile, type Customer, type CustomerInput, type CustomerPayment, type Employee, type EmployeeInput, type Estimate, type EstimateLine, type ExchangeRate, type Expense, type FiscalClose, type ImportAMFINAVInput, type ImportBankStatementInput, type ImportInvestmentPricesInput, type InvestmentPriceImportResult, type IndiaPayrollPreview, type IndiaProfessionalTaxPreset, type IndiaSeedResult, type InvestmentCorporateAction, type InvestmentCorporateActionReport, type InvestmentDividend, type InvestmentDividendReport, type InvestmentLot, type InvestmentTaxAdjustmentReport, type InvestmentTaxLotReport, type Invoice, type InvoiceLine, type JournalTransaction, type JournalTransactionInput, type LedgerSplit, type LoginInput, type MFASetupResponse, type Organization, type OrganizationUser, type PayrollRun, type PayrollSummaryReport, type PayslipPreview, type PostRevaluationInput, type ProfitAndLossReport, type PurchaseOrder, type PurchaseOrderLine, type RealizedGainsReport, type RecordPaymentInput, type RecurringInvoiceTemplate, type RegisterOrganizationInput, type ReportRow, type RevaluationPreview, type Role, type ScheduledReport, type ScheduledReportRun, type SellInvestmentLotInput, type TaxAuthority, type TaxCalculation, type TaxGroup, type TaxLiabilityReport, type TaxRate, type TaxReportRow, type TaxSummaryReport, type TrialBalanceReport, type UpdateOrganizationUserInput, type Vendor, type VendorInput, type VendorPayment } from "./api/client";
import { clearReportSnapshot, loadAccountDrafts, loadAccountingSnapshot, loadConfig, loadJournalDrafts, loadReportSnapshot, saveAccountDrafts, saveAccountingSnapshot, saveConfig, saveJournalDrafts, saveReportSnapshot, type QueuedAccountDraft, type QueuedJournalDraft, type ReportSnapshot } from "./api/storage";
import { connectionReadinessChecks, extractPasswordResetToken, generateTemporaryPassword, organizationUserOnboardingChecks, passwordChangeChecks, passwordStrengthChecks, roleDescription, safeFilenamePart } from "./accountSecurity";
import { investmentPriceImportFormats, investmentPriceImportMetadata, nextInvestmentPriceImportSource, type InvestmentPriceImportFormat } from "./investmentImports";
import { importNotice, mapCsvStatementLines, summarizeReconciliation, suggestReconciliationMatches } from "./reconciliation";

type View = "dashboard" | "accounts" | "ledger" | "tax" | "reports" | "budgets" | "investments" | "payroll" | "invoices" | "expenses" | "documents" | "reconciliation" | "admin";

type FocusTarget = {
  view: View;
  documentType: string;
  documentId: string;
  documentNumber?: string;
  journalTransactionId?: string;
};

export function App() {
  const cachedSnapshot = useMemo(() => loadAccountingSnapshot(), []);
  const [config, setConfig] = useState<ApiConfig>(() => loadConfig());
  const [view, setView] = useState<View>("dashboard");
  const [focusTarget, setFocusTarget] = useState<FocusTarget | null>(null);
  const [accounts, setAccounts] = useState<Account[]>(() => cachedSnapshot?.accounts ?? []);
  const [transactions, setTransactions] = useState<JournalTransaction[]>(() => cachedSnapshot?.transactions ?? []);
  const [accountRegisterAccountId, setAccountRegisterAccountId] = useState(() => cachedSnapshot?.accountRegisterAccountId ?? "");
  const [accountRegisterSplits, setAccountRegisterSplits] = useState<LedgerSplit[]>(() => cachedSnapshot?.accountRegisterSplits ?? []);
  const [taxAuthorities, setTaxAuthorities] = useState<TaxAuthority[]>(() => cachedSnapshot?.taxAuthorities ?? []);
  const [taxRates, setTaxRates] = useState<TaxRate[]>(() => cachedSnapshot?.taxRates ?? []);
  const [taxGroups, setTaxGroups] = useState<TaxGroup[]>(() => cachedSnapshot?.taxGroups ?? []);
  const [payrollRuns, setPayrollRuns] = useState<PayrollRun[]>(() => cachedSnapshot?.payrollRuns ?? []);
  const [employees, setEmployees] = useState<Employee[]>(() => cachedSnapshot?.employees ?? []);
  const [lastPayslipPreview, setLastPayslipPreview] = useState<PayslipPreview | null>(() => cachedSnapshot?.lastPayslipPreview ?? null);
  const [customers, setCustomers] = useState<Customer[]>(() => cachedSnapshot?.customers ?? []);
  const [invoices, setInvoices] = useState<Invoice[]>(() => cachedSnapshot?.invoices ?? []);
  const [recurringInvoices, setRecurringInvoices] = useState<RecurringInvoiceTemplate[]>(() => cachedSnapshot?.recurringInvoices ?? []);
  const [estimates, setEstimates] = useState<Estimate[]>(() => cachedSnapshot?.estimates ?? []);
  const [creditNotes, setCreditNotes] = useState<CreditNote[]>(() => cachedSnapshot?.creditNotes ?? []);
  const [vendors, setVendors] = useState<Vendor[]>(() => cachedSnapshot?.vendors ?? []);
  const [expenses, setExpenses] = useState<Expense[]>(() => cachedSnapshot?.expenses ?? []);
  const [bills, setBills] = useState<Bill[]>(() => cachedSnapshot?.bills ?? []);
  const [purchaseOrders, setPurchaseOrders] = useState<PurchaseOrder[]>(() => cachedSnapshot?.purchaseOrders ?? []);
  const [bankStatementLines, setBankStatementLines] = useState<BankStatementLine[]>(() => cachedSnapshot?.bankStatementLines ?? []);
  const [exchangeRates, setExchangeRates] = useState<ExchangeRate[]>(() => cachedSnapshot?.exchangeRates ?? []);
  const [fiscalCloses, setFiscalCloses] = useState<FiscalClose[]>(() => cachedSnapshot?.fiscalCloses ?? []);
  const [auditLogs, setAuditLogs] = useState<AuditLog[]>(() => cachedSnapshot?.auditLogs ?? []);
  const [organizationUsers, setOrganizationUsers] = useState<OrganizationUser[]>(() => cachedSnapshot?.organizationUsers ?? []);
  const [attachments, setAttachments] = useState<Attachment[]>(() => cachedSnapshot?.attachments ?? []);
  const [budgets, setBudgets] = useState<Budget[]>(() => cachedSnapshot?.budgets ?? []);
  const [investmentLots, setInvestmentLots] = useState<InvestmentLot[]>(() => cachedSnapshot?.investmentLots ?? []);
  const [investmentDividends, setInvestmentDividends] = useState<InvestmentDividend[]>(() => cachedSnapshot?.investmentDividends ?? []);
  const [investmentCorporateActions, setInvestmentCorporateActions] = useState<InvestmentCorporateAction[]>(() => cachedSnapshot?.investmentCorporateActions ?? []);
  const [queuedAccountDrafts, setQueuedAccountDrafts] = useState<QueuedAccountDraft[]>(() => loadAccountDrafts());
  const [queuedJournalDrafts, setQueuedJournalDrafts] = useState<QueuedJournalDraft[]>(() => loadJournalDrafts());
  const [error, setError] = useState("");
  const [notice, setNotice] = useState(cachedSnapshot ? `Loaded cached accounting snapshot from ${new Date(cachedSnapshot.savedAt).toLocaleString()}.` : "");

  const api = useMemo(() => new ApiClient(config), [config]);

  function openFocusedDocument(target: FocusTarget) {
    setFocusTarget(target);
    setView(target.view);
  }

  async function refresh() {
    if (!config.accessToken || !config.organizationId) {
      return;
    }
    setError("");
    try {
      const [nextAccounts, nextTransactions, nextTaxAuthorities, nextTaxRates, nextTaxGroups, nextPayrollRuns, nextEmployees, nextCustomers, nextInvoices, nextRecurringInvoices, nextEstimates, nextCreditNotes, nextVendors, nextExpenses, nextBills, nextPurchaseOrders, nextExchangeRates, nextFiscalCloses, nextAuditLogs, nextOrganizationUsers, nextAttachments, nextBudgets, nextInvestmentLots, nextInvestmentDividends, nextInvestmentCorporateActions] = await Promise.all([
        api.listAccounts(),
        api.listJournalTransactions(),
        api.listTaxAuthorities(),
        api.listTaxRates(),
        api.listTaxGroups(),
        api.listPayrollRuns(),
        api.listEmployees(),
        api.listCustomers(),
        api.listInvoices(),
        api.listRecurringInvoices(),
        api.listEstimates(),
        api.listCreditNotes(),
        api.listVendors(),
        api.listExpenses(),
        api.listBills(),
        api.listPurchaseOrders(),
        api.listExchangeRates(),
        api.listFiscalCloses(),
        api.listAuditLogs(),
        api.listOrganizationUsers(),
        api.listAttachments(),
        api.listBudgets(),
        api.listInvestmentLots(),
        api.listInvestmentDividends(),
        api.listInvestmentCorporateActions()
      ]);
      setAccounts(nextAccounts);
      setTransactions(nextTransactions);
      setTaxAuthorities(nextTaxAuthorities);
      setTaxRates(nextTaxRates);
      setTaxGroups(nextTaxGroups);
      setPayrollRuns(nextPayrollRuns);
      setEmployees(nextEmployees);
      setCustomers(nextCustomers);
      setInvoices(nextInvoices);
      setRecurringInvoices(nextRecurringInvoices);
      setEstimates(nextEstimates);
      setCreditNotes(nextCreditNotes);
      setVendors(nextVendors);
      setExpenses(nextExpenses);
      setBills(nextBills);
      setPurchaseOrders(nextPurchaseOrders);
      setExchangeRates(nextExchangeRates);
      setFiscalCloses(nextFiscalCloses);
      setAuditLogs(nextAuditLogs);
      setOrganizationUsers(nextOrganizationUsers);
      setAttachments(nextAttachments);
      setBudgets(nextBudgets);
      setInvestmentLots(nextInvestmentLots);
      setInvestmentDividends(nextInvestmentDividends);
      setInvestmentCorporateActions(nextInvestmentCorporateActions);
      saveAccountingSnapshot({
        savedAt: new Date().toISOString(),
        accounts: nextAccounts,
        transactions: nextTransactions,
        accountRegisterAccountId,
        accountRegisterSplits,
        taxAuthorities: nextTaxAuthorities,
        taxRates: nextTaxRates,
        taxGroups: nextTaxGroups,
        payrollRuns: nextPayrollRuns,
        employees: nextEmployees,
        lastPayslipPreview: lastPayslipPreview ?? undefined,
        customers: nextCustomers,
        invoices: nextInvoices,
        recurringInvoices: nextRecurringInvoices,
        estimates: nextEstimates,
        creditNotes: nextCreditNotes,
        vendors: nextVendors,
        expenses: nextExpenses,
        bills: nextBills,
        purchaseOrders: nextPurchaseOrders,
        bankStatementLines,
        exchangeRates: nextExchangeRates,
        fiscalCloses: nextFiscalCloses,
        auditLogs: nextAuditLogs,
        organizationUsers: nextOrganizationUsers,
        attachments: nextAttachments,
        budgets: nextBudgets,
        investmentLots: nextInvestmentLots,
        investmentDividends: nextInvestmentDividends,
        investmentCorporateActions: nextInvestmentCorporateActions
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : "Refresh failed");
    }
  }

  useEffect(() => {
    void refresh();
  }, [config.accessToken, config.organizationId]);

  function updateConfig(next: ApiConfig) {
    setConfig(next);
    saveConfig(next);
    setNotice("Connection settings saved locally.");
  }

  function queueAccountDraft(input: AccountInput) {
    const draft = {
      id: createDraftId("account-draft"),
      createdAt: new Date().toISOString(),
      input
    };
    const next = [draft, ...queuedAccountDrafts];
    setQueuedAccountDrafts(next);
    saveAccountDrafts(next);
    setNotice("Account draft queued locally for offline sync.");
  }

  function deleteQueuedAccountDraft(draftId: string) {
    const next = queuedAccountDrafts.filter((draft) => draft.id !== draftId);
    setQueuedAccountDrafts(next);
    saveAccountDrafts(next);
    setNotice("Queued account draft removed locally.");
  }

  function updateQueuedAccountDraft(draftId: string, input: AccountInput) {
    const next = queuedAccountDrafts.map((draft) => (
      draft.id === draftId ? { ...draft, input, lastError: undefined } : draft
    ));
    persistAccountDrafts(next);
    setNotice("Queued account draft updated locally.");
  }

  function clearQueuedAccountDraftError(draftId: string) {
    const next = queuedAccountDrafts.map((draft) => (
      draft.id === draftId ? { ...draft, lastError: undefined } : draft
    ));
    persistAccountDrafts(next);
    setNotice("Queued account draft error cleared locally.");
  }

  function clearQueuedAccountDrafts() {
    setQueuedAccountDrafts([]);
    saveAccountDrafts([]);
    setNotice("All queued account drafts cleared locally.");
  }

  async function syncQueuedAccountDrafts() {
    if (!config.accessToken || !config.organizationId) {
      setNotice("Add API credentials and organization ID before syncing queued account drafts.");
      return;
    }

    setError("");
    const result = await syncDraftQueue(queuedAccountDrafts, (draft) => api.createAccount(draft.input));
    persistAccountDrafts(result.remaining);
    setNotice(`Synced ${result.synced} queued account drafts; ${result.failed} failed and remain queued.`);
    if (result.synced > 0) {
      await refresh();
    }
  }

  function queueJournalDraft(input: JournalTransactionInput) {
    const draft = {
      id: createDraftId("journal-draft"),
      createdAt: new Date().toISOString(),
      input
    };
    const next = [draft, ...queuedJournalDrafts];
    setQueuedJournalDrafts(next);
    saveJournalDrafts(next);
    setNotice("Journal draft queued locally for offline sync.");
  }

  function deleteQueuedJournalDraft(draftId: string) {
    const next = queuedJournalDrafts.filter((draft) => draft.id !== draftId);
    setQueuedJournalDrafts(next);
    saveJournalDrafts(next);
    setNotice("Queued journal draft removed locally.");
  }

  function updateQueuedJournalDraft(draftId: string, input: JournalTransactionInput) {
    const next = queuedJournalDrafts.map((draft) => (
      draft.id === draftId ? { ...draft, input, lastError: undefined } : draft
    ));
    persistJournalDrafts(next);
    setNotice("Queued journal draft updated locally.");
  }

  function clearQueuedJournalDraftError(draftId: string) {
    const next = queuedJournalDrafts.map((draft) => (
      draft.id === draftId ? { ...draft, lastError: undefined } : draft
    ));
    persistJournalDrafts(next);
    setNotice("Queued journal draft error cleared locally.");
  }

  function clearQueuedJournalDrafts() {
    setQueuedJournalDrafts([]);
    saveJournalDrafts([]);
    setNotice("All queued journal drafts cleared locally.");
  }

  async function syncQueuedJournalDrafts() {
    if (!config.accessToken || !config.organizationId) {
      setNotice("Add API credentials and organization ID before syncing queued journal drafts.");
      return;
    }

    setError("");
    const result = await syncDraftQueue(queuedJournalDrafts, (draft) => api.postJournalTransaction(draft.input));
    persistJournalDrafts(result.remaining);
    setNotice(`Synced ${result.synced} queued journal drafts; ${result.failed} failed and remain queued.`);
    if (result.synced > 0) {
      await refresh();
    }
  }

  async function syncAllQueuedDrafts() {
    if (!config.accessToken || !config.organizationId) {
      setNotice("Add API credentials and organization ID before syncing queued work.");
      return;
    }

    setError("");
    const accountResult = await syncDraftQueue(queuedAccountDrafts, (draft) => api.createAccount(draft.input));
    const journalResult = await syncDraftQueue(queuedJournalDrafts, (draft) => api.postJournalTransaction(draft.input));
    persistAccountDrafts(accountResult.remaining);
    persistJournalDrafts(journalResult.remaining);
    setNotice(
      `Synced ${accountResult.synced} account drafts and ${journalResult.synced} journal drafts; `
      + `${accountResult.failed + journalResult.failed} failed and remain queued.`
    );
    if (accountResult.synced + journalResult.synced > 0) {
      await refresh();
    }
  }

  function persistAccountDrafts(drafts: QueuedAccountDraft[]) {
    setQueuedAccountDrafts(drafts);
    saveAccountDrafts(drafts);
  }

  function persistJournalDrafts(drafts: QueuedJournalDraft[]) {
    setQueuedJournalDrafts(drafts);
    saveJournalDrafts(drafts);
  }

  function updateBankStatementLines(next: BankStatementLine[]) {
    setBankStatementLines(next);
    saveAccountingSnapshot({
      savedAt: new Date().toISOString(),
      accounts,
      transactions,
      taxRates,
      taxGroups,
      payrollRuns,
      employees,
      lastPayslipPreview: lastPayslipPreview ?? undefined,
      customers,
      invoices,
      vendors,
      expenses,
      bankStatementLines: next,
      exchangeRates,
      fiscalCloses,
      auditLogs,
      organizationUsers,
      attachments,
      budgets,
      investmentLots,
      investmentDividends,
      investmentCorporateActions
    });
  }

  function updatePayslipPreview(preview: PayslipPreview | null) {
    setLastPayslipPreview(preview);
    saveAccountingSnapshot({
      savedAt: new Date().toISOString(),
      accounts,
      transactions,
      accountRegisterAccountId,
      accountRegisterSplits,
      taxAuthorities,
      taxRates,
      taxGroups,
      payrollRuns,
      employees,
      lastPayslipPreview: preview ?? undefined,
      customers,
      invoices,
      recurringInvoices,
      estimates,
      creditNotes,
      vendors,
      expenses,
      bills,
      purchaseOrders,
      bankStatementLines,
      exchangeRates,
      fiscalCloses,
      auditLogs,
      organizationUsers,
      attachments,
      budgets,
      investmentLots,
      investmentDividends,
      investmentCorporateActions
    });
  }

  function updateAccountRegister(accountId: string, splits: LedgerSplit[]) {
    setAccountRegisterAccountId(accountId);
    setAccountRegisterSplits(splits);
    saveAccountingSnapshot({
      savedAt: new Date().toISOString(),
      accounts,
      transactions,
      accountRegisterAccountId: accountId,
      accountRegisterSplits: splits,
      taxAuthorities,
      taxRates,
      taxGroups,
      payrollRuns,
      employees,
      lastPayslipPreview: lastPayslipPreview ?? undefined,
      customers,
      invoices,
      vendors,
      expenses,
      bankStatementLines,
      exchangeRates,
      fiscalCloses,
      auditLogs,
      organizationUsers,
      attachments,
      budgets,
      investmentLots,
      investmentDividends,
      investmentCorporateActions
    });
  }

  return (
    <main className="app-shell">
      <aside className="sidebar">
        <div>
          <p className="eyebrow">Ledger Works</p>
          <h1>Accounting cockpit</h1>
        </div>
        <nav>
          <button className={view === "dashboard" ? "active" : ""} onClick={() => setView("dashboard")}>Dashboard</button>
          <button className={view === "accounts" ? "active" : ""} onClick={() => setView("accounts")}>Accounts</button>
          <button className={view === "ledger" ? "active" : ""} onClick={() => setView("ledger")}>Ledger</button>
          <button className={view === "tax" ? "active" : ""} onClick={() => setView("tax")}>Tax</button>
          <button className={view === "reports" ? "active" : ""} onClick={() => setView("reports")}>Reports</button>
          <button className={view === "budgets" ? "active" : ""} onClick={() => setView("budgets")}>Budgets</button>
          <button className={view === "investments" ? "active" : ""} onClick={() => setView("investments")}>Investments</button>
          <button className={view === "payroll" ? "active" : ""} onClick={() => setView("payroll")}>Payroll</button>
          <button className={view === "invoices" ? "active" : ""} onClick={() => setView("invoices")}>Invoices</button>
          <button className={view === "expenses" ? "active" : ""} onClick={() => setView("expenses")}>Expenses</button>
          <button className={view === "documents" ? "active" : ""} onClick={() => setView("documents")}>Documents</button>
          <button className={view === "reconciliation" ? "active" : ""} onClick={() => setView("reconciliation")}>Reconcile</button>
          <button className={view === "admin" ? "active" : ""} onClick={() => setView("admin")}>Admin</button>
        </nav>
        <ConnectionPanel config={config} onSave={updateConfig} />
      </aside>

      <section className="workspace">
        <header className="topbar">
          <div>
            <p className="eyebrow">India-first SMB accounting</p>
            <h2>{titleFor(view)}</h2>
          </div>
          <button className="secondary" onClick={() => void refresh()}>Refresh</button>
        </header>

        {error && <div className="alert error">{error}</div>}
        {notice && <div className="alert success">{notice}</div>}

        {view === "dashboard" && (
          <Dashboard
            accounts={accounts}
            transactions={transactions}
            taxRates={taxRates.length}
            taxGroups={taxGroups.length}
            queuedAccountDrafts={queuedAccountDrafts.length}
            queuedJournalDrafts={queuedJournalDrafts.length}
            hasConnection={Boolean(config.accessToken && config.organizationId)}
            onOpenAccounts={() => setView("accounts")}
            onOpenLedger={() => setView("ledger")}
            onSyncAllQueuedDrafts={syncAllQueuedDrafts}
          />
        )}
        {view === "accounts" && (
          <AccountsPage
            accounts={accounts}
            queuedAccountDrafts={queuedAccountDrafts}
            api={api}
            onChanged={refresh}
            onQueueDraft={queueAccountDraft}
            onUpdateQueuedDraft={updateQueuedAccountDraft}
            onDeleteQueuedDraft={deleteQueuedAccountDraft}
            onClearQueuedDraftError={clearQueuedAccountDraftError}
            onClearQueuedDrafts={clearQueuedAccountDrafts}
            onSyncQueuedDrafts={syncQueuedAccountDrafts}
          />
        )}
        {view === "ledger" && (
          <LedgerPage
            accounts={accounts}
            transactions={transactions}
            accountRegisterAccountId={accountRegisterAccountId}
            accountRegisterSplits={accountRegisterSplits}
            queuedJournalDrafts={queuedJournalDrafts}
            focusTarget={focusTarget?.view === "ledger" ? focusTarget : null}
            api={api}
            onChanged={refresh}
            onAccountRegisterChanged={updateAccountRegister}
            onQueueDraft={queueJournalDraft}
            onUpdateQueuedDraft={updateQueuedJournalDraft}
            onDeleteQueuedDraft={deleteQueuedJournalDraft}
            onClearQueuedDraftError={clearQueuedJournalDraftError}
            onClearQueuedDrafts={clearQueuedJournalDrafts}
            onSyncQueuedDrafts={syncQueuedJournalDrafts}
          />
        )}
        {view === "tax" && (
          <TaxPage
            api={api}
            accounts={accounts}
            taxAuthorities={taxAuthorities}
            taxRates={taxRates}
            taxGroups={taxGroups}
            onTaxAuthoritiesChanged={setTaxAuthorities}
            onTaxRatesChanged={setTaxRates}
            onTaxGroupsChanged={setTaxGroups}
            onRefresh={refresh}
          />
        )}
        {view === "reports" && (
          <ReportsPage api={api} budgets={budgets} onBudgetsChanged={setBudgets} onOpenSourceDocument={openFocusedDocument} />
        )}
        {view === "budgets" && (
          <BudgetsPage
            api={api}
            accounts={accounts}
            budgets={budgets}
            onBudgetsChanged={setBudgets}
            onRefresh={refresh}
          />
        )}
        {view === "investments" && (
          <InvestmentsPage
            api={api}
            accounts={accounts}
            investmentLots={investmentLots}
            onInvestmentLotsChanged={setInvestmentLots}
            investmentDividends={investmentDividends}
            onInvestmentDividendsChanged={setInvestmentDividends}
            investmentCorporateActions={investmentCorporateActions}
            onInvestmentCorporateActionsChanged={setInvestmentCorporateActions}
            onRefresh={refresh}
          />
        )}
        {view === "payroll" && (
          <PayrollPage
            api={api}
            accounts={accounts}
            payrollRuns={payrollRuns}
            employees={employees}
            payslipPreview={lastPayslipPreview}
            focusTarget={focusTarget?.view === "payroll" ? focusTarget : null}
            onPayrollRunsChanged={setPayrollRuns}
            onEmployeesChanged={setEmployees}
            onPayslipPreviewChanged={updatePayslipPreview}
            onRefresh={refresh}
          />
        )}
        {view === "invoices" && (
          <InvoicesPage
            api={api}
            accounts={accounts}
            customers={customers}
            invoices={invoices}
            recurringInvoices={recurringInvoices}
            estimates={estimates}
            creditNotes={creditNotes}
            taxRates={taxRates}
            taxGroups={taxGroups}
            focusTarget={focusTarget?.view === "invoices" ? focusTarget : null}
            onCustomersChanged={setCustomers}
            onInvoicesChanged={setInvoices}
            onRecurringInvoicesChanged={setRecurringInvoices}
            onEstimatesChanged={setEstimates}
            onCreditNotesChanged={setCreditNotes}
            onRefresh={refresh}
          />
        )}
        {view === "expenses" && (
          <ExpensesPage
            api={api}
            accounts={accounts}
            vendors={vendors}
            expenses={expenses}
            bills={bills}
            purchaseOrders={purchaseOrders}
            taxRates={taxRates}
            taxGroups={taxGroups}
            focusTarget={focusTarget?.view === "expenses" ? focusTarget : null}
            onVendorsChanged={setVendors}
            onExpensesChanged={setExpenses}
            onBillsChanged={setBills}
            onPurchaseOrdersChanged={setPurchaseOrders}
            onRefresh={refresh}
          />
        )}
        {view === "documents" && (
          <DocumentsPage
            api={api}
            attachments={attachments}
            onAttachmentsChanged={setAttachments}
            onRefresh={refresh}
          />
        )}
        {view === "reconciliation" && (
          <ReconciliationPage
            api={api}
            accounts={accounts}
            transactions={transactions}
            statementLines={bankStatementLines}
            onStatementLinesChanged={updateBankStatementLines}
            onRefresh={refresh}
          />
        )}
        {view === "admin" && (
          <AdminPage
            api={api}
            accounts={accounts}
            exchangeRates={exchangeRates}
            fiscalCloses={fiscalCloses}
            auditLogs={auditLogs}
            organizationUsers={organizationUsers}
            onExchangeRatesChanged={setExchangeRates}
            onFiscalClosesChanged={setFiscalCloses}
            onAuditLogsChanged={setAuditLogs}
            onOrganizationUsersChanged={setOrganizationUsers}
            onRefresh={refresh}
          />
        )}
      </section>
    </main>
  );
}

function ConnectionPanel({ config, onSave }: { config: ApiConfig; onSave: (config: ApiConfig) => void }) {
  const [draft, setDraft] = useState(config);
  const [loginForm, setLoginForm] = useState<LoginInput>({ email: "", password: "", mfa_code: "" });
  const [passwordResetEmail, setPasswordResetEmail] = useState("");
  const [passwordResetToken, setPasswordResetToken] = useState("");
  const [passwordResetNewPassword, setPasswordResetNewPassword] = useState("");
  const [passwordResetTokenExpiresAt, setPasswordResetTokenExpiresAt] = useState("");
  const [mfaSetup, setMfaSetup] = useState<MFASetupResponse | null>(null);
  const [mfaCode, setMfaCode] = useState("");
  const [mfaRecoveryCodes, setMfaRecoveryCodes] = useState<string[]>([]);
  const [currentUserProfile, setCurrentUserProfile] = useState<CurrentUserProfile | null>(null);
  const [profileName, setProfileName] = useState("");
  const [changePasswordForm, setChangePasswordForm] = useState<ChangePasswordInput>({
    current_password: "",
    new_password: ""
  });
  const [bootstrapForm, setBootstrapForm] = useState<BootstrapFirstAdminInput>({
    organization_name: "",
    admin_name: "",
    admin_email: "",
    admin_password: "",
    base_currency: "INR",
    country_code: "IN",
    seed_india_defaults: true
  });
  const [registrationForm, setRegistrationForm] = useState<RegisterOrganizationInput>({
    organization_name: "",
    admin_name: "",
    admin_email: "",
    admin_password: "",
    base_currency: "INR",
    country_code: "IN",
    seed_india_defaults: true
  });
  const [organizationForm, setOrganizationForm] = useState<CreateOrganizationInput>({ name: "", base_currency: "INR", country_code: "IN" });
  const [organizations, setOrganizations] = useState<Organization[]>([]);
  const [loading, setLoading] = useState("");
  const [connectionError, setConnectionError] = useState("");
  const [connectionNotice, setConnectionNotice] = useState("");
  const connectionApi = useMemo(() => new ApiClient(draft), [draft]);
  const passwordResetChecks = passwordStrengthChecks(passwordResetNewPassword);
  const connectionChecks = connectionReadinessChecks(draft);
  const passwordReady = passwordResetChecks.every((check) => check.ok);
  const changePasswordChecks = passwordChangeChecks(changePasswordForm.current_password, changePasswordForm.new_password);
  const canChangePassword = changePasswordChecks.every((check) => check.ok);

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }
    const resetToken = extractPasswordResetToken(window.location.href);
    if (!resetToken || passwordResetToken) {
      return;
    }
    setPasswordResetToken(resetToken);
    setConnectionNotice("Detected a password reset token from the current URL. Review it, enter a new password, then confirm the reset.");
  }, [passwordResetToken]);

  function submit(event: FormEvent) {
    event.preventDefault();
    onSave(draft);
  }

  async function login(event: FormEvent) {
    event.preventDefault();
    setLoading("login");
    setConnectionError("");
    try {
      const token = await connectionApi.login(loginForm);
      const next = { ...draft, accessToken: token.access_token, refreshToken: token.refresh_token };
      setDraft(next);
      onSave(next);
      setConnectionNotice(`Logged in. Access token expires in ${token.expires_in} seconds.`);
      await loadOrganizations(next);
    } catch (error) {
      setConnectionError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function refreshAccessToken() {
    if (!draft.refreshToken) {
      setConnectionError("No refresh token is saved yet.");
      return;
    }
    setLoading("refresh-token");
    setConnectionError("");
    try {
      const token = await connectionApi.refreshToken(draft.refreshToken);
      const next = { ...draft, accessToken: token.access_token, refreshToken: token.refresh_token };
      setDraft(next);
      onSave(next);
      setConnectionNotice(`Token refreshed. Access token expires in ${token.expires_in} seconds.`);
    } catch (error) {
      setConnectionError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function logoutCurrentSession() {
    if (!draft.refreshToken) {
      setConnectionError("No refresh token is saved yet.");
      return;
    }
    setLoading("logout");
    setConnectionError("");
    try {
      await connectionApi.logout(draft.refreshToken);
      const next = { ...draft, accessToken: "", refreshToken: "" };
      setDraft(next);
      onSave(next);
      setConnectionNotice("Current refresh token revoked and local tokens cleared.");
    } catch (error) {
      setConnectionError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function revokeAllSessions() {
    if (!draft.accessToken) {
      setConnectionError("An access token is required to revoke all sessions.");
      return;
    }
    setLoading("revoke-sessions");
    setConnectionError("");
    try {
      const result = await connectionApi.revokeAllSessions();
      const next = { ...draft, accessToken: "", refreshToken: "" };
      setDraft(next);
      onSave(next);
      setConnectionNotice(`Revoked ${result.revoked_count} session(s) and cleared local tokens.`);
    } catch (error) {
      setConnectionError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function loadCurrentUserProfile() {
    if (!draft.accessToken) {
      setConnectionError("An access token is required to load account settings.");
      return;
    }
    setLoading("current-user");
    setConnectionError("");
    try {
      const profile = await connectionApi.currentUser();
      setCurrentUserProfile(profile);
      setProfileName(profile.name);
      setConnectionNotice(`Loaded account settings for ${profile.email}.`);
    } catch (error) {
      setConnectionError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function updateCurrentUserProfile(event: FormEvent) {
    event.preventDefault();
    if (!profileName.trim()) {
      return;
    }
    setLoading("update-current-user");
    setConnectionError("");
    try {
      const profile = await connectionApi.updateCurrentUser({ name: profileName.trim() });
      setCurrentUserProfile(profile);
      setProfileName(profile.name);
      setConnectionNotice("Account profile updated.");
    } catch (error) {
      setConnectionError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function changeCurrentPassword(event: FormEvent) {
    event.preventDefault();
    if (!canChangePassword) {
      return;
    }
    setLoading("change-password");
    setConnectionError("");
    try {
      await connectionApi.changePassword(changePasswordForm);
      const next = { ...draft, refreshToken: "" };
      setDraft(next);
      onSave(next);
      setChangePasswordForm({ current_password: "", new_password: "" });
      setConnectionNotice("Password changed and existing refresh-token sessions were revoked. Log in again before refreshing tokens.");
    } catch (error) {
      setConnectionError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function requestPasswordReset(event: FormEvent) {
    event.preventDefault();
    setLoading("request-password-reset");
    setConnectionError("");
    try {
      const result = await connectionApi.requestPasswordReset({ email: passwordResetEmail });
      if (result.reset_token) {
        setPasswordResetToken(result.reset_token);
        setPasswordResetTokenExpiresAt(result.reset_token_expires_at ?? "");
        setConnectionNotice("Password reset requested. A reset token was returned because token exposure is enabled for this environment.");
      } else {
        setPasswordResetTokenExpiresAt("");
        setConnectionNotice(result.email_sent
          ? "Password reset email sent. Use the emailed link or token to set a new password."
          : "If that email exists, a reset flow was started. Check SMTP configuration if no email arrives.");
      }
    } catch (error) {
      setConnectionError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function confirmPasswordReset(event: FormEvent) {
    event.preventDefault();
    setLoading("confirm-password-reset");
    setConnectionError("");
    try {
      await connectionApi.confirmPasswordReset({
        reset_token: passwordResetToken,
        new_password: passwordResetNewPassword
      });
      setPasswordResetToken("");
      setPasswordResetNewPassword("");
      setPasswordResetTokenExpiresAt("");
      setConnectionNotice("Password reset complete. Log in with the new password.");
    } catch (error) {
      setConnectionError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function setupMFA() {
    setLoading("mfa-setup");
    setConnectionError("");
    try {
      const result = await connectionApi.setupMFA();
      setMfaSetup(result);
      setMfaRecoveryCodes([]);
      setConnectionNotice("MFA secret generated. Add it to an authenticator app, then verify a code to enable MFA.");
    } catch (error) {
      setConnectionError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function enableMFA() {
    setLoading("mfa-enable");
    setConnectionError("");
    try {
      const result = await connectionApi.enableMFA(mfaCode);
      setMfaRecoveryCodes(result.recovery_codes ?? []);
      setConnectionNotice("MFA enabled. Save the recovery codes now; they will not be shown again.");
      setMfaSetup((current) => current ? { ...current, mfa_enabled: true } : current);
    } catch (error) {
      setConnectionError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function disableMFA() {
    setLoading("mfa-disable");
    setConnectionError("");
    try {
      await connectionApi.disableMFA(mfaCode);
      setConnectionNotice("MFA disabled for this user.");
      setMfaSetup(null);
      setMfaCode("");
      setMfaRecoveryCodes([]);
    } catch (error) {
      setConnectionError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function regenerateMFARecoveryCodes() {
    setLoading("mfa-regenerate-codes");
    setConnectionError("");
    try {
      const result = await connectionApi.regenerateMFARecoveryCodes(mfaCode);
      setMfaRecoveryCodes(result.recovery_codes ?? []);
      setConnectionNotice("Recovery codes regenerated. Save this new set now; old recovery codes no longer work.");
    } catch (error) {
      setConnectionError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function copyMFARecoveryCodes() {
    if (mfaRecoveryCodes.length === 0) {
      return;
    }
    try {
      await navigator.clipboard.writeText(mfaRecoveryCodes.join("\n"));
      setConnectionNotice("Recovery codes copied to the clipboard.");
    } catch {
      setConnectionError("Clipboard copy is unavailable in this browser. Download the codes instead.");
    }
  }

  function downloadMFARecoveryCodes() {
    if (mfaRecoveryCodes.length === 0) {
      return;
    }
    const blob = new Blob([
      [
        "Accounting Platform MFA Recovery Codes",
        `Generated: ${new Date().toISOString()}`,
        "",
        ...mfaRecoveryCodes,
        "",
        "Store these securely. Each code can be used once."
      ].join("\n")
    ], { type: "text/plain;charset=utf-8" });
    downloadBlob("accounting-mfa-recovery-codes.txt", blob);
    setConnectionNotice("Recovery codes downloaded. Store the file securely and remove it from shared devices.");
  }

  async function bootstrapFirstAdmin(event: FormEvent) {
    event.preventDefault();
    setLoading("bootstrap");
    setConnectionError("");
    try {
      const result = await connectionApi.bootstrapFirstAdmin(toBootstrapFirstAdminInput(bootstrapForm));
      const organizationId = result.organization?.id ?? draft.organizationId;
      const next = { ...draft, organizationId };
      setDraft(next);
      onSave(next);
      setConnectionNotice(`Bootstrap complete${result.organization?.name ? ` for ${result.organization.name}` : ""}. Log in with the admin email to receive tokens.`);
    } catch (error) {
      setConnectionError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function registerOrganization(event: FormEvent) {
    event.preventDefault();
    setLoading("register");
    setConnectionError("");
    try {
      const result = await connectionApi.registerOrganization(registrationForm);
      const organizationId = result.organization?.id ?? draft.organizationId;
      const next = { ...draft, organizationId };
      setDraft(next);
      onSave(next);
      setConnectionNotice(`Registration complete${result.organization?.name ? ` for ${result.organization.name}` : ""}. Log in with the owner email to receive tokens.`);
    } catch (error) {
      setConnectionError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function loadOrganizations(configOverride = draft) {
    setLoading("organizations");
    setConnectionError("");
    try {
      const nextOrganizations = await new ApiClient(configOverride).listOrganizations();
      setOrganizations(nextOrganizations);
      const firstOrganizationId = nextOrganizations[0]?.id;
      if (!configOverride.organizationId && firstOrganizationId) {
        const next = { ...configOverride, organizationId: firstOrganizationId };
        setDraft(next);
        onSave(next);
      }
      setConnectionNotice(`Loaded ${nextOrganizations.length} organization(s).`);
    } catch (error) {
      setConnectionError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function createOrganization(event: FormEvent) {
    event.preventDefault();
    setLoading("create-organization");
    setConnectionError("");
    try {
      const organization = await connectionApi.createOrganization(toCreateOrganizationInput(organizationForm));
      const next = { ...draft, organizationId: organization.id };
      setOrganizations([organization, ...organizations]);
      setOrganizationForm({ name: "", base_currency: "INR", country_code: "IN" });
      setDraft(next);
      onSave(next);
      setConnectionNotice(`Created and selected ${organization.name}.`);
    } catch (error) {
      setConnectionError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  return (
    <div className="connection-card stack">
      <section className="panel">
        <p className="eyebrow">Connection status</p>
        <h3>Account session readiness</h3>
        <p>Use this checklist before testing protected workflows. Tokens are stored only in this browser's local settings.</p>
        <div className="security-checklist">
          {connectionChecks.map((check) => (
            <span key={check.label} className={check.ok ? "check-good" : "check-warn"}>
              {check.ok ? "Ready" : "Missing"} · {check.label}
            </span>
          ))}
        </div>
      </section>

      <form className="form-grid" onSubmit={submit}>
        <label>
          API URL
          <input value={draft.baseUrl} onChange={(event) => setDraft({ ...draft, baseUrl: event.target.value })} />
        </label>
        <label>
          Access token
          <textarea value={draft.accessToken} onChange={(event) => setDraft({ ...draft, accessToken: event.target.value })} />
        </label>
        <label>
          Refresh token
          <textarea value={draft.refreshToken ?? ""} onChange={(event) => setDraft({ ...draft, refreshToken: event.target.value })} />
        </label>
        <label>
          Organization ID
          <input value={draft.organizationId} onChange={(event) => setDraft({ ...draft, organizationId: event.target.value })} />
        </label>
        <button type="submit">Save connection</button>
        <button className="secondary" type="button" disabled={!draft.refreshToken || loading === "refresh-token"} onClick={() => void refreshAccessToken()}>
          {loading === "refresh-token" ? "Refreshing..." : "Refresh token"}
        </button>
        <button className="secondary" type="button" disabled={!draft.refreshToken || loading === "logout"} onClick={() => void logoutCurrentSession()}>
          {loading === "logout" ? "Logging out..." : "Logout session"}
        </button>
        <button className="secondary" type="button" disabled={!draft.accessToken || loading === "revoke-sessions"} onClick={() => void revokeAllSessions()}>
          {loading === "revoke-sessions" ? "Revoking..." : "Revoke all sessions"}
        </button>
      </form>

      {connectionError && <div className="alert error">{connectionError}</div>}
      {connectionNotice && <div className="alert success">{connectionNotice}</div>}

      <form className="form-grid" onSubmit={login}>
        <input placeholder="Email" value={loginForm.email} onChange={(event) => setLoginForm({ ...loginForm, email: event.target.value })} />
        <input placeholder="Password" type="password" value={loginForm.password} onChange={(event) => setLoginForm({ ...loginForm, password: event.target.value })} />
        <input placeholder="MFA or recovery code (if enabled)" value={loginForm.mfa_code ?? ""} onChange={(event) => setLoginForm({ ...loginForm, mfa_code: event.target.value })} />
        <button disabled={!loginForm.email || !loginForm.password || loading === "login"}>{loading === "login" ? "Logging in..." : "Login"}</button>
        <button className="secondary" type="button" disabled={!draft.accessToken || loading === "organizations"} onClick={() => void loadOrganizations()}>
          {loading === "organizations" ? "Loading..." : "Load organizations"}
        </button>
      </form>

      <section className="panel">
        <p className="eyebrow">Account settings</p>
        <h3>Current user</h3>
        <p>Load the authenticated profile, update your display name, or rotate your password without asking an administrator.</p>
        <div className="button-row">
          <button className="secondary" type="button" disabled={!draft.accessToken || loading === "current-user"} onClick={() => void loadCurrentUserProfile()}>
            {loading === "current-user" ? "Loading..." : "Load account settings"}
          </button>
        </div>
        {currentUserProfile && (
          <div className="snapshot-card">
            <strong>{currentUserProfile.name}</strong>
            <p>{currentUserProfile.email} · {currentUserProfile.mfa_enabled ? "MFA enabled" : "MFA disabled"} · {currentUserProfile.is_active ? "Active" : "Inactive"}</p>
            <div className="security-checklist">
              {Object.entries(currentUserProfile.organization_roles).map(([organizationId, role]) => (
                <span key={organizationId} className="check-good">{roleLabel(role)} · {organizationId.slice(0, 8)}</span>
              ))}
            </div>
          </div>
        )}
        <form className="form-grid" onSubmit={updateCurrentUserProfile}>
          <input placeholder="Display name" value={profileName} onChange={(event) => setProfileName(event.target.value)} />
          <button disabled={!draft.accessToken || !profileName.trim() || loading === "update-current-user"}>
            {loading === "update-current-user" ? "Saving..." : "Update profile"}
          </button>
        </form>
        <form className="form-grid" onSubmit={changeCurrentPassword}>
          <input placeholder="Current password" type="password" value={changePasswordForm.current_password} onChange={(event) => setChangePasswordForm({ ...changePasswordForm, current_password: event.target.value })} />
          <input placeholder="New password, 12+ characters" type="password" value={changePasswordForm.new_password} onChange={(event) => setChangePasswordForm({ ...changePasswordForm, new_password: event.target.value })} />
          <button disabled={!draft.accessToken || !canChangePassword || loading === "change-password"}>
            {loading === "change-password" ? "Changing..." : "Change password"}
          </button>
        </form>
        <div className="security-checklist">
          {changePasswordChecks.map((check) => (
            <span key={check.label} className={check.ok ? "check-good" : "check-warn"}>
              {check.ok ? "OK" : "Need"} · {check.label}
            </span>
          ))}
        </div>
      </section>

      <section className="panel">
        <p className="eyebrow">Account recovery</p>
        <h3>Password reset</h3>
        <p>Request a reset email, then paste the emailed token or link token here to set a new password. Development environments may return the token directly when explicitly configured.</p>
        <form className="form-grid" onSubmit={requestPasswordReset}>
          <input placeholder="Account email" value={passwordResetEmail} onChange={(event) => setPasswordResetEmail(event.target.value)} />
          <button disabled={!passwordResetEmail || loading === "request-password-reset"}>
            {loading === "request-password-reset" ? "Requesting..." : "Request reset"}
          </button>
        </form>
        <form className="form-grid" onSubmit={confirmPasswordReset}>
          <input placeholder="Reset token" value={passwordResetToken} onChange={(event) => setPasswordResetToken(event.target.value)} />
          <input placeholder="New password, 12+ characters" type="password" value={passwordResetNewPassword} onChange={(event) => setPasswordResetNewPassword(event.target.value)} />
          <button disabled={!passwordResetToken || !passwordReady || loading === "confirm-password-reset"}>
            {loading === "confirm-password-reset" ? "Resetting..." : "Set new password"}
          </button>
        </form>
        <div className="security-checklist">
          {passwordResetChecks.map((check) => (
            <span key={check.label} className={check.ok ? "check-good" : "check-warn"}>
              {check.ok ? "OK" : "Need"} · {check.label}
            </span>
          ))}
        </div>
        {passwordResetTokenExpiresAt && (
          <div className="snapshot-card">
            <strong>Returned reset token expires:</strong> {new Date(passwordResetTokenExpiresAt).toLocaleString()}
          </div>
        )}
      </section>

      {organizations.length > 0 && (
        <label>
          Select organization
          <select value={draft.organizationId} onChange={(event) => {
            const next = { ...draft, organizationId: event.target.value };
            setDraft(next);
            onSave(next);
          }}>
            <option value="">Select organization</option>
            {organizations.map((organization) => (
              <option key={organization.id} value={organization.id}>{organization.name} ({organization.base_currency})</option>
            ))}
          </select>
        </label>
      )}

      <section className="panel">
        <p className="eyebrow">Security</p>
        <h3>Multi-factor authentication</h3>
        <p>Generate a TOTP secret, add it to an authenticator app, then enter a current 6-digit code to enable MFA. Recovery codes can be used once if the authenticator is unavailable.</p>
        <div className="button-row">
          <button className="secondary" type="button" disabled={!draft.accessToken || loading === "mfa-setup"} onClick={() => void setupMFA()}>
            {loading === "mfa-setup" ? "Generating..." : "Setup MFA"}
          </button>
          <button className="secondary" type="button" disabled={!draft.accessToken || !mfaCode || loading === "mfa-enable"} onClick={() => void enableMFA()}>
            {loading === "mfa-enable" ? "Enabling..." : "Enable MFA"}
          </button>
          <button className="secondary" type="button" disabled={!draft.accessToken || !mfaCode || loading === "mfa-disable"} onClick={() => void disableMFA()}>
            {loading === "mfa-disable" ? "Disabling..." : "Disable MFA"}
          </button>
          <button className="secondary" type="button" disabled={!draft.accessToken || !mfaCode || loading === "mfa-regenerate-codes"} onClick={() => void regenerateMFARecoveryCodes()}>
            {loading === "mfa-regenerate-codes" ? "Regenerating..." : "Regenerate recovery codes"}
          </button>
        </div>
        <input placeholder="Authenticator code" value={mfaCode} onChange={(event) => setMfaCode(event.target.value)} />
        {mfaSetup && (
          <div className="snapshot-card">
            <strong>Secret:</strong> {mfaSetup.secret}
            <br />
            <strong>OTPAuth URL:</strong> {mfaSetup.otpauth_url}
          </div>
        )}
        {mfaRecoveryCodes.length > 0 && (
          <div className="snapshot-card">
            <strong>Recovery codes:</strong>
            <p>Store these securely. Each code works once and this list will disappear after you leave this screen.</p>
            <div className="button-row">
              <button className="secondary compact" type="button" onClick={() => void copyMFARecoveryCodes()}>Copy codes</button>
              <button className="secondary compact" type="button" onClick={downloadMFARecoveryCodes}>Download codes</button>
            </div>
            <div className="code-grid">
              {mfaRecoveryCodes.map((code) => (
                <code key={code}>{code}</code>
              ))}
            </div>
          </div>
        )}
      </section>

      <form className="form-grid" onSubmit={createOrganization}>
        <input placeholder="New organization name" value={organizationForm.name} onChange={(event) => setOrganizationForm({ ...organizationForm, name: event.target.value })} />
        <input placeholder="Currency" maxLength={3} value={organizationForm.base_currency} onChange={(event) => setOrganizationForm({ ...organizationForm, base_currency: event.target.value.toUpperCase() })} />
        <input placeholder="Country" value={organizationForm.country_code ?? ""} onChange={(event) => setOrganizationForm({ ...organizationForm, country_code: event.target.value.toUpperCase() })} />
        <button disabled={!draft.accessToken || !organizationForm.name.trim() || loading === "create-organization"}>
          {loading === "create-organization" ? "Creating..." : "Create organization"}
        </button>
      </form>

      <form className="form-grid" onSubmit={bootstrapFirstAdmin}>
        <input placeholder="Bootstrap organization" value={bootstrapForm.organization_name} onChange={(event) => setBootstrapForm({ ...bootstrapForm, organization_name: event.target.value })} />
        <input placeholder="Admin name" value={bootstrapForm.admin_name} onChange={(event) => setBootstrapForm({ ...bootstrapForm, admin_name: event.target.value })} />
        <input placeholder="Admin email" value={bootstrapForm.admin_email} onChange={(event) => setBootstrapForm({ ...bootstrapForm, admin_email: event.target.value })} />
        <input placeholder="Admin password" type="password" value={bootstrapForm.admin_password} onChange={(event) => setBootstrapForm({ ...bootstrapForm, admin_password: event.target.value })} />
        <input placeholder="Currency" maxLength={3} value={bootstrapForm.base_currency ?? ""} onChange={(event) => setBootstrapForm({ ...bootstrapForm, base_currency: event.target.value.toUpperCase() })} />
        <label>
          Seed India defaults
          <select value={bootstrapForm.seed_india_defaults ? "yes" : "no"} onChange={(event) => setBootstrapForm({ ...bootstrapForm, seed_india_defaults: event.target.value === "yes" })}>
            <option value="yes">Yes</option>
            <option value="no">No</option>
          </select>
        </label>
        <button disabled={!bootstrapForm.organization_name || !bootstrapForm.admin_email || bootstrapForm.admin_password.length < 12 || loading === "bootstrap"}>
          {loading === "bootstrap" ? "Bootstrapping..." : "Bootstrap first admin"}
        </button>
      </form>

      <form className="form-grid" onSubmit={registerOrganization}>
        <input placeholder="Register organization" value={registrationForm.organization_name} onChange={(event) => setRegistrationForm({ ...registrationForm, organization_name: event.target.value })} />
        <input placeholder="Owner name" value={registrationForm.admin_name} onChange={(event) => setRegistrationForm({ ...registrationForm, admin_name: event.target.value })} />
        <input placeholder="Owner email" value={registrationForm.admin_email} onChange={(event) => setRegistrationForm({ ...registrationForm, admin_email: event.target.value })} />
        <input placeholder="Owner password" type="password" value={registrationForm.admin_password} onChange={(event) => setRegistrationForm({ ...registrationForm, admin_password: event.target.value })} />
        <input placeholder="Currency" maxLength={3} value={registrationForm.base_currency ?? ""} onChange={(event) => setRegistrationForm({ ...registrationForm, base_currency: event.target.value.toUpperCase() })} />
        <label>
          Seed India defaults
          <select value={registrationForm.seed_india_defaults ? "yes" : "no"} onChange={(event) => setRegistrationForm({ ...registrationForm, seed_india_defaults: event.target.value === "yes" })}>
            <option value="yes">Yes</option>
            <option value="no">No</option>
          </select>
        </label>
        <button disabled={!registrationForm.organization_name || !registrationForm.admin_email || registrationForm.admin_password.length < 12 || loading === "register"}>
          {loading === "register" ? "Registering..." : "Register organization"}
        </button>
      </form>
    </div>
  );
}

function Dashboard({
  accounts,
  transactions,
  taxRates,
  taxGroups,
  queuedAccountDrafts,
  queuedJournalDrafts,
  hasConnection,
  onOpenAccounts,
  onOpenLedger,
  onSyncAllQueuedDrafts
}: {
  accounts: Account[];
  transactions: JournalTransaction[];
  taxRates: number;
  taxGroups: number;
  queuedAccountDrafts: number;
  queuedJournalDrafts: number;
  hasConnection: boolean;
  onOpenAccounts: () => void;
  onOpenLedger: () => void;
  onSyncAllQueuedDrafts: () => Promise<void>;
}) {
  const activeAccounts = accounts.filter((account) => account.is_active).length;
  const postedTransactions = transactions.filter((transaction) => transaction.status === "posted").length;
  const totalQueuedDrafts = queuedAccountDrafts + queuedJournalDrafts;

  return (
    <div className="grid">
      <Metric label="Active accounts" value={activeAccounts.toString()} />
      <Metric label="Posted transactions" value={postedTransactions.toString()} />
      <Metric label="Offline drafts" value={totalQueuedDrafts.toString()} />
      <Metric label="Currencies in chart" value={new Set(accounts.map((account) => account.currency)).size.toString()} />
      <Metric label="GST rates cached" value={taxRates.toString()} />
      <Metric label="Tax groups cached" value={taxGroups.toString()} />
      <section className="panel wide offline-panel">
        <div>
          <p className="eyebrow">Offline readiness</p>
          <h3>{hasConnection ? "Ready to sync queued work" : "Waiting for connection settings"}</h3>
          <p>
            Cached locally: {accounts.length} accounts and {transactions.length} journal transactions.
            Queued locally: {queuedAccountDrafts} account drafts and {queuedJournalDrafts} journal drafts.
          </p>
        </div>
        <div className="button-row">
          <button
            disabled={!hasConnection || totalQueuedDrafts === 0}
            onClick={() => void onSyncAllQueuedDrafts()}
          >
            Sync all queued work
          </button>
          <button className="secondary" onClick={onOpenAccounts}>Review account queue</button>
          <button className="secondary" onClick={onOpenLedger}>Review journal queue</button>
        </div>
      </section>
      <section className="panel wide">
        <h3>Next useful moves</h3>
        <p>Create your chart, post opening balances, seed GST presets, then start recording invoices and expenses. The backend is ready for those workflows; this web shell gives us a clean control room to grow from.</p>
      </section>
    </div>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <section className="metric">
      <span>{label}</span>
      <strong>{value}</strong>
    </section>
  );
}

function TaxPage({
  api,
  accounts,
  taxAuthorities,
  taxRates,
  taxGroups,
  onTaxAuthoritiesChanged,
  onTaxRatesChanged,
  onTaxGroupsChanged,
  onRefresh
}: {
  api: ApiClient;
  accounts: Account[];
  taxAuthorities: TaxAuthority[];
  taxRates: TaxRate[];
  taxGroups: TaxGroup[];
  onTaxAuthoritiesChanged: (authorities: TaxAuthority[]) => void;
  onTaxRatesChanged: (rates: TaxRate[]) => void;
  onTaxGroupsChanged: (groups: TaxGroup[]) => void;
  onRefresh: () => Promise<void>;
}) {
  const activeRates = taxRates.filter((rate) => rate.is_active).length;
  const activeGroups = taxGroups.filter((group) => group.is_active).length;
  const taxAccounts = accounts.filter((account) => account.type === "liability" || account.type === "asset");
  const defaultAuthorityId = taxAuthorities[0]?.id ?? "";
  const [calculator, setCalculator] = useState({
    amount_minor: 10000,
    tax_inclusive: false,
    target: defaultTaxTarget(taxGroups, taxRates)
  });
  const [authorityForm, setAuthorityForm] = useState<CreateTaxAuthorityInput>({ name: "", country_code: "IN", region_code: "" });
  const [rateForm, setRateForm] = useState<CreateTaxRateInput>({
    tax_authority_id: defaultAuthorityId,
    name: "",
    percentage_basis: 180000,
    type: "GST",
    output_account_id: "",
    input_account_id: "",
    effective_from: new Date().toISOString().slice(0, 10),
    effective_to: "",
    is_compound: false
  });
  const [groupForm, setGroupForm] = useState<CreateTaxGroupInput>({ name: "", description: "", tax_rate_ids: [] });
  const [calculation, setCalculation] = useState<TaxCalculation | null>(null);
  const [calculationError, setCalculationError] = useState("");
  const [taxConfigError, setTaxConfigError] = useState("");
  const [taxConfigNotice, setTaxConfigNotice] = useState("");
  const [seedResult, setSeedResult] = useState<IndiaSeedResult | null>(null);
  const [seedError, setSeedError] = useState("");
  const canCalculate = calculator.amount_minor >= 0 && Boolean(calculator.target);
  const canCreateAuthority = Boolean(authorityForm.name.trim());
  const canCreateRate = Boolean(rateForm.tax_authority_id && rateForm.name.trim() && rateForm.effective_from && rateForm.percentage_basis >= 0);
  const canCreateGroup = Boolean(groupForm.name.trim() && groupForm.tax_rate_ids.length > 0);

  useEffect(() => {
    if (!calculator.target) {
      setCalculator((current) => ({ ...current, target: defaultTaxTarget(taxGroups, taxRates) }));
    }
  }, [calculator.target, taxGroups, taxRates]);

  useEffect(() => {
    if (!rateForm.tax_authority_id && taxAuthorities[0]) {
      setRateForm((current) => ({ ...current, tax_authority_id: taxAuthorities[0].id }));
    }
  }, [rateForm.tax_authority_id, taxAuthorities]);

  async function calculate(event: FormEvent) {
    event.preventDefault();
    if (!calculator.target) {
      return;
    }

    setCalculationError("");
    try {
      const target = parseTaxTarget(calculator.target);
      const result = await api.calculateTax({
        base_amount_minor: calculator.amount_minor,
        tax_inclusive: calculator.tax_inclusive,
        tax_group_id: target.kind === "group" ? target.id : undefined,
        tax_rate_id: target.kind === "rate" ? target.id : undefined
      });
      setCalculation(result);
    } catch (error) {
      setCalculation(null);
      setCalculationError(errorMessage(error));
    }
  }

  async function seedIndiaDefaults() {
    setSeedError("");
    setSeedResult(null);
    try {
      const result = await api.seedIndiaDefaults();
      setSeedResult(result);
      await onRefresh();
    } catch (error) {
      setSeedError(errorMessage(error));
    }
  }

  async function createAuthority(event: FormEvent) {
    event.preventDefault();
    if (!canCreateAuthority) {
      return;
    }
    setTaxConfigError("");
    try {
      const authority = await api.createTaxAuthority(toTaxAuthorityInput(authorityForm));
      onTaxAuthoritiesChanged([authority, ...taxAuthorities]);
      setAuthorityForm({ name: "", country_code: "IN", region_code: "" });
      setTaxConfigNotice(`Tax authority ${authority.name} created.`);
      await onRefresh();
    } catch (error) {
      setTaxConfigError(errorMessage(error));
    }
  }

  async function createRate(event: FormEvent) {
    event.preventDefault();
    if (!canCreateRate) {
      return;
    }
    setTaxConfigError("");
    try {
      const rate = await api.createTaxRate(toTaxRateInput(rateForm));
      onTaxRatesChanged([rate, ...taxRates]);
      setRateForm({ ...rateForm, name: "", percentage_basis: 0, effective_to: "" });
      setTaxConfigNotice(`Tax rate ${rate.name} created.`);
      await onRefresh();
    } catch (error) {
      setTaxConfigError(errorMessage(error));
    }
  }

  async function createGroup(event: FormEvent) {
    event.preventDefault();
    if (!canCreateGroup) {
      return;
    }
    setTaxConfigError("");
    try {
      const group = await api.createTaxGroup(toTaxGroupInput(groupForm));
      onTaxGroupsChanged([group, ...taxGroups]);
      setGroupForm({ name: "", description: "", tax_rate_ids: [] });
      setTaxConfigNotice(`Tax group ${group.name} created.`);
      await onRefresh();
    } catch (error) {
      setTaxConfigError(errorMessage(error));
    }
  }

  function toggleGroupRate(rateId: string) {
    setGroupForm((current) => ({
      ...current,
      tax_rate_ids: current.tax_rate_ids.includes(rateId)
        ? current.tax_rate_ids.filter((candidate) => candidate !== rateId)
        : [...current.tax_rate_ids, rateId]
    }));
  }

  return (
    <div className="stack">
      <section className="panel offline-panel">
        <div>
          <p className="eyebrow">GST catalog</p>
          <h3>Config-driven India tax setup</h3>
          <p>
            Cached locally: {taxRates.length} tax rates ({activeRates} active) and {taxGroups.length} groups ({activeGroups} active).
            Refresh when online to pull the latest GST presets and organization-specific edits.
          </p>
        </div>
        <div className="button-row">
          <button className="secondary" onClick={() => void onRefresh()}>Refresh tax catalog</button>
          <button onClick={() => void seedIndiaDefaults()}>Seed India defaults</button>
        </div>
      </section>

      {seedError && <div className="alert error">{seedError}</div>}
      {taxConfigError && <div className="alert error">{taxConfigError}</div>}
      {taxConfigNotice && <div className="alert success">{taxConfigNotice}</div>}
      {seedResult && (
        <div className="alert success">
          Seeded {seedResult.accounts_created} accounts, {seedResult.tax_rates_created} rates, and {seedResult.tax_groups_created} groups.
          GST authority {seedResult.tax_authority_created ? "created" : "already existed"}.
        </div>
      )}

      <form className="panel form-grid" onSubmit={createAuthority}>
        <input placeholder="Authority name" value={authorityForm.name} onChange={(event) => setAuthorityForm({ ...authorityForm, name: event.target.value })} />
        <input placeholder="Country code" value={authorityForm.country_code ?? ""} onChange={(event) => setAuthorityForm({ ...authorityForm, country_code: event.target.value.toUpperCase() })} />
        <input placeholder="Region code" value={authorityForm.region_code ?? ""} onChange={(event) => setAuthorityForm({ ...authorityForm, region_code: event.target.value.toUpperCase() })} />
        <button disabled={!canCreateAuthority}>Create authority</button>
      </form>

      <form className="panel form-grid" onSubmit={createRate}>
        <label>
          Authority
          <select value={rateForm.tax_authority_id} onChange={(event) => setRateForm({ ...rateForm, tax_authority_id: event.target.value })}>
            <option value="">Select authority</option>
            {taxAuthorities.map((authority) => (
              <option key={authority.id} value={authority.id}>{authority.name}</option>
            ))}
          </select>
        </label>
        <input placeholder="Rate name" value={rateForm.name} onChange={(event) => setRateForm({ ...rateForm, name: event.target.value })} />
        <label>
          Percentage basis
          <input type="number" min="0" value={rateForm.percentage_basis} onChange={(event) => setRateForm({ ...rateForm, percentage_basis: Number(event.target.value) })} />
        </label>
        <label>
          Type
          <select value={rateForm.type} onChange={(event) => setRateForm({ ...rateForm, type: event.target.value as TaxRate["type"] })}>
            <option value="GST">GST</option>
            <option value="VAT">VAT</option>
            <option value="Sales Tax">Sales Tax</option>
            <option value="Withholding">Withholding</option>
          </select>
        </label>
        <AccountSelect label="Output tax account" accounts={taxAccounts} value={rateForm.output_account_id ?? ""} onChange={(value) => setRateForm({ ...rateForm, output_account_id: value })} />
        <AccountSelect label="Input tax account" accounts={taxAccounts} value={rateForm.input_account_id ?? ""} onChange={(value) => setRateForm({ ...rateForm, input_account_id: value })} />
        <label>
          Effective from
          <input type="date" value={rateForm.effective_from} onChange={(event) => setRateForm({ ...rateForm, effective_from: event.target.value })} />
        </label>
        <label>
          Effective to
          <input type="date" value={rateForm.effective_to ?? ""} onChange={(event) => setRateForm({ ...rateForm, effective_to: event.target.value })} />
        </label>
        <label>
          Compound
          <select value={rateForm.is_compound ? "yes" : "no"} onChange={(event) => setRateForm({ ...rateForm, is_compound: event.target.value === "yes" })}>
            <option value="no">No</option>
            <option value="yes">Yes</option>
          </select>
        </label>
        <button disabled={!canCreateRate}>Create tax rate</button>
      </form>

      <form className="panel queue-panel" onSubmit={createGroup}>
        <div className="queue-heading">
          <div>
            <p className="eyebrow">Tax group</p>
            <h3>Create split/compound group</h3>
            <p>Select one or more configured rates, such as CGST plus SGST.</p>
          </div>
          <strong>{groupForm.tax_rate_ids.length}</strong>
        </div>
        <div className="form-grid">
          <input placeholder="Group name" value={groupForm.name} onChange={(event) => setGroupForm({ ...groupForm, name: event.target.value })} />
          <input placeholder="Description" value={groupForm.description ?? ""} onChange={(event) => setGroupForm({ ...groupForm, description: event.target.value })} />
        </div>
        <section className="table-panel">
          <table>
            <thead>
              <tr>
                <th>Use</th>
                <th>Rate</th>
                <th>Basis</th>
                <th>Type</th>
              </tr>
            </thead>
            <tbody>
              {taxRates.map((rate) => (
                <tr key={rate.id}>
                  <td><input type="checkbox" checked={groupForm.tax_rate_ids.includes(rate.id)} onChange={() => toggleGroupRate(rate.id)} /></td>
                  <td>{rate.name}</td>
                  <td>{formatTaxBasis(rate.percentage_basis)}</td>
                  <td>{rate.type}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
        <button disabled={!canCreateGroup}>Create tax group</button>
      </form>

      <form className="panel form-grid" onSubmit={calculate}>
        <label>
          Amount in paise
          <input
            type="number"
            min="0"
            value={calculator.amount_minor}
            onChange={(event) => setCalculator({ ...calculator, amount_minor: Number(event.target.value) })}
          />
        </label>
        <label>
          Tax target
          <select
            value={calculator.target}
            onChange={(event) => setCalculator({ ...calculator, target: event.target.value })}
            required
          >
            <option value="">Select GST rate or group</option>
            {taxGroups.map((group) => (
              <option key={group.id} value={`group:${group.id}`}>Group: {group.name}</option>
            ))}
            {taxRates.map((rate) => (
              <option key={rate.id} value={`rate:${rate.id}`}>Rate: {rate.name}</option>
            ))}
          </select>
        </label>
        <label>
          Pricing mode
          <select
            value={calculator.tax_inclusive ? "inclusive" : "exclusive"}
            onChange={(event) => setCalculator({ ...calculator, tax_inclusive: event.target.value === "inclusive" })}
          >
            <option value="exclusive">Tax exclusive</option>
            <option value="inclusive">Tax inclusive</option>
          </select>
        </label>
        <button disabled={!canCalculate}>Preview GST</button>
      </form>

      {calculationError && <div className="alert error">{calculationError}</div>}
      {calculation && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">Calculation preview</p>
              <h3>{formatMinorAsInr(calculation.total_amount_minor)} total</h3>
              <p>
                Base {formatMinorAsInr(calculation.base_amount_minor)} plus tax {formatMinorAsInr(calculation.tax_amount_minor)}.
              </p>
            </div>
            <strong>{calculation.components.length}</strong>
          </div>
          <DataTable
            headers={["Component", "Rate", "Tax amount"]}
            rows={calculation.components.map((component) => [
              component.name,
              formatTaxBasis(component.percentage_basis),
              formatMinorAsInr(component.tax_amount_minor)
            ])}
          />
        </section>
      )}

      <section className="panel queue-panel">
        <div className="queue-heading">
          <div>
            <p className="eyebrow">Rates</p>
            <h3>Tax rates</h3>
            <p>Rates stay rule-based: no hardcoded country behavior in business code.</p>
          </div>
          <strong>{taxRates.length}</strong>
        </div>
        <DataTable
          headers={["Name", "Type", "Rate", "Effective from", "Active"]}
          rows={taxRates.map((rate) => [
            rate.name,
            rate.type,
            formatTaxBasis(rate.percentage_basis),
            rate.effective_from.slice(0, 10),
            rate.is_active ? "Yes" : "No"
          ])}
        />
      </section>

      <section className="panel queue-panel">
        <div className="queue-heading">
          <div>
            <p className="eyebrow">Groups</p>
            <h3>Tax groups</h3>
            <p>Groups model split GST such as CGST plus SGST while keeping each component separately reportable.</p>
          </div>
          <strong>{taxGroups.length}</strong>
        </div>
        <DataTable
          headers={["Name", "Components", "Total rate", "Active"]}
          rows={taxGroups.map((group) => [
            group.name,
            formatTaxGroupComponents(group),
            formatTaxBasis(totalTaxGroupBasis(group)),
            group.is_active ? "Yes" : "No"
          ])}
        />
      </section>
    </div>
  );
}

function ReportsPage({
  api,
  budgets,
  onBudgetsChanged,
  onOpenSourceDocument
}: {
  api: ApiClient;
  budgets: Budget[];
  onBudgetsChanged: (budgets: Budget[]) => void;
  onOpenSourceDocument: (target: FocusTarget) => void;
}) {
  const today = new Date().toISOString().slice(0, 10);
  const cachedReports = useMemo(() => loadReportSnapshot(), []);
  const [asOf, setAsOf] = useState(today);
  const [fromDate, setFromDate] = useState(`${today.slice(0, 4)}-04-01`);
  const [toDate, setToDate] = useState(today);
  const [reportSnapshot, setReportSnapshot] = useState<ReportSnapshot>(() => cachedReports ?? { savedAt: "" });
  const [selectedBudgetId, setSelectedBudgetId] = useState(cachedReports?.budgetVsActual?.budget_id ?? "");
  const [trialBalance, setTrialBalance] = useState<TrialBalanceReport | null>(() => cachedReports?.trialBalance ?? null);
  const [profitAndLoss, setProfitAndLoss] = useState<ProfitAndLossReport | null>(() => cachedReports?.profitAndLoss ?? null);
  const [balanceSheet, setBalanceSheet] = useState<BalanceSheetReport | null>(() => cachedReports?.balanceSheet ?? null);
  const [cashFlow, setCashFlow] = useState<CashFlowReport | null>(() => cachedReports?.cashFlow ?? null);
  const [arAging, setARAging] = useState<ARAgingReport | null>(() => cachedReports?.arAging ?? null);
  const [apAging, setAPAging] = useState<APAgingReport | null>(() => cachedReports?.apAging ?? null);
  const [taxLiability, setTaxLiability] = useState<TaxLiabilityReport | null>(() => cachedReports?.taxLiability ?? null);
  const [taxSummary, setTaxSummary] = useState<TaxSummaryReport | null>(() => cachedReports?.taxSummary ?? null);
  const [payrollSummary, setPayrollSummary] = useState<PayrollSummaryReport | null>(() => cachedReports?.payrollSummary ?? null);
  const [budgetVsActual, setBudgetVsActual] = useState<BudgetVsActualReport | null>(() => cachedReports?.budgetVsActual ?? null);
  const [accountDrilldown, setAccountDrilldown] = useState<AccountDrilldownReport | null>(null);
  const [accountDrilldownLabel, setAccountDrilldownLabel] = useState("");
  const [scheduledReports, setScheduledReports] = useState<ScheduledReport[]>([]);
  const [scheduledReportRuns, setScheduledReportRuns] = useState<ScheduledReportRun[]>([]);
  const [selectedScheduledReportId, setSelectedScheduledReportId] = useState("");
  const [scheduledReportForm, setScheduledReportForm] = useState<CreateScheduledReportInput>({
    name: "Monthly P&L",
    report_type: "profit_and_loss",
    frequency: "monthly",
    parameters_json: `{"from_date":"${fromDate}","to_date":"${toDate}"}`,
    email_recipients: "",
    next_run_at: today
  });
  const [loadingReport, setLoadingReport] = useState<"trial-balance" | "profit-and-loss" | "balance-sheet" | "cash-flow" | "account-drilldown" | "ar-aging" | "ap-aging" | "tax-liability" | "tax-summary" | "payroll-summary" | "budgets" | "budget-vs-actual" | "scheduled-reports" | "scheduled-runs" | "report-pdf" | null>(null);
  const [reportError, setReportError] = useState("");

  async function loadTrialBalance(event?: FormEvent) {
    event?.preventDefault();
    setLoadingReport("trial-balance");
    setReportError("");
    try {
      const report = await api.getTrialBalance(asOf);
      setTrialBalance(report);
      persistReportSnapshot({ trialBalance: report });
    } catch (error) {
      setTrialBalance(null);
      setReportError(errorMessage(error));
    } finally {
      setLoadingReport(null);
    }
  }

  async function loadProfitAndLoss(event?: FormEvent) {
    event?.preventDefault();
    setLoadingReport("profit-and-loss");
    setReportError("");
    try {
      const report = await api.getProfitAndLoss(fromDate, toDate);
      setProfitAndLoss(report);
      persistReportSnapshot({ profitAndLoss: report });
    } catch (error) {
      setProfitAndLoss(null);
      setReportError(errorMessage(error));
    } finally {
      setLoadingReport(null);
    }
  }

  async function loadBalanceSheet(event?: FormEvent) {
    event?.preventDefault();
    setLoadingReport("balance-sheet");
    setReportError("");
    try {
      const report = await api.getBalanceSheet(asOf);
      setBalanceSheet(report);
      persistReportSnapshot({ balanceSheet: report });
    } catch (error) {
      setBalanceSheet(null);
      setReportError(errorMessage(error));
    } finally {
      setLoadingReport(null);
    }
  }

  async function loadCashFlow(event?: FormEvent) {
    event?.preventDefault();
    setLoadingReport("cash-flow");
    setReportError("");
    try {
      const report = await api.getCashFlow(fromDate, toDate);
      setCashFlow(report);
      persistReportSnapshot({ cashFlow: report });
    } catch (error) {
      setCashFlow(null);
      setReportError(errorMessage(error));
    } finally {
      setLoadingReport(null);
    }
  }

  async function loadAccountDrilldown(row: Pick<ReportRow, "account_id" | "account_code" | "account_name">, from: string, to: string) {
    setLoadingReport("account-drilldown");
    setReportError("");
    try {
      const report = await api.getAccountDrilldown(row.account_id, from, to);
      setAccountDrilldown(report);
      setAccountDrilldownLabel(`${row.account_code} · ${row.account_name}`);
    } catch (error) {
      setReportError(errorMessage(error));
    } finally {
      setLoadingReport(null);
    }
  }

  function fiscalYearStartFor(date: string) {
    const year = Number(date.slice(0, 4));
    const month = Number(date.slice(5, 7));
    const fiscalYear = month >= 4 ? year : year - 1;
    return `${fiscalYear}-04-01`;
  }

  function drilldownButton(row: Pick<ReportRow, "account_id" | "account_code" | "account_name">, from: string, to: string) {
    return (
      <button className="secondary compact" type="button" disabled={loadingReport === "account-drilldown"} onClick={() => void loadAccountDrilldown(row, from, to)}>
        {loadingReport === "account-drilldown" ? "Loading..." : "Drill down"}
      </button>
    );
  }

  function sourceDocumentLabel(row: AccountDrilldownReport["rows"][number]) {
    if (!row.source_document_type) {
      return "Journal entry";
    }
    const typeLabel = titleCase(row.source_document_type.replace(/_/g, " "));
    return row.source_document_number ? `${typeLabel} ${row.source_document_number}` : typeLabel;
  }

  function sourceDocumentTarget(row: AccountDrilldownReport["rows"][number]): View {
    if (row.source_document_type === "invoice" || row.source_document_type === "credit_note" || row.source_document_type === "customer_payment") {
      return "invoices";
    }
    if (row.source_document_type === "expense" || row.source_document_type === "bill" || row.source_document_type === "vendor_payment") {
      return "expenses";
    }
    if (row.source_document_type === "payroll_run") {
      return "payroll";
    }
    return "ledger";
  }

  function sourceDocumentButton(row: AccountDrilldownReport["rows"][number]) {
    const target = sourceDocumentTarget(row);
    const label = row.source_document_type ? `Open ${titleCase(row.source_document_type.replace(/_/g, " "))}` : "Open journal";
    const documentType = row.source_document_type || "journal_transaction";
    const documentId = row.source_document_id || row.journal_transaction_id;
    return (
      <button
        className="secondary compact"
        type="button"
        onClick={() => onOpenSourceDocument({
          view: target,
          documentType,
          documentId,
          documentNumber: row.source_document_number || row.transaction_memo || undefined,
          journalTransactionId: row.journal_transaction_id
        })}
        title={documentId}
      >
        {label}
      </button>
    );
  }

  async function loadARAging(event?: FormEvent) {
    event?.preventDefault();
    setLoadingReport("ar-aging");
    setReportError("");
    try {
      const report = await api.getARAging(asOf);
      setARAging(report);
      persistReportSnapshot({ arAging: report });
    } catch (error) {
      setARAging(null);
      setReportError(errorMessage(error));
    } finally {
      setLoadingReport(null);
    }
  }

  async function loadAPAging(event?: FormEvent) {
    event?.preventDefault();
    setLoadingReport("ap-aging");
    setReportError("");
    try {
      const report = await api.getAPAging(asOf);
      setAPAging(report);
      persistReportSnapshot({ apAging: report });
    } catch (error) {
      setAPAging(null);
      setReportError(errorMessage(error));
    } finally {
      setLoadingReport(null);
    }
  }

  async function loadTaxLiability(event?: FormEvent) {
    event?.preventDefault();
    setLoadingReport("tax-liability");
    setReportError("");
    try {
      const report = await api.getTaxLiability(fromDate, toDate);
      setTaxLiability(report);
      persistReportSnapshot({ taxLiability: report });
    } catch (error) {
      setTaxLiability(null);
      setReportError(errorMessage(error));
    } finally {
      setLoadingReport(null);
    }
  }

  async function loadTaxSummary(event?: FormEvent) {
    event?.preventDefault();
    setLoadingReport("tax-summary");
    setReportError("");
    try {
      const report = await api.getTaxSummary(fromDate, toDate);
      setTaxSummary(report);
      persistReportSnapshot({ taxSummary: report });
    } catch (error) {
      setTaxSummary(null);
      setReportError(errorMessage(error));
    } finally {
      setLoadingReport(null);
    }
  }

  async function loadPayrollSummary(event?: FormEvent) {
    event?.preventDefault();
    setLoadingReport("payroll-summary");
    setReportError("");
    try {
      const report = await api.getPayrollSummary(fromDate, toDate);
      setPayrollSummary(report);
      persistReportSnapshot({ payrollSummary: report });
    } catch (error) {
      setPayrollSummary(null);
      setReportError(errorMessage(error));
    } finally {
      setLoadingReport(null);
    }
  }

  async function downloadPayrollSummaryCSV() {
    setLoadingReport("payroll-summary");
    setReportError("");
    try {
      const download = await api.downloadPayrollSummaryCSV(fromDate, toDate);
      downloadBlob(download.filename, download.blob);
    } catch (error) {
      setReportError(errorMessage(error));
    } finally {
      setLoadingReport(null);
    }
  }

  async function downloadPayrollStatutoryComponentCSV(component: string) {
    setLoadingReport("payroll-summary");
    setReportError("");
    try {
      const download = await api.downloadPayrollStatutoryComponentCSV(fromDate, toDate, component);
      downloadBlob(download.filename, download.blob);
    } catch (error) {
      setReportError(errorMessage(error));
    } finally {
      setLoadingReport(null);
    }
  }

  async function downloadTrialBalancePDF() {
    setLoadingReport("report-pdf");
    setReportError("");
    try {
      const download = await api.downloadTrialBalancePDF(asOf);
      downloadBlob(download.filename, download.blob);
    } catch (error) {
      setReportError(errorMessage(error));
    } finally {
      setLoadingReport(null);
    }
  }

  async function downloadProfitAndLossPDF() {
    setLoadingReport("report-pdf");
    setReportError("");
    try {
      const download = await api.downloadProfitAndLossPDF(fromDate, toDate);
      downloadBlob(download.filename, download.blob);
    } catch (error) {
      setReportError(errorMessage(error));
    } finally {
      setLoadingReport(null);
    }
  }

  async function downloadBalanceSheetPDF() {
    setLoadingReport("report-pdf");
    setReportError("");
    try {
      const download = await api.downloadBalanceSheetPDF(asOf);
      downloadBlob(download.filename, download.blob);
    } catch (error) {
      setReportError(errorMessage(error));
    } finally {
      setLoadingReport(null);
    }
  }

  async function loadBudgets() {
    setLoadingReport("budgets");
    setReportError("");
    try {
      const nextBudgets = await api.listBudgets();
      onBudgetsChanged(nextBudgets);
      setSelectedBudgetId((current) => current || nextBudgets[0]?.id || "");
    } catch (error) {
      setReportError(errorMessage(error));
    } finally {
      setLoadingReport(null);
    }
  }

  async function loadBudgetVsActual(event?: FormEvent) {
    event?.preventDefault();
    if (!selectedBudgetId) {
      return;
    }
    setLoadingReport("budget-vs-actual");
    setReportError("");
    try {
      const report = await api.getBudgetVsActual(selectedBudgetId);
      setBudgetVsActual(report);
      persistReportSnapshot({ budgetVsActual: report });
    } catch (error) {
      setBudgetVsActual(null);
      setReportError(errorMessage(error));
    } finally {
      setLoadingReport(null);
    }
  }

  async function loadScheduledReports() {
    setLoadingReport("scheduled-reports");
    setReportError("");
    try {
      const schedules = await api.listScheduledReports();
      setScheduledReports(schedules);
      setSelectedScheduledReportId((current) => current || schedules[0]?.id || "");
    } catch (error) {
      setReportError(errorMessage(error));
    } finally {
      setLoadingReport(null);
    }
  }

  async function createScheduledReport(event: FormEvent) {
    event.preventDefault();
    setLoadingReport("scheduled-reports");
    setReportError("");
    try {
      const created = await api.createScheduledReport({
        ...scheduledReportForm,
        parameters_json: scheduledReportForm.parameters_json?.trim()
          ? scheduledReportForm.parameters_json.trim()
          : undefined,
        email_recipients: scheduledReportForm.email_recipients?.trim()
          ? scheduledReportForm.email_recipients.trim()
          : undefined
      });
      setScheduledReports((current) => [created, ...current]);
      setSelectedScheduledReportId(created.id);
    } catch (error) {
      setReportError(errorMessage(error));
    } finally {
      setLoadingReport(null);
    }
  }

  async function loadScheduledReportRuns(reportId = selectedScheduledReportId) {
    if (!reportId) {
      return;
    }
    setLoadingReport("scheduled-runs");
    setReportError("");
    try {
      setScheduledReportRuns(await api.listScheduledReportRuns(reportId));
      setSelectedScheduledReportId(reportId);
    } catch (error) {
      setReportError(errorMessage(error));
    } finally {
      setLoadingReport(null);
    }
  }

  function persistReportSnapshot(update: Partial<Omit<ReportSnapshot, "savedAt">>) {
    const next = {
      ...reportSnapshot,
      ...update,
      savedAt: new Date().toISOString()
    };
    setReportSnapshot(next);
    saveReportSnapshot(next);
  }

  function clearCachedReports() {
    clearReportSnapshot();
    setReportSnapshot({ savedAt: "" });
    setTrialBalance(null);
    setProfitAndLoss(null);
    setBalanceSheet(null);
    setCashFlow(null);
    setARAging(null);
    setAPAging(null);
    setTaxLiability(null);
    setTaxSummary(null);
    setPayrollSummary(null);
    setBudgetVsActual(null);
    setAccountDrilldown(null);
    setAccountDrilldownLabel("");
    setReportError("");
  }

  return (
    <div className="stack">
      <section className="panel offline-panel">
        <div>
          <p className="eyebrow">Financial reports</p>
          <h3>Core statements</h3>
          <p>
            Run point-in-time, period, and GST reports from the double-entry ledger and tax postings.
            {reportSnapshot.savedAt && ` Last cached report set: ${new Date(reportSnapshot.savedAt).toLocaleString()}.`}
          </p>
        </div>
        {reportSnapshot.savedAt && (
          <div className="button-row">
            <button className="danger" onClick={clearCachedReports}>Clear cached reports</button>
          </div>
        )}
      </section>

      <form className="panel form-grid" onSubmit={loadTrialBalance}>
        <label>
          As of date
          <input type="date" value={asOf} onChange={(event) => setAsOf(event.target.value)} required />
        </label>
        <button disabled={loadingReport === "trial-balance"}>
          {loadingReport === "trial-balance" ? "Loading..." : "Run trial balance"}
        </button>
        <button className="secondary" type="button" disabled={loadingReport === "balance-sheet"} onClick={() => void loadBalanceSheet()}>
          {loadingReport === "balance-sheet" ? "Loading..." : "Run balance sheet"}
        </button>
        <button className="secondary" type="button" disabled={loadingReport === "ar-aging"} onClick={() => void loadARAging()}>
          {loadingReport === "ar-aging" ? "Loading..." : "Run AR aging"}
        </button>
        <button className="secondary" type="button" disabled={loadingReport === "ap-aging"} onClick={() => void loadAPAging()}>
          {loadingReport === "ap-aging" ? "Loading..." : "Run AP aging"}
        </button>
      </form>

      <form className="panel form-grid" onSubmit={loadProfitAndLoss}>
        <label>
          From date
          <input type="date" value={fromDate} onChange={(event) => setFromDate(event.target.value)} required />
        </label>
        <label>
          To date
          <input type="date" value={toDate} onChange={(event) => setToDate(event.target.value)} required />
        </label>
        <button disabled={loadingReport === "profit-and-loss"}>
          {loadingReport === "profit-and-loss" ? "Loading..." : "Run P&L"}
        </button>
        <button className="secondary" type="button" disabled={loadingReport === "cash-flow"} onClick={() => void loadCashFlow()}>
          {loadingReport === "cash-flow" ? "Loading..." : "Run cash flow"}
        </button>
        <button className="secondary" type="button" disabled={loadingReport === "tax-liability"} onClick={() => void loadTaxLiability()}>
          {loadingReport === "tax-liability" ? "Loading..." : "Run GST liability"}
        </button>
        <button className="secondary" type="button" disabled={loadingReport === "tax-summary"} onClick={() => void loadTaxSummary()}>
          {loadingReport === "tax-summary" ? "Loading..." : "Run GST summary"}
        </button>
        <button className="secondary" type="button" disabled={loadingReport === "payroll-summary"} onClick={() => void loadPayrollSummary()}>
          {loadingReport === "payroll-summary" ? "Loading..." : "Run payroll summary"}
        </button>
      </form>

      <form className="panel form-grid" onSubmit={loadBudgetVsActual}>
        <label>
          Budget
          <select value={selectedBudgetId} onChange={(event) => setSelectedBudgetId(event.target.value)} required>
            <option value="">Select budget</option>
            {budgets.map((budget) => (
              <option key={budget.id} value={budget.id}>
                {budget.name} ({budget.start_date.slice(0, 10)} to {budget.end_date.slice(0, 10)})
              </option>
            ))}
          </select>
        </label>
        <button className="secondary" type="button" disabled={loadingReport === "budgets"} onClick={() => void loadBudgets()}>
          {loadingReport === "budgets" ? "Loading..." : "Refresh budgets"}
        </button>
        <button disabled={!selectedBudgetId || loadingReport === "budget-vs-actual"}>
          {loadingReport === "budget-vs-actual" ? "Loading..." : "Run budget vs actual"}
        </button>
      </form>

      <form className="panel form-grid" onSubmit={createScheduledReport}>
        <label>
          Schedule name
          <input
            value={scheduledReportForm.name}
            onChange={(event) => setScheduledReportForm((current) => ({ ...current, name: event.target.value }))}
            required
          />
        </label>
        <label>
          Report type
          <select
            value={scheduledReportForm.report_type}
            onChange={(event) => setScheduledReportForm((current) => ({ ...current, report_type: event.target.value as CreateScheduledReportInput["report_type"] }))}
          >
            <option value="trial_balance">Trial balance</option>
            <option value="profit_and_loss">Profit and loss</option>
            <option value="balance_sheet">Balance sheet</option>
          </select>
        </label>
        <label>
          Frequency
          <select
            value={scheduledReportForm.frequency}
            onChange={(event) => setScheduledReportForm((current) => ({ ...current, frequency: event.target.value as CreateScheduledReportInput["frequency"] }))}
          >
            <option value="daily">Daily</option>
            <option value="weekly">Weekly</option>
            <option value="monthly">Monthly</option>
          </select>
        </label>
        <label>
          Next run
          <input
            type="date"
            value={scheduledReportForm.next_run_at.slice(0, 10)}
            onChange={(event) => setScheduledReportForm((current) => ({ ...current, next_run_at: event.target.value }))}
            required
          />
        </label>
        <label className="wide">
          Parameters JSON
          <textarea
            value={scheduledReportForm.parameters_json ?? ""}
            onChange={(event) => setScheduledReportForm((current) => ({ ...current, parameters_json: event.target.value }))}
            rows={3}
            placeholder='{"as_of_date":"2026-07-31"}'
          />
        </label>
        <label className="wide">
          Email recipients
          <textarea
            value={scheduledReportForm.email_recipients ?? ""}
            onChange={(event) => setScheduledReportForm((current) => ({ ...current, email_recipients: event.target.value }))}
            rows={2}
            placeholder="owner@example.com, accountant@example.com"
          />
        </label>
        <button disabled={loadingReport === "scheduled-reports"}>
          {loadingReport === "scheduled-reports" ? "Saving..." : "Create schedule"}
        </button>
        <button className="secondary" type="button" disabled={loadingReport === "scheduled-reports"} onClick={() => void loadScheduledReports()}>
          Refresh schedules
        </button>
      </form>

      {scheduledReports.length > 0 && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">Scheduled reports</p>
              <h3>{scheduledReports.length} recurring snapshots</h3>
              <p>Worker-created runs are stored as immutable JSON snapshots for later export and review.</p>
            </div>
            <strong>{scheduledReportRuns.length}</strong>
          </div>
          <div className="button-row">
            <select value={selectedScheduledReportId} onChange={(event) => setSelectedScheduledReportId(event.target.value)}>
              {scheduledReports.map((report) => (
                <option key={report.id} value={report.id}>{report.name}</option>
              ))}
            </select>
            <button className="secondary" disabled={!selectedScheduledReportId || loadingReport === "scheduled-runs"} onClick={() => void loadScheduledReportRuns()}>
              {loadingReport === "scheduled-runs" ? "Loading..." : "Load runs"}
            </button>
          </div>
          <DataTable
            headers={["Name", "Type", "Frequency", "Next run", "Last run", "Email", "Active"]}
            rows={scheduledReports.map((report) => [
              report.name,
              titleCase(report.report_type.replace(/_/g, " ")),
              titleCase(report.frequency),
              report.next_run_at.slice(0, 10),
              report.last_run_at ? report.last_run_at.slice(0, 10) : "-",
              report.email_recipients || "-",
              report.is_active ? "Yes" : "No"
            ])}
          />
          {scheduledReportRuns.length > 0 && (
            <DataTable
              headers={["Run", "Type", "Status", "Period", "Snapshot", "Error"]}
              rows={scheduledReportRuns.map((run) => [
                run.created_at ? new Date(run.created_at).toLocaleString() : run.id.slice(0, 8),
                titleCase(run.report_type.replace(/_/g, " ")),
                titleCase(run.status),
                run.as_of_date ? `As of ${run.as_of_date.slice(0, 10)}` : `${run.period_start?.slice(0, 10) ?? "-"} to ${run.period_end?.slice(0, 10) ?? "-"}`,
                run.report_json ? `${Math.round(run.report_json.length / 1024)} KB` : "-",
                run.error_message || "-"
              ])}
            />
          )}
        </section>
      )}

      {reportError && <div className="alert error">{reportError}</div>}
      {trialBalance && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">As of {trialBalance.as_of_date.slice(0, 10)}</p>
              <h3>{trialBalance.balanced ? "Ledger is balanced" : "Ledger is out of balance"}</h3>
              <p>
                Total debits {formatMinorAsInr(trialBalance.total_debit_minor)} and total credits {formatMinorAsInr(trialBalance.total_credit_minor)}.
              </p>
            </div>
            <strong>{trialBalance.rows.length}</strong>
          </div>
          <div className="button-row">
            <button className="secondary" onClick={() => exportTrialBalance(trialBalance)}>Export CSV</button>
            <button className="secondary" disabled={loadingReport === "report-pdf"} onClick={() => void downloadTrialBalancePDF()}>
              {loadingReport === "report-pdf" ? "Downloading..." : "Export PDF"}
            </button>
          </div>
          <DataTable
            headers={["Code", "Account", "Type", "Debit", "Credit", "Balance", "Detail"]}
            rows={trialBalance.rows.map((row) => [
              row.account_code,
              row.account_name,
              row.account_type,
              formatMinorAsInr(row.debit_minor),
              formatMinorAsInr(row.credit_minor),
              formatMinorAsInr(row.balance_minor),
              drilldownButton(row, fiscalYearStartFor(trialBalance.as_of_date.slice(0, 10)), trialBalance.as_of_date.slice(0, 10))
            ])}
          />
        </section>
      )}
      {profitAndLoss && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">
                {profitAndLoss.from_date.slice(0, 10)} to {profitAndLoss.to_date.slice(0, 10)}
              </p>
              <h3>Net income {formatMinorAsInr(profitAndLoss.net_income_minor)}</h3>
              <p>
                Income {formatMinorAsInr(profitAndLoss.total_income_minor)} less expenses {formatMinorAsInr(profitAndLoss.total_expense_minor)}.
              </p>
            </div>
            <strong>{profitAndLoss.income_rows.length + profitAndLoss.expense_rows.length}</strong>
          </div>
          <div className="button-row">
            <button className="secondary" onClick={() => exportProfitAndLoss(profitAndLoss)}>Export CSV</button>
            <button className="secondary" disabled={loadingReport === "report-pdf"} onClick={() => void downloadProfitAndLossPDF()}>
              {loadingReport === "report-pdf" ? "Downloading..." : "Export PDF"}
            </button>
          </div>
          <DataTable
            headers={["Section", "Code", "Account", "Amount", "Detail"]}
            rows={[
              ...profitAndLoss.income_rows.map((row) => [
                "Income",
                row.account_code,
                row.account_name,
                formatMinorAsInr(row.balance_minor),
                drilldownButton(row, profitAndLoss.from_date.slice(0, 10), profitAndLoss.to_date.slice(0, 10))
              ]),
              ...profitAndLoss.expense_rows.map((row) => [
                "Expense",
                row.account_code,
                row.account_name,
                formatMinorAsInr(row.balance_minor),
                drilldownButton(row, profitAndLoss.from_date.slice(0, 10), profitAndLoss.to_date.slice(0, 10))
              ])
            ]}
          />
        </section>
      )}
      {balanceSheet && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">As of {balanceSheet.as_of_date.slice(0, 10)}</p>
              <h3>{balanceSheet.balanced ? "Balance sheet balances" : "Balance sheet is out of balance"}</h3>
              <p>
                Assets {formatMinorAsInr(balanceSheet.total_assets_minor)} against liabilities {formatMinorAsInr(balanceSheet.total_liabilities_minor)}
                {" "}and equity {formatMinorAsInr(balanceSheet.total_equity_minor)}.
              </p>
            </div>
            <strong>{balanceSheet.asset_rows.length + balanceSheet.liability_rows.length + balanceSheet.equity_rows.length}</strong>
          </div>
          <div className="button-row">
            <button className="secondary" onClick={() => exportBalanceSheet(balanceSheet)}>Export CSV</button>
            <button className="secondary" disabled={loadingReport === "report-pdf"} onClick={() => void downloadBalanceSheetPDF()}>
              {loadingReport === "report-pdf" ? "Downloading..." : "Export PDF"}
            </button>
          </div>
          <DataTable
            headers={["Section", "Code", "Account", "Balance", "Detail"]}
            rows={[
              ...balanceSheet.asset_rows.map((row) => [
                "Assets",
                row.account_code,
                row.account_name,
                formatMinorAsInr(row.balance_minor),
                drilldownButton(row, fiscalYearStartFor(balanceSheet.as_of_date.slice(0, 10)), balanceSheet.as_of_date.slice(0, 10))
              ]),
              ...balanceSheet.liability_rows.map((row) => [
                "Liabilities",
                row.account_code,
                row.account_name,
                formatMinorAsInr(row.balance_minor),
                drilldownButton(row, fiscalYearStartFor(balanceSheet.as_of_date.slice(0, 10)), balanceSheet.as_of_date.slice(0, 10))
              ]),
              ...balanceSheet.equity_rows.map((row) => [
                "Equity",
                row.account_code,
                row.account_name,
                formatMinorAsInr(row.balance_minor),
                drilldownButton(row, fiscalYearStartFor(balanceSheet.as_of_date.slice(0, 10)), balanceSheet.as_of_date.slice(0, 10))
              ])
            ]}
          />
        </section>
      )}
      {cashFlow && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">
                {cashFlow.from_date.slice(0, 10)} to {cashFlow.to_date.slice(0, 10)}
              </p>
              <h3>Net cash flow {formatMinorAsInr(cashFlow.net_cash_flow_minor)}</h3>
              <p>
                Opening cash {formatMinorAsInr(cashFlow.opening_cash_minor)}, inflows {formatMinorAsInr(cashFlow.total_inflows_minor)},
                {" "}outflows {formatMinorAsInr(cashFlow.total_outflows_minor)}, closing cash {formatMinorAsInr(cashFlow.closing_cash_minor)}.
              </p>
            </div>
            <strong>{cashFlow.rows.length}</strong>
          </div>
          <div className="button-row">
            <button className="secondary" onClick={() => exportCashFlow(cashFlow)}>Export CSV</button>
          </div>
          <DataTable
            headers={["Code", "Cash account", "Source", "Inflows", "Outflows", "Net", "Detail"]}
            rows={cashFlow.rows.map((row) => [
              row.account_code,
              row.account_name,
              titleCase(row.source_module),
              formatMinorAsInr(row.inflow_minor),
              formatMinorAsInr(row.outflow_minor),
              formatMinorAsInr(row.net_cash_flow_minor),
              drilldownButton(row, cashFlow.from_date.slice(0, 10), cashFlow.to_date.slice(0, 10))
            ])}
          />
        </section>
      )}
      {arAging && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">As of {arAging.as_of_date.slice(0, 10)}</p>
              <h3>AR outstanding {formatMinorAsInr(arAging.total_outstanding_minor)}</h3>
              <p>
                Current {formatMinorAsInr(arAging.total_current_minor)}, 1-30 {formatMinorAsInr(arAging.total_one_to_thirty_minor)},
                {" "}31-60 {formatMinorAsInr(arAging.total_thirty_one_to_sixty_minor)}, 61-90 {formatMinorAsInr(arAging.total_sixty_one_to_ninety_minor)},
                {" "}90+ {formatMinorAsInr(arAging.total_over_ninety_minor)}.
              </p>
            </div>
            <strong>{arAging.rows.length}</strong>
          </div>
          <div className="button-row">
            <button className="secondary" onClick={() => exportARAging(arAging)}>Export CSV</button>
          </div>
          <DataTable
            headers={["Customer", "Invoice", "Due", "Days", "Current", "1-30", "31-60", "61-90", "90+", "Outstanding"]}
            rows={arAging.rows.map((row) => [
              row.customer_name,
              row.invoice_number,
              row.due_date.slice(0, 10),
              String(row.days_overdue),
              formatMinorAsInr(row.current_minor),
              formatMinorAsInr(row.one_to_thirty_minor),
              formatMinorAsInr(row.thirty_one_to_sixty_minor),
              formatMinorAsInr(row.sixty_one_to_ninety_minor),
              formatMinorAsInr(row.over_ninety_minor),
              formatMinorAsInr(row.outstanding_minor)
            ])}
          />
        </section>
      )}
      {apAging && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">As of {apAging.as_of_date.slice(0, 10)}</p>
              <h3>AP outstanding {formatMinorAsInr(apAging.total_outstanding_minor)}</h3>
              <p>
                Current {formatMinorAsInr(apAging.total_current_minor)}, 1-30 {formatMinorAsInr(apAging.total_one_to_thirty_minor)},
                {" "}31-60 {formatMinorAsInr(apAging.total_thirty_one_to_sixty_minor)}, 61-90 {formatMinorAsInr(apAging.total_sixty_one_to_ninety_minor)},
                {" "}90+ {formatMinorAsInr(apAging.total_over_ninety_minor)}.
              </p>
            </div>
            <strong>{apAging.rows.length}</strong>
          </div>
          <div className="button-row">
            <button className="secondary" onClick={() => exportAPAging(apAging)}>Export CSV</button>
          </div>
          <DataTable
            headers={["Vendor", "Bill", "Due", "Days", "Current", "1-30", "31-60", "61-90", "90+", "Outstanding"]}
            rows={apAging.rows.map((row) => [
              row.vendor_name,
              row.bill_number,
              row.due_date.slice(0, 10),
              String(row.days_overdue),
              formatMinorAsInr(row.current_minor),
              formatMinorAsInr(row.one_to_thirty_minor),
              formatMinorAsInr(row.thirty_one_to_sixty_minor),
              formatMinorAsInr(row.sixty_one_to_ninety_minor),
              formatMinorAsInr(row.over_ninety_minor),
              formatMinorAsInr(row.outstanding_minor)
            ])}
          />
        </section>
      )}
      {taxLiability && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">
                {taxLiability.from_date.slice(0, 10)} to {taxLiability.to_date.slice(0, 10)}
              </p>
              <h3>Net GST {formatMinorAsInr(taxLiability.net_payable_minor)}</h3>
              <p>
                Output GST {formatMinorAsInr(taxLiability.output_tax_minor)} less input GST {formatMinorAsInr(taxLiability.input_tax_minor)}.
              </p>
            </div>
            <strong>{taxLiability.rows.length}</strong>
          </div>
          <div className="button-row">
            <button className="secondary" onClick={() => exportTaxLiability(taxLiability)}>Export CSV</button>
          </div>
          <DataTable
            headers={["Tax", "Output", "Input", "Net payable"]}
            rows={taxLiability.rows.map((row) => [
              row.name,
              formatMinorAsInr(row.output_tax_minor),
              formatMinorAsInr(row.input_tax_minor),
              formatMinorAsInr(row.net_payable_minor)
            ])}
          />
        </section>
      )}
      {taxSummary && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">
                {taxSummary.from_date.slice(0, 10)} to {taxSummary.to_date.slice(0, 10)}
              </p>
              <h3>GST summary by rate/group</h3>
              <p>Use this filing-oriented breakdown to reconcile collected and paid GST before export workflows are added.</p>
            </div>
            <strong>{taxSummary.rows.length}</strong>
          </div>
          <div className="button-row">
            <button className="secondary" onClick={() => exportTaxSummary(taxSummary)}>Export CSV</button>
          </div>
          <DataTable
            headers={["Tax", "Output", "Input", "Net"]}
            rows={taxSummary.rows.map((row) => [
              row.name,
              formatMinorAsInr(row.output_tax_minor),
              formatMinorAsInr(row.input_tax_minor),
              formatMinorAsInr(row.net_payable_minor)
            ])}
          />
        </section>
      )}
      {payrollSummary && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">
                {payrollSummary.from_date.slice(0, 10)} to {payrollSummary.to_date.slice(0, 10)}
              </p>
              <h3>Payroll cost {formatMinorAsInr(payrollSummary.total_payroll_cost_minor)}</h3>
              <p>
                {payrollSummary.total_runs} posted runs, {payrollSummary.total_employees} employee payslips,
                net pay {formatMinorAsInr(payrollSummary.total_net_pay_minor)} and employer contributions {formatMinorAsInr(payrollSummary.total_employer_contributions_minor)}.
              </p>
            </div>
            <strong>{payrollSummary.rows.length}</strong>
          </div>
          <div className="button-row">
            <button className="secondary" onClick={() => void downloadPayrollSummaryCSV()}>Download summary CSV</button>
            {["TDS", "PF", "ESI", "PT"].map((component) => (
              <button key={component} className="secondary" onClick={() => void downloadPayrollStatutoryComponentCSV(component)}>
                Download {component} CSV
              </button>
            ))}
            <button className="secondary" onClick={() => exportPayrollSummary(payrollSummary)}>Export cached CSV</button>
          </div>
          <DataTable
            headers={["Run", "Pay date", "Employees", "Gross", "Deductions", "Net", "Employer", "Cost"]}
            rows={payrollSummary.rows.map((row) => [
              row.run_number,
              row.pay_date.slice(0, 10),
              String(row.employee_count),
              formatMinorAsInr(row.gross_pay_minor),
              formatMinorAsInr(row.deductions_minor),
              formatMinorAsInr(row.net_pay_minor),
              formatMinorAsInr(row.employer_contributions_minor),
              formatMinorAsInr(row.payroll_cost_minor)
            ])}
          />
        </section>
      )}
      {budgetVsActual && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">Budget {budgetVsActual.budget_id}</p>
              <h3>Budget vs actual</h3>
              <p>
                Total variance {formatMinorAsInr(totalBudgetVarianceMinor(budgetVsActual))} across {budgetVsActual.rows.length} budget lines.
              </p>
            </div>
            <strong>{budgetVsActual.rows.length}</strong>
          </div>
          <div className="button-row">
            <button className="secondary" onClick={() => exportBudgetVsActual(budgetVsActual)}>Export CSV</button>
          </div>
          <DataTable
            headers={["Code", "Account", "Period", "Budget", "Actual", "Variance", "Variance %", "Detail"]}
            rows={budgetVsActual.rows.map((row) => [
              row.account_code,
              row.account_name,
              `${row.period_start.slice(0, 10)} to ${row.period_end.slice(0, 10)}`,
              formatMinorAsInr(row.budget_minor),
              formatMinorAsInr(row.actual_minor),
              formatMinorAsInr(row.variance_minor),
              formatBasisPercent(row.variance_percent_basis),
              drilldownButton(row, row.period_start.slice(0, 10), row.period_end.slice(0, 10))
            ])}
          />
        </section>
      )}
      {accountDrilldown && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">
                {accountDrilldown.from_date.slice(0, 10)} to {accountDrilldown.to_date.slice(0, 10)}
              </p>
              <h3>{accountDrilldownLabel || `${accountDrilldown.account_code} · ${accountDrilldown.account_name}`}</h3>
              <p>
                Opening {formatMinorAsInr(accountDrilldown.opening_balance_minor)}, debits {formatMinorAsInr(accountDrilldown.total_debit_minor)},
                {" "}credits {formatMinorAsInr(accountDrilldown.total_credit_minor)}, closing {formatMinorAsInr(accountDrilldown.closing_balance_minor)}.
              </p>
            </div>
            <strong>{accountDrilldown.rows.length}</strong>
          </div>
          <div className="button-row">
            <button className="secondary" type="button" onClick={() => {
              setAccountDrilldown(null);
              setAccountDrilldownLabel("");
            }}>
              Clear drilldown
            </button>
          </div>
          <DataTable
            headers={["Date", "Source", "Document", "Transaction memo", "Split memo", "Debit", "Credit", "Running balance", "Status", "Open"]}
            rows={accountDrilldown.rows.map((row) => [
              row.transaction_date.slice(0, 10),
              titleCase(row.source_module),
              sourceDocumentLabel(row),
              row.transaction_memo || "-",
              row.split_memo || "-",
              formatMinorAsInr(row.debit_minor),
              formatMinorAsInr(row.credit_minor),
              formatMinorAsInr(row.balance_minor),
              row.reconciled ? "Reconciled" : row.cleared ? "Cleared" : "Open",
              sourceDocumentButton(row)
            ])}
          />
        </section>
      )}
    </div>
  );
}

function BudgetsPage({
  api,
  accounts,
  budgets,
  onBudgetsChanged,
  onRefresh
}: {
  api: ApiClient;
  accounts: Account[];
  budgets: Budget[];
  onBudgetsChanged: (budgets: Budget[]) => void;
  onRefresh: () => Promise<void>;
}) {
  const today = new Date().toISOString().slice(0, 10);
  const fiscalStart = `${today.slice(0, 4)}-04-01`;
  const fiscalEnd = `${Number(today.slice(0, 4)) + 1}-03-31`;
  const [budgetForm, setBudgetForm] = useState({
    name: "",
    start_date: fiscalStart,
    end_date: fiscalEnd,
    status: "active" as Budget["status"]
  });
  const [lineForm, setLineForm] = useState({
    account_id: accounts.find((account) => account.type === "income" || account.type === "expense")?.id ?? "",
    period_start: fiscalStart,
    period_end: fiscalEnd,
    amount_minor: 0
  });
  const [draftLines, setDraftLines] = useState<CreateBudgetInput["lines"]>([]);
  const [loading, setLoading] = useState("");
  const [budgetError, setBudgetError] = useState("");
  const [budgetNotice, setBudgetNotice] = useState("");
  const budgetAccounts = accounts.filter((account) => account.type === "income" || account.type === "expense");
  const canAddLine = Boolean(lineForm.account_id && lineForm.period_start && lineForm.period_end);
  const canCreateBudget = Boolean(budgetForm.name.trim() && budgetForm.start_date && budgetForm.end_date && draftLines.length > 0);

  async function refreshBudgets() {
    setLoading("refresh");
    setBudgetError("");
    try {
      const nextBudgets = await api.listBudgets();
      onBudgetsChanged(nextBudgets);
      setBudgetNotice(`Loaded ${nextBudgets.length} budget plan(s).`);
    } catch (error) {
      setBudgetError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  function addBudgetLine() {
    if (!canAddLine) {
      return;
    }
    setDraftLines([...draftLines, { ...lineForm }]);
    setLineForm({ ...lineForm, amount_minor: 0 });
    setBudgetNotice("Budget line staged locally.");
  }

  function removeBudgetLine(index: number) {
    setDraftLines(draftLines.filter((_, draftIndex) => draftIndex !== index));
    setBudgetNotice("Budget line removed.");
  }

  async function createBudget(event: FormEvent) {
    event.preventDefault();
    if (!canCreateBudget) {
      return;
    }
    setLoading("create");
    setBudgetError("");
    try {
      const budget = await api.createBudget(toBudgetInput(budgetForm, draftLines));
      onBudgetsChanged([budget, ...budgets]);
      setBudgetForm({ name: "", start_date: budgetForm.start_date, end_date: budgetForm.end_date, status: "active" });
      setDraftLines([]);
      setBudgetNotice(`Budget ${budget.name} created.`);
      await onRefresh();
    } catch (error) {
      setBudgetError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  function accountName(accountId: string) {
    const account = accounts.find((candidate) => candidate.id === accountId);
    return account ? `${account.code} · ${account.name}` : accountId;
  }

  return (
    <div className="stack">
      <section className="panel offline-panel">
        <div>
          <p className="eyebrow">Planning</p>
          <h3>Budget plans</h3>
          <p>Create account-period budgets that feed the budget-vs-actual report.</p>
        </div>
        <button className="secondary" disabled={loading === "refresh"} onClick={() => void refreshBudgets()}>
          {loading === "refresh" ? "Refreshing..." : "Refresh budgets"}
        </button>
      </section>

      {budgetError && <div className="alert error">{budgetError}</div>}
      {budgetNotice && <div className="alert success">{budgetNotice}</div>}

      <section className="panel form-grid">
        <AccountSelect label="Budget account" accounts={budgetAccounts} value={lineForm.account_id} onChange={(value) => setLineForm({ ...lineForm, account_id: value })} />
        <label>
          Period start
          <input type="date" value={lineForm.period_start} onChange={(event) => setLineForm({ ...lineForm, period_start: event.target.value })} />
        </label>
        <label>
          Period end
          <input type="date" value={lineForm.period_end} onChange={(event) => setLineForm({ ...lineForm, period_end: event.target.value })} />
        </label>
        <label>
          Amount minor
          <input type="number" value={lineForm.amount_minor} onChange={(event) => setLineForm({ ...lineForm, amount_minor: Number(event.target.value) })} />
        </label>
        <button type="button" disabled={!canAddLine} onClick={addBudgetLine}>Stage budget line</button>
      </section>

      <form className="panel queue-panel" onSubmit={createBudget}>
        <div className="queue-heading">
          <div>
            <p className="eyebrow">Draft budget</p>
            <h3>Create budget</h3>
            <p>Stage one or more account-period lines, then save the plan for reporting.</p>
          </div>
          <strong>{draftLines.length}</strong>
        </div>
        <div className="form-grid">
          <input placeholder="Budget name" value={budgetForm.name} onChange={(event) => setBudgetForm({ ...budgetForm, name: event.target.value })} />
          <label>
            Start date
            <input type="date" value={budgetForm.start_date} onChange={(event) => setBudgetForm({ ...budgetForm, start_date: event.target.value })} />
          </label>
          <label>
            End date
            <input type="date" value={budgetForm.end_date} onChange={(event) => setBudgetForm({ ...budgetForm, end_date: event.target.value })} />
          </label>
          <label>
            Status
            <select value={budgetForm.status} onChange={(event) => setBudgetForm({ ...budgetForm, status: event.target.value as Budget["status"] })}>
              <option value="draft">Draft</option>
              <option value="active">Active</option>
              <option value="closed">Closed</option>
            </select>
          </label>
        </div>
        <section className="table-panel">
          <table>
            <thead>
              <tr>
                <th>Account</th>
                <th>Period</th>
                <th>Budget</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {draftLines.map((line, index) => (
                <tr key={`${line.account_id}-${line.period_start}-${index}`}>
                  <td>{accountName(line.account_id)}</td>
                  <td>{line.period_start} to {line.period_end}</td>
                  <td>{formatMinorAsInr(line.amount_minor ?? 0)}</td>
                  <td><button className="danger compact" type="button" onClick={() => removeBudgetLine(index)}>Remove</button></td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
        <button disabled={!canCreateBudget || loading === "create"}>{loading === "create" ? "Creating..." : "Create budget"}</button>
      </form>

      <section className="panel queue-panel">
        <div className="queue-heading">
          <div>
            <p className="eyebrow">Budget catalog</p>
            <h3>Saved budgets</h3>
            <p>Budget metadata and lines are cached locally for offline review.</p>
          </div>
          <strong>{budgets.length}</strong>
        </div>
        <section className="table-panel">
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Period</th>
                <th>Status</th>
                <th>Lines</th>
                <th>Total</th>
              </tr>
            </thead>
            <tbody>
              {budgets.map((budget) => (
                <tr key={budget.id}>
                  <td>{budget.name}</td>
                  <td>{budget.start_date.slice(0, 10)} to {budget.end_date.slice(0, 10)}</td>
                  <td>{budget.status}</td>
                  <td>{budget.lines?.length ?? 0}</td>
                  <td>{formatMinorAsInr(totalBudgetMinor(budget))}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      </section>
    </div>
  );
}

function InvestmentsPage({
  api,
  accounts,
  investmentLots,
  onInvestmentLotsChanged,
  investmentDividends,
  onInvestmentDividendsChanged,
  investmentCorporateActions,
  onInvestmentCorporateActionsChanged,
  onRefresh
}: {
  api: ApiClient;
  accounts: Account[];
  investmentLots: InvestmentLot[];
  onInvestmentLotsChanged: (lots: InvestmentLot[]) => void;
  investmentDividends: InvestmentDividend[];
  onInvestmentDividendsChanged: (dividends: InvestmentDividend[]) => void;
  investmentCorporateActions: InvestmentCorporateAction[];
  onInvestmentCorporateActionsChanged: (actions: InvestmentCorporateAction[]) => void;
  onRefresh: () => Promise<void>;
}) {
  const today = new Date().toISOString().slice(0, 10);
  const fiscalStart = `${today.slice(0, 4)}-04-01`;
  const investmentAccounts = accounts.filter((account) => account.type === "asset");
  const cachedReports = useMemo(() => loadReportSnapshot(), []);
  const [lotForm, setLotForm] = useState({
    account_id: investmentAccounts[0]?.id ?? "",
    symbol: "",
    security_name: "",
    acquisition_date: today,
    quantity_millis: 1000,
    cost_basis_minor: 0,
    currency: "INR",
    cost_method: "specific_lot" as InvestmentLot["cost_method"],
    notes: ""
  });
  const [saleForm, setSaleForm] = useState({
    lot_id: "",
    sale_date: today,
    quantity_millis: 1000,
    proceeds_minor: 0,
    proceeds_account_id: investmentAccounts[0]?.id ?? "",
    gain_loss_account_id: accounts.find((account) => account.type === "income" || account.type === "expense")?.id ?? "",
    notes: ""
  });
  const [dividendForm, setDividendForm] = useState({
    account_id: investmentAccounts[0]?.id ?? "",
    symbol: "",
    dividend_date: today,
    amount_minor: 0,
    currency: "INR",
    cash_account_id: investmentAccounts[0]?.id ?? "",
    income_account_id: accounts.find((account) => account.type === "income")?.id ?? "",
    notes: ""
  });
  const [corporateActionForm, setCorporateActionForm] = useState({
    account_id: investmentAccounts[0]?.id ?? "",
    symbol: "",
    action_type: "split" as InvestmentCorporateAction["action_type"],
    action_date: today,
    ratio_numerator: 2,
    ratio_denominator: 1,
    notes: ""
  });
  const [priceImportForm, setPriceImportForm] = useState({
    format: "csv" as InvestmentPriceImportFormat,
    source: "csv_import",
    symbol: "",
    symbol_mode: "scheme_code" as ImportAMFINAVInput["symbol_mode"],
    csv: "symbol,price_date,price_minor,currency\nNIFTYBEES,2026-07-31,7200,INR"
  });
  const [reportFrom, setReportFrom] = useState(fiscalStart);
  const [reportTo, setReportTo] = useState(today);
  const [taxAdjustmentWindowDays, setTaxAdjustmentWindowDays] = useState(30);
  const [realizedGains, setRealizedGains] = useState<RealizedGainsReport | null>(() => cachedReports?.realizedGains ?? null);
  const [dividendReport, setDividendReport] = useState<InvestmentDividendReport | null>(() => cachedReports?.investmentDividends ?? null);
  const [corporateActionReport, setCorporateActionReport] = useState<InvestmentCorporateActionReport | null>(null);
  const [taxAdjustmentReport, setTaxAdjustmentReport] = useState<InvestmentTaxAdjustmentReport | null>(null);
  const [taxLotReport, setTaxLotReport] = useState<InvestmentTaxLotReport | null>(() => cachedReports?.investmentTaxLots ?? null);
  const [loading, setLoading] = useState("");
  const [investmentError, setInvestmentError] = useState("");
  const [investmentNotice, setInvestmentNotice] = useState("");
  const openLots = investmentLots.filter((lot) => lot.remaining_quantity_millis > 0);
  const totalCostBasis = investmentLots.reduce((total, lot) => total + lot.cost_basis_minor, 0);
  const totalRemainingQuantity = investmentLots.reduce((total, lot) => total + lot.remaining_quantity_millis, 0);
  const canCreateLot = Boolean(lotForm.account_id && lotForm.symbol.trim() && lotForm.acquisition_date && lotForm.quantity_millis > 0 && lotForm.cost_basis_minor > 0);
  const canSellLot = Boolean(saleForm.lot_id && saleForm.sale_date && saleForm.quantity_millis > 0 && saleForm.proceeds_minor > 0);
  const canCreateDividend = Boolean(dividendForm.account_id && dividendForm.symbol.trim() && dividendForm.dividend_date && dividendForm.amount_minor > 0);
  const canCreateCorporateAction = Boolean(corporateActionForm.account_id && corporateActionForm.symbol.trim() && corporateActionForm.action_date && corporateActionForm.ratio_numerator > 0 && corporateActionForm.ratio_denominator > 0);
  const canImportPrices = Boolean(priceImportForm.csv.trim());
  const priceImportMetadata = investmentPriceImportMetadata(priceImportForm.format);

  async function refreshLots() {
    setLoading("refresh");
    setInvestmentError("");
    try {
      const lots = await api.listInvestmentLots();
      onInvestmentLotsChanged(lots);
      setInvestmentNotice(`Loaded ${lots.length} investment lot(s).`);
    } catch (error) {
      setInvestmentError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function refreshDividends() {
    setLoading("refresh-dividends");
    setInvestmentError("");
    try {
      const dividends = await api.listInvestmentDividends();
      onInvestmentDividendsChanged(dividends);
      setInvestmentNotice(`Loaded ${dividends.length} dividend(s).`);
    } catch (error) {
      setInvestmentError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function refreshCorporateActions() {
    setLoading("refresh-actions");
    setInvestmentError("");
    try {
      const actions = await api.listInvestmentCorporateActions();
      onInvestmentCorporateActionsChanged(actions);
      setInvestmentNotice(`Loaded ${actions.length} corporate action(s).`);
    } catch (error) {
      setInvestmentError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function createLot(event: FormEvent) {
    event.preventDefault();
    if (!canCreateLot) {
      return;
    }
    setLoading("create-lot");
    setInvestmentError("");
    try {
      const lot = await api.createInvestmentLot(toInvestmentLotInput(lotForm));
      onInvestmentLotsChanged([lot, ...investmentLots]);
      setLotForm({ ...lotForm, symbol: "", security_name: "", quantity_millis: 1000, cost_basis_minor: 0, notes: "" });
      setInvestmentNotice(`Created lot for ${lot.symbol}.`);
      await onRefresh();
    } catch (error) {
      setInvestmentError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function sellLot(event: FormEvent) {
    event.preventDefault();
    if (!canSellLot) {
      return;
    }
    setLoading("sell-lot");
    setInvestmentError("");
    try {
      const disposition = await api.sellInvestmentLot(saleForm.lot_id, toSellInvestmentLotInput(saleForm));
      const lots = await api.listInvestmentLots();
      onInvestmentLotsChanged(lots);
      setSaleForm({ ...saleForm, lot_id: "", quantity_millis: 1000, proceeds_minor: 0, notes: "" });
      setInvestmentNotice(`Recorded sale with realized gain/loss ${formatMinorAsInr(disposition.realized_gain_loss_minor)}${disposition.journal_transaction_id ? " and posted it to the ledger" : ""}.`);
      await onRefresh();
    } catch (error) {
      setInvestmentError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function createDividend(event: FormEvent) {
    event.preventDefault();
    if (!canCreateDividend) {
      return;
    }
    setLoading("create-dividend");
    setInvestmentError("");
    try {
      const dividend = await api.createInvestmentDividend(toInvestmentDividendInput(dividendForm));
      onInvestmentDividendsChanged([dividend, ...investmentDividends]);
      setDividendForm({ ...dividendForm, symbol: "", amount_minor: 0, notes: "" });
      setInvestmentNotice(`Recorded dividend ${formatMinorAsInr(dividend.amount_minor)} for ${dividend.symbol}${dividend.journal_transaction_id ? " and posted it to the ledger" : ""}.`);
      await onRefresh();
    } catch (error) {
      setInvestmentError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function createCorporateAction(event: FormEvent) {
    event.preventDefault();
    if (!canCreateCorporateAction) {
      return;
    }
    setLoading("create-action");
    setInvestmentError("");
    try {
      const action = await api.createInvestmentCorporateAction(toInvestmentCorporateActionInput(corporateActionForm));
      onInvestmentCorporateActionsChanged([action, ...investmentCorporateActions]);
      setCorporateActionForm({ ...corporateActionForm, symbol: "", notes: "" });
      setInvestmentNotice(`Applied ${titleCase(action.action_type)} to ${action.affected_lots} lot(s), changing open quantity by ${formatQuantityMillis(action.quantity_delta_millis)}.`);
      await onRefresh();
    } catch (error) {
      setInvestmentError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function importPrices(event: FormEvent) {
    event.preventDefault();
    if (!canImportPrices) {
      return;
    }
    setLoading("import-prices");
    setInvestmentError("");
    try {
      const importInput = toImportInvestmentPricesInput({
        ...priceImportForm,
        source: priceImportForm.source || priceImportMetadata.defaultSource
      });
      let result: InvestmentPriceImportResult;
      switch (priceImportForm.format) {
        case "amfi":
          result = await api.importAMFINAV(toImportAMFINAVInput(priceImportForm));
          break;
        case "nse":
          result = await api.importNSEEquityPrices(importInput);
          break;
        case "bse":
          result = await api.importBSEEquityPrices(importInput);
          break;
        case "yahoo":
          result = await api.importYahooFinancePrices(importInput);
          break;
        case "alphavantage":
          result = await api.importAlphaVantagePrices(importInput);
          break;
        case "broker":
          result = await api.importBrokerHoldingsPrices(importInput);
          break;
        case "zerodha":
          result = await api.importZerodhaHoldingsPrices(importInput);
          break;
        case "groww":
          result = await api.importGrowwHoldingsPrices(importInput);
          break;
        case "upstox":
          result = await api.importUpstoxHoldingsPrices(importInput);
          break;
        case "angelone":
          result = await api.importAngelOneHoldingsPrices(importInput);
          break;
        case "dhan":
          result = await api.importDhanHoldingsPrices(importInput);
          break;
        case "icicidirect":
          result = await api.importICICIDirectHoldingsPrices(importInput);
          break;
        case "hdfcsky":
          result = await api.importHDFCSkyHoldingsPrices(importInput);
          break;
        case "kotakneo":
          result = await api.importKotakNeoHoldingsPrices(importInput);
          break;
        case "paytmmoney":
          result = await api.importPaytmMoneyHoldingsPrices(importInput);
          break;
        case "motilaloswal":
          result = await api.importMotilalOswalHoldingsPrices(importInput);
          break;
        default:
          result = await api.importInvestmentPrices(importInput);
      }
      const suffix = result.errors.length > 0 ? ` ${result.errors.length} row issue(s) need review.` : "";
      setInvestmentNotice(`Imported ${result.imported} price row(s), skipped ${result.skipped}.${suffix}`);
      await onRefresh();
    } catch (error) {
      setInvestmentError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function loadRealizedGains(event?: FormEvent) {
    event?.preventDefault();
    setLoading("realized-gains");
    setInvestmentError("");
    try {
      const report = await api.getRealizedGains(reportFrom, reportTo);
      setRealizedGains(report);
      const snapshot = loadReportSnapshot() ?? { savedAt: "" };
      saveReportSnapshot({ ...snapshot, realizedGains: report, savedAt: new Date().toISOString() });
      setInvestmentNotice(`Loaded realized gains report with ${report.rows.length} disposition(s).`);
    } catch (error) {
      setInvestmentError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function loadDividendReport(event?: FormEvent) {
    event?.preventDefault();
    setLoading("dividend-report");
    setInvestmentError("");
    try {
      const report = await api.getInvestmentDividends(reportFrom, reportTo);
      setDividendReport(report);
      const snapshot = loadReportSnapshot() ?? { savedAt: "" };
      saveReportSnapshot({ ...snapshot, investmentDividends: report, savedAt: new Date().toISOString() });
      setInvestmentNotice(`Loaded dividend report with ${report.rows.length} dividend(s).`);
    } catch (error) {
      setInvestmentError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function loadTaxLotReport() {
    setLoading("tax-lots");
    setInvestmentError("");
    try {
      const report = await api.getInvestmentTaxLots(reportTo);
      setTaxLotReport(report);
      const snapshot = loadReportSnapshot() ?? { savedAt: "" };
      saveReportSnapshot({ ...snapshot, investmentTaxLots: report, savedAt: new Date().toISOString() });
      setInvestmentNotice(`Loaded tax-lot report with ${report.rows.length} lot(s).`);
    } catch (error) {
      setInvestmentError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function loadTaxAdjustmentReport() {
    setLoading("tax-adjustments");
    setInvestmentError("");
    try {
      const report = await api.getInvestmentTaxAdjustments(reportFrom, reportTo, taxAdjustmentWindowDays);
      setTaxAdjustmentReport(report);
      setInvestmentNotice(`Loaded tax adjustment report with ${report.rows.length} candidate adjustment(s).`);
    } catch (error) {
      setInvestmentError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function loadCorporateActionReport() {
    setLoading("corporate-action-report");
    setInvestmentError("");
    try {
      const report = await api.getInvestmentCorporateActions(reportFrom, reportTo);
      setCorporateActionReport(report);
      setInvestmentNotice(`Loaded corporate-action report with ${report.total_actions} action(s).`);
    } catch (error) {
      setInvestmentError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function downloadCorporateActionReportCSV() {
    setLoading("corporate-action-csv");
    setInvestmentError("");
    try {
      const download = await api.downloadInvestmentCorporateActionsCSV(reportFrom, reportTo);
      downloadBlob(download.filename, download.blob);
      setInvestmentNotice("Downloaded corporate-action report CSV.");
    } catch (error) {
      setInvestmentError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  function accountName(accountId: string) {
    const account = accounts.find((candidate) => candidate.id === accountId);
    return account ? `${account.code} · ${account.name}` : accountId;
  }

  return (
    <div className="stack">
      <section className="panel offline-panel">
        <div>
          <p className="eyebrow">Investment lots</p>
          <h3>Specific-lot capital gains</h3>
          <p>
            Cached locally: {investmentLots.length} lots, {openLots.length} still open, {formatQuantityMillis(totalRemainingQuantity)} units remaining,
            with original cost basis {formatMinorAsInr(totalCostBasis)}.
          </p>
        </div>
        <button className="secondary" disabled={loading === "refresh"} onClick={() => void refreshLots()}>
          {loading === "refresh" ? "Refreshing..." : "Refresh lots"}
        </button>
        <button className="secondary" disabled={loading === "refresh-dividends"} onClick={() => void refreshDividends()}>
          {loading === "refresh-dividends" ? "Refreshing..." : "Refresh dividends"}
        </button>
        <button className="secondary" disabled={loading === "refresh-actions"} onClick={() => void refreshCorporateActions()}>
          {loading === "refresh-actions" ? "Refreshing..." : "Refresh actions"}
        </button>
      </section>

      {investmentError && <div className="alert error">{investmentError}</div>}
      {investmentNotice && <div className="alert success">{investmentNotice}</div>}

      <form className="panel form-grid" onSubmit={createLot}>
        <AccountSelect label="Investment account" accounts={investmentAccounts} value={lotForm.account_id} onChange={(value) => setLotForm({ ...lotForm, account_id: value })} />
        <input placeholder="Symbol" value={lotForm.symbol} onChange={(event) => setLotForm({ ...lotForm, symbol: event.target.value.toUpperCase() })} />
        <input placeholder="Security name" value={lotForm.security_name} onChange={(event) => setLotForm({ ...lotForm, security_name: event.target.value })} />
        <label>
          Acquisition date
          <input type="date" value={lotForm.acquisition_date} onChange={(event) => setLotForm({ ...lotForm, acquisition_date: event.target.value })} />
        </label>
        <label>
          Quantity x1000
          <input type="number" min={1} value={lotForm.quantity_millis} onChange={(event) => setLotForm({ ...lotForm, quantity_millis: Number(event.target.value) })} />
        </label>
        <label>
          Cost basis minor
          <input type="number" min={1} value={lotForm.cost_basis_minor} onChange={(event) => setLotForm({ ...lotForm, cost_basis_minor: Number(event.target.value) })} />
        </label>
        <input maxLength={3} value={lotForm.currency} onChange={(event) => setLotForm({ ...lotForm, currency: event.target.value.toUpperCase() })} />
        <label>
          Cost method
          <select value={lotForm.cost_method} onChange={(event) => setLotForm({ ...lotForm, cost_method: event.target.value as InvestmentLot["cost_method"] })}>
            <option value="specific_lot">Specific lot</option>
            <option value="average_cost">Average cost</option>
          </select>
        </label>
        <input placeholder="Notes" value={lotForm.notes} onChange={(event) => setLotForm({ ...lotForm, notes: event.target.value })} />
        <button disabled={!canCreateLot || loading === "create-lot"}>{loading === "create-lot" ? "Creating..." : "Create lot"}</button>
      </form>

      <form className="panel form-grid" onSubmit={sellLot}>
        <label>
          Lot to sell
          <select value={saleForm.lot_id} onChange={(event) => setSaleForm({ ...saleForm, lot_id: event.target.value })} required>
            <option value="">Select open lot</option>
            {openLots.map((lot) => (
              <option key={lot.id} value={lot.id}>
                {lot.symbol} · {formatQuantityMillis(lot.remaining_quantity_millis)} remaining · {lot.acquisition_date.slice(0, 10)}
              </option>
            ))}
          </select>
        </label>
        <label>
          Sale date
          <input type="date" value={saleForm.sale_date} onChange={(event) => setSaleForm({ ...saleForm, sale_date: event.target.value })} />
        </label>
        <label>
          Quantity x1000
          <input type="number" min={1} value={saleForm.quantity_millis} onChange={(event) => setSaleForm({ ...saleForm, quantity_millis: Number(event.target.value) })} />
        </label>
        <label>
          Proceeds minor
          <input type="number" min={1} value={saleForm.proceeds_minor} onChange={(event) => setSaleForm({ ...saleForm, proceeds_minor: Number(event.target.value) })} />
        </label>
        <AccountSelect label="Proceeds account" accounts={accounts.filter((account) => account.type === "asset")} value={saleForm.proceeds_account_id} onChange={(value) => setSaleForm({ ...saleForm, proceeds_account_id: value })} />
        <AccountSelect label="Gain/loss account" accounts={accounts.filter((account) => account.type === "income" || account.type === "expense")} value={saleForm.gain_loss_account_id} onChange={(value) => setSaleForm({ ...saleForm, gain_loss_account_id: value })} />
        <input placeholder="Sale notes" value={saleForm.notes} onChange={(event) => setSaleForm({ ...saleForm, notes: event.target.value })} />
        <button disabled={!canSellLot || loading === "sell-lot"}>{loading === "sell-lot" ? "Recording..." : "Record sale"}</button>
      </form>

      <form className="panel form-grid" onSubmit={createDividend}>
        <AccountSelect label="Investment account" accounts={investmentAccounts} value={dividendForm.account_id} onChange={(value) => setDividendForm({ ...dividendForm, account_id: value })} />
        <input placeholder="Dividend symbol" value={dividendForm.symbol} onChange={(event) => setDividendForm({ ...dividendForm, symbol: event.target.value.toUpperCase() })} />
        <label>
          Dividend date
          <input type="date" value={dividendForm.dividend_date} onChange={(event) => setDividendForm({ ...dividendForm, dividend_date: event.target.value })} />
        </label>
        <label>
          Amount minor
          <input type="number" min={1} value={dividendForm.amount_minor} onChange={(event) => setDividendForm({ ...dividendForm, amount_minor: Number(event.target.value) })} />
        </label>
        <input maxLength={3} value={dividendForm.currency} onChange={(event) => setDividendForm({ ...dividendForm, currency: event.target.value.toUpperCase() })} />
        <AccountSelect label="Cash account" accounts={accounts.filter((account) => account.type === "asset")} value={dividendForm.cash_account_id} onChange={(value) => setDividendForm({ ...dividendForm, cash_account_id: value })} />
        <AccountSelect label="Dividend income account" accounts={accounts.filter((account) => account.type === "income")} value={dividendForm.income_account_id} onChange={(value) => setDividendForm({ ...dividendForm, income_account_id: value })} />
        <input placeholder="Dividend notes" value={dividendForm.notes} onChange={(event) => setDividendForm({ ...dividendForm, notes: event.target.value })} />
        <button disabled={!canCreateDividend || loading === "create-dividend"}>{loading === "create-dividend" ? "Recording..." : "Record dividend"}</button>
      </form>

      <form className="panel form-grid" onSubmit={createCorporateAction}>
        <AccountSelect label="Investment account" accounts={investmentAccounts} value={corporateActionForm.account_id} onChange={(value) => setCorporateActionForm({ ...corporateActionForm, account_id: value })} />
        <input placeholder="Action symbol" value={corporateActionForm.symbol} onChange={(event) => setCorporateActionForm({ ...corporateActionForm, symbol: event.target.value.toUpperCase() })} />
        <label>
          Action type
          <select value={corporateActionForm.action_type} onChange={(event) => setCorporateActionForm({ ...corporateActionForm, action_type: event.target.value as InvestmentCorporateAction["action_type"] })}>
            <option value="split">Stock split</option>
            <option value="bonus">Bonus issue</option>
          </select>
        </label>
        <label>
          Action date
          <input type="date" value={corporateActionForm.action_date} onChange={(event) => setCorporateActionForm({ ...corporateActionForm, action_date: event.target.value })} />
        </label>
        <label>
          Ratio numerator
          <input type="number" min={1} value={corporateActionForm.ratio_numerator} onChange={(event) => setCorporateActionForm({ ...corporateActionForm, ratio_numerator: Number(event.target.value) })} />
        </label>
        <label>
          Ratio denominator
          <input type="number" min={1} value={corporateActionForm.ratio_denominator} onChange={(event) => setCorporateActionForm({ ...corporateActionForm, ratio_denominator: Number(event.target.value) })} />
        </label>
        <input placeholder="Action notes" value={corporateActionForm.notes} onChange={(event) => setCorporateActionForm({ ...corporateActionForm, notes: event.target.value })} />
        <button disabled={!canCreateCorporateAction || loading === "create-action"}>{loading === "create-action" ? "Applying..." : "Apply corporate action"}</button>
      </form>

      <form className="panel form-grid" onSubmit={importPrices}>
        <label>
          Price feed format
          <select
            value={priceImportForm.format}
            onChange={(event) => {
              const format = event.target.value as InvestmentPriceImportFormat;
              const source = nextInvestmentPriceImportSource(priceImportForm.source, format);
              setPriceImportForm({
                ...priceImportForm,
                format,
                source
              });
            }}
          >
            {investmentPriceImportFormats.map((format) => (
              <option key={format} value={format}>{investmentPriceImportMetadata(format).label}</option>
            ))}
          </select>
        </label>
        {!priceImportMetadata.isAMFI ? (
          <>
            <input placeholder="Price import source" value={priceImportForm.source} onChange={(event) => setPriceImportForm({ ...priceImportForm, source: event.target.value })} />
            {priceImportMetadata.requiresSingleSymbol && (
              <input placeholder="Symbol for single-symbol feed" value={priceImportForm.symbol} onChange={(event) => setPriceImportForm({ ...priceImportForm, symbol: event.target.value.toUpperCase() })} />
            )}
          </>
        ) : (
          <label>
            AMFI symbol mapping
            <select value={priceImportForm.symbol_mode} onChange={(event) => setPriceImportForm({ ...priceImportForm, symbol_mode: event.target.value as ImportAMFINAVInput["symbol_mode"] })}>
              <option value="scheme_code">Scheme code</option>
              <option value="isin_growth">Growth ISIN</option>
              <option value="scheme_name">Scheme name</option>
            </select>
          </label>
        )}
        <label className="full-span">
          {priceImportMetadata.label}
          <textarea
            rows={5}
            value={priceImportForm.csv}
            onChange={(event) => setPriceImportForm({ ...priceImportForm, csv: event.target.value })}
            placeholder={priceImportMetadata.placeholder}
          />
        </label>
        <button disabled={!canImportPrices || loading === "import-prices"}>{loading === "import-prices" ? "Importing..." : priceImportMetadata.buttonLabel}</button>
      </form>

      <DataTable
        headers={["Symbol", "Security", "Account", "Acquired", "Qty", "Remaining", "Cost", "Method"]}
        rows={investmentLots.map((lot) => [
          lot.symbol,
          lot.security_name ?? "",
          accountName(lot.account_id),
          lot.acquisition_date.slice(0, 10),
          formatQuantityMillis(lot.quantity_millis),
          formatQuantityMillis(lot.remaining_quantity_millis),
          formatMinorAsInr(lot.cost_basis_minor),
          titleCase(lot.cost_method)
        ])}
      />

      <DataTable
        headers={["Date", "Symbol", "Account", "Amount", "Currency", "Posted"]}
        rows={investmentDividends.map((dividend) => [
          dividend.dividend_date.slice(0, 10),
          dividend.symbol,
          accountName(dividend.account_id),
          formatMinorAsInr(dividend.amount_minor),
          dividend.currency,
          dividend.journal_transaction_id ? "Yes" : "No"
        ])}
      />

      <DataTable
        headers={["Date", "Symbol", "Type", "Ratio", "Affected lots", "Qty delta", "Cost delta"]}
        rows={investmentCorporateActions.map((action) => [
          action.action_date.slice(0, 10),
          action.symbol,
          titleCase(action.action_type),
          `${action.ratio_numerator}:${action.ratio_denominator}`,
          String(action.affected_lots),
          formatQuantityMillis(action.quantity_delta_millis),
          formatMinorAsInr(action.cost_basis_delta_minor)
        ])}
      />

      <form className="panel form-grid" onSubmit={loadRealizedGains}>
        <label>
          From date
          <input type="date" value={reportFrom} onChange={(event) => setReportFrom(event.target.value)} required />
        </label>
        <label>
          To date
          <input type="date" value={reportTo} onChange={(event) => setReportTo(event.target.value)} required />
        </label>
        <label>
          Tax window days
          <input type="number" min={1} value={taxAdjustmentWindowDays} onChange={(event) => setTaxAdjustmentWindowDays(Number(event.target.value))} />
        </label>
        <button disabled={loading === "realized-gains"}>{loading === "realized-gains" ? "Loading..." : "Run realized gains"}</button>
        <button className="secondary" type="button" disabled={loading === "dividend-report"} onClick={() => void loadDividendReport()}>
          {loading === "dividend-report" ? "Loading..." : "Run dividend report"}
        </button>
        <button className="secondary" type="button" disabled={loading === "tax-adjustments"} onClick={() => void loadTaxAdjustmentReport()}>
          {loading === "tax-adjustments" ? "Loading..." : "Run tax adjustments"}
        </button>
        <button className="secondary" type="button" disabled={loading === "tax-lots"} onClick={() => void loadTaxLotReport()}>
          {loading === "tax-lots" ? "Loading..." : "Run tax lots"}
        </button>
        <button className="secondary" type="button" disabled={loading === "corporate-action-report"} onClick={() => void loadCorporateActionReport()}>
          {loading === "corporate-action-report" ? "Loading..." : "Run action report"}
        </button>
      </form>

      {realizedGains && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">{realizedGains.from_date.slice(0, 10)} to {realizedGains.to_date.slice(0, 10)}</p>
              <h3>Realized gain/loss {formatMinorAsInr(realizedGains.total_gain_loss_minor)}</h3>
              <p>Proceeds {formatMinorAsInr(realizedGains.total_proceeds_minor)} less cost basis {formatMinorAsInr(realizedGains.total_cost_basis_minor)}.</p>
            </div>
            <button className="secondary" onClick={() => exportRealizedGains(realizedGains)}>Export CSV</button>
          </div>
          <DataTable
            headers={["Sale date", "Lot", "Qty", "Proceeds", "Cost basis", "Gain/Loss", "Currency"]}
            rows={realizedGains.rows.map((row) => [
              row.sale_date.slice(0, 10),
              row.investment_lot_id,
              formatQuantityMillis(row.quantity_millis),
              formatMinorAsInr(row.proceeds_minor),
              formatMinorAsInr(row.allocated_cost_basis_minor),
              formatMinorAsInr(row.realized_gain_loss_minor),
              row.currency
            ])}
          />
        </section>
      )}
      {taxAdjustmentReport && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">{taxAdjustmentReport.from_date.slice(0, 10)} to {taxAdjustmentReport.to_date.slice(0, 10)} · {taxAdjustmentReport.window_days}-day window</p>
              <h3>Potential deferred loss {formatMinorAsInr(taxAdjustmentReport.total_deferred_loss_minor)}</h3>
              <p>{taxAdjustmentReport.rows.length} loss repurchase candidate(s), replacement quantity {formatQuantityMillis(taxAdjustmentReport.total_replacement_quantity_millis)}.</p>
            </div>
            <button className="secondary" onClick={() => exportInvestmentTaxAdjustments(taxAdjustmentReport)}>Export CSV</button>
          </div>
          <DataTable
            headers={["Sale date", "Symbol", "Sold qty", "Loss", "Replacement qty", "Deferred loss", "Window", "Replacement lots"]}
            rows={taxAdjustmentReport.rows.map((row) => [
              row.sale_date.slice(0, 10),
              row.symbol,
              formatQuantityMillis(row.quantity_millis),
              formatMinorAsInr(row.realized_loss_minor),
              formatQuantityMillis(row.replacement_quantity_millis),
              formatMinorAsInr(row.deferred_loss_minor),
              `${row.window_start.slice(0, 10)} to ${row.window_end.slice(0, 10)}`,
              row.replacement_lot_ids.join(", ")
            ])}
          />
        </section>
      )}
      {dividendReport && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">{dividendReport.from_date.slice(0, 10)} to {dividendReport.to_date.slice(0, 10)}</p>
              <h3>Dividend income {formatMinorAsInr(dividendReport.total_amount_minor)}</h3>
              <p>{dividendReport.rows.length} dividend receipt(s) recorded in this period.</p>
            </div>
            <button className="secondary" onClick={() => exportInvestmentDividends(dividendReport)}>Export CSV</button>
          </div>
          <DataTable
            headers={["Date", "Symbol", "Account", "Amount", "Currency", "Posted"]}
            rows={dividendReport.rows.map((row) => [
              row.dividend_date.slice(0, 10),
              row.symbol,
              accountName(row.account_id),
              formatMinorAsInr(row.amount_minor),
              row.currency,
              row.journal_transaction_id ? "Yes" : "No"
            ])}
          />
        </section>
      )}
      {corporateActionReport && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">{corporateActionReport.from_date.slice(0, 10)} to {corporateActionReport.to_date.slice(0, 10)}</p>
              <h3>{corporateActionReport.total_actions} corporate action(s)</h3>
              <p>
                {corporateActionReport.total_affected_lots} lot(s) affected, quantity delta {formatQuantityMillis(corporateActionReport.total_quantity_delta_millis)},
                cost basis delta {formatMinorAsInr(corporateActionReport.total_cost_basis_delta_minor)}.
              </p>
            </div>
            <div className="button-row">
              <button className="secondary" onClick={() => exportInvestmentCorporateActions(corporateActionReport)}>Export cached CSV</button>
              <button className="secondary" disabled={loading === "corporate-action-csv"} onClick={() => void downloadCorporateActionReportCSV()}>
                {loading === "corporate-action-csv" ? "Downloading..." : "Download API CSV"}
              </button>
            </div>
          </div>
          <DataTable
            headers={["Date", "Symbol", "Type", "Ratio", "Affected lots", "Qty delta", "Cost delta", "Notes"]}
            rows={corporateActionReport.rows.map((row) => [
              row.action_date.slice(0, 10),
              row.symbol,
              titleCase(row.action_type),
              `${row.ratio_numerator}:${row.ratio_denominator}`,
              String(row.affected_lots),
              formatQuantityMillis(row.quantity_delta_millis),
              formatMinorAsInr(row.cost_basis_delta_minor),
              row.notes ?? ""
            ])}
          />
        </section>
      )}
      {taxLotReport && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">As of {taxLotReport.as_of_date.slice(0, 10)}</p>
              <h3>Tax lots {formatMinorAsInr(taxLotReport.total_remaining_cost_basis_minor)} remaining basis</h3>
              <p>Remaining {formatQuantityMillis(taxLotReport.total_remaining_quantity_millis)} units; realized gain/loss {formatMinorAsInr(taxLotReport.total_realized_gain_loss_minor)}.</p>
            </div>
            <button className="secondary" onClick={() => exportInvestmentTaxLots(taxLotReport)}>Export CSV</button>
          </div>
          <DataTable
            headers={["Symbol", "Acquired", "Qty", "Remaining", "Disposed", "Cost", "Remaining cost", "Proceeds", "Gain/Loss", "Unit cost"]}
            rows={taxLotReport.rows.map((row) => [
              row.symbol,
              row.acquisition_date.slice(0, 10),
              formatQuantityMillis(row.quantity_millis),
              formatQuantityMillis(row.remaining_quantity_millis),
              formatQuantityMillis(row.disposed_quantity_millis),
              formatMinorAsInr(row.cost_basis_minor),
              formatMinorAsInr(row.remaining_cost_basis_minor),
              formatMinorAsInr(row.proceeds_minor),
              formatMinorAsInr(row.realized_gain_loss_minor),
              formatMinorAsInr(row.unit_cost_minor)
            ])}
          />
        </section>
      )}
    </div>
  );
}

function PayrollPage({
  api,
  accounts,
  payrollRuns,
  employees,
  payslipPreview,
  focusTarget,
  onPayrollRunsChanged,
  onEmployeesChanged,
  onPayslipPreviewChanged,
  onRefresh
}: {
  api: ApiClient;
  accounts: Account[];
  payrollRuns: PayrollRun[];
  employees: Employee[];
  payslipPreview: PayslipPreview | null;
  focusTarget: FocusTarget | null;
  onPayrollRunsChanged: (runs: PayrollRun[]) => void;
  onEmployeesChanged: (employees: Employee[]) => void;
  onPayslipPreviewChanged: (preview: PayslipPreview | null) => void;
  onRefresh: () => Promise<void>;
}) {
  const [payrollError, setPayrollError] = useState("");
  const [payrollNotice, setPayrollNotice] = useState("");
  const [loading, setLoading] = useState<"refresh" | string | null>(null);
  const [indiaPayrollPreview, setIndiaPayrollPreview] = useState<IndiaPayrollPreview | null>(null);
  const [professionalTaxPresets, setProfessionalTaxPresets] = useState<IndiaProfessionalTaxPreset[]>([]);
  const [selectedProfessionalTaxPreset, setSelectedProfessionalTaxPreset] = useState("");
  const [employeeForm, setEmployeeForm] = useState({
    display_name: "",
    email: "",
    phone: "",
    employee_code: "",
    pan: "",
    uan: ""
  });
  const [runForm, setRunForm] = useState({
    run_number: "",
    period_start: new Date().toISOString().slice(0, 10),
    period_end: new Date().toISOString().slice(0, 10),
    pay_date: new Date().toISOString().slice(0, 10),
    currency: "INR",
    employee_id: "",
    gross_pay_minor: 0,
    deductions_minor: 0,
    basic_pay_minor: 0,
    hra_minor: 0,
    special_minor: 0,
    bonus_minor: 0,
    reimbursement_minor: 0,
    employee_pf_enabled: true,
    employee_pf_rate_bps: 1200,
    pf_wage_ceiling_minor: 1500000,
    employer_pf_enabled: true,
    employer_pf_rate_bps: 1200,
    employee_esi_enabled: true,
    employee_esi_rate_bps: 75,
    employer_esi_enabled: true,
    employer_esi_rate_bps: 325,
    esi_gross_limit_minor: 2100000,
    professional_tax_minor: 0,
    tds_rate_bps: 0,
    tds_minor: 0,
    tds_annual_income_minor: 0,
    tds_periods_in_year: 12,
    tds_slabs_text: "0,30000000,0\n30000000,60000000,500\n60000000,,1000",
    preview_components: [] as CreatePayrollComponentInput[],
    employer_contributions_minor: 0,
    payslip_key: "",
    payroll_expense_account_id: "",
    payroll_liability_account_id: "",
    deduction_liability_account_id: "",
    employer_expense_account_id: "",
    employer_liability_account_id: ""
  });
  const draftRuns = payrollRuns.filter((run) => run.status === "draft").length;
  const postedRuns = payrollRuns.filter((run) => run.status === "posted").length;
  const activeEmployees = employees.filter((employee) => employee.is_active).length;
  const canCreateEmployee = Boolean(employeeForm.display_name.trim());
  const canCreatePayrollRun = Boolean(
    runForm.run_number.trim() &&
    runForm.employee_id &&
    (runForm.gross_pay_minor > 0 || runForm.preview_components.length > 0 || runForm.basic_pay_minor + runForm.hra_minor + runForm.special_minor + runForm.bonus_minor + runForm.reimbursement_minor > 0) &&
    runForm.payroll_expense_account_id &&
    runForm.payroll_liability_account_id &&
    runForm.deduction_liability_account_id &&
    (runForm.employer_contributions_minor === 0 || (runForm.employer_expense_account_id && runForm.employer_liability_account_id))
  );

  function updatePayrollRunForm(next: Partial<typeof runForm>, clearPreview = false) {
    setRunForm((current) => ({
      ...current,
      ...next,
      preview_components: clearPreview ? [] : current.preview_components
    }));
    if (clearPreview) {
      setIndiaPayrollPreview(null);
    }
  }

  async function refreshPayrollRuns() {
    setLoading("refresh");
    setPayrollError("");
    try {
      const runs = await api.listPayrollRuns();
      onPayrollRunsChanged(runs);
      setPayrollNotice(`Loaded ${runs.length} payroll runs.`);
    } catch (error) {
      setPayrollError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function refreshEmployees() {
    setLoading("employees");
    setPayrollError("");
    try {
      const nextEmployees = await api.listEmployees();
      onEmployeesChanged(nextEmployees);
      setPayrollNotice(`Loaded ${nextEmployees.length} employees.`);
    } catch (error) {
      setPayrollError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function loadProfessionalTaxPresets() {
    setLoading("pt-presets");
    setPayrollError("");
    try {
      const presets = await api.listIndiaProfessionalTaxPresets();
      setProfessionalTaxPresets(presets);
      setPayrollNotice(`Loaded ${presets.length} India professional tax starter preset(s).`);
    } catch (error) {
      setPayrollError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  function applyProfessionalTaxPreset(stateCode: string) {
    setSelectedProfessionalTaxPreset(stateCode);
    const preset = professionalTaxPresets.find((candidate) => candidate.state_code === stateCode);
    if (!preset) {
      return;
    }
    updatePayrollRunForm({ professional_tax_minor: preset.monthly_amount_minor }, true);
    setPayrollNotice(`Applied ${preset.state_name} PT starter preset: ${formatMinorAsInr(preset.monthly_amount_minor)}. Verify active slabs before filing.`);
  }

  async function createEmployee(event: FormEvent) {
    event.preventDefault();
    if (!canCreateEmployee) {
      return;
    }

    setLoading("create-employee");
    setPayrollError("");
    try {
      const employee = await api.createEmployee(toEmployeeInput(employeeForm));
      onEmployeesChanged([employee, ...employees]);
      setEmployeeForm({
        display_name: "",
        email: "",
        phone: "",
        employee_code: "",
        pan: "",
        uan: ""
      });
      setPayrollNotice(`Created employee ${employee.display_name}.`);
      await onRefresh();
    } catch (error) {
      setPayrollError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function createPayrollRun(event: FormEvent) {
    event.preventDefault();
    if (!canCreatePayrollRun) {
      return;
    }

    setLoading("create-run");
    setPayrollError("");
    try {
      const run = await api.createPayrollRun(toPayrollRunInput(runForm));
      onPayrollRunsChanged([run, ...payrollRuns]);
      setRunForm({
        ...runForm,
        run_number: "",
        employee_id: "",
        gross_pay_minor: 0,
        deductions_minor: 0,
        preview_components: [],
        employer_contributions_minor: 0,
        payslip_key: ""
      });
      setIndiaPayrollPreview(null);
      setPayrollNotice(`Created payroll run ${run.run_number}.`);
      await onRefresh();
    } catch (error) {
      setPayrollError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function previewIndiaPayroll() {
    setLoading("preview-india-payroll");
    setPayrollError("");
    try {
      const preview = await api.previewIndiaPayroll({
        basic_minor: runForm.basic_pay_minor,
        hra_minor: runForm.hra_minor,
        special_minor: runForm.special_minor,
        bonus_minor: runForm.bonus_minor,
        reimbursement_minor: runForm.reimbursement_minor,
        employee_pf_enabled: runForm.employee_pf_enabled,
        employee_pf_rate_bps: runForm.employee_pf_rate_bps,
        pf_wage_ceiling_minor: runForm.pf_wage_ceiling_minor,
        employer_pf_enabled: runForm.employer_pf_enabled,
        employer_pf_rate_bps: runForm.employer_pf_rate_bps,
        employee_esi_enabled: runForm.employee_esi_enabled,
        employee_esi_rate_bps: runForm.employee_esi_rate_bps,
        employer_esi_enabled: runForm.employer_esi_enabled,
        employer_esi_rate_bps: runForm.employer_esi_rate_bps,
        esi_gross_limit_minor: runForm.esi_gross_limit_minor,
        professional_tax_minor: runForm.professional_tax_minor,
        tds_rate_bps: runForm.tds_rate_bps,
        tds_minor: runForm.tds_minor,
        tds_annual_income_minor: runForm.tds_annual_income_minor,
        tds_periods_in_year: runForm.tds_periods_in_year,
        tds_slabs: parseTDSSlabs(runForm.tds_slabs_text)
      });
      setIndiaPayrollPreview(preview);
      setRunForm({
        ...runForm,
        gross_pay_minor: preview.gross_pay_minor,
        deductions_minor: preview.deductions_minor,
        employer_contributions_minor: preview.employer_contributions_minor,
        preview_components: preview.components
      });
      setPayrollNotice(`Previewed India payroll: net pay ${formatMinorAsInr(preview.net_pay_minor)}, employer cost ${formatMinorAsInr(preview.payroll_cost_minor)}.`);
    } catch (error) {
      setPayrollError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function postPayrollRun(runId: string) {
    setLoading(runId);
    setPayrollError("");
    try {
      const postedRun = await api.postPayrollRun(runId);
      onPayrollRunsChanged(payrollRuns.map((run) => run.id === postedRun.id ? postedRun : run));
      setPayrollNotice(`Posted payroll run ${postedRun.run_number} to the ledger.`);
      await onRefresh();
    } catch (error) {
      setPayrollError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function loadPayslipPreview(run: PayrollRun) {
    const item = run.items?.find((candidate) => candidate.id);
    if (!item?.id) {
      setPayrollError("This payroll run does not include a payslip-ready item yet.");
      return;
    }

    setLoading(`payslip-${run.id}`);
    setPayrollError("");
    try {
      const preview = await api.getPayslipPreview(run.id, item.id);
      onPayslipPreviewChanged(preview);
      setPayrollNotice(`Loaded payslip preview for ${preview.employee.display_name}.`);
    } catch (error) {
      setPayrollError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function downloadPayslipPDF(run: PayrollRun) {
    const item = run.items?.find((candidate) => candidate.id);
    if (!item?.id) {
      setPayrollError("This payroll run does not include a payslip-ready item yet.");
      return;
    }

    setLoading(`payslip-pdf-${run.id}`);
    setPayrollError("");
    try {
      const download = await api.downloadPayslipPDF(run.id, item.id);
      downloadBlob(download.filename, download.blob);
      setPayrollNotice(`Downloaded payslip PDF for ${run.run_number}.`);
    } catch (error) {
      setPayrollError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function downloadCurrentPayslipPDF() {
    if (!payslipPreview) {
      return;
    }

    setLoading(`payslip-pdf-${payslipPreview.payroll_run_id}`);
    setPayrollError("");
    try {
      const download = await api.downloadPayslipPDF(payslipPreview.payroll_run_id, payslipPreview.payroll_item_id);
      downloadBlob(download.filename, download.blob);
      setPayrollNotice(`Downloaded payslip PDF for ${payslipPreview.employee.display_name}.`);
    } catch (error) {
      setPayrollError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  return (
    <div className="stack">
      <section className="panel offline-panel">
        <div>
          <p className="eyebrow">Payroll</p>
          <h3>Payroll run control</h3>
          <p>
            Cached locally: {payrollRuns.length} payroll runs, including {draftRuns} draft and {postedRuns} posted runs.
            Employees cached locally: {employees.length}, with {activeEmployees} active.
            Draft runs can be posted to create payroll ledger entries.
            {payslipPreview ? ` Last payslip preview cached for ${payslipPreview.employee.display_name}.` : ""}
          </p>
        </div>
        <div className="button-row">
          <button className="secondary" disabled={loading === "refresh"} onClick={() => void refreshPayrollRuns()}>
            {loading === "refresh" ? "Loading..." : "Refresh payroll runs"}
          </button>
          <button className="secondary" disabled={loading === "employees"} onClick={() => void refreshEmployees()}>
            {loading === "employees" ? "Loading..." : "Refresh employees"}
          </button>
          <button className="secondary" disabled={loading === "pt-presets"} onClick={() => void loadProfessionalTaxPresets()}>
            {loading === "pt-presets" ? "Loading..." : "Load PT presets"}
          </button>
        </div>
      </section>

      {payrollError && <div className="alert error">{payrollError}</div>}
      {payrollNotice && <div className="alert success">{payrollNotice}</div>}
      <FocusNotice focusTarget={focusTarget} />

      <form className="panel form-grid" onSubmit={createEmployee}>
        <input
          placeholder="Display name"
          value={employeeForm.display_name}
          onChange={(event) => setEmployeeForm({ ...employeeForm, display_name: event.target.value })}
          required
        />
        <input
          placeholder="Email"
          value={employeeForm.email}
          onChange={(event) => setEmployeeForm({ ...employeeForm, email: event.target.value })}
        />
        <input
          placeholder="Phone"
          value={employeeForm.phone}
          onChange={(event) => setEmployeeForm({ ...employeeForm, phone: event.target.value })}
        />
        <input
          placeholder="Employee code"
          value={employeeForm.employee_code}
          onChange={(event) => setEmployeeForm({ ...employeeForm, employee_code: event.target.value })}
        />
        <input
          placeholder="PAN"
          value={employeeForm.pan}
          onChange={(event) => setEmployeeForm({ ...employeeForm, pan: event.target.value })}
        />
        <input
          placeholder="UAN"
          value={employeeForm.uan}
          onChange={(event) => setEmployeeForm({ ...employeeForm, uan: event.target.value })}
        />
        <button disabled={!canCreateEmployee || loading === "create-employee"}>
          {loading === "create-employee" ? "Creating..." : "Create employee"}
        </button>
      </form>

      <section className="panel queue-panel">
        <div className="queue-heading">
          <div>
            <p className="eyebrow">Employees</p>
            <h3>Employee master</h3>
            <p>India payroll identifiers are captured as editable master data for payroll previews and posted runs.</p>
          </div>
          <strong>{employees.length}</strong>
        </div>
        <DataTable
          headers={["Code", "Name", "Email", "Phone", "PAN", "UAN", "Active"]}
          rows={employees.map((employee) => [
            employee.employee_code ?? "",
            employee.display_name,
            employee.email ?? "",
            employee.phone ?? "",
            employee.pan ?? "",
            employee.uan ?? "",
            employee.is_active ? "Yes" : "No"
          ])}
        />
      </section>

      <form className="panel form-grid" onSubmit={createPayrollRun}>
        <input
          placeholder="Run number"
          value={runForm.run_number}
          onChange={(event) => setRunForm({ ...runForm, run_number: event.target.value })}
          required
        />
        <label>
          Period start
          <input type="date" value={runForm.period_start} onChange={(event) => setRunForm({ ...runForm, period_start: event.target.value })} required />
        </label>
        <label>
          Period end
          <input type="date" value={runForm.period_end} onChange={(event) => setRunForm({ ...runForm, period_end: event.target.value })} required />
        </label>
        <label>
          Pay date
          <input type="date" value={runForm.pay_date} onChange={(event) => setRunForm({ ...runForm, pay_date: event.target.value })} required />
        </label>
        <input
          placeholder="Currency"
          value={runForm.currency}
          onChange={(event) => setRunForm({ ...runForm, currency: event.target.value })}
        />
        <label>
          Employee
          <select value={runForm.employee_id} onChange={(event) => setRunForm({ ...runForm, employee_id: event.target.value })} required>
            <option value="">Select employee</option>
            {employees.map((employee) => (
              <option key={employee.id} value={employee.id}>{employee.employee_code ? `${employee.employee_code} · ` : ""}{employee.display_name}</option>
            ))}
          </select>
        </label>
        <input
          type="number"
          min="0"
          placeholder="Gross pay minor"
          value={runForm.gross_pay_minor}
          onChange={(event) => updatePayrollRunForm({ gross_pay_minor: Number(event.target.value) }, true)}
          required
        />
        <input
          type="number"
          min="0"
          placeholder="Deductions minor"
          value={runForm.deductions_minor}
          onChange={(event) => updatePayrollRunForm({ deductions_minor: Number(event.target.value) }, true)}
        />
        <input
          type="number"
          min="0"
          placeholder="Employer contributions minor"
          value={runForm.employer_contributions_minor}
          onChange={(event) => updatePayrollRunForm({ employer_contributions_minor: Number(event.target.value) }, true)}
        />
        <input
          type="number"
          min="0"
          placeholder="Basic pay component"
          value={runForm.basic_pay_minor}
          onChange={(event) => updatePayrollRunForm({ basic_pay_minor: Number(event.target.value) }, true)}
        />
        <input
          type="number"
          min="0"
          placeholder="HRA component"
          value={runForm.hra_minor}
          onChange={(event) => updatePayrollRunForm({ hra_minor: Number(event.target.value) }, true)}
        />
        <input
          type="number"
          min="0"
          placeholder="Special allowance"
          value={runForm.special_minor}
          onChange={(event) => updatePayrollRunForm({ special_minor: Number(event.target.value) }, true)}
        />
        <input
          type="number"
          min="0"
          placeholder="Bonus"
          value={runForm.bonus_minor}
          onChange={(event) => updatePayrollRunForm({ bonus_minor: Number(event.target.value) }, true)}
        />
        <input
          type="number"
          min="0"
          placeholder="Reimbursement"
          value={runForm.reimbursement_minor}
          onChange={(event) => updatePayrollRunForm({ reimbursement_minor: Number(event.target.value) }, true)}
        />
        <label>
          <input
            type="checkbox"
            checked={runForm.employee_pf_enabled}
            onChange={(event) => updatePayrollRunForm({ employee_pf_enabled: event.target.checked }, true)}
          />
          Employee PF enabled
        </label>
        <input
          type="number"
          min="0"
          placeholder="Employee PF rate bps"
          value={runForm.employee_pf_rate_bps}
          onChange={(event) => updatePayrollRunForm({ employee_pf_rate_bps: Number(event.target.value) }, true)}
        />
        <label>
          <input
            type="checkbox"
            checked={runForm.employer_pf_enabled}
            onChange={(event) => updatePayrollRunForm({ employer_pf_enabled: event.target.checked }, true)}
          />
          Employer PF enabled
        </label>
        <input
          type="number"
          min="0"
          placeholder="Employer PF rate bps"
          value={runForm.employer_pf_rate_bps}
          onChange={(event) => updatePayrollRunForm({ employer_pf_rate_bps: Number(event.target.value) }, true)}
        />
        <input
          type="number"
          min="0"
          placeholder="PF wage ceiling minor"
          value={runForm.pf_wage_ceiling_minor}
          onChange={(event) => updatePayrollRunForm({ pf_wage_ceiling_minor: Number(event.target.value) }, true)}
        />
        <label>
          <input
            type="checkbox"
            checked={runForm.employee_esi_enabled}
            onChange={(event) => updatePayrollRunForm({ employee_esi_enabled: event.target.checked }, true)}
          />
          Employee ESI enabled
        </label>
        <input
          type="number"
          min="0"
          placeholder="Employee ESI rate bps"
          value={runForm.employee_esi_rate_bps}
          onChange={(event) => updatePayrollRunForm({ employee_esi_rate_bps: Number(event.target.value) }, true)}
        />
        <label>
          <input
            type="checkbox"
            checked={runForm.employer_esi_enabled}
            onChange={(event) => updatePayrollRunForm({ employer_esi_enabled: event.target.checked }, true)}
          />
          Employer ESI enabled
        </label>
        <input
          type="number"
          min="0"
          placeholder="Employer ESI rate bps"
          value={runForm.employer_esi_rate_bps}
          onChange={(event) => updatePayrollRunForm({ employer_esi_rate_bps: Number(event.target.value) }, true)}
        />
        <input
          type="number"
          min="0"
          placeholder="ESI gross limit minor"
          value={runForm.esi_gross_limit_minor}
          onChange={(event) => updatePayrollRunForm({ esi_gross_limit_minor: Number(event.target.value) }, true)}
        />
        <input
          type="number"
          min="0"
          placeholder="Professional tax minor"
          value={runForm.professional_tax_minor}
          onChange={(event) => updatePayrollRunForm({ professional_tax_minor: Number(event.target.value) }, true)}
        />
        <label>
          Professional tax preset
          <select value={selectedProfessionalTaxPreset} onChange={(event) => applyProfessionalTaxPreset(event.target.value)}>
            <option value="">Manual or select state</option>
            {professionalTaxPresets.map((preset) => (
              <option key={preset.state_code} value={preset.state_code}>
                {preset.state_code} · {preset.state_name} · {formatMinorAsInr(preset.monthly_amount_minor)}
              </option>
            ))}
          </select>
        </label>
        <div className="metric-card">
          <span>PT preset note</span>
          <small>{professionalTaxPresets.find((preset) => preset.state_code === selectedProfessionalTaxPreset)?.notes ?? "Load presets to apply starter India state PT amounts; always verify current local slabs."}</small>
        </div>
        <input
          type="number"
          min="0"
          placeholder="TDS rate bps when fixed TDS is empty"
          value={runForm.tds_rate_bps}
          onChange={(event) => updatePayrollRunForm({ tds_rate_bps: Number(event.target.value) }, true)}
        />
        <input
          type="number"
          min="0"
          placeholder="Fixed TDS minor"
          value={runForm.tds_minor}
          onChange={(event) => updatePayrollRunForm({ tds_minor: Number(event.target.value) }, true)}
        />
        <input
          type="number"
          min="0"
          placeholder="Annual taxable income for slab TDS"
          value={runForm.tds_annual_income_minor}
          onChange={(event) => updatePayrollRunForm({ tds_annual_income_minor: Number(event.target.value) }, true)}
        />
        <input
          type="number"
          min="1"
          placeholder="TDS periods in year"
          value={runForm.tds_periods_in_year}
          onChange={(event) => updatePayrollRunForm({ tds_periods_in_year: Number(event.target.value) }, true)}
        />
        <label className="full-span">
          TDS slabs: from_minor,to_minor,rate_bps
          <textarea
            rows={4}
            value={runForm.tds_slabs_text}
            onChange={(event) => updatePayrollRunForm({ tds_slabs_text: event.target.value }, true)}
          />
        </label>
        <input
          placeholder="Payslip key"
          value={runForm.payslip_key}
          onChange={(event) => setRunForm({ ...runForm, payslip_key: event.target.value })}
        />
        <AccountSelect
          label="Payroll expense account"
          accounts={accounts}
          value={runForm.payroll_expense_account_id}
          onChange={(value) => setRunForm({ ...runForm, payroll_expense_account_id: value })}
        />
        <AccountSelect
          label="Net pay liability account"
          accounts={accounts}
          value={runForm.payroll_liability_account_id}
          onChange={(value) => setRunForm({ ...runForm, payroll_liability_account_id: value })}
        />
        <AccountSelect
          label="Deduction liability account"
          accounts={accounts}
          value={runForm.deduction_liability_account_id}
          onChange={(value) => setRunForm({ ...runForm, deduction_liability_account_id: value })}
        />
        <AccountSelect
          label="Employer contribution expense account"
          accounts={accounts}
          value={runForm.employer_expense_account_id}
          onChange={(value) => setRunForm({ ...runForm, employer_expense_account_id: value })}
        />
        <AccountSelect
          label="Employer contribution liability account"
          accounts={accounts}
          value={runForm.employer_liability_account_id}
          onChange={(value) => setRunForm({ ...runForm, employer_liability_account_id: value })}
        />
        <button type="button" className="secondary" disabled={loading === "preview-india-payroll"} onClick={() => void previewIndiaPayroll()}>
          {loading === "preview-india-payroll" ? "Previewing..." : "Preview India payroll"}
        </button>
        <button disabled={!canCreatePayrollRun || loading === "create-run"}>
          {loading === "create-run" ? "Creating..." : "Create payroll run"}
        </button>
      </form>

      {indiaPayrollPreview && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">India preview</p>
              <h3>Payroll component breakdown</h3>
              <p>
                Gross {formatMinorAsInr(indiaPayrollPreview.gross_pay_minor)}, deductions {formatMinorAsInr(indiaPayrollPreview.deductions_minor)},
                {" "}net {formatMinorAsInr(indiaPayrollPreview.net_pay_minor)}, employer cost {formatMinorAsInr(indiaPayrollPreview.payroll_cost_minor)}.
                Employee components will be attached to the next draft run.
                {indiaPayrollPreview.rule_summary.tds_slab_count > 0 ? ` Slab TDS annual tax ${formatMinorAsInr(indiaPayrollPreview.rule_summary.tds_annual_tax_minor)} over ${indiaPayrollPreview.rule_summary.tds_periods_in_year} period(s).` : ""}
              </p>
            </div>
            <strong>{indiaPayrollPreview.components.length + indiaPayrollPreview.employer_contributions.length}</strong>
          </div>
          <DataTable
            headers={["Code", "Name", "Type", "Amount", "Statutory"]}
            rows={indiaPayrollPreview.components.map((component) => [
              component.code,
              component.name,
              component.type,
              formatMinorAsInr(component.amount_minor),
              component.is_statutory ? "Yes" : "No"
            ])}
          />
          <DataTable
            headers={["Employer contribution", "Amount", "Statutory"]}
            rows={[
              ...indiaPayrollPreview.employer_contributions.map((component) => [
                `${component.code} - ${component.name}`,
                formatMinorAsInr(component.amount_minor),
                component.is_statutory ? "Yes" : "No"
              ]),
              ["Total employer contributions", formatMinorAsInr(indiaPayrollPreview.employer_contributions_minor), ""],
              ["Total payroll cost", formatMinorAsInr(indiaPayrollPreview.payroll_cost_minor), ""]
            ]}
          />
        </section>
      )}

      <section className="panel queue-panel">
        <div className="queue-heading">
          <div>
            <p className="eyebrow">Runs</p>
            <h3>Payroll runs</h3>
            <p>Use the India preview to generate componentized draft runs, then post approved runs to the ledger.</p>
          </div>
          <strong>{payrollRuns.length}</strong>
        </div>
        <section className="table-panel">
          <table>
            <thead>
              <tr>
                <th>Run</th>
                <th>Period</th>
                <th>Pay date</th>
                <th>Status</th>
                <th>Gross</th>
                <th>Deductions</th>
                <th>Net</th>
                <th>Employer</th>
                <th>Cost</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {payrollRuns.map((run) => (
                <tr key={run.id} className={focusRowClass(focusTarget, "payroll_run", run.id)}>
                  <td>{run.run_number}</td>
                  <td>{run.period_start.slice(0, 10)} to {run.period_end.slice(0, 10)}</td>
                  <td>{run.pay_date.slice(0, 10)}</td>
                  <td>{run.status}</td>
                  <td>{formatMinorAsInr(run.gross_pay_minor)}</td>
                  <td>{formatMinorAsInr(run.deductions_minor)}</td>
                  <td>{formatMinorAsInr(run.net_pay_minor)}</td>
                  <td>{formatMinorAsInr(run.employer_contributions_minor ?? 0)}</td>
                  <td>{formatMinorAsInr((run.payroll_cost_minor && run.payroll_cost_minor > 0) ? run.payroll_cost_minor : run.gross_pay_minor + (run.employer_contributions_minor ?? 0))}</td>
                  <td>
                    <div className="button-row compact">
                      <button
                        className="secondary compact"
                        disabled={!run.items?.some((item) => item.id) || loading === `payslip-${run.id}`}
                        onClick={() => void loadPayslipPreview(run)}
                      >
                        {loading === `payslip-${run.id}` ? "Loading..." : "Payslip"}
                      </button>
                      <button
                        className="secondary compact"
                        disabled={!run.items?.some((item) => item.id) || loading === `payslip-pdf-${run.id}`}
                        onClick={() => void downloadPayslipPDF(run)}
                      >
                        {loading === `payslip-pdf-${run.id}` ? "Downloading..." : "PDF"}
                      </button>
                      <button
                        className="secondary compact"
                        disabled={run.status !== "draft" || loading === run.id}
                        onClick={() => void postPayrollRun(run.id)}
                      >
                        {loading === run.id ? "Posting..." : "Post"}
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      </section>

      {payslipPreview && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">Payslip preview</p>
              <h3>{payslipPreview.employee.display_name}</h3>
              <p>
                {payslipPreview.run_number} · {payslipPreview.period_start.slice(0, 10)} to {payslipPreview.period_end.slice(0, 10)}
                {" "}· Net {formatMinorAsInr(payslipPreview.net_pay_minor)}
              </p>
            </div>
            <div className="button-row">
              <strong>{payslipPreview.status}</strong>
              <button className="secondary compact" disabled={loading === `payslip-pdf-${payslipPreview.payroll_run_id}`} onClick={() => void downloadCurrentPayslipPDF()}>
                {loading === `payslip-pdf-${payslipPreview.payroll_run_id}` ? "Downloading..." : "Download PDF"}
              </button>
              <button className="secondary compact" onClick={() => exportPayslipPreview(payslipPreview)}>
                Export CSV
              </button>
            </div>
          </div>
          <DataTable
            headers={["Earning", "Amount"]}
            rows={payslipPreview.earnings.map((component) => [component.name, formatMinorAsInr(component.amount_minor)])}
          />
          <DataTable
            headers={["Deduction", "Amount", "Statutory"]}
            rows={payslipPreview.deductions.map((component) => [
              component.name,
              formatMinorAsInr(component.amount_minor),
              component.is_statutory ? "Yes" : "No"
            ])}
          />
        </section>
      )}
    </div>
  );
}

function InvoicesPage({
  api,
  accounts,
  customers,
  invoices,
  recurringInvoices,
  estimates,
  creditNotes,
  taxRates,
  taxGroups,
  focusTarget,
  onCustomersChanged,
  onInvoicesChanged,
  onRecurringInvoicesChanged,
  onEstimatesChanged,
  onCreditNotesChanged,
  onRefresh
}: {
  api: ApiClient;
  accounts: Account[];
  customers: Customer[];
  invoices: Invoice[];
  recurringInvoices: RecurringInvoiceTemplate[];
  estimates: Estimate[];
  creditNotes: CreditNote[];
  taxRates: TaxRate[];
  taxGroups: TaxGroup[];
  focusTarget: FocusTarget | null;
  onCustomersChanged: (customers: Customer[]) => void;
  onInvoicesChanged: (invoices: Invoice[]) => void;
  onRecurringInvoicesChanged: (templates: RecurringInvoiceTemplate[]) => void;
  onEstimatesChanged: (estimates: Estimate[]) => void;
  onCreditNotesChanged: (creditNotes: CreditNote[]) => void;
  onRefresh: () => Promise<void>;
}) {
  const [invoiceError, setInvoiceError] = useState("");
  const [invoiceNotice, setInvoiceNotice] = useState("");
  const [loading, setLoading] = useState<"customers" | "invoices" | "create-customer" | string | null>(null);
  const [customerPayments, setCustomerPayments] = useState<CustomerPayment[]>([]);
  const [customerPaymentsInvoiceId, setCustomerPaymentsInvoiceId] = useState("");
  const [resolvedCustomerPaymentId, setResolvedCustomerPaymentId] = useState("");
  const [selectedInvoiceId, setSelectedInvoiceId] = useState("");
  const [selectedEstimateId, setSelectedEstimateId] = useState("");
  const [customerForm, setCustomerForm] = useState({
    display_name: "",
    email: "",
    phone: "",
    billing_address: "",
    gstin: ""
  });
  const [invoiceForm, setInvoiceForm] = useState({
    customer_id: "",
    invoice_number: "",
    issue_date: new Date().toISOString().slice(0, 10),
    due_date: new Date().toISOString().slice(0, 10),
    currency: "INR",
    tax_inclusive: false,
    accounts_receivable_id: "",
    description: "",
    quantity_millis: 1000,
    unit_price_minor: 0,
    income_account_id: "",
    tax_target: ""
  });
  const [paymentForm, setPaymentForm] = useState({
    invoice_id: "",
    payment_number: "",
    payment_date: new Date().toISOString().slice(0, 10),
    payment_method: "bank_transfer",
    reference: "",
    currency: "INR",
    amount_minor: 0,
    payment_account_id: ""
  });
  const [estimateForm, setEstimateForm] = useState({
    customer_id: "",
    estimate_number: "",
    issue_date: new Date().toISOString().slice(0, 10),
    expiry_date: new Date().toISOString().slice(0, 10),
    currency: "INR",
    tax_inclusive: false,
    description: "",
    quantity_millis: 1000,
    unit_price_minor: 0,
    income_account_id: "",
    tax_target: ""
  });
  const [recurringInvoiceForm, setRecurringInvoiceForm] = useState({
    customer_id: "",
    name: "",
    invoice_number_prefix: "",
    start_date: new Date().toISOString().slice(0, 10),
    next_run_date: "",
    frequency: "monthly" as RecurringInvoiceTemplate["frequency"],
    due_days: 30,
    currency: "INR",
    tax_inclusive: false,
    accounts_receivable_id: "",
    description: "",
    quantity_millis: 1000,
    unit_price_minor: 0,
    income_account_id: "",
    tax_target: ""
  });
  const [creditNoteForm, setCreditNoteForm] = useState({
    customer_id: "",
    invoice_id: "",
    credit_note_number: "",
    issue_date: new Date().toISOString().slice(0, 10),
    currency: "INR",
    tax_inclusive: false,
    accounts_receivable_id: "",
    description: "",
    quantity_millis: 1000,
    unit_price_minor: 0,
    income_account_id: "",
    tax_target: ""
  });
  const draftInvoices = invoices.filter((invoice) => invoice.status === "draft").length;
  const postedInvoices = invoices.filter((invoice) => invoice.status === "posted").length;
  const draftCreditNotes = creditNotes.filter((creditNote) => creditNote.status === "draft").length;
  const canCreateCustomer = Boolean(customerForm.display_name.trim());
  const canCreateInvoice = Boolean(
    invoiceForm.customer_id &&
    invoiceForm.invoice_number.trim() &&
    invoiceForm.accounts_receivable_id &&
    invoiceForm.description.trim() &&
    invoiceForm.unit_price_minor >= 0 &&
    invoiceForm.income_account_id
  );
  const canRecordPayment = Boolean(
    paymentForm.invoice_id &&
    paymentForm.payment_number.trim() &&
    paymentForm.amount_minor > 0 &&
    paymentForm.payment_account_id
  );
  const canCreateEstimate = Boolean(
    estimateForm.customer_id &&
    estimateForm.estimate_number.trim() &&
    estimateForm.description.trim() &&
    estimateForm.income_account_id &&
    estimateForm.unit_price_minor >= 0
  );
  const canCreateRecurringInvoice = Boolean(
    recurringInvoiceForm.customer_id &&
    recurringInvoiceForm.name.trim() &&
    recurringInvoiceForm.invoice_number_prefix.trim() &&
    recurringInvoiceForm.accounts_receivable_id &&
    recurringInvoiceForm.description.trim() &&
    recurringInvoiceForm.income_account_id &&
    recurringInvoiceForm.unit_price_minor >= 0
  );
  const canCreateCreditNote = Boolean(
    creditNoteForm.customer_id &&
    creditNoteForm.credit_note_number.trim() &&
    creditNoteForm.accounts_receivable_id &&
    creditNoteForm.description.trim() &&
    creditNoteForm.income_account_id &&
    creditNoteForm.unit_price_minor >= 0
  );

  async function refreshCustomers() {
    setLoading("customers");
    setInvoiceError("");
    try {
      const nextCustomers = await api.listCustomers();
      onCustomersChanged(nextCustomers);
      setInvoiceNotice(`Loaded ${nextCustomers.length} customers.`);
    } catch (error) {
      setInvoiceError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function refreshInvoices() {
    setLoading("invoices");
    setInvoiceError("");
    try {
      const nextInvoices = await api.listInvoices();
      onInvoicesChanged(nextInvoices);
      setInvoiceNotice(`Loaded ${nextInvoices.length} invoices.`);
    } catch (error) {
      setInvoiceError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function refreshCommercialDocs() {
    setLoading("commercial-docs");
    setInvoiceError("");
    try {
      const [nextEstimates, nextCreditNotes] = await Promise.all([
        api.listEstimates(),
        api.listCreditNotes()
      ]);
      onEstimatesChanged(nextEstimates);
      onCreditNotesChanged(nextCreditNotes);
      setInvoiceNotice(`Loaded ${nextEstimates.length} estimates and ${nextCreditNotes.length} credit notes.`);
    } catch (error) {
      setInvoiceError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function refreshRecurringInvoices() {
    setLoading("recurring-invoices");
    setInvoiceError("");
    try {
      const nextTemplates = await api.listRecurringInvoices();
      onRecurringInvoicesChanged(nextTemplates);
      setInvoiceNotice(`Loaded ${nextTemplates.length} recurring invoice templates.`);
    } catch (error) {
      setInvoiceError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function createCustomer(event: FormEvent) {
    event.preventDefault();
    if (!canCreateCustomer) {
      return;
    }

    setLoading("create-customer");
    setInvoiceError("");
    try {
      const customer = await api.createCustomer(toCustomerInput(customerForm));
      onCustomersChanged([customer, ...customers]);
      setCustomerForm({
        display_name: "",
        email: "",
        phone: "",
        billing_address: "",
        gstin: ""
      });
      setInvoiceNotice(`Created customer ${customer.display_name}.`);
      await onRefresh();
    } catch (error) {
      setInvoiceError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function createInvoice(event: FormEvent) {
    event.preventDefault();
    if (!canCreateInvoice) {
      return;
    }

    setLoading("create-invoice");
    setInvoiceError("");
    try {
      const invoice = await api.createInvoice(toInvoiceInput(invoiceForm));
      onInvoicesChanged([invoice, ...invoices]);
      setInvoiceForm({
        ...invoiceForm,
        invoice_number: "",
        description: "",
        unit_price_minor: 0,
        tax_target: ""
      });
      setInvoiceNotice(`Created invoice ${invoice.invoice_number}.`);
      await onRefresh();
    } catch (error) {
      setInvoiceError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function createEstimate(event: FormEvent) {
    event.preventDefault();
    if (!canCreateEstimate) {
      return;
    }
    setLoading("create-estimate");
    setInvoiceError("");
    try {
      const estimate = await api.createEstimate(toEstimateInput(estimateForm));
      onEstimatesChanged([estimate, ...estimates]);
      setEstimateForm({ ...estimateForm, estimate_number: "", description: "", unit_price_minor: 0, tax_target: "" });
      setInvoiceNotice(`Created estimate ${estimate.estimate_number}.`);
      await onRefresh();
    } catch (error) {
      setInvoiceError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function createRecurringInvoice(event: FormEvent) {
    event.preventDefault();
    if (!canCreateRecurringInvoice) {
      return;
    }
    setLoading("create-recurring-invoice");
    setInvoiceError("");
    try {
      const template = await api.createRecurringInvoice(toRecurringInvoiceInput(recurringInvoiceForm));
      onRecurringInvoicesChanged([template, ...recurringInvoices]);
      setRecurringInvoiceForm({ ...recurringInvoiceForm, name: "", invoice_number_prefix: "", description: "", unit_price_minor: 0, tax_target: "" });
      setInvoiceNotice(`Created recurring invoice template ${template.name}.`);
      await onRefresh();
    } catch (error) {
      setInvoiceError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function generateDueRecurringInvoices() {
    setLoading("generate-recurring-invoices");
    setInvoiceError("");
    try {
      const result = await api.generateDueRecurringInvoices(new Date().toISOString().slice(0, 10));
      const [nextInvoices, nextTemplates] = await Promise.all([
        api.listInvoices(),
        api.listRecurringInvoices()
      ]);
      onInvoicesChanged(nextInvoices);
      onRecurringInvoicesChanged(nextTemplates);
      setInvoiceNotice(`Generated ${result.generated_count} recurring draft invoice(s).`);
      await onRefresh();
    } catch (error) {
      setInvoiceError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function createCreditNote(event: FormEvent) {
    event.preventDefault();
    if (!canCreateCreditNote) {
      return;
    }
    setLoading("create-credit-note");
    setInvoiceError("");
    try {
      const creditNote = await api.createCreditNote(toCreditNoteInput(creditNoteForm));
      onCreditNotesChanged([creditNote, ...creditNotes]);
      setCreditNoteForm({ ...creditNoteForm, credit_note_number: "", description: "", unit_price_minor: 0, tax_target: "" });
      setInvoiceNotice(`Created credit note ${creditNote.credit_note_number}.`);
      await onRefresh();
    } catch (error) {
      setInvoiceError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function postInvoice(invoiceId: string) {
    setLoading(invoiceId);
    setInvoiceError("");
    try {
      const postedInvoice = await api.postInvoice(invoiceId);
      onInvoicesChanged(invoices.map((invoice) => invoice.id === postedInvoice.id ? postedInvoice : invoice));
      setInvoiceNotice(`Posted invoice ${postedInvoice.invoice_number} to the ledger.`);
      await onRefresh();
    } catch (error) {
      setInvoiceError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function recordCustomerPayment(event: FormEvent) {
    event.preventDefault();
    if (!canRecordPayment) {
      return;
    }

    setLoading("record-payment");
    setInvoiceError("");
    try {
      await api.recordCustomerPayment(paymentForm.invoice_id, toRecordPaymentInput(paymentForm));
      const nextInvoices = await api.listInvoices();
      onInvoicesChanged(nextInvoices);
      setPaymentForm({
        ...paymentForm,
        invoice_id: "",
        payment_number: "",
        reference: "",
        amount_minor: 0
      });
      setInvoiceNotice("Recorded customer payment and updated AR status.");
      await onRefresh();
    } catch (error) {
      setInvoiceError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function loadCustomerPayments(invoiceId: string) {
    if (!invoiceId) {
      return;
    }
    setLoading(`customer-payments-${invoiceId}`);
    setInvoiceError("");
    try {
      const payments = await api.listCustomerPayments(invoiceId);
      setCustomerPayments(payments);
      setCustomerPaymentsInvoiceId(invoiceId);
      setInvoiceNotice(`Loaded ${payments.length} payment(s) for invoice ${invoiceNumber(invoiceId)}.`);
    } catch (error) {
      setInvoiceError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function loadFocusedCustomerPaymentHistory(paymentId: string) {
    if (!paymentId || resolvedCustomerPaymentId === paymentId) {
      return;
    }
    setLoading(`customer-payment-focus-${paymentId}`);
    setInvoiceError("");
    try {
      for (const invoice of invoices) {
        const payments = await api.listCustomerPayments(invoice.id);
        if (payments.some((payment) => payment.id === paymentId)) {
          setCustomerPayments(payments);
          setCustomerPaymentsInvoiceId(invoice.id);
          setResolvedCustomerPaymentId(paymentId);
          setInvoiceNotice(`Loaded payment history for invoice ${invoice.invoice_number}.`);
          return;
        }
      }
      setInvoiceNotice("Focused customer payment was not found in the currently cached invoice payment histories.");
    } catch (error) {
      setInvoiceError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function postCreditNote(creditNoteId: string) {
    setLoading(creditNoteId);
    setInvoiceError("");
    try {
      const postedCreditNote = await api.postCreditNote(creditNoteId);
      onCreditNotesChanged(creditNotes.map((creditNote) => creditNote.id === postedCreditNote.id ? postedCreditNote : creditNote));
      setInvoiceNotice(`Posted credit note ${postedCreditNote.credit_note_number} to AR.`);
      await onRefresh();
    } catch (error) {
      setInvoiceError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function convertEstimateToInvoice(estimate: Estimate) {
    const accountsReceivable = defaultAccountsReceivableAccount(accounts);
    if (!accountsReceivable) {
      setInvoiceError("Create or seed an accounts receivable account before converting estimates.");
      return;
    }
    const invoiceNumber = window.prompt("Invoice number", estimate.estimate_number.replace(/^EST/i, "INV"));
    if (!invoiceNumber) {
      return;
    }
    const issueDate = new Date().toISOString().slice(0, 10);
    const dueDate = addDays(issueDate, 30);
    setLoading(estimate.id);
    setInvoiceError("");
    try {
      const invoice = await api.convertEstimateToInvoice(estimate.id, {
        invoice_number: invoiceNumber.trim(),
        issue_date: issueDate,
        due_date: dueDate,
        accounts_receivable_id: accountsReceivable.id
      });
      onInvoicesChanged([invoice, ...invoices]);
      const nextEstimates = await api.listEstimates();
      onEstimatesChanged(nextEstimates);
      setInvoiceNotice(`Converted estimate ${estimate.estimate_number} to draft invoice ${invoice.invoice_number}.`);
      await onRefresh();
    } catch (error) {
      setInvoiceError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function updateEstimateStatus(estimate: Estimate, status: Estimate["status"]) {
    setLoading(`${estimate.id}-${status}`);
    setInvoiceError("");
    try {
      const updated = await api.updateEstimateStatus(estimate.id, status);
      onEstimatesChanged(estimates.map((candidate) => candidate.id === updated.id ? updated : candidate));
      setInvoiceNotice(`Updated estimate ${updated.estimate_number} to ${updated.status}.`);
      await onRefresh();
    } catch (error) {
      setInvoiceError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  function customerName(customerId?: string) {
    return customers.find((customer) => customer.id === customerId)?.display_name ?? customerId ?? "";
  }

  function invoiceNumber(invoiceId?: string) {
    return invoices.find((invoice) => invoice.id === invoiceId)?.invoice_number ?? invoiceId ?? "";
  }

  function accountName(accountId?: string | null) {
    if (!accountId) {
      return "-";
    }
    const account = accounts.find((candidate) => candidate.id === accountId);
    return account ? `${account.code} · ${account.name}` : accountId;
  }

  function taxName(line: InvoiceLine) {
    if (line.tax_group_id) {
      return taxGroups.find((group) => group.id === line.tax_group_id)?.name ?? line.tax_group_id;
    }
    if (line.tax_rate_id) {
      return taxRates.find((rate) => rate.id === line.tax_rate_id)?.name ?? line.tax_rate_id;
    }
    return "No tax";
  }

  function estimateTaxName(line: EstimateLine) {
    if (line.tax_group_id) {
      return taxGroups.find((group) => group.id === line.tax_group_id)?.name ?? line.tax_group_id;
    }
    if (line.tax_rate_id) {
      return taxRates.find((rate) => rate.id === line.tax_rate_id)?.name ?? line.tax_rate_id;
    }
    return "No tax";
  }

  const selectedInvoice = invoices.find((invoice) => invoice.id === selectedInvoiceId) ?? null;
  const selectedEstimate = estimates.find((estimate) => estimate.id === selectedEstimateId) ?? null;

  useEffect(() => {
    if (focusTarget?.documentType !== "customer_payment") {
      return;
    }
    void loadFocusedCustomerPaymentHistory(focusTarget.documentId);
  }, [focusTarget, invoices, resolvedCustomerPaymentId]);

  return (
    <div className="stack">
      <section className="panel offline-panel">
        <div>
          <p className="eyebrow">Invoices</p>
          <h3>Customer and AR control</h3>
          <p>
            Cached locally: {customers.length} customers and {invoices.length} invoices, including {draftInvoices} draft and {postedInvoices} posted invoices.
            Commercial docs: {estimates.length} estimates, {creditNotes.length} credit notes ({draftCreditNotes} draft), and {recurringInvoices.length} recurring templates.
          </p>
        </div>
        <div className="button-row">
          <button className="secondary" disabled={loading === "customers"} onClick={() => void refreshCustomers()}>
            {loading === "customers" ? "Loading..." : "Refresh customers"}
          </button>
          <button className="secondary" disabled={loading === "invoices"} onClick={() => void refreshInvoices()}>
            {loading === "invoices" ? "Loading..." : "Refresh invoices"}
          </button>
          <button className="secondary" disabled={loading === "commercial-docs"} onClick={() => void refreshCommercialDocs()}>
            {loading === "commercial-docs" ? "Loading..." : "Refresh estimates/credits"}
          </button>
          <button className="secondary" disabled={loading === "recurring-invoices"} onClick={() => void refreshRecurringInvoices()}>
            {loading === "recurring-invoices" ? "Loading..." : "Refresh recurring"}
          </button>
          <button className="secondary" disabled={loading === "generate-recurring-invoices"} onClick={() => void generateDueRecurringInvoices()}>
            {loading === "generate-recurring-invoices" ? "Generating..." : "Generate due drafts"}
          </button>
        </div>
      </section>

      {invoiceError && <div className="alert error">{invoiceError}</div>}
      {invoiceNotice && <div className="alert success">{invoiceNotice}</div>}
      <FocusNotice focusTarget={focusTarget} />

      {customerPayments.length > 0 && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">Payment history</p>
              <h3>{invoiceNumber(customerPaymentsInvoiceId)}</h3>
              <p>Customer payments loaded from the selected invoice, with drilldown-sourced payments highlighted.</p>
            </div>
            <strong>{customerPayments.length}</strong>
          </div>
          <section className="table-panel">
            <table>
              <thead>
                <tr>
                  <th>Payment</th>
                  <th>Date</th>
                  <th>Method</th>
                  <th>Reference</th>
                  <th>Amount</th>
                  <th>Journal</th>
                </tr>
              </thead>
              <tbody>
                {customerPayments.map((payment) => (
                  <tr key={payment.id} className={focusRowClass(focusTarget, "customer_payment", payment.id)}>
                    <td>{payment.payment_number}</td>
                    <td>{payment.payment_date.slice(0, 10)}</td>
                    <td>{payment.payment_method || "-"}</td>
                    <td>{payment.reference || "-"}</td>
                    <td>{formatMinor(payment.amount_minor, payment.currency)}</td>
                    <td>{payment.journal_transaction_id.slice(0, 8)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>
        </section>
      )}

      <form className="panel form-grid" onSubmit={createCustomer}>
        <input
          placeholder="Display name"
          value={customerForm.display_name}
          onChange={(event) => setCustomerForm({ ...customerForm, display_name: event.target.value })}
          required
        />
        <input
          placeholder="Email"
          value={customerForm.email}
          onChange={(event) => setCustomerForm({ ...customerForm, email: event.target.value })}
        />
        <input
          placeholder="Phone"
          value={customerForm.phone}
          onChange={(event) => setCustomerForm({ ...customerForm, phone: event.target.value })}
        />
        <input
          placeholder="GSTIN"
          value={customerForm.gstin}
          onChange={(event) => setCustomerForm({ ...customerForm, gstin: event.target.value })}
        />
        <input
          placeholder="Billing address"
          value={customerForm.billing_address}
          onChange={(event) => setCustomerForm({ ...customerForm, billing_address: event.target.value })}
        />
        <button disabled={!canCreateCustomer || loading === "create-customer"}>
          {loading === "create-customer" ? "Creating..." : "Create customer"}
        </button>
      </form>

      <section className="panel queue-panel">
        <div className="queue-heading">
          <div>
            <p className="eyebrow">Customers</p>
            <h3>Customer master</h3>
            <p>GSTIN and billing details are cached locally after refresh for offline review.</p>
          </div>
          <strong>{customers.length}</strong>
        </div>
        <DataTable
          headers={["Name", "Email", "Phone", "GSTIN", "Active"]}
          rows={customers.map((customer) => [
            customer.display_name,
            customer.email ?? "",
            customer.phone ?? "",
            customer.gstin ?? "",
            customer.is_active ? "Yes" : "No"
          ])}
        />
      </section>

      <form className="panel form-grid" onSubmit={createRecurringInvoice}>
        <label>
          Customer
          <select value={recurringInvoiceForm.customer_id} onChange={(event) => setRecurringInvoiceForm({ ...recurringInvoiceForm, customer_id: event.target.value })} required>
            <option value="">Select customer</option>
            {customers.map((customer) => (
              <option key={customer.id} value={customer.id}>{customer.display_name}</option>
            ))}
          </select>
        </label>
        <input placeholder="Template name" value={recurringInvoiceForm.name} onChange={(event) => setRecurringInvoiceForm({ ...recurringInvoiceForm, name: event.target.value })} required />
        <input placeholder="Invoice prefix" value={recurringInvoiceForm.invoice_number_prefix} onChange={(event) => setRecurringInvoiceForm({ ...recurringInvoiceForm, invoice_number_prefix: event.target.value })} required />
        <label>
          Start date
          <input type="date" value={recurringInvoiceForm.start_date} onChange={(event) => setRecurringInvoiceForm({ ...recurringInvoiceForm, start_date: event.target.value })} required />
        </label>
        <label>
          Next run date
          <input type="date" value={recurringInvoiceForm.next_run_date} onChange={(event) => setRecurringInvoiceForm({ ...recurringInvoiceForm, next_run_date: event.target.value })} />
        </label>
        <label>
          Frequency
          <select value={recurringInvoiceForm.frequency} onChange={(event) => setRecurringInvoiceForm({ ...recurringInvoiceForm, frequency: event.target.value as RecurringInvoiceTemplate["frequency"] })}>
            <option value="weekly">Weekly</option>
            <option value="monthly">Monthly</option>
            <option value="yearly">Yearly</option>
          </select>
        </label>
        <input type="number" min="0" placeholder="Due days" value={recurringInvoiceForm.due_days} onChange={(event) => setRecurringInvoiceForm({ ...recurringInvoiceForm, due_days: Number(event.target.value) })} />
        <AccountSelect label="Accounts receivable" accounts={accounts} value={recurringInvoiceForm.accounts_receivable_id} onChange={(value) => setRecurringInvoiceForm({ ...recurringInvoiceForm, accounts_receivable_id: value })} />
        <input placeholder="Line description" value={recurringInvoiceForm.description} onChange={(event) => setRecurringInvoiceForm({ ...recurringInvoiceForm, description: event.target.value })} required />
        <input type="number" min="1" placeholder="Quantity millis" value={recurringInvoiceForm.quantity_millis} onChange={(event) => setRecurringInvoiceForm({ ...recurringInvoiceForm, quantity_millis: Number(event.target.value) })} />
        <input type="number" min="0" placeholder="Unit price minor" value={recurringInvoiceForm.unit_price_minor} onChange={(event) => setRecurringInvoiceForm({ ...recurringInvoiceForm, unit_price_minor: Number(event.target.value) })} required />
        <AccountSelect label="Income account" accounts={accounts} value={recurringInvoiceForm.income_account_id} onChange={(value) => setRecurringInvoiceForm({ ...recurringInvoiceForm, income_account_id: value })} />
        <label>
          GST rate/group
          <select value={recurringInvoiceForm.tax_target} onChange={(event) => setRecurringInvoiceForm({ ...recurringInvoiceForm, tax_target: event.target.value })}>
            <option value="">No tax</option>
            {taxGroups.map((group) => (
              <option key={group.id} value={`group:${group.id}`}>Group: {group.name}</option>
            ))}
            {taxRates.map((rate) => (
              <option key={rate.id} value={`rate:${rate.id}`}>Rate: {rate.name}</option>
            ))}
          </select>
        </label>
        <button disabled={!canCreateRecurringInvoice || loading === "create-recurring-invoice"}>
          {loading === "create-recurring-invoice" ? "Creating..." : "Create recurring template"}
        </button>
      </form>

      <section className="panel queue-panel">
        <div className="queue-heading">
          <div>
            <p className="eyebrow">Automation</p>
            <h3>Recurring invoices</h3>
            <p>Generate-due creates draft invoices; posting still stays explicit for audit control.</p>
          </div>
          <strong>{recurringInvoices.length}</strong>
        </div>
        <DataTable
          headers={["Template", "Customer", "Frequency", "Next run", "Due days", "Total", "Active"]}
          rows={recurringInvoices.map((template) => [
            template.name,
            customerName(template.customer_id),
            template.frequency,
            template.next_run_date.slice(0, 10),
            String(template.due_days),
            formatMinorAsInr(template.total_minor),
            template.is_active ? "Yes" : "No"
          ])}
        />
      </section>

      <form className="panel form-grid" onSubmit={createEstimate}>
        <label>
          Customer
          <select value={estimateForm.customer_id} onChange={(event) => setEstimateForm({ ...estimateForm, customer_id: event.target.value })} required>
            <option value="">Select customer</option>
            {customers.map((customer) => (
              <option key={customer.id} value={customer.id}>{customer.display_name}</option>
            ))}
          </select>
        </label>
        <input placeholder="Estimate number" value={estimateForm.estimate_number} onChange={(event) => setEstimateForm({ ...estimateForm, estimate_number: event.target.value })} required />
        <label>
          Issue date
          <input type="date" value={estimateForm.issue_date} onChange={(event) => setEstimateForm({ ...estimateForm, issue_date: event.target.value })} required />
        </label>
        <label>
          Expiry date
          <input type="date" value={estimateForm.expiry_date} onChange={(event) => setEstimateForm({ ...estimateForm, expiry_date: event.target.value })} required />
        </label>
        <input placeholder="Currency" value={estimateForm.currency} onChange={(event) => setEstimateForm({ ...estimateForm, currency: event.target.value })} />
        <label>
          Pricing mode
          <select value={estimateForm.tax_inclusive ? "inclusive" : "exclusive"} onChange={(event) => setEstimateForm({ ...estimateForm, tax_inclusive: event.target.value === "inclusive" })}>
            <option value="exclusive">Tax exclusive</option>
            <option value="inclusive">Tax inclusive</option>
          </select>
        </label>
        <input placeholder="Line description" value={estimateForm.description} onChange={(event) => setEstimateForm({ ...estimateForm, description: event.target.value })} required />
        <input type="number" min="1" placeholder="Quantity millis" value={estimateForm.quantity_millis} onChange={(event) => setEstimateForm({ ...estimateForm, quantity_millis: Number(event.target.value) })} />
        <input type="number" min="0" placeholder="Unit price minor" value={estimateForm.unit_price_minor} onChange={(event) => setEstimateForm({ ...estimateForm, unit_price_minor: Number(event.target.value) })} required />
        <AccountSelect label="Income account" accounts={accounts} value={estimateForm.income_account_id} onChange={(value) => setEstimateForm({ ...estimateForm, income_account_id: value })} />
        <label>
          GST rate/group
          <select value={estimateForm.tax_target} onChange={(event) => setEstimateForm({ ...estimateForm, tax_target: event.target.value })}>
            <option value="">No tax</option>
            {taxGroups.map((group) => (
              <option key={group.id} value={`group:${group.id}`}>Group: {group.name}</option>
            ))}
            {taxRates.map((rate) => (
              <option key={rate.id} value={`rate:${rate.id}`}>Rate: {rate.name}</option>
            ))}
          </select>
        </label>
        <button disabled={!canCreateEstimate || loading === "create-estimate"}>
          {loading === "create-estimate" ? "Creating..." : "Create estimate"}
        </button>
      </form>

      <section className="panel queue-panel">
        <div className="queue-heading">
          <div>
            <p className="eyebrow">Quotes</p>
            <h3>Estimates</h3>
            <p>Estimates are non-posting commercial documents and do not affect the ledger.</p>
          </div>
          <strong>{estimates.length}</strong>
        </div>
        <DataTable
          headers={["Estimate", "Customer", "Issue", "Expiry", "Status", "Total", "Action"]}
          rows={estimates.map((estimate) => [
            estimate.estimate_number,
            customerName(estimate.customer_id),
            estimate.issue_date.slice(0, 10),
            estimate.expiry_date.slice(0, 10),
            estimate.status,
            formatMinorAsInr(estimate.total_minor),
            estimate.status === "converted" || estimate.status === "void" ? "" : "Convert available"
          ])}
        />
        <div className="button-row">
          {estimates.filter((estimate) => estimate.status !== "converted" && estimate.status !== "void").slice(0, 5).map((estimate) => (
            <span key={estimate.id} className="button-row">
              {estimate.status === "draft" && (
                <button className="secondary compact" disabled={loading === `${estimate.id}-sent`} onClick={() => void updateEstimateStatus(estimate, "sent")}>
                  {loading === `${estimate.id}-sent` ? "Sending..." : `Send ${estimate.estimate_number}`}
                </button>
              )}
              {(estimate.status === "draft" || estimate.status === "sent") && (
                <button className="secondary compact" disabled={loading === `${estimate.id}-accepted`} onClick={() => void updateEstimateStatus(estimate, "accepted")}>
                  {loading === `${estimate.id}-accepted` ? "Accepting..." : "Accept"}
                </button>
              )}
              <button className="secondary compact" disabled={loading === estimate.id} onClick={() => void convertEstimateToInvoice(estimate)}>
                {loading === estimate.id ? "Converting..." : `Convert ${estimate.estimate_number}`}
              </button>
              <button className="secondary compact" disabled={loading === `${estimate.id}-void`} onClick={() => void updateEstimateStatus(estimate, "void")}>
                {loading === `${estimate.id}-void` ? "Voiding..." : "Void"}
              </button>
              <button className="secondary compact" onClick={() => setSelectedEstimateId(estimate.id)}>
                Details
              </button>
            </span>
          ))}
        </div>
      </section>

      {selectedEstimate && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">Estimate detail</p>
              <h3>{selectedEstimate.estimate_number} · {customerName(selectedEstimate.customer_id)}</h3>
              <p>
                {selectedEstimate.status} · {selectedEstimate.issue_date.slice(0, 10)} to {selectedEstimate.expiry_date.slice(0, 10)}
                {" "}· {selectedEstimate.tax_inclusive ? "Tax inclusive" : "Tax exclusive"}
              </p>
            </div>
            <button className="secondary compact" onClick={() => setSelectedEstimateId("")}>Close</button>
          </div>
          <div className="metric-grid">
            <div><span>Subtotal</span><strong>{formatMinor(selectedEstimate.subtotal_minor, selectedEstimate.currency)}</strong></div>
            <div><span>Tax</span><strong>{formatMinor(selectedEstimate.tax_total_minor, selectedEstimate.currency)}</strong></div>
            <div><span>Total</span><strong>{formatMinor(selectedEstimate.total_minor, selectedEstimate.currency)}</strong></div>
          </div>
          {selectedEstimate.lines && selectedEstimate.lines.length > 0 ? (
            <DataTable
              headers={["Description", "Qty", "Unit", "Income", "Tax", "Subtotal", "Tax amount", "Line total"]}
              rows={selectedEstimate.lines.map((line) => [
                line.description ?? "-",
                formatQuantityMillis(line.quantity_millis ?? 0),
                formatMinor(line.unit_price_minor ?? 0, selectedEstimate.currency),
                accountName(line.income_account_id),
                estimateTaxName(line),
                formatMinor(line.line_subtotal_minor ?? 0, selectedEstimate.currency),
                formatMinor(line.tax_amount_minor ?? 0, selectedEstimate.currency),
                formatMinor(line.line_total_minor ?? 0, selectedEstimate.currency)
              ])}
            />
          ) : (
            <p>No estimate lines are cached for this estimate yet. Refresh estimates while online to update local detail data.</p>
          )}
        </section>
      )}

      <form className="panel form-grid" onSubmit={createCreditNote}>
        <label>
          Customer
          <select value={creditNoteForm.customer_id} onChange={(event) => setCreditNoteForm({ ...creditNoteForm, customer_id: event.target.value })} required>
            <option value="">Select customer</option>
            {customers.map((customer) => (
              <option key={customer.id} value={customer.id}>{customer.display_name}</option>
            ))}
          </select>
        </label>
        <label>
          Related invoice
          <select value={creditNoteForm.invoice_id} onChange={(event) => setCreditNoteForm({ ...creditNoteForm, invoice_id: event.target.value })}>
            <option value="">No specific invoice</option>
            {invoices.map((invoice) => (
              <option key={invoice.id} value={invoice.id}>{invoice.invoice_number}</option>
            ))}
          </select>
        </label>
        <input placeholder="Credit note number" value={creditNoteForm.credit_note_number} onChange={(event) => setCreditNoteForm({ ...creditNoteForm, credit_note_number: event.target.value })} required />
        <label>
          Issue date
          <input type="date" value={creditNoteForm.issue_date} onChange={(event) => setCreditNoteForm({ ...creditNoteForm, issue_date: event.target.value })} required />
        </label>
        <input placeholder="Currency" value={creditNoteForm.currency} onChange={(event) => setCreditNoteForm({ ...creditNoteForm, currency: event.target.value })} />
        <label>
          Pricing mode
          <select value={creditNoteForm.tax_inclusive ? "inclusive" : "exclusive"} onChange={(event) => setCreditNoteForm({ ...creditNoteForm, tax_inclusive: event.target.value === "inclusive" })}>
            <option value="exclusive">Tax exclusive</option>
            <option value="inclusive">Tax inclusive</option>
          </select>
        </label>
        <AccountSelect label="Accounts receivable" accounts={accounts} value={creditNoteForm.accounts_receivable_id} onChange={(value) => setCreditNoteForm({ ...creditNoteForm, accounts_receivable_id: value })} />
        <input placeholder="Line description" value={creditNoteForm.description} onChange={(event) => setCreditNoteForm({ ...creditNoteForm, description: event.target.value })} required />
        <input type="number" min="1" placeholder="Quantity millis" value={creditNoteForm.quantity_millis} onChange={(event) => setCreditNoteForm({ ...creditNoteForm, quantity_millis: Number(event.target.value) })} />
        <input type="number" min="0" placeholder="Unit price minor" value={creditNoteForm.unit_price_minor} onChange={(event) => setCreditNoteForm({ ...creditNoteForm, unit_price_minor: Number(event.target.value) })} required />
        <AccountSelect label="Income account" accounts={accounts} value={creditNoteForm.income_account_id} onChange={(value) => setCreditNoteForm({ ...creditNoteForm, income_account_id: value })} />
        <label>
          GST rate/group
          <select value={creditNoteForm.tax_target} onChange={(event) => setCreditNoteForm({ ...creditNoteForm, tax_target: event.target.value })}>
            <option value="">No tax</option>
            {taxGroups.map((group) => (
              <option key={group.id} value={`group:${group.id}`}>Group: {group.name}</option>
            ))}
            {taxRates.map((rate) => (
              <option key={rate.id} value={`rate:${rate.id}`}>Rate: {rate.name}</option>
            ))}
          </select>
        </label>
        <button disabled={!canCreateCreditNote || loading === "create-credit-note"}>
          {loading === "create-credit-note" ? "Creating..." : "Create credit note"}
        </button>
      </form>

      <section className="panel queue-panel">
        <div className="queue-heading">
          <div>
            <p className="eyebrow">Credits</p>
            <h3>Credit notes</h3>
            <p>Posting a credit note reduces revenue/output GST and credits accounts receivable.</p>
          </div>
          <strong>{creditNotes.length}</strong>
        </div>
        <section className="table-panel">
          <table>
            <thead>
              <tr>
                <th>Credit note</th>
                <th>Customer</th>
                <th>Issue</th>
                <th>Status</th>
                <th>Total</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {creditNotes.map((creditNote) => (
                <tr key={creditNote.id} className={focusRowClass(focusTarget, "credit_note", creditNote.id)}>
                  <td>{creditNote.credit_note_number}</td>
                  <td>{customerName(creditNote.customer_id)}</td>
                  <td>{creditNote.issue_date.slice(0, 10)}</td>
                  <td>{creditNote.status}</td>
                  <td>{formatMinorAsInr(creditNote.total_minor)}</td>
                  <td>
                    <button className="secondary compact" disabled={creditNote.status !== "draft" || loading === creditNote.id} onClick={() => void postCreditNote(creditNote.id)}>
                      {loading === creditNote.id ? "Posting..." : "Post"}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      </section>

      <form className="panel form-grid" onSubmit={recordCustomerPayment}>
        <label>
          Invoice
          <select value={paymentForm.invoice_id} onChange={(event) => setPaymentForm({ ...paymentForm, invoice_id: event.target.value })} required>
            <option value="">Select posted invoice</option>
            {invoices.filter((invoice) => invoice.status === "posted" || invoice.status === "paid").map((invoice) => (
              <option key={invoice.id} value={invoice.id}>{invoice.invoice_number} · {customerName(invoice.customer_id)} · {formatMinorAsInr(invoice.total_minor)}</option>
            ))}
          </select>
        </label>
        <input
          placeholder="Receipt number"
          value={paymentForm.payment_number}
          onChange={(event) => setPaymentForm({ ...paymentForm, payment_number: event.target.value })}
          required
        />
        <label>
          Payment date
          <input type="date" value={paymentForm.payment_date} onChange={(event) => setPaymentForm({ ...paymentForm, payment_date: event.target.value })} required />
        </label>
        <input
          placeholder="Method"
          value={paymentForm.payment_method}
          onChange={(event) => setPaymentForm({ ...paymentForm, payment_method: event.target.value })}
        />
        <input
          placeholder="Reference"
          value={paymentForm.reference}
          onChange={(event) => setPaymentForm({ ...paymentForm, reference: event.target.value })}
        />
        <input
          placeholder="Currency"
          value={paymentForm.currency}
          onChange={(event) => setPaymentForm({ ...paymentForm, currency: event.target.value })}
        />
        <input
          type="number"
          min="1"
          placeholder="Amount minor"
          value={paymentForm.amount_minor}
          onChange={(event) => setPaymentForm({ ...paymentForm, amount_minor: Number(event.target.value) })}
          required
        />
        <AccountSelect label="Deposit account" accounts={accounts} value={paymentForm.payment_account_id} onChange={(value) => setPaymentForm({ ...paymentForm, payment_account_id: value })} />
        <button disabled={!canRecordPayment || loading === "record-payment"}>
          {loading === "record-payment" ? "Recording..." : "Record receipt"}
        </button>
      </form>

      <form className="panel form-grid" onSubmit={createInvoice}>
        <label>
          Customer
          <select value={invoiceForm.customer_id} onChange={(event) => setInvoiceForm({ ...invoiceForm, customer_id: event.target.value })} required>
            <option value="">Select customer</option>
            {customers.map((customer) => (
              <option key={customer.id} value={customer.id}>{customer.display_name}</option>
            ))}
          </select>
        </label>
        <input
          placeholder="Invoice number"
          value={invoiceForm.invoice_number}
          onChange={(event) => setInvoiceForm({ ...invoiceForm, invoice_number: event.target.value })}
          required
        />
        <label>
          Issue date
          <input type="date" value={invoiceForm.issue_date} onChange={(event) => setInvoiceForm({ ...invoiceForm, issue_date: event.target.value })} required />
        </label>
        <label>
          Due date
          <input type="date" value={invoiceForm.due_date} onChange={(event) => setInvoiceForm({ ...invoiceForm, due_date: event.target.value })} required />
        </label>
        <input
          placeholder="Currency"
          value={invoiceForm.currency}
          onChange={(event) => setInvoiceForm({ ...invoiceForm, currency: event.target.value })}
        />
        <label>
          Pricing mode
          <select
            value={invoiceForm.tax_inclusive ? "inclusive" : "exclusive"}
            onChange={(event) => setInvoiceForm({ ...invoiceForm, tax_inclusive: event.target.value === "inclusive" })}
          >
            <option value="exclusive">Tax exclusive</option>
            <option value="inclusive">Tax inclusive</option>
          </select>
        </label>
        <AccountSelect
          label="Accounts receivable"
          accounts={accounts}
          value={invoiceForm.accounts_receivable_id}
          onChange={(value) => setInvoiceForm({ ...invoiceForm, accounts_receivable_id: value })}
        />
        <input
          placeholder="Line description"
          value={invoiceForm.description}
          onChange={(event) => setInvoiceForm({ ...invoiceForm, description: event.target.value })}
          required
        />
        <input
          type="number"
          min="1"
          placeholder="Quantity millis"
          value={invoiceForm.quantity_millis}
          onChange={(event) => setInvoiceForm({ ...invoiceForm, quantity_millis: Number(event.target.value) })}
        />
        <input
          type="number"
          min="0"
          placeholder="Unit price minor"
          value={invoiceForm.unit_price_minor}
          onChange={(event) => setInvoiceForm({ ...invoiceForm, unit_price_minor: Number(event.target.value) })}
          required
        />
        <AccountSelect
          label="Income account"
          accounts={accounts}
          value={invoiceForm.income_account_id}
          onChange={(value) => setInvoiceForm({ ...invoiceForm, income_account_id: value })}
        />
        <label>
          GST rate/group
          <select value={invoiceForm.tax_target} onChange={(event) => setInvoiceForm({ ...invoiceForm, tax_target: event.target.value })}>
            <option value="">No tax</option>
            {taxGroups.map((group) => (
              <option key={group.id} value={`group:${group.id}`}>Group: {group.name}</option>
            ))}
            {taxRates.map((rate) => (
              <option key={rate.id} value={`rate:${rate.id}`}>Rate: {rate.name}</option>
            ))}
          </select>
        </label>
        <button disabled={!canCreateInvoice || loading === "create-invoice"}>
          {loading === "create-invoice" ? "Creating..." : "Create draft invoice"}
        </button>
      </form>

      <section className="panel queue-panel">
        <div className="queue-heading">
          <div>
            <p className="eyebrow">Accounts receivable</p>
            <h3>Invoices</h3>
            <p>Draft invoices post to AR/revenue/GST. Posted invoices can receive payments, and paid invoices drop out of AR aging.</p>
          </div>
          <strong>{invoices.length}</strong>
        </div>
        <section className="table-panel">
          <table>
            <thead>
              <tr>
                <th>Invoice</th>
                <th>Customer</th>
                <th>Issue</th>
                <th>Due</th>
                <th>Status</th>
                <th>Subtotal</th>
                <th>Tax</th>
                <th>Total</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {invoices.map((invoice) => (
                <tr key={invoice.id} className={focusRowClass(focusTarget, "invoice", invoice.id)}>
                  <td>{invoice.invoice_number}</td>
                  <td>{customerName(invoice.customer_id)}</td>
                  <td>{invoice.issue_date?.slice(0, 10) ?? ""}</td>
                  <td>{invoice.due_date?.slice(0, 10) ?? ""}</td>
                  <td>{invoice.status}</td>
                  <td>{formatMinorAsInr(invoice.subtotal_minor)}</td>
                  <td>{formatMinorAsInr(invoice.tax_total_minor)}</td>
                  <td>{formatMinorAsInr(invoice.total_minor)}</td>
                  <td>
                    <div className="button-row compact">
                      <button
                        className="secondary compact"
                        disabled={invoice.status !== "draft" || loading === invoice.id}
                        onClick={() => void postInvoice(invoice.id)}
                      >
                        {loading === invoice.id ? "Posting..." : "Post"}
                      </button>
                      <button
                        className="secondary compact"
                        disabled={loading === `customer-payments-${invoice.id}`}
                        onClick={() => void loadCustomerPayments(invoice.id)}
                      >
                        {loading === `customer-payments-${invoice.id}` ? "Loading..." : "Payments"}
                      </button>
                      <button
                        className="secondary compact"
                        onClick={() => setSelectedInvoiceId(invoice.id)}
                      >
                        Details
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      </section>

      {selectedInvoice && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">Invoice detail</p>
              <h3>{selectedInvoice.invoice_number} · {customerName(selectedInvoice.customer_id)}</h3>
              <p>
                {selectedInvoice.status} · {selectedInvoice.issue_date?.slice(0, 10) ?? "-"} to {selectedInvoice.due_date?.slice(0, 10) ?? "-"}
                {" "}· {selectedInvoice.tax_inclusive ? "Tax inclusive" : "Tax exclusive"}
              </p>
            </div>
            <button className="secondary compact" onClick={() => setSelectedInvoiceId("")}>Close</button>
          </div>
          <div className="metric-grid">
            <div><span>Subtotal</span><strong>{formatMinor(selectedInvoice.subtotal_minor, selectedInvoice.currency ?? "INR")}</strong></div>
            <div><span>Tax</span><strong>{formatMinor(selectedInvoice.tax_total_minor, selectedInvoice.currency ?? "INR")}</strong></div>
            <div><span>Total</span><strong>{formatMinor(selectedInvoice.total_minor, selectedInvoice.currency ?? "INR")}</strong></div>
            <div><span>AR account</span><strong>{accountName(selectedInvoice.accounts_receivable_id)}</strong></div>
            <div><span>Journal</span><strong>{selectedInvoice.journal_transaction_id ?? "-"}</strong></div>
            <div><span>PDF attachment</span><strong>{selectedInvoice.pdf_attachment_id ?? "-"}</strong></div>
          </div>
          {selectedInvoice.lines && selectedInvoice.lines.length > 0 ? (
            <DataTable
              headers={["Description", "Qty", "Unit", "Income", "Tax", "Subtotal", "Tax amount", "Line total"]}
              rows={selectedInvoice.lines.map((line) => [
                line.description ?? "-",
                formatQuantityMillis(line.quantity_millis ?? 0),
                formatMinor(line.unit_price_minor ?? 0, selectedInvoice.currency ?? "INR"),
                accountName(line.income_account_id),
                taxName(line),
                formatMinor(line.line_subtotal_minor ?? 0, selectedInvoice.currency ?? "INR"),
                formatMinor(line.tax_amount_minor ?? 0, selectedInvoice.currency ?? "INR"),
                formatMinor(line.line_total_minor ?? 0, selectedInvoice.currency ?? "INR")
              ])}
            />
          ) : (
            <p>No invoice lines are cached for this invoice yet. Refresh invoices while online to update local detail data.</p>
          )}
        </section>
      )}
    </div>
  );
}

function ExpensesPage({
  api,
  accounts,
  vendors,
  expenses,
  bills,
  purchaseOrders,
  taxRates,
  taxGroups,
  focusTarget,
  onVendorsChanged,
  onExpensesChanged,
  onBillsChanged,
  onPurchaseOrdersChanged,
  onRefresh
}: {
  api: ApiClient;
  accounts: Account[];
  vendors: Vendor[];
  expenses: Expense[];
  bills: Bill[];
  purchaseOrders: PurchaseOrder[];
  taxRates: TaxRate[];
  taxGroups: TaxGroup[];
  focusTarget: FocusTarget | null;
  onVendorsChanged: (vendors: Vendor[]) => void;
  onExpensesChanged: (expenses: Expense[]) => void;
  onBillsChanged: (bills: Bill[]) => void;
  onPurchaseOrdersChanged: (purchaseOrders: PurchaseOrder[]) => void;
  onRefresh: () => Promise<void>;
}) {
  const [expenseError, setExpenseError] = useState("");
  const [expenseNotice, setExpenseNotice] = useState("");
  const [loading, setLoading] = useState<"vendors" | "expenses" | "create-vendor" | "create-expense" | string | null>(null);
  const [vendorPayments, setVendorPayments] = useState<VendorPayment[]>([]);
  const [vendorPaymentsBillId, setVendorPaymentsBillId] = useState("");
  const [resolvedVendorPaymentId, setResolvedVendorPaymentId] = useState("");
  const [selectedBillId, setSelectedBillId] = useState("");
  const [selectedPurchaseOrderId, setSelectedPurchaseOrderId] = useState("");
  const [vendorForm, setVendorForm] = useState({
    display_name: "",
    email: "",
    phone: "",
    billing_address: "",
    gstin: ""
  });
  const [expenseForm, setExpenseForm] = useState({
    vendor_id: "",
    expense_number: "",
    expense_date: new Date().toISOString().slice(0, 10),
    currency: "INR",
    tax_inclusive: false,
    amount_minor: 0,
    expense_account_id: "",
    payment_account_id: "",
    tax_target: "",
    reimbursable: false
  });
  const [billForm, setBillForm] = useState({
    vendor_id: "",
    bill_number: "",
    issue_date: new Date().toISOString().slice(0, 10),
    due_date: new Date().toISOString().slice(0, 10),
    currency: "INR",
    tax_inclusive: false,
    accounts_payable_id: "",
    description: "",
    quantity_millis: 1000,
    unit_price_minor: 0,
    expense_account_id: "",
    tax_target: ""
  });
  const [vendorPaymentForm, setVendorPaymentForm] = useState({
    bill_id: "",
    payment_number: "",
    payment_date: new Date().toISOString().slice(0, 10),
    payment_method: "bank_transfer",
    reference: "",
    currency: "INR",
    amount_minor: 0,
    payment_account_id: ""
  });
  const [purchaseOrderForm, setPurchaseOrderForm] = useState({
    vendor_id: "",
    purchase_order_number: "",
    issue_date: new Date().toISOString().slice(0, 10),
    expected_date: "",
    currency: "INR",
    tax_inclusive: false,
    description: "",
    quantity_millis: 1000,
    unit_price_minor: 0,
    expense_account_id: "",
    tax_target: ""
  });
  const draftExpenses = expenses.filter((expense) => expense.status === "draft").length;
  const postedExpenses = expenses.filter((expense) => expense.status === "posted").length;
  const draftBills = bills.filter((bill) => bill.status === "draft").length;
  const postedBills = bills.filter((bill) => bill.status === "posted").length;
  const draftPurchaseOrders = purchaseOrders.filter((purchaseOrder) => purchaseOrder.status === "draft").length;
  const canCreateVendor = Boolean(vendorForm.display_name.trim());
  const canCreateExpense = Boolean(
    expenseForm.expense_number.trim() &&
    expenseForm.amount_minor >= 0 &&
    expenseForm.expense_account_id &&
    expenseForm.payment_account_id
  );
  const canCreateBill = Boolean(
    billForm.vendor_id &&
    billForm.bill_number.trim() &&
    billForm.accounts_payable_id &&
    billForm.expense_account_id &&
    billForm.description.trim() &&
    billForm.unit_price_minor > 0
  );
  const canRecordVendorPayment = Boolean(
    vendorPaymentForm.bill_id &&
    vendorPaymentForm.payment_number.trim() &&
    vendorPaymentForm.amount_minor > 0 &&
    vendorPaymentForm.payment_account_id
  );
  const canCreatePurchaseOrder = Boolean(
    purchaseOrderForm.vendor_id &&
    purchaseOrderForm.purchase_order_number.trim() &&
    purchaseOrderForm.description.trim() &&
    purchaseOrderForm.expense_account_id &&
    purchaseOrderForm.unit_price_minor >= 0
  );

  async function refreshVendors() {
    setLoading("vendors");
    setExpenseError("");
    try {
      const nextVendors = await api.listVendors();
      onVendorsChanged(nextVendors);
      setExpenseNotice(`Loaded ${nextVendors.length} vendors.`);
    } catch (error) {
      setExpenseError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function refreshExpenses() {
    setLoading("expenses");
    setExpenseError("");
    try {
      const nextExpenses = await api.listExpenses();
      onExpensesChanged(nextExpenses);
      setExpenseNotice(`Loaded ${nextExpenses.length} expenses.`);
    } catch (error) {
      setExpenseError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function refreshBills() {
    setLoading("bills");
    setExpenseError("");
    try {
      const nextBills = await api.listBills();
      onBillsChanged(nextBills);
      setExpenseNotice(`Loaded ${nextBills.length} bills.`);
    } catch (error) {
      setExpenseError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function refreshPurchaseOrders() {
    setLoading("purchase-orders");
    setExpenseError("");
    try {
      const nextPurchaseOrders = await api.listPurchaseOrders();
      onPurchaseOrdersChanged(nextPurchaseOrders);
      setExpenseNotice(`Loaded ${nextPurchaseOrders.length} purchase orders.`);
    } catch (error) {
      setExpenseError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function createVendor(event: FormEvent) {
    event.preventDefault();
    if (!canCreateVendor) {
      return;
    }

    setLoading("create-vendor");
    setExpenseError("");
    try {
      const vendor = await api.createVendor(toVendorInput(vendorForm));
      onVendorsChanged([vendor, ...vendors]);
      setVendorForm({
        display_name: "",
        email: "",
        phone: "",
        billing_address: "",
        gstin: ""
      });
      setExpenseNotice(`Created vendor ${vendor.display_name}.`);
      await onRefresh();
    } catch (error) {
      setExpenseError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function createExpense(event: FormEvent) {
    event.preventDefault();
    if (!canCreateExpense) {
      return;
    }

    setLoading("create-expense");
    setExpenseError("");
    try {
      const expense = await api.createExpense(toExpenseInput(expenseForm));
      onExpensesChanged([expense, ...expenses]);
      setExpenseForm({
        ...expenseForm,
        vendor_id: "",
        expense_number: "",
        amount_minor: 0,
        tax_target: "",
        reimbursable: false
      });
      setExpenseNotice(`Created expense ${expense.expense_number}.`);
      await onRefresh();
    } catch (error) {
      setExpenseError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function postExpense(expenseId: string) {
    setLoading(expenseId);
    setExpenseError("");
    try {
      const postedExpense = await api.postExpense(expenseId);
      onExpensesChanged(expenses.map((expense) => expense.id === postedExpense.id ? postedExpense : expense));
      setExpenseNotice(`Posted expense ${postedExpense.expense_number} to the ledger.`);
      await onRefresh();
    } catch (error) {
      setExpenseError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function createBill(event: FormEvent) {
    event.preventDefault();
    if (!canCreateBill) {
      return;
    }
    setLoading("create-bill");
    setExpenseError("");
    try {
      const bill = await api.createBill(toBillInput(billForm));
      onBillsChanged([bill, ...bills]);
      setBillForm({ ...billForm, bill_number: "", description: "", unit_price_minor: 0, tax_target: "" });
      setExpenseNotice(`Created bill ${bill.bill_number}.`);
      await onRefresh();
    } catch (error) {
      setExpenseError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function createPurchaseOrder(event: FormEvent) {
    event.preventDefault();
    if (!canCreatePurchaseOrder) {
      return;
    }
    setLoading("create-purchase-order");
    setExpenseError("");
    try {
      const purchaseOrder = await api.createPurchaseOrder(toPurchaseOrderInput(purchaseOrderForm));
      onPurchaseOrdersChanged([purchaseOrder, ...purchaseOrders]);
      setPurchaseOrderForm({ ...purchaseOrderForm, purchase_order_number: "", description: "", unit_price_minor: 0, tax_target: "" });
      setExpenseNotice(`Created purchase order ${purchaseOrder.purchase_order_number}.`);
      await onRefresh();
    } catch (error) {
      setExpenseError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function postBill(billId: string) {
    setLoading(billId);
    setExpenseError("");
    try {
      const postedBill = await api.postBill(billId);
      onBillsChanged(bills.map((bill) => bill.id === postedBill.id ? postedBill : bill));
      setExpenseNotice(`Posted bill ${postedBill.bill_number} to accounts payable.`);
      await onRefresh();
    } catch (error) {
      setExpenseError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function recordVendorPayment(event: FormEvent) {
    event.preventDefault();
    if (!canRecordVendorPayment) {
      return;
    }
    setLoading("record-vendor-payment");
    setExpenseError("");
    try {
      await api.recordVendorPayment(vendorPaymentForm.bill_id, toRecordPaymentInput(vendorPaymentForm));
      const nextBills = await api.listBills();
      onBillsChanged(nextBills);
      setVendorPaymentForm({
        ...vendorPaymentForm,
        bill_id: "",
        payment_number: "",
        reference: "",
        amount_minor: 0
      });
      setExpenseNotice("Recorded vendor payment and updated AP status.");
      await onRefresh();
    } catch (error) {
      setExpenseError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function loadVendorPayments(billId: string) {
    if (!billId) {
      return;
    }
    setLoading(`vendor-payments-${billId}`);
    setExpenseError("");
    try {
      const payments = await api.listVendorPayments(billId);
      setVendorPayments(payments);
      setVendorPaymentsBillId(billId);
      setExpenseNotice(`Loaded ${payments.length} payment(s) for bill ${billNumber(billId)}.`);
    } catch (error) {
      setExpenseError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function loadFocusedVendorPaymentHistory(paymentId: string) {
    if (!paymentId || resolvedVendorPaymentId === paymentId) {
      return;
    }
    setLoading(`vendor-payment-focus-${paymentId}`);
    setExpenseError("");
    try {
      for (const bill of bills) {
        const payments = await api.listVendorPayments(bill.id);
        if (payments.some((payment) => payment.id === paymentId)) {
          setVendorPayments(payments);
          setVendorPaymentsBillId(bill.id);
          setResolvedVendorPaymentId(paymentId);
          setExpenseNotice(`Loaded payment history for bill ${bill.bill_number}.`);
          return;
        }
      }
      setExpenseNotice("Focused vendor payment was not found in the currently cached bill payment histories.");
    } catch (error) {
      setExpenseError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function convertPurchaseOrderToBill(purchaseOrder: PurchaseOrder) {
    const accountsPayable = defaultAccountsPayableAccount(accounts);
    if (!accountsPayable) {
      setExpenseError("Create or seed an accounts payable account before converting purchase orders.");
      return;
    }
    const billNumber = window.prompt("Bill number", purchaseOrder.purchase_order_number.replace(/^PO/i, "BILL"));
    if (!billNumber) {
      return;
    }
    const issueDate = new Date().toISOString().slice(0, 10);
    const dueDate = addDays(issueDate, 30);
    setLoading(purchaseOrder.id);
    setExpenseError("");
    try {
      const bill = await api.convertPurchaseOrderToBill(purchaseOrder.id, {
        bill_number: billNumber.trim(),
        issue_date: issueDate,
        due_date: dueDate,
        accounts_payable_id: accountsPayable.id
      });
      onBillsChanged([bill, ...bills]);
      const nextPurchaseOrders = await api.listPurchaseOrders();
      onPurchaseOrdersChanged(nextPurchaseOrders);
      setExpenseNotice(`Converted purchase order ${purchaseOrder.purchase_order_number} to draft bill ${bill.bill_number}.`);
      await onRefresh();
    } catch (error) {
      setExpenseError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  async function updatePurchaseOrderStatus(purchaseOrder: PurchaseOrder, status: PurchaseOrder["status"]) {
    setLoading(`${purchaseOrder.id}-${status}`);
    setExpenseError("");
    try {
      const updated = await api.updatePurchaseOrderStatus(purchaseOrder.id, status);
      onPurchaseOrdersChanged(purchaseOrders.map((candidate) => candidate.id === updated.id ? updated : candidate));
      setExpenseNotice(`Updated purchase order ${updated.purchase_order_number} to ${updated.status}.`);
      await onRefresh();
    } catch (error) {
      setExpenseError(errorMessage(error));
    } finally {
      setLoading(null);
    }
  }

  function vendorName(vendorId?: string | null) {
    return vendors.find((vendor) => vendor.id === vendorId)?.display_name ?? vendorId ?? "";
  }

  function billNumber(billId?: string) {
    return bills.find((bill) => bill.id === billId)?.bill_number ?? billId ?? "";
  }

  function accountName(accountId?: string | null) {
    if (!accountId) {
      return "-";
    }
    const account = accounts.find((candidate) => candidate.id === accountId);
    return account ? `${account.code} · ${account.name}` : accountId;
  }

  function taxName(line: BillLine) {
    if (line.tax_group_id) {
      return taxGroups.find((group) => group.id === line.tax_group_id)?.name ?? line.tax_group_id;
    }
    if (line.tax_rate_id) {
      return taxRates.find((rate) => rate.id === line.tax_rate_id)?.name ?? line.tax_rate_id;
    }
    return "No tax";
  }

  function purchaseOrderTaxName(line: PurchaseOrderLine) {
    if (line.tax_group_id) {
      return taxGroups.find((group) => group.id === line.tax_group_id)?.name ?? line.tax_group_id;
    }
    if (line.tax_rate_id) {
      return taxRates.find((rate) => rate.id === line.tax_rate_id)?.name ?? line.tax_rate_id;
    }
    return "No tax";
  }

  const selectedBill = bills.find((bill) => bill.id === selectedBillId) ?? null;
  const selectedPurchaseOrder = purchaseOrders.find((purchaseOrder) => purchaseOrder.id === selectedPurchaseOrderId) ?? null;

  useEffect(() => {
    if (focusTarget?.documentType !== "vendor_payment") {
      return;
    }
    void loadFocusedVendorPaymentHistory(focusTarget.documentId);
  }, [focusTarget, bills, resolvedVendorPaymentId]);

  return (
    <div className="stack">
      <section className="panel offline-panel">
        <div>
          <p className="eyebrow">Expenses</p>
          <h3>Vendor and expense control</h3>
          <p>
            Cached locally: {vendors.length} vendors, {expenses.length} paid/spend records, and {bills.length} AP bills.
            Expenses: {draftExpenses} draft/{postedExpenses} posted. Bills: {draftBills} draft/{postedBills} posted.
            Purchase orders: {purchaseOrders.length} total/{draftPurchaseOrders} draft.
          </p>
        </div>
        <div className="button-row">
          <button className="secondary" disabled={loading === "vendors"} onClick={() => void refreshVendors()}>
            {loading === "vendors" ? "Loading..." : "Refresh vendors"}
          </button>
          <button className="secondary" disabled={loading === "expenses"} onClick={() => void refreshExpenses()}>
            {loading === "expenses" ? "Loading..." : "Refresh expenses"}
          </button>
          <button className="secondary" disabled={loading === "bills"} onClick={() => void refreshBills()}>
            {loading === "bills" ? "Loading..." : "Refresh bills"}
          </button>
          <button className="secondary" disabled={loading === "purchase-orders"} onClick={() => void refreshPurchaseOrders()}>
            {loading === "purchase-orders" ? "Loading..." : "Refresh POs"}
          </button>
        </div>
      </section>

      {expenseError && <div className="alert error">{expenseError}</div>}
      {expenseNotice && <div className="alert success">{expenseNotice}</div>}
      <FocusNotice focusTarget={focusTarget} />

      {vendorPayments.length > 0 && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">Payment history</p>
              <h3>{billNumber(vendorPaymentsBillId)}</h3>
              <p>Vendor payments loaded from the selected bill, with drilldown-sourced payments highlighted.</p>
            </div>
            <strong>{vendorPayments.length}</strong>
          </div>
          <section className="table-panel">
            <table>
              <thead>
                <tr>
                  <th>Payment</th>
                  <th>Date</th>
                  <th>Method</th>
                  <th>Reference</th>
                  <th>Amount</th>
                  <th>Journal</th>
                </tr>
              </thead>
              <tbody>
                {vendorPayments.map((payment) => (
                  <tr key={payment.id} className={focusRowClass(focusTarget, "vendor_payment", payment.id)}>
                    <td>{payment.payment_number}</td>
                    <td>{payment.payment_date.slice(0, 10)}</td>
                    <td>{payment.payment_method || "-"}</td>
                    <td>{payment.reference || "-"}</td>
                    <td>{formatMinor(payment.amount_minor, payment.currency)}</td>
                    <td>{payment.journal_transaction_id.slice(0, 8)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>
        </section>
      )}

      <form className="panel form-grid" onSubmit={createVendor}>
        <input placeholder="Display name" value={vendorForm.display_name} onChange={(event) => setVendorForm({ ...vendorForm, display_name: event.target.value })} required />
        <input placeholder="Email" value={vendorForm.email} onChange={(event) => setVendorForm({ ...vendorForm, email: event.target.value })} />
        <input placeholder="Phone" value={vendorForm.phone} onChange={(event) => setVendorForm({ ...vendorForm, phone: event.target.value })} />
        <input placeholder="GSTIN" value={vendorForm.gstin} onChange={(event) => setVendorForm({ ...vendorForm, gstin: event.target.value })} />
        <input placeholder="Billing address" value={vendorForm.billing_address} onChange={(event) => setVendorForm({ ...vendorForm, billing_address: event.target.value })} />
        <button disabled={!canCreateVendor || loading === "create-vendor"}>
          {loading === "create-vendor" ? "Creating..." : "Create vendor"}
        </button>
      </form>

      <form className="panel form-grid" onSubmit={createPurchaseOrder}>
        <label>
          Vendor
          <select value={purchaseOrderForm.vendor_id} onChange={(event) => setPurchaseOrderForm({ ...purchaseOrderForm, vendor_id: event.target.value })} required>
            <option value="">Select vendor</option>
            {vendors.map((vendor) => (
              <option key={vendor.id} value={vendor.id}>{vendor.display_name}</option>
            ))}
          </select>
        </label>
        <input placeholder="PO number" value={purchaseOrderForm.purchase_order_number} onChange={(event) => setPurchaseOrderForm({ ...purchaseOrderForm, purchase_order_number: event.target.value })} required />
        <label>
          Issue date
          <input type="date" value={purchaseOrderForm.issue_date} onChange={(event) => setPurchaseOrderForm({ ...purchaseOrderForm, issue_date: event.target.value })} required />
        </label>
        <label>
          Expected date
          <input type="date" value={purchaseOrderForm.expected_date} onChange={(event) => setPurchaseOrderForm({ ...purchaseOrderForm, expected_date: event.target.value })} />
        </label>
        <input placeholder="Currency" value={purchaseOrderForm.currency} onChange={(event) => setPurchaseOrderForm({ ...purchaseOrderForm, currency: event.target.value })} />
        <label>
          Pricing mode
          <select value={purchaseOrderForm.tax_inclusive ? "inclusive" : "exclusive"} onChange={(event) => setPurchaseOrderForm({ ...purchaseOrderForm, tax_inclusive: event.target.value === "inclusive" })}>
            <option value="exclusive">Tax exclusive</option>
            <option value="inclusive">Tax inclusive</option>
          </select>
        </label>
        <input placeholder="Line description" value={purchaseOrderForm.description} onChange={(event) => setPurchaseOrderForm({ ...purchaseOrderForm, description: event.target.value })} required />
        <input type="number" min="1" placeholder="Quantity millis" value={purchaseOrderForm.quantity_millis} onChange={(event) => setPurchaseOrderForm({ ...purchaseOrderForm, quantity_millis: Number(event.target.value) })} />
        <input type="number" min="0" placeholder="Unit price minor" value={purchaseOrderForm.unit_price_minor} onChange={(event) => setPurchaseOrderForm({ ...purchaseOrderForm, unit_price_minor: Number(event.target.value) })} required />
        <AccountSelect label="Expense account" accounts={accounts} value={purchaseOrderForm.expense_account_id} onChange={(value) => setPurchaseOrderForm({ ...purchaseOrderForm, expense_account_id: value })} />
        <label>
          GST rate/group
          <select value={purchaseOrderForm.tax_target} onChange={(event) => setPurchaseOrderForm({ ...purchaseOrderForm, tax_target: event.target.value })}>
            <option value="">No tax</option>
            {taxGroups.map((group) => (
              <option key={group.id} value={`group:${group.id}`}>Group: {group.name}</option>
            ))}
            {taxRates.map((rate) => (
              <option key={rate.id} value={`rate:${rate.id}`}>Rate: {rate.name}</option>
            ))}
          </select>
        </label>
        <button disabled={!canCreatePurchaseOrder || loading === "create-purchase-order"}>
          {loading === "create-purchase-order" ? "Creating..." : "Create purchase order"}
        </button>
      </form>

      <section className="panel queue-panel">
        <div className="queue-heading">
          <div>
            <p className="eyebrow">Procurement</p>
            <h3>Purchase orders</h3>
            <p>Purchase orders are non-posting documents used before vendor bills.</p>
          </div>
          <strong>{purchaseOrders.length}</strong>
        </div>
        <DataTable
          headers={["PO", "Vendor", "Issue", "Expected", "Status", "Total", "Action"]}
          rows={purchaseOrders.map((purchaseOrder) => [
            purchaseOrder.purchase_order_number,
            vendorName(purchaseOrder.vendor_id),
            purchaseOrder.issue_date.slice(0, 10),
            purchaseOrder.expected_date?.slice(0, 10) ?? "",
            purchaseOrder.status,
            formatMinorAsInr(purchaseOrder.total_minor),
            purchaseOrder.status === "converted" || purchaseOrder.status === "void" ? "" : "Convert available"
          ])}
        />
        <div className="button-row">
          {purchaseOrders.filter((purchaseOrder) => purchaseOrder.status !== "converted" && purchaseOrder.status !== "void").slice(0, 5).map((purchaseOrder) => (
            <span key={purchaseOrder.id} className="button-row">
              {purchaseOrder.status === "draft" && (
                <button className="secondary compact" disabled={loading === `${purchaseOrder.id}-sent`} onClick={() => void updatePurchaseOrderStatus(purchaseOrder, "sent")}>
                  {loading === `${purchaseOrder.id}-sent` ? "Sending..." : `Send ${purchaseOrder.purchase_order_number}`}
                </button>
              )}
              {(purchaseOrder.status === "draft" || purchaseOrder.status === "sent") && (
                <button className="secondary compact" disabled={loading === `${purchaseOrder.id}-approved`} onClick={() => void updatePurchaseOrderStatus(purchaseOrder, "approved")}>
                  {loading === `${purchaseOrder.id}-approved` ? "Approving..." : "Approve"}
                </button>
              )}
              <button className="secondary compact" disabled={loading === purchaseOrder.id} onClick={() => void convertPurchaseOrderToBill(purchaseOrder)}>
                {loading === purchaseOrder.id ? "Converting..." : `Convert ${purchaseOrder.purchase_order_number}`}
              </button>
              <button className="secondary compact" disabled={loading === `${purchaseOrder.id}-void`} onClick={() => void updatePurchaseOrderStatus(purchaseOrder, "void")}>
                {loading === `${purchaseOrder.id}-void` ? "Voiding..." : "Void"}
              </button>
              <button className="secondary compact" onClick={() => setSelectedPurchaseOrderId(purchaseOrder.id)}>
                Details
              </button>
            </span>
          ))}
        </div>
      </section>

      {selectedPurchaseOrder && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">Purchase order detail</p>
              <h3>{selectedPurchaseOrder.purchase_order_number} · {vendorName(selectedPurchaseOrder.vendor_id)}</h3>
              <p>
                {selectedPurchaseOrder.status} · {selectedPurchaseOrder.issue_date.slice(0, 10)}
                {selectedPurchaseOrder.expected_date ? ` to ${selectedPurchaseOrder.expected_date.slice(0, 10)}` : ""}
                {" "}· {selectedPurchaseOrder.tax_inclusive ? "Tax inclusive" : "Tax exclusive"}
              </p>
            </div>
            <button className="secondary compact" onClick={() => setSelectedPurchaseOrderId("")}>Close</button>
          </div>
          <div className="metric-grid">
            <div><span>Subtotal</span><strong>{formatMinor(selectedPurchaseOrder.subtotal_minor, selectedPurchaseOrder.currency)}</strong></div>
            <div><span>Tax</span><strong>{formatMinor(selectedPurchaseOrder.tax_total_minor, selectedPurchaseOrder.currency)}</strong></div>
            <div><span>Total</span><strong>{formatMinor(selectedPurchaseOrder.total_minor, selectedPurchaseOrder.currency)}</strong></div>
          </div>
          {selectedPurchaseOrder.lines && selectedPurchaseOrder.lines.length > 0 ? (
            <DataTable
              headers={["Description", "Qty", "Unit", "Expense", "Tax", "Subtotal", "Tax amount", "Line total"]}
              rows={selectedPurchaseOrder.lines.map((line) => [
                line.description ?? "-",
                formatQuantityMillis(line.quantity_millis ?? 0),
                formatMinor(line.unit_price_minor ?? 0, selectedPurchaseOrder.currency),
                accountName(line.expense_account_id),
                purchaseOrderTaxName(line),
                formatMinor(line.line_subtotal_minor ?? 0, selectedPurchaseOrder.currency),
                formatMinor(line.tax_amount_minor ?? 0, selectedPurchaseOrder.currency),
                formatMinor(line.line_total_minor ?? 0, selectedPurchaseOrder.currency)
              ])}
            />
          ) : (
            <p>No purchase order lines are cached for this purchase order yet. Refresh purchase orders while online to update local detail data.</p>
          )}
        </section>
      )}

      <form className="panel form-grid" onSubmit={createBill}>
        <label>
          Vendor
          <select value={billForm.vendor_id} onChange={(event) => setBillForm({ ...billForm, vendor_id: event.target.value })} required>
            <option value="">Select vendor</option>
            {vendors.map((vendor) => (
              <option key={vendor.id} value={vendor.id}>{vendor.display_name}</option>
            ))}
          </select>
        </label>
        <input placeholder="Bill number" value={billForm.bill_number} onChange={(event) => setBillForm({ ...billForm, bill_number: event.target.value })} required />
        <label>
          Issue date
          <input type="date" value={billForm.issue_date} onChange={(event) => setBillForm({ ...billForm, issue_date: event.target.value })} required />
        </label>
        <label>
          Due date
          <input type="date" value={billForm.due_date} onChange={(event) => setBillForm({ ...billForm, due_date: event.target.value })} required />
        </label>
        <input placeholder="Currency" value={billForm.currency} onChange={(event) => setBillForm({ ...billForm, currency: event.target.value })} />
        <label>
          Pricing mode
          <select value={billForm.tax_inclusive ? "inclusive" : "exclusive"} onChange={(event) => setBillForm({ ...billForm, tax_inclusive: event.target.value === "inclusive" })}>
            <option value="exclusive">Tax exclusive</option>
            <option value="inclusive">Tax inclusive</option>
          </select>
        </label>
        <AccountSelect label="Accounts payable" accounts={accounts} value={billForm.accounts_payable_id} onChange={(value) => setBillForm({ ...billForm, accounts_payable_id: value })} />
        <input placeholder="Line description" value={billForm.description} onChange={(event) => setBillForm({ ...billForm, description: event.target.value })} required />
        <input type="number" min="1" placeholder="Quantity millis" value={billForm.quantity_millis} onChange={(event) => setBillForm({ ...billForm, quantity_millis: Number(event.target.value) })} />
        <input type="number" min="0" placeholder="Unit price minor" value={billForm.unit_price_minor} onChange={(event) => setBillForm({ ...billForm, unit_price_minor: Number(event.target.value) })} required />
        <AccountSelect label="Expense account" accounts={accounts} value={billForm.expense_account_id} onChange={(value) => setBillForm({ ...billForm, expense_account_id: value })} />
        <label>
          GST rate/group
          <select value={billForm.tax_target} onChange={(event) => setBillForm({ ...billForm, tax_target: event.target.value })}>
            <option value="">No tax</option>
            {taxGroups.map((group) => (
              <option key={group.id} value={`group:${group.id}`}>Group: {group.name}</option>
            ))}
            {taxRates.map((rate) => (
              <option key={rate.id} value={`rate:${rate.id}`}>Rate: {rate.name}</option>
            ))}
          </select>
        </label>
        <button disabled={!canCreateBill || loading === "create-bill"}>
          {loading === "create-bill" ? "Creating..." : "Create draft bill"}
        </button>
      </form>

      <form className="panel form-grid" onSubmit={recordVendorPayment}>
        <label>
          Bill
          <select value={vendorPaymentForm.bill_id} onChange={(event) => setVendorPaymentForm({ ...vendorPaymentForm, bill_id: event.target.value })} required>
            <option value="">Select posted bill</option>
            {bills.filter((bill) => bill.status === "posted" || bill.status === "paid").map((bill) => (
              <option key={bill.id} value={bill.id}>{bill.bill_number} · {vendorName(bill.vendor_id)} · {formatMinorAsInr(bill.total_minor)}</option>
            ))}
          </select>
        </label>
        <input placeholder="Payment number" value={vendorPaymentForm.payment_number} onChange={(event) => setVendorPaymentForm({ ...vendorPaymentForm, payment_number: event.target.value })} required />
        <label>
          Payment date
          <input type="date" value={vendorPaymentForm.payment_date} onChange={(event) => setVendorPaymentForm({ ...vendorPaymentForm, payment_date: event.target.value })} required />
        </label>
        <input placeholder="Method" value={vendorPaymentForm.payment_method} onChange={(event) => setVendorPaymentForm({ ...vendorPaymentForm, payment_method: event.target.value })} />
        <input placeholder="Reference" value={vendorPaymentForm.reference} onChange={(event) => setVendorPaymentForm({ ...vendorPaymentForm, reference: event.target.value })} />
        <input placeholder="Currency" value={vendorPaymentForm.currency} onChange={(event) => setVendorPaymentForm({ ...vendorPaymentForm, currency: event.target.value })} />
        <input type="number" min="1" placeholder="Amount minor" value={vendorPaymentForm.amount_minor} onChange={(event) => setVendorPaymentForm({ ...vendorPaymentForm, amount_minor: Number(event.target.value) })} required />
        <AccountSelect label="Payment account" accounts={accounts} value={vendorPaymentForm.payment_account_id} onChange={(value) => setVendorPaymentForm({ ...vendorPaymentForm, payment_account_id: value })} />
        <button disabled={!canRecordVendorPayment || loading === "record-vendor-payment"}>
          {loading === "record-vendor-payment" ? "Recording..." : "Record vendor payment"}
        </button>
      </form>

      <section className="panel queue-panel">
        <div className="queue-heading">
          <div>
            <p className="eyebrow">Accounts payable</p>
            <h3>Bills</h3>
            <p>Draft bills post to expense/input GST and accounts payable, then feed AP aging.</p>
          </div>
          <strong>{bills.length}</strong>
        </div>
        <section className="table-panel">
          <table>
            <thead>
              <tr>
                <th>Bill</th>
                <th>Vendor</th>
                <th>Issue</th>
                <th>Due</th>
                <th>Status</th>
                <th>Subtotal</th>
                <th>Tax</th>
                <th>Total</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {bills.map((bill) => (
                <tr key={bill.id} className={focusRowClass(focusTarget, "bill", bill.id)}>
                  <td>{bill.bill_number}</td>
                  <td>{vendorName(bill.vendor_id)}</td>
                  <td>{bill.issue_date.slice(0, 10)}</td>
                  <td>{bill.due_date.slice(0, 10)}</td>
                  <td>{bill.status}</td>
                  <td>{formatMinorAsInr(bill.subtotal_minor)}</td>
                  <td>{formatMinorAsInr(bill.tax_total_minor)}</td>
                  <td>{formatMinorAsInr(bill.total_minor)}</td>
                  <td>
                    <div className="button-row compact">
                      <button
                        className="secondary compact"
                        disabled={bill.status !== "draft" || loading === bill.id}
                        onClick={() => void postBill(bill.id)}
                      >
                        {loading === bill.id ? "Posting..." : "Post"}
                      </button>
                      <button
                        className="secondary compact"
                        disabled={loading === `vendor-payments-${bill.id}`}
                        onClick={() => void loadVendorPayments(bill.id)}
                      >
                        {loading === `vendor-payments-${bill.id}` ? "Loading..." : "Payments"}
                      </button>
                      <button
                        className="secondary compact"
                        onClick={() => setSelectedBillId(bill.id)}
                      >
                        Details
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      </section>

      {selectedBill && (
        <section className="panel queue-panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">Bill detail</p>
              <h3>{selectedBill.bill_number} · {vendorName(selectedBill.vendor_id)}</h3>
              <p>
                {selectedBill.status} · {selectedBill.issue_date.slice(0, 10)} to {selectedBill.due_date.slice(0, 10)}
                {" "}· {selectedBill.tax_inclusive ? "Tax inclusive" : "Tax exclusive"}
              </p>
            </div>
            <button className="secondary compact" onClick={() => setSelectedBillId("")}>Close</button>
          </div>
          <div className="metric-grid">
            <div><span>Subtotal</span><strong>{formatMinor(selectedBill.subtotal_minor, selectedBill.currency)}</strong></div>
            <div><span>Tax</span><strong>{formatMinor(selectedBill.tax_total_minor, selectedBill.currency)}</strong></div>
            <div><span>Total</span><strong>{formatMinor(selectedBill.total_minor, selectedBill.currency)}</strong></div>
            <div><span>AP account</span><strong>{accountName(selectedBill.accounts_payable_id)}</strong></div>
            <div><span>Journal</span><strong>{selectedBill.journal_transaction_id ?? "-"}</strong></div>
            <div><span>Document attachment</span><strong>{selectedBill.document_attachment_id ?? "-"}</strong></div>
          </div>
          {selectedBill.lines && selectedBill.lines.length > 0 ? (
            <DataTable
              headers={["Description", "Qty", "Unit", "Expense", "Tax", "Subtotal", "Tax amount", "Line total"]}
              rows={selectedBill.lines.map((line) => [
                line.description,
                formatQuantityMillis(line.quantity_millis),
                formatMinor(line.unit_price_minor, selectedBill.currency),
                accountName(line.expense_account_id),
                taxName(line),
                formatMinor(line.line_subtotal_minor, selectedBill.currency),
                formatMinor(line.tax_amount_minor, selectedBill.currency),
                formatMinor(line.line_total_minor, selectedBill.currency)
              ])}
            />
          ) : (
            <p>No bill lines are cached for this bill yet. Refresh bills while online to update local detail data.</p>
          )}
        </section>
      )}

      <section className="panel queue-panel">
        <div className="queue-heading">
          <div>
            <p className="eyebrow">Vendors</p>
            <h3>Vendor master</h3>
            <p>Vendor GSTIN and billing details are cached locally after refresh for offline review.</p>
          </div>
          <strong>{vendors.length}</strong>
        </div>
        <DataTable
          headers={["Name", "Email", "Phone", "GSTIN", "Active"]}
          rows={vendors.map((vendor) => [
            vendor.display_name,
            vendor.email ?? "",
            vendor.phone ?? "",
            vendor.gstin ?? "",
            vendor.is_active ? "Yes" : "No"
          ])}
        />
      </section>

      <form className="panel form-grid" onSubmit={createExpense}>
        <label>
          Vendor
          <select value={expenseForm.vendor_id} onChange={(event) => setExpenseForm({ ...expenseForm, vendor_id: event.target.value })}>
            <option value="">No vendor</option>
            {vendors.map((vendor) => (
              <option key={vendor.id} value={vendor.id}>{vendor.display_name}</option>
            ))}
          </select>
        </label>
        <input placeholder="Expense number" value={expenseForm.expense_number} onChange={(event) => setExpenseForm({ ...expenseForm, expense_number: event.target.value })} required />
        <label>
          Expense date
          <input type="date" value={expenseForm.expense_date} onChange={(event) => setExpenseForm({ ...expenseForm, expense_date: event.target.value })} required />
        </label>
        <input placeholder="Currency" value={expenseForm.currency} onChange={(event) => setExpenseForm({ ...expenseForm, currency: event.target.value })} />
        <label>
          Pricing mode
          <select value={expenseForm.tax_inclusive ? "inclusive" : "exclusive"} onChange={(event) => setExpenseForm({ ...expenseForm, tax_inclusive: event.target.value === "inclusive" })}>
            <option value="exclusive">Tax exclusive</option>
            <option value="inclusive">Tax inclusive</option>
          </select>
        </label>
        <input type="number" min="0" placeholder="Amount minor" value={expenseForm.amount_minor} onChange={(event) => setExpenseForm({ ...expenseForm, amount_minor: Number(event.target.value) })} required />
        <AccountSelect label="Expense account" accounts={accounts} value={expenseForm.expense_account_id} onChange={(value) => setExpenseForm({ ...expenseForm, expense_account_id: value })} />
        <AccountSelect label="Payment account" accounts={accounts} value={expenseForm.payment_account_id} onChange={(value) => setExpenseForm({ ...expenseForm, payment_account_id: value })} />
        <label>
          GST rate/group
          <select value={expenseForm.tax_target} onChange={(event) => setExpenseForm({ ...expenseForm, tax_target: event.target.value })}>
            <option value="">No tax</option>
            {taxGroups.map((group) => (
              <option key={group.id} value={`group:${group.id}`}>Group: {group.name}</option>
            ))}
            {taxRates.map((rate) => (
              <option key={rate.id} value={`rate:${rate.id}`}>Rate: {rate.name}</option>
            ))}
          </select>
        </label>
        <label>
          Reimbursable
          <select value={expenseForm.reimbursable ? "yes" : "no"} onChange={(event) => setExpenseForm({ ...expenseForm, reimbursable: event.target.value === "yes" })}>
            <option value="no">No</option>
            <option value="yes">Yes</option>
          </select>
        </label>
        <button disabled={!canCreateExpense || loading === "create-expense"}>
          {loading === "create-expense" ? "Creating..." : "Create draft expense"}
        </button>
      </form>

      <section className="panel queue-panel">
        <div className="queue-heading">
          <div>
            <p className="eyebrow">Spend</p>
            <h3>Expenses</h3>
            <p>Draft expenses can be posted from here to create expense/payment ledger entries.</p>
          </div>
          <strong>{expenses.length}</strong>
        </div>
        <section className="table-panel">
          <table>
            <thead>
              <tr>
                <th>Expense</th>
                <th>Vendor</th>
                <th>Date</th>
                <th>Status</th>
                <th>Subtotal</th>
                <th>Tax</th>
                <th>Total</th>
                <th>Reimb.</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {expenses.map((expense) => (
                <tr key={expense.id} className={focusRowClass(focusTarget, "expense", expense.id)}>
                  <td>{expense.expense_number}</td>
                  <td>{vendorName(expense.vendor_id)}</td>
                  <td>{expense.expense_date.slice(0, 10)}</td>
                  <td>{expense.status}</td>
                  <td>{formatMinorAsInr(expense.subtotal_minor)}</td>
                  <td>{formatMinorAsInr(expense.tax_total_minor)}</td>
                  <td>{formatMinorAsInr(expense.total_minor)}</td>
                  <td>{expense.reimbursable ? "Yes" : "No"}</td>
                  <td>
                    <button
                      className="secondary compact"
                      disabled={expense.status !== "draft" || loading === expense.id}
                      onClick={() => void postExpense(expense.id)}
                    >
                      {loading === expense.id ? "Posting..." : "Post"}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      </section>
    </div>
  );
}

function DocumentsPage({
  api,
  attachments,
  onAttachmentsChanged,
  onRefresh
}: {
  api: ApiClient;
  attachments: Attachment[];
  onAttachmentsChanged: (attachments: Attachment[]) => void;
  onRefresh: () => Promise<void>;
}) {
  const [metadataForm, setMetadataForm] = useState<CreateAttachmentInput>({
    file_name: "",
    content_type: "",
    storage_driver: "local",
    storage_key: "",
    size_bytes: 0
  });
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [loading, setLoading] = useState("");
  const [documentError, setDocumentError] = useState("");
  const [documentNotice, setDocumentNotice] = useState("");
  const canCreateMetadata = Boolean(metadataForm.file_name.trim() && metadataForm.storage_key.trim());
  const canUpload = Boolean(selectedFile);

  async function refreshAttachments() {
    setLoading("refresh");
    setDocumentError("");
    try {
      const nextAttachments = await api.listAttachments();
      onAttachmentsChanged(nextAttachments);
      setDocumentNotice(`Loaded ${nextAttachments.length} attachment metadata record(s).`);
    } catch (error) {
      setDocumentError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function createAttachment(event: FormEvent) {
    event.preventDefault();
    if (!canCreateMetadata) {
      return;
    }
    setLoading("create-metadata");
    setDocumentError("");
    try {
      const attachment = await api.createAttachment(toAttachmentInput(metadataForm));
      onAttachmentsChanged([attachment, ...attachments]);
      setMetadataForm({ file_name: "", content_type: "", storage_driver: "local", storage_key: "", size_bytes: 0 });
      setDocumentNotice(`Attachment metadata saved for ${attachment.file_name}.`);
      await onRefresh();
    } catch (error) {
      setDocumentError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function uploadAttachment(event: FormEvent) {
    event.preventDefault();
    if (!selectedFile) {
      return;
    }
    setLoading("upload");
    setDocumentError("");
    try {
      const attachment = await api.uploadAttachment(selectedFile);
      onAttachmentsChanged([attachment, ...attachments]);
      setSelectedFile(null);
      setDocumentNotice(`Uploaded ${attachment.file_name}.`);
      await onRefresh();
    } catch (error) {
      setDocumentError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  return (
    <div className="stack">
      <section className="panel offline-panel">
        <div>
          <p className="eyebrow">Documents</p>
          <h3>Receipts, invoices, and generated files</h3>
          <p>Create attachment metadata for external storage workflows or upload local files to the backend storage driver.</p>
        </div>
        <button className="secondary" disabled={loading === "refresh"} onClick={() => void refreshAttachments()}>
          {loading === "refresh" ? "Refreshing..." : "Refresh attachments"}
        </button>
      </section>

      {documentError && <div className="alert error">{documentError}</div>}
      {documentNotice && <div className="alert success">{documentNotice}</div>}

      <form className="panel form-grid" onSubmit={uploadAttachment}>
        <label>
          Upload local file
          <input type="file" onChange={(event) => setSelectedFile(event.target.files?.[0] ?? null)} />
        </label>
        <div className="metric-card">
          <span>Selected file</span>
          <strong>{selectedFile ? selectedFile.name : "None"}</strong>
        </div>
        <button disabled={!canUpload || loading === "upload"}>{loading === "upload" ? "Uploading..." : "Upload file"}</button>
      </form>

      <form className="panel form-grid" onSubmit={createAttachment}>
        <input placeholder="File name" value={metadataForm.file_name} onChange={(event) => setMetadataForm({ ...metadataForm, file_name: event.target.value })} />
        <input placeholder="Content type" value={metadataForm.content_type ?? ""} onChange={(event) => setMetadataForm({ ...metadataForm, content_type: event.target.value })} />
        <input placeholder="Storage driver" value={metadataForm.storage_driver ?? ""} onChange={(event) => setMetadataForm({ ...metadataForm, storage_driver: event.target.value })} />
        <input placeholder="Storage key" value={metadataForm.storage_key} onChange={(event) => setMetadataForm({ ...metadataForm, storage_key: event.target.value })} />
        <label>
          Size bytes
          <input type="number" min={0} value={metadataForm.size_bytes ?? 0} onChange={(event) => setMetadataForm({ ...metadataForm, size_bytes: Number(event.target.value) })} />
        </label>
        <button disabled={!canCreateMetadata || loading === "create-metadata"}>{loading === "create-metadata" ? "Saving..." : "Create metadata"}</button>
      </form>

      <section className="panel queue-panel">
        <div className="queue-heading">
          <div>
            <p className="eyebrow">Attachment catalog</p>
            <h3>Stored documents</h3>
            <p>Metadata is cached locally for offline lookup. Download requires a live authenticated API session.</p>
          </div>
          <strong>{attachments.length}</strong>
        </div>
        <section className="table-panel">
          <table>
            <thead>
              <tr>
                <th>File</th>
                <th>Type</th>
                <th>Driver</th>
                <th>Storage key</th>
                <th>Size</th>
                <th>Download</th>
              </tr>
            </thead>
            <tbody>
              {attachments.map((attachment) => (
                <tr key={attachment.id}>
                  <td>{attachment.file_name}</td>
                  <td>{attachment.content_type || "-"}</td>
                  <td>{attachment.storage_driver}</td>
                  <td>{attachment.storage_key}</td>
                  <td>{formatBytes(attachment.size_bytes)}</td>
                  <td>
                    <a href={api.attachmentDownloadUrl(attachment.id)} target="_blank" rel="noreferrer">Download</a>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      </section>
    </div>
  );
}

function ReconciliationPage({
  api,
  accounts,
  transactions,
  statementLines,
  onStatementLinesChanged,
  onRefresh
}: {
  api: ApiClient;
  accounts: Account[];
  transactions: JournalTransaction[];
  statementLines: BankStatementLine[];
  onStatementLinesChanged: (lines: BankStatementLine[]) => void;
  onRefresh: () => Promise<void>;
}) {
  const defaultBankAccountId = accounts.find((account) => account.subtype === "bank" || account.subtype === "cash" || account.type === "asset")?.id ?? "";
  const [accountId, setAccountId] = useState(defaultBankAccountId);
  const [importForm, setImportForm] = useState({ file_name: "manual-bank-import.csv", format: "csv" });
  const [csvForm, setCsvForm] = useState({
    csv_content: "",
    date_columns: "date,posted date,value date,transaction date",
    description_columns: "description,narration,details,particulars,transaction remarks",
    amount_columns: "amount,transaction amount",
    debit_columns: "debit,withdrawal,withdrawals,paid out",
    credit_columns: "credit,deposit,deposits,paid in",
    reference_columns: "reference,ref,utr,cheque no,cheque number,transaction id"
  });
  const [qifForm, setQifForm] = useState({ file_name: "bank-statement.qif", qif_content: "" });
  const [ofxForm, setOfxForm] = useState({ file_name: "bank-statement.ofx", ofx_content: "" });
  const [lineForm, setLineForm] = useState({ posted_date: new Date().toISOString().slice(0, 10), description: "", amount_minor: 0, reference: "" });
  const [draftLines, setDraftLines] = useState<ImportBankStatementInput["lines"]>([]);
  const [matchForm, setMatchForm] = useState({ statement_line_id: "", ledger_split_id: "" });
  const [loading, setLoading] = useState("");
  const [reconciliationError, setReconciliationError] = useState("");
  const [reconciliationNotice, setReconciliationNotice] = useState("");
  const accountStatementLines = statementLines.filter((line) => !accountId || line.account_id === accountId);
  const unmatchedLines = accountStatementLines.filter((line) => !line.matched_split_id);
  const candidateSplits = transactions.flatMap((transaction) => (
    transaction.splits
      .filter((split) => split.account_id === accountId)
      .map((split) => ({ transaction, split }))
  ));
  const unreconciledSplits = candidateSplits.filter(({ split }) => !split.reconciled);
  const reconciliationSummary = summarizeReconciliation(accountStatementLines, candidateSplits);
  const suggestedMatches = suggestReconciliationMatches(unmatchedLines.filter((line) => !line.is_duplicate), unreconciledSplits);
  const suggestedMatchByLineId = new Map(suggestedMatches.map((suggestion) => [suggestion.line.id, suggestion]));
  const canAddLine = Boolean(lineForm.posted_date && lineForm.amount_minor !== 0);
  const canImport = Boolean(accountId && draftLines.length > 0);
  const canImportQif = Boolean(accountId && qifForm.qif_content.trim());
  const canImportOfx = Boolean(accountId && ofxForm.ofx_content.trim());
  const canMatch = Boolean(matchForm.statement_line_id && matchForm.ledger_split_id);
  const canApplySuggestions = suggestedMatches.length > 0;

  async function loadLines(selectedAccountId = accountId) {
    if (!selectedAccountId) {
      setReconciliationError("Select a bank/cash account before loading statement lines.");
      return;
    }
    setLoading("load-lines");
    setReconciliationError("");
    try {
      const nextLines = await api.listBankStatementLines(selectedAccountId);
      const otherAccountLines = statementLines.filter((line) => line.account_id !== selectedAccountId);
      onStatementLinesChanged([...nextLines, ...otherAccountLines]);
      setReconciliationNotice(`Loaded ${nextLines.length} statement line(s).`);
    } catch (error) {
      setReconciliationError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  function addDraftLine() {
    if (!canAddLine) {
      return;
    }
    setDraftLines([
      ...draftLines,
      {
        posted_date: lineForm.posted_date,
        description: lineForm.description.trim() || undefined,
        amount_minor: lineForm.amount_minor,
        reference: lineForm.reference.trim() || undefined
      }
    ]);
    setLineForm({ posted_date: lineForm.posted_date, description: "", amount_minor: 0, reference: "" });
    setReconciliationNotice("Statement line staged locally.");
  }

  function removeDraftLine(index: number) {
    setDraftLines(draftLines.filter((_, draftIndex) => draftIndex !== index));
    setReconciliationNotice("Staged statement line removed.");
  }

  function stageCsvLines() {
    setReconciliationError("");
    try {
      const mappedLines = mapCsvStatementLines(csvForm.csv_content, csvForm);
      setDraftLines([...draftLines, ...mappedLines]);
      setReconciliationNotice(`Mapped ${mappedLines.length} CSV line(s) into the staged import queue.`);
    } catch (error) {
      setReconciliationError(errorMessage(error));
    }
  }

  async function importStatement(event: FormEvent) {
    event.preventDefault();
    if (!canImport) {
      return;
    }
    setLoading("import");
    setReconciliationError("");
    try {
      const result = await api.importBankStatement({
        account_id: accountId,
        file_name: importForm.file_name.trim() || undefined,
        format: importForm.format.trim() || "csv",
        lines: draftLines
      });
      const importedLines = result.lines ?? [];
      const otherAccountLines = statementLines.filter((line) => line.account_id !== accountId);
      onStatementLinesChanged([...importedLines, ...otherAccountLines]);
      setDraftLines([]);
      setReconciliationNotice(importNotice(result.line_count, importedLines));
    } catch (error) {
      setReconciliationError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function importQIFStatement(event: FormEvent) {
    event.preventDefault();
    if (!canImportQif) {
      return;
    }
    setLoading("import-qif");
    setReconciliationError("");
    try {
      const result = await api.importQIFBankStatement({
        account_id: accountId,
        file_name: qifForm.file_name.trim() || undefined,
        qif_content: qifForm.qif_content
      });
      const importedLines = result.lines ?? [];
      const otherAccountLines = statementLines.filter((line) => line.account_id !== accountId);
      onStatementLinesChanged([...importedLines, ...otherAccountLines]);
      setQifForm({ ...qifForm, qif_content: "" });
      setReconciliationNotice(importNotice(result.line_count, importedLines, "QIF"));
    } catch (error) {
      setReconciliationError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function importOFXStatement(event: FormEvent) {
    event.preventDefault();
    if (!canImportOfx) {
      return;
    }
    setLoading("import-ofx");
    setReconciliationError("");
    try {
      const result = await api.importOFXBankStatement({
        account_id: accountId,
        file_name: ofxForm.file_name.trim() || undefined,
        ofx_content: ofxForm.ofx_content
      });
      const importedLines = result.lines ?? [];
      const otherAccountLines = statementLines.filter((line) => line.account_id !== accountId);
      onStatementLinesChanged([...importedLines, ...otherAccountLines]);
      setOfxForm({ ...ofxForm, ofx_content: "" });
      setReconciliationNotice(importNotice(result.line_count, importedLines, "OFX"));
    } catch (error) {
      setReconciliationError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function matchStatementLine(event: FormEvent) {
    event.preventDefault();
    if (!canMatch) {
      return;
    }
    setLoading("match");
    setReconciliationError("");
    try {
      const matchedLine = await api.matchBankStatementLine(matchForm.statement_line_id, matchForm.ledger_split_id);
      onStatementLinesChanged(statementLines.map((line) => line.id === matchedLine.id ? matchedLine : line));
      setMatchForm({ statement_line_id: "", ledger_split_id: "" });
      setReconciliationNotice("Statement line matched and ledger split reconciled.");
      await onRefresh();
    } catch (error) {
      setReconciliationError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function applySuggestedMatches() {
    if (!canApplySuggestions) {
      return;
    }
    setLoading("auto-match");
    setReconciliationError("");
    try {
      const matchedLines: BankStatementLine[] = [];
      for (const suggestion of suggestedMatches) {
        matchedLines.push(await api.matchBankStatementLine(suggestion.line.id, suggestion.candidate.split.id));
      }
      const matchedByID = new Map(matchedLines.map((line) => [line.id, line]));
      onStatementLinesChanged(statementLines.map((line) => matchedByID.get(line.id) ?? line));
      setMatchForm({ statement_line_id: "", ledger_split_id: "" });
      setReconciliationNotice(`Applied ${matchedLines.length} suggested match(es).`);
      await onRefresh();
    } catch (error) {
      setReconciliationError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  function updateAccount(nextAccountId: string) {
    setAccountId(nextAccountId);
    setMatchForm({ statement_line_id: "", ledger_split_id: "" });
  }

  return (
    <div className="stack">
      <section className="panel offline-panel">
        <div>
          <p className="eyebrow">Bank reconciliation</p>
          <h3>Import, review, and match statement lines</h3>
          <p>Choose a bank/cash account, import structured statement lines, then match each line to an unreconciled ledger split.</p>
        </div>
        <button className="secondary" disabled={!accountId || loading === "load-lines"} onClick={() => void loadLines()}>
          {loading === "load-lines" ? "Loading..." : "Load statement lines"}
        </button>
      </section>

      {reconciliationError && <div className="alert error">{reconciliationError}</div>}
      {reconciliationNotice && <div className="alert success">{reconciliationNotice}</div>}

      <section className="panel form-grid">
        <div className="metric-card">
          <span>Statement lines</span>
          <strong>{reconciliationSummary.lineCount}</strong>
          <small>{reconciliationSummary.matchedLineCount} matched · {reconciliationSummary.openLineCount} open</small>
        </div>
        <div className="metric-card">
          <span>Duplicate candidates</span>
          <strong>{reconciliationSummary.duplicateLineCount}</strong>
          <small>Skipped by suggested matching</small>
        </div>
        <div className="metric-card">
          <span>Statement flow</span>
          <strong>{formatMinorAsInr(reconciliationSummary.inflowMinor)}</strong>
          <small>{formatMinorAsInr(reconciliationSummary.outflowMinor)} outflow</small>
        </div>
        <div className="metric-card">
          <span>Ledger splits</span>
          <strong>{reconciliationSummary.reconciledSplitCount}/{reconciliationSummary.splitCount}</strong>
          <small>{reconciliationSummary.unreconciledSplitCount} unreconciled</small>
        </div>
        <div className="metric-card">
          <span>Suggested matches</span>
          <strong>{suggestedMatches.length}</strong>
          <small>Exact amount within 3 days</small>
        </div>
        <div className="metric-card">
          <span>Statement net</span>
          <strong>{formatMinorAsInr(reconciliationSummary.netMinor)}</strong>
          <small>Imported line total</small>
        </div>
      </section>

      <section className="panel form-grid">
        <AccountSelect label="Bank or cash account" accounts={accounts.filter((account) => account.type === "asset")} value={accountId} onChange={updateAccount} />
        <label>
          Import file name
          <input value={importForm.file_name} onChange={(event) => setImportForm({ ...importForm, file_name: event.target.value })} />
        </label>
        <label>
          Format
          <input value={importForm.format} onChange={(event) => setImportForm({ ...importForm, format: event.target.value })} />
        </label>
      </section>

      <section className="panel queue-panel">
        <div className="queue-heading">
          <div>
            <p className="eyebrow">CSV mapper</p>
            <h3>Paste bank CSV and stage lines</h3>
            <p>Maps common headers automatically. Debit/withdrawal columns become outflows; credit/deposit columns become inflows.</p>
          </div>
          <strong>{csvForm.csv_content.trim() ? "Ready" : "Empty"}</strong>
        </div>
        <label className="full-span">
          CSV content
          <textarea
            rows={7}
            value={csvForm.csv_content}
            onChange={(event) => setCsvForm({ ...csvForm, csv_content: event.target.value })}
            placeholder={"Value Date,Narration,Withdrawal,Deposit,UTR\n2026-07-13,UPI payment,1250.00,,UPI-123\n2026-07-14,Client receipt,,5000.00,UTR-456"}
          />
        </label>
        <div className="form-grid">
          <label>
            Date columns
            <input value={csvForm.date_columns} onChange={(event) => setCsvForm({ ...csvForm, date_columns: event.target.value })} />
          </label>
          <label>
            Description columns
            <input value={csvForm.description_columns} onChange={(event) => setCsvForm({ ...csvForm, description_columns: event.target.value })} />
          </label>
          <label>
            Amount columns
            <input value={csvForm.amount_columns} onChange={(event) => setCsvForm({ ...csvForm, amount_columns: event.target.value })} />
          </label>
          <label>
            Debit columns
            <input value={csvForm.debit_columns} onChange={(event) => setCsvForm({ ...csvForm, debit_columns: event.target.value })} />
          </label>
          <label>
            Credit columns
            <input value={csvForm.credit_columns} onChange={(event) => setCsvForm({ ...csvForm, credit_columns: event.target.value })} />
          </label>
          <label>
            Reference columns
            <input value={csvForm.reference_columns} onChange={(event) => setCsvForm({ ...csvForm, reference_columns: event.target.value })} />
          </label>
        </div>
        <button type="button" disabled={!csvForm.csv_content.trim()} onClick={stageCsvLines}>Map CSV to staged lines</button>
      </section>

      <section className="panel form-grid">
        <label>
          Posted date
          <input type="date" value={lineForm.posted_date} onChange={(event) => setLineForm({ ...lineForm, posted_date: event.target.value })} />
        </label>
        <label>
          Description
          <input value={lineForm.description} onChange={(event) => setLineForm({ ...lineForm, description: event.target.value })} placeholder="UPI receipt, bank charge, deposit" />
        </label>
        <label>
          Amount minor
          <input type="number" value={lineForm.amount_minor} onChange={(event) => setLineForm({ ...lineForm, amount_minor: Number(event.target.value) })} />
        </label>
        <label>
          Reference
          <input value={lineForm.reference} onChange={(event) => setLineForm({ ...lineForm, reference: event.target.value })} placeholder="UTR / cheque / narration ref" />
        </label>
        <button type="button" disabled={!canAddLine} onClick={addDraftLine}>Stage line</button>
      </section>

      <form className="panel queue-panel" onSubmit={importStatement}>
        <div className="queue-heading">
          <div>
            <p className="eyebrow">Structured import</p>
            <h3>Staged statement lines</h3>
            <p>Positive amounts are inflows to the selected asset account; negative amounts are outflows.</p>
          </div>
          <strong>{draftLines.length}</strong>
        </div>
        <section className="table-panel">
          <table>
            <thead>
              <tr>
                <th>Date</th>
                <th>Description</th>
                <th>Amount</th>
                <th>Reference</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {draftLines.map((line, index) => (
                <tr key={`${line.posted_date}-${index}`}>
                  <td>{line.posted_date}</td>
                  <td>{line.description ?? "Unlabeled line"}</td>
                  <td>{formatMinorAsInr(line.amount_minor)}</td>
                  <td>{line.reference ?? "-"}</td>
                  <td><button className="danger compact" type="button" onClick={() => removeDraftLine(index)}>Remove</button></td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
        <button disabled={!canImport || loading === "import"}>{loading === "import" ? "Importing..." : "Import staged lines"}</button>
      </form>

      <form className="panel queue-panel" onSubmit={importQIFStatement}>
        <div className="queue-heading">
          <div>
            <p className="eyebrow">QIF import</p>
            <h3>Paste bank-export QIF</h3>
            <p>Supports common bank QIF records using D date, T amount, P/M description, and N reference fields.</p>
          </div>
          <strong>{qifForm.qif_content.trim() ? "Ready" : "Empty"}</strong>
        </div>
        <div className="form-grid">
          <label>
            QIF file name
            <input value={qifForm.file_name} onChange={(event) => setQifForm({ ...qifForm, file_name: event.target.value })} />
          </label>
        </div>
        <label className="full-span">
          QIF content
          <textarea
            rows={8}
            value={qifForm.qif_content}
            onChange={(event) => setQifForm({ ...qifForm, qif_content: event.target.value })}
            placeholder={"!Type:Bank\nD13/07/2026\nT1250.00\nPClient receipt\nNUPI-123\n^"}
          />
        </label>
        <button disabled={!canImportQif || loading === "import-qif"}>{loading === "import-qif" ? "Importing..." : "Import QIF"}</button>
      </form>

      <form className="panel queue-panel" onSubmit={importOFXStatement}>
        <div className="queue-heading">
          <div>
            <p className="eyebrow">OFX import</p>
            <h3>Paste bank-export OFX</h3>
            <p>Supports common OFX statement transactions using DTPOSTED, TRNAMT, NAME/MEMO, and FITID fields.</p>
          </div>
          <strong>{ofxForm.ofx_content.trim() ? "Ready" : "Empty"}</strong>
        </div>
        <div className="form-grid">
          <label>
            OFX file name
            <input value={ofxForm.file_name} onChange={(event) => setOfxForm({ ...ofxForm, file_name: event.target.value })} />
          </label>
        </div>
        <label className="full-span">
          OFX content
          <textarea
            rows={8}
            value={ofxForm.ofx_content}
            onChange={(event) => setOfxForm({ ...ofxForm, ofx_content: event.target.value })}
            placeholder={"<OFX>\n<STMTTRN>\n<DTPOSTED>20260713\n<TRNAMT>1250.00\n<FITID>OFX-123\n<NAME>Client receipt\n</STMTTRN>\n</OFX>"}
          />
        </label>
        <button disabled={!canImportOfx || loading === "import-ofx"}>{loading === "import-ofx" ? "Importing..." : "Import OFX"}</button>
      </form>

      <form className="panel form-grid" onSubmit={matchStatementLine}>
        <label>
          Unmatched statement line
          <select value={matchForm.statement_line_id} onChange={(event) => setMatchForm({ ...matchForm, statement_line_id: event.target.value })}>
            <option value="">Select statement line</option>
            {unmatchedLines.map((line) => (
              <option key={line.id} value={line.id}>
                {line.posted_date.slice(0, 10)} · {formatMinorAsInr(line.amount_minor)} · {line.description || line.reference || line.id}
              </option>
            ))}
          </select>
        </label>
        <label>
          Ledger split
          <select value={matchForm.ledger_split_id} onChange={(event) => setMatchForm({ ...matchForm, ledger_split_id: event.target.value })}>
            <option value="">Select ledger split</option>
            {unreconciledSplits.map(({ transaction, split }) => (
              <option key={split.id} value={split.id}>
                {transaction.transaction_date.slice(0, 10)} · {transaction.memo || transaction.source_module} · {formatMinorAsInr(split.debit_minor - split.credit_minor)}
              </option>
            ))}
          </select>
        </label>
        <button disabled={!canMatch || loading === "match"}>{loading === "match" ? "Matching..." : "Match and reconcile"}</button>
      </form>

      <section className="panel queue-panel">
        <div className="queue-heading">
          <div>
            <p className="eyebrow">Matching rules</p>
            <h3>Suggested matches</h3>
            <p>Exact amount and near-date matches are proposed first; duplicate statement lines are skipped.</p>
          </div>
          <strong>{suggestedMatches.length}</strong>
        </div>
        <section className="table-panel">
          <table>
            <thead>
              <tr>
                <th>Statement line</th>
                <th>Suggested ledger split</th>
                <th>Rule</th>
              </tr>
            </thead>
            <tbody>
              {suggestedMatches.map((suggestion) => (
                <tr key={`${suggestion.line.id}-${suggestion.candidate.split.id}`}>
                  <td>{suggestion.line.posted_date.slice(0, 10)} · {formatMinorAsInr(suggestion.line.amount_minor)} · {suggestion.line.description || suggestion.line.reference || suggestion.line.id}</td>
                  <td>{suggestion.candidate.transaction.transaction_date.slice(0, 10)} · {suggestion.candidate.transaction.memo || suggestion.candidate.transaction.source_module} · {formatMinorAsInr(suggestion.candidate.split.debit_minor - suggestion.candidate.split.credit_minor)}</td>
                  <td>{suggestion.reason}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
        <button type="button" disabled={!canApplySuggestions || loading === "auto-match"} onClick={() => void applySuggestedMatches()}>
          {loading === "auto-match" ? "Applying..." : "Apply suggested matches"}
        </button>
      </section>

      <section className="panel queue-panel">
        <div className="queue-heading">
          <div>
            <p className="eyebrow">Review</p>
            <h3>Statement lines</h3>
            <p>Cached locally after load/import for offline review. Duplicate candidates are flagged for manual review.</p>
          </div>
          <strong>{accountStatementLines.length} · {accountStatementLines.filter((line) => line.is_duplicate).length} dupes</strong>
        </div>
        <section className="table-panel">
          <table>
            <thead>
              <tr>
                <th>Date</th>
                <th>Description</th>
                <th>Amount</th>
                <th>Reference</th>
                <th>Status</th>
                <th>Suggestion</th>
                <th>Split</th>
              </tr>
            </thead>
            <tbody>
              {accountStatementLines.map((line) => {
                const suggestion = suggestedMatchByLineId.get(line.id);
                return (
                  <tr key={line.id}>
                    <td>{line.posted_date.slice(0, 10)}</td>
                    <td>{line.description || "Unlabeled line"}</td>
                    <td>{formatMinorAsInr(line.amount_minor)}</td>
                    <td>{line.reference || "-"}</td>
                    <td>{line.is_duplicate ? `Duplicate${line.duplicate_of_id ? ` of ${line.duplicate_of_id.slice(0, 8)}` : ""}` : line.matched_split_id ? "Matched" : "Open"}</td>
                    <td>{suggestion ? suggestion.reason : "-"}</td>
                    <td>{line.matched_split_id ?? "-"}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </section>
      </section>
    </div>
  );
}

function AdminPage({
  api,
  accounts,
  exchangeRates,
  fiscalCloses,
  auditLogs,
  organizationUsers,
  onExchangeRatesChanged,
  onFiscalClosesChanged,
  onAuditLogsChanged,
  onOrganizationUsersChanged,
  onRefresh
}: {
  api: ApiClient;
  accounts: Account[];
  exchangeRates: ExchangeRate[];
  fiscalCloses: FiscalClose[];
  auditLogs: AuditLog[];
  organizationUsers: OrganizationUser[];
  onExchangeRatesChanged: (rates: ExchangeRate[]) => void;
  onFiscalClosesChanged: (closes: FiscalClose[]) => void;
  onAuditLogsChanged: (logs: AuditLog[]) => void;
  onOrganizationUsersChanged: (users: OrganizationUser[]) => void;
  onRefresh: () => Promise<void>;
}) {
  const retainedEarningsAccountId = accounts.find((account) => account.type === "equity")?.id ?? "";
  const [rateForm, setRateForm] = useState<CreateExchangeRateInput>({
    from_currency: "USD",
    to_currency: "INR",
    rate_date: new Date().toISOString().slice(0, 10),
    numerator: 8350,
    denominator: 100,
    source: "manual"
  });
  const [closeForm, setCloseForm] = useState<CloseFiscalYearInput>({
    fiscal_year_start: `${new Date().getFullYear() - 1}-04-01`,
    fiscal_year_end: `${new Date().getFullYear()}-03-31`,
    retained_earnings_account_id: retainedEarningsAccountId
  });
  const gainLossAccountId = accounts.find((account) => account.type === "income" || account.type === "expense")?.id ?? "";
  const [revaluationForm, setRevaluationForm] = useState<PostRevaluationInput>({
    as_of_date: new Date().toISOString().slice(0, 10),
    gain_loss_account_id: gainLossAccountId
  });
  const [revaluationPreview, setRevaluationPreview] = useState<RevaluationPreview | null>(null);
  const [userForm, setUserForm] = useState<CreateOrganizationUserInput>({
    name: "",
    email: "",
    password: "",
    role: "viewer"
  });
  const [loading, setLoading] = useState("");
  const [adminError, setAdminError] = useState("");
  const [adminNotice, setAdminNotice] = useState("");
  const canCreateRate = Boolean(rateForm.from_currency.trim().length === 3 && rateForm.to_currency.trim().length === 3 && rateForm.rate_date && rateForm.numerator > 0 && rateForm.denominator > 0);
  const canCloseYear = Boolean(closeForm.fiscal_year_start && closeForm.fiscal_year_end && closeForm.retained_earnings_account_id);
  const canPostRevaluation = Boolean(revaluationForm.as_of_date && revaluationForm.gain_loss_account_id && revaluationPreview && revaluationPreview.rows.length > 0);
  const activeOrganizationUsers = organizationUsers.filter((user) => user.is_active).length;
  const inviteEmailsSent = organizationUsers.filter((user) => user.invite_email_sent).length;
  const inviteEmailsFailed = organizationUsers.filter((user) => user.invite_email_error).length;
  const userOnboardingChecks = organizationUserOnboardingChecks(userForm);
  const canCreateUser = userOnboardingChecks.every((check) => check.ok);

  function generateUserTemporaryPassword() {
    const password = generateTemporaryPassword();
    setUserForm({ ...userForm, password });
    setAdminNotice("Generated a temporary password locally. Share it securely, or ask the user to use password reset after invitation.");
  }

  async function copyUserTemporaryPassword() {
    if (!userForm.password) {
      return;
    }
    try {
      await navigator.clipboard.writeText(userForm.password);
      setAdminNotice("Temporary password copied to the clipboard. Clear it after sharing through a secure channel.");
    } catch {
      setAdminError("Clipboard copy is unavailable in this browser. Download the temporary password instead.");
    }
  }

  function downloadUserTemporaryPassword() {
    if (!userForm.password) {
      return;
    }
    const filenamePart = safeFilenamePart(userForm.email || userForm.name || "new-user");
    const blob = new Blob([
      [
        "AbhashTech Accounting Temporary Password",
        `Generated: ${new Date().toISOString()}`,
        `User: ${userForm.name || "-"}`,
        `Email: ${userForm.email || "-"}`,
        `Role: ${roleLabel(userForm.role)}`,
        "",
        userForm.password,
        "",
        "Share this through a secure channel. Ask the user to reset their password after first login."
      ].join("\n")
    ], { type: "text/plain;charset=utf-8" });
    downloadBlob(`temporary-password-${filenamePart}.txt`, blob);
    setAdminNotice("Temporary password downloaded. Remove the file from shared devices after onboarding.");
  }

  async function loadAdminData() {
    setLoading("refresh-admin");
    setAdminError("");
    try {
      const [nextRates, nextCloses, nextAuditLogs, nextUsers] = await Promise.all([
        api.listExchangeRates(),
        api.listFiscalCloses(),
        api.listAuditLogs(),
        api.listOrganizationUsers()
      ]);
      onExchangeRatesChanged(nextRates);
      onFiscalClosesChanged(nextCloses);
      onAuditLogsChanged(nextAuditLogs);
      onOrganizationUsersChanged(nextUsers);
      setAdminNotice("Admin data refreshed.");
    } catch (error) {
      setAdminError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function createExchangeRate(event: FormEvent) {
    event.preventDefault();
    if (!canCreateRate) {
      return;
    }
    setLoading("create-rate");
    setAdminError("");
    try {
      const rate = await api.createExchangeRate(toExchangeRateInput(rateForm));
      onExchangeRatesChanged([rate, ...exchangeRates]);
      setAdminNotice(`Exchange rate ${rate.from_currency}/${rate.to_currency} saved.`);
      await onRefresh();
    } catch (error) {
      setAdminError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function closeFiscalYear(event: FormEvent) {
    event.preventDefault();
    if (!canCloseYear) {
      return;
    }
    setLoading("close-year");
    setAdminError("");
    try {
      const close = await api.closeFiscalYear(closeForm);
      onFiscalClosesChanged([close, ...fiscalCloses]);
      setAdminNotice(`Fiscal year closed with net income ${formatMinorAsInr(close.net_income_minor)}.`);
      await onRefresh();
    } catch (error) {
      setAdminError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function previewRevaluation() {
    if (!revaluationForm.as_of_date) {
      return;
    }
    setLoading("preview-revaluation");
    setAdminError("");
    try {
      const preview = await api.previewRevaluation(revaluationForm.as_of_date);
      setRevaluationPreview(preview);
      setAdminNotice(preview.rows.length > 0 ? `Found ${preview.rows.length} FX balance(s) to revalue.` : "No foreign currency adjustments found for that date.");
    } catch (error) {
      setAdminError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function postRevaluation(event: FormEvent) {
    event.preventDefault();
    if (!canPostRevaluation) {
      return;
    }
    setLoading("post-revaluation");
    setAdminError("");
    try {
      const transaction = await api.postRevaluation(toPostRevaluationInput(revaluationForm));
      setAdminNotice(`Revaluation journal ${transaction.id.slice(0, 8)} posted.`);
      setRevaluationPreview(null);
      await onRefresh();
    } catch (error) {
      setAdminError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function createOrganizationUser(event: FormEvent) {
    event.preventDefault();
    if (!canCreateUser) {
      return;
    }
    setLoading("create-user");
    setAdminError("");
    try {
      const user = await api.createOrganizationUser(toOrganizationUserInput(userForm));
      onOrganizationUsersChanged([user, ...organizationUsers]);
      setUserForm({ name: "", email: "", password: "", role: "viewer" });
      const inviteStatus = user.invite_email_sent ? " Invitation email sent." : user.invite_email_error ? ` Invitation email failed: ${user.invite_email_error}` : "";
      setAdminNotice(`User ${user.email} added as ${user.role}.${inviteStatus}`);
      await onRefresh();
    } catch (error) {
      setAdminError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function updateOrganizationUser(user: OrganizationUser, input: UpdateOrganizationUserInput) {
    setLoading(`update-user-${user.user_id}`);
    setAdminError("");
    try {
      const updated = await api.updateOrganizationUser(user.user_id, input);
      onOrganizationUsersChanged(organizationUsers.map((candidate) => candidate.user_id === updated.user_id ? updated : candidate));
      setAdminNotice(`Updated ${updated.email}: ${roleLabel(updated.role)}, ${updated.is_active ? "active" : "inactive"}.`);
      await onRefresh();
    } catch (error) {
      setAdminError(errorMessage(error));
    } finally {
      setLoading("");
    }
  }

  async function updateOrganizationUserRole(user: OrganizationUser, role: Role) {
    if (role === user.role) {
      return;
    }
    await updateOrganizationUser(user, { role });
  }

  async function toggleOrganizationUserActive(user: OrganizationUser) {
    await updateOrganizationUser(user, { is_active: !user.is_active });
  }

  return (
    <div className="stack">
      <section className="panel offline-panel">
        <div>
          <p className="eyebrow">Operations</p>
          <h3>Admin controls</h3>
          <p>Manage currency rates, fiscal close records, organization users, and the audit trail from one guarded surface.</p>
        </div>
        <button className="secondary" disabled={loading === "refresh-admin"} onClick={() => void loadAdminData()}>
          {loading === "refresh-admin" ? "Refreshing..." : "Refresh admin data"}
        </button>
      </section>

      {adminError && <div className="alert error">{adminError}</div>}
      {adminNotice && <div className="alert success">{adminNotice}</div>}

      <form className="panel form-grid" onSubmit={createExchangeRate}>
        <label>
          From currency
          <input maxLength={3} value={rateForm.from_currency} onChange={(event) => setRateForm({ ...rateForm, from_currency: event.target.value.toUpperCase() })} />
        </label>
        <label>
          To currency
          <input maxLength={3} value={rateForm.to_currency} onChange={(event) => setRateForm({ ...rateForm, to_currency: event.target.value.toUpperCase() })} />
        </label>
        <label>
          Rate date
          <input type="date" value={rateForm.rate_date} onChange={(event) => setRateForm({ ...rateForm, rate_date: event.target.value })} />
        </label>
        <label>
          Numerator
          <input type="number" min={1} value={rateForm.numerator} onChange={(event) => setRateForm({ ...rateForm, numerator: Number(event.target.value) })} />
        </label>
        <label>
          Denominator
          <input type="number" min={1} value={rateForm.denominator} onChange={(event) => setRateForm({ ...rateForm, denominator: Number(event.target.value) })} />
        </label>
        <label>
          Source
          <input value={rateForm.source ?? ""} onChange={(event) => setRateForm({ ...rateForm, source: event.target.value })} />
        </label>
        <button disabled={!canCreateRate || loading === "create-rate"}>{loading === "create-rate" ? "Saving..." : "Save exchange rate"}</button>
      </form>

      <DataTable
        headers={["Pair", "Date", "Ratio", "Source"]}
        rows={exchangeRates.map((rate) => [
          `${rate.from_currency}/${rate.to_currency}`,
          rate.rate_date.slice(0, 10),
          `${rate.numerator}/${rate.denominator}`,
          rate.source ?? "-"
        ])}
      />

      <form className="panel form-grid" onSubmit={postRevaluation}>
        <label>
          Revalue as of
          <input type="date" value={revaluationForm.as_of_date} onChange={(event) => {
            setRevaluationForm({ ...revaluationForm, as_of_date: event.target.value });
            setRevaluationPreview(null);
          }} />
        </label>
        <AccountSelect label="FX gain/loss account" accounts={accounts.filter((account) => account.type === "income" || account.type === "expense")} value={revaluationForm.gain_loss_account_id} onChange={(value) => setRevaluationForm({ ...revaluationForm, gain_loss_account_id: value })} />
        <button type="button" className="secondary" disabled={!revaluationForm.as_of_date || loading === "preview-revaluation"} onClick={() => void previewRevaluation()}>
          {loading === "preview-revaluation" ? "Previewing..." : "Preview revaluation"}
        </button>
        <button disabled={!canPostRevaluation || loading === "post-revaluation"}>{loading === "post-revaluation" ? "Posting..." : "Post revaluation journal"}</button>
      </form>

      {revaluationPreview && (
        <section className="panel">
          <div className="queue-heading">
            <div>
              <p className="eyebrow">Advanced accounting</p>
              <h3>Unrealized FX revaluation</h3>
              <p>Total adjustment: {formatMinorAsInr(revaluationPreview.total_adjustment_minor)} in {revaluationPreview.base_currency}.</p>
            </div>
          </div>
          <DataTable
            headers={["Account", "Currency", "Foreign balance", "Carrying", "Revalued", "Adjustment", "Rate"]}
            rows={revaluationPreview.rows.map((row) => [
              `${row.account_code} ${row.account_name}`,
              row.currency,
              `${row.currency} minor ${row.foreign_balance_minor}`,
              formatMinorAsInr(row.carrying_base_minor),
              formatMinorAsInr(row.revalued_base_minor),
              formatMinorAsInr(row.adjustment_minor),
              `${row.exchange_rate_numerator}/${row.exchange_rate_denominator}`
            ])}
          />
        </section>
      )}

      <form className="panel form-grid" onSubmit={closeFiscalYear}>
        <label>
          Fiscal year start
          <input type="date" value={closeForm.fiscal_year_start} onChange={(event) => setCloseForm({ ...closeForm, fiscal_year_start: event.target.value })} />
        </label>
        <label>
          Fiscal year end
          <input type="date" value={closeForm.fiscal_year_end} onChange={(event) => setCloseForm({ ...closeForm, fiscal_year_end: event.target.value })} />
        </label>
        <AccountSelect label="Retained earnings account" accounts={accounts.filter((account) => account.type === "equity")} value={closeForm.retained_earnings_account_id} onChange={(value) => setCloseForm({ ...closeForm, retained_earnings_account_id: value })} />
        <button disabled={!canCloseYear || loading === "close-year"}>{loading === "close-year" ? "Closing..." : "Close fiscal year"}</button>
      </form>

      <DataTable
        headers={["Start", "End", "Net income", "Status", "Journal transaction"]}
        rows={fiscalCloses.map((close) => [
          close.fiscal_year_start.slice(0, 10),
          close.fiscal_year_end.slice(0, 10),
          formatMinorAsInr(close.net_income_minor),
          close.status,
          close.journal_transaction_id
        ])}
      />

      <form className="panel form-grid" onSubmit={createOrganizationUser}>
        <div className="full-span">
          <p className="eyebrow">User onboarding</p>
          <p>Invitation email delivery depends on SMTP settings. A temporary password is still required; users can also recover access through the password reset flow.</p>
          <div className="security-checklist">
            <span className="check-good">Users · {organizationUsers.length}</span>
            <span className="check-good">Active · {activeOrganizationUsers}</span>
            <span className={inviteEmailsFailed > 0 ? "check-warn" : "check-good"}>Invites sent · {inviteEmailsSent}</span>
            <span className={inviteEmailsFailed > 0 ? "check-warn" : "check-good"}>Invite failures · {inviteEmailsFailed}</span>
          </div>
        </div>
        <input placeholder="Name" value={userForm.name} onChange={(event) => setUserForm({ ...userForm, name: event.target.value })} />
        <input placeholder="Email" value={userForm.email} onChange={(event) => setUserForm({ ...userForm, email: event.target.value })} />
        <input placeholder="Temporary password" type="password" value={userForm.password} onChange={(event) => setUserForm({ ...userForm, password: event.target.value })} />
        <label>
          Role
          <select value={userForm.role} onChange={(event) => setUserForm({ ...userForm, role: event.target.value as Role })}>
            {roleOptions.map((role) => <option key={role} value={role}>{roleLabel(role)}</option>)}
          </select>
        </label>
        <button className="secondary" type="button" onClick={generateUserTemporaryPassword}>Generate temporary password</button>
        <button className="secondary" type="button" disabled={!userForm.password} onClick={() => void copyUserTemporaryPassword()}>Copy password</button>
        <button className="secondary" type="button" disabled={!userForm.password} onClick={downloadUserTemporaryPassword}>Download password</button>
        <button disabled={!canCreateUser || loading === "create-user"}>{loading === "create-user" ? "Creating..." : "Create user"}</button>
        <div className="full-span">
          <div className="security-checklist">
            {userOnboardingChecks.map((check) => (
              <span key={check.label} className={check.ok ? "check-good" : "check-warn"}>
                {check.ok ? "OK" : "Need"} · {check.label}
              </span>
            ))}
          </div>
          <p><strong>{roleLabel(userForm.role)}:</strong> {roleDescription(userForm.role)}</p>
        </div>
      </form>

      <section className="table-panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Email</th>
              <th>Role</th>
              <th>Access</th>
              <th>Invite email</th>
              <th>Onboarding note</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {organizationUsers.map((user) => (
              <tr key={user.user_id}>
                <td>{user.name}</td>
                <td>{user.email}</td>
                <td>
                  <select value={user.role} disabled={loading === `update-user-${user.user_id}`} onChange={(event) => void updateOrganizationUserRole(user, event.target.value as Role)}>
                    {roleOptions.map((role) => <option key={role} value={role}>{roleLabel(role)}</option>)}
                  </select>
                </td>
                <td>{user.is_active ? "Active" : "Inactive"}</td>
                <td>{user.invite_email_sent ? "Sent" : user.invite_email_error ? `Failed: ${user.invite_email_error}` : "Not sent"}</td>
                <td>{user.invite_email_error ? "Check SMTP settings and share password-reset fallback." : roleDescription(user.role)}</td>
                <td>
                  <button className={user.is_active ? "danger compact" : "secondary compact"} disabled={loading === `update-user-${user.user_id}`} onClick={() => void toggleOrganizationUserActive(user)}>
                    {loading === `update-user-${user.user_id}` ? "Updating..." : user.is_active ? "Deactivate" : "Reactivate"}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      <section className="panel queue-panel">
        <div className="queue-heading">
          <div>
            <p className="eyebrow">Audit trail</p>
            <h3>Recent audit logs</h3>
            <p>Immutable trail for posting, matching, closing, and admin workflows.</p>
          </div>
          <strong>{auditLogs.length}</strong>
        </div>
        <section className="table-panel">
          <table>
            <thead>
              <tr>
                <th>When</th>
                <th>Entity</th>
                <th>Action</th>
                <th>Actor</th>
              </tr>
            </thead>
            <tbody>
              {auditLogs.slice(0, 50).map((log) => (
                <tr key={log.id}>
                  <td>{new Date(log.created_at).toLocaleString()}</td>
                  <td>{log.entity_type} · {log.entity_id}</td>
                  <td>{log.action}</td>
                  <td>{log.actor_user_id ?? "system"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      </section>
    </div>
  );
}

function AccountsPage({
  accounts,
  queuedAccountDrafts,
  api,
  onChanged,
  onQueueDraft,
  onUpdateQueuedDraft,
  onDeleteQueuedDraft,
  onClearQueuedDraftError,
  onClearQueuedDrafts,
  onSyncQueuedDrafts
}: {
  accounts: Account[];
  queuedAccountDrafts: QueuedAccountDraft[];
  api: ApiClient;
  onChanged: () => Promise<void>;
  onQueueDraft: (input: AccountInput) => void;
  onUpdateQueuedDraft: (draftId: string, input: AccountInput) => void;
  onDeleteQueuedDraft: (draftId: string) => void;
  onClearQueuedDraftError: (draftId: string) => void;
  onClearQueuedDrafts: () => void;
  onSyncQueuedDrafts: () => Promise<void>;
}) {
  const [form, setForm] = useState({ code: "", name: "", type: "asset" as Account["type"], subtype: "", currency: "INR" });
  const [editingDraftId, setEditingDraftId] = useState<string | null>(null);
  const canSaveDraft = Boolean(form.code.trim() && form.name.trim());

  function toInput(): AccountInput {
    return {
      code: form.code.trim(),
      name: form.name.trim(),
      type: form.type,
      subtype: form.subtype.trim() || undefined,
      currency: form.currency.trim() || "INR"
    };
  }

  function resetForm() {
    setForm({ code: "", name: "", type: "asset", subtype: "", currency: "INR" });
    setEditingDraftId(null);
  }

  async function submit(event: FormEvent) {
    event.preventDefault();
    await api.createAccount(toInput());
    resetForm();
    await onChanged();
  }

  function queueDraft() {
    if (!canSaveDraft) {
      return;
    }
    if (editingDraftId) {
      onUpdateQueuedDraft(editingDraftId, toInput());
      resetForm();
      return;
    }
    onQueueDraft(toInput());
    resetForm();
  }

  function editQueuedDraft(draft: QueuedAccountDraft) {
    setEditingDraftId(draft.id);
    setForm({
      code: draft.input.code,
      name: draft.input.name,
      type: draft.input.type,
      subtype: draft.input.subtype ?? "",
      currency: draft.input.currency ?? "INR"
    });
  }

  return (
    <div className="stack">
      <form className="panel form-grid" onSubmit={submit}>
        <input placeholder="Code" value={form.code} onChange={(event) => setForm({ ...form, code: event.target.value })} required />
        <input placeholder="Name" value={form.name} onChange={(event) => setForm({ ...form, name: event.target.value })} required />
        <select value={form.type} onChange={(event) => setForm({ ...form, type: event.target.value as Account["type"] })}>
          <option value="asset">Asset</option>
          <option value="liability">Liability</option>
          <option value="equity">Equity</option>
          <option value="income">Income</option>
          <option value="expense">Expense</option>
        </select>
        <input placeholder="Subtype" value={form.subtype} onChange={(event) => setForm({ ...form, subtype: event.target.value })} />
        <input placeholder="Currency" value={form.currency} onChange={(event) => setForm({ ...form, currency: event.target.value })} />
        <button>Create account</button>
        <button className="secondary" type="button" disabled={!canSaveDraft} onClick={queueDraft}>
          {editingDraftId ? "Save queued account" : "Queue offline account"}
        </button>
        {editingDraftId && (
          <button className="secondary" type="button" onClick={resetForm}>Cancel edit</button>
        )}
      </form>
      <section className="panel queue-panel">
        <div className="queue-heading">
          <div>
            <p className="eyebrow">Browser queue</p>
            <h3>Offline account drafts</h3>
            <p>{queuedAccountDrafts.length} account drafts are stored in this browser for reconnect sync.</p>
          </div>
          <strong>{queuedAccountDrafts.length}</strong>
        </div>
        <div className="button-row">
          <button className="secondary" disabled={queuedAccountDrafts.length === 0} onClick={() => void onSyncQueuedDrafts()}>Sync queued accounts</button>
          <button className="danger" disabled={queuedAccountDrafts.length === 0} onClick={onClearQueuedDrafts}>Clear account drafts</button>
        </div>
        {queuedAccountDrafts.length > 0 && (
          <QueuedAccountDraftTable
            drafts={queuedAccountDrafts}
            onClearDraftError={onClearQueuedDraftError}
            onDeleteDraft={onDeleteQueuedDraft}
            onEditDraft={editQueuedDraft}
          />
        )}
      </section>
      <DataTable headers={["Code", "Name", "Type", "Subtype", "Currency"]} rows={accounts.map((account) => [account.code, account.name, account.type, account.subtype ?? "", account.currency])} />
    </div>
  );
}

function QueuedAccountDraftTable({
  drafts,
  onClearDraftError,
  onDeleteDraft,
  onEditDraft
}: {
  drafts: QueuedAccountDraft[];
  onClearDraftError: (draftId: string) => void;
  onDeleteDraft: (draftId: string) => void;
  onEditDraft: (draft: QueuedAccountDraft) => void;
}) {
  return (
    <section className="table-panel">
      <table>
        <thead>
          <tr>
            <th>Created</th>
            <th>Code</th>
            <th>Name</th>
            <th>Type</th>
            <th>Currency</th>
            <th>Last error</th>
            <th>Action</th>
          </tr>
        </thead>
        <tbody>
          {drafts.map((draft) => (
            <tr key={draft.id}>
              <td>{new Date(draft.createdAt).toLocaleString()}</td>
              <td>{draft.input.code}</td>
              <td>{draft.input.name}</td>
              <td>{draft.input.type}</td>
              <td>{draft.input.currency ?? "INR"}</td>
              <td>{draft.lastError ?? ""}</td>
              <td>
                <button className="secondary compact" onClick={() => onEditDraft(draft)}>Edit</button>
                {draft.lastError && (
                  <button className="secondary compact" onClick={() => onClearDraftError(draft.id)}>Clear error</button>
                )}
                <button className="danger compact" onClick={() => onDeleteDraft(draft.id)}>Delete</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}

function LedgerPage({
  accounts,
  transactions,
  accountRegisterAccountId,
  accountRegisterSplits,
  queuedJournalDrafts,
  focusTarget,
  api,
  onChanged,
  onAccountRegisterChanged,
  onQueueDraft,
  onUpdateQueuedDraft,
  onDeleteQueuedDraft,
  onClearQueuedDraftError,
  onClearQueuedDrafts,
  onSyncQueuedDrafts
}: {
  accounts: Account[];
  transactions: JournalTransaction[];
  accountRegisterAccountId: string;
  accountRegisterSplits: LedgerSplit[];
  queuedJournalDrafts: QueuedJournalDraft[];
  focusTarget: FocusTarget | null;
  api: ApiClient;
  onChanged: () => Promise<void>;
  onAccountRegisterChanged: (accountId: string, splits: LedgerSplit[]) => void;
  onQueueDraft: (input: JournalTransactionInput) => void;
  onUpdateQueuedDraft: (draftId: string, input: JournalTransactionInput) => void;
  onDeleteQueuedDraft: (draftId: string) => void;
  onClearQueuedDraftError: (draftId: string) => void;
  onClearQueuedDrafts: () => void;
  onSyncQueuedDrafts: () => Promise<void>;
}) {
  const today = new Date().toISOString().slice(0, 10);
  const [form, setForm] = useState({
    transaction_date: today,
    memo: "",
    debit_account_id: "",
    credit_account_id: "",
    amount_minor: 0
  });
  const [editingDraftId, setEditingDraftId] = useState<string | null>(null);
  const [registerAccountId, setRegisterAccountId] = useState(accountRegisterAccountId || accounts[0]?.id || "");
  const [registerLoading, setRegisterLoading] = useState(false);
  const [registerError, setRegisterError] = useState("");
  const canSaveDraft = Boolean(form.debit_account_id && form.credit_account_id && form.amount_minor > 0);
  const registerRows = accountRegisterSplits.map((split, index) => ({
    split,
    runningBalanceMinor: accountRegisterSplits
      .slice(0, index + 1)
      .reduce((total, current) => total + current.debit_minor - current.credit_minor, 0)
  }));

  function toInput(): JournalTransactionInput {
    return {
      transaction_date: form.transaction_date,
      memo: form.memo,
      splits: [
        { account_id: form.debit_account_id, debit_minor: form.amount_minor, credit_minor: 0, currency: "INR" },
        { account_id: form.credit_account_id, debit_minor: 0, credit_minor: form.amount_minor, currency: "INR" }
      ]
    };
  }

  function resetForm() {
    setForm({
      transaction_date: today,
      memo: "",
      debit_account_id: "",
      credit_account_id: "",
      amount_minor: 0
    });
    setEditingDraftId(null);
  }

  async function submit(event: FormEvent) {
    event.preventDefault();
    await api.postJournalTransaction(toInput());
    resetForm();
    await onChanged();
  }

  function queueDraft() {
    if (!canSaveDraft) {
      return;
    }
    if (editingDraftId) {
      onUpdateQueuedDraft(editingDraftId, toInput());
      resetForm();
      return;
    }
    onQueueDraft(toInput());
    resetForm();
  }

  function editQueuedDraft(draft: QueuedJournalDraft) {
    const debitSplit = draft.input.splits.find((split) => split.debit_minor > 0);
    const creditSplit = draft.input.splits.find((split) => split.credit_minor > 0);
    setEditingDraftId(draft.id);
    setForm({
      transaction_date: draft.input.transaction_date,
      memo: draft.input.memo ?? "",
      debit_account_id: debitSplit?.account_id ?? "",
      credit_account_id: creditSplit?.account_id ?? "",
      amount_minor: debitSplit?.debit_minor ?? creditSplit?.credit_minor ?? 0
    });
  }

  async function loadAccountRegister(event?: FormEvent) {
    event?.preventDefault();
    if (!registerAccountId) {
      return;
    }
    setRegisterLoading(true);
    setRegisterError("");
    try {
      const splits = await api.getAccountRegister(registerAccountId);
      onAccountRegisterChanged(registerAccountId, splits);
    } catch (error) {
      setRegisterError(errorMessage(error));
    } finally {
      setRegisterLoading(false);
    }
  }

  function accountName(accountId: string) {
    const account = accounts.find((candidate) => candidate.id === accountId);
    return account ? `${account.code} · ${account.name}` : accountId;
  }

  return (
    <div className="stack">
      <form className="panel form-grid" onSubmit={submit}>
        <input type="date" value={form.transaction_date} onChange={(event) => setForm({ ...form, transaction_date: event.target.value })} />
        <input placeholder="Memo" value={form.memo} onChange={(event) => setForm({ ...form, memo: event.target.value })} />
        <AccountSelect label="Debit account" accounts={accounts} value={form.debit_account_id} onChange={(value) => setForm({ ...form, debit_account_id: value })} />
        <AccountSelect label="Credit account" accounts={accounts} value={form.credit_account_id} onChange={(value) => setForm({ ...form, credit_account_id: value })} />
        <input type="number" min="1" placeholder="Amount minor" value={form.amount_minor} onChange={(event) => setForm({ ...form, amount_minor: Number(event.target.value) })} />
        <button>Post journal</button>
        <button className="secondary" type="button" disabled={!canSaveDraft} onClick={queueDraft}>
          {editingDraftId ? "Save queued draft" : "Queue offline draft"}
        </button>
        {editingDraftId && (
          <button className="secondary" type="button" onClick={resetForm}>Cancel edit</button>
        )}
      </form>
      <section className="panel queue-panel">
        <div className="queue-heading">
          <div>
            <p className="eyebrow">Browser queue</p>
            <h3>Offline journal drafts</h3>
            <p>{queuedJournalDrafts.length} manual journal drafts are stored in this browser for reconnect sync.</p>
          </div>
          <strong>{queuedJournalDrafts.length}</strong>
        </div>
        <div className="button-row">
          <button className="secondary" disabled={queuedJournalDrafts.length === 0} onClick={() => void onSyncQueuedDrafts()}>Sync queued drafts</button>
          <button className="danger" disabled={queuedJournalDrafts.length === 0} onClick={onClearQueuedDrafts}>Clear all drafts</button>
        </div>
        {queuedJournalDrafts.length > 0 && (
          <QueuedDraftTable
            drafts={queuedJournalDrafts}
            onClearDraftError={onClearQueuedDraftError}
            onDeleteDraft={onDeleteQueuedDraft}
            onEditDraft={editQueuedDraft}
          />
        )}
      </section>
      <form className="panel form-grid" onSubmit={loadAccountRegister}>
        <AccountSelect label="Account register" accounts={accounts} value={registerAccountId} onChange={setRegisterAccountId} />
        <button disabled={!registerAccountId || registerLoading}>{registerLoading ? "Loading..." : "Load register"}</button>
      </form>
      {registerError && <div className="alert error">{registerError}</div>}
      <FocusNotice focusTarget={focusTarget} />
      <section className="panel queue-panel">
        <div className="queue-heading">
          <div>
            <p className="eyebrow">Register</p>
            <h3>{accountRegisterAccountId ? accountName(accountRegisterAccountId) : "Account register"}</h3>
            <p>Posted split activity is cached locally after loading for offline review.</p>
          </div>
          <strong>{accountRegisterSplits.length}</strong>
        </div>
        <section className="table-panel">
          <table>
            <thead>
              <tr>
                <th>Memo</th>
                <th>Debit</th>
                <th>Credit</th>
                <th>Balance</th>
                <th>Currency</th>
                <th>Cleared</th>
                <th>Reconciled</th>
              </tr>
            </thead>
            <tbody>
              {registerRows.map(({ split, runningBalanceMinor }) => (
                <tr key={split.id}>
                  <td>{split.memo || split.id}</td>
                  <td>{formatMinor(split.debit_minor, split.currency)}</td>
                  <td>{formatMinor(split.credit_minor, split.currency)}</td>
                  <td>{formatMinor(runningBalanceMinor, split.currency)}</td>
                  <td>{split.currency}</td>
                  <td>{split.cleared ? "Yes" : "No"}</td>
                  <td>{split.reconciled ? "Yes" : "No"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      </section>
      <section className="panel table-panel">
        <table>
          <thead>
            <tr>
              <th>Date</th>
              <th>Memo</th>
              <th>Status</th>
              <th>Splits</th>
            </tr>
          </thead>
          <tbody>
            {transactions.map((transaction) => (
              <tr key={transaction.id} className={focusTarget?.journalTransactionId === transaction.id || focusRowClass(focusTarget, "journal_transaction", transaction.id) ? "focused-row" : undefined}>
                <td>{transaction.transaction_date.slice(0, 10)}</td>
                <td>{transaction.memo ?? ""}</td>
                <td>{transaction.status}</td>
                <td>{transaction.splits.length.toString()}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </div>
  );
}

function QueuedDraftTable({
  drafts,
  onClearDraftError,
  onDeleteDraft,
  onEditDraft
}: {
  drafts: QueuedJournalDraft[];
  onClearDraftError: (draftId: string) => void;
  onDeleteDraft: (draftId: string) => void;
  onEditDraft: (draft: QueuedJournalDraft) => void;
}) {
  return (
    <section className="table-panel">
      <table>
        <thead>
          <tr>
            <th>Created</th>
            <th>Date</th>
            <th>Memo</th>
            <th>Amount</th>
            <th>Splits</th>
            <th>Last error</th>
            <th>Action</th>
          </tr>
        </thead>
        <tbody>
          {drafts.map((draft) => (
            <tr key={draft.id}>
              <td>{new Date(draft.createdAt).toLocaleString()}</td>
              <td>{draft.input.transaction_date}</td>
              <td>{draft.input.memo ?? ""}</td>
              <td>{formatMinorAsInr(totalDebitMinor(draft.input))}</td>
              <td>{draft.input.splits.length}</td>
              <td>{draft.lastError ?? ""}</td>
              <td>
                <button className="secondary compact" onClick={() => onEditDraft(draft)}>Edit</button>
                {draft.lastError && (
                  <button className="secondary compact" onClick={() => onClearDraftError(draft.id)}>Clear error</button>
                )}
                <button className="danger compact" onClick={() => onDeleteDraft(draft.id)}>Delete</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}

function AccountSelect({ label, accounts, value, onChange }: { label: string; accounts: Account[]; value: string; onChange: (value: string) => void }) {
  return (
    <label className="select-label">
      {label}
      <select value={value} onChange={(event) => onChange(event.target.value)} required>
        <option value="">Select account</option>
        {accounts.map((account) => (
          <option key={account.id} value={account.id}>{account.code} · {account.name}</option>
        ))}
      </select>
    </label>
  );
}

function FocusNotice({ focusTarget, fallback }: { focusTarget: FocusTarget | null; fallback?: string }) {
  if (!focusTarget) {
    return null;
  }
  const label = titleCase(focusTarget.documentType.replace(/_/g, " "));
  const identifier = focusTarget.documentNumber || focusTarget.documentId.slice(0, 8);
  return (
    <div className="alert success">
      Focused from report drilldown: {label} {identifier}. {fallback ?? "Matching rows are highlighted below when available."}
    </div>
  );
}

function focusRowClass(focusTarget: FocusTarget | null, documentType: string, documentId?: string | null) {
  return focusTarget?.documentType === documentType && focusTarget.documentId === documentId ? "focused-row" : undefined;
}

function DataTable({ headers, rows }: { headers: string[]; rows: ReactNode[][] }) {
  return (
    <section className="panel table-panel">
      <table>
        <thead>
          <tr>{headers.map((header) => <th key={header}>{header}</th>)}</tr>
        </thead>
        <tbody>
          {rows.map((row, index) => (
            <tr key={index}>{row.map((cell, cellIndex) => <td key={cellIndex}>{cell}</td>)}</tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}

function titleFor(view: View) {
  if (view === "accounts") return "Chart of accounts";
  if (view === "ledger") return "Manual ledger entry";
  if (view === "tax") return "GST tax catalog";
  if (view === "reports") return "Financial reports";
  if (view === "budgets") return "Budgets";
  if (view === "investments") return "Investments";
  if (view === "payroll") return "Payroll";
  if (view === "invoices") return "Invoices";
  if (view === "expenses") return "Expenses";
  if (view === "documents") return "Documents";
  if (view === "reconciliation") return "Bank reconciliation";
  if (view === "admin") return "Admin";
  return "Dashboard";
}

function createDraftId(prefix: string) {
  if ("randomUUID" in crypto) {
    return `${prefix}-${crypto.randomUUID()}`;
  }
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

type SyncableDraft = {
  lastError?: string;
};

async function syncDraftQueue<TDraft extends SyncableDraft>(
  drafts: TDraft[],
  syncDraft: (draft: TDraft) => Promise<unknown>
) {
  const remaining: TDraft[] = [];
  let synced = 0;

  for (const draft of drafts) {
    try {
      await syncDraft(draft);
      synced += 1;
    } catch (error) {
      remaining.push({
        ...draft,
        lastError: errorMessage(error)
      });
    }
  }

  return { synced, failed: remaining.length, remaining };
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : "Sync failed";
}

function totalDebitMinor(input: JournalTransactionInput) {
  return input.splits.reduce((total, split) => total + split.debit_minor, 0);
}

function formatMinorAsInr(amountMinor: number) {
  return `INR ${(amountMinor / 100).toFixed(2)}`;
}

function formatMinor(amountMinor: number, currency: string) {
  return `${currency || "INR"} ${(amountMinor / 100).toFixed(2)}`;
}

function addDays(date: string, days: number) {
  const parsed = new Date(`${date}T00:00:00.000Z`);
  parsed.setUTCDate(parsed.getUTCDate() + days);
  return parsed.toISOString().slice(0, 10);
}

function defaultAccountsReceivableAccount(accounts: Account[]) {
  return accounts.find((account) => account.subtype === "receivable") ??
    accounts.find((account) => account.code === "1100") ??
    accounts.find((account) => account.type === "asset" && account.name.toLowerCase().includes("receivable"));
}

function defaultAccountsPayableAccount(accounts: Account[]) {
  return accounts.find((account) => account.subtype === "payable") ??
    accounts.find((account) => account.code === "2000") ??
    accounts.find((account) => account.type === "liability" && account.name.toLowerCase().includes("payable"));
}

function formatBytes(sizeBytes: number) {
  if (sizeBytes < 1024) {
    return `${sizeBytes} B`;
  }
  if (sizeBytes < 1024 * 1024) {
    return `${(sizeBytes / 1024).toFixed(1)} KB`;
  }
  return `${(sizeBytes / (1024 * 1024)).toFixed(1)} MB`;
}

function formatTaxBasis(percentageBasis: number) {
  return `${(percentageBasis / 10000).toFixed(4)}%`;
}

function totalTaxGroupBasis(group: TaxGroup) {
  return group.components.reduce((total, component) => total + (component.tax_rate?.percentage_basis ?? 0), 0);
}

function formatTaxGroupComponents(group: TaxGroup) {
  if (group.components.length === 0) {
    return "No components";
  }
  return group.components
    .slice()
    .sort((left, right) => left.sort_order - right.sort_order)
    .map((component) => {
      const rate = component.tax_rate;
      if (!rate) {
        return component.tax_rate_id;
      }
      return `${rate.name} (${formatTaxBasis(rate.percentage_basis)})`;
    })
    .join(" + ");
}

function defaultTaxTarget(taxGroups: TaxGroup[], taxRates: TaxRate[]) {
  const activeGroup = taxGroups.find((group) => group.is_active);
  if (activeGroup) {
    return `group:${activeGroup.id}`;
  }
  const activeRate = taxRates.find((rate) => rate.is_active);
  if (activeRate) {
    return `rate:${activeRate.id}`;
  }
  return "";
}

function parseTaxTarget(target: string) {
  const [kind, id] = target.split(":", 2);
  return {
    kind: kind === "rate" ? "rate" as const : "group" as const,
    id
  };
}

const roleOptions: Role[] = ["admin", "accountant", "bookkeeper", "payroll_manager", "viewer", "employee_self_service"];

function roleLabel(role: Role) {
  return role
    .split("_")
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

function toExchangeRateInput(form: CreateExchangeRateInput): CreateExchangeRateInput {
  return {
    from_currency: form.from_currency.trim().toUpperCase(),
    to_currency: form.to_currency.trim().toUpperCase(),
    rate_date: form.rate_date,
    numerator: form.numerator,
    denominator: form.denominator,
    source: form.source?.trim() || undefined
  };
}

function toPostRevaluationInput(form: PostRevaluationInput): PostRevaluationInput {
  return {
    as_of_date: form.as_of_date,
    gain_loss_account_id: form.gain_loss_account_id
  };
}

function toOrganizationUserInput(form: CreateOrganizationUserInput): CreateOrganizationUserInput {
  return {
    name: form.name.trim(),
    email: form.email.trim(),
    password: form.password,
    role: form.role
  };
}

function toAttachmentInput(form: CreateAttachmentInput): CreateAttachmentInput {
  return {
    file_name: form.file_name.trim(),
    content_type: form.content_type?.trim() || undefined,
    storage_driver: form.storage_driver?.trim() || "local",
    storage_key: form.storage_key.trim(),
    size_bytes: form.size_bytes ?? 0
  };
}

function toBudgetInput(form: { name: string; start_date: string; end_date: string; status: Budget["status"] }, lines: CreateBudgetInput["lines"]): CreateBudgetInput {
  return {
    name: form.name.trim(),
    start_date: form.start_date,
    end_date: form.end_date,
    status: form.status,
    lines
  };
}

function toInvestmentLotInput(form: {
  account_id: string;
  symbol: string;
  security_name: string;
  acquisition_date: string;
  quantity_millis: number;
  cost_basis_minor: number;
  currency: string;
  cost_method: InvestmentLot["cost_method"];
  notes: string;
}): CreateInvestmentLotInput {
  return {
    account_id: form.account_id,
    symbol: form.symbol.trim().toUpperCase(),
    security_name: form.security_name.trim() || undefined,
    acquisition_date: form.acquisition_date,
    quantity_millis: form.quantity_millis,
    cost_basis_minor: form.cost_basis_minor,
    currency: form.currency.trim().toUpperCase() || "INR",
    cost_method: form.cost_method,
    notes: form.notes.trim() || undefined
  };
}

function toInvestmentDividendInput(form: {
  account_id: string;
  symbol: string;
  dividend_date: string;
  amount_minor: number;
  currency: string;
  cash_account_id: string;
  income_account_id: string;
  notes: string;
}): CreateInvestmentDividendInput {
  return {
    account_id: form.account_id,
    symbol: form.symbol.trim().toUpperCase(),
    dividend_date: form.dividend_date,
    amount_minor: form.amount_minor,
    currency: form.currency.trim() || "INR",
    cash_account_id: form.cash_account_id || undefined,
    income_account_id: form.income_account_id || undefined,
    notes: form.notes.trim() || undefined
  };
}

function toInvestmentCorporateActionInput(form: {
  account_id: string;
  symbol: string;
  action_type: InvestmentCorporateAction["action_type"];
  action_date: string;
  ratio_numerator: number;
  ratio_denominator: number;
  notes: string;
}): CreateInvestmentCorporateActionInput {
  return {
    account_id: form.account_id,
    symbol: form.symbol.trim().toUpperCase(),
    action_type: form.action_type,
    action_date: form.action_date,
    ratio_numerator: form.ratio_numerator,
    ratio_denominator: form.ratio_denominator,
    notes: form.notes.trim() || undefined
  };
}

function toImportInvestmentPricesInput(form: { csv: string; source: string; symbol?: string }): ImportInvestmentPricesInput {
  return {
    csv: form.csv,
    source: form.source.trim() || "csv_import",
    symbol: form.symbol?.trim().toUpperCase() || undefined
  };
}

function toImportAMFINAVInput(form: { csv: string; symbol_mode: ImportAMFINAVInput["symbol_mode"] }): ImportAMFINAVInput {
  return {
    text: form.csv,
    symbol_mode: form.symbol_mode ?? "scheme_code"
  };
}

function toSellInvestmentLotInput(form: {
  sale_date: string;
  quantity_millis: number;
  proceeds_minor: number;
  proceeds_account_id: string;
  gain_loss_account_id: string;
  notes: string;
}): SellInvestmentLotInput {
  return {
    sale_date: form.sale_date,
    quantity_millis: form.quantity_millis,
    proceeds_minor: form.proceeds_minor,
    proceeds_account_id: form.proceeds_account_id || undefined,
    gain_loss_account_id: form.gain_loss_account_id || undefined,
    notes: form.notes.trim() || undefined
  };
}

function toCreateOrganizationInput(form: CreateOrganizationInput): CreateOrganizationInput {
  return {
    name: form.name.trim(),
    base_currency: form.base_currency.trim().toUpperCase() || "INR",
    country_code: form.country_code?.trim().toUpperCase() || undefined
  };
}

function toBootstrapFirstAdminInput(form: BootstrapFirstAdminInput): BootstrapFirstAdminInput {
  return {
    organization_name: form.organization_name.trim(),
    admin_name: form.admin_name.trim(),
    admin_email: form.admin_email.trim(),
    admin_password: form.admin_password,
    base_currency: form.base_currency?.trim().toUpperCase() || "INR",
    country_code: form.country_code?.trim().toUpperCase() || undefined,
    seed_india_defaults: form.seed_india_defaults
  };
}

function toTaxAuthorityInput(form: CreateTaxAuthorityInput): CreateTaxAuthorityInput {
  return {
    name: form.name.trim(),
    country_code: form.country_code?.trim().toUpperCase() || undefined,
    region_code: form.region_code?.trim().toUpperCase() || undefined
  };
}

function toTaxRateInput(form: CreateTaxRateInput): CreateTaxRateInput {
  return {
    tax_authority_id: form.tax_authority_id,
    name: form.name.trim(),
    percentage_basis: form.percentage_basis,
    type: form.type,
    output_account_id: form.output_account_id || undefined,
    input_account_id: form.input_account_id || undefined,
    effective_from: form.effective_from,
    effective_to: form.effective_to || undefined,
    is_compound: form.is_compound
  };
}

function toTaxGroupInput(form: CreateTaxGroupInput): CreateTaxGroupInput {
  return {
    name: form.name.trim(),
    description: form.description?.trim() || undefined,
    tax_rate_ids: form.tax_rate_ids
  };
}

function totalBudgetMinor(budget: Budget) {
  return budget.lines?.reduce((total, line) => total + line.amount_minor, 0) ?? 0;
}

function toEmployeeInput(form: EmployeeInput): EmployeeInput {
  return {
    display_name: form.display_name.trim(),
    email: form.email?.trim() || undefined,
    phone: form.phone?.trim() || undefined,
    employee_code: form.employee_code?.trim() || undefined,
    pan: form.pan?.trim() || undefined,
    uan: form.uan?.trim() || undefined
  };
}

function toCustomerInput(form: CustomerInput): CustomerInput {
  return {
    display_name: form.display_name.trim(),
    email: form.email?.trim() || undefined,
    phone: form.phone?.trim() || undefined,
    billing_address: form.billing_address?.trim() || undefined,
    gstin: form.gstin?.trim() || undefined
  };
}

function toVendorInput(form: VendorInput): VendorInput {
  return {
    display_name: form.display_name.trim(),
    email: form.email?.trim() || undefined,
    phone: form.phone?.trim() || undefined,
    billing_address: form.billing_address?.trim() || undefined,
    gstin: form.gstin?.trim() || undefined
  };
}

function toExpenseInput(form: {
  vendor_id: string;
  expense_number: string;
  expense_date: string;
  currency: string;
  tax_inclusive: boolean;
  amount_minor: number;
  expense_account_id: string;
  payment_account_id: string;
  tax_target: string;
  reimbursable: boolean;
}): CreateExpenseInput {
  const taxTarget = form.tax_target ? parseTaxTarget(form.tax_target) : null;
  return {
    vendor_id: form.vendor_id || undefined,
    expense_number: form.expense_number.trim(),
    expense_date: form.expense_date,
    currency: form.currency.trim() || "INR",
    tax_inclusive: form.tax_inclusive,
    amount_minor: form.amount_minor,
    expense_account_id: form.expense_account_id,
    payment_account_id: form.payment_account_id,
    tax_rate_id: taxTarget?.kind === "rate" ? taxTarget.id : undefined,
    tax_group_id: taxTarget?.kind === "group" ? taxTarget.id : undefined,
    reimbursable: form.reimbursable
  };
}

function toRecordPaymentInput(form: {
  payment_number: string;
  payment_date: string;
  payment_method: string;
  reference: string;
  currency: string;
  amount_minor: number;
  payment_account_id: string;
}): RecordPaymentInput {
  return {
    payment_number: form.payment_number.trim(),
    payment_date: form.payment_date,
    payment_method: form.payment_method.trim() || undefined,
    reference: form.reference.trim() || undefined,
    currency: form.currency.trim().toUpperCase() || "INR",
    amount_minor: form.amount_minor,
    payment_account_id: form.payment_account_id
  };
}

function toEstimateInput(form: {
  customer_id: string;
  estimate_number: string;
  issue_date: string;
  expiry_date: string;
  currency: string;
  tax_inclusive: boolean;
  description: string;
  quantity_millis: number;
  unit_price_minor: number;
  income_account_id: string;
  tax_target: string;
}): CreateEstimateInput {
  const taxTarget = form.tax_target ? parseTaxTarget(form.tax_target) : null;
  return {
    customer_id: form.customer_id,
    estimate_number: form.estimate_number.trim(),
    issue_date: form.issue_date,
    expiry_date: form.expiry_date,
    currency: form.currency.trim().toUpperCase() || "INR",
    tax_inclusive: form.tax_inclusive,
    lines: [{
      description: form.description.trim(),
      quantity_millis: form.quantity_millis,
      unit_price_minor: form.unit_price_minor,
      income_account_id: form.income_account_id,
      tax_rate_id: taxTarget?.kind === "rate" ? taxTarget.id : undefined,
      tax_group_id: taxTarget?.kind === "group" ? taxTarget.id : undefined
    }]
  };
}

function toRecurringInvoiceInput(form: {
  customer_id: string;
  name: string;
  invoice_number_prefix: string;
  start_date: string;
  next_run_date: string;
  frequency: RecurringInvoiceTemplate["frequency"];
  due_days: number;
  currency: string;
  tax_inclusive: boolean;
  accounts_receivable_id: string;
  description: string;
  quantity_millis: number;
  unit_price_minor: number;
  income_account_id: string;
  tax_target: string;
}): CreateRecurringInvoiceTemplateInput {
  const taxTarget = form.tax_target ? parseTaxTarget(form.tax_target) : null;
  return {
    customer_id: form.customer_id,
    name: form.name.trim(),
    invoice_number_prefix: form.invoice_number_prefix.trim(),
    start_date: form.start_date,
    next_run_date: form.next_run_date || undefined,
    frequency: form.frequency,
    due_days: form.due_days,
    currency: form.currency.trim().toUpperCase() || "INR",
    tax_inclusive: form.tax_inclusive,
    accounts_receivable_id: form.accounts_receivable_id,
    lines: [{
      description: form.description.trim(),
      quantity_millis: form.quantity_millis,
      unit_price_minor: form.unit_price_minor,
      income_account_id: form.income_account_id,
      tax_rate_id: taxTarget?.kind === "rate" ? taxTarget.id : undefined,
      tax_group_id: taxTarget?.kind === "group" ? taxTarget.id : undefined
    }]
  };
}

function toCreditNoteInput(form: {
  customer_id: string;
  invoice_id: string;
  credit_note_number: string;
  issue_date: string;
  currency: string;
  tax_inclusive: boolean;
  accounts_receivable_id: string;
  description: string;
  quantity_millis: number;
  unit_price_minor: number;
  income_account_id: string;
  tax_target: string;
}): CreateCreditNoteInput {
  const taxTarget = form.tax_target ? parseTaxTarget(form.tax_target) : null;
  return {
    customer_id: form.customer_id,
    invoice_id: form.invoice_id || undefined,
    credit_note_number: form.credit_note_number.trim(),
    issue_date: form.issue_date,
    currency: form.currency.trim().toUpperCase() || "INR",
    tax_inclusive: form.tax_inclusive,
    accounts_receivable_id: form.accounts_receivable_id,
    lines: [{
      description: form.description.trim(),
      quantity_millis: form.quantity_millis,
      unit_price_minor: form.unit_price_minor,
      income_account_id: form.income_account_id,
      tax_rate_id: taxTarget?.kind === "rate" ? taxTarget.id : undefined,
      tax_group_id: taxTarget?.kind === "group" ? taxTarget.id : undefined
    }]
  };
}

function toBillInput(form: {
  vendor_id: string;
  bill_number: string;
  issue_date: string;
  due_date: string;
  currency: string;
  tax_inclusive: boolean;
  accounts_payable_id: string;
  description: string;
  quantity_millis: number;
  unit_price_minor: number;
  expense_account_id: string;
  tax_target: string;
}): CreateBillInput {
  const taxTarget = form.tax_target ? parseTaxTarget(form.tax_target) : null;
  return {
    vendor_id: form.vendor_id,
    bill_number: form.bill_number.trim(),
    issue_date: form.issue_date,
    due_date: form.due_date,
    currency: form.currency.trim() || "INR",
    tax_inclusive: form.tax_inclusive,
    accounts_payable_id: form.accounts_payable_id,
    lines: [
      {
        description: form.description.trim(),
        quantity_millis: form.quantity_millis,
        unit_price_minor: form.unit_price_minor,
        expense_account_id: form.expense_account_id,
        tax_rate_id: taxTarget?.kind === "rate" ? taxTarget.id : undefined,
        tax_group_id: taxTarget?.kind === "group" ? taxTarget.id : undefined
      }
    ]
  };
}

function toPurchaseOrderInput(form: {
  vendor_id: string;
  purchase_order_number: string;
  issue_date: string;
  expected_date: string;
  currency: string;
  tax_inclusive: boolean;
  description: string;
  quantity_millis: number;
  unit_price_minor: number;
  expense_account_id: string;
  tax_target: string;
}): CreatePurchaseOrderInput {
  const taxTarget = form.tax_target ? parseTaxTarget(form.tax_target) : null;
  return {
    vendor_id: form.vendor_id,
    purchase_order_number: form.purchase_order_number.trim(),
    issue_date: form.issue_date,
    expected_date: form.expected_date || undefined,
    currency: form.currency.trim().toUpperCase() || "INR",
    tax_inclusive: form.tax_inclusive,
    lines: [{
      description: form.description.trim(),
      quantity_millis: form.quantity_millis,
      unit_price_minor: form.unit_price_minor,
      expense_account_id: form.expense_account_id,
      tax_rate_id: taxTarget?.kind === "rate" ? taxTarget.id : undefined,
      tax_group_id: taxTarget?.kind === "group" ? taxTarget.id : undefined
    }]
  };
}

function toInvoiceInput(form: {
  customer_id: string;
  invoice_number: string;
  issue_date: string;
  due_date: string;
  currency: string;
  tax_inclusive: boolean;
  accounts_receivable_id: string;
  description: string;
  quantity_millis: number;
  unit_price_minor: number;
  income_account_id: string;
  tax_target: string;
}): CreateInvoiceInput {
  const taxTarget = form.tax_target ? parseTaxTarget(form.tax_target) : null;
  return {
    customer_id: form.customer_id,
    invoice_number: form.invoice_number.trim(),
    issue_date: form.issue_date,
    due_date: form.due_date,
    currency: form.currency.trim() || "INR",
    tax_inclusive: form.tax_inclusive,
    accounts_receivable_id: form.accounts_receivable_id,
    lines: [
      {
        description: form.description.trim(),
        quantity_millis: form.quantity_millis,
        unit_price_minor: form.unit_price_minor,
        income_account_id: form.income_account_id,
        tax_rate_id: taxTarget?.kind === "rate" ? taxTarget.id : undefined,
        tax_group_id: taxTarget?.kind === "group" ? taxTarget.id : undefined
      }
    ]
  };
}

function toPayrollRunInput(form: {
  run_number: string;
  period_start: string;
  period_end: string;
  pay_date: string;
  currency: string;
  employee_id: string;
  gross_pay_minor: number;
  deductions_minor: number;
  basic_pay_minor: number;
  hra_minor: number;
  special_minor: number;
  bonus_minor: number;
  reimbursement_minor: number;
  professional_tax_minor: number;
  tds_minor: number;
  preview_components: CreatePayrollComponentInput[];
  employer_contributions_minor: number;
  payslip_key: string;
  payroll_expense_account_id: string;
  payroll_liability_account_id: string;
  deduction_liability_account_id: string;
  employer_expense_account_id: string;
  employer_liability_account_id: string;
}): CreatePayrollRunInput {
  const manualComponents = [
    form.basic_pay_minor > 0 ? { code: "BASIC", name: "Basic Pay", type: "earning" as const, amount_minor: form.basic_pay_minor } : null,
    form.hra_minor > 0 ? { code: "HRA", name: "House Rent Allowance", type: "earning" as const, amount_minor: form.hra_minor } : null,
    form.special_minor > 0 ? { code: "SPECIAL", name: "Special Allowance", type: "earning" as const, amount_minor: form.special_minor } : null,
    form.bonus_minor > 0 ? { code: "BONUS", name: "Bonus", type: "earning" as const, amount_minor: form.bonus_minor } : null,
    form.reimbursement_minor > 0 ? { code: "REIMB", name: "Reimbursement", type: "earning" as const, amount_minor: form.reimbursement_minor } : null,
    form.professional_tax_minor > 0 ? { code: "PT", name: "Professional Tax", type: "deduction" as const, amount_minor: form.professional_tax_minor, is_statutory: true } : null,
    form.tds_minor > 0 ? { code: "TDS", name: "Tax Deducted at Source", type: "deduction" as const, amount_minor: form.tds_minor, is_statutory: true } : null
  ].filter((component) => component !== null);
  const components = form.preview_components.length > 0 ? form.preview_components : manualComponents;
  const componentGross = components
    .filter((component) => component.type === "earning")
    .reduce((total, component) => total + component.amount_minor, 0);
  const componentDeductions = components
    .filter((component) => component.type === "deduction")
    .reduce((total, component) => total + component.amount_minor, 0);
  return {
    run_number: form.run_number.trim(),
    period_start: form.period_start,
    period_end: form.period_end,
    pay_date: form.pay_date,
    currency: form.currency.trim() || "INR",
    payroll_expense_account_id: form.payroll_expense_account_id,
    payroll_liability_account_id: form.payroll_liability_account_id,
    deduction_liability_account_id: form.deduction_liability_account_id,
    employer_expense_account_id: form.employer_contributions_minor > 0 ? form.employer_expense_account_id : undefined,
    employer_liability_account_id: form.employer_contributions_minor > 0 ? form.employer_liability_account_id : undefined,
    employer_contributions_minor: form.employer_contributions_minor > 0 ? form.employer_contributions_minor : undefined,
    items: [
      {
        employee_id: form.employee_id,
        gross_pay_minor: componentGross > 0 ? componentGross : form.gross_pay_minor,
        deductions_minor: componentDeductions > 0 ? componentDeductions : form.deductions_minor,
        components: components.length > 0 ? components : undefined,
        payslip_key: form.payslip_key.trim() || undefined
      }
    ]
  };
}

function parseTDSSlabs(value: string) {
  return value
    .split(/\r?\n/)
    .map((line, index) => {
      const trimmed = line.trim();
      if (!trimmed) {
        return null;
      }
      const [fromMinor, toMinor, rateBps] = trimmed.split(",").map((part) => part.trim());
      const parsedFrom = Number(fromMinor);
      const parsedTo = toMinor ? Number(toMinor) : 0;
      const parsedRate = Number(rateBps);
      if (!Number.isFinite(parsedFrom) || !Number.isFinite(parsedTo) || !Number.isFinite(parsedRate)) {
        throw new Error(`Invalid TDS slab row ${index + 1}. Use from_minor,to_minor,rate_bps.`);
      }
      return {
        from_minor: parsedFrom,
        to_minor: parsedTo,
        rate_bps: parsedRate
      };
    })
    .filter((slab) => slab !== null);
}

function exportTrialBalance(report: TrialBalanceReport) {
  downloadCsv(
    `trial-balance-${report.as_of_date.slice(0, 10)}.csv`,
    [["Code", "Account", "Type", "Debit minor", "Credit minor", "Balance minor"]],
    report.rows.map(reportRowCsv)
  );
}

function exportProfitAndLoss(report: ProfitAndLossReport) {
  downloadCsv(
    `profit-and-loss-${report.from_date.slice(0, 10)}-to-${report.to_date.slice(0, 10)}.csv`,
    [["Section", "Code", "Account", "Amount minor"]],
    [
      ...report.income_rows.map((row) => ["Income", row.account_code, row.account_name, row.balance_minor]),
      ...report.expense_rows.map((row) => ["Expense", row.account_code, row.account_name, row.balance_minor]),
      ["Total income", "", "", report.total_income_minor],
      ["Total expense", "", "", report.total_expense_minor],
      ["Net income", "", "", report.net_income_minor]
    ]
  );
}

function exportBalanceSheet(report: BalanceSheetReport) {
  downloadCsv(
    `balance-sheet-${report.as_of_date.slice(0, 10)}.csv`,
    [["Section", "Code", "Account", "Balance minor"]],
    [
      ...report.asset_rows.map((row) => ["Assets", row.account_code, row.account_name, row.balance_minor]),
      ...report.liability_rows.map((row) => ["Liabilities", row.account_code, row.account_name, row.balance_minor]),
      ...report.equity_rows.map((row) => ["Equity", row.account_code, row.account_name, row.balance_minor]),
      ["Total assets", "", "", report.total_assets_minor],
      ["Total liabilities", "", "", report.total_liabilities_minor],
      ["Total equity", "", "", report.total_equity_minor],
      ["Balanced", "", "", report.balanced ? "yes" : "no"]
    ]
  );
}

function exportCashFlow(report: CashFlowReport) {
  downloadCsv(
    `cash-flow-${report.from_date.slice(0, 10)}-to-${report.to_date.slice(0, 10)}.csv`,
    [["Code", "Cash account", "Source", "Inflows minor", "Outflows minor", "Net cash flow minor"]],
    [
      ...report.rows.map((row) => [
        row.account_code,
        row.account_name,
        row.source_module,
        row.inflow_minor,
        row.outflow_minor,
        row.net_cash_flow_minor
      ]),
      ["Opening cash", "", "", "", "", report.opening_cash_minor],
      ["Total inflows", "", "", report.total_inflows_minor, "", ""],
      ["Total outflows", "", "", "", report.total_outflows_minor, ""],
      ["Net cash flow", "", "", "", "", report.net_cash_flow_minor],
      ["Closing cash", "", "", "", "", report.closing_cash_minor]
    ]
  );
}

function exportARAging(report: ARAgingReport) {
  downloadCsv(
    `ar-aging-${report.as_of_date.slice(0, 10)}.csv`,
    [["Customer", "Invoice", "Due date", "Days overdue", "Current minor", "1-30 minor", "31-60 minor", "61-90 minor", "90+ minor", "Outstanding minor"]],
    [
      ...report.rows.map((row) => [
        row.customer_name,
        row.invoice_number,
        row.due_date.slice(0, 10),
        row.days_overdue,
        row.current_minor,
        row.one_to_thirty_minor,
        row.thirty_one_to_sixty_minor,
        row.sixty_one_to_ninety_minor,
        row.over_ninety_minor,
        row.outstanding_minor
      ]),
      ["Total", "", "", "", report.total_current_minor, report.total_one_to_thirty_minor, report.total_thirty_one_to_sixty_minor, report.total_sixty_one_to_ninety_minor, report.total_over_ninety_minor, report.total_outstanding_minor]
    ]
  );
}

function exportAPAging(report: APAgingReport) {
  downloadCsv(
    `ap-aging-${report.as_of_date.slice(0, 10)}.csv`,
    [["Vendor", "Bill", "Due date", "Days overdue", "Current minor", "1-30 minor", "31-60 minor", "61-90 minor", "90+ minor", "Outstanding minor"]],
    [
      ...report.rows.map((row) => [
        row.vendor_name,
        row.bill_number,
        row.due_date.slice(0, 10),
        row.days_overdue,
        row.current_minor,
        row.one_to_thirty_minor,
        row.thirty_one_to_sixty_minor,
        row.sixty_one_to_ninety_minor,
        row.over_ninety_minor,
        row.outstanding_minor
      ]),
      ["Total", "", "", "", report.total_current_minor, report.total_one_to_thirty_minor, report.total_thirty_one_to_sixty_minor, report.total_sixty_one_to_ninety_minor, report.total_over_ninety_minor, report.total_outstanding_minor]
    ]
  );
}

function exportTaxLiability(report: TaxLiabilityReport) {
  downloadCsv(
    `gst-liability-${report.from_date.slice(0, 10)}-to-${report.to_date.slice(0, 10)}.csv`,
    [["Tax", "Output tax minor", "Input tax minor", "Net payable minor"]],
    [
      ...report.rows.map(taxReportRowCsv),
      ["Total", report.output_tax_minor, report.input_tax_minor, report.net_payable_minor]
    ]
  );
}

function exportTaxSummary(report: TaxSummaryReport) {
  downloadCsv(
    `gst-summary-${report.from_date.slice(0, 10)}-to-${report.to_date.slice(0, 10)}.csv`,
    [["Tax", "Output tax minor", "Input tax minor", "Net payable minor"]],
    report.rows.map(taxReportRowCsv)
  );
}

function exportPayrollSummary(report: PayrollSummaryReport) {
  downloadCsv(
    `payroll-summary-${report.from_date.slice(0, 10)}-to-${report.to_date.slice(0, 10)}.csv`,
    [["Run", "Period start", "Period end", "Pay date", "Employees", "Gross minor", "Deductions minor", "Net minor", "Employer contributions minor", "Payroll cost minor", "Journal transaction ID"]],
    [
      ...report.rows.map((row) => [
        row.run_number,
        row.period_start.slice(0, 10),
        row.period_end.slice(0, 10),
        row.pay_date.slice(0, 10),
        row.employee_count,
        row.gross_pay_minor,
        row.deductions_minor,
        row.net_pay_minor,
        row.employer_contributions_minor,
        row.payroll_cost_minor,
        row.journal_transaction_id ?? ""
      ]),
      ["Total", "", "", "", report.total_employees, report.total_gross_pay_minor, report.total_deductions_minor, report.total_net_pay_minor, report.total_employer_contributions_minor, report.total_payroll_cost_minor, ""]
    ]
  );
}

function exportBudgetVsActual(report: BudgetVsActualReport) {
  downloadCsv(
    `budget-vs-actual-${report.budget_id}.csv`,
    [["Code", "Account", "Period start", "Period end", "Budget minor", "Actual minor", "Variance minor", "Variance percent"]],
    report.rows.map(budgetVsActualRowCsv)
  );
}

function exportRealizedGains(report: RealizedGainsReport) {
  downloadCsv(
    `realized-gains-${report.from_date.slice(0, 10)}-to-${report.to_date.slice(0, 10)}.csv`,
    [["Sale date", "Lot ID", "Quantity", "Proceeds minor", "Cost basis minor", "Gain/loss minor", "Currency"]],
    [
      ...report.rows.map((row) => [
        row.sale_date.slice(0, 10),
        row.investment_lot_id,
        formatQuantityMillis(row.quantity_millis),
        row.proceeds_minor,
        row.allocated_cost_basis_minor,
        row.realized_gain_loss_minor,
        row.currency
      ]),
      ["Total", "", "", report.total_proceeds_minor, report.total_cost_basis_minor, report.total_gain_loss_minor, ""]
    ]
  );
}

function exportInvestmentDividends(report: InvestmentDividendReport) {
  downloadCsv(
    `investment-dividends-${report.from_date.slice(0, 10)}-to-${report.to_date.slice(0, 10)}.csv`,
    [["Dividend date", "Symbol", "Account ID", "Amount minor", "Currency", "Journal transaction ID"]],
    [
      ...report.rows.map((row) => [
        row.dividend_date.slice(0, 10),
        row.symbol,
        row.account_id,
        row.amount_minor,
        row.currency,
        row.journal_transaction_id ?? ""
      ]),
      ["Total", "", "", report.total_amount_minor, "", ""]
    ]
  );
}

function exportInvestmentCorporateActions(report: InvestmentCorporateActionReport) {
  downloadCsv(
    `investment-corporate-actions-${report.from_date.slice(0, 10)}-to-${report.to_date.slice(0, 10)}.csv`,
    [["Action date", "Symbol", "Action type", "Ratio numerator", "Ratio denominator", "Affected lots", "Quantity delta millis", "Cost basis delta minor", "Account ID", "Notes"]],
    [
      ...report.rows.map((row) => [
        row.action_date.slice(0, 10),
        row.symbol,
        row.action_type,
        row.ratio_numerator,
        row.ratio_denominator,
        row.affected_lots,
        row.quantity_delta_millis,
        row.cost_basis_delta_minor,
        row.account_id,
        row.notes ?? ""
      ]),
      ["Total", "", "", "", "", report.total_affected_lots, report.total_quantity_delta_millis, report.total_cost_basis_delta_minor, "", ""]
    ]
  );
}

function exportInvestmentTaxAdjustments(report: InvestmentTaxAdjustmentReport) {
  downloadCsv(
    `investment-tax-adjustments-${report.from_date.slice(0, 10)}-to-${report.to_date.slice(0, 10)}.csv`,
    [["Sale date", "Symbol", "Disposition ID", "Lot ID", "Quantity", "Proceeds minor", "Cost basis minor", "Realized loss minor", "Replacement quantity", "Deferred loss minor", "Window start", "Window end", "Replacement lot IDs", "Currency", "Notes"]],
    [
      ...report.rows.map((row) => [
        row.sale_date.slice(0, 10),
        row.symbol,
        row.disposition_id,
        row.lot_id,
        formatQuantityMillis(row.quantity_millis),
        row.proceeds_minor,
        row.allocated_cost_basis_minor,
        row.realized_loss_minor,
        formatQuantityMillis(row.replacement_quantity_millis),
        row.deferred_loss_minor,
        row.window_start.slice(0, 10),
        row.window_end.slice(0, 10),
        row.replacement_lot_ids.join(" "),
        row.currency,
        row.notes ?? ""
      ]),
      ["Total", "", "", "", "", "", "", report.total_loss_minor, formatQuantityMillis(report.total_replacement_quantity_millis), report.total_deferred_loss_minor, "", "", "", "", ""]
    ]
  );
}

function exportInvestmentTaxLots(report: InvestmentTaxLotReport) {
  downloadCsv(
    `investment-tax-lots-${report.as_of_date.slice(0, 10)}.csv`,
    [["Symbol", "Lot ID", "Acquired", "Quantity", "Remaining", "Disposed", "Cost basis minor", "Remaining cost minor", "Disposed cost minor", "Proceeds minor", "Realized gain/loss minor", "Unit cost minor", "Currency", "Cost method"]],
    [
      ...report.rows.map((row) => [
        row.symbol,
        row.lot_id,
        row.acquisition_date.slice(0, 10),
        formatQuantityMillis(row.quantity_millis),
        formatQuantityMillis(row.remaining_quantity_millis),
        formatQuantityMillis(row.disposed_quantity_millis),
        row.cost_basis_minor,
        row.remaining_cost_basis_minor,
        row.disposed_cost_basis_minor,
        row.proceeds_minor,
        row.realized_gain_loss_minor,
        row.unit_cost_minor,
        row.currency,
        row.cost_method
      ]),
      ["Total", "", "", formatQuantityMillis(report.total_quantity_millis), formatQuantityMillis(report.total_remaining_quantity_millis), "", report.total_cost_basis_minor, report.total_remaining_cost_basis_minor, "", report.total_proceeds_minor, report.total_realized_gain_loss_minor, "", "", ""]
    ]
  );
}

function exportPayslipPreview(preview: PayslipPreview) {
  downloadCsv(
    `payslip-${safeFilenamePart(preview.run_number)}-${safeFilenamePart(preview.employee.employee_code || preview.employee.display_name)}.csv`,
    [
      ["Run", preview.run_number],
      ["Employee", preview.employee.display_name],
      ["Employee code", preview.employee.employee_code ?? ""],
      ["PAN", preview.employee.pan ?? ""],
      ["UAN", preview.employee.uan ?? ""],
      ["Period", `${preview.period_start.slice(0, 10)} to ${preview.period_end.slice(0, 10)}`],
      ["Pay date", preview.pay_date.slice(0, 10)],
      ["Currency", preview.currency],
      ["Status", preview.status],
      ["Gross pay minor", preview.gross_pay_minor],
      ["Deductions minor", preview.deductions_minor],
      ["Net pay minor", preview.net_pay_minor],
      [],
      ["Section", "Code", "Component", "Amount minor", "Statutory"]
    ],
    [
      ...preview.earnings.map((component) => [
        "Earning",
        component.code,
        component.name,
        component.amount_minor,
        component.is_statutory ? "yes" : "no"
      ]),
      ...preview.deductions.map((component) => [
        "Deduction",
        component.code,
        component.name,
        component.amount_minor,
        component.is_statutory ? "yes" : "no"
      ])
    ]
  );
}

function reportRowCsv(row: ReportRow) {
  return [
    row.account_code,
    row.account_name,
    row.account_type,
    row.debit_minor,
    row.credit_minor,
    row.balance_minor
  ];
}

function taxReportRowCsv(row: TaxReportRow) {
  return [
    row.name,
    row.output_tax_minor,
    row.input_tax_minor,
    row.net_payable_minor
  ];
}

function budgetVsActualRowCsv(row: BudgetVsActualReportRow) {
  return [
    row.account_code,
    row.account_name,
    row.period_start.slice(0, 10),
    row.period_end.slice(0, 10),
    row.budget_minor,
    row.actual_minor,
    row.variance_minor,
    formatBasisPercent(row.variance_percent_basis)
  ];
}

function totalBudgetVarianceMinor(report: BudgetVsActualReport) {
  return report.rows.reduce((total, row) => total + row.variance_minor, 0);
}

function formatBasisPercent(value: number) {
  return `${(value / 10000).toFixed(2)}%`;
}

function formatQuantityMillis(value: number) {
  return (value / 1000).toLocaleString("en-IN", { maximumFractionDigits: 3 });
}

function titleCase(value: string) {
  return value
    .replace(/[_-]+/g, " ")
    .replace(/\b\w/g, (character) => character.toUpperCase());
}

function downloadCsv(filename: string, headerRows: CsvCell[][], dataRows: CsvCell[][]) {
  const csv = [...headerRows, ...dataRows]
    .map((row) => row.map(escapeCsvCell).join(","))
    .join("\n");
  const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
  downloadBlob(filename, blob);
}

function downloadBlob(filename: string, blob: Blob) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}

type CsvCell = string | number | boolean;

function escapeCsvCell(cell: CsvCell) {
  const value = String(cell);
  if (!/[",\n\r]/.test(value)) {
    return value;
  }
  return `"${value.replace(/"/g, "\"\"")}"`;
}
