package handlers

import (
	"errors"
	"net/http"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type TaxHandler struct {
	tax services.TaxService
}

type createTaxAuthorityRequest struct {
	Name        string `json:"name" binding:"required"`
	CountryCode string `json:"country_code"`
	RegionCode  string `json:"region_code"`
}

type createTaxRateRequest struct {
	TaxAuthorityID  string         `json:"tax_authority_id" binding:"required"`
	Name            string         `json:"name" binding:"required"`
	PercentageBasis int64          `json:"percentage_basis" binding:"required,min=0"`
	Type            domain.TaxType `json:"type"`
	OutputAccountID *string        `json:"output_account_id"`
	InputAccountID  *string        `json:"input_account_id"`
	EffectiveFrom   string         `json:"effective_from" binding:"required"`
	EffectiveTo     *string        `json:"effective_to"`
	IsCompound      bool           `json:"is_compound"`
}

type createTaxGroupRequest struct {
	Name        string   `json:"name" binding:"required"`
	Description string   `json:"description"`
	TaxRateIDs  []string `json:"tax_rate_ids" binding:"required,min=1"`
}

type calculateTaxRequest struct {
	BaseAmountMinor int64   `json:"base_amount_minor" binding:"required,min=0"`
	TaxInclusive    bool    `json:"tax_inclusive"`
	TaxRateID       *string `json:"tax_rate_id"`
	TaxGroupID      *string `json:"tax_group_id"`
}

func NewTaxHandler(tax services.TaxService) TaxHandler {
	return TaxHandler{tax: tax}
}

func (h TaxHandler) RegisterReadRoutes(router gin.IRoutes) {
	router.GET("/tax/authorities", h.ListAuthorities)
	router.GET("/tax/rates", h.ListRates)
	router.GET("/tax/groups", h.ListGroups)
	router.POST("/tax/calculate", h.Calculate)
}

func (h TaxHandler) RegisterWriteRoutes(router gin.IRoutes) {
	router.POST("/tax/authorities", h.CreateAuthority)
	router.POST("/tax/rates", h.CreateRate)
	router.POST("/tax/groups", h.CreateGroup)
}

func (h TaxHandler) ListAuthorities(c *gin.Context) {
	authorities, err := h.tax.ListAuthorities(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_tax_authorities_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, authorities)
}

func (h TaxHandler) CreateAuthority(c *gin.Context) {
	var request createTaxAuthorityRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	authority, err := h.tax.CreateAuthority(c.Request.Context(), services.CreateTaxAuthorityInput{
		OrganizationID: c.Param("organizationId"),
		Name:           request.Name,
		CountryCode:    request.CountryCode,
		RegionCode:     request.RegionCode,
	})
	if err != nil {
		respondError(c, http.StatusInternalServerError, "create_tax_authority_failed", err.Error())
		return
	}
	c.JSON(http.StatusCreated, authority)
}

func (h TaxHandler) ListRates(c *gin.Context) {
	rates, err := h.tax.ListRates(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_tax_rates_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, rates)
}

func (h TaxHandler) CreateRate(c *gin.Context) {
	var request createTaxRateRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	effectiveFrom, err := time.Parse("2006-01-02", request.EffectiveFrom)
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_effective_from", "effective_from must use YYYY-MM-DD format")
		return
	}

	var effectiveTo *time.Time
	if request.EffectiveTo != nil {
		parsed, err := time.Parse("2006-01-02", *request.EffectiveTo)
		if err != nil {
			respondError(c, http.StatusBadRequest, "invalid_effective_to", "effective_to must use YYYY-MM-DD format")
			return
		}
		effectiveTo = &parsed
	}

	rate, err := h.tax.CreateRate(c.Request.Context(), services.CreateTaxRateInput{
		OrganizationID:  c.Param("organizationId"),
		TaxAuthorityID:  request.TaxAuthorityID,
		Name:            request.Name,
		PercentageBasis: request.PercentageBasis,
		Type:            request.Type,
		OutputAccountID: request.OutputAccountID,
		InputAccountID:  request.InputAccountID,
		EffectiveFrom:   effectiveFrom,
		EffectiveTo:     effectiveTo,
		IsCompound:      request.IsCompound,
	})
	if err != nil {
		respondError(c, http.StatusInternalServerError, "create_tax_rate_failed", err.Error())
		return
	}
	c.JSON(http.StatusCreated, rate)
}

func (h TaxHandler) ListGroups(c *gin.Context) {
	groups, err := h.tax.ListGroups(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_tax_groups_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, groups)
}

func (h TaxHandler) CreateGroup(c *gin.Context) {
	var request createTaxGroupRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	group, err := h.tax.CreateGroup(c.Request.Context(), services.CreateTaxGroupInput{
		OrganizationID: c.Param("organizationId"),
		Name:           request.Name,
		Description:    request.Description,
		TaxRateIDs:     request.TaxRateIDs,
	})
	if err != nil {
		status, code := taxErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, group)
}

func (h TaxHandler) Calculate(c *gin.Context) {
	var request calculateTaxRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	result, err := h.tax.Calculate(c.Request.Context(), services.CalculateTaxInput{
		OrganizationID:  c.Param("organizationId"),
		BaseAmountMinor: request.BaseAmountMinor,
		TaxInclusive:    request.TaxInclusive,
		TaxRateID:       request.TaxRateID,
		TaxGroupID:      request.TaxGroupID,
	})
	if err != nil {
		status, code := taxErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusOK, result)
}

func taxErrorStatus(err error) (int, string) {
	switch {
	case errors.Is(err, services.ErrTaxGroupHasNoRates),
		errors.Is(err, services.ErrTaxCalculationTargetMissing),
		errors.Is(err, services.ErrTaxCalculationTargetConflict),
		errors.Is(err, domain.ErrTenantScope):
		return http.StatusBadRequest, "invalid_tax_request"
	default:
		return http.StatusInternalServerError, "tax_request_failed"
	}
}
