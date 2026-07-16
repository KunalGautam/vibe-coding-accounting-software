package services

import (
	"bytes"
	"context"
	"strings"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

func TestReportServiceFinancialStatements(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if _, err := NewSeedService(db).SeedIndiaDefaults(ctx, org.ID); err != nil {
		t.Fatalf("seed defaults: %v", err)
	}
	customer := domain.Customer{OrganizationID: org.ID, DisplayName: "Example Customer", IsActive: true}
	if err := db.Create(&customer).Error; err != nil {
		t.Fatalf("create customer: %v", err)
	}
	vendor := domain.Vendor{OrganizationID: org.ID, DisplayName: "Example Vendor", IsActive: true}
	if err := db.Create(&vendor).Error; err != nil {
		t.Fatalf("create vendor: %v", err)
	}

	bank := mustAccountByCode(t, db, org.ID, "1010")
	equity := mustAccountByCode(t, db, org.ID, "3000")
	income := mustAccountByCode(t, db, org.ID, "4000")
	expense := mustAccountByCode(t, db, org.ID, "6000")

	postTestTransaction(t, db, org.ID, time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), []domain.LedgerSplit{
		{OrganizationID: org.ID, AccountID: bank.ID, DebitMinor: 100000, Currency: "INR"},
		{OrganizationID: org.ID, AccountID: equity.ID, CreditMinor: 100000, Currency: "INR"},
	})
	postTestTransaction(t, db, org.ID, time.Date(2026, 7, 2, 0, 0, 0, 0, time.UTC), []domain.LedgerSplit{
		{OrganizationID: org.ID, AccountID: bank.ID, DebitMinor: 50000, Currency: "INR"},
		{OrganizationID: org.ID, AccountID: income.ID, CreditMinor: 50000, Currency: "INR"},
	})
	postTestTransaction(t, db, org.ID, time.Date(2026, 7, 3, 0, 0, 0, 0, time.UTC), []domain.LedgerSplit{
		{OrganizationID: org.ID, AccountID: expense.ID, DebitMinor: 10000, Currency: "INR"},
		{OrganizationID: org.ID, AccountID: bank.ID, CreditMinor: 10000, Currency: "INR"},
	})

	service := NewReportService(db)
	asOf := time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC)
	trialBalance, err := service.TrialBalance(ctx, org.ID, asOf)
	if err != nil {
		t.Fatalf("TrialBalance() error = %v", err)
	}
	if !trialBalance.Balanced {
		t.Fatalf("trial balance should be balanced: %+v", trialBalance)
	}
	if trialBalance.TotalDebitMinor != trialBalance.TotalCreditMinor {
		t.Fatalf("trial debit=%d credit=%d", trialBalance.TotalDebitMinor, trialBalance.TotalCreditMinor)
	}

	pnl, err := service.ProfitAndLoss(ctx, org.ID, time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), asOf)
	if err != nil {
		t.Fatalf("ProfitAndLoss() error = %v", err)
	}
	if pnl.TotalIncomeMinor != 50000 {
		t.Fatalf("income = %d, want 50000", pnl.TotalIncomeMinor)
	}
	if pnl.TotalExpenseMinor != 10000 {
		t.Fatalf("expense = %d, want 10000", pnl.TotalExpenseMinor)
	}
	if pnl.NetIncomeMinor != 40000 {
		t.Fatalf("net income = %d, want 40000", pnl.NetIncomeMinor)
	}

	balanceSheet, err := service.BalanceSheet(ctx, org.ID, asOf)
	if err != nil {
		t.Fatalf("BalanceSheet() error = %v", err)
	}
	if !balanceSheet.Balanced {
		t.Fatalf("balance sheet should be balanced: %+v", balanceSheet)
	}
	if balanceSheet.TotalAssetsMinor != 140000 {
		t.Fatalf("assets = %d, want 140000", balanceSheet.TotalAssetsMinor)
	}

	pdf, filename, err := service.TrialBalancePDF(ctx, org.ID, asOf)
	assertReportPDF(t, pdf, filename, err)
	csvPayload, filename, err := service.TrialBalanceCSV(ctx, org.ID, asOf)
	assertReportCSV(t, csvPayload, filename, err, "Code,Account,Type")
	pdf, filename, err = service.ProfitAndLossPDF(ctx, org.ID, time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), asOf)
	assertReportPDF(t, pdf, filename, err)
	csvPayload, filename, err = service.ProfitAndLossCSV(ctx, org.ID, time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), asOf)
	assertReportCSV(t, csvPayload, filename, err, "Net income")
	pdf, filename, err = service.BalanceSheetPDF(ctx, org.ID, asOf)
	assertReportPDF(t, pdf, filename, err)
	csvPayload, filename, err = service.BalanceSheetCSV(ctx, org.ID, asOf)
	assertReportCSV(t, csvPayload, filename, err, "Total assets")

	cashFlow, err := service.CashFlow(ctx, org.ID, time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), asOf)
	if err != nil {
		t.Fatalf("CashFlow() error = %v", err)
	}
	if cashFlow.OpeningCashMinor != 0 {
		t.Fatalf("opening cash = %d, want 0", cashFlow.OpeningCashMinor)
	}
	if cashFlow.TotalInflowsMinor != 150000 {
		t.Fatalf("cash inflows = %d, want 150000", cashFlow.TotalInflowsMinor)
	}
	if cashFlow.TotalOutflowsMinor != 10000 {
		t.Fatalf("cash outflows = %d, want 10000", cashFlow.TotalOutflowsMinor)
	}
	if cashFlow.NetCashFlowMinor != 140000 {
		t.Fatalf("net cash flow = %d, want 140000", cashFlow.NetCashFlowMinor)
	}
	if cashFlow.ClosingCashMinor != 140000 {
		t.Fatalf("closing cash = %d, want 140000", cashFlow.ClosingCashMinor)
	}
	drilldown, err := service.AccountDrilldown(ctx, org.ID, bank.ID, time.Date(2026, 7, 2, 0, 0, 0, 0, time.UTC), asOf)
	if err != nil {
		t.Fatalf("AccountDrilldown() error = %v", err)
	}
	if drilldown.OpeningBalanceMinor != 100000 {
		t.Fatalf("opening drilldown balance = %d, want 100000", drilldown.OpeningBalanceMinor)
	}
	if drilldown.ClosingBalanceMinor != 140000 {
		t.Fatalf("closing drilldown balance = %d, want 140000", drilldown.ClosingBalanceMinor)
	}
	if len(drilldown.Rows) != 2 {
		t.Fatalf("drilldown rows = %d, want 2", len(drilldown.Rows))
	}
	if drilldown.Rows[0].BalanceMinor != 150000 || drilldown.Rows[1].BalanceMinor != 140000 {
		t.Fatalf("unexpected running balances: %+v", drilldown.Rows)
	}
	pdf, filename, err = service.CashFlowPDF(ctx, org.ID, time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), asOf)
	assertReportPDF(t, pdf, filename, err)
	csvPayload, filename, err = service.CashFlowCSV(ctx, org.ID, time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), asOf)
	assertReportCSV(t, csvPayload, filename, err, "Closing cash")

	agingInvoices := []domain.Invoice{
		{OrganizationID: org.ID, CustomerID: customer.ID, InvoiceNumber: "AR-CURRENT", IssueDate: time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), DueDate: time.Date(2026, 8, 10, 0, 0, 0, 0, time.UTC), Status: domain.InvoiceStatusPosted, Currency: "INR", TotalMinor: 1000, AccountsReceivableID: bank.ID},
		{OrganizationID: org.ID, CustomerID: customer.ID, InvoiceNumber: "AR-030", IssueDate: time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC), DueDate: time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC), Status: domain.InvoiceStatusPosted, Currency: "INR", TotalMinor: 2000, AccountsReceivableID: bank.ID},
		{OrganizationID: org.ID, CustomerID: customer.ID, InvoiceNumber: "AR-060", IssueDate: time.Date(2026, 5, 1, 0, 0, 0, 0, time.UTC), DueDate: time.Date(2026, 6, 15, 0, 0, 0, 0, time.UTC), Status: domain.InvoiceStatusPosted, Currency: "INR", TotalMinor: 3000, AccountsReceivableID: bank.ID},
		{OrganizationID: org.ID, CustomerID: customer.ID, InvoiceNumber: "AR-090", IssueDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC), DueDate: time.Date(2026, 5, 15, 0, 0, 0, 0, time.UTC), Status: domain.InvoiceStatusPosted, Currency: "INR", TotalMinor: 4000, AccountsReceivableID: bank.ID},
		{OrganizationID: org.ID, CustomerID: customer.ID, InvoiceNumber: "AR-OLD", IssueDate: time.Date(2026, 3, 1, 0, 0, 0, 0, time.UTC), DueDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC), Status: domain.InvoiceStatusPosted, Currency: "INR", TotalMinor: 5000, AccountsReceivableID: bank.ID},
		{OrganizationID: org.ID, CustomerID: customer.ID, InvoiceNumber: "AR-PAID", IssueDate: time.Date(2026, 3, 1, 0, 0, 0, 0, time.UTC), DueDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC), Status: domain.InvoiceStatusPaid, Currency: "INR", TotalMinor: 6000, AccountsReceivableID: bank.ID},
	}
	if err := db.Create(&agingInvoices).Error; err != nil {
		t.Fatalf("create aging invoices: %v", err)
	}
	if err := db.Create(&domain.CustomerPayment{
		OrganizationID:       org.ID,
		InvoiceID:            agingInvoices[5].ID,
		PaymentNumber:        "RCPT-PAID",
		PaymentDate:          time.Date(2026, 7, 10, 0, 0, 0, 0, time.UTC),
		Currency:             "INR",
		AmountMinor:          6000,
		PaymentAccountID:     bank.ID,
		JournalTransactionID: agingInvoices[5].ID,
	}).Error; err != nil {
		t.Fatalf("create paid invoice payment: %v", err)
	}
	arAging, err := service.ARAging(ctx, org.ID, asOf)
	if err != nil {
		t.Fatalf("ARAging() error = %v", err)
	}
	if arAging.TotalCurrentMinor != 1000 {
		t.Fatalf("current = %d, want 1000", arAging.TotalCurrentMinor)
	}
	if arAging.TotalOneToThirtyMinor != 2000 {
		t.Fatalf("1-30 = %d, want 2000", arAging.TotalOneToThirtyMinor)
	}
	if arAging.TotalThirtyOneToSixtyMinor != 3000 {
		t.Fatalf("31-60 = %d, want 3000", arAging.TotalThirtyOneToSixtyMinor)
	}
	if arAging.TotalSixtyOneToNinetyMinor != 4000 {
		t.Fatalf("61-90 = %d, want 4000", arAging.TotalSixtyOneToNinetyMinor)
	}
	if arAging.TotalOverNinetyMinor != 5000 {
		t.Fatalf("90+ = %d, want 5000", arAging.TotalOverNinetyMinor)
	}
	if arAging.TotalOutstandingMinor != 15000 {
		t.Fatalf("outstanding = %d, want 15000", arAging.TotalOutstandingMinor)
	}
	pdf, filename, err = service.ARAgingPDF(ctx, org.ID, asOf)
	assertReportPDF(t, pdf, filename, err)
	csvPayload, filename, err = service.ARAgingCSV(ctx, org.ID, asOf)
	assertReportCSV(t, csvPayload, filename, err, "AR-OLD")

	ap := mustAccountByCode(t, db, org.ID, "2000")
	agingBills := []domain.Bill{
		{OrganizationID: org.ID, VendorID: vendor.ID, BillNumber: "AP-CURRENT", IssueDate: time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), DueDate: time.Date(2026, 8, 10, 0, 0, 0, 0, time.UTC), Status: domain.BillStatusPosted, Currency: "INR", TotalMinor: 1100, AccountsPayableID: ap.ID},
		{OrganizationID: org.ID, VendorID: vendor.ID, BillNumber: "AP-030", IssueDate: time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC), DueDate: time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC), Status: domain.BillStatusPosted, Currency: "INR", TotalMinor: 2200, AccountsPayableID: ap.ID},
		{OrganizationID: org.ID, VendorID: vendor.ID, BillNumber: "AP-060", IssueDate: time.Date(2026, 5, 1, 0, 0, 0, 0, time.UTC), DueDate: time.Date(2026, 6, 15, 0, 0, 0, 0, time.UTC), Status: domain.BillStatusPosted, Currency: "INR", TotalMinor: 3300, AccountsPayableID: ap.ID},
		{OrganizationID: org.ID, VendorID: vendor.ID, BillNumber: "AP-090", IssueDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC), DueDate: time.Date(2026, 5, 15, 0, 0, 0, 0, time.UTC), Status: domain.BillStatusPosted, Currency: "INR", TotalMinor: 4400, AccountsPayableID: ap.ID},
		{OrganizationID: org.ID, VendorID: vendor.ID, BillNumber: "AP-OLD", IssueDate: time.Date(2026, 3, 1, 0, 0, 0, 0, time.UTC), DueDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC), Status: domain.BillStatusPosted, Currency: "INR", TotalMinor: 5500, AccountsPayableID: ap.ID},
		{OrganizationID: org.ID, VendorID: vendor.ID, BillNumber: "AP-PAID", IssueDate: time.Date(2026, 3, 1, 0, 0, 0, 0, time.UTC), DueDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC), Status: domain.BillStatusPaid, Currency: "INR", TotalMinor: 6600, AccountsPayableID: ap.ID},
	}
	if err := db.Create(&agingBills).Error; err != nil {
		t.Fatalf("create aging bills: %v", err)
	}
	if err := db.Create(&domain.VendorPayment{
		OrganizationID:       org.ID,
		BillID:               agingBills[5].ID,
		PaymentNumber:        "VPAY-PAID",
		PaymentDate:          time.Date(2026, 7, 10, 0, 0, 0, 0, time.UTC),
		Currency:             "INR",
		AmountMinor:          6600,
		PaymentAccountID:     bank.ID,
		JournalTransactionID: agingBills[5].ID,
	}).Error; err != nil {
		t.Fatalf("create paid bill payment: %v", err)
	}
	apAging, err := service.APAging(ctx, org.ID, asOf)
	if err != nil {
		t.Fatalf("APAging() error = %v", err)
	}
	if apAging.TotalCurrentMinor != 1100 ||
		apAging.TotalOneToThirtyMinor != 2200 ||
		apAging.TotalThirtyOneToSixtyMinor != 3300 ||
		apAging.TotalSixtyOneToNinetyMinor != 4400 ||
		apAging.TotalOverNinetyMinor != 5500 ||
		apAging.TotalOutstandingMinor != 16500 {
		t.Fatalf("unexpected AP aging totals: %+v", apAging)
	}
	pdf, filename, err = service.APAgingPDF(ctx, org.ID, asOf)
	assertReportPDF(t, pdf, filename, err)
	csvPayload, filename, err = service.APAgingCSV(ctx, org.ID, asOf)
	assertReportCSV(t, csvPayload, filename, err, "AP-OLD")
	pdf, filename, err = service.TaxLiabilityPDF(ctx, org.ID, time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), asOf)
	assertReportPDF(t, pdf, filename, err)
	csvPayload, filename, err = service.TaxLiabilityCSV(ctx, org.ID, time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), asOf)
	assertReportCSV(t, csvPayload, filename, err, "Tax,Output tax minor")
	pdf, filename, err = service.TaxSummaryPDF(ctx, org.ID, time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), asOf)
	assertReportPDF(t, pdf, filename, err)
	csvPayload, filename, err = service.TaxSummaryCSV(ctx, org.ID, time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), asOf)
	assertReportCSV(t, csvPayload, filename, err, "Tax,Output tax minor")
}

