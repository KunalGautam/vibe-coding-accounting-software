package services

import (
	"context"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/domain"
)

func TestInvoicePostingCreatesAuditLog(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if _, err := NewSeedService(db).SeedIndiaDefaults(ctx, org.ID); err != nil {
		t.Fatalf("seed defaults: %v", err)
	}

	customer := domain.Customer{OrganizationID: org.ID, DisplayName: "Customer", IsActive: true}
	if err := db.Create(&customer).Error; err != nil {
		t.Fatalf("create customer: %v", err)
	}

	ar := mustAccountByCode(t, db, org.ID, "1100")
	income := mustAccountByCode(t, db, org.ID, "4000")
	service := NewInvoiceService(db, NewTaxService(db))
	invoice, err := service.Create(ctx, CreateInvoiceInput{
		OrganizationID:       org.ID,
		CustomerID:           customer.ID,
		InvoiceNumber:        "INV-AUDIT-001",
		IssueDate:            time.Date(2026, 7, 11, 0, 0, 0, 0, time.UTC),
		DueDate:              time.Date(2026, 8, 10, 0, 0, 0, 0, time.UTC),
		AccountsReceivableID: ar.ID,
		Lines: []CreateInvoiceLineInput{
			{Description: "Consulting", QuantityMillis: 1000, UnitPriceMinor: 10000, IncomeAccountID: income.ID},
		},
	})
	if err != nil {
		t.Fatalf("create invoice: %v", err)
	}
	if _, err := service.Post(ctx, org.ID, invoice.ID); err != nil {
		t.Fatalf("post invoice: %v", err)
	}

	logs, err := NewAuditService(db).List(ctx, org.ID)
	if err != nil {
		t.Fatalf("list audit logs: %v", err)
	}
	if len(logs) != 1 {
		t.Fatalf("audit logs = %d, want 1", len(logs))
	}
	if logs[0].EntityType != "invoice" || logs[0].EntityID != invoice.ID || logs[0].Action != "post" {
		t.Fatalf("unexpected audit log: %+v", logs[0])
	}
	if logs[0].AfterJSON == "" {
		t.Fatalf("after_json should not be empty")
	}
}
