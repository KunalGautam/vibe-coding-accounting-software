package services

import (
	"context"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/domain"
)

func TestBudgetServiceBudgetVsActual(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if _, err := NewSeedService(db).SeedIndiaDefaults(ctx, org.ID); err != nil {
		t.Fatalf("seed defaults: %v", err)
	}

	bank := mustAccountByCode(t, db, org.ID, "1010")
	income := mustAccountByCode(t, db, org.ID, "4000")
	expense := mustAccountByCode(t, db, org.ID, "6000")

	postTestTransaction(t, db, org.ID, time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC), []domain.LedgerSplit{
		{OrganizationID: org.ID, AccountID: bank.ID, DebitMinor: 70000, Currency: "INR"},
		{OrganizationID: org.ID, AccountID: income.ID, CreditMinor: 70000, Currency: "INR"},
	})
	postTestTransaction(t, db, org.ID, time.Date(2026, 7, 20, 0, 0, 0, 0, time.UTC), []domain.LedgerSplit{
		{OrganizationID: org.ID, AccountID: expense.ID, DebitMinor: 15000, Currency: "INR"},
		{OrganizationID: org.ID, AccountID: bank.ID, CreditMinor: 15000, Currency: "INR"},
	})

	service := NewBudgetService(db)
	budget, err := service.Create(ctx, CreateBudgetInput{
		OrganizationID: org.ID,
		Name:           "FY 2026 Budget",
		StartDate:      time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		EndDate:        time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC),
		Lines: []CreateBudgetLineInput{
			{AccountID: income.ID, PeriodStart: time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), PeriodEnd: time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC), AmountMinor: 60000},
			{AccountID: expense.ID, PeriodStart: time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), PeriodEnd: time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC), AmountMinor: 20000},
		},
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}

	report, err := service.BudgetVsActual(ctx, org.ID, budget.ID)
	if err != nil {
		t.Fatalf("BudgetVsActual() error = %v", err)
	}
	if len(report.Rows) != 2 {
		t.Fatalf("rows = %d, want 2", len(report.Rows))
	}

	incomeRow := budgetRowByAccount(t, report.Rows, income.ID)
	if incomeRow.ActualMinor != 70000 || incomeRow.VarianceMinor != 10000 {
		t.Fatalf("unexpected income row: %+v", incomeRow)
	}
	expenseRow := budgetRowByAccount(t, report.Rows, expense.ID)
	if expenseRow.ActualMinor != 15000 || expenseRow.VarianceMinor != -5000 {
		t.Fatalf("unexpected expense row: %+v", expenseRow)
	}
}

func budgetRowByAccount(t *testing.T, rows []BudgetVsActualReportRow, accountID string) BudgetVsActualReportRow {
	t.Helper()
	for _, row := range rows {
		if row.AccountID == accountID {
			return row
		}
	}
	t.Fatalf("missing budget row for account %s", accountID)
	return BudgetVsActualReportRow{}
}