func TestReportServiceAccountDrilldownIncludesSourceDocumentReference(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Source Links Pvt Ltd", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	customer := domain.Customer{OrganizationID: org.ID, DisplayName: "Linked Customer", IsActive: true}
	if err := db.Create(&customer).Error; err != nil {
		t.Fatalf("create customer: %v", err)
	}
	bank := domain.Account{OrganizationID: org.ID, Code: "1010", Name: "Bank", Type: domain.AccountTypeAsset, Subtype: "Bank", Currency: "INR", IsActive: true}
	income := domain.Account{OrganizationID: org.ID, Code: "4000", Name: "Sales", Type: domain.AccountTypeIncome, Currency: "INR", IsActive: true}
	if err := db.Create(&bank).Error; err != nil {
		t.Fatalf("create bank account: %v", err)
	}
	if err := db.Create(&income).Error; err != nil {
		t.Fatalf("create income account: %v", err)
	}

	transaction, err := NewLedgerService(db).PostTransaction(ctx, PostJournalTransactionInput{
		OrganizationID:  org.ID,
		TransactionDate: time.Date(2026, 7, 16, 0, 0, 0, 0, time.UTC),
		Memo:            "Invoice INV-LINK",
		SourceModule:    domain.SourceModuleInvoice,
		Splits: []PostLedgerSplitInput{
			{AccountID: bank.ID, DebitMinor: 125000, Currency: "INR"},
			{AccountID: income.ID, CreditMinor: 125000, Currency: "INR"},
		},
	})
	if err != nil {
		t.Fatalf("post linked transaction: %v", err)
	}
	invoice := domain.Invoice{
		OrganizationID:       org.ID,
		CustomerID:           customer.ID,
		InvoiceNumber:        "INV-LINK",
		IssueDate:            time.Date(2026, 7, 16, 0, 0, 0, 0, time.UTC),
		DueDate:              time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC),
		Status:               domain.InvoiceStatusPosted,
		Currency:             "INR",
		TotalMinor:           125000,
		AccountsReceivableID: bank.ID,
		JournalTransactionID: &transaction.ID,
	}
	if err := db.Create(&invoice).Error; err != nil {
		t.Fatalf("create linked invoice: %v", err)
	}

	drilldown, err := NewReportService(db).AccountDrilldown(ctx, org.ID, bank.ID, time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("AccountDrilldown() error = %v", err)
	}
	if len(drilldown.Rows) != 1 {
		t.Fatalf("drilldown rows = %d, want 1", len(drilldown.Rows))
	}
	row := drilldown.Rows[0]
	if row.SourceDocumentType != "invoice" || row.SourceDocumentID != invoice.ID || row.SourceDocumentNumber != "INV-LINK" {
		t.Fatalf("unexpected source document ref: %+v", row)
	}
}

