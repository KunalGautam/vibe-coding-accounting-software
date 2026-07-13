package config

import (
	"os"
	"strconv"
	"time"
)

type Config struct {
	AppEnv                  string
	APIAddr                 string
	DatabaseDriver          string
	DatabaseDSN             string
	MySQLDSN                string
	JWTAccessSecret         string
	JWTRefreshSecret        string
	SwaggerEnabled          bool
	DefaultCountry          string
	DefaultCurrency         string
	CORSAllowedOrigins      string
	AccessTokenTTLMinutes   int
	RefreshTokenTTLHours    int
	AttachmentStoragePath   string
	AttachmentStorageDriver string
	BackupStoragePath       string
	BackupRetentionCount    int
	WorkerRunOnce           bool
	WorkerIntervalSeconds   int
}

func Load() Config {
	return Config{
		AppEnv:                  env("APP_ENV", "development"),
		APIAddr:                 env("API_ADDR", ":8080"),
		DatabaseDriver:          env("DATABASE_DRIVER", "sqlite"),
		DatabaseDSN:             env("DATABASE_DSN", "file:accounting.db?cache=shared"),
		MySQLDSN:                env("MYSQL_DSN", ""),
		JWTAccessSecret:         env("JWT_ACCESS_SECRET", "dev-access-secret-change-me"),
		JWTRefreshSecret:        env("JWT_REFRESH_SECRET", "dev-refresh-secret-change-me"),
		SwaggerEnabled:          envBool("SWAGGER_ENABLED", true),
		DefaultCountry:          env("DEFAULT_COUNTRY", "IN"),
		DefaultCurrency:         env("DEFAULT_CURRENCY", "INR"),
		CORSAllowedOrigins:      env("CORS_ALLOWED_ORIGINS", "*"),
		AccessTokenTTLMinutes:   envInt("ACCESS_TOKEN_TTL_MINUTES", 15),
		RefreshTokenTTLHours:    envInt("REFRESH_TOKEN_TTL_HOURS", 720),
		AttachmentStorageDriver: env("ATTACHMENT_STORAGE_DRIVER", "local"),
		AttachmentStoragePath:   env("ATTACHMENT_STORAGE_PATH", "./storage"),
		BackupStoragePath:       env("BACKUP_STORAGE_PATH", "./storage/backups"),
		BackupRetentionCount:    envInt("BACKUP_RETENTION_COUNT", 7),
		WorkerRunOnce:           envBool("WORKER_RUN_ONCE", false),
		WorkerIntervalSeconds:   envInt("WORKER_INTERVAL_SECONDS", 3600),
	}
}

func (c Config) AccessTokenTTL() time.Duration {
	return time.Duration(c.AccessTokenTTLMinutes) * time.Minute
}

func (c Config) RefreshTokenTTL() time.Duration {
	return time.Duration(c.RefreshTokenTTLHours) * time.Hour
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
