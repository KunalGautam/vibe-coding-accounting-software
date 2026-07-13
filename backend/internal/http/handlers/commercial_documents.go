package handlers

import (
	"errors"
	"net/http"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type CommercialDocumentHandler struct {
	documents services.CommercialDocumentService
}

type createEstimateRequest struct {
	CustomerID     string                      `json:"customer_id" binding:"required"`
	EstimateNumber string                      `json:"estimate_number" binding:"required"`
	IssueDate      string                      `json:"issue_date" binding:"required"`
	ExpiryDate     string                      `json:"expiry_date" binding:"required"`
	Currency       string                      `json:"currency"`
	TaxInclusive   bool                        `json:"tax_inclusive"`
	Lines          []createEstimateLineRequest `json:"lines" binding:"required,min=1"`
}

type createEstimateLineRequest struct {
	Description     string  `json:"description" binding:"required"`
	QuantityMillis  int64   `json:"quantity_millis"`
	UnitPriceMinor  int64   `json:"unit_price_minor" binding:"required,min=0"`
	IncomeAccountID string  `json:"income_account_id" binding:"required"`
	TaxRateID       *string `json:"tax_rate_id"`
	TaxGroupID      *string `json:"tax_group_id"`
}

type convertEstimateToInvoiceRequest struct {
	InvoiceNumber        string  `json:"invoice_number" binding:"required"`
	IssueDate            string  `json:"issue_date" binding:"required"`
	DueDate              string  `json:"due_date" binding:"required"`
	AccountsReceivableID string  `json:"accounts_receivable_id" binding:"required"`
	PDFAttachmentID      *string `json:"pdf_attachment_id"`
}

type updateEstimateStatusRequest struct {
	Status domain.EstimateStatus `json:"status" binding:"required"`
}

type createCreditNoteRequest struct {
	CustomerID           string                        `json:"customer_id" binding:"required"`
	InvoiceID            *string                       `json:"invoice_id"`
	CreditNoteNumber     string                        `json:"credit_note_number" binding:"required"`
	IssueDate            string                        `json:"issue_date" binding:"required"`
	Currency             string                        `json:"currency"`
	TaxInclusive         bool                          `json:"tax_inclusive"`
	AccountsReceivableID string                        `json:"accounts_receivable_id" binding:"required"`
	Lines                []createCreditNoteLineRequest `json:"lines" binding:"required,min=1"`
}

type createCreditNoteLineRequest struct {
	Description     string  `json:"description" binding:"required"`
	QuantityMillis  int64   `json:"quantity_millis"`
	UnitPriceMinor  int64   `json:"unit_price_minor" binding:"required,min=0"`
	IncomeAccountID string  `json:"income_account_id" binding:"required"`
	TaxRateID       *string `json:"tax_rate_id"`
	TaxGroupID      *string `json:"tax_group_id"`
}

type createPurchaseOrderRequest struct {
	VendorID            string                           `json:"vendor_id" binding:"required"`
	PurchaseOrderNumber string                           `json:"purchase_order_number" binding:"required"`
	IssueDate           string                           `json:"issue_date" binding:"required"`
	ExpectedDate        string                           `json:"expected_date"`
	Currency            string                           `json:"currency"`
	TaxInclusive        bool                             `json:"tax_inclusive"`
	Lines               []createPurchaseOrderLineRequest `json:"lines" binding:"required,min=1"`
}

type createPurchaseOrderLineRequest struct {
	Description      string  `json:"description" binding:"required"`
	QuantityMillis   int64   `json:"quantity_millis"`
	UnitPriceMinor   int64   `json:"unit_price_minor" binding:"required,min=0"`
	ExpenseAccountID string  `json:"expense_account_id" binding:"required"`
	TaxRateID        *string `json:"tax_rate_id"`
	TaxGroupID       *string `json:"tax_group_id"`
}

type convertPurchaseOrderToBillRequest struct {
	BillNumber           string  `json:"bill_number" binding:"required"`
	IssueDate            string  `json:"issue_date" binding:"required"`
	DueDate              string  `json:"due_date" binding:"required"`
	AccountsPayableID    string  `json:"accounts_payable_id" binding:"required"`
	DocumentAttachmentID *string `json:"document_attachment_id"`
}

type updatePurchaseOrderStatusRequest struct {
	Status domain.PurchaseOrderStatus `json:"status" binding:"required"`
}

func NewCommercialDocumentHandler(documents services.CommercialDocumentService) CommercialDocumentHandler {
	return CommercialDocumentHandler{documents: documents}
}

func (h CommercialDocumentHandler) RegisterReadRoutes(router gin.IRoutes) {
	router.GET("/estimates", h.ListEstimates)
	router.GET("/credit-notes", h.ListCreditNotes)
	router.GET("/purchase-orders", h.ListPurchaseOrders)
}

func (h CommercialDocumentHandler) RegisterWriteRoutes(router gin.IRoutes) {
	router.POST("/estimates", h.CreateEstimate)
	router.POST("/estimates/:estimateId/status", h.UpdateEstimateStatus)
	router.POST("/estimates/:estimateId/convert-to-invoice", h.ConvertEstimateToInvoice)
	router.POST("/credit-notes", h.CreateCreditNote)
	router.POST("/credit-notes/:creditNoteId/post", h.PostCreditNote)
	router.POST("/purchase-orders", h.CreatePurchaseOrder)
	router.POST("/purchase-orders/:purchaseOrderId/status", h.UpdatePurchaseOrderStatus)
	router.POST("/purchase-orders/:purchaseOrderId/convert-to-bill", h.ConvertPurchaseOrderToBill)
}

func (h CommercialDocumentHandler) ListEstimates(c *gin.Context) {
	estimates, err := h.documents.ListEstimates(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_estimates_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, estimates)
}

func (h CommercialDocumentHandler) CreateEstimate(c *gin.Context) {
	var request createEstimateRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	issueDate, expiryDate, ok := parseDatePair(c, request.IssueDate, request.ExpiryDate, "expiry_date")
	if !ok {
		return
	}
	lines := make([]services.CreateEstimateLineInput, 0, len(request.Lines))
	for _, line := range request.Lines {
		lines = append(lines, services.CreateEstimateLineInput{Description: line.Description, QuantityMillis: line.QuantityMillis, UnitPriceMinor: line.UnitPriceMinor, IncomeAccountID: line.IncomeAccountID, TaxRateID: line.TaxRateID, TaxGroupID: line.TaxGroupID})
	}
	estimate, err := h.documents.CreateEstimate(c.Request.Context(), services.CreateEstimateInput{
		OrganizationID: c.Param("organizationId"),
		CustomerID:     request.CustomerID,
		EstimateNumber: request.EstimateNumber,
		IssueDate:      issueDate,
		ExpiryDate:     expiryDate,
		Currency:       request.Currency,
		TaxInclusive:   request.TaxInclusive,
		Lines:          lines,
	})
	if err != nil {
		status, code := commercialDocumentErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, estimate)
}

func (h CommercialDocumentHandler) ConvertEstimateToInvoice(c *gin.Context) {
	var request convertEstimateToInvoiceRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	issueDate, dueDate, ok := parseDatePair(c, request.IssueDate, request.DueDate, "due_date")
	if !ok {
		return
	}
	invoice, err := h.documents.ConvertEstimateToInvoice(c.Request.Context(), services.ConvertEstimateToInvoiceInput{
		OrganizationID:       c.Param("organizationId"),
		EstimateID:           c.Param("estimateId"),
		InvoiceNumber:        request.InvoiceNumber,
		IssueDate:            issueDate,
		DueDate:              dueDate,
		AccountsReceivableID: request.AccountsReceivableID,
		PDFAttachmentID:      request.PDFAttachmentID,
	})
	if err != nil {
		status, code := commercialDocumentErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, invoice)
}

func (h CommercialDocumentHandler) UpdateEstimateStatus(c *gin.Context) {
	var request updateEstimateStatusRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	estimate, err := h.documents.UpdateEstimateStatus(c.Request.Context(), services.UpdateEstimateStatusInput{
		OrganizationID: c.Param("organizationId"),
		EstimateID:     c.Param("estimateId"),
		Status:         request.Status,
	})
	if err != nil {
		status, code := commercialDocumentErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusOK, estimate)
}

func (h CommercialDocumentHandler) ListCreditNotes(c *gin.Context) {
	creditNotes, err := h.documents.ListCreditNotes(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_credit_notes_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, creditNotes)
}

func (h CommercialDocumentHandler) CreateCreditNote(c *gin.Context) {
	var request createCreditNoteRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	issueDate, err := time.Parse("2006-01-02", request.IssueDate)
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_issue_date", "issue_date must use YYYY-MM-DD format")
		return
	}
	lines := make([]services.CreateCreditNoteLineInput, 0, len(request.Lines))
	for _, line := range request.Lines {
		lines = append(lines, services.CreateCreditNoteLineInput{Description: line.Description, QuantityMillis: line.QuantityMillis, UnitPriceMinor: line.UnitPriceMinor, IncomeAccountID: line.IncomeAccountID, TaxRateID: line.TaxRateID, TaxGroupID: line.TaxGroupID})
	}
	creditNote, err := h.documents.CreateCreditNote(c.Request.Context(), services.CreateCreditNoteInput{
		OrganizationID:       c.Param("organizationId"),
		CustomerID:           request.CustomerID,
		InvoiceID:            request.InvoiceID,
		CreditNoteNumber:     request.CreditNoteNumber,
		IssueDate:            issueDate,
		Currency:             request.Currency,
		TaxInclusive:         request.TaxInclusive,
		AccountsReceivableID: request.AccountsReceivableID,
		Lines:                lines,
	})
	if err != nil {
		status, code := commercialDocumentErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, creditNote)
}

