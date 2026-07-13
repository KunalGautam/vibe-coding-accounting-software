package services

import (
	"context"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/domain"
)

func TestReportServiceTaxLiability(t *testing.T) {
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
	expenseAccount := mustAccountByCode(t, db, org.ID, "6000")
	bank := mustAccountByCode(t, db, org.ID, "1010")
	gst18 := mustTaxGroupByName(t, db, org.ID, "GST 18%")

	invoiceService := NewInvoiceService(db, NewTaxService(db))
	invoice, err := invoiceService.Create(ctx, CreateInvoiceInput{
		OrganizationID:       org.ID,
		CustomerID:           customer.ID,
		InvoiceNumber:        "INV-TAX-001",
		IssueDate:            time.Date(2026, 7, 11, 0, 0, 0, 0, time.UTC),
		DueDate:              time.Date(2026, 8, 10, 0, 0, 0, 0, time.UTC),
		AccountsReceivableID: ar.ID,
		Lines: []CreateInvoiceLineInput{
			{Description: "Consulting", QuantityMillis: 1000, UnitPriceMinor: 10000, IncomeAccountID: income.ID, TaxGroupID: &gst18.ID},
		},
	})
	if err != nil {
		t.Fatalf("create invoice: %v", err)
	}
	if _, err := invoiceService.Post(ctx, org.ID, invoice.ID); err != nil {
		t.Fatalf("post invoice: %v", err)
	}

	expenseService := NewExpenseService(db, NewTaxService(db))
	expense, err := expenseService.Create(ctx, CreateExpenseInput{
		OrganizationID:   org.ID,
		ExpenseNumber:    "EXP-TAX-001",
		ExpenseDate:      time.Date(2026, 7, 12, 0, 0, 0, 0, time.UTC),
		AmountMinor:      5000,
		ExpenseAccountID: expenseAccount.ID,
		PaymentAccountID: bank.ID,
		TaxGroupID:       &gst18.ID,
	})
	if err != nil {
		t.Fatalf("create expense: %v", err)
	}
	if _, err := expenseService.Post(ctx, org.ID, expense.ID); err != nil {
		t.Fatalf("post expense: %v", err)
	}

	report, err := NewReportService(db).TaxLiability(ctx, org.ID, time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("TaxLiability() error = %v", err)
	}
	if report.OutputTaxMinor != 1800 {
		t.Fatalf("output tax = %d, want 1800", report.OutputTaxMinor)
	}
	if report.InputTaxMinor != 900 {
		t.Fatalf("input tax = %d, want 900", report.InputTaxMinor)
	}
	if report.NetPayableMinor != 900 {
		t.Fatalf("net payable = %d, want 900", report.NetPayableMinor)
	}
	if len(report.Rows) != 1 {
		t.Fatalf("rows = %d, want 1", len(report.Rows))
	}
}
