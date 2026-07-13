package main

import (
	"context"
	"log"
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

	db, err := config.OpenDatabase(cfg)
	if err != nil {
		log.Fatalf("open database: %v", err)
	}
	if err := db.AutoMigrate(domain.AllModels()...); err != nil {
		log.Fatalf("auto migrate database: %v", err)
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	jobs := services.NewJobService(db)
	run := func() {
		result, err := jobs.GenerateDueRecurringInvoices(ctx, time.Now().UTC())
		if err != nil {
			log.Printf("generate due recurring invoices failed: %v", err)
			return
		}
		log.Printf("recurring invoices job complete: organizations=%d generated=%d", result.OrganizationsProcessed, result.GeneratedCount)

		backupResult, err := jobs.CreateScheduledBackups(ctx, cfg.BackupStoragePath, cfg.BackupRetentionCount)
		if err != nil {
			log.Printf("scheduled backups failed: %v", err)
			return
		}
		log.Printf("scheduled backups complete: organizations=%d created=%d", backupResult.OrganizationsProcessed, backupResult.CreatedCount)
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
			log.Print("worker shutdown requested")
			return
		case <-ticker.C:
			run()
		}
	}
}
