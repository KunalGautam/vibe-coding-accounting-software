package services

import (
	"context"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/domain"
)

func TestExchangeRateServiceCreate(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	service := NewExchangeRateService(db)
	rate, err := service.Create(ctx, CreateExchangeRateInput{
		OrganizationID: org.ID,
		FromCurrency:   "USD",
		ToCurrency:     "INR",
		RateDate:       time.Date(2026, 7, 11, 0, 0, 0, 0, time.UTC),
		Numerator:      8350,
		Denominator:    100,
		Source:         "manual",
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	if rate.Numerator != 8350 || rate.Denominator != 100 {
		t.Fatalf("unexpected rate: %+v", rate)
	}
}
