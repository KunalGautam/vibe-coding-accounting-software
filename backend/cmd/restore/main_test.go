package main

import (
	"crypto/sha256"
	"encoding/hex"
	"os"
	"path/filepath"
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

func TestLoadExpectedSHA256(t *testing.T) {
	dir := t.TempDir()
	checksumFile := filepath.Join(dir, "backup.json.sha256")
	if err := os.WriteFile(checksumFile, []byte(strings.Repeat("a", 64)+"  backup.json\n"), 0o600); err != nil {
		t.Fatalf("write checksum file: %v", err)
	}

	loaded, err := loadExpectedSHA256("", checksumFile)
	if err != nil {
		t.Fatalf("loadExpectedSHA256(file) error = %v", err)
	}
	if loaded != strings.Repeat("a", 64) {
		t.Fatalf("loaded checksum = %q, want sidecar checksum", loaded)
	}

	loaded, err = loadExpectedSHA256(strings.Repeat("b", 64), checksumFile)
	if err != nil {
		t.Fatalf("loadExpectedSHA256(inline) error = %v", err)
	}
	if loaded != strings.Repeat("b", 64) {
		t.Fatalf("loaded checksum = %q, want inline checksum to win", loaded)
	}
}

func TestLoadExpectedSHA256RejectsEmptyFile(t *testing.T) {
	checksumFile := filepath.Join(t.TempDir(), "empty.sha256")
	if err := os.WriteFile(checksumFile, []byte("\n"), 0o600); err != nil {
		t.Fatalf("write checksum file: %v", err)
	}
	if _, err := loadExpectedSHA256("", checksumFile); err == nil {
		t.Fatalf("loadExpectedSHA256() error = nil, want empty-file error")
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
