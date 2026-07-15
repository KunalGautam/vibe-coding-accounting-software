package main

import (
	"log"
	"log/slog"
	"os"
	"time"

	"accounting.abhashtech.com/internal/auth"
	"accounting.abhashtech.com/internal/config"
	"accounting.abhashtech.com/internal/domain"
	apihttp "accounting.abhashtech.com/internal/http"
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

	router := apihttp.NewRouter(apihttp.RouterConfig{
		SwaggerEnabled:                 cfg.SwaggerEnabled,
		DB:                             db,
		MFAEncryptionKey:               cfg.MFAEncryptionKey,
		EmailSender:                    emailSender,
		PasswordResetBaseURL:           cfg.PasswordResetBaseURL,
		InvitationBaseURL:              cfg.InvitationBaseURL,
		ExposePasswordResetToken:       cfg.ExposePasswordResetToken,
		SelfServiceRegistrationEnabled: cfg.SelfServiceRegistrationEnabled,
		CORSAllowedOrigins:             cfg.CORSAllowedOrigins,
		AttachmentStorageDriver:        cfg.AttachmentStorageDriver,
		AttachmentStoragePath:          cfg.AttachmentStoragePath,
		RateLimitEnabled:               cfg.RateLimitEnabled,
		RateLimitRequests:              cfg.RateLimitRequests,
		RateLimitWindow:                time.Duration(cfg.RateLimitWindowSeconds) * time.Second,
		Logger:                         logger,
		MetricsEnabled:                 cfg.MetricsEnabled,
		Tokens: auth.NewTokenManager(
			cfg.JWTAccessSecret,
			cfg.JWTRefreshSecret,
			cfg.AccessTokenTTL(),
			cfg.RefreshTokenTTL(),
		),
	})

	if err := router.Run(cfg.APIAddr); err != nil {
		logger.Error("run api failed", slog.Any("error", err))
		os.Exit(1)
	}
}
