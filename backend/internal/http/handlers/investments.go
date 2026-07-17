package handlers

import (
	"errors"
	"net/http"
	"strconv"

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

type importInvestmentPricesRequest struct {
	CSV    string `json:"csv" binding:"required"`
	Source string `json:"source"`
	Symbol string `json:"symbol"`
}

type importAMFINAVRequest struct {
	Text       string `json:"text" binding:"required"`
	SymbolMode string `json:"symbol_mode"`
}

type createInvestmentDividendRequest struct {
	AccountID       string `json:"account_id" binding:"required"`
	Symbol          string `json:"symbol" binding:"required"`
	DividendDate    string `json:"dividend_date" binding:"required"`
	AmountMinor     int64  `json:"amount_minor" binding:"required,min=1"`
	Currency        string `json:"currency"`
	CashAccountID   string `json:"cash_account_id"`
	IncomeAccountID string `json:"income_account_id"`
	Notes           string `json:"notes"`
}

type createInvestmentCorporateActionRequest struct {
	AccountID        string                               `json:"account_id" binding:"required"`
	Symbol           string                               `json:"symbol" binding:"required"`
	ActionType       domain.InvestmentCorporateActionType `json:"action_type" binding:"required"`
	ActionDate       string                               `json:"action_date" binding:"required"`
	RatioNumerator   int64                                `json:"ratio_numerator" binding:"required,min=1"`
	RatioDenominator int64                                `json:"ratio_denominator" binding:"required,min=1"`
	Notes            string                               `json:"notes"`
}

func NewInvestmentHandler(investments services.InvestmentService) InvestmentHandler {
	return InvestmentHandler{investments: investments}
}

func (h InvestmentHandler) RegisterReadRoutes(router gin.IRoutes) {
	router.GET("/investments/lots", h.ListLots)
	router.GET("/investments/prices", h.ListPrices)
	router.GET("/investments/dividends", h.ListDividends)
	router.GET("/investments/corporate-actions", h.ListCorporateActions)
	router.GET("/reports/realized-gains", h.RealizedGains)
	router.GET("/reports/investment-dividends", h.DividendReport)
	router.GET("/reports/investment-tax-lots", h.TaxLotReport)
	router.GET("/reports/investment-tax-adjustments", h.TaxAdjustmentReport)
	router.GET("/reports/investment-valuation", h.Valuation)
	router.GET("/reports/investment-corporate-actions", h.CorporateActionReport)
	router.GET("/reports/investment-corporate-actions.csv", h.CorporateActionReportCSV)
}

func (h InvestmentHandler) RegisterWriteRoutes(router gin.IRoutes) {
	router.POST("/investments/lots", h.CreateLot)
	router.POST("/investments/lots/:lotId/sell", h.SellLot)
	router.POST("/investments/average-cost-sales", h.SellAverageCost)
	router.POST("/investments/prices", h.CreatePrice)
	router.POST("/investments/prices/import", h.ImportPrices)
	router.POST("/investments/prices/import/amfi", h.ImportAMFINAV)
	router.POST("/investments/prices/import/nse", h.ImportNSEEquityCSV)
	router.POST("/investments/prices/import/bse", h.ImportBSEEquityCSV)
	router.POST("/investments/prices/import/yahoo", h.ImportYahooFinanceCSV)
	router.POST("/investments/prices/import/alphavantage", h.ImportAlphaVantageCSV)
	router.POST("/investments/prices/import/broker-holdings", h.ImportBrokerHoldingsCSV)
	router.POST("/investments/prices/import/zerodha-holdings", h.ImportZerodhaHoldingsCSV)
	router.POST("/investments/dividends", h.CreateDividend)
	router.POST("/investments/corporate-actions", h.CreateCorporateAction)
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

func (h InvestmentHandler) ImportPrices(c *gin.Context) {
	var request importInvestmentPricesRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	result, err := h.investments.ImportPricesCSV(c.Request.Context(), services.ImportInvestmentPricesInput{
		OrganizationID: c.Param("organizationId"),
		CSV:            request.CSV,
		Source:         request.Source,
	})
	if err != nil {
		status, code := investmentErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, result)
}

func (h InvestmentHandler) ImportAMFINAV(c *gin.Context) {
	var request importAMFINAVRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	result, err := h.investments.ImportAMFINAV(c.Request.Context(), services.ImportAMFINAVInput{
		OrganizationID: c.Param("organizationId"),
		Text:           request.Text,
		SymbolMode:     request.SymbolMode,
	})
	if err != nil {
		status, code := investmentErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, result)
}

func (h InvestmentHandler) ImportYahooFinanceCSV(c *gin.Context) {
	var request importInvestmentPricesRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	result, err := h.investments.ImportYahooFinanceCSV(c.Request.Context(), services.ImportInvestmentPricesInput{
		OrganizationID: c.Param("organizationId"),
		CSV:            request.CSV,
		Source:         request.Source,
		Symbol:         request.Symbol,
	})
	if err != nil {
		status, code := investmentErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, result)
}

func (h InvestmentHandler) ImportNSEEquityCSV(c *gin.Context) {
	var request importInvestmentPricesRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	result, err := h.investments.ImportNSEEquityCSV(c.Request.Context(), services.ImportInvestmentPricesInput{
		OrganizationID: c.Param("organizationId"),
		CSV:            request.CSV,
		Source:         request.Source,
	})
	if err != nil {
		status, code := investmentErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, result)
}

func (h InvestmentHandler) ImportAlphaVantageCSV(c *gin.Context) {
	var request importInvestmentPricesRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	result, err := h.investments.ImportAlphaVantageCSV(c.Request.Context(), services.ImportInvestmentPricesInput{
		OrganizationID: c.Param("organizationId"),
		CSV:            request.CSV,
		Source:         request.Source,
		Symbol:         request.Symbol,
	})
	if err != nil {
		status, code := investmentErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, result)
}

func (h InvestmentHandler) ImportBrokerHoldingsCSV(c *gin.Context) {
	var request importInvestmentPricesRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	result, err := h.investments.ImportBrokerHoldingsCSV(c.Request.Context(), services.ImportInvestmentPricesInput{
		OrganizationID: c.Param("organizationId"),
		CSV:            request.CSV,
		Source:         request.Source,
	})
	if err != nil {
		status, code := investmentErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, result)
}

func (h InvestmentHandler) ImportZerodhaHoldingsCSV(c *gin.Context) {
	var request importInvestmentPricesRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	result, err := h.investments.ImportZerodhaHoldingsCSV(c.Request.Context(), services.ImportInvestmentPricesInput{
		OrganizationID: c.Param("organizationId"),
		CSV:            request.CSV,
		Source:         request.Source,
	})
	if err != nil {
		status, code := investmentErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, result)
}

func (h InvestmentHandler) ImportBSEEquityCSV(c *gin.Context) {
	var request importInvestmentPricesRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	result, err := h.investments.ImportBSEEquityCSV(c.Request.Context(), services.ImportInvestmentPricesInput{
		OrganizationID: c.Param("organizationId"),
		CSV:            request.CSV,
		Source:         request.Source,
	})
	if err != nil {
		status, code := investmentErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, result)
}

func (h InvestmentHandler) ListDividends(c *gin.Context) {
	dividends, err := h.investments.ListDividends(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_investment_dividends_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, dividends)
}

func (h InvestmentHandler) CreateDividend(c *gin.Context) {
	var request createInvestmentDividendRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	dividendDate, err := parseDateField(request.DividendDate, "dividend_date")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_dividend_date", err.Error())
		return
	}

	dividend, err := h.investments.CreateDividend(c.Request.Context(), services.CreateInvestmentDividendInput{
		OrganizationID:  c.Param("organizationId"),
		AccountID:       request.AccountID,
		Symbol:          request.Symbol,
		DividendDate:    dividendDate,
		AmountMinor:     request.AmountMinor,
		Currency:        request.Currency,
		CashAccountID:   request.CashAccountID,
		IncomeAccountID: request.IncomeAccountID,
		Notes:           request.Notes,
	})
	if err != nil {
		status, code := investmentErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, dividend)
}

func (h InvestmentHandler) ListCorporateActions(c *gin.Context) {
	actions, err := h.investments.ListCorporateActions(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_investment_corporate_actions_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, actions)
}

func (h InvestmentHandler) CreateCorporateAction(c *gin.Context) {
	var request createInvestmentCorporateActionRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	actionDate, err := parseDateField(request.ActionDate, "action_date")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_action_date", err.Error())
		return
	}

	action, err := h.investments.CreateCorporateAction(c.Request.Context(), services.CreateInvestmentCorporateActionInput{
		OrganizationID:   c.Param("organizationId"),
		AccountID:        request.AccountID,
		Symbol:           request.Symbol,
		ActionType:       request.ActionType,
		ActionDate:       actionDate,
		RatioNumerator:   request.RatioNumerator,
		RatioDenominator: request.RatioDenominator,
		Notes:            request.Notes,
	})
	if err != nil {
		status, code := investmentErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, action)
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

func (h InvestmentHandler) DividendReport(c *gin.Context) {
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

	report, err := h.investments.DividendReport(c.Request.Context(), c.Param("organizationId"), from, to)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "investment_dividends_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, report)
}

func (h InvestmentHandler) CorporateActionReport(c *gin.Context) {
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

	report, err := h.investments.CorporateActionReport(c.Request.Context(), c.Param("organizationId"), from, to)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "investment_corporate_actions_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, report)
}

func (h InvestmentHandler) CorporateActionReportCSV(c *gin.Context) {
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

	payload, filename, err := h.investments.CorporateActionReportCSV(c.Request.Context(), c.Param("organizationId"), from, to)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "investment_corporate_actions_csv_failed", err.Error())
		return
	}
	c.Header("Content-Disposition", `attachment; filename="`+filename+`"`)
	c.Header("Cache-Control", "no-store")
	c.Data(http.StatusOK, "text/csv; charset=utf-8", payload)
}

