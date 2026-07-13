package config

import (
	"fmt"

	"gorm.io/driver/mysql"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func OpenDatabase(cfg Config) (*gorm.DB, error) {
	switch cfg.DatabaseDriver {
	case "sqlite":
		return gorm.Open(sqlite.Open(cfg.DatabaseDSN), &gorm.Config{})
	case "mysql":
		if cfg.MySQLDSN == "" {
			return nil, fmt.Errorf("MYSQL_DSN is required when DATABASE_DRIVER=mysql")
		}
		return gorm.Open(mysql.Open(cfg.MySQLDSN), &gorm.Config{})
	default:
		return nil, fmt.Errorf("unsupported database driver %q", cfg.DatabaseDriver)
	}
}
