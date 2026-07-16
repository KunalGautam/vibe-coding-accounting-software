package handlers

import (
	"errors"
	"net/http"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type InvoiceHandler struct {
	invoices services.InvoiceService
}

type createInvoiceRequest struct {
	CustomerID           string                     `json:"customer_id" binding:"required"`
	InvoiceNumber        string                     `json:"invoice_number" binding:"required"`
	IssueDate            string                     `json:"issue_date" binding:"required"`
	DueDate              string                     `json:"due_date" binding:"required"`
	Currency             string                     `json:"currency"`
	TaxInclusive         bool                       `json:"tax_inclusive"`
	AccountsReceivableID string                     `json:"accounts_receivable_id" binding:"required"`
	PDFAttachmentID      *string                    `json:"pdf_attachment_id"`
	Lines                []createInvoiceLineRequest `json:"lines" binding:"required,min=1"`
}

type createInvoiceLineRequest struct {
	Description     string  `json:"description" binding:"required"`
	QuantityMillis  int64   `json:"quantity_millis"`
	UnitPriceMinor  int64   `json:"unit_price_minor" binding:"required,min=0"`
	IncomeAccountID string  `json:"income_account_id" binding:"required"`
	TaxRateID       *string `json:"tax_rate_id"`
	TaxGroupID      *string `json:"tax_group_id"`
}

func NewInvoiceHandler(invoices services.InvoiceService) InvoiceHandler {
	return InvoiceHandler{invoices: invoices}
}

func (h InvoiceHandler) RegisterReadRoutes(router gin.IRoutes) {
	router.GET("/invoices", h.List)
}

func (h InvoiceHandler) RegisterWriteRoutes(router gin.IRoutes) {
	router.POST("/invoices", h.Create)
	router.PUT("/invoices/:invoiceId", h.Update)
	router.POST("/invoices/:invoiceId/post", h.Post)
}

func (h InvoiceHandler) List(c *gin.Context) {
	invoices, err := h.invoices.List(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_invoices_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, invoices)
}

func (h InvoiceHandler) Create(c *gin.Context) {
	var request createInvoiceRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	issueDate, err := time.Parse("2006-01-02", request.IssueDate)
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_issue_date", "issue_date must use YYYY-MM-DD format")
		return
	}
	dueDate, err := time.Parse("2006-01-02", request.DueDate)
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_due_date", "due_date must use YYYY-MM-DD format")
		return
	}

	lines := make([]services.CreateInvoiceLineInput, 0, len(request.Lines))
	for _, line := range request.Lines {
		lines = append(lines, services.CreateInvoiceLineInput{
			Description:     line.Description,
			QuantityMillis:  line.QuantityMillis,
			UnitPriceMinor:  line.UnitPriceMinor,
			IncomeAccountID: line.IncomeAccountID,
			TaxRateID:       line.TaxRateID,
			TaxGroupID:      line.TaxGroupID,
		})
	}

	invoice, err := h.invoices.Create(c.Request.Context(), services.CreateInvoiceInput{
		OrganizationID:       c.Param("organizationId"),
		CustomerID:           request.CustomerID,
		InvoiceNumber:        request.InvoiceNumber,
		IssueDate:            issueDate,
		DueDate:              dueDate,
		Currency:             request.Currency,
		TaxInclusive:         request.TaxInclusive,
		AccountsReceivableID: request.AccountsReceivableID,
		PDFAttachmentID:      request.PDFAttachmentID,
		Lines:                lines,
	})
	if err != nil {
		status, code := invoiceErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, invoice)
}

func (h InvoiceHandler) Update(c *gin.Context) {
	var request createInvoiceRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	issueDate, err := time.Parse("2006-01-02", request.IssueDate)
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_issue_date", "issue_date must use YYYY-MM-DD format")
		return
	}
	dueDate, err := time.Parse("2006-01-02", request.DueDate)
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_due_date", "due_date must use YYYY-MM-DD format")
		return
	}

	lines := make([]services.CreateInvoiceLineInput, 0, len(request.Lines))
	for _, line := range request.Lines {
		lines = append(lines, services.CreateInvoiceLineInput{
			Description:     line.Description,
			QuantityMillis:  line.QuantityMillis,
			UnitPriceMinor:  line.UnitPriceMinor,
			IncomeAccountID: line.IncomeAccountID,
			TaxRateID:       line.TaxRateID,
			TaxGroupID:      line.TaxGroupID,
		})
	}

	invoice, err := h.invoices.Update(c.Request.Context(), services.UpdateInvoiceInput{
		InvoiceID: c.Param("invoiceId"),
		CreateInvoiceInput: services.CreateInvoiceInput{
			OrganizationID:       c.Param("organizationId"),
			CustomerID:           request.CustomerID,
			InvoiceNumber:        request.InvoiceNumber,
			IssueDate:            issueDate,
			DueDate:              dueDate,
			Currency:             request.Currency,
			TaxInclusive:         request.TaxInclusive,
			AccountsReceivableID: request.AccountsReceivableID,
			PDFAttachmentID:      request.PDFAttachmentID,
			Lines:                lines,
		},
	})
	if err != nil {
		status, code := invoiceErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusOK, invoice)
}

func (h InvoiceHandler) Post(c *gin.Context) {
	invoice, err := h.invoices.Post(c.Request.Context(), c.Param("organizationId"), c.Param("invoiceId"))
	if err != nil {
		status, code := invoiceErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusOK, invoice)
}

func invoiceErrorStatus(err error) (int, string) {
	switch {
	case errors.Is(err, services.ErrInvoiceHasNoLines),
		errors.Is(err, services.ErrInvoiceAlreadyPosted),
		errors.Is(err, services.ErrInvoiceAccountScope),
		errors.Is(err, services.ErrInvoiceCustomerScope),
		errors.Is(err, services.ErrTaxCalculationTargetConflict),
		errors.Is(err, services.ErrTaxCalculationTargetMissing),
		errors.Is(err, services.ErrTaxGroupHasNoRates),
		errors.Is(err, domain.ErrTenantScope):
		return http.StatusBadRequest, "invalid_invoice"
	default:
		return http.StatusInternalServerError, "invoice_request_failed"
	}
}
