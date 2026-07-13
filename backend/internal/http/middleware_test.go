package http

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/auth"
	"github.com/gin-gonic/gin"
)

func TestRequestIDMiddleware(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(RequestIDMiddleware())
	router.GET("/ping", func(c *gin.Context) {
		c.Status(http.StatusNoContent)
	})

	request := httptest.NewRequest(http.MethodGet, "/ping", nil)
	request.Header.Set("X-Request-ID", "req-123")
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)

	if response.Header().Get("X-Request-ID") != "req-123" {
		t.Fatalf("X-Request-ID = %q, want req-123", response.Header().Get("X-Request-ID"))
	}
}

func TestCORSMiddlewarePreflight(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(CORSMiddleware("https://example.com"))
	router.GET("/ping", func(c *gin.Context) {
		c.Status(http.StatusNoContent)
	})

	request := httptest.NewRequest(http.MethodOptions, "/ping", nil)
	request.Header.Set("Origin", "https://example.com")
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)

	if response.Code != http.StatusNoContent {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusNoContent)
	}
	if response.Header().Get("Access-Control-Allow-Origin") != "https://example.com" {
		t.Fatalf("allow origin = %q", response.Header().Get("Access-Control-Allow-Origin"))
	}
}

func TestSwaggerHTMLRoute(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := NewRouter(RouterConfig{
		DB:                 routerTestDB(t),
		SwaggerEnabled:     true,
		CORSAllowedOrigins: "*",
		Tokens:             auth.NewTokenManager("access-secret", "refresh-secret", time.Minute, time.Hour),
	})

	request := httptest.NewRequest(http.MethodGet, "/swagger/index.html", nil)
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusOK)
	}
	body := response.Body.String()
	for _, expected := range []string{
		"AbhashTech Accounting API Docs",
		"url: \"/openapi.yaml\"",
		"deepLinking: true",
		"persistAuthorization: true",
		"Swagger UI assets failed to load",
	} {
		if !strings.Contains(body, expected) {
			t.Fatalf("swagger html missing %q", expected)
		}
	}
}

func TestSwaggerConvenienceRouteRedirects(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := NewRouter(RouterConfig{
		DB:                 routerTestDB(t),
		SwaggerEnabled:     true,
		CORSAllowedOrigins: "*",
		Tokens:             auth.NewTokenManager("access-secret", "refresh-secret", time.Minute, time.Hour),
	})

	request := httptest.NewRequest(http.MethodGet, "/swagger", nil)
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)

	if response.Code != http.StatusMovedPermanently {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusMovedPermanently)
	}
	if response.Header().Get("Location") != "/swagger/index.html" {
		t.Fatalf("location = %q, want /swagger/index.html", response.Header().Get("Location"))
	}
}
