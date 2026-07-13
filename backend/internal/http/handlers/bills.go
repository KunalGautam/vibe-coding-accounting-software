package handlers

import (
	"errors"
	"net/http"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type BillHandler struct {
	bills services.BillService
}

type createBillRequest struct {
	VendorID             string                  `json:"vendor_id" binding:"required"`
	BillNumber           string                  `json:"bill_number" binding:"required"`
	IssueDate            string                  `json:"issue_date" binding:"required"`
	DueDate              string                  `json:"due_date" binding:"required"`
	Currency             string                  `json:"currency"`
	TaxInclusive         bool                    `json:"tax_inclusive"`
	AccountsPayableID    string                  `json:"accounts_payable_id" binding:"required"`
	DocumentAttachmentID *string                 `json:"document_attachment_id"`
	Lines                []createBillLineRequest `json:"lines" binding:"required,min=1"`
}

type createBillLineRequest struct {
	Description      string  `json:"description" binding:"required"`
	QuantityMillis   int64   `json:"quantity_millis"`
	UnitPriceMinor   int64   `json:"unit_price_minor" binding:"required"`
	ExpenseAccountID string  `json:"expense_account_id" binding:"required"`
	TaxRateID        *string `json:"tax_rate_id"`
	TaxGroupID       *string `json:"tax_group_id"`
}

func NewBillHandler(bills services.BillService) BillHandler {
	return BillHandler{bills: bills}
}

func (h BillHandler) RegisterReadRoutes(router gin.IRoutes) {
	router.GET("/bills", h.List)
}

func (h BillHandler) RegisterWriteRoutes(router gin.IRoutes) {
	router.POST("/bills", h.Create)
	router.POST("/bills/:billId/post", h.Post)
}

func (h BillHandler) List(c *gin.Context) {
	bills, err := h.bills.List(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_bills_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, bills)
}

func (h BillHandler) Create(c *gin.Context) {
	var request createBillRequest
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
	lines := make([]services.CreateBillLineInput, 0, len(request.Lines))
	for _, line := range request.Lines {
		lines = append(lines, services.CreateBillLineInput{
			Description:      line.Description,
			QuantityMillis:   line.QuantityMillis,
			UnitPriceMinor:   line.UnitPriceMinor,
			ExpenseAccountID: line.ExpenseAccountID,
			TaxRateID:        line.TaxRateID,
			TaxGroupID:       line.TaxGroupID,
		})
	}

	bill, err := h.bills.Create(c.Request.Context(), services.CreateBillInput{
		OrganizationID:       c.Param("organizationId"),
		VendorID:             request.VendorID,
		BillNumber:           request.BillNumber,
		IssueDate:            issueDate,
		DueDate:              dueDate,
		Currency:             request.Currency,
		TaxInclusive:         request.TaxInclusive,
		AccountsPayableID:    request.AccountsPayableID,
		DocumentAttachmentID: request.DocumentAttachmentID,
		Lines:                lines,
	})
	if err != nil {
		status, code := billErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, bill)
}

func (h BillHandler) Post(c *gin.Context) {
	bill, err := h.bills.Post(c.Request.Context(), c.Param("organizationId"), c.Param("billId"))
	if err != nil {
		status, code := billErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusOK, bill)
}

func billErrorStatus(err error) (int, string) {
	switch {
	case errors.Is(err, services.ErrBillHasNoLines),
		errors.Is(err, services.ErrBillAlreadyPosted),
		errors.Is(err, services.ErrBillAccountScope),
		errors.Is(err, services.ErrBillVendorScope),
		errors.Is(err, services.ErrTaxCalculationTargetConflict),
		errors.Is(err, services.ErrTaxCalculationTargetMissing),
		errors.Is(err, services.ErrTaxGroupHasNoRates),
		errors.Is(err, domain.ErrTenantScope):
		return http.StatusBadRequest, "invalid_bill"
	default:
		return http.StatusInternalServerError, "bill_request_failed"
	}
}
