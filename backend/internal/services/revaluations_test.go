package services

import (
	"context"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/domain"
)

func TestRevaluationServicePreviewAndPost(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	usdBank := domain.Account{OrganizationID: org.ID, Code: "1020", Name: "USD Bank", Type: domain.AccountTypeAsset, Subtype: "Bank", Currency: "USD", IsActive: true}
	equity := domain.Account{OrganizationID: org.ID, Code: "3000", Name: "Owner Equity", Type: domain.AccountTypeEquity, Currency: "INR", IsActive: true}
	unrealizedGain := domain.Account{OrganizationID: org.ID, Code: "4900", Name: "Unrealized FX Gain/Loss", Type: domain.AccountTypeIncome, Currency: "INR", IsActive: true}
	if err := db.Create(&usdBank).Error; err != nil {
		t.Fatalf("create usd bank: %v", err)
	}
	if err := db.Create(&equity).Error; err != nil {
		t.Fatalf("create equity: %v", err)
	}
	if err := db.Create(&unrealizedGain).Error; err != nil {
		t.Fatalf("create unrealized gain account: %v", err)
	}

	_, err := NewLedgerService(db).PostTransaction(ctx, PostJournalTransactionInput{
		OrganizationID:  org.ID,
		TransactionDate: time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		Memo:            "USD deposit",
		Splits: []PostLedgerSplitInput{
			{AccountID: usdBank.ID, DebitMinor: 10000, BaseDebitMinor: 800000, Currency: "USD", ExchangeRateNumerator: 8000, ExchangeRateDenominator: 100},
			{AccountID: equity.ID, CreditMinor: 800000, BaseCreditMinor: 800000, Currency: "INR"},
		},
	})
	if err != nil {
		t.Fatalf("post opening transaction: %v", err)
	}

	_, err = NewExchangeRateService(db).Create(ctx, CreateExchangeRateInput{
		OrganizationID: org.ID,
		FromCurrency:   "USD",
		ToCurrency:     "INR",
		RateDate:       time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC),
		Numerator:      8500,
		Denominator:    100,
		Source:         "month-end",
	})
	if err != nil {
		t.Fatalf("create exchange rate: %v", err)
	}

	service := NewRevaluationService(db)
	preview, err := service.Preview(ctx, org.ID, time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("Preview() error = %v", err)
	}
	if len(preview.Rows) != 1 {
		t.Fatalf("rows = %d, want 1", len(preview.Rows))
	}
	if preview.Rows[0].AdjustmentMinor != 50000 {
		t.Fatalf("adjustment = %d, want 50000", preview.Rows[0].AdjustmentMinor)
	}

	transaction, err := service.Post(ctx, PostRevaluationInput{
		OrganizationID:    org.ID,
		AsOfDate:          time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC),
		GainLossAccountID: unrealizedGain.ID,
	})
	if err != nil {
		t.Fatalf("Post() error = %v", err)
	}
	if transaction.SourceModule != domain.SourceModuleRevalue {
		t.Fatalf("source = %s, want %s", transaction.SourceModule, domain.SourceModuleRevalue)
	}
	if len(transaction.Splits) != 2 {
		t.Fatalf("splits = %d, want 2", len(transaction.Splits))
	}
}
