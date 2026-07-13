package services

import (
	"context"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/domain"
)

func TestRecurringInvoiceServiceCreateAndGenerateDue(t *testing.T) {
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
	ar := mustAccountByCode(t, db, org.ID, "1100")
	income := mustAccountByCode(t, db, org.ID, "4000")
	gst18 := mustTaxGroupByName(t, db, org.ID, "GST 18%")

	service := NewRecurringInvoiceService(db, NewTaxService(db))
	template, err := service.Create(ctx, CreateRecurringInvoiceTemplateInput{
		OrganizationID:       org.ID,
		CustomerID:           customer.ID,
		Name:                 "Monthly retainer",
		InvoiceNumberPrefix:  "RET",
		StartDate:            time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		Frequency:            domain.RecurrenceFrequencyMonthly,
		DueDays:              15,
		AccountsReceivableID: ar.ID,
		Lines: []CreateRecurringInvoiceLineInput{{
			Description:     "Monthly retainer",
			QuantityMillis:  1000,
			UnitPriceMinor:  10000,
			IncomeAccountID: income.ID,
			TaxGroupID:      &gst18.ID,
		}},
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	if template.TotalMinor != 11800 || template.TaxTotalMinor != 1800 {
		t.Fatalf("template totals = %d/%d, want 11800/1800", template.TotalMinor, template.TaxTotalMinor)
	}

	result, err := service.GenerateDue(ctx, org.ID, time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("GenerateDue() error = %v", err)
	}
	if result.GeneratedCount != 1 {
		t.Fatalf("generated count = %d, want 1", result.GeneratedCount)
	}
	invoice := result.GeneratedInvoices[0]
	if invoice.InvoiceNumber != "RET-20260701" {
		t.Fatalf("invoice number = %s, want RET-20260701", invoice.InvoiceNumber)
	}
	if invoice.Status != domain.InvoiceStatusDraft {
		t.Fatalf("invoice status = %s, want draft", invoice.Status)
	}
	if invoice.DueDate.Format("2006-01-02") != "2026-07-16" {
		t.Fatalf("due date = %s, want 2026-07-16", invoice.DueDate.Format("2006-01-02"))
	}

	var refreshed domain.RecurringInvoiceTemplate
	if err := db.First(&refreshed, "id = ?", template.ID).Error; err != nil {
		t.Fatalf("reload template: %v", err)
	}
	if refreshed.NextRunDate.Format("2006-01-02") != "2026-08-01" {
		t.Fatalf("next run = %s, want 2026-08-01", refreshed.NextRunDate.Format("2006-01-02"))
	}
}

func TestRecurringInvoiceServiceGenerateDueSkipsFutureTemplates(t *testing.T) {
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
	ar := mustAccountByCode(t, db, org.ID, "1100")
	income := mustAccountByCode(t, db, org.ID, "4000")

	service := NewRecurringInvoiceService(db, NewTaxService(db))
	if _, err := service.Create(ctx, CreateRecurringInvoiceTemplateInput{
		OrganizationID:       org.ID,
		CustomerID:           customer.ID,
		Name:                 "Future retainer",
		InvoiceNumberPrefix:  "FUT",
		StartDate:            time.Date(2026, 8, 1, 0, 0, 0, 0, time.UTC),
		Frequency:            domain.RecurrenceFrequencyMonthly,
		AccountsReceivableID: ar.ID,
		Lines: []CreateRecurringInvoiceLineInput{{
			Description:     "Future retainer",
			QuantityMillis:  1000,
			UnitPriceMinor:  10000,
			IncomeAccountID: income.ID,
		}},
	}); err != nil {
		t.Fatalf("Create() error = %v", err)
	}

	result, err := service.GenerateDue(ctx, org.ID, time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("GenerateDue() error = %v", err)
	}
	if result.GeneratedCount != 0 {
		t.Fatalf("generated count = %d, want 0", result.GeneratedCount)
	}
}