func (h CommercialDocumentHandler) PostCreditNote(c *gin.Context) {
	creditNote, err := h.documents.PostCreditNote(c.Request.Context(), c.Param("organizationId"), c.Param("creditNoteId"))
	if err != nil {
		status, code := commercialDocumentErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusOK, creditNote)
}

func (h CommercialDocumentHandler) ListPurchaseOrders(c *gin.Context) {
	purchaseOrders, err := h.documents.ListPurchaseOrders(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_purchase_orders_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, purchaseOrders)
}

func (h CommercialDocumentHandler) CreatePurchaseOrder(c *gin.Context) {
	var request createPurchaseOrderRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	issueDate, err := time.Parse("2006-01-02", request.IssueDate)
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_issue_date", "issue_date must use YYYY-MM-DD format")
		return
	}
	var expectedDate *time.Time
	if request.ExpectedDate != "" {
		parsed, err := time.Parse("2006-01-02", request.ExpectedDate)
		if err != nil {
			respondError(c, http.StatusBadRequest, "invalid_expected_date", "expected_date must use YYYY-MM-DD format")
			return
		}
		expectedDate = &parsed
	}
	lines := make([]services.CreatePurchaseOrderLineInput, 0, len(request.Lines))
	for _, line := range request.Lines {
		lines = append(lines, services.CreatePurchaseOrderLineInput{Description: line.Description, QuantityMillis: line.QuantityMillis, UnitPriceMinor: line.UnitPriceMinor, ExpenseAccountID: line.ExpenseAccountID, TaxRateID: line.TaxRateID, TaxGroupID: line.TaxGroupID})
	}
	purchaseOrder, err := h.documents.CreatePurchaseOrder(c.Request.Context(), services.CreatePurchaseOrderInput{
		OrganizationID:      c.Param("organizationId"),
		VendorID:            request.VendorID,
		PurchaseOrderNumber: request.PurchaseOrderNumber,
		IssueDate:           issueDate,
		ExpectedDate:        expectedDate,
		Currency:            request.Currency,
		TaxInclusive:        request.TaxInclusive,
		Lines:               lines,
	})
	if err != nil {
		status, code := commercialDocumentErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, purchaseOrder)
}

