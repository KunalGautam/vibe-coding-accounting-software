package handlers

import (
	"errors"
	"net/http"

	"accounting.abhashtech.com/internal/domain"
	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type InvestmentHandler struct {
	investments services.InvestmentService
}

type createInvestmentLotRequest struct {
	AccountID       string                      `json:"account_id" binding:"required"`
	Symbol          string                      `json:"symbol" binding:"required"`
	SecurityName    string                      `json:"security_name"`
	AcquisitionDate string                      `json:"acquisition_date" binding:"required"`
	QuantityMillis  int64                       `json:"quantity_millis" binding:"required,min=1"`
	CostBasisMinor  int64                       `json:"cost_basis_minor" binding:"required,min=1"`
	Currency        string                      `json:"currency"`
	CostMethod      domain.InvestmentCostMethod `json:"cost_method"`
	Notes           string                      `json:"notes"`
}

type sellInvestmentLotRequest struct {
	SaleDate          string `json:"sale_date" binding:"required"`
	QuantityMillis    int64  `json:"quantity_millis" binding:"required,min=1"`
	ProceedsMinor     int64  `json:"proceeds_minor" binding:"required,min=1"`
	ProceedsAccountID string `json:"proceeds_account_id"`
	GainLossAccountID string `json:"gain_loss_account_id"`
	Notes             string `json:"notes"`
}

type sellAverageCostRequest struct {
	AccountID         string `json:"account_id" binding:"required"`
	Symbol            string `json:"symbol" binding:"required"`
	Currency          string `json:"currency"`
	SaleDate          string `json:"sale_date" binding:"required"`
	QuantityMillis    int64  `json:"quantity_millis" binding:"required,min=1"`
	ProceedsMinor     int64  `json:"proceeds_minor" binding:"required,min=1"`
	ProceedsAccountID string `json:"proceeds_account_id"`
	GainLossAccountID string `json:"gain_loss_account_id"`
	Notes             string `json:"notes"`
}

type createInvestmentPriceRequest struct {
	Symbol     string `json:"symbol" binding:"required"`
	PriceDate  string `json:"price_date" binding:"required"`
	PriceMinor int64  `json:"price_minor" binding:"required,min=1"`
	Currency   string `json:"currency"`
	Source     string `json:"source"`
}

func NewInvestmentHandler(investments services.InvestmentService) InvestmentHandler {
	return InvestmentHandler{investments: investments}
}

func (h InvestmentHandler) RegisterReadRoutes(router gin.IRoutes) {
	router.GET("/investments/lots", h.ListLots)
	router.GET("/investments/prices", h.ListPrices)
	router.GET("/reports/realized-gains", h.RealizedGains)
	router.GET("/reports/investment-valuation", h.Valuation)
}

func (h InvestmentHandler) RegisterWriteRoutes(router gin.IRoutes) {
	router.POST("/investments/lots", h.CreateLot)
	router.POST("/investments/lots/:lotId/sell", h.SellLot)
	router.POST("/investments/average-cost-sales", h.SellAverageCost)
	router.POST("/investments/prices", h.CreatePrice)
}

func (h InvestmentHandler) ListLots(c *gin.Context) {
	lots, err := h.investments.ListLots(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_investment_lots_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, lots)
}

func (h InvestmentHandler) CreateLot(c *gin.Context) {
	var request createInvestmentLotRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	acquisitionDate, err := parseDateField(request.AcquisitionDate, "acquisition_date")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_acquisition_date", err.Error())
		return
	}

	lot, err := h.investments.CreateLot(c.Request.Context(), services.CreateInvestmentLotInput{
		OrganizationID:  c.Param("organizationId"),
		AccountID:       request.AccountID,
		Symbol:          request.Symbol,
		SecurityName:    request.SecurityName,
		AcquisitionDate: acquisitionDate,
		QuantityMillis:  request.QuantityMillis,
		CostBasisMinor:  request.CostBasisMinor,
		Currency:        request.Currency,
		CostMethod:      request.CostMethod,
		Notes:           request.Notes,
	})
	if err != nil {
		status, code := investmentErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, lot)
}

