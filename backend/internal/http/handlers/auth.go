package handlers

import (
	"errors"
	"net/http"

	"accounting.abhashtech.com/internal/auth"
	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type AuthHandler struct {
	auth services.AuthService
}

type loginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
	MFACode  string `json:"mfa_code"`
}

type refreshTokenRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

type revokeRefreshTokenRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

type requestPasswordResetRequest struct {
	Email string `json:"email" binding:"required,email"`
}

type confirmPasswordResetRequest struct {
	ResetToken  string `json:"reset_token" binding:"required"`
	NewPassword string `json:"new_password" binding:"required,min=12"`
}

type updateCurrentUserRequest struct {
	Name string `json:"name" binding:"required"`
}

type changePasswordRequest struct {
	CurrentPassword string `json:"current_password" binding:"required"`
	NewPassword     string `json:"new_password" binding:"required,min=12"`
}

type mfaCodeRequest struct {
	Code string `json:"code" binding:"required"`
}

func NewAuthHandler(auth services.AuthService) AuthHandler {
	return AuthHandler{auth: auth}
}

func (h AuthHandler) RegisterRoutes(router gin.IRoutes) {
	router.POST("/auth/login", h.Login)
	router.POST("/auth/refresh", h.Refresh)
	router.POST("/auth/logout", h.Logout)
	router.POST("/auth/password-reset/request", h.RequestPasswordReset)
	router.POST("/auth/password-reset/confirm", h.ConfirmPasswordReset)
}

func (h AuthHandler) RegisterProtectedRoutes(router gin.IRoutes) {
	router.GET("/auth/me", h.CurrentUser)
	router.PATCH("/auth/me", h.UpdateCurrentUser)
	router.POST("/auth/password/change", h.ChangePassword)
	router.POST("/auth/sessions/revoke-all", h.RevokeAllSessions)
	router.POST("/auth/mfa/setup", h.SetupMFA)
	router.POST("/auth/mfa/enable", h.EnableMFA)
	router.POST("/auth/mfa/disable", h.DisableMFA)
	router.POST("/auth/mfa/recovery-codes/regenerate", h.RegenerateMFARecoveryCodes)
}

func (h AuthHandler) Login(c *gin.Context) {
	var request loginRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	result, err := h.auth.Login(c.Request.Context(), request.Email, request.Password, request.MFACode)
	if err != nil {
		status, code := authErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}

	c.JSON(http.StatusOK, authResponse(result))
}

func (h AuthHandler) Refresh(c *gin.Context) {
	var request refreshTokenRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	result, err := h.auth.Refresh(c.Request.Context(), request.RefreshToken)
	if err != nil {
		status, code := authErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}

	c.JSON(http.StatusOK, authResponse(result))
}

func (h AuthHandler) Logout(c *gin.Context) {
	var request revokeRefreshTokenRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	if err := h.auth.RevokeRefreshToken(c.Request.Context(), request.RefreshToken); err != nil {
		status, code := authErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusOK, gin.H{"revoked": true})
}

func (h AuthHandler) CurrentUser(c *gin.Context) {
	claims, ok := currentAccessClaims(c)
	if !ok {
		respondError(c, http.StatusUnauthorized, "missing_claims", "Access token claims are required")
		return
	}
	profile, err := h.auth.CurrentUser(c.Request.Context(), claims.UserID)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "current_user_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, profile)
}

func (h AuthHandler) UpdateCurrentUser(c *gin.Context) {
	claims, ok := currentAccessClaims(c)
	if !ok {
		respondError(c, http.StatusUnauthorized, "missing_claims", "Access token claims are required")
		return
	}
	var request updateCurrentUserRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	profile, err := h.auth.UpdateCurrentUser(c.Request.Context(), claims.UserID, request.Name)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "current_user_update_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, profile)
}

func (h AuthHandler) ChangePassword(c *gin.Context) {
	claims, ok := currentAccessClaims(c)
	if !ok {
		respondError(c, http.StatusUnauthorized, "missing_claims", "Access token claims are required")
		return
	}
	var request changePasswordRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	if err := h.auth.ChangePassword(c.Request.Context(), claims.UserID, request.CurrentPassword, request.NewPassword); err != nil {
		status, code := authErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusOK, gin.H{"changed": true, "sessions_revoked": true})
}

