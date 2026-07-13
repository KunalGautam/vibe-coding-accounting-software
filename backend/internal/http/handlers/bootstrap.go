package handlers

import (
	"errors"
	"net/http"

	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type BootstrapHandler struct {
	bootstrap services.BootstrapService
	seeds     services.SeedService
}

type bootstrapRequest struct {
	OrganizationName  string `json:"organization_name" binding:"required"`
	AdminName         string `json:"admin_name" binding:"required"`
	AdminEmail        string `json:"admin_email" binding:"required,email"`
	AdminPassword     string `json:"admin_password" binding:"required,min=12"`
	BaseCurrency      string `json:"base_currency"`
	CountryCode       string `json:"country_code"`
	SeedIndiaDefaults bool   `json:"seed_india_defaults"`
}

func NewBootstrapHandler(bootstrap services.BootstrapService, seeds services.SeedService) BootstrapHandler {
	return BootstrapHandler{bootstrap: bootstrap, seeds: seeds}
}

func (h BootstrapHandler) RegisterRoutes(router gin.IRoutes) {
	router.POST("/bootstrap/first-admin", h.CreateFirstAdmin)
}

func (h BootstrapHandler) CreateFirstAdmin(c *gin.Context) {
	var request bootstrapRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	result, err := h.bootstrap.CreateFirstAdmin(c.Request.Context(), services.BootstrapInput{
		OrganizationName: request.OrganizationName,
		AdminName:        request.AdminName,
		AdminEmail:       request.AdminEmail,
		AdminPassword:    request.AdminPassword,
		BaseCurrency:     request.BaseCurrency,
		CountryCode:      request.CountryCode,
	})
	if err != nil {
		if errors.Is(err, services.ErrBootstrapAlreadyCompleted) {
			respondError(c, http.StatusConflict, "bootstrap_already_completed", err.Error())
			return
		}
		respondError(c, http.StatusInternalServerError, "bootstrap_failed", err.Error())
		return
	}

	response := gin.H{
		"organization": result.Organization,
		"user": gin.H{
			"id":         result.User.ID,
			"email":      result.User.Email,
			"name":       result.User.Name,
			"is_active":  result.User.IsActive,
			"created_at": result.User.CreatedAt,
		},
		"membership": result.Membership,
	}

	if request.SeedIndiaDefaults {
		seedResult, err := h.seeds.SeedIndiaDefaults(c.Request.Context(), result.Organization.ID)
		if err != nil {
			respondError(c, http.StatusInternalServerError, "seed_india_defaults_failed", err.Error())
			return
		}
		response["india_seed"] = seedResult
	}

	c.JSON(http.StatusCreated, response)
}
