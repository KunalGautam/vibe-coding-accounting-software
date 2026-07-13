package services

import (
	"context"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/domain"
)

func TestClosingServiceCloseFiscalYear(t *testing.T) {
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
	retainedEarnings := mustAccountByCode(t, db, org.ID, "3000")

	postTestTransaction(t, db, org.ID, time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC), []domain.LedgerSplit{
		{OrganizationID: org.ID, AccountID: bank.ID, DebitMinor: 70000, Currency: "INR"},
		{OrganizationID: org.ID, AccountID: income.ID, CreditMinor: 70000, Currency: "INR"},
	})
	postTestTransaction(t, db, org.ID, time.Date(2026, 7, 20, 0, 0, 0, 0, time.UTC), []domain.LedgerSplit{
		{OrganizationID: org.ID, AccountID: expense.ID, DebitMinor: 15000, Currency: "INR"},
		{OrganizationID: org.ID, AccountID: bank.ID, CreditMinor: 15000, Currency: "INR"},
	})

	closeRecord, err := NewClosingService(db).CloseFiscalYear(ctx, CloseFiscalYearInput{
		OrganizationID:            org.ID,
		FiscalYearStart:           time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC),
		FiscalYearEnd:             time.Date(2027, 3, 31, 0, 0, 0, 0, time.UTC),
		RetainedEarningsAccountID: retainedEarnings.ID,
	})
	if err != nil {
		t.Fatalf("CloseFiscalYear() error = %v", err)
	}
	if closeRecord.NetIncomeMinor != 55000 {
		t.Fatalf("net income = %d, want 55000", closeRecord.NetIncomeMinor)
	}

	var splits []domain.LedgerSplit
	if err := db.Where("journal_transaction_id = ?", closeRecord.JournalTransactionID).Find(&splits).Error; err != nil {
		t.Fatalf("find splits: %v", err)
	}
	assertSplit(t, splits, income.ID, 70000, 0)
	assertSplit(t, splits, expense.ID, 0, 15000)
	assertSplit(t, splits, retainedEarnings.ID, 0, 55000)
}
