package services

import (
	"context"
	"errors"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

func TestInvoiceServiceCreateAndPostGSTInvoice(t *testing.T) {
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
	taxPayable := mustAccountByCode(t, db, org.ID, "2100")
	gst18 := mustTaxGroupByName(t, db, org.ID, "GST 18%")

	service := NewInvoiceService(db, NewTaxService(db))
	invoice, err := service.Create(ctx, CreateInvoiceInput{
		OrganizationID:       org.ID,
		CustomerID:           customer.ID,
		InvoiceNumber:        "INV-001",
		IssueDate:            time.Date(2026, 7, 11, 0, 0, 0, 0, time.UTC),
		DueDate:              time.Date(2026, 8, 10, 0, 0, 0, 0, time.UTC),
		AccountsReceivableID: ar.ID,
		Lines: []CreateInvoiceLineInput{
			{
				Description:     "Consulting",
				QuantityMillis:  1000,
				UnitPriceMinor:  10000,
				IncomeAccountID: income.ID,
				TaxGroupID:      &gst18.ID,
			},
		},
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	if invoice.SubtotalMinor != 10000 {
		t.Fatalf("subtotal = %d, want 10000", invoice.SubtotalMinor)
	}
	if invoice.TaxTotalMinor != 1800 {
		t.Fatalf("tax total = %d, want 1800", invoice.TaxTotalMinor)
	}
	if invoice.TotalMinor != 11800 {
		t.Fatalf("total = %d, want 11800", invoice.TotalMinor)
	}

	posted, err := service.Post(ctx, org.ID, invoice.ID)
	if err != nil {
		t.Fatalf("Post() error = %v", err)
	}
	if posted.Status != domain.InvoiceStatusPosted {
		t.Fatalf("status = %s, want posted", posted.Status)
	}
	if posted.JournalTransactionID == nil {
		t.Fatalf("journal transaction id is nil")
	}

	var splits []domain.LedgerSplit
	if err := db.Where("journal_transaction_id = ?", *posted.JournalTransactionID).Find(&splits).Error; err != nil {
		t.Fatalf("find splits: %v", err)
	}
	assertSplit(t, splits, ar.ID, 11800, 0)
	assertSplit(t, splits, income.ID, 0, 10000)
	assertSplit(t, splits, taxPayable.ID, 0, 1800)
}

func TestInvoiceServiceCreateStoresScopedPDFAttachment(t *testing.T) {
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
	attachment := domain.Attachment{
		OrganizationID: org.ID,
		FileName:       "INV-002.pdf",
		ContentType:    "application/pdf",
		StorageDriver:  "local",
		StorageKey:     "invoices/INV-002.pdf",
		SizeBytes:      4096,
	}
	if err := db.Create(&attachment).Error; err != nil {
		t.Fatalf("create attachment: %v", err)
	}

	ar := mustAccountByCode(t, db, org.ID, "1100")
	income := mustAccountByCode(t, db, org.ID, "4000")

	service := NewInvoiceService(db, NewTaxService(db))
	invoice, err := service.Create(ctx, CreateInvoiceInput{
		OrganizationID:       org.ID,
		CustomerID:           customer.ID,
		InvoiceNumber:        "INV-002",
		IssueDate:            time.Date(2026, 7, 12, 0, 0, 0, 0, time.UTC),
		DueDate:              time.Date(2026, 8, 11, 0, 0, 0, 0, time.UTC),
		AccountsReceivableID: ar.ID,
		PDFAttachmentID:      &attachment.ID,
		Lines: []CreateInvoiceLineInput{
			{
				Description:     "Implementation",
				QuantityMillis:  1000,
				UnitPriceMinor:  50000,
				IncomeAccountID: income.ID,
			},
		},
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	if invoice.PDFAttachmentID == nil || *invoice.PDFAttachmentID != attachment.ID {
		t.Fatalf("pdf attachment id = %v, want %s", invoice.PDFAttachmentID, attachment.ID)
	}
}

func TestInvoiceServiceCreateRejectsOutOfScopePDFAttachment(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	otherOrg := domain.Organization{Name: "Other India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if err := db.Create(&otherOrg).Error; err != nil {
		t.Fatalf("create other organization: %v", err)
	}
	if _, err := NewSeedService(db).SeedIndiaDefaults(ctx, org.ID); err != nil {
		t.Fatalf("seed defaults: %v", err)
	}

	customer := domain.Customer{OrganizationID: org.ID, DisplayName: "Example Customer", IsActive: true}
	if err := db.Create(&customer).Error; err != nil {
		t.Fatalf("create customer: %v", err)
	}
	attachment := domain.Attachment{
		OrganizationID: otherOrg.ID,
		FileName:       "INV-003.pdf",
		ContentType:    "application/pdf",
		StorageDriver:  "local",
		StorageKey:     "invoices/INV-003.pdf",
		SizeBytes:      4096,
	}
	if err := db.Create(&attachment).Error; err != nil {
		t.Fatalf("create attachment: %v", err)
	}

	ar := mustAccountByCode(t, db, org.ID, "1100")
	income := mustAccountByCode(t, db, org.ID, "4000")

	service := NewInvoiceService(db, NewTaxService(db))
	_, err := service.Create(ctx, CreateInvoiceInput{
		OrganizationID:       org.ID,
		CustomerID:           customer.ID,
		InvoiceNumber:        "INV-003",
		IssueDate:            time.Date(2026, 7, 12, 0, 0, 0, 0, time.UTC),
		DueDate:              time.Date(2026, 8, 11, 0, 0, 0, 0, time.UTC),
		AccountsReceivableID: ar.ID,
		PDFAttachmentID:      &attachment.ID,
		Lines: []CreateInvoiceLineInput{
			{
				Description:     "Implementation",
				QuantityMillis:  1000,
				UnitPriceMinor:  50000,
				IncomeAccountID: income.ID,
			},
		},
	})
	if !errors.Is(err, domain.ErrTenantScope) {
		t.Fatalf("Create() error = %v, want %v", err, domain.ErrTenantScope)
	}
}

func mustAccountByCode(t *testing.T, db *gorm.DB, organizationID string, code string) domain.Account {
	t.Helper()
	var account domain.Account
	if err := db.Where("organization_id = ? AND code = ?", organizationID, code).First(&account).Error; err != nil {
		t.Fatalf("find account %s: %v", code, err)
	}
	return account
}

func mustTaxGroupByName(t *testing.T, db *gorm.DB, organizationID string, name string) domain.TaxGroup {
	t.Helper()
	var group domain.TaxGroup
	if err := db.Where("organization_id = ? AND name = ?", organizationID, name).First(&group).Error; err != nil {
		t.Fatalf("find tax group %s: %v", name, err)
	}
	return group
}

func assertSplit(t *testing.T, splits []domain.LedgerSplit, accountID string, debitMinor int64, creditMinor int64) {
	t.Helper()
	for _, split := range splits {
		if split.AccountID == accountID && split.DebitMinor == debitMinor && split.CreditMinor == creditMinor {
			return
		}
	}
	t.Fatalf("missing split account=%s debit=%d credit=%d in %+v", accountID, debitMinor, creditMinor, splits)
}