func (h CommercialDocumentHandler) ConvertPurchaseOrderToBill(c *gin.Context) {
	var request convertPurchaseOrderToBillRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	issueDate, dueDate, ok := parseDatePair(c, request.IssueDate, request.DueDate, "due_date")
	if !ok {
		return
	}
	bill, err := h.documents.ConvertPurchaseOrderToBill(c.Request.Context(), services.ConvertPurchaseOrderToBillInput{
		OrganizationID:       c.Param("organizationId"),
		PurchaseOrderID:      c.Param("purchaseOrderId"),
		BillNumber:           request.BillNumber,
		IssueDate:            issueDate,
		DueDate:              dueDate,
		AccountsPayableID:    request.AccountsPayableID,
		DocumentAttachmentID: request.DocumentAttachmentID,
	})
	if err != nil {
		status, code := commercialDocumentErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, bill)
}

func (h CommercialDocumentHandler) UpdatePurchaseOrderStatus(c *gin.Context) {
	var request updatePurchaseOrderStatusRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	purchaseOrder, err := h.documents.UpdatePurchaseOrderStatus(c.Request.Context(), services.UpdatePurchaseOrderStatusInput{
		OrganizationID:  c.Param("organizationId"),
		PurchaseOrderID: c.Param("purchaseOrderId"),
		Status:          request.Status,
	})
	if err != nil {
		status, code := commercialDocumentErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusOK, purchaseOrder)
}

