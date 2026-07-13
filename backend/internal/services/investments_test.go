package services

import (
	"context"
	"errors"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/domain"
)

func TestInvestmentServiceSellLotCalculatesRealizedGain(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	account := domain.Account{OrganizationID: org.ID, Code: "1500", Name: "Brokerage", Type: domain.AccountTypeAsset, Subtype: "Stock", Currency: "INR", IsActive: true}
	if err := db.Create(&account).Error; err != nil {
		t.Fatalf("create account: %v", err)
	}
	cashAccount := domain.Account{OrganizationID: org.ID, Code: "1010", Name: "Settlement Cash", Type: domain.AccountTypeAsset, Subtype: "Bank", Currency: "INR", IsActive: true}
	if err := db.Create(&cashAccount).Error; err != nil {
		t.Fatalf("create cash account: %v", err)
	}
	gainAccount := domain.Account{OrganizationID: org.ID, Code: "4100", Name: "Investment Gains", Type: domain.AccountTypeIncome, Currency: "INR", IsActive: true}
	if err := db.Create(&gainAccount).Error; err != nil {
		t.Fatalf("create gain account: %v", err)
	}

	service := NewInvestmentService(db)
	lot, err := service.CreateLot(ctx, CreateInvestmentLotInput{
		OrganizationID:  org.ID,
		AccountID:       account.ID,
		Symbol:          "NIFTYBEES",
		SecurityName:    "Nippon India ETF Nifty BeES",
		AcquisitionDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC),
		QuantityMillis:  100000,
		CostBasisMinor:  1000000,
	})
	if err != nil {
		t.Fatalf("CreateLot() error = %v", err)
	}

	disposition, err := service.SellLot(ctx, SellInvestmentLotInput{
		OrganizationID:    org.ID,
		LotID:             lot.ID,
		SaleDate:          time.Date(2026, 7, 12, 0, 0, 0, 0, time.UTC),
		QuantityMillis:    40000,
		ProceedsMinor:     520000,
		ProceedsAccountID: cashAccount.ID,
		GainLossAccountID: gainAccount.ID,
	})
	if err != nil {
		t.Fatalf("SellLot() error = %v", err)
	}
	if disposition.AllocatedCostBasisMinor != 400000 {
		t.Fatalf("allocated cost = %d, want 400000", disposition.AllocatedCostBasisMinor)
	}
	if disposition.RealizedGainLossMinor != 120000 {
		t.Fatalf("gain = %d, want 120000", disposition.RealizedGainLossMinor)
	}
	if disposition.JournalTransactionID == nil {
		t.Fatalf("expected investment sale to post a journal transaction")
	}
	var saleSplits []domain.LedgerSplit
	if err := db.Where("journal_transaction_id = ?", *disposition.JournalTransactionID).Find(&saleSplits).Error; err != nil {
		t.Fatalf("find sale splits: %v", err)
	}
	assertSplit(t, saleSplits, cashAccount.ID, 520000, 0)
	assertSplit(t, saleSplits, account.ID, 0, 400000)
	assertSplit(t, saleSplits, gainAccount.ID, 0, 120000)

	var updated domain.InvestmentLot
	if err := db.First(&updated, "id = ?", lot.ID).Error; err != nil {
		t.Fatalf("load updated lot: %v", err)
	}
	if updated.RemainingQuantityMillis != 60000 {
		t.Fatalf("remaining quantity = %d, want 60000", updated.RemainingQuantityMillis)
	}

	report, err := service.RealizedGains(ctx, org.ID, time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("RealizedGains() error = %v", err)
	}
	if report.TotalGainLoss != 120000 || len(report.Rows) != 1 {
		t.Fatalf("unexpected realized gains report: %+v", report)
	}

	price, err := service.CreatePrice(ctx, CreateInvestmentPriceInput{
		OrganizationID: org.ID,
		Symbol:         "NIFTYBEES",
		PriceDate:      time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC),
		PriceMinor:     14000,
		Currency:       "INR",
		Source:         "manual",
	})
	if err != nil {
		t.Fatalf("CreatePrice() error = %v", err)
	}
	if price.Symbol != "NIFTYBEES" {
		t.Fatalf("price symbol = %s, want NIFTYBEES", price.Symbol)
	}

	valuation, err := service.Valuation(ctx, org.ID, time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("Valuation() error = %v", err)
	}
	if len(valuation.Rows) != 1 {
		t.Fatalf("valuation rows = %d, want 1", len(valuation.Rows))
	}
	if valuation.TotalCostBasisMinor != 600000 || valuation.TotalMarketValueMinor != 840000 || valuation.TotalUnrealizedMinor != 240000 {
		t.Fatalf("unexpected valuation totals: %+v", valuation)
	}
}

