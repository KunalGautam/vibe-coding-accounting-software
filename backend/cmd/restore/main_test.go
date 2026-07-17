package main

import (
	"crypto/sha256"
	"encoding/hex"
	"strings"
	"testing"

	"accounting.abhashtech.com/internal/domain"
	"accounting.abhashtech.com/internal/services"
)

func TestVerifyPayloadSHA256(t *testing.T) {
	payload := []byte(`{"organization":{"id":"org-1"}}`)
	sum := sha256.Sum256(payload)
	expected := strings.ToUpper(hex.EncodeToString(sum[:]))

	if err := verifyPayloadSHA256(payload, expected); err != nil {
		t.Fatalf("verifyPayloadSHA256() error = %v, want nil", err)
	}
	if err := verifyPayloadSHA256(payload, ""); err != nil {
		t.Fatalf("verifyPayloadSHA256(empty) error = %v, want nil", err)
	}
	if err := verifyPayloadSHA256(payload, strings.Repeat("0", 64)); err == nil {
		t.Fatalf("verifyPayloadSHA256() error = nil, want mismatch")
	}
}

func TestRestoreSummaryCountsExportRows(t *testing.T) {
	summary := restoreSummary(services.OrganizationDataExport{
		Organization: domain.Organization{BaseModel: domain.BaseModel{ID: "org-restore"}},
		Accounts: []domain.Account{
			{BaseModel: domain.BaseModel{ID: "account-1"}},
			{BaseModel: domain.BaseModel{ID: "account-2"}},
		},
		JournalTransactions: []domain.JournalTransaction{{BaseModel: domain.BaseModel{ID: "journal-1"}}},
		Invoices:            []domain.Invoice{{BaseModel: domain.BaseModel{ID: "invoice-1"}}},
		Expenses:            []domain.Expense{{BaseModel: domain.BaseModel{ID: "expense-1"}}},
		PayrollRuns:         []domain.PayrollRun{{BaseModel: domain.BaseModel{ID: "payroll-1"}}},
		InvestmentLots:      []domain.InvestmentLot{{BaseModel: domain.BaseModel{ID: "lot-1"}}},
	})

	if summary.OrganizationID != "org-restore" ||
		summary.Accounts != 2 ||
		summary.JournalTransactions != 1 ||
		summary.Invoices != 1 ||
		summary.Expenses != 1 ||
		summary.PayrollRuns != 1 ||
		summary.InvestmentLots != 1 {
		t.Fatalf("unexpected restore summary: %+v", summary)
	}
}