func TestReportServicePayrollSummary(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Payroll Reports Co", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if _, err := NewSeedService(db).SeedIndiaDefaults(ctx, org.ID); err != nil {
		t.Fatalf("seed defaults: %v", err)
	}
	employee := domain.Employee{OrganizationID: org.ID, DisplayName: "Employee One", EmployeeCode: "E001", IsActive: true}
	if err := db.Create(&employee).Error; err != nil {
		t.Fatalf("create employee: %v", err)
	}

	payrollExpense := mustAccountByCode(t, db, org.ID, "6100")
	payrollLiability := mustAccountByCode(t, db, org.ID, "2200")
	payroll := NewPayrollService(db)
	postedRun, err := payroll.CreateRun(ctx, CreatePayrollRunInput{
		OrganizationID:              org.ID,
		RunNumber:                   "PAY-POSTED",
		PeriodStart:                 time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		PeriodEnd:                   time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC),
		PayDate:                     time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC),
		PayrollExpenseAccountID:     payrollExpense.ID,
		PayrollLiabilityAccountID:   payrollLiability.ID,
		DeductionLiabilityAccountID: payrollLiability.ID,
		EmployerExpenseAccountID:    payrollExpense.ID,
		EmployerLiabilityAccountID:  payrollLiability.ID,
		EmployerContributionsMinor:  12000,
		Items: []CreatePayrollItemInput{{
			EmployeeID:      employee.ID,
			GrossPayMinor:   100000,
			DeductionsMinor: 10000,
			Components: []CreatePayrollComponentInput{
				{Code: "BASIC", Name: "Basic Pay", Type: domain.PayrollComponentEarning, AmountMinor: 100000},
				{Code: "PF", Name: "Employee Provident Fund", Type: domain.PayrollComponentDeduction, AmountMinor: 5000, IsStatutory: true},
				{Code: "TDS", Name: "Tax Deducted at Source", Type: domain.PayrollComponentDeduction, AmountMinor: 5000, IsStatutory: true},
			},
		}},
	})
	if err != nil {
		t.Fatalf("CreateRun(posted) error = %v", err)
	}
	if _, err := payroll.PostRun(ctx, org.ID, postedRun.ID); err != nil {
		t.Fatalf("PostRun() error = %v", err)
	}
	if _, err := payroll.CreateRun(ctx, CreatePayrollRunInput{
		OrganizationID:              org.ID,
		RunNumber:                   "PAY-DRAFT",
		PeriodStart:                 time.Date(2026, 8, 1, 0, 0, 0, 0, time.UTC),
		PeriodEnd:                   time.Date(2026, 8, 31, 0, 0, 0, 0, time.UTC),
		PayDate:                     time.Date(2026, 8, 31, 0, 0, 0, 0, time.UTC),
		PayrollExpenseAccountID:     payrollExpense.ID,
		PayrollLiabilityAccountID:   payrollLiability.ID,
		DeductionLiabilityAccountID: payrollLiability.ID,
		Items: []CreatePayrollItemInput{{
			EmployeeID:    employee.ID,
			GrossPayMinor: 999999,
		}},
	}); err != nil {
		t.Fatalf("CreateRun(draft) error = %v", err)
	}

	report, err := NewReportService(db).PayrollSummary(ctx, org.ID, time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), time.Date(2026, 8, 31, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("PayrollSummary() error = %v", err)
	}
	if report.TotalRuns != 1 || report.TotalEmployees != 1 || len(report.Rows) != 1 {
		t.Fatalf("unexpected payroll summary row counts: %+v", report)
	}
	if report.TotalGrossPayMinor != 100000 || report.TotalDeductionsMinor != 10000 || report.TotalNetPayMinor != 90000 {
		t.Fatalf("unexpected payroll summary pay totals: %+v", report)
	}
	if report.TotalEmployerContributionsMinor != 12000 || report.TotalPayrollCostMinor != 112000 {
		t.Fatalf("unexpected payroll summary employer totals: %+v", report)
	}

	csvPayload, filename, err := NewReportService(db).PayrollSummaryCSV(ctx, org.ID, time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), time.Date(2026, 8, 31, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("PayrollSummaryCSV() error = %v", err)
	}
	if filename != "payroll-summary-2026-07-01-to-2026-08-31.csv" {
		t.Fatalf("filename = %q", filename)
	}
	csvText := string(csvPayload)
	if !strings.Contains(csvText, "PAY-POSTED") || !strings.Contains(csvText, "Total,,,,,1,100000,10000,90000,12000,112000,") {
		t.Fatalf("unexpected payroll summary csv:\n%s", csvText)
	}

	tdsPayload, tdsFilename, err := NewReportService(db).PayrollStatutoryComponentCSV(ctx, org.ID, time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), time.Date(2026, 8, 31, 0, 0, 0, 0, time.UTC), "TDS")
	if err != nil {
		t.Fatalf("PayrollStatutoryComponentCSV() error = %v", err)
	}
	if tdsFilename != "payroll-tds-statutory-2026-07-01-to-2026-08-31.csv" {
		t.Fatalf("tds filename = %q", tdsFilename)
	}
	tdsText := string(tdsPayload)
	if !strings.Contains(tdsText, "PAY-POSTED,2026-07-01,2026-07-31,2026-07-31,E001,Employee One,,") ||
		!strings.Contains(tdsText, "TDS,Tax Deducted at Source,5000,100000,90000") ||
		!strings.Contains(tdsText, "Total,,,,,,,,TDS,,5000,,") {
		t.Fatalf("unexpected statutory component csv:\n%s", tdsText)
	}
}

