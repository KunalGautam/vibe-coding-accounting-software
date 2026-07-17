package config

import (
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"os"
	"strconv"
	"strings"
	"time"
)

const (
	defaultAccessSecret  = "dev-access-secret-change-me"
	defaultRefreshSecret = "dev-refresh-secret-change-me"
)

type Config struct {
	AppEnv                         string
	APIAddr                        string
	DatabaseDriver                 string
	DatabaseDSN                    string
	MySQLDSN                       string
	JWTAccessSecret                string
	JWTRefreshSecret               string
	MFAEncryptionKey               string
	EmailDeliveryEnabled           bool
	SMTPHost                       string
	SMTPPort                       int
	SMTPUsername                   string
	SMTPPassword                   string
	SMTPFrom                       string
	PasswordResetBaseURL           string
	InvitationBaseURL              string
	ExposePasswordResetToken       bool
	SelfServiceRegistrationEnabled bool
	SwaggerEnabled                 bool
	DefaultCountry                 string
	DefaultCurrency                string
	CORSAllowedOrigins             string
	AccessTokenTTLMinutes          int
	RefreshTokenTTLHours           int
	AttachmentStoragePath          string
	AttachmentStorageDriver        string
	BackupStoragePath              string
	BackupRetentionCount           int
	WorkerRunOnce                  bool
	WorkerIntervalSeconds          int
	MarketDataImportEnabled        bool
	MarketDataImportPath           string
	MarketDataImportURL            string
	MarketDataBearerToken          string
	MarketDataTimeoutSeconds       int
	MarketDataImportFormat         string
	MarketDataSymbolMode           string
	MarketDataSource               string
	MarketDataSymbol               string
	MarketDataOrganizationID       string
	AutoMigrate                    bool
	RateLimitEnabled               bool
	RateLimitRequests              int
	RateLimitWindowSeconds         int
	LogFormat                      string
	LogLevel                       string
	MetricsEnabled                 bool
}

func Load() Config {
	return Config{
		AppEnv:                         env("APP_ENV", "development"),
		APIAddr:                        env("API_ADDR", ":8080"),
		DatabaseDriver:                 env("DATABASE_DRIVER", "sqlite"),
		DatabaseDSN:                    env("DATABASE_DSN", "file:accounting.db?cache=shared"),
		MySQLDSN:                       env("MYSQL_DSN", ""),
		JWTAccessSecret:                env("JWT_ACCESS_SECRET", defaultAccessSecret),
		JWTRefreshSecret:               env("JWT_REFRESH_SECRET", defaultRefreshSecret),
		MFAEncryptionKey:               env("MFA_ENCRYPTION_KEY", ""),
		EmailDeliveryEnabled:           envBool("EMAIL_DELIVERY_ENABLED", false),
		SMTPHost:                       env("SMTP_HOST", ""),
		SMTPPort:                       envInt("SMTP_PORT", 587),
		SMTPUsername:                   env("SMTP_USERNAME", ""),
		SMTPPassword:                   env("SMTP_PASSWORD", ""),
		SMTPFrom:                       env("SMTP_FROM", ""),
		PasswordResetBaseURL:           env("PASSWORD_RESET_BASE_URL", ""),
		InvitationBaseURL:              env("INVITATION_BASE_URL", ""),
		ExposePasswordResetToken:       envBool("EXPOSE_PASSWORD_RESET_TOKEN", false),
		SelfServiceRegistrationEnabled: envBool("SELF_SERVICE_REGISTRATION_ENABLED", false),
		SwaggerEnabled:                 envBool("SWAGGER_ENABLED", true),
		DefaultCountry:                 env("DEFAULT_COUNTRY", "IN"),
		DefaultCurrency:                env("DEFAULT_CURRENCY", "INR"),
		CORSAllowedOrigins:             env("CORS_ALLOWED_ORIGINS", "*"),
		AccessTokenTTLMinutes:          envInt("ACCESS_TOKEN_TTL_MINUTES", 15),
		RefreshTokenTTLHours:           envInt("REFRESH_TOKEN_TTL_HOURS", 720),
		AttachmentStorageDriver:        env("ATTACHMENT_STORAGE_DRIVER", "local"),
		AttachmentStoragePath:          env("ATTACHMENT_STORAGE_PATH", "./storage"),
		BackupStoragePath:              env("BACKUP_STORAGE_PATH", "./storage/backups"),
		BackupRetentionCount:           envInt("BACKUP_RETENTION_COUNT", 7),
		WorkerRunOnce:                  envBool("WORKER_RUN_ONCE", false),
		WorkerIntervalSeconds:          envInt("WORKER_INTERVAL_SECONDS", 3600),
		MarketDataImportEnabled:        envBool("MARKET_DATA_IMPORT_ENABLED", false),
		MarketDataImportPath:           env("MARKET_DATA_IMPORT_PATH", ""),
		MarketDataImportURL:            env("MARKET_DATA_IMPORT_URL", ""),
		MarketDataBearerToken:          env("MARKET_DATA_BEARER_TOKEN", ""),
		MarketDataTimeoutSeconds:       envInt("MARKET_DATA_TIMEOUT_SECONDS", 30),
		MarketDataImportFormat:         env("MARKET_DATA_IMPORT_FORMAT", "amfi"),
		MarketDataSymbolMode:           env("MARKET_DATA_SYMBOL_MODE", "scheme_code"),
		MarketDataSource:               env("MARKET_DATA_SOURCE", "scheduled_market_data"),
		MarketDataSymbol:               env("MARKET_DATA_SYMBOL", ""),
		MarketDataOrganizationID:       env("MARKET_DATA_ORGANIZATION_ID", ""),
		AutoMigrate:                    envBool("AUTO_MIGRATE", true),
		RateLimitEnabled:               envBool("RATE_LIMIT_ENABLED", true),
		RateLimitRequests:              envInt("RATE_LIMIT_REQUESTS", 20),
		RateLimitWindowSeconds:         envInt("RATE_LIMIT_WINDOW_SECONDS", 60),
		LogFormat:                      env("LOG_FORMAT", "text"),
		LogLevel:                       env("LOG_LEVEL", "info"),
		MetricsEnabled:                 envBool("METRICS_ENABLED", true),
	}
}