func TestInvestmentServiceSellLotRejectsOversell(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	account := domain.Account{OrganizationID: org.ID, Code: "1500", Name: "Brokerage", Type: domain.AccountTypeAsset, Subtype: "Stock", Currency: "INR", IsActive: true}
	if err := db.Create(&account).Error; err != nil {
		t.Fatalf("create account: %v", err)
	}

	service := NewInvestmentService(db)
	lot, err := service.CreateLot(ctx, CreateInvestmentLotInput{
		OrganizationID:  org.ID,
		AccountID:       account.ID,
		Symbol:          "NIFTYBEES",
		AcquisitionDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC),
		QuantityMillis:  1000,
		CostBasisMinor:  10000,
	})
	if err != nil {
		t.Fatalf("CreateLot() error = %v", err)
	}

	_, err = service.SellLot(ctx, SellInvestmentLotInput{
		OrganizationID: org.ID,
		LotID:          lot.ID,
		SaleDate:       time.Date(2026, 7, 12, 0, 0, 0, 0, time.UTC),
		QuantityMillis: 2000,
		ProceedsMinor:  20000,
	})
	if !errors.Is(err, ErrInvestmentLotInsufficientUnits) {
		t.Fatalf("SellLot() error = %v, want %v", err, ErrInvestmentLotInsufficientUnits)
	}
}

func TestInvestmentServiceSellAverageCostConsumesPooledLots(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	investmentAccount := domain.Account{OrganizationID: org.ID, Code: "1500", Name: "Mutual Funds", Type: domain.AccountTypeAsset, Subtype: "Mutual Fund", Currency: "INR", IsActive: true}
	if err := db.Create(&investmentAccount).Error; err != nil {
		t.Fatalf("create investment account: %v", err)
	}
	cashAccount := domain.Account{OrganizationID: org.ID, Code: "1010", Name: "Settlement Cash", Type: domain.AccountTypeAsset, Subtype: "Bank", Currency: "INR", IsActive: true}
	if err := db.Create(&cashAccount).Error; err != nil {
		t.Fatalf("create cash account: %v", err)
	}
	gainAccount := domain.Account{OrganizationID: org.ID, Code: "4100", Name: "Investment Gains", Type: domain.AccountTypeIncome, Currency: "INR", IsActive: true}
	if err := db.Create(&gainAccount).Error; err != nil {
		t.Fatalf("create gain account: %v", err)
	}

	service := NewInvestmentService(db)
	firstLot, err := service.CreateLot(ctx, CreateInvestmentLotInput{
		OrganizationID:  org.ID,
		AccountID:       investmentAccount.ID,
		Symbol:          "LIQUIDFUND",
		AcquisitionDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC),
		QuantityMillis:  100000,
		CostBasisMinor:  1000000,
		CostMethod:      domain.InvestmentCostMethodAverageCost,
	})
	if err != nil {
		t.Fatalf("CreateLot(first) error = %v", err)
	}
	secondLot, err := service.CreateLot(ctx, CreateInvestmentLotInput{
		OrganizationID:  org.ID,
		AccountID:       investmentAccount.ID,
		Symbol:          "LIQUIDFUND",
		AcquisitionDate: time.Date(2026, 5, 1, 0, 0, 0, 0, time.UTC),
		QuantityMillis:  100000,
		CostBasisMinor:  2000000,
		CostMethod:      domain.InvestmentCostMethodAverageCost,
	})
	if err != nil {
		t.Fatalf("CreateLot(second) error = %v", err)
	}

	result, err := service.SellAverageCost(ctx, SellAverageCostInput{
		OrganizationID:    org.ID,
		AccountID:         investmentAccount.ID,
		Symbol:            "LIQUIDFUND",
		Currency:          "INR",
		SaleDate:          time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC),
		QuantityMillis:    150000,
		ProceedsMinor:     2400000,
		ProceedsAccountID: cashAccount.ID,
		GainLossAccountID: gainAccount.ID,
	})
	if err != nil {
		t.Fatalf("SellAverageCost() error = %v", err)
	}
	if result.AllocatedCostBasisMinor != 2250000 || result.RealizedGainLossMinor != 150000 {
		t.Fatalf("unexpected average-cost result: %+v", result)
	}
	if len(result.Dispositions) != 2 {
		t.Fatalf("dispositions = %d, want 2", len(result.Dispositions))
	}
	if result.JournalTransactionID == nil {
		t.Fatalf("journal transaction id is nil")
	}

	var updatedFirst domain.InvestmentLot
	if err := db.First(&updatedFirst, "id = ?", firstLot.ID).Error; err != nil {
		t.Fatalf("load first lot: %v", err)
	}
	if updatedFirst.RemainingQuantityMillis != 0 {
		t.Fatalf("first remaining = %d, want 0", updatedFirst.RemainingQuantityMillis)
	}
	var updatedSecond domain.InvestmentLot
	if err := db.First(&updatedSecond, "id = ?", secondLot.ID).Error; err != nil {
		t.Fatalf("load second lot: %v", err)
	}
	if updatedSecond.RemainingQuantityMillis != 50000 {
		t.Fatalf("second remaining = %d, want 50000", updatedSecond.RemainingQuantityMillis)
	}

	var splits []domain.LedgerSplit
	if err := db.Where("journal_transaction_id = ?", *result.JournalTransactionID).Find(&splits).Error; err != nil {
		t.Fatalf("find sale splits: %v", err)
	}
	assertSplit(t, splits, cashAccount.ID, 2400000, 0)
	assertSplit(t, splits, investmentAccount.ID, 0, 2250000)
	assertSplit(t, splits, gainAccount.ID, 0, 150000)
}