func TestReportServiceRunDueScheduledReports(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Scheduled Reports Co", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create org: %v", err)
	}

	emailSender := &captureEmailSender{}
	reportService := NewReportServiceWithEmail(db, emailSender)
	scheduled, err := reportService.CreateScheduledReport(ctx, CreateScheduledReportInput{
		OrganizationID:  org.ID,
		Name:            "Monthly P&L",
		ReportType:      domain.ScheduledReportProfitAndLoss,
		Frequency:       domain.ScheduledReportFrequencyMonthly,
		ParametersJSON:  `{"from_date":"2026-07-01","to_date":"2026-07-31"}`,
		EmailRecipients: "owner@example.com, accountant@example.com",
		NextRunAt:       time.Date(2026, 8, 1, 0, 0, 0, 0, time.UTC),
	})
	if err != nil {
		t.Fatalf("CreateScheduledReport() error = %v", err)
	}

	result, err := reportService.RunDueScheduledReports(ctx, time.Date(2026, 8, 2, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("RunDueScheduledReports() error = %v", err)
	}
	if result.ReportsProcessed != 1 || result.CompletedCount != 1 || result.FailedCount != 0 {
		t.Fatalf("unexpected scheduled report result: %+v", result)
	}

	schedules, err := reportService.ListScheduledReports(ctx, org.ID)
	if err != nil {
		t.Fatalf("ListScheduledReports() error = %v", err)
	}
	if len(schedules) != 1 || schedules[0].ID != scheduled.ID {
		t.Fatalf("unexpected scheduled reports: %+v", schedules)
	}

	var run domain.ScheduledReportRun
	if err := db.Where("scheduled_report_id = ?", scheduled.ID).First(&run).Error; err != nil {
		t.Fatalf("load scheduled report run: %v", err)
	}
	if run.Status != domain.ScheduledReportRunCompleted || run.ReportJSON == "" || run.PeriodStart == nil || run.PeriodEnd == nil {
		t.Fatalf("unexpected scheduled report run: %+v", run)
	}
	if len(emailSender.messages) != 2 {
		t.Fatalf("sent messages = %d, want 2", len(emailSender.messages))
	}
	if emailSender.messages[0].To != "owner@example.com" || !strings.Contains(emailSender.messages[0].Text, "JSON snapshot") {
		t.Fatalf("unexpected scheduled report email: %+v", emailSender.messages[0])
	}
	runs, err := reportService.ListScheduledReportRuns(ctx, org.ID, scheduled.ID)
	if err != nil {
		t.Fatalf("ListScheduledReportRuns() error = %v", err)
	}
	if len(runs) != 1 || runs[0].ID != run.ID {
		t.Fatalf("unexpected scheduled report runs: %+v", runs)
	}

	var updated domain.ScheduledReport
	if err := db.First(&updated, "id = ?", scheduled.ID).Error; err != nil {
		t.Fatalf("load updated schedule: %v", err)
	}
	if updated.LastRunAt == nil || !updated.NextRunAt.After(time.Date(2026, 8, 2, 0, 0, 0, 0, time.UTC)) {
		t.Fatalf("schedule was not advanced: %+v", updated)
	}
}

