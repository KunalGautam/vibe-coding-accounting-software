package http

import (
	"net/http"
	"strings"

	"accounting.abhashtech.com/internal/auth"
	"accounting.abhashtech.com/internal/domain"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

const accessClaimsKey = "access_claims"
const requestIDKey = "request_id"

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
