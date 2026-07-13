package services

import (
	"context"
	"testing"

	"accounting.abhashtech.com/internal/domain"
)

func TestTaxServiceCalculateGSTGroupExclusive(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	seeds := NewSeedService(db)
	if _, err := seeds.SeedIndiaDefaults(ctx, org.ID); err != nil {
		t.Fatalf("seed defaults: %v", err)
	}

	var group domain.TaxGroup
	if err := db.Where("organization_id = ? AND name = ?", org.ID, "GST 18%").First(&group).Error; err != nil {
		t.Fatalf("find GST group: %v", err)
	}

	tax := NewTaxService(db)
	result, err := tax.Calculate(ctx, CalculateTaxInput{
		OrganizationID:  org.ID,
		BaseAmountMinor: 10000,
		TaxGroupID:      &group.ID,
	})
	if err != nil {
		t.Fatalf("Calculate() error = %v", err)
	}

	if result.BaseAmountMinor != 10000 {
		t.Fatalf("base amount = %d, want 10000", result.BaseAmountMinor)
	}
	if result.TaxAmountMinor != 1800 {
		t.Fatalf("tax amount = %d, want 1800", result.TaxAmountMinor)
	}
	if result.TotalAmountMinor != 11800 {
		t.Fatalf("total amount = %d, want 11800", result.TotalAmountMinor)
	}
	if len(result.Components) != 2 {
		t.Fatalf("components = %d, want 2", len(result.Components))
	}
	for _, component := range result.Components {
		if component.TaxAmountMinor != 900 {
			t.Fatalf("component tax = %d, want 900", component.TaxAmountMinor)
		}
	}
}

func TestTaxServiceCalculateGSTGroupInclusive(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	seeds := NewSeedService(db)
	if _, err := seeds.SeedIndiaDefaults(ctx, org.ID); err != nil {
		t.Fatalf("seed defaults: %v", err)
	}

	var group domain.TaxGroup
	if err := db.Where("organization_id = ? AND name = ?", org.ID, "GST 18%").First(&group).Error; err != nil {
		t.Fatalf("find GST group: %v", err)
	}

	tax := NewTaxService(db)
	result, err := tax.Calculate(ctx, CalculateTaxInput{
		OrganizationID:  org.ID,
		BaseAmountMinor: 11800,
		TaxInclusive:    true,
		TaxGroupID:      &group.ID,
	})
	if err != nil {
		t.Fatalf("Calculate() error = %v", err)
	}

	if result.BaseAmountMinor != 10000 {
		t.Fatalf("base amount = %d, want 10000", result.BaseAmountMinor)
	}
	if result.TaxAmountMinor != 1800 {
		t.Fatalf("tax amount = %d, want 1800", result.TaxAmountMinor)
	}
	if result.TotalAmountMinor != 11800 {
		t.Fatalf("total amount = %d, want 11800", result.TotalAmountMinor)
	}
}