func (h AuthHandler) RevokeAllSessions(c *gin.Context) {
	claims, ok := currentAccessClaims(c)
	if !ok {
		respondError(c, http.StatusUnauthorized, "missing_claims", "Access token claims are required")
		return
	}
	count, err := h.auth.RevokeUserSessions(c.Request.Context(), claims.UserID)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "session_revocation_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, gin.H{"revoked": true, "revoked_count": count})
}

func (h AuthHandler) SetupMFA(c *gin.Context) {
	claims, ok := currentAccessClaims(c)
	if !ok {
		respondError(c, http.StatusUnauthorized, "missing_claims", "Access token claims are required")
		return
	}
	result, err := h.auth.SetupMFA(c.Request.Context(), claims.UserID)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "mfa_setup_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, result)
}

func (h AuthHandler) EnableMFA(c *gin.Context) {
	claims, ok := currentAccessClaims(c)
	if !ok {
		respondError(c, http.StatusUnauthorized, "missing_claims", "Access token claims are required")
		return
	}
	var request mfaCodeRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	result, err := h.auth.EnableMFA(c.Request.Context(), claims.UserID, request.Code)
	if err != nil {
		status, code := authErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusOK, result)
}

func (h AuthHandler) DisableMFA(c *gin.Context) {
	claims, ok := currentAccessClaims(c)
	if !ok {
		respondError(c, http.StatusUnauthorized, "missing_claims", "Access token claims are required")
		return
	}
	var request mfaCodeRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	if err := h.auth.DisableMFA(c.Request.Context(), claims.UserID, request.Code); err != nil {
		status, code := authErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusOK, gin.H{"mfa_enabled": false})
}

func (h AuthHandler) RegenerateMFARecoveryCodes(c *gin.Context) {
	claims, ok := currentAccessClaims(c)
	if !ok {
		respondError(c, http.StatusUnauthorized, "missing_claims", "Access token claims are required")
		return
	}
	var request mfaCodeRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	result, err := h.auth.RegenerateMFARecoveryCodes(c.Request.Context(), claims.UserID, request.Code)
	if err != nil {
		status, code := authErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusOK, result)
}

func (h AuthHandler) RequestPasswordReset(c *gin.Context) {
	var request requestPasswordResetRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	result, err := h.auth.RequestPasswordReset(c.Request.Context(), request.Email)
	if err != nil {
		status, code := authErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusOK, result)
}

func (h AuthHandler) ConfirmPasswordReset(c *gin.Context) {
	var request confirmPasswordResetRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	if err := h.auth.ConfirmPasswordReset(c.Request.Context(), request.ResetToken, request.NewPassword); err != nil {
		status, code := authErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusOK, gin.H{"reset": true})
}

func authResponse(result services.AuthResult) gin.H {
	return gin.H{
		"access_token":  result.AccessToken,
		"refresh_token": result.RefreshToken,
		"token_type":    result.TokenType,
		"expires_in":    result.ExpiresIn,
	}
}

func authErrorStatus(err error) (int, string) {
	switch {
	case errors.Is(err, services.ErrInvalidCredentials),
		errors.Is(err, services.ErrInvalidRefreshToken),
		errors.Is(err, services.ErrInvalidResetToken):
		return http.StatusUnauthorized, "invalid_credentials"
	case errors.Is(err, services.ErrMFARequired):
		return http.StatusUnauthorized, "mfa_required"
	case errors.Is(err, services.ErrInvalidMFACode):
		return http.StatusUnauthorized, "invalid_mfa_code"
	default:
		return http.StatusInternalServerError, "auth_failed"
	}
}

func currentAccessClaims(c *gin.Context) (auth.AccessClaims, bool) {
	value, ok := c.Get("access_claims")
	claims, ok := value.(auth.AccessClaims)
	return claims, ok
}
