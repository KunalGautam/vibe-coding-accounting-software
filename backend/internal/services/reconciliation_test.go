package services

import (
	"context"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/domain"
)

func TestReconciliationServiceImportAndMatchStatementLine(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if _, err := NewSeedService(db).SeedIndiaDefaults(ctx, org.ID); err != nil {
		t.Fatalf("seed defaults: %v", err)
	}

	bank := mustAccountByCode(t, db, org.ID, "1010")
	equity := mustAccountByCode(t, db, org.ID, "3000")
	postTestTransaction(t, db, org.ID, time.Date(2026, 7, 11, 0, 0, 0, 0, time.UTC), []domain.LedgerSplit{
		{OrganizationID: org.ID, AccountID: bank.ID, DebitMinor: 10000, Currency: "INR"},
		{OrganizationID: org.ID, AccountID: equity.ID, CreditMinor: 10000, Currency: "INR"},
	})

	var bankSplit domain.LedgerSplit
	if err := db.Where("organization_id = ? AND account_id = ? AND debit_minor = ?", org.ID, bank.ID, 10000).First(&bankSplit).Error; err != nil {
		t.Fatalf("find bank split: %v", err)
	}

	service := NewReconciliationService(db)
	statementImport, err := service.ImportBankStatement(ctx, ImportBankStatementInput{
		OrganizationID: org.ID,
		AccountID:      bank.ID,
		FileName:       "bank.csv",
		Format:         "csv",
		Lines: []ImportBankStatementLineInput{
			{
				PostedDate:  time.Date(2026, 7, 11, 0, 0, 0, 0, time.UTC),
				Description: "Owner contribution",
				AmountMinor: 10000,
				Reference:   "REF-001",
			},
		},
	})
	if err != nil {
		t.Fatalf("ImportBankStatement() error = %v", err)
	}
	if statementImport.LineCount != 1 {
		t.Fatalf("line count = %d, want 1", statementImport.LineCount)
	}
	if len(statementImport.Lines) != 1 {
		t.Fatalf("lines = %d, want 1", len(statementImport.Lines))
	}

	matched, err := service.MatchStatementLine(ctx, MatchStatementLineInput{
		OrganizationID:  org.ID,
		StatementLineID: statementImport.Lines[0].ID,
		LedgerSplitID:   bankSplit.ID,
	})
	if err != nil {
		t.Fatalf("MatchStatementLine() error = %v", err)
	}
	if matched.MatchedSplitID == nil || *matched.MatchedSplitID != bankSplit.ID {
		t.Fatalf("matched split id = %v, want %s", matched.MatchedSplitID, bankSplit.ID)
	}

	var updatedSplit domain.LedgerSplit
	if err := db.First(&updatedSplit, "id = ?", bankSplit.ID).Error; err != nil {
		t.Fatalf("find updated split: %v", err)
	}
	if !updatedSplit.Cleared || !updatedSplit.Reconciled || updatedSplit.ReconciledAt == nil {
		t.Fatalf("split not reconciled: %+v", updatedSplit)
	}
}

func TestParseQIFBankStatement(t *testing.T) {
	lines, err := ParseQIFBankStatement(`!Type:Bank
D11/07/2026
T1,234.50
PClient receipt
MInvoice INV-1001
NUPI-001
^
D12/07/2026
T-89.05
PBank charges
^`)
	if err != nil {
		t.Fatalf("ParseQIFBankStatement() error = %v", err)
	}
	if len(lines) != 2 {
		t.Fatalf("lines = %d, want 2", len(lines))
	}
	if lines[0].PostedDate.Format("2006-01-02") != "2026-07-11" {
		t.Fatalf("first date = %s, want 2026-07-11", lines[0].PostedDate.Format("2006-01-02"))
	}
	if lines[0].AmountMinor != 123450 {
		t.Fatalf("first amount = %d, want 123450", lines[0].AmountMinor)
	}
	if lines[0].Description != "Client receipt - Invoice INV-1001" {
		t.Fatalf("first description = %q", lines[0].Description)
	}
	if lines[0].Reference != "UPI-001" {
		t.Fatalf("first reference = %q", lines[0].Reference)
	}
	if lines[1].AmountMinor != -8905 {
		t.Fatalf("second amount = %d, want -8905", lines[1].AmountMinor)
	}
}

