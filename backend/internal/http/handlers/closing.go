package handlers

import (
	"errors"
	"net/http"

	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type ClosingHandler struct {
	closing services.ClosingService
}

type closeFiscalYearRequest struct {
	FiscalYearStart           string `json:"fiscal_year_start" binding:"required"`
	FiscalYearEnd             string `json:"fiscal_year_end" binding:"required"`
	RetainedEarningsAccountID string `json:"retained_earnings_account_id" binding:"required"`
}

func NewClosingHandler(closing services.ClosingService) ClosingHandler {
	return ClosingHandler{closing: closing}
}

func (h ClosingHandler) RegisterReadRoutes(router gin.IRoutes) {
	router.GET("/closing/fiscal-years", h.List)
}

func (h ClosingHandler) RegisterWriteRoutes(router gin.IRoutes) {
	router.POST("/closing/fiscal-years", h.CloseFiscalYear)
}

func (h ClosingHandler) List(c *gin.Context) {
	closes, err := h.closing.List(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_fiscal_closes_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, closes)
}

func (h ClosingHandler) CloseFiscalYear(c *gin.Context) {
	var request closeFiscalYearRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	start, err := parseDateField(request.FiscalYearStart, "fiscal_year_start")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_fiscal_year_start", err.Error())
		return
	}
	end, err := parseDateField(request.FiscalYearEnd, "fiscal_year_end")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_fiscal_year_end", err.Error())
		return
	}

	closeRecord, err := h.closing.CloseFiscalYear(c.Request.Context(), services.CloseFiscalYearInput{
		OrganizationID:            c.Param("organizationId"),
		FiscalYearStart:           start,
		FiscalYearEnd:             end,
		RetainedEarningsAccountID: request.RetainedEarningsAccountID,
	})
	if err != nil {
		status, code := closingErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, closeRecord)
}

func closingErrorStatus(err error) (int, string) {
	switch {
	case errors.Is(err, services.ErrCloseAccountScope),
		errors.Is(err, services.ErrCloseNoBalances):
		return http.StatusBadRequest, "invalid_fiscal_close"
	default:
		return http.StatusInternalServerError, "fiscal_close_failed"
	}
}
