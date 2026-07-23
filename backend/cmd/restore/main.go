package main

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"log/slog"
	"os"
	"strings"

	"accounting.abhashtech.com/internal/config"
	"accounting.abhashtech.com/internal/domain"
	"accounting.abhashtech.com/internal/services"
)

func main() {
	filePath := flag.String("file", "", "path to organization export or backup JSON")
	expectedSHA256 := flag.String("sha256", "", "expected SHA-256 checksum for the restore file")
	expectedSHA256File := flag.String("sha256-file", "", "path to a sha256sum-style checksum sidecar file")
	dryRun := flag.Bool("dry-run", false, "parse and validate the restore file without writing to the database")
	flag.Parse()
	if *filePath == "" {
		log.Fatal("restore requires -file")
	}

	payload, err := os.ReadFile(*filePath)
	if err != nil {
		log.Fatalf("read restore file: %v", err)
	}
	expectedChecksum, err := loadExpectedSHA256(*expectedSHA256, *expectedSHA256File)
	if err != nil {
		log.Fatalf("load restore file checksum: %v", err)
	}
	if err := verifyPayloadSHA256(payload, expectedChecksum); err != nil {
		log.Fatalf("verify restore file checksum: %v", err)
	}

	var export services.OrganizationDataExport
	if err := json.Unmarshal(payload, &export); err != nil {
		log.Fatalf("parse restore file: %v", err)
	}

	cfg := config.Load()
	if err := cfg.Validate(); err != nil {
		log.Fatalf("validate config: %v", err)
	}
	logger, err := cfg.Logger(os.Stdout)
	if err != nil {
		log.Fatalf("configure logger: %v", err)
	}
	slog.SetDefault(logger)
	if *dryRun {
		result := restoreSummary(export)
		logger.Info("restore_dry_run_complete",
			slog.String("organization_id", result.OrganizationID),
			slog.Int("accounts", result.Accounts),
			slog.Int("journal_transactions", result.JournalTransactions),
			slog.Int("invoices", result.Invoices),
			slog.Int("expenses", result.Expenses),
			slog.Int("payroll_runs", result.PayrollRuns),
			slog.Int("investment_lots", result.InvestmentLots),
		)
		return
	}
	db, err := config.OpenDatabase(cfg)
	if err != nil {
		log.Fatalf("open database: %v", err)
	}
	if err := db.AutoMigrate(domain.AllModels()...); err != nil {
		log.Fatalf("auto migrate database: %v", err)
	}

	result, err := services.NewDataExportService(db).RestoreOrganization(context.Background(), export)
	if err != nil {
		log.Fatalf("restore organization: %v", err)
	}
	logger.Info("restore_complete",
		slog.String("organization_id", result.OrganizationID),
		slog.Int("accounts", result.Accounts),
		slog.Int("journal_transactions", result.JournalTransactions),
		slog.Int("invoices", result.Invoices),
		slog.Int("expenses", result.Expenses),
		slog.Int("payroll_runs", result.PayrollRuns),
		slog.Int("investment_lots", result.InvestmentLots),
	)
}

func loadExpectedSHA256(inline string, checksumFile string) (string, error) {
	inline = strings.TrimSpace(inline)
	if inline != "" {
		return inline, nil
	}
	checksumFile = strings.TrimSpace(checksumFile)
	if checksumFile == "" {
		return "", nil
	}
	payload, err := os.ReadFile(checksumFile)
	if err != nil {
		return "", err
	}
	fields := strings.Fields(string(payload))
	if len(fields) == 0 {
		return "", fmt.Errorf("checksum file %s is empty", checksumFile)
	}
	return fields[0], nil
}

func verifyPayloadSHA256(payload []byte, expected string) error {
	expected = strings.TrimSpace(strings.ToLower(expected))
	if expected == "" {
		return nil
	}
	sum := sha256.Sum256(payload)
	actual := hex.EncodeToString(sum[:])
	if actual != expected {
		return fmt.Errorf("checksum mismatch: got %s, want %s", actual, expected)
	}
	return nil
}

func restoreSummary(export services.OrganizationDataExport) services.RestoreOrganizationResult {
	return services.RestoreOrganizationResult{
		OrganizationID:      export.Organization.ID,
		Accounts:            len(export.Accounts),
		JournalTransactions: len(export.JournalTransactions),
		Invoices:            len(export.Invoices),
		Expenses:            len(export.Expenses),
		PayrollRuns:         len(export.PayrollRuns),
		InvestmentLots:      len(export.InvestmentLots),
	}
}
