package main

import (
	"flag"
	"log"
	"log/slog"
	"os"

	"accounting.abhashtech.com/internal/config"
	"accounting.abhashtech.com/internal/domain"
)

func main() {
	direction := flag.String("direction", "up", "migration direction; only up is currently supported")
	flag.Parse()

	if *direction != "up" {
		log.Fatalf("unsupported migration direction %q; only up is currently supported", *direction)
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
	logger.Info("database_migration_complete", slog.String("direction", *direction))
}
