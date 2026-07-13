package handlers

import (
	"errors"
	"net/http"

	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type ExchangeRateHandler struct {
	rates services.ExchangeRateService
}

type createExchangeRateRequest struct {
	FromCurrency string `json:"from_currency" binding:"required,len=3"`
	ToCurrency   string `json:"to_currency" binding:"required,len=3"`
	RateDate     string `json:"rate_date" binding:"required"`
	Numerator    int64  `json:"numerator" binding:"required,min=1"`
	Denominator  int64  `json:"denominator" binding:"required,min=1"`
	Source       string `json:"source"`
}

func NewExchangeRateHandler(rates services.ExchangeRateService) ExchangeRateHandler {
	return ExchangeRateHandler{rates: rates}
}

func (h ExchangeRateHandler) RegisterReadRoutes(router gin.IRoutes) {
	router.GET("/exchange-rates", h.List)
}

func (h ExchangeRateHandler) RegisterWriteRoutes(router gin.IRoutes) {
	router.POST("/exchange-rates", h.Create)
}

func (h ExchangeRateHandler) List(c *gin.Context) {
	rates, err := h.rates.List(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_exchange_rates_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, rates)
}

func (h ExchangeRateHandler) Create(c *gin.Context) {
	var request createExchangeRateRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	rateDate, err := parseDateField(request.RateDate, "rate_date")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_rate_date", err.Error())
		return
	}

	rate, err := h.rates.Create(c.Request.Context(), services.CreateExchangeRateInput{
		OrganizationID: c.Param("organizationId"),
		FromCurrency:   request.FromCurrency,
		ToCurrency:     request.ToCurrency,
		RateDate:       rateDate,
		Numerator:      request.Numerator,
		Denominator:    request.Denominator,
		Source:         request.Source,
	})
	if err != nil {
		status, code := exchangeRateErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, rate)
}

func exchangeRateErrorStatus(err error) (int, string) {
	switch {
	case errors.Is(err, services.ErrExchangeRateInvalid):
		return http.StatusBadRequest, "invalid_exchange_rate"
	default:
		return http.StatusInternalServerError, "exchange_rate_request_failed"
	}
}
