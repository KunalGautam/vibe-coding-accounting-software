package handlers

import (
	"net/http"
	"time"

	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type ReportHandler struct {
	reports services.ReportService
}

func NewReportHandler(reports services.ReportService) ReportHandler {
	return ReportHandler{reports: reports}
}

func (h ReportHandler) RegisterRoutes(router gin.IRoutes) {
	router.GET("/reports/trial-balance", h.TrialBalance)
	router.GET("/reports/profit-and-loss", h.ProfitAndLoss)
	router.GET("/reports/balance-sheet", h.BalanceSheet)
	router.GET("/reports/cash-flow", h.CashFlow)
	router.GET("/reports/ar-aging", h.ARAging)
	router.GET("/reports/ap-aging", h.APAging)
	router.GET("/reports/tax-liability", h.TaxLiability)
	router.GET("/reports/tax-summary", h.TaxSummary)
}

func (h ReportHandler) TrialBalance(c *gin.Context) {
	asOf, err := requiredDateQuery(c, "as_of")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_as_of", err.Error())
		return
	}

	report, err := h.reports.TrialBalance(c.Request.Context(), c.Param("organizationId"), asOf)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "trial_balance_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, report)
}

func (h ReportHandler) ProfitAndLoss(c *gin.Context) {
	from, err := requiredDateQuery(c, "from")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_from", err.Error())
		return
	}
	to, err := requiredDateQuery(c, "to")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_to", err.Error())
		return
	}

	report, err := h.reports.ProfitAndLoss(c.Request.Context(), c.Param("organizationId"), from, to)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "profit_and_loss_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, report)
}

func (h ReportHandler) BalanceSheet(c *gin.Context) {
	asOf, err := requiredDateQuery(c, "as_of")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_as_of", err.Error())
		return
	}

	report, err := h.reports.BalanceSheet(c.Request.Context(), c.Param("organizationId"), asOf)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "balance_sheet_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, report)
}

func (h ReportHandler) CashFlow(c *gin.Context) {
	from, err := requiredDateQuery(c, "from")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_from", err.Error())
		return
	}
	to, err := requiredDateQuery(c, "to")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_to", err.Error())
		return
	}

	report, err := h.reports.CashFlow(c.Request.Context(), c.Param("organizationId"), from, to)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "cash_flow_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, report)
}

func (h ReportHandler) ARAging(c *gin.Context) {
	asOf, err := requiredDateQuery(c, "as_of")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_as_of", err.Error())
		return
	}

	report, err := h.reports.ARAging(c.Request.Context(), c.Param("organizationId"), asOf)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "ar_aging_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, report)
}

func (h ReportHandler) APAging(c *gin.Context) {
	asOf, err := requiredDateQuery(c, "as_of")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_as_of", err.Error())
		return
	}

	report, err := h.reports.APAging(c.Request.Context(), c.Param("organizationId"), asOf)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "ap_aging_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, report)
}

func (h ReportHandler) TaxLiability(c *gin.Context) {
	from, err := requiredDateQuery(c, "from")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_from", err.Error())
		return
	}
	to, err := requiredDateQuery(c, "to")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_to", err.Error())
		return
	}

	report, err := h.reports.TaxLiability(c.Request.Context(), c.Param("organizationId"), from, to)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "tax_liability_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, report)
}

func (h ReportHandler) TaxSummary(c *gin.Context) {
	from, err := requiredDateQuery(c, "from")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_from", err.Error())
		return
	}
	to, err := requiredDateQuery(c, "to")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_to", err.Error())
		return
	}

	report, err := h.reports.TaxSummary(c.Request.Context(), c.Param("organizationId"), from, to)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "tax_summary_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, report)
}

func requiredDateQuery(c *gin.Context, name string) (time.Time, error) {
	value := c.Query(name)
	if value == "" {
		return time.Time{}, &dateQueryError{name: name}
	}
	parsed, err := time.Parse("2006-01-02", value)
	if err != nil {
		return time.Time{}, err
	}
	return parsed, nil
}

type dateQueryError struct {
	name string
}

func (e *dateQueryError) Error() string {
	return e.name + " query parameter is required and must use YYYY-MM-DD format"
}
