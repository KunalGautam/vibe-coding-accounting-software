package handlers

import (
	"errors"
	"net/http"
	"time"

	"accounting.abhashtech.com/internal/domain"
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
	h.RegisterReadRoutes(router)
}

func (h ReportHandler) RegisterReadRoutes(router gin.IRoutes) {
	router.GET("/reports/trial-balance", h.TrialBalance)
	router.GET("/reports/trial-balance.pdf", h.TrialBalancePDF)
	router.GET("/reports/profit-and-loss", h.ProfitAndLoss)
	router.GET("/reports/profit-and-loss.pdf", h.ProfitAndLossPDF)
	router.GET("/reports/balance-sheet", h.BalanceSheet)
	router.GET("/reports/balance-sheet.pdf", h.BalanceSheetPDF)
	router.GET("/reports/cash-flow", h.CashFlow)
	router.GET("/reports/cash-flow.pdf", h.CashFlowPDF)
	router.GET("/reports/ar-aging", h.ARAging)
	router.GET("/reports/ar-aging.pdf", h.ARAgingPDF)
	router.GET("/reports/ap-aging", h.APAging)
	router.GET("/reports/ap-aging.pdf", h.APAgingPDF)
	router.GET("/reports/tax-liability", h.TaxLiability)
	router.GET("/reports/tax-liability.pdf", h.TaxLiabilityPDF)
	router.GET("/reports/tax-summary", h.TaxSummary)
	router.GET("/reports/tax-summary.pdf", h.TaxSummaryPDF)
	router.GET("/reports/payroll-summary", h.PayrollSummary)
	router.GET("/reports/payroll-summary.csv", h.PayrollSummaryCSV)
	router.GET("/reports/payroll-statutory-components.csv", h.PayrollStatutoryComponentCSV)
	router.GET("/reports/scheduled", h.ListScheduledReports)
	router.GET("/reports/scheduled/:scheduledReportId/runs", h.ListScheduledReportRuns)
}

func (h ReportHandler) RegisterWriteRoutes(router gin.IRoutes) {
	router.POST("/reports/scheduled", h.CreateScheduledReport)
}

type createScheduledReportRequest struct {
	Name            string                          `json:"name" binding:"required"`
	ReportType      domain.ScheduledReportType      `json:"report_type" binding:"required"`
	Frequency       domain.ScheduledReportFrequency `json:"frequency" binding:"required"`
	ParametersJSON  string                          `json:"parameters_json"`
	EmailRecipients string                          `json:"email_recipients"`
	NextRunAt       string                          `json:"next_run_at" binding:"required"`
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

func (h ReportHandler) TrialBalancePDF(c *gin.Context) {
	asOf, err := requiredDateQuery(c, "as_of")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_as_of", err.Error())
		return
	}
	payload, filename, err := h.reports.TrialBalancePDF(c.Request.Context(), c.Param("organizationId"), asOf)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "trial_balance_pdf_failed", err.Error())
		return
	}
	respondPDF(c, filename, payload)
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

func (h ReportHandler) ProfitAndLossPDF(c *gin.Context) {
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
	payload, filename, err := h.reports.ProfitAndLossPDF(c.Request.Context(), c.Param("organizationId"), from, to)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "profit_and_loss_pdf_failed", err.Error())
		return
	}
	respondPDF(c, filename, payload)
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

func (h ReportHandler) BalanceSheetPDF(c *gin.Context) {
	asOf, err := requiredDateQuery(c, "as_of")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_as_of", err.Error())
		return
	}
	payload, filename, err := h.reports.BalanceSheetPDF(c.Request.Context(), c.Param("organizationId"), asOf)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "balance_sheet_pdf_failed", err.Error())
		return
	}
	respondPDF(c, filename, payload)
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

func (h ReportHandler) CashFlowPDF(c *gin.Context) {
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

	payload, filename, err := h.reports.CashFlowPDF(c.Request.Context(), c.Param("organizationId"), from, to)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "cash_flow_pdf_failed", err.Error())
		return
	}
	respondPDF(c, filename, payload)
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

func (h ReportHandler) ARAgingPDF(c *gin.Context) {
	asOf, err := requiredDateQuery(c, "as_of")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_as_of", err.Error())
		return
	}

	payload, filename, err := h.reports.ARAgingPDF(c.Request.Context(), c.Param("organizationId"), asOf)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "ar_aging_pdf_failed", err.Error())
		return
	}
	respondPDF(c, filename, payload)
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

