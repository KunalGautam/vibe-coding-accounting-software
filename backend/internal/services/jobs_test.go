package services

import (
	"context"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

func TestJobServiceGenerateDueRecurringInvoicesAcrossOrganizations(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	orgOne := createRecurringInvoiceJobFixture(t, db, ctx, "Acme One", "DUE", time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC))
	createRecurringInvoiceJobFixture(t, db, ctx, "Acme Two", "FUT", time.Date(2026, 8, 1, 0, 0, 0, 0, time.UTC))

	result, err := NewJobService(db).GenerateDueRecurringInvoices(ctx, time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("GenerateDueRecurringInvoices() error = %v", err)
	}
	if result.OrganizationsProcessed != 2 {
		t.Fatalf("organizations processed = %d, want 2", result.OrganizationsProcessed)
	}
	if result.GeneratedCount != 1 {
		t.Fatalf("generated count = %d, want 1", result.GeneratedCount)
	}

	var invoices []domain.Invoice
	if err := db.Where("organization_id = ?", orgOne.ID).Find(&invoices).Error; err != nil {
		t.Fatalf("find org one invoices: %v", err)
	}
	if len(invoices) != 1 {
		t.Fatalf("org one invoices = %d, want 1", len(invoices))
	}
}

func createRecurringInvoiceJobFixture(t *testing.T, db *gorm.DB, ctx context.Context, orgName string, prefix string, startDate time.Time) domain.Organization {
	t.Helper()
	org := domain.Organization{Name: orgName, BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if _, err := NewSeedService(db).SeedIndiaDefaults(ctx, org.ID); err != nil {
		t.Fatalf("seed defaults: %v", err)
	}
	customer := domain.Customer{OrganizationID: org.ID, DisplayName: orgName + " Customer", IsActive: true}
	if err := db.Create(&customer).Error; err != nil {
		t.Fatalf("create customer: %v", err)
	}
	ar := mustAccountByCode(t, db, org.ID, "1100")
	income := mustAccountByCode(t, db, org.ID, "4000")

	if _, err := NewRecurringInvoiceService(db, NewTaxService(db)).Create(ctx, CreateRecurringInvoiceTemplateInput{
		OrganizationID:       org.ID,
		CustomerID:           customer.ID,
		Name:                 prefix + " template",
		InvoiceNumberPrefix:  prefix,
		StartDate:            startDate,
		Frequency:            domain.RecurrenceFrequencyMonthly,
		AccountsReceivableID: ar.ID,
		Lines: []CreateRecurringInvoiceLineInput{{
			Description:     "Retainer",
			QuantityMillis:  1000,
			UnitPriceMinor:  10000,
			IncomeAccountID: income.ID,
		}},
	}); err != nil {
		t.Fatalf("create recurring invoice template: %v", err)
	}
	return org
}