func TestReconciliationServiceImportQIFBankStatement(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if _, err := NewSeedService(db).SeedIndiaDefaults(ctx, org.ID); err != nil {
		t.Fatalf("seed defaults: %v", err)
	}
	bank := mustAccountByCode(t, db, org.ID, "1010")

	statementImport, err := NewReconciliationService(db).ImportQIFBankStatement(ctx, ImportQIFBankStatementInput{
		OrganizationID: org.ID,
		AccountID:      bank.ID,
		FileName:       "bank.qif",
		Content: `!Type:Bank
D2026-07-13
T250.25
PInterest credit
^`,
	})
	if err != nil {
		t.Fatalf("ImportQIFBankStatement() error = %v", err)
	}
	if statementImport.Format != "qif" {
		t.Fatalf("format = %q, want qif", statementImport.Format)
	}
	if statementImport.LineCount != 1 || len(statementImport.Lines) != 1 {
		t.Fatalf("imported lines = count %d len %d, want 1", statementImport.LineCount, len(statementImport.Lines))
	}
	if statementImport.Lines[0].AmountMinor != 25025 {
		t.Fatalf("amount = %d, want 25025", statementImport.Lines[0].AmountMinor)
	}
}

func TestParseOFXBankStatement(t *testing.T) {
	lines, err := ParseOFXBankStatement(`<OFX>
<BANKMSGSRSV1>
<STMTTRN>
<TRNTYPE>CREDIT
<DTPOSTED>20260713000000[+5.5:IST]
<TRNAMT>1,500.75
<FITID>OFX-001
<NAME>Client receipt
<MEMO>Invoice INV-2001
</STMTTRN>
<STMTTRN>
<TRNTYPE>DEBIT
<DTPOSTED>20260714
<TRNAMT>-125.50
<FITID>OFX-002
<NAME>Bank fee
</STMTTRN>
</BANKMSGSRSV1>
</OFX>`)
	if err != nil {
		t.Fatalf("ParseOFXBankStatement() error = %v", err)
	}
	if len(lines) != 2 {
		t.Fatalf("lines = %d, want 2", len(lines))
	}
	if lines[0].PostedDate.Format("2006-01-02") != "2026-07-13" {
		t.Fatalf("first date = %s, want 2026-07-13", lines[0].PostedDate.Format("2006-01-02"))
	}
	if lines[0].AmountMinor != 150075 {
		t.Fatalf("first amount = %d, want 150075", lines[0].AmountMinor)
	}
	if lines[0].Description != "Client receipt - Invoice INV-2001" {
		t.Fatalf("first description = %q", lines[0].Description)
	}
	if lines[0].Reference != "OFX-001" {
		t.Fatalf("first reference = %q", lines[0].Reference)
	}
	if lines[1].AmountMinor != -12550 {
		t.Fatalf("second amount = %d, want -12550", lines[1].AmountMinor)
	}
}

func TestReconciliationServiceImportOFXBankStatement(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if _, err := NewSeedService(db).SeedIndiaDefaults(ctx, org.ID); err != nil {
		t.Fatalf("seed defaults: %v", err)
	}
	bank := mustAccountByCode(t, db, org.ID, "1010")

	statementImport, err := NewReconciliationService(db).ImportOFXBankStatement(ctx, ImportOFXBankStatementInput{
		OrganizationID: org.ID,
		AccountID:      bank.ID,
		FileName:       "bank.ofx",
		Content: `<OFX>
<STMTTRN>
<DTPOSTED>20260713
<TRNAMT>99.99
<NAME>Interest credit
</STMTTRN>
</OFX>`,
	})
	if err != nil {
		t.Fatalf("ImportOFXBankStatement() error = %v", err)
	}
	if statementImport.Format != "ofx" {
		t.Fatalf("format = %q, want ofx", statementImport.Format)
	}
	if statementImport.LineCount != 1 || len(statementImport.Lines) != 1 {
		t.Fatalf("imported lines = count %d len %d, want 1", statementImport.LineCount, len(statementImport.Lines))
	}
	if statementImport.Lines[0].AmountMinor != 9999 {
		t.Fatalf("amount = %d, want 9999", statementImport.Lines[0].AmountMinor)
	}
}
