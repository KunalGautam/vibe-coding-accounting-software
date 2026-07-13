package main

import (
	"log"

	"accounting.abhashtech.com/internal/auth"
	"accounting.abhashtech.com/internal/config"
	"accounting.abhashtech.com/internal/domain"
	apihttp "accounting.abhashtech.com/internal/http"
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

	router := apihttp.NewRouter(apihttp.RouterConfig{
		SwaggerEnabled:          cfg.SwaggerEnabled,
		DB:                      db,
		CORSAllowedOrigins:      cfg.CORSAllowedOrigins,
		AttachmentStorageDriver: cfg.AttachmentStorageDriver,
		AttachmentStoragePath:   cfg.AttachmentStoragePath,
		Tokens: auth.NewTokenManager(
			cfg.JWTAccessSecret,
			cfg.JWTRefreshSecret,
			cfg.AccessTokenTTL(),
			cfg.RefreshTokenTTL(),
		),
	})

	if err := router.Run(cfg.APIAddr); err != nil {
		log.Fatalf("run api: %v", err)
	}
}
