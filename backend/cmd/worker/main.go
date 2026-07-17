package main

import (
	"context"
	"log"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"accounting.abhashtech.com/internal/config"
	"accounting.abhashtech.com/internal/domain"
	"accounting.abhashtech.com/internal/services"
)

func main() {
	cfg := config.Load()
	if err := cfg.ValidateRuntime(); err != nil {
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
	if cfg.AutoMigrate {
		if err := db.AutoMigrate(domain.AllModels()...); err != nil {
			log.Fatalf("auto migrate database: %v", err)
		}
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	var emailSender services.EmailSender
	if cfg.EmailDeliveryEnabled {
		emailSender = services.SMTPEmailSender{
			Host:     cfg.SMTPHost,
			Port:     cfg.SMTPPort,
			Username: cfg.SMTPUsername,
			Password: cfg.SMTPPassword,
			From:     cfg.SMTPFrom,
		}
	}

	jobs := services.NewJobServiceWithEmail(db, emailSender)
	run := func() {
		result, err := jobs.GenerateDueRecurringInvoices(ctx, time.Now().UTC())
		if err != nil {
			logger.Error("generate_due_recurring_invoices_failed", slog.Any("error", err))
			return
		}
		logger.Info("recurring_invoices_job_complete",
			slog.Int("organizations", result.OrganizationsProcessed),
			slog.Int("generated", result.GeneratedCount),
		)

		scheduledReportResult, err := jobs.RunDueScheduledReports(ctx, time.Now().UTC())
		if err != nil {
			logger.Error("scheduled_reports_failed", slog.Any("error", err))
			return
		}
		logger.Info("scheduled_reports_complete",
			slog.Int("processed", scheduledReportResult.ReportsProcessed),
			slog.Int("completed", scheduledReportResult.CompletedCount),
			slog.Int("failed", scheduledReportResult.FailedCount),
		)

		backupResult, err := jobs.CreateScheduledBackups(ctx, cfg.BackupStoragePath, cfg.BackupMirrorPath, cfg.BackupRetentionCount)
		if err != nil {
			logger.Error("scheduled_backups_failed", slog.Any("error", err))
			return
		}
		logger.Info("scheduled_backups_complete",
			slog.Int("organizations", backupResult.OrganizationsProcessed),
			slog.Int("created", backupResult.CreatedCount),
		)

		if cfg.MarketDataImportEnabled {
			marketDataResult, err := jobs.ImportScheduledMarketData(ctx, services.MarketDataImportJobInput{
				Path:           cfg.MarketDataImportPath,
				URL:            cfg.MarketDataImportURL,
				BearerToken:    cfg.MarketDataBearerToken,
				TimeoutSeconds: cfg.MarketDataTimeoutSeconds,
				Format:         cfg.MarketDataImportFormat,
				SymbolMode:     cfg.MarketDataSymbolMode,
				Source:         cfg.MarketDataSource,
				Symbol:         cfg.MarketDataSymbol,
				OrganizationID: cfg.MarketDataOrganizationID,
			})
			if err != nil {
				logger.Error("scheduled_market_data_import_failed", slog.Any("error", err))
				return
			}
			logger.Info("scheduled_market_data_import_complete",
				slog.Int("organizations", marketDataResult.OrganizationsProcessed),
				slog.Int("imported", marketDataResult.ImportedCount),
				slog.Int("skipped", marketDataResult.SkippedCount),
				slog.Int("row_errors", len(marketDataResult.Errors)),
			)
		}
	}

	run()
	if cfg.WorkerRunOnce {
		return
	}

	interval := time.Duration(cfg.WorkerIntervalSeconds) * time.Second
	if interval <= 0 {
		interval = time.Hour
	}
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			logger.Info("worker_shutdown_requested")
			return
		case <-ticker.C:
			run()
		}
	}
}
