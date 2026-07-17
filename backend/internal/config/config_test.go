package config

import (
	"bytes"
	"strings"
	"testing"
)

const testMFAEncryptionKey = "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY="

func TestConfigValidateAllowsDevelopmentDefaults(t *testing.T) {
	cfg := Load()
	cfg.AppEnv = "development"
	if err := cfg.Validate(); err != nil {
		t.Fatalf("Validate() error = %v, want nil", err)
	}
}

func TestConfigValidateRejectsProductionDefaults(t *testing.T) {
	cfg := Config{
		AppEnv:                 "production",
		DatabaseDriver:         "sqlite",
		JWTAccessSecret:        defaultAccessSecret,
		JWTRefreshSecret:       defaultRefreshSecret,
		SwaggerEnabled:         true,
		CORSAllowedOrigins:     "*",
		AutoMigrate:            true,
		RateLimitEnabled:       true,
		RateLimitRequests:      0,
		RateLimitWindowSeconds: 0,
	}
	err := cfg.ValidateRuntime()
	if err == nil {
		t.Fatalf("Validate() error = nil, want production hardening errors")
	}
	for _, expected := range []string{
		"JWT_ACCESS_SECRET",
		"JWT_REFRESH_SECRET",
		"DATABASE_DRIVER=sqlite",
		"CORS_ALLOWED_ORIGINS",
		"SWAGGER_ENABLED",
		"AUTO_MIGRATE",
		"rate limit",
		"MFA_ENCRYPTION_KEY",
	} {
		if !strings.Contains(err.Error(), expected) {
			t.Fatalf("Validate() error %q missing %q", err.Error(), expected)
		}
	}
}

func TestConfigValidateAllowsHardenedProduction(t *testing.T) {
	cfg := Config{
		AppEnv:                 "production",
		DatabaseDriver:         "mysql",
		MySQLDSN:               "user:pass@tcp(mysql:3306)/accounting?parseTime=true",
		JWTAccessSecret:        "access-secret-with-enough-entropy",
		JWTRefreshSecret:       "refresh-secret-with-enough-entropy",
		MFAEncryptionKey:       testMFAEncryptionKey,
		SwaggerEnabled:         false,
		CORSAllowedOrigins:     "https://app.example.com",
		AutoMigrate:            false,
		RateLimitEnabled:       true,
		RateLimitRequests:      20,
		RateLimitWindowSeconds: 60,
		LogFormat:              "json",
		LogLevel:               "info",
	}
	if err := cfg.Validate(); err != nil {
		t.Fatalf("Validate() error = %v, want nil", err)
	}
}

func TestConfigValidateAllowsProductionMigrationWithAutoMigrate(t *testing.T) {
	cfg := Config{
		AppEnv:                 "production",
		DatabaseDriver:         "mysql",
		MySQLDSN:               "user:pass@tcp(mysql:3306)/accounting?parseTime=true",
		JWTAccessSecret:        "access-secret-with-enough-entropy",
		JWTRefreshSecret:       "refresh-secret-with-enough-entropy",
		MFAEncryptionKey:       testMFAEncryptionKey,
		SwaggerEnabled:         false,
		CORSAllowedOrigins:     "https://app.example.com",
		AutoMigrate:            true,
		RateLimitEnabled:       true,
		RateLimitRequests:      20,
		RateLimitWindowSeconds: 60,
		LogFormat:              "json",
		LogLevel:               "info",
	}
	if err := cfg.Validate(); err != nil {
		t.Fatalf("Validate() error = %v, want nil for migration command", err)
	}
	if err := cfg.ValidateRuntime(); err == nil || !strings.Contains(err.Error(), "AUTO_MIGRATE") {
		t.Fatalf("ValidateRuntime() error = %v, want AUTO_MIGRATE error", err)
	}
}