func (c Config) AccessTokenTTL() time.Duration {
	return time.Duration(c.AccessTokenTTLMinutes) * time.Minute
}

func (c Config) RefreshTokenTTL() time.Duration {
	return time.Duration(c.RefreshTokenTTLHours) * time.Hour
}

func (c Config) Validate() error {
	return c.validate(false)
}

func (c Config) ValidateRuntime() error {
	return c.validate(true)
}

func (c Config) validate(runtime bool) error {
	if !strings.EqualFold(c.AppEnv, "production") {
		return nil
	}

	var problems []error
	if c.JWTAccessSecret == "" || c.JWTAccessSecret == defaultAccessSecret {
		problems = append(problems, errors.New("JWT_ACCESS_SECRET must be set to a non-default value"))
	}
	if c.JWTRefreshSecret == "" || c.JWTRefreshSecret == defaultRefreshSecret {
		problems = append(problems, errors.New("JWT_REFRESH_SECRET must be set to a non-default value"))
	}
	if c.JWTAccessSecret != "" && c.JWTAccessSecret == c.JWTRefreshSecret {
		problems = append(problems, errors.New("JWT_ACCESS_SECRET and JWT_REFRESH_SECRET must be different"))
	}
	if strings.TrimSpace(c.MFAEncryptionKey) == "" {
		problems = append(problems, errors.New("MFA_ENCRYPTION_KEY must be set in production"))
	} else if _, err := parseMFAEncryptionKey(c.MFAEncryptionKey); err != nil {
		problems = append(problems, err)
	}
	if c.DatabaseDriver == "sqlite" {
		problems = append(problems, errors.New("DATABASE_DRIVER=sqlite is not allowed in production"))
	}
	if c.DatabaseDriver == "mysql" && c.MySQLDSN == "" {
		problems = append(problems, errors.New("MYSQL_DSN is required in production"))
	}
	if c.CORSAllowedOrigins == "*" || strings.TrimSpace(c.CORSAllowedOrigins) == "" {
		problems = append(problems, errors.New("CORS_ALLOWED_ORIGINS must list explicit origins in production"))
	}
	if c.SwaggerEnabled {
		problems = append(problems, errors.New("SWAGGER_ENABLED must be false in production unless docs are separately auth-gated"))
	}
	if runtime && c.AutoMigrate {
		problems = append(problems, errors.New("AUTO_MIGRATE must be false in production; run cmd/migrate explicitly"))
	}
	if c.RateLimitEnabled && (c.RateLimitRequests <= 0 || c.RateLimitWindowSeconds <= 0) {
		problems = append(problems, errors.New("rate limit settings must be positive when RATE_LIMIT_ENABLED=true"))
	}
	if c.MarketDataImportEnabled {
		if strings.TrimSpace(c.MarketDataImportPath) == "" && strings.TrimSpace(c.MarketDataImportURL) == "" {
			problems = append(problems, errors.New("MARKET_DATA_IMPORT_PATH or MARKET_DATA_IMPORT_URL is required when MARKET_DATA_IMPORT_ENABLED=true"))
		}
		if !isSupportedMarketDataFormat(c.MarketDataImportFormat) {
			problems = append(problems, errors.New("MARKET_DATA_IMPORT_FORMAT must be amfi, csv, nse_equity_csv, bse_equity_csv, yahoo_finance_csv, alpha_vantage_csv, broker_holdings_csv, zerodha_holdings_csv, groww_holdings_csv, upstox_holdings_csv, angelone_holdings_csv, dhan_holdings_csv, icicidirect_holdings_csv, hdfcsky_holdings_csv, kotakneo_holdings_csv, paytmmoney_holdings_csv, motilaloswal_holdings_csv, sharekhan_holdings_csv, fivepaisa_holdings_csv, axisdirect_holdings_csv, sbisecurities_holdings_csv, nuvama_holdings_csv, geojit_holdings_csv, iiflsecurities_holdings_csv, fyers_holdings_csv, or edelweiss_holdings_csv"))
		}
		if c.MarketDataTimeoutSeconds <= 0 {
			problems = append(problems, errors.New("MARKET_DATA_TIMEOUT_SECONDS must be positive"))
		}
	}
	if c.EmailDeliveryEnabled {
		if strings.TrimSpace(c.SMTPHost) == "" {
			problems = append(problems, errors.New("SMTP_HOST is required when EMAIL_DELIVERY_ENABLED=true"))
		}
		if c.SMTPPort <= 0 {
			problems = append(problems, errors.New("SMTP_PORT must be positive when EMAIL_DELIVERY_ENABLED=true"))
		}
		if strings.TrimSpace(c.SMTPFrom) == "" {
			problems = append(problems, errors.New("SMTP_FROM is required when EMAIL_DELIVERY_ENABLED=true"))
		}
		if strings.TrimSpace(c.PasswordResetBaseURL) == "" {
			problems = append(problems, errors.New("PASSWORD_RESET_BASE_URL is required when EMAIL_DELIVERY_ENABLED=true"))
		}
	}
	if _, err := parseLogLevel(c.LogLevel); err != nil {
		problems = append(problems, err)
	}
	if c.LogFormat != "text" && c.LogFormat != "json" {
		problems = append(problems, errors.New("LOG_FORMAT must be text or json"))
	}
	if len(problems) > 0 {
		return fmt.Errorf("invalid production configuration: %w", errors.Join(problems...))
	}
	return nil
}