func parseDatePair(c *gin.Context, first string, second string, secondName string) (time.Time, time.Time, bool) {
	firstDate, err := time.Parse("2006-01-02", first)
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_issue_date", "issue_date must use YYYY-MM-DD format")
		return time.Time{}, time.Time{}, false
	}
	secondDate, err := time.Parse("2006-01-02", second)
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_"+secondName, secondName+" must use YYYY-MM-DD format")
		return time.Time{}, time.Time{}, false
	}
	return firstDate, secondDate, true
}

func commercialDocumentErrorStatus(err error) (int, string) {
	switch {
	case errors.Is(err, services.ErrEstimateHasNoLines),
		errors.Is(err, services.ErrEstimateCannotConvert),
		errors.Is(err, services.ErrEstimateStatusInvalid),
		errors.Is(err, services.ErrCreditNoteHasNoLines),
		errors.Is(err, services.ErrCreditNoteAlreadyPosted),
		errors.Is(err, services.ErrCommercialAccountScope),
		errors.Is(err, services.ErrCommercialCustomerScope),
		errors.Is(err, services.ErrPurchaseOrderHasNoLines),
		errors.Is(err, services.ErrPurchaseOrderCannotConvert),
		errors.Is(err, services.ErrPurchaseOrderStatusInvalid),
		errors.Is(err, services.ErrPurchaseOrderVendorScope),
		errors.Is(err, services.ErrInvoiceHasNoLines),
		errors.Is(err, services.ErrInvoiceAccountScope),
		errors.Is(err, services.ErrInvoiceCustomerScope),
		errors.Is(err, services.ErrBillHasNoLines),
		errors.Is(err, services.ErrBillAccountScope),
		errors.Is(err, services.ErrBillVendorScope),
		errors.Is(err, services.ErrTaxCalculationTargetConflict),
		errors.Is(err, services.ErrTaxCalculationTargetMissing),
		errors.Is(err, services.ErrTaxGroupHasNoRates),
		errors.Is(err, domain.ErrTenantScope):
		return http.StatusBadRequest, "invalid_commercial_document"
	default:
		return http.StatusInternalServerError, "commercial_document_request_failed"
	}
}
