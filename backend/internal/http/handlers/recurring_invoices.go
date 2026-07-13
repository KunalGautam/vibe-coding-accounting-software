package handlers

import (
	"errors"
	"net/http"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type RecurringInvoiceHandler struct {
	recurringInvoices services.RecurringInvoiceService
}

type createRecurringInvoiceTemplateRequest struct {
	CustomerID           string                              `json:"customer_id" binding:"required"`
	Name                 string                              `json:"name" binding:"required"`
	InvoiceNumberPrefix  string                              `json:"invoice_number_prefix" binding:"required"`
	StartDate            string                              `json:"start_date" binding:"required"`
	NextRunDate          string                              `json:"next_run_date"`
	Frequency            domain.RecurrenceFrequency          `json:"frequency" binding:"required"`
	DueDays              int                                 `json:"due_days"`
	Currency             string                              `json:"currency"`
	TaxInclusive         bool                                `json:"tax_inclusive"`
	AccountsReceivableID string                              `json:"accounts_receivable_id" binding:"required"`
	Lines                []createRecurringInvoiceLineRequest `json:"lines" binding:"required,min=1"`
}

type createRecurringInvoiceLineRequest struct {
	Description     string  `json:"description" binding:"required"`
	QuantityMillis  int64   `json:"quantity_millis"`
	UnitPriceMinor  int64   `json:"unit_price_minor" binding:"required,min=0"`
	IncomeAccountID string  `json:"income_account_id" binding:"required"`
	TaxRateID       *string `json:"tax_rate_id"`
	TaxGroupID      *string `json:"tax_group_id"`
}

func NewRecurringInvoiceHandler(recurringInvoices services.RecurringInvoiceService) RecurringInvoiceHandler {
	return RecurringInvoiceHandler{recurringInvoices: recurringInvoices}
}

func (h RecurringInvoiceHandler) RegisterReadRoutes(router gin.IRoutes) {
	router.GET("/recurring-invoices", h.List)
}

func (h RecurringInvoiceHandler) RegisterWriteRoutes(router gin.IRoutes) {
	router.POST("/recurring-invoices", h.Create)
	router.POST("/recurring-invoices/generate-due", h.GenerateDue)
}

func (h RecurringInvoiceHandler) List(c *gin.Context) {
	templates, err := h.recurringInvoices.List(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_recurring_invoices_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, templates)
}

func (h RecurringInvoiceHandler) Create(c *gin.Context) {
	var request createRecurringInvoiceTemplateRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	startDate, err := time.Parse("2006-01-02", request.StartDate)
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_start_date", "start_date must use YYYY-MM-DD format")
		return
	}
	var nextRunDate time.Time
	if request.NextRunDate != "" {
		nextRunDate, err = time.Parse("2006-01-02", request.NextRunDate)
		if err != nil {
			respondError(c, http.StatusBadRequest, "invalid_next_run_date", "next_run_date must use YYYY-MM-DD format")
			return
		}
	}
	lines := make([]services.CreateRecurringInvoiceLineInput, 0, len(request.Lines))
	for _, line := range request.Lines {
		lines = append(lines, services.CreateRecurringInvoiceLineInput{
			Description:     line.Description,
			QuantityMillis:  line.QuantityMillis,
			UnitPriceMinor:  line.UnitPriceMinor,
			IncomeAccountID: line.IncomeAccountID,
			TaxRateID:       line.TaxRateID,
			TaxGroupID:      line.TaxGroupID,
		})
	}
	template, err := h.recurringInvoices.Create(c.Request.Context(), services.CreateRecurringInvoiceTemplateInput{
		OrganizationID:       c.Param("organizationId"),
		CustomerID:           request.CustomerID,
		Name:                 request.Name,
		InvoiceNumberPrefix:  request.InvoiceNumberPrefix,
		StartDate:            startDate,
		NextRunDate:          nextRunDate,
		Frequency:            request.Frequency,
		DueDays:              request.DueDays,
		Currency:             request.Currency,
		TaxInclusive:         request.TaxInclusive,
		AccountsReceivableID: request.AccountsReceivableID,
		Lines:                lines,
	})
	if err != nil {
		status, code := recurringInvoiceErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, template)
}

func (h RecurringInvoiceHandler) GenerateDue(c *gin.Context) {
	asOf := time.Now().UTC()
	if value := c.Query("as_of"); value != "" {
		parsed, err := time.Parse("2006-01-02", value)
		if err != nil {
			respondError(c, http.StatusBadRequest, "invalid_as_of", "as_of must use YYYY-MM-DD format")
			return
		}
		asOf = parsed
	}
	result, err := h.recurringInvoices.GenerateDue(c.Request.Context(), c.Param("organizationId"), asOf)
	if err != nil {
		status, code := recurringInvoiceErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, result)
}

func recurringInvoiceErrorStatus(err error) (int, string) {
	switch {
	case errors.Is(err, services.ErrRecurringInvoiceHasNoLines),
		errors.Is(err, services.ErrRecurringInvoiceFrequencyUnsupported),
		errors.Is(err, services.ErrInvoiceAccountScope),
		errors.Is(err, services.ErrInvoiceCustomerScope),
		errors.Is(err, services.ErrTaxCalculationTargetConflict),
		errors.Is(err, services.ErrTaxCalculationTargetMissing),
		errors.Is(err, services.ErrTaxGroupHasNoRates),
		errors.Is(err, domain.ErrTenantScope):
		return http.StatusBadRequest, "invalid_recurring_invoice"
	default:
		return http.StatusInternalServerError, "recurring_invoice_request_failed"
	}
}