func isSupportedMarketDataFormat(format string) bool {
	switch format {
	case "amfi", "csv", "nse_equity_csv", "bse_equity_csv", "yahoo_finance_csv", "alpha_vantage_csv", "broker_holdings_csv", "zerodha_holdings_csv", "groww_holdings_csv", "upstox_holdings_csv", "angelone_holdings_csv", "dhan_holdings_csv", "icicidirect_holdings_csv", "hdfcsky_holdings_csv", "kotakneo_holdings_csv", "paytmmoney_holdings_csv", "motilaloswal_holdings_csv", "sharekhan_holdings_csv", "fivepaisa_holdings_csv", "axisdirect_holdings_csv", "sbisecurities_holdings_csv", "nuvama_holdings_csv", "geojit_holdings_csv", "iiflsecurities_holdings_csv", "fyers_holdings_csv", "edelweiss_holdings_csv":
		return true
	default:
		return false
	}
}

func parseMFAEncryptionKey(rawKey string) ([]byte, error) {
	key, err := decodeBase64Key(rawKey)
	if err != nil {
		return nil, errors.New("MFA_ENCRYPTION_KEY must be base64 encoded")
	}
	if len(key) != 32 {
		return nil, errors.New("MFA_ENCRYPTION_KEY must decode to 32 bytes")
	}
	return key, nil
}

func decodeBase64Key(rawKey string) ([]byte, error) {
	rawKey = strings.TrimSpace(rawKey)
	for _, decoder := range []func(string) ([]byte, error){
		base64.StdEncoding.DecodeString,
		base64.RawStdEncoding.DecodeString,
		base64.RawURLEncoding.DecodeString,
	} {
		key, err := decoder(rawKey)
		if err == nil {
			return key, nil
		}
	}
	return nil, errors.New("invalid base64 key")
}

func (c Config) Logger(output io.Writer) (*slog.Logger, error) {
	level, err := parseLogLevel(c.LogLevel)
	if err != nil {
		return nil, err
	}
	options := &slog.HandlerOptions{Level: level}
	if c.LogFormat == "json" {
		return slog.New(slog.NewJSONHandler(output, options)), nil
	}
	if c.LogFormat == "" || c.LogFormat == "text" {
		return slog.New(slog.NewTextHandler(output, options)), nil
	}
	return nil, errors.New("LOG_FORMAT must be text or json")
}

func parseLogLevel(value string) (slog.Level, error) {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "", "info":
		return slog.LevelInfo, nil
	case "debug":
		return slog.LevelDebug, nil
	case "warn", "warning":
		return slog.LevelWarn, nil
	case "error":
		return slog.LevelError, nil
	default:
		return slog.LevelInfo, fmt.Errorf("LOG_LEVEL must be debug, info, warn, or error")
	}
}

func env(key string, fallback string) string {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	return value
}

func envBool(key string, fallback bool) bool {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}

	parsed, err := strconv.ParseBool(value)
	if err != nil {
		return fallback
	}
	return parsed
}

func envInt(key string, fallback int) int {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}

	parsed, err := strconv.Atoi(value)
	if err != nil {
		return fallback
	}
	return parsed
}