func (h InvestmentHandler) ListPrices(c *gin.Context) {
	prices, err := h.investments.ListPrices(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_investment_prices_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, prices)
}

func (h InvestmentHandler) CreatePrice(c *gin.Context) {
	var request createInvestmentPriceRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	priceDate, err := parseDateField(request.PriceDate, "price_date")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_price_date", err.Error())
		return
	}

	price, err := h.investments.CreatePrice(c.Request.Context(), services.CreateInvestmentPriceInput{
		OrganizationID: c.Param("organizationId"),
		Symbol:         request.Symbol,
		PriceDate:      priceDate,
		PriceMinor:     request.PriceMinor,
		Currency:       request.Currency,
		Source:         request.Source,
	})
	if err != nil {
		status, code := investmentErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, price)
}

func (h InvestmentHandler) SellLot(c *gin.Context) {
	var request sellInvestmentLotRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	saleDate, err := parseDateField(request.SaleDate, "sale_date")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_sale_date", err.Error())
		return
	}

	disposition, err := h.investments.SellLot(c.Request.Context(), services.SellInvestmentLotInput{
		OrganizationID:    c.Param("organizationId"),
		LotID:             c.Param("lotId"),
		SaleDate:          saleDate,
		QuantityMillis:    request.QuantityMillis,
		ProceedsMinor:     request.ProceedsMinor,
		ProceedsAccountID: request.ProceedsAccountID,
		GainLossAccountID: request.GainLossAccountID,
		Notes:             request.Notes,
	})
	if err != nil {
		status, code := investmentErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, disposition)
}

func (h InvestmentHandler) SellAverageCost(c *gin.Context) {
	var request sellAverageCostRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	saleDate, err := parseDateField(request.SaleDate, "sale_date")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_sale_date", err.Error())
		return
	}

	result, err := h.investments.SellAverageCost(c.Request.Context(), services.SellAverageCostInput{
		OrganizationID:    c.Param("organizationId"),
		AccountID:         request.AccountID,
		Symbol:            request.Symbol,
		Currency:          request.Currency,
		SaleDate:          saleDate,
		QuantityMillis:    request.QuantityMillis,
		ProceedsMinor:     request.ProceedsMinor,
		ProceedsAccountID: request.ProceedsAccountID,
		GainLossAccountID: request.GainLossAccountID,
		Notes:             request.Notes,
	})
	if err != nil {
		status, code := investmentErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, result)
}

func (h InvestmentHandler) RealizedGains(c *gin.Context) {
	from, err := requiredDateQuery(c, "from")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_from_date", err.Error())
		return
	}
	to, err := requiredDateQuery(c, "to")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_to_date", err.Error())
		return
	}

	report, err := h.investments.RealizedGains(c.Request.Context(), c.Param("organizationId"), from, to)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "realized_gains_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, report)
}

func (h InvestmentHandler) Valuation(c *gin.Context) {
	asOf, err := requiredDateQuery(c, "as_of")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_as_of_date", err.Error())
		return
	}

	report, err := h.investments.Valuation(c.Request.Context(), c.Param("organizationId"), asOf)
	if err != nil {
		status, code := investmentErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusOK, report)
}

func investmentErrorStatus(err error) (int, string) {
	switch {
	case errors.Is(err, services.ErrInvestmentLotInvalid),
		errors.Is(err, services.ErrInvestmentDispositionInvalid),
		errors.Is(err, services.ErrInvestmentPriceInvalid),
		errors.Is(err, services.ErrInvestmentAverageCostInvalid):
		return http.StatusBadRequest, "invalid_investment_request"
	case errors.Is(err, services.ErrInvestmentLotInsufficientUnits):
		return http.StatusBadRequest, "insufficient_investment_lot_quantity"
	case errors.Is(err, services.ErrInvestmentPriceMissing):
		return http.StatusBadRequest, "missing_investment_price"
	case errors.Is(err, services.ErrInvestmentPostingAccounts):
		return http.StatusBadRequest, "missing_investment_posting_accounts"
	case errors.Is(err, domain.ErrTenantScope):
		return http.StatusNotFound, "investment_reference_not_found"
	default:
		return http.StatusInternalServerError, "investment_request_failed"
	}
}
