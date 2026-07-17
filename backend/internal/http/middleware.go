package http

import (
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"accounting.abhashtech.com/internal/auth"
	"accounting.abhashtech.com/internal/domain"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

const accessClaimsKey = "access_claims"
const requestIDKey = "request_id"

type rateLimitBucket struct {
	windowStart time.Time
	count       int
}

func RequestIDMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		requestID := c.GetHeader("X-Request-ID")
		if requestID == "" {
			requestID = uuid.NewString()
		}
		c.Set(requestIDKey, requestID)
		c.Header("X-Request-ID", requestID)
		c.Next()
	}
}

func CORSMiddleware(allowedOrigins string) gin.HandlerFunc {
	if allowedOrigins == "" {
		allowedOrigins = "*"
	}

	return func(c *gin.Context) {
		origin := c.GetHeader("Origin")
		if allowedOrigins == "*" {
			c.Header("Access-Control-Allow-Origin", "*")
		} else if originAllowed(origin, allowedOrigins) {
			c.Header("Access-Control-Allow-Origin", origin)
			c.Header("Vary", "Origin")
		}
		c.Header("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Authorization,Content-Type,X-Request-ID")
		c.Header("Access-Control-Expose-Headers", "X-Request-ID")

		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}

func SecurityHeadersMiddleware(hstsMaxAge time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("X-Content-Type-Options", "nosniff")
		c.Header("X-Frame-Options", "DENY")
		c.Header("Referrer-Policy", "no-referrer")
		c.Header("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
		c.Header("Cross-Origin-Resource-Policy", "same-origin")
		if hstsMaxAge > 0 {
			c.Header("Strict-Transport-Security", "max-age="+strconv.Itoa(int(hstsMaxAge.Seconds()))+"; includeSubDomains")
		}
		c.Next()
	}
}

func StructuredLoggerMiddleware(logger *slog.Logger) gin.HandlerFunc {
	if logger == nil {
		logger = slog.Default()
	}
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()
		latency := time.Since(start)
		level := slog.LevelInfo
		if c.Writer.Status() >= http.StatusInternalServerError {
			level = slog.LevelError
		} else if c.Writer.Status() >= http.StatusBadRequest {
			level = slog.LevelWarn
		}
		logger.LogAttrs(c.Request.Context(), level, "http_request",
			slog.String("request_id", CurrentRequestID(c)),
			slog.String("method", c.Request.Method),
			slog.String("path", c.Request.URL.Path),
			slog.String("route", c.FullPath()),
			slog.Int("status", c.Writer.Status()),
			slog.Int("bytes", c.Writer.Size()),
			slog.Duration("latency", latency),
			slog.String("client_ip", c.ClientIP()),
			slog.String("user_agent", c.Request.UserAgent()),
		)
	}
}

func RateLimitMiddleware(maxRequests int, window time.Duration) gin.HandlerFunc {
	if maxRequests <= 0 || window <= 0 {
		return func(c *gin.Context) {
			c.Next()
		}
	}

	var mutex sync.Mutex
	buckets := map[string]rateLimitBucket{}

	return func(c *gin.Context) {
		now := time.Now()
		key := c.ClientIP() + " " + c.FullPath()
		if key == c.ClientIP()+" " {
			key = c.ClientIP() + " " + c.Request.URL.Path
		}

		mutex.Lock()
		bucket := buckets[key]
		if bucket.windowStart.IsZero() || now.Sub(bucket.windowStart) >= window {
			bucket = rateLimitBucket{windowStart: now}
		}
		bucket.count++
		buckets[key] = bucket
		limited := bucket.count > maxRequests
		retryAfter := int(window.Seconds() - now.Sub(bucket.windowStart).Seconds())
		if retryAfter < 1 {
			retryAfter = 1
		}
		mutex.Unlock()

		if limited {
			c.Header("Retry-After", strconv.Itoa(retryAfter))
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"error": gin.H{"code": "rate_limited", "message": "Too many requests; retry later"},
			})
			return
		}
		c.Next()
	}
}

func AuthMiddleware(tokens auth.TokenManager) gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		if header == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": gin.H{"code": "missing_authorization", "message": "Authorization header is required"},
			})
			return
		}

		rawToken, ok := strings.CutPrefix(header, "Bearer ")
		if !ok || rawToken == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": gin.H{"code": "invalid_authorization", "message": "Authorization header must use Bearer token format"},
			})
			return
		}

		claims, err := tokens.ParseAccessToken(rawToken)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": gin.H{"code": "invalid_token", "message": "Access token is invalid or expired"},
			})
			return
		}

		c.Set(accessClaimsKey, claims)
		c.Next()
	}
}

func RequireOrganizationRole(allowedRoles ...domain.Role) gin.HandlerFunc {
	allowed := make(map[domain.Role]struct{}, len(allowedRoles))
	for _, role := range allowedRoles {
		allowed[role] = struct{}{}
	}

	return func(c *gin.Context) {
		claims, ok := CurrentAccessClaims(c)
		if !ok {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": gin.H{"code": "missing_claims", "message": "Access token claims are required"},
			})
			return
		}

		organizationID := c.Param("organizationId")
		role, ok := claims.OrganizationRoles[organizationID]
		if !ok {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"error": gin.H{"code": "organization_access_denied", "message": "User is not a member of this organization"},
			})
			return
		}

		if _, ok := allowed[role]; !ok {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"error": gin.H{"code": "insufficient_role", "message": "User role is not permitted for this operation"},
			})
			return
		}

		c.Next()
	}
}

func CurrentAccessClaims(c *gin.Context) (auth.AccessClaims, bool) {
	value, ok := c.Get(accessClaimsKey)
	if !ok {
		return auth.AccessClaims{}, false
	}

	claims, ok := value.(auth.AccessClaims)
	return claims, ok
}

func CurrentRequestID(c *gin.Context) string {
	value, ok := c.Get(requestIDKey)
	if !ok {
		return ""
	}
	requestID, _ := value.(string)
	return requestID
}

func originAllowed(origin string, allowedOrigins string) bool {
	for _, allowed := range strings.Split(allowedOrigins, ",") {
		if strings.TrimSpace(allowed) == origin {
			return true
		}
	}
	return false
}