func (h InvestmentHandler) TaxLotReport(c *gin.Context) {
	asOf, err := requiredDateQuery(c, "as_of")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_as_of_date", err.Error())
		return
	}

	report, err := h.investments.TaxLotReport(c.Request.Context(), c.Param("organizationId"), asOf)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "investment_tax_lots_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, report)
}

func (h InvestmentHandler) TaxAdjustmentReport(c *gin.Context) {
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
	windowDays := 30
	if value := c.Query("window_days"); value != "" {
		parsed, err := strconv.Atoi(value)
		if err != nil || parsed <= 0 {
			respondError(c, http.StatusBadRequest, "invalid_window_days", "window_days must be a positive integer")
			return
		}
		windowDays = parsed
	}

	report, err := h.investments.TaxAdjustmentReport(c.Request.Context(), c.Param("organizationId"), from, to, windowDays)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "investment_tax_adjustments_failed", err.Error())
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
		errors.Is(err, services.ErrInvestmentPriceImportInvalid),
		errors.Is(err, services.ErrInvestmentAverageCostInvalid),
		errors.Is(err, services.ErrInvestmentDividendInvalid),
		errors.Is(err, services.ErrInvestmentCorporateActionInvalid):
		return http.StatusBadRequest, "invalid_investment_request"
	case errors.Is(err, services.ErrInvestmentLotInsufficientUnits):
		return http.StatusBadRequest, "insufficient_investment_lot_quantity"
	case errors.Is(err, services.ErrInvestmentCorporateActionNoLots):
		return http.StatusBadRequest, "no_matching_investment_lots"
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
