package handlers

import (
	"net/http"

	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type OrganizationHandler struct {
	organizations services.OrganizationService
}

type createOrganizationRequest struct {
	Name         string `json:"name" binding:"required"`
	BaseCurrency string `json:"base_currency"`
	CountryCode  string `json:"country_code"`
}

func NewOrganizationHandler(organizations services.OrganizationService) OrganizationHandler {
	return OrganizationHandler{organizations: organizations}
}

func (h OrganizationHandler) RegisterRoutes(router gin.IRoutes) {
	router.GET("/organizations", h.List)
	router.POST("/organizations", h.Create)
}

func (h OrganizationHandler) List(c *gin.Context) {
	organizations, err := h.organizations.List(c.Request.Context())
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_organizations_failed", err.Error())
		return
	}

	c.JSON(http.StatusOK, organizations)
}

func (h OrganizationHandler) Create(c *gin.Context) {
	var request createOrganizationRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	organization, err := h.organizations.Create(c.Request.Context(), services.CreateOrganizationInput{
		Name:         request.Name,
		BaseCurrency: request.BaseCurrency,
		CountryCode:  request.CountryCode,
	})
	if err != nil {
		respondError(c, http.StatusInternalServerError, "create_organization_failed", err.Error())
		return
	}

	c.JSON(http.StatusCreated, organization)
}
