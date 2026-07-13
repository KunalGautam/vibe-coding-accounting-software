package services

import (
	"context"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/domain"
)

func TestPaymentServiceRecordsCustomerPaymentAndMarksInvoicePaid(t *testing.T) {
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

	bank := mustAccountByCode(t, db, org.ID, "1010")
	ar := mustAccountByCode(t, db, org.ID, "1100")
	income := mustAccountByCode(t, db, org.ID, "4000")
	invoice, err := NewInvoiceService(db, NewTaxService(db)).Create(ctx, CreateInvoiceInput{
		OrganizationID:       org.ID,
		CustomerID:           customer.ID,
		InvoiceNumber:        "INV-PAY-001",
		IssueDate:            time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		DueDate:              time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC),
		AccountsReceivableID: ar.ID,
		Lines: []CreateInvoiceLineInput{{
			Description:     "Consulting",
			QuantityMillis:  1000,
			UnitPriceMinor:  5000,
			IncomeAccountID: income.ID,
		}},
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	postedInvoice, err := NewInvoiceService(db, NewTaxService(db)).Post(ctx, org.ID, invoice.ID)
	if err != nil {
		t.Fatalf("Post() error = %v", err)
	}

	payment, err := NewPaymentService(db).RecordCustomerPayment(ctx, RecordCustomerPaymentInput{
		OrganizationID:   org.ID,
		InvoiceID:        postedInvoice.ID,
		PaymentNumber:    "RCPT-001",
		PaymentDate:      time.Date(2026, 7, 5, 0, 0, 0, 0, time.UTC),
		PaymentMethod:    "bank_transfer",
		AmountMinor:      5000,
		PaymentAccountID: bank.ID,
	})
	if err != nil {
		t.Fatalf("RecordCustomerPayment() error = %v", err)
	}

	var refreshed domain.Invoice
	if err := db.First(&refreshed, "id = ?", postedInvoice.ID).Error; err != nil {
		t.Fatalf("reload invoice: %v", err)
	}
	if refreshed.Status != domain.InvoiceStatusPaid {
		t.Fatalf("invoice status = %s, want paid", refreshed.Status)
	}

	var splits []domain.LedgerSplit
	if err := db.Where("journal_transaction_id = ?", payment.JournalTransactionID).Find(&splits).Error; err != nil {
		t.Fatalf("find payment splits: %v", err)
	}
	assertSplit(t, splits, bank.ID, 5000, 0)
	assertSplit(t, splits, ar.ID, 0, 5000)
}

func TestPaymentServiceRecordsPartialVendorPaymentAndAgingUsesOutstanding(t *testing.T) {
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

	bank := mustAccountByCode(t, db, org.ID, "1010")
	ap := mustAccountByCode(t, db, org.ID, "2000")
	expense := mustAccountByCode(t, db, org.ID, "6000")
	bill, err := NewBillService(db, NewTaxService(db)).Create(ctx, CreateBillInput{
		OrganizationID:    org.ID,
		VendorID:          vendor.ID,
		BillNumber:        "BILL-PAY-001",
		IssueDate:         time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		DueDate:           time.Date(2026, 7, 10, 0, 0, 0, 0, time.UTC),
		AccountsPayableID: ap.ID,
		Lines: []CreateBillLineInput{{
			Description:      "Services",
			QuantityMillis:   1000,
			UnitPriceMinor:   9000,
			ExpenseAccountID: expense.ID,
		}},
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	postedBill, err := NewBillService(db, NewTaxService(db)).Post(ctx, org.ID, bill.ID)
	if err != nil {
		t.Fatalf("Post() error = %v", err)
	}

	payment, err := NewPaymentService(db).RecordVendorPayment(ctx, RecordVendorPaymentInput{
		OrganizationID:   org.ID,
		BillID:           postedBill.ID,
		PaymentNumber:    "VPAY-001",
		PaymentDate:      time.Date(2026, 7, 5, 0, 0, 0, 0, time.UTC),
		PaymentMethod:    "bank_transfer",
		AmountMinor:      4000,
		PaymentAccountID: bank.ID,
	})
	if err != nil {
		t.Fatalf("RecordVendorPayment() error = %v", err)
	}

	var refreshed domain.Bill
	if err := db.First(&refreshed, "id = ?", postedBill.ID).Error; err != nil {
		t.Fatalf("reload bill: %v", err)
	}
	if refreshed.Status != domain.BillStatusPosted {
		t.Fatalf("bill status = %s, want posted after partial payment", refreshed.Status)
	}

	var splits []domain.LedgerSplit
	if err := db.Where("journal_transaction_id = ?", payment.JournalTransactionID).Find(&splits).Error; err != nil {
		t.Fatalf("find payment splits: %v", err)
	}
	assertSplit(t, splits, ap.ID, 4000, 0)
	assertSplit(t, splits, bank.ID, 0, 4000)

	report, err := NewReportService(db).APAging(ctx, org.ID, time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("APAging() error = %v", err)
	}
	if report.TotalOutstandingMinor != 5000 {
		t.Fatalf("outstanding = %d, want 5000", report.TotalOutstandingMinor)
	}
}
