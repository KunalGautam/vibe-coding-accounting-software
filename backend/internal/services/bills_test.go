package services

import (
	"context"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/domain"
)

func TestBillServiceCreateAndPostGSTBill(t *testing.T) {
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

	ap := mustAccountByCode(t, db, org.ID, "2000")
	expense := mustAccountByCode(t, db, org.ID, "6000")
	inputGST := mustAccountByCode(t, db, org.ID, "1400")
	gst18 := mustTaxGroupByName(t, db, org.ID, "GST 18%")

	service := NewBillService(db, NewTaxService(db))
	bill, err := service.Create(ctx, CreateBillInput{
		OrganizationID:    org.ID,
		VendorID:          vendor.ID,
		BillNumber:        "BILL-001",
		IssueDate:         time.Date(2026, 7, 11, 0, 0, 0, 0, time.UTC),
		DueDate:           time.Date(2026, 8, 10, 0, 0, 0, 0, time.UTC),
		AccountsPayableID: ap.ID,
		Lines: []CreateBillLineInput{
			{
				Description:      "Office supplies",
				QuantityMillis:   1000,
				UnitPriceMinor:   10000,
				ExpenseAccountID: expense.ID,
				TaxGroupID:       &gst18.ID,
			},
		},
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	if bill.TotalMinor != 11800 {
		t.Fatalf("bill total = %d, want 11800", bill.TotalMinor)
	}

	posted, err := service.Post(ctx, org.ID, bill.ID)
	if err != nil {
		t.Fatalf("Post() error = %v", err)
	}
	if posted.Status != domain.BillStatusPosted {
		t.Fatalf("status = %s, want posted", posted.Status)
	}
	if posted.JournalTransactionID == nil {
		t.Fatalf("journal transaction id is nil")
	}

	var splits []domain.LedgerSplit
	if err := db.Where("journal_transaction_id = ?", *posted.JournalTransactionID).Find(&splits).Error; err != nil {
		t.Fatalf("find splits: %v", err)
	}
	assertSplit(t, splits, expense.ID, 10000, 0)
	assertSplit(t, splits, inputGST.ID, 1800, 0)
	assertSplit(t, splits, ap.ID, 0, 11800)
}