func (h ReportHandler) APAgingPDF(c *gin.Context) {
	asOf, err := requiredDateQuery(c, "as_of")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_as_of", err.Error())
		return
	}

	payload, filename, err := h.reports.APAgingPDF(c.Request.Context(), c.Param("organizationId"), asOf)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "ap_aging_pdf_failed", err.Error())
		return
	}
	respondPDF(c, filename, payload)
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

func (h ReportHandler) TaxLiabilityPDF(c *gin.Context) {
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

	payload, filename, err := h.reports.TaxLiabilityPDF(c.Request.Context(), c.Param("organizationId"), from, to)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "tax_liability_pdf_failed", err.Error())
		return
	}
	respondPDF(c, filename, payload)
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

func (h ReportHandler) TaxSummaryPDF(c *gin.Context) {
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

	payload, filename, err := h.reports.TaxSummaryPDF(c.Request.Context(), c.Param("organizationId"), from, to)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "tax_summary_pdf_failed", err.Error())
		return
	}
	respondPDF(c, filename, payload)
}

func (h ReportHandler) PayrollSummary(c *gin.Context) {
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

	report, err := h.reports.PayrollSummary(c.Request.Context(), c.Param("organizationId"), from, to)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "payroll_summary_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, report)
}

func respondPDF(c *gin.Context, filename string, payload []byte) {
	c.Header("Content-Disposition", `attachment; filename="`+filename+`"`)
	c.Header("Cache-Control", "no-store")
	c.Data(http.StatusOK, "application/pdf", payload)
}

func (h ReportHandler) PayrollSummaryCSV(c *gin.Context) {
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

	payload, filename, err := h.reports.PayrollSummaryCSV(c.Request.Context(), c.Param("organizationId"), from, to)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "payroll_summary_csv_failed", err.Error())
		return
	}
	c.Header("Content-Disposition", `attachment; filename="`+filename+`"`)
	c.Header("Cache-Control", "no-store")
	c.Data(http.StatusOK, "text/csv; charset=utf-8", payload)
}

func (h ReportHandler) PayrollStatutoryComponentCSV(c *gin.Context) {
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

	payload, filename, err := h.reports.PayrollStatutoryComponentCSV(c.Request.Context(), c.Param("organizationId"), from, to, c.Query("component"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "payroll_statutory_component_csv_failed", err.Error())
		return
	}
	c.Header("Content-Disposition", `attachment; filename="`+filename+`"`)
	c.Header("Cache-Control", "no-store")
	c.Data(http.StatusOK, "text/csv; charset=utf-8", payload)
}

func (h ReportHandler) ListScheduledReports(c *gin.Context) {
	reports, err := h.reports.ListScheduledReports(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "scheduled_reports_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, reports)
}

func (h ReportHandler) CreateScheduledReport(c *gin.Context) {
	var request createScheduledReportRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_scheduled_report", err.Error())
		return
	}
	nextRunAt, err := parseScheduledRunAt(request.NextRunAt)
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_next_run_at", err.Error())
		return
	}

	report, err := h.reports.CreateScheduledReport(c.Request.Context(), services.CreateScheduledReportInput{
		OrganizationID:  c.Param("organizationId"),
		Name:            request.Name,
		ReportType:      request.ReportType,
		Frequency:       request.Frequency,
		ParametersJSON:  request.ParametersJSON,
		EmailRecipients: request.EmailRecipients,
		NextRunAt:       nextRunAt,
	})
	if errors.Is(err, services.ErrScheduledReportInvalid) {
		respondError(c, http.StatusBadRequest, "invalid_scheduled_report", err.Error())
		return
	}
	if err != nil {
		respondError(c, http.StatusInternalServerError, "create_scheduled_report_failed", err.Error())
		return
	}
	c.JSON(http.StatusCreated, report)
}

func (h ReportHandler) ListScheduledReportRuns(c *gin.Context) {
	runs, err := h.reports.ListScheduledReportRuns(c.Request.Context(), c.Param("organizationId"), c.Param("scheduledReportId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "scheduled_report_runs_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, runs)
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

func parseScheduledRunAt(value string) (time.Time, error) {
	if parsed, err := time.Parse(time.RFC3339, value); err == nil {
		return parsed, nil
	}
	return time.Parse("2006-01-02", value)
}

type dateQueryError struct {
	name string
}

func (e *dateQueryError) Error() string {
	return e.name + " query parameter is required and must use YYYY-MM-DD format"
}