func TestConfigValidateMarketDataImportSettings(t *testing.T) {
	cfg := Config{
		AppEnv:                  "production",
		DatabaseDriver:          "mysql",
		MySQLDSN:                "user:pass@tcp(mysql:3306)/accounting?parseTime=true",
		JWTAccessSecret:         "access-secret-with-enough-entropy",
		JWTRefreshSecret:        "refresh-secret-with-enough-entropy",
		MFAEncryptionKey:        testMFAEncryptionKey,
		SwaggerEnabled:          false,
		CORSAllowedOrigins:      "https://app.example.com",
		AutoMigrate:             false,
		RateLimitEnabled:        true,
		RateLimitRequests:       20,
		RateLimitWindowSeconds:  60,
		LogFormat:               "json",
		LogLevel:                "info",
		MarketDataImportEnabled: true,
		MarketDataImportFormat:  "amfi",
	}
	err := cfg.ValidateRuntime()
	if err == nil || !strings.Contains(err.Error(), "MARKET_DATA_IMPORT_PATH or MARKET_DATA_IMPORT_URL") {
		t.Fatalf("ValidateRuntime() error = %v, want market data path/url error", err)
	}

	cfg.MarketDataImportURL = "https://prices.example.com/amfi.txt"
	cfg.MarketDataImportFormat = "json"
	err = cfg.ValidateRuntime()
	if err == nil || !strings.Contains(err.Error(), "MARKET_DATA_IMPORT_FORMAT") {
		t.Fatalf("ValidateRuntime() error = %v, want MARKET_DATA_IMPORT_FORMAT error", err)
	}

	cfg.MarketDataImportFormat = "csv"
	cfg.MarketDataTimeoutSeconds = 0
	err = cfg.ValidateRuntime()
	if err == nil || !strings.Contains(err.Error(), "MARKET_DATA_TIMEOUT_SECONDS") {
		t.Fatalf("ValidateRuntime() error = %v, want MARKET_DATA_TIMEOUT_SECONDS error", err)
	}

	cfg.MarketDataTimeoutSeconds = 30
	if err := cfg.ValidateRuntime(); err != nil {
		t.Fatalf("ValidateRuntime() error = %v, want nil", err)
	}

	cfg.MarketDataImportFormat = "nse_equity_csv"
	if err := cfg.ValidateRuntime(); err != nil {
		t.Fatalf("ValidateRuntime() error = %v, want nil for NSE equity CSV", err)
	}

	cfg.MarketDataImportFormat = "bse_equity_csv"
	if err := cfg.ValidateRuntime(); err != nil {
		t.Fatalf("ValidateRuntime() error = %v, want nil for BSE equity CSV", err)
	}

	cfg.MarketDataImportFormat = "yahoo_finance_csv"
	if err := cfg.ValidateRuntime(); err != nil {
		t.Fatalf("ValidateRuntime() error = %v, want nil for Yahoo Finance CSV", err)
	}

	cfg.MarketDataImportFormat = "alpha_vantage_csv"
	if err := cfg.ValidateRuntime(); err != nil {
		t.Fatalf("ValidateRuntime() error = %v, want nil for Alpha Vantage CSV", err)
	}

	cfg.MarketDataImportFormat = "broker_holdings_csv"
	if err := cfg.ValidateRuntime(); err != nil {
		t.Fatalf("ValidateRuntime() error = %v, want nil for broker holdings CSV", err)
	}

	cfg.MarketDataImportFormat = "zerodha_holdings_csv"
	if err := cfg.ValidateRuntime(); err != nil {
		t.Fatalf("ValidateRuntime() error = %v, want nil for Zerodha holdings CSV", err)
	}

	cfg.MarketDataImportFormat = "groww_holdings_csv"
	if err := cfg.ValidateRuntime(); err != nil {
		t.Fatalf("ValidateRuntime() error = %v, want nil for Groww holdings CSV", err)
	}

	cfg.MarketDataImportFormat = "upstox_holdings_csv"
	if err := cfg.ValidateRuntime(); err != nil {
		t.Fatalf("ValidateRuntime() error = %v, want nil for Upstox holdings CSV", err)
	}

	cfg.MarketDataImportFormat = "angelone_holdings_csv"
	if err := cfg.ValidateRuntime(); err != nil {
		t.Fatalf("ValidateRuntime() error = %v, want nil for Angel One holdings CSV", err)
	}

	cfg.MarketDataImportFormat = "dhan_holdings_csv"
	if err := cfg.ValidateRuntime(); err != nil {
		t.Fatalf("ValidateRuntime() error = %v, want nil for Dhan holdings CSV", err)
	}

	cfg.MarketDataImportFormat = "icicidirect_holdings_csv"
	if err := cfg.ValidateRuntime(); err != nil {
		t.Fatalf("ValidateRuntime() error = %v, want nil for ICICI Direct holdings CSV", err)
	}

	cfg.MarketDataImportFormat = "hdfcsky_holdings_csv"
	if err := cfg.ValidateRuntime(); err != nil {
		t.Fatalf("ValidateRuntime() error = %v, want nil for HDFC Sky holdings CSV", err)
	}

	cfg.MarketDataImportFormat = "kotakneo_holdings_csv"
	if err := cfg.ValidateRuntime(); err != nil {
		t.Fatalf("ValidateRuntime() error = %v, want nil for Kotak Neo holdings CSV", err)
	}

	cfg.MarketDataImportFormat = "paytmmoney_holdings_csv"
	if err := cfg.ValidateRuntime(); err != nil {
		t.Fatalf("ValidateRuntime() error = %v, want nil for Paytm Money holdings CSV", err)
	}

	cfg.MarketDataImportFormat = "motilaloswal_holdings_csv"
	if err := cfg.ValidateRuntime(); err != nil {
		t.Fatalf("ValidateRuntime() error = %v, want nil for Motilal Oswal holdings CSV", err)
	}

	cfg.MarketDataImportFormat = "sharekhan_holdings_csv"
	if err := cfg.ValidateRuntime(); err != nil {
		t.Fatalf("ValidateRuntime() error = %v, want nil for Sharekhan holdings CSV", err)
	}

	cfg.MarketDataImportFormat = "fivepaisa_holdings_csv"
	if err := cfg.ValidateRuntime(); err != nil {
		t.Fatalf("ValidateRuntime() error = %v, want nil for 5paisa holdings CSV", err)
	}
}

