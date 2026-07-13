package handlers

import (
	"errors"
	"net/http"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type ExpenseHandler struct {
	expenses services.ExpenseService
}

type createExpenseRequest struct {
	VendorID            *string `json:"vendor_id"`
	ExpenseNumber       string  `json:"expense_number" binding:"required"`
	ExpenseDate         string  `json:"expense_date" binding:"required"`
	Currency            string  `json:"currency"`
	TaxInclusive        bool    `json:"tax_inclusive"`
	AmountMinor         int64   `json:"amount_minor" binding:"required,min=0"`
	ExpenseAccountID    string  `json:"expense_account_id" binding:"required"`
	PaymentAccountID    string  `json:"payment_account_id" binding:"required"`
	ReceiptAttachmentID *string `json:"receipt_attachment_id"`
	TaxRateID           *string `json:"tax_rate_id"`
	TaxGroupID          *string `json:"tax_group_id"`
	Reimbursable        bool    `json:"reimbursable"`
}

func NewExpenseHandler(expenses services.ExpenseService) ExpenseHandler {
	return ExpenseHandler{expenses: expenses}
}

func (h ExpenseHandler) RegisterReadRoutes(router gin.IRoutes) {
	router.GET("/expenses", h.List)
}

func (h ExpenseHandler) RegisterWriteRoutes(router gin.IRoutes) {
	router.POST("/expenses", h.Create)
	router.POST("/expenses/:expenseId/post", h.Post)
}

func (h ExpenseHandler) List(c *gin.Context) {
	expenses, err := h.expenses.List(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_expenses_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, expenses)
}

func (h ExpenseHandler) Create(c *gin.Context) {
	var request createExpenseRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	expenseDate, err := time.Parse("2006-01-02", request.ExpenseDate)
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_expense_date", "expense_date must use YYYY-MM-DD format")
		return
	}

	expense, err := h.expenses.Create(c.Request.Context(), services.CreateExpenseInput{
		OrganizationID:      c.Param("organizationId"),
		VendorID:            request.VendorID,
		ExpenseNumber:       request.ExpenseNumber,
		ExpenseDate:         expenseDate,
		Currency:            request.Currency,
		TaxInclusive:        request.TaxInclusive,
		AmountMinor:         request.AmountMinor,
		ExpenseAccountID:    request.ExpenseAccountID,
		PaymentAccountID:    request.PaymentAccountID,
		ReceiptAttachmentID: request.ReceiptAttachmentID,
		TaxRateID:           request.TaxRateID,
		TaxGroupID:          request.TaxGroupID,
		Reimbursable:        request.Reimbursable,
	})
	if err != nil {
		status, code := expenseErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, expense)
}

func (h ExpenseHandler) Post(c *gin.Context) {
	expense, err := h.expenses.Post(c.Request.Context(), c.Param("organizationId"), c.Param("expenseId"))
	if err != nil {
		status, code := expenseErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusOK, expense)
}

func expenseErrorStatus(err error) (int, string) {
	switch {
	case errors.Is(err, services.ErrExpenseAlreadyPosted),
		errors.Is(err, services.ErrExpenseAccountScope),
		errors.Is(err, services.ErrExpenseVendorScope),
		errors.Is(err, services.ErrTaxCalculationTargetConflict),
		errors.Is(err, services.ErrTaxCalculationTargetMissing),
		errors.Is(err, services.ErrTaxGroupHasNoRates),
		errors.Is(err, domain.ErrTenantScope):
		return http.StatusBadRequest, "invalid_expense"
	default:
		return http.StatusInternalServerError, "expense_request_failed"
	}
}
