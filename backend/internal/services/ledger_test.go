package services

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func TestLedgerServicePostTransaction(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	bank := domain.Account{OrganizationID: org.ID, Code: "1000", Name: "Bank", Type: domain.AccountTypeAsset, Currency: "INR", IsActive: true}
	equity := domain.Account{OrganizationID: org.ID, Code: "3000", Name: "Owner Equity", Type: domain.AccountTypeEquity, Currency: "INR", IsActive: true}
	if err := db.Create(&bank).Error; err != nil {
		t.Fatalf("create bank account: %v", err)
	}
	if err := db.Create(&equity).Error; err != nil {
		t.Fatalf("create equity account: %v", err)
	}

	service := NewLedgerService(db)
	transaction, err := service.PostTransaction(ctx, PostJournalTransactionInput{
		OrganizationID:  org.ID,
		TransactionDate: time.Date(2026, 7, 11, 0, 0, 0, 0, time.UTC),
		Memo:            "Owner contribution",
		Splits: []PostLedgerSplitInput{
			{AccountID: bank.ID, DebitMinor: 100000, Currency: "INR"},
			{AccountID: equity.ID, CreditMinor: 100000, Currency: "INR"},
		},
	})
	if err != nil {
		t.Fatalf("PostTransaction() error = %v", err)
	}

	if transaction.Status != domain.JournalStatusPosted {
		t.Fatalf("transaction status = %s, want %s", transaction.Status, domain.JournalStatusPosted)
	}
	if len(transaction.Splits) != 2 {
		t.Fatalf("transaction splits = %d, want 2", len(transaction.Splits))
	}
}

func TestLedgerServicePostTransactionRejectsWrongOrganizationAccount(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	otherOrg := domain.Organization{Name: "Other", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if err := db.Create(&otherOrg).Error; err != nil {
		t.Fatalf("create other organization: %v", err)
	}

	bank := domain.Account{OrganizationID: org.ID, Code: "1000", Name: "Bank", Type: domain.AccountTypeAsset, Currency: "INR", IsActive: true}
	otherEquity := domain.Account{OrganizationID: otherOrg.ID, Code: "3000", Name: "Owner Equity", Type: domain.AccountTypeEquity, Currency: "INR", IsActive: true}
	if err := db.Create(&bank).Error; err != nil {
		t.Fatalf("create bank account: %v", err)
	}
	if err := db.Create(&otherEquity).Error; err != nil {
		t.Fatalf("create other equity account: %v", err)
	}

	service := NewLedgerService(db)
	_, err := service.PostTransaction(ctx, PostJournalTransactionInput{
		OrganizationID:  org.ID,
		TransactionDate: time.Date(2026, 7, 11, 0, 0, 0, 0, time.UTC),
		Splits: []PostLedgerSplitInput{
			{AccountID: bank.ID, DebitMinor: 100000, Currency: "INR"},
			{AccountID: otherEquity.ID, CreditMinor: 100000, Currency: "INR"},
		},
	})
	if !errors.Is(err, domain.ErrLedgerAccountScope) {
		t.Fatalf("PostTransaction() error = %v, want %v", err, domain.ErrLedgerAccountScope)
	}
}

func testDB(t *testing.T) *gorm.DB {
	t.Helper()

	name := strings.NewReplacer("/", "_", " ", "_").Replace(t.Name())
	db, err := gorm.Open(sqlite.Open("file:"+name+"?mode=memory&cache=shared"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open test database: %v", err)
	}
	if err := db.AutoMigrate(domain.AllModels()...); err != nil {
		t.Fatalf("auto migrate test database: %v", err)
	}
	return db
}
