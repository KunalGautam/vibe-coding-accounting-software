package handlers

import (
	"errors"
	"net/http"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type PaymentHandler struct {
	payments services.PaymentService
}

type recordPaymentRequest struct {
	PaymentNumber    string `json:"payment_number" binding:"required"`
	PaymentDate      string `json:"payment_date" binding:"required"`
	PaymentMethod    string `json:"payment_method"`
	Reference        string `json:"reference"`
	Currency         string `json:"currency"`
	AmountMinor      int64  `json:"amount_minor" binding:"required,min=1"`
	PaymentAccountID string `json:"payment_account_id" binding:"required"`
}

func NewPaymentHandler(payments services.PaymentService) PaymentHandler {
	return PaymentHandler{payments: payments}
}

func (h PaymentHandler) RegisterReadRoutes(router gin.IRoutes) {
	router.GET("/invoices/:invoiceId/payments", h.ListCustomerPayments)
	router.GET("/bills/:billId/payments", h.ListVendorPayments)
}

func (h PaymentHandler) RegisterWriteRoutes(router gin.IRoutes) {
	router.POST("/invoices/:invoiceId/payments", h.RecordCustomerPayment)
	router.POST("/bills/:billId/payments", h.RecordVendorPayment)
}

func (h PaymentHandler) ListCustomerPayments(c *gin.Context) {
	payments, err := h.payments.ListCustomerPayments(c.Request.Context(), c.Param("organizationId"), c.Param("invoiceId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_customer_payments_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, payments)
}

func (h PaymentHandler) ListVendorPayments(c *gin.Context) {
	payments, err := h.payments.ListVendorPayments(c.Request.Context(), c.Param("organizationId"), c.Param("billId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_vendor_payments_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, payments)
}

func (h PaymentHandler) RecordCustomerPayment(c *gin.Context) {
	request, paymentDate, ok := bindPaymentRequest(c)
	if !ok {
		return
	}
	payment, err := h.payments.RecordCustomerPayment(c.Request.Context(), services.RecordCustomerPaymentInput{
		OrganizationID:   c.Param("organizationId"),
		InvoiceID:        c.Param("invoiceId"),
		PaymentNumber:    request.PaymentNumber,
		PaymentDate:      paymentDate,
		PaymentMethod:    request.PaymentMethod,
		Reference:        request.Reference,
		Currency:         request.Currency,
		AmountMinor:      request.AmountMinor,
		PaymentAccountID: request.PaymentAccountID,
	})
	if err != nil {
		status, code := paymentErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, payment)
}

func (h PaymentHandler) RecordVendorPayment(c *gin.Context) {
	request, paymentDate, ok := bindPaymentRequest(c)
	if !ok {
		return
	}
	payment, err := h.payments.RecordVendorPayment(c.Request.Context(), services.RecordVendorPaymentInput{
		OrganizationID:   c.Param("organizationId"),
		BillID:           c.Param("billId"),
		PaymentNumber:    request.PaymentNumber,
		PaymentDate:      paymentDate,
		PaymentMethod:    request.PaymentMethod,
		Reference:        request.Reference,
		Currency:         request.Currency,
		AmountMinor:      request.AmountMinor,
		PaymentAccountID: request.PaymentAccountID,
	})
	if err != nil {
		status, code := paymentErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, payment)
}

func bindPaymentRequest(c *gin.Context) (recordPaymentRequest, time.Time, bool) {
	var request recordPaymentRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return recordPaymentRequest{}, time.Time{}, false
	}
	paymentDate, err := time.Parse("2006-01-02", request.PaymentDate)
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_payment_date", "payment_date must use YYYY-MM-DD format")
		return recordPaymentRequest{}, time.Time{}, false
	}
	return request, paymentDate, true
}

func paymentErrorStatus(err error) (int, string) {
	switch {
	case errors.Is(err, services.ErrPaymentAmountRequired),
		errors.Is(err, services.ErrPaymentDocumentStatus),
		errors.Is(err, services.ErrPaymentAccountScope),
		errors.Is(err, domain.ErrLedgerAccountScope):
		return http.StatusBadRequest, "invalid_payment"
	case errors.Is(err, gorm.ErrRecordNotFound):
		return http.StatusNotFound, "payment_document_not_found"
	default:
		return http.StatusInternalServerError, "payment_request_failed"
	}
}
