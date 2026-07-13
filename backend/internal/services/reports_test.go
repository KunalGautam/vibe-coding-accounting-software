package services

import (
	"context"
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
