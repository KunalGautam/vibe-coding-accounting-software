package main

import (
	"context"
	"encoding/json"
	"flag"
	"log"
	"log/slog"
	"os"

	"accounting.abhashtech.com/internal/config"
	"accounting.abhashtech.com/internal/domain"
	"accounting.abhashtech.com/internal/services"
)

func main() {
	filePath := flag.String("file", "", "path to organization export or backup JSON")
	flag.Parse()
	if *filePath == "" {
		log.Fatal("restore requires -file")
	}

	payload, err := os.ReadFile(*filePath)
	if err != nil {
		log.Fatalf("read restore file: %v", err)
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
