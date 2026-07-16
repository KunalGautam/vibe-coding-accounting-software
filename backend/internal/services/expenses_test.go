package services

import (
	"context"
	"errors"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/domain"
)

func TestExpenseServiceCreateAndPostGSTExpense(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if _, err := NewSeedService(db).SeedIndiaDefaults(ctx, org.ID); err != nil {
		t.Fatalf("seed defaults: %v", err)
	}

	expenseAccount := mustAccountByCode(t, db, org.ID, "6000")
	bank := mustAccountByCode(t, db, org.ID, "1010")
	inputGST := mustAccountByCode(t, db, org.ID, "1400")
	gst18 := mustTaxGroupByName(t, db, org.ID, "GST 18%")

	service := NewExpenseService(db, NewTaxService(db))
	expense, err := service.Create(ctx, CreateExpenseInput{
		OrganizationID:   org.ID,
		ExpenseNumber:    "EXP-001",
		ExpenseDate:      time.Date(2026, 7, 11, 0, 0, 0, 0, time.UTC),
		AmountMinor:      10000,
		ExpenseAccountID: expenseAccount.ID,
		PaymentAccountID: bank.ID,
		TaxGroupID:       &gst18.ID,
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	if expense.SubtotalMinor != 10000 {
		t.Fatalf("subtotal = %d, want 10000", expense.SubtotalMinor)
	}
	if expense.TaxTotalMinor != 1800 {
		t.Fatalf("tax total = %d, want 1800", expense.TaxTotalMinor)
	}
	if expense.TotalMinor != 11800 {
		t.Fatalf("total = %d, want 11800", expense.TotalMinor)
	}

	posted, err := service.Post(ctx, org.ID, expense.ID)
	if err != nil {
		t.Fatalf("Post() error = %v", err)
	}
	if posted.Status != domain.ExpenseStatusPosted {
		t.Fatalf("status = %s, want posted", posted.Status)
	}
	if posted.JournalTransactionID == nil {
		t.Fatalf("journal transaction id is nil")
	}

	var splits []domain.LedgerSplit
	if err := db.Where("journal_transaction_id = ?", *posted.JournalTransactionID).Find(&splits).Error; err != nil {
		t.Fatalf("find splits: %v", err)
	}
	assertSplit(t, splits, expenseAccount.ID, 10000, 0)
	assertSplit(t, splits, inputGST.ID, 1800, 0)
	assertSplit(t, splits, bank.ID, 0, 11800)
}

func TestExpenseServiceUpdateDraftRecalculatesAndRejectsPosted(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if _, err := NewSeedService(db).SeedIndiaDefaults(ctx, org.ID); err != nil {
		t.Fatalf("seed defaults: %v", err)
	}

	expenseAccount := mustAccountByCode(t, db, org.ID, "6000")
	bank := mustAccountByCode(t, db, org.ID, "1010")
	gst18 := mustTaxGroupByName(t, db, org.ID, "GST 18%")
	service := NewExpenseService(db, NewTaxService(db))

	expense, err := service.Create(ctx, CreateExpenseInput{
		OrganizationID:   org.ID,
		ExpenseNumber:    "EXP-UPD-001",
		ExpenseDate:      time.Date(2026, 7, 11, 0, 0, 0, 0, time.UTC),
		AmountMinor:      10000,
		ExpenseAccountID: expenseAccount.ID,
		PaymentAccountID: bank.ID,
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}

	updated, err := service.Update(ctx, UpdateExpenseInput{
		ExpenseID: expense.ID,
		CreateExpenseInput: CreateExpenseInput{
			OrganizationID:   org.ID,
			ExpenseNumber:    "EXP-UPD-002",
			ExpenseDate:      time.Date(2026, 7, 12, 0, 0, 0, 0, time.UTC),
			AmountMinor:      20000,
			ExpenseAccountID: expenseAccount.ID,
			PaymentAccountID: bank.ID,
			TaxGroupID:       &gst18.ID,
			Reimbursable:     true,
		},
	})
	if err != nil {
		t.Fatalf("Update() error = %v", err)
	}
	if updated.ExpenseNumber != "EXP-UPD-002" {
		t.Fatalf("expense number = %s, want EXP-UPD-002", updated.ExpenseNumber)
	}
	if updated.SubtotalMinor != 20000 || updated.TaxTotalMinor != 3600 || updated.TotalMinor != 23600 {
		t.Fatalf("totals = %d/%d/%d, want 20000/3600/23600", updated.SubtotalMinor, updated.TaxTotalMinor, updated.TotalMinor)
	}
	if !updated.Reimbursable {
		t.Fatalf("reimbursable = false, want true")
	}

	if _, err := service.Post(ctx, org.ID, expense.ID); err != nil {
		t.Fatalf("Post() error = %v", err)
	}
	_, err = service.Update(ctx, UpdateExpenseInput{
		ExpenseID:          expense.ID,
		CreateExpenseInput: updatedInputFromExpense(updated),
	})
	if !errors.Is(err, ErrExpenseAlreadyPosted) {
		t.Fatalf("Update() error = %v, want ErrExpenseAlreadyPosted", err)
	}
}

func updatedInputFromExpense(expense domain.Expense) CreateExpenseInput {
	return CreateExpenseInput{
		OrganizationID:      expense.OrganizationID,
		VendorID:            expense.VendorID,
		ExpenseNumber:       expense.ExpenseNumber,
		ExpenseDate:         expense.ExpenseDate,
		Currency:            expense.Currency,
		TaxInclusive:        expense.TaxInclusive,
		AmountMinor:         expense.TotalMinor,
		ExpenseAccountID:    expense.ExpenseAccountID,
		PaymentAccountID:    expense.PaymentAccountID,
		ReceiptAttachmentID: expense.ReceiptAttachmentID,
		TaxRateID:           expense.TaxRateID,
		TaxGroupID:          expense.TaxGroupID,
		Reimbursable:        expense.Reimbursable,
	}
}