func postTestTransaction(t *testing.T, db *gorm.DB, organizationID string, transactionDate time.Time, splits []domain.LedgerSplit) {
	t.Helper()
	postedAt := time.Now().UTC()
	transaction := domain.JournalTransaction{
		OrganizationID:  organizationID,
		TransactionDate: transactionDate,
		SourceModule:    domain.SourceModuleManual,
		Status:          domain.JournalStatusPosted,
		PostedAt:        &postedAt,
		Splits:          splits,
	}
	if err := transaction.ValidateBalanced(); err != nil {
		t.Fatalf("test transaction not balanced: %v", err)
	}
	if err := db.Create(&transaction).Error; err != nil {
		t.Fatalf("create test transaction: %v", err)
	}
}

func assertReportPDF(t *testing.T, payload []byte, filename string, err error) {
	t.Helper()
	if err != nil {
		t.Fatalf("report PDF error = %v", err)
	}
	if !bytes.HasPrefix(payload, []byte("%PDF-1.4")) || !bytes.Contains(payload, []byte("%%EOF")) {
		t.Fatalf("report PDF is not complete: %q", string(payload[:min(len(payload), 32)]))
	}
	if !strings.HasSuffix(filename, ".pdf") {
		t.Fatalf("filename = %q, want .pdf suffix", filename)
	}
}

func assertReportCSV(t *testing.T, payload []byte, filename string, err error, expected string) {
	t.Helper()
	if err != nil {
		t.Fatalf("report CSV error = %v", err)
	}
	if !strings.HasSuffix(filename, ".csv") {
		t.Fatalf("filename = %q, want .csv suffix", filename)
	}
	if csvText := string(payload); !strings.Contains(csvText, expected) {
		t.Fatalf("CSV does not contain %q:\n%s", expected, csvText)
	}
}
