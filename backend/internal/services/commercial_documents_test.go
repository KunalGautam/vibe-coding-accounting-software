package services

import (
	"context"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

func TestCommercialDocumentServiceCreateEstimate(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org, customer, _, income, _, gst18 := commercialDocumentTestFixtures(t, db, ctx)

	estimate, err := NewCommercialDocumentService(db, NewTaxService(db)).CreateEstimate(ctx, CreateEstimateInput{
		OrganizationID: org.ID,
		CustomerID:     customer.ID,
		EstimateNumber: "EST-001",
		IssueDate:      time.Date(2026, 7, 13, 0, 0, 0, 0, time.UTC),
		ExpiryDate:     time.Date(2026, 8, 12, 0, 0, 0, 0, time.UTC),
		Lines: []CreateEstimateLineInput{{
			Description:     "Implementation estimate",
			QuantityMillis:  1000,
			UnitPriceMinor:  10000,
			IncomeAccountID: income.ID,
			TaxGroupID:      &gst18.ID,
		}},
	})
	if err != nil {
		t.Fatalf("CreateEstimate() error = %v", err)
	}
	if estimate.TotalMinor != 11800 || estimate.TaxTotalMinor != 1800 {
		t.Fatalf("estimate totals = total %d tax %d, want 11800/1800", estimate.TotalMinor, estimate.TaxTotalMinor)
	}
	if estimate.Status != domain.EstimateStatusDraft {
		t.Fatalf("estimate status = %s, want draft", estimate.Status)
	}
}

func TestCommercialDocumentServiceConvertEstimateToInvoice(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org, customer, ar, income, _, gst18 := commercialDocumentTestFixtures(t, db, ctx)

	service := NewCommercialDocumentService(db, NewTaxService(db))
	estimate, err := service.CreateEstimate(ctx, CreateEstimateInput{
		OrganizationID: org.ID,
		CustomerID:     customer.ID,
		EstimateNumber: "EST-CONVERT",
		IssueDate:      time.Date(2026, 7, 13, 0, 0, 0, 0, time.UTC),
		ExpiryDate:     time.Date(2026, 8, 12, 0, 0, 0, 0, time.UTC),
		Lines: []CreateEstimateLineInput{{
			Description:     "Implementation estimate",
			QuantityMillis:  1000,
			UnitPriceMinor:  10000,
			IncomeAccountID: income.ID,
			TaxGroupID:      &gst18.ID,
		}},
	})
	if err != nil {
		t.Fatalf("CreateEstimate() error = %v", err)
	}

	invoice, err := service.ConvertEstimateToInvoice(ctx, ConvertEstimateToInvoiceInput{
		OrganizationID:       org.ID,
		EstimateID:           estimate.ID,
		InvoiceNumber:        "INV-FROM-EST",
		IssueDate:            time.Date(2026, 7, 14, 0, 0, 0, 0, time.UTC),
		DueDate:              time.Date(2026, 8, 13, 0, 0, 0, 0, time.UTC),
		AccountsReceivableID: ar.ID,
	})
	if err != nil {
		t.Fatalf("ConvertEstimateToInvoice() error = %v", err)
	}
	if invoice.Status != domain.InvoiceStatusDraft {
		t.Fatalf("invoice status = %s, want draft", invoice.Status)
	}
	if invoice.TotalMinor != estimate.TotalMinor || invoice.TaxTotalMinor != estimate.TaxTotalMinor {
		t.Fatalf("invoice totals = %d/%d, want %d/%d", invoice.TotalMinor, invoice.TaxTotalMinor, estimate.TotalMinor, estimate.TaxTotalMinor)
	}
	if len(invoice.Lines) != 1 {
		t.Fatalf("invoice lines = %d, want 1", len(invoice.Lines))
	}

	var refreshed domain.Estimate
	if err := db.First(&refreshed, "id = ?", estimate.ID).Error; err != nil {
		t.Fatalf("reload estimate: %v", err)
	}
	if refreshed.Status != domain.EstimateStatusConverted {
		t.Fatalf("estimate status = %s, want converted", refreshed.Status)
	}

	if _, err := service.UpdateEstimateStatus(ctx, UpdateEstimateStatusInput{
		OrganizationID: org.ID,
		EstimateID:     estimate.ID,
		Status:         domain.EstimateStatusSent,
	}); err != ErrEstimateStatusInvalid {
		t.Fatalf("UpdateEstimateStatus() error = %v, want %v", err, ErrEstimateStatusInvalid)
	}
}

func TestCommercialDocumentServiceUpdateEstimateStatus(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org, customer, _, income, _, _ := commercialDocumentTestFixtures(t, db, ctx)

	service := NewCommercialDocumentService(db, NewTaxService(db))
	estimate, err := service.CreateEstimate(ctx, CreateEstimateInput{
		OrganizationID: org.ID,
		CustomerID:     customer.ID,
		EstimateNumber: "EST-STATUS",
		IssueDate:      time.Date(2026, 7, 13, 0, 0, 0, 0, time.UTC),
		ExpiryDate:     time.Date(2026, 8, 12, 0, 0, 0, 0, time.UTC),
		Lines: []CreateEstimateLineInput{{
			Description:     "Implementation estimate",
			QuantityMillis:  1000,
			UnitPriceMinor:  10000,
			IncomeAccountID: income.ID,
		}},
	})
	if err != nil {
		t.Fatalf("CreateEstimate() error = %v", err)
	}
	updated, err := service.UpdateEstimateStatus(ctx, UpdateEstimateStatusInput{
		OrganizationID: org.ID,
		EstimateID:     estimate.ID,
		Status:         domain.EstimateStatusAccepted,
	})
	if err != nil {
		t.Fatalf("UpdateEstimateStatus() error = %v", err)
	}
	if updated.Status != domain.EstimateStatusAccepted {
		t.Fatalf("estimate status = %s, want accepted", updated.Status)
	}
}

func TestCommercialDocumentServicePostCreditNote(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org, customer, ar, income, taxPayable, gst18 := commercialDocumentTestFixtures(t, db, ctx)

	service := NewCommercialDocumentService(db, NewTaxService(db))
	creditNote, err := service.CreateCreditNote(ctx, CreateCreditNoteInput{
		OrganizationID:       org.ID,
		CustomerID:           customer.ID,
		CreditNoteNumber:     "CN-001",
		IssueDate:            time.Date(2026, 7, 13, 0, 0, 0, 0, time.UTC),
		AccountsReceivableID: ar.ID,
		Lines: []CreateCreditNoteLineInput{{
			Description:     "Service credit",
			QuantityMillis:  1000,
			UnitPriceMinor:  10000,
			IncomeAccountID: income.ID,
			TaxGroupID:      &gst18.ID,
		}},
	})
	if err != nil {
		t.Fatalf("CreateCreditNote() error = %v", err)
	}

	posted, err := service.PostCreditNote(ctx, org.ID, creditNote.ID)
	if err != nil {
		t.Fatalf("PostCreditNote() error = %v", err)
	}
	if posted.Status != domain.CreditNoteStatusPosted {
		t.Fatalf("credit note status = %s, want posted", posted.Status)
	}
	if posted.JournalTransactionID == nil {
		t.Fatalf("journal transaction id is nil")
	}

	var splits []domain.LedgerSplit
	if err := db.Where("journal_transaction_id = ?", *posted.JournalTransactionID).Find(&splits).Error; err != nil {
		t.Fatalf("find credit note splits: %v", err)
	}
	assertSplit(t, splits, income.ID, 10000, 0)
	assertSplit(t, splits, taxPayable.ID, 1800, 0)
	assertSplit(t, splits, ar.ID, 0, 11800)
}

func TestCommercialDocumentServiceCreatePurchaseOrder(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if _, err := NewSeedService(db).SeedIndiaDefaults(ctx, org.ID); err != nil {
		t.Fatalf("seed defaults: %v", err)
	}
	vendor := domain.Vendor{OrganizationID: org.ID, DisplayName: "Example Vendor", IsActive: true}
	if err := db.Create(&vendor).Error; err != nil {
		t.Fatalf("create vendor: %v", err)
	}
	expense := mustAccountByCode(t, db, org.ID, "6000")
	gst18 := mustTaxGroupByName(t, db, org.ID, "GST 18%")

	purchaseOrder, err := NewCommercialDocumentService(db, NewTaxService(db)).CreatePurchaseOrder(ctx, CreatePurchaseOrderInput{
		OrganizationID:      org.ID,
		VendorID:            vendor.ID,
		PurchaseOrderNumber: "PO-001",
		IssueDate:           time.Date(2026, 7, 13, 0, 0, 0, 0, time.UTC),
		Lines: []CreatePurchaseOrderLineInput{{
			Description:      "Hardware",
			QuantityMillis:   1000,
			UnitPriceMinor:   20000,
			ExpenseAccountID: expense.ID,
			TaxGroupID:       &gst18.ID,
		}},
	})
	if err != nil {
		t.Fatalf("CreatePurchaseOrder() error = %v", err)
	}
	if purchaseOrder.TotalMinor != 23600 || purchaseOrder.TaxTotalMinor != 3600 {
		t.Fatalf("purchase order totals = total %d tax %d, want 23600/3600", purchaseOrder.TotalMinor, purchaseOrder.TaxTotalMinor)
	}
	if purchaseOrder.Status != domain.PurchaseOrderStatusDraft {
		t.Fatalf("purchase order status = %s, want draft", purchaseOrder.Status)
	}
}

func TestCommercialDocumentServiceConvertPurchaseOrderToBill(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if _, err := NewSeedService(db).SeedIndiaDefaults(ctx, org.ID); err != nil {
		t.Fatalf("seed defaults: %v", err)
	}
	vendor := domain.Vendor{OrganizationID: org.ID, DisplayName: "Example Vendor", IsActive: true}
	if err := db.Create(&vendor).Error; err != nil {
		t.Fatalf("create vendor: %v", err)
	}
	expense := mustAccountByCode(t, db, org.ID, "6000")
	ap := mustAccountByCode(t, db, org.ID, "2000")
	gst18 := mustTaxGroupByName(t, db, org.ID, "GST 18%")

	service := NewCommercialDocumentService(db, NewTaxService(db))
	purchaseOrder, err := service.CreatePurchaseOrder(ctx, CreatePurchaseOrderInput{
		OrganizationID:      org.ID,
		VendorID:            vendor.ID,
		PurchaseOrderNumber: "PO-CONVERT",
		IssueDate:           time.Date(2026, 7, 13, 0, 0, 0, 0, time.UTC),
		Lines: []CreatePurchaseOrderLineInput{{
			Description:      "Hardware",
			QuantityMillis:   1000,
			UnitPriceMinor:   20000,
			ExpenseAccountID: expense.ID,
			TaxGroupID:       &gst18.ID,
		}},
	})
	if err != nil {
		t.Fatalf("CreatePurchaseOrder() error = %v", err)
	}

	bill, err := service.ConvertPurchaseOrderToBill(ctx, ConvertPurchaseOrderToBillInput{
		OrganizationID:    org.ID,
		PurchaseOrderID:   purchaseOrder.ID,
		BillNumber:        "BILL-FROM-PO",
		IssueDate:         time.Date(2026, 7, 14, 0, 0, 0, 0, time.UTC),
		DueDate:           time.Date(2026, 8, 13, 0, 0, 0, 0, time.UTC),
		AccountsPayableID: ap.ID,
	})
	if err != nil {
		t.Fatalf("ConvertPurchaseOrderToBill() error = %v", err)
	}
	if bill.Status != domain.BillStatusDraft {
		t.Fatalf("bill status = %s, want draft", bill.Status)
	}
	if bill.TotalMinor != purchaseOrder.TotalMinor || bill.TaxTotalMinor != purchaseOrder.TaxTotalMinor {
		t.Fatalf("bill totals = %d/%d, want %d/%d", bill.TotalMinor, bill.TaxTotalMinor, purchaseOrder.TotalMinor, purchaseOrder.TaxTotalMinor)
	}
	if len(bill.Lines) != 1 {
		t.Fatalf("bill lines = %d, want 1", len(bill.Lines))
	}

	var refreshed domain.PurchaseOrder
	if err := db.First(&refreshed, "id = ?", purchaseOrder.ID).Error; err != nil {
		t.Fatalf("reload purchase order: %v", err)
	}
	if refreshed.Status != domain.PurchaseOrderStatusConverted {
		t.Fatalf("purchase order status = %s, want converted", refreshed.Status)
	}

	if _, err := service.UpdatePurchaseOrderStatus(ctx, UpdatePurchaseOrderStatusInput{
		OrganizationID:  org.ID,
		PurchaseOrderID: purchaseOrder.ID,
		Status:          domain.PurchaseOrderStatusApproved,
	}); err != ErrPurchaseOrderStatusInvalid {
		t.Fatalf("UpdatePurchaseOrderStatus() error = %v, want %v", err, ErrPurchaseOrderStatusInvalid)
	}
}

func TestCommercialDocumentServiceUpdatePurchaseOrderStatus(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if _, err := NewSeedService(db).SeedIndiaDefaults(ctx, org.ID); err != nil {
		t.Fatalf("seed defaults: %v", err)
	}
	vendor := domain.Vendor{OrganizationID: org.ID, DisplayName: "Example Vendor", IsActive: true}
	if err := db.Create(&vendor).Error; err != nil {
		t.Fatalf("create vendor: %v", err)
	}
	expense := mustAccountByCode(t, db, org.ID, "6000")

	service := NewCommercialDocumentService(db, NewTaxService(db))
	purchaseOrder, err := service.CreatePurchaseOrder(ctx, CreatePurchaseOrderInput{
		OrganizationID:      org.ID,
		VendorID:            vendor.ID,
		PurchaseOrderNumber: "PO-STATUS",
		IssueDate:           time.Date(2026, 7, 13, 0, 0, 0, 0, time.UTC),
		Lines: []CreatePurchaseOrderLineInput{{
			Description:      "Hardware",
			QuantityMillis:   1000,
			UnitPriceMinor:   20000,
			ExpenseAccountID: expense.ID,
		}},
	})
	if err != nil {
		t.Fatalf("CreatePurchaseOrder() error = %v", err)
	}
	updated, err := service.UpdatePurchaseOrderStatus(ctx, UpdatePurchaseOrderStatusInput{
		OrganizationID:  org.ID,
		PurchaseOrderID: purchaseOrder.ID,
		Status:          domain.PurchaseOrderStatusApproved,
	})
	if err != nil {
		t.Fatalf("UpdatePurchaseOrderStatus() error = %v", err)
	}
	if updated.Status != domain.PurchaseOrderStatusApproved {
		t.Fatalf("purchase order status = %s, want approved", updated.Status)
	}
}

func commercialDocumentTestFixtures(t *testing.T, db *gorm.DB, ctx context.Context) (domain.Organization, domain.Customer, domain.Account, domain.Account, domain.Account, domain.TaxGroup) {
	t.Helper()
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
	return org, customer, ar, income, taxPayable, gst18
}
