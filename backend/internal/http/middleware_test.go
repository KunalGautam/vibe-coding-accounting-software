package http

import (
	"bytes"
	"log/slog"
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

func TestSecurityHeadersMiddlewareAddsBrowserHardeningHeaders(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(SecurityHeadersMiddleware(0))
	router.GET("/ping", func(c *gin.Context) {
		c.Status(http.StatusNoContent)
	})

	request := httptest.NewRequest(http.MethodGet, "/ping", nil)
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)

	expectedHeaders := map[string]string{
		"X-Content-Type-Options":       "nosniff",
		"X-Frame-Options":              "DENY",
		"Referrer-Policy":              "no-referrer",
		"Permissions-Policy":           "camera=(), microphone=(), geolocation=()",
		"Cross-Origin-Resource-Policy": "same-origin",
	}
	for header, expected := range expectedHeaders {
		if response.Header().Get(header) != expected {
			t.Fatalf("%s = %q, want %q", header, response.Header().Get(header), expected)
		}
	}
	if response.Header().Get("Strict-Transport-Security") != "" {
		t.Fatalf("Strict-Transport-Security = %q, want empty when HSTS max age is zero", response.Header().Get("Strict-Transport-Security"))
	}
}

func TestSecurityHeadersMiddlewareAddsHSTSWhenConfigured(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(SecurityHeadersMiddleware(365 * 24 * time.Hour))
	router.GET("/ping", func(c *gin.Context) {
		c.Status(http.StatusNoContent)
	})

	request := httptest.NewRequest(http.MethodGet, "/ping", nil)
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)

	if response.Header().Get("Strict-Transport-Security") != "max-age=31536000; includeSubDomains" {
		t.Fatalf("Strict-Transport-Security = %q", response.Header().Get("Strict-Transport-Security"))
	}
}

func TestRateLimitMiddlewareLimitsByRouteAndClient(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(RateLimitMiddleware(2, time.Minute))
	router.GET("/limited", func(c *gin.Context) {
		c.Status(http.StatusNoContent)
	})

	for attempt := 1; attempt <= 2; attempt++ {
		request := httptest.NewRequest(http.MethodGet, "/limited", nil)
		request.RemoteAddr = "192.0.2.10:1234"
		response := httptest.NewRecorder()
		router.ServeHTTP(response, request)
		if response.Code != http.StatusNoContent {
			t.Fatalf("attempt %d status = %d, want %d", attempt, response.Code, http.StatusNoContent)
		}
	}

	request := httptest.NewRequest(http.MethodGet, "/limited", nil)
	request.RemoteAddr = "192.0.2.10:1234"
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)
	if response.Code != http.StatusTooManyRequests {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusTooManyRequests)
	}
	if response.Header().Get("Retry-After") == "" {
		t.Fatalf("expected Retry-After header")
	}
}

func TestStructuredLoggerMiddlewareWritesRequestFields(t *testing.T) {
	gin.SetMode(gin.TestMode)
	var buffer bytes.Buffer
	logger := slog.New(slog.NewJSONHandler(&buffer, nil))
	router := gin.New()
	router.Use(RequestIDMiddleware(), StructuredLoggerMiddleware(logger))
	router.GET("/logged", func(c *gin.Context) {
		c.String(http.StatusAccepted, "ok")
	})

	request := httptest.NewRequest(http.MethodGet, "/logged", nil)
	request.Header.Set("X-Request-ID", "req-log-1")
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)

	output := buffer.String()
	for _, expected := range []string{
		`"msg":"http_request"`,
		`"request_id":"req-log-1"`,
		`"method":"GET"`,
		`"path":"/logged"`,
		`"status":202`,
	} {
		if !strings.Contains(output, expected) {
			t.Fatalf("structured log %q missing %s", output, expected)
		}
	}
}

func TestMetricsEndpointExposesRequestCounters(t *testing.T) {
	gin.SetMode(gin.TestMode)
	metrics := NewHTTPMetrics()
	router := gin.New()
	router.Use(MetricsMiddleware(metrics))
	router.GET("/ping", func(c *gin.Context) {
		c.Status(http.StatusNoContent)
	})
	router.GET("/metrics", metrics.Handler())

	ping := httptest.NewRequest(http.MethodGet, "/ping", nil)
	pingResponse := httptest.NewRecorder()
	router.ServeHTTP(pingResponse, ping)

	request := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusOK)
	}
	body := response.Body.String()
	for _, expected := range []string{
		"accounting_process_uptime_seconds",
		`accounting_http_requests_total{method="GET",route="/ping",status="204"} 1`,
		`accounting_http_request_duration_seconds_count{method="GET",route="/ping",status="204"} 1`,
	} {
		if !strings.Contains(body, expected) {
			t.Fatalf("metrics body missing %q:\n%s", expected, body)
		}
	}
}

func TestMetricsEndpointCanBeDisabled(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := NewRouter(RouterConfig{
		DB:                 routerTestDB(t),
		CORSAllowedOrigins: "*",
		Tokens:             auth.NewTokenManager("access-secret", "refresh-secret", time.Minute, time.Hour),
		MetricsEnabled:     false,
	})

	request := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)

	if response.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusNotFound)
	}
}

func TestHealthAndReadinessEndpoints(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := NewRouter(RouterConfig{
		DB:                 routerTestDB(t),
		CORSAllowedOrigins: "*",
		Tokens:             auth.NewTokenManager("access-secret", "refresh-secret", time.Minute, time.Hour),
	})

	tests := []struct {
		path       string
		wantStatus int
		wantBody   string
	}{
		{path: "/health", wantStatus: http.StatusOK, wantBody: `"status":"ok"`},
		{path: "/healthz", wantStatus: http.StatusOK, wantBody: `"status":"ok"`},
		{path: "/livez", wantStatus: http.StatusOK, wantBody: `"status":"ok"`},
		{path: "/readyz", wantStatus: http.StatusOK, wantBody: `"database":"ok"`},
		{path: "/api/v1/health", wantStatus: http.StatusOK, wantBody: `"status":"ok"`},
		{path: "/api/v1/healthz", wantStatus: http.StatusOK, wantBody: `"status":"ok"`},
		{path: "/api/v1/livez", wantStatus: http.StatusOK, wantBody: `"status":"ok"`},
		{path: "/api/v1/readyz", wantStatus: http.StatusOK, wantBody: `"database":"ok"`},
	}

	for _, test := range tests {
		t.Run(test.path, func(t *testing.T) {
			request := httptest.NewRequest(http.MethodGet, test.path, nil)
			response := httptest.NewRecorder()
			router.ServeHTTP(response, request)
			if response.Code != test.wantStatus {
				t.Fatalf("status = %d, want %d; body=%s", response.Code, test.wantStatus, response.Body.String())
			}
			if !strings.Contains(response.Body.String(), test.wantBody) {
				t.Fatalf("body = %s, want %s", response.Body.String(), test.wantBody)
			}
		})
	}
}

func TestReadinessEndpointFailsWithoutDatabase(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := NewRouter(RouterConfig{
		DB:                 nil,
		CORSAllowedOrigins: "*",
		Tokens:             auth.NewTokenManager("access-secret", "refresh-secret", time.Minute, time.Hour),
	})

	request := httptest.NewRequest(http.MethodGet, "/readyz", nil)
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)

	if response.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, want %d; body=%s", response.Code, http.StatusServiceUnavailable, response.Body.String())
	}
	if !strings.Contains(response.Body.String(), `"database":"missing"`) {
		t.Fatalf("body = %s, want missing database marker", response.Body.String())
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