func TestConfigValidateEmailDeliverySettings(t *testing.T) {
	cfg := Config{
		AppEnv:                   "production",
		DatabaseDriver:           "mysql",
		MySQLDSN:                 "user:pass@tcp(mysql:3306)/accounting?parseTime=true",
		JWTAccessSecret:          "access-secret-with-enough-entropy",
		JWTRefreshSecret:         "refresh-secret-with-enough-entropy",
		MFAEncryptionKey:         testMFAEncryptionKey,
		SwaggerEnabled:           false,
		CORSAllowedOrigins:       "https://app.example.com",
		AutoMigrate:              false,
		RateLimitEnabled:         true,
		RateLimitRequests:        20,
		RateLimitWindowSeconds:   60,
		LogFormat:                "json",
		LogLevel:                 "info",
		EmailDeliveryEnabled:     true,
		SMTPPort:                 587,
		ExposePasswordResetToken: false,
	}
	err := cfg.ValidateRuntime()
	if err == nil || !strings.Contains(err.Error(), "SMTP_HOST") {
		t.Fatalf("ValidateRuntime() error = %v, want SMTP_HOST error", err)
	}

	cfg.SMTPHost = "smtp.example.com"
	cfg.SMTPFrom = "no-reply@example.com"
	cfg.PasswordResetBaseURL = "https://app.example.com/reset-password"
	if err := cfg.ValidateRuntime(); err != nil {
		t.Fatalf("ValidateRuntime() error = %v, want nil", err)
	}
}

func TestConfigLoggerWritesJSON(t *testing.T) {
	var buffer bytes.Buffer
	cfg := Config{LogFormat: "json", LogLevel: "debug"}
	logger, err := cfg.Logger(&buffer)
	if err != nil {
		t.Fatalf("Logger() error = %v", err)
	}
	logger.Debug("hello", "answer", 42)
	output := buffer.String()
	if !strings.Contains(output, `"msg":"hello"`) || !strings.Contains(output, `"answer":42`) {
		t.Fatalf("unexpected json log output: %s", output)
	}
}
