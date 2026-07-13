package handlers

import (
	"errors"
	"net/http"

	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type AuthHandler struct {
	auth services.AuthService
}

type loginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

type refreshTokenRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

type requestPasswordResetRequest struct {
	Email string `json:"email" binding:"required,email"`
}

type confirmPasswordResetRequest struct {
	ResetToken  string `json:"reset_token" binding:"required"`
	NewPassword string `json:"new_password" binding:"required,min=12"`
}

func NewAuthHandler(auth services.AuthService) AuthHandler {
	return AuthHandler{auth: auth}
}

func (h AuthHandler) RegisterRoutes(router gin.IRoutes) {
	router.POST("/auth/login", h.Login)
	router.POST("/auth/refresh", h.Refresh)
	router.POST("/auth/password-reset/request", h.RequestPasswordReset)
	router.POST("/auth/password-reset/confirm", h.ConfirmPasswordReset)
}

func (h AuthHandler) Login(c *gin.Context) {
	var request loginRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	result, err := h.auth.Login(c.Request.Context(), request.Email, request.Password)
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
	default:
		return http.StatusInternalServerError, "auth_failed"
	}
}
