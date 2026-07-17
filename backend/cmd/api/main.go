package main

import (
	"context"
	"database/sql"
	"log"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
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
		AttachmentMaxUploadBytes:       cfg.AttachmentMaxUploadBytes,
		RateLimitEnabled:               cfg.RateLimitEnabled,
		RateLimitRequests:              cfg.RateLimitRequests,
		RateLimitWindow:                time.Duration(cfg.RateLimitWindowSeconds) * time.Second,
		SecurityHeadersEnabled:         cfg.SecurityHeadersEnabled,
		SecurityHSTSMaxAge:             time.Duration(cfg.SecurityHSTSMaxAgeSeconds) * time.Second,
		Logger:                         logger,
		MetricsEnabled:                 cfg.MetricsEnabled,
		Tokens: auth.NewTokenManager(
			cfg.JWTAccessSecret,
			cfg.JWTRefreshSecret,
			cfg.AccessTokenTTL(),
			cfg.RefreshTokenTTL(),
		),
	})

	server := &http.Server{
		Addr:         cfg.APIAddr,
		Handler:      router,
		ReadTimeout:  time.Duration(cfg.APIReadTimeoutSeconds) * time.Second,
		WriteTimeout: time.Duration(cfg.APIWriteTimeoutSeconds) * time.Second,
		IdleTimeout:  time.Duration(cfg.APIIdleTimeoutSeconds) * time.Second,
	}

	serverErrors := make(chan error, 1)
	go func() {
		logger.Info("api_server_starting", slog.String("addr", cfg.APIAddr))
		serverErrors <- server.ListenAndServe()
	}()

	shutdownSignals := make(chan os.Signal, 1)
	signal.Notify(shutdownSignals, os.Interrupt, syscall.SIGTERM)
	defer signal.Stop(shutdownSignals)

	select {
	case err := <-serverErrors:
		if err != nil && err != http.ErrServerClosed {
			logger.Error("run api failed", slog.Any("error", err))
			os.Exit(1)
		}
	case signal := <-shutdownSignals:
		logger.Info("api_shutdown_requested", slog.String("signal", signal.String()))
		shutdownCtx, cancel := context.WithTimeout(context.Background(), time.Duration(cfg.APIShutdownTimeoutSeconds)*time.Second)
		defer cancel()
		if err := server.Shutdown(shutdownCtx); err != nil {
			logger.Error("api_shutdown_failed", slog.Any("error", err))
			os.Exit(1)
		}
		logger.Info("api_shutdown_complete")
	}
	if err := dbConnClose(db); err != nil {
		logger.Warn("database_close_failed", slog.Any("error", err))
	}
}

func dbConnClose(db interface{ DB() (*sql.DB, error) }) error {
	sqlDB, err := db.DB()
	if err != nil {
		return err
	}
	return sqlDB.Close()
}
