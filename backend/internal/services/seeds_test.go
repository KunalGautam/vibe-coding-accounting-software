package services

import (
	"context"
	"testing"

	"accounting.abhashtech.com/internal/domain"
)

func TestSeedServiceSeedIndiaDefaultsIsIdempotent(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	service := NewSeedService(db)
	first, err := service.SeedIndiaDefaults(ctx, org.ID)
	if err != nil {
		t.Fatalf("SeedIndiaDefaults() first error = %v", err)
	}
	if first.AccountsCreated == 0 || first.TaxRatesCreated == 0 || first.TaxGroupsCreated == 0 || !first.TaxAuthorityCreated {
		t.Fatalf("first seed did not create expected records: %+v", first)
	}

	second, err := service.SeedIndiaDefaults(ctx, org.ID)
	if err != nil {
		t.Fatalf("SeedIndiaDefaults() second error = %v", err)
	}
	if second.AccountsCreated != 0 || second.TaxRatesCreated != 0 || second.TaxGroupsCreated != 0 || second.TaxAuthorityCreated {
		t.Fatalf("second seed should be idempotent, got %+v", second)
	}
}
