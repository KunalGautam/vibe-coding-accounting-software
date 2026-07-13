package handlers

import (
	"net/http"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type LedgerHandler struct {
	ledger services.LedgerService
}

type postJournalTransactionRequest struct {
	TransactionDate string                   `json:"transaction_date" binding:"required"`
	Memo            string                   `json:"memo"`
	SourceModule    domain.SourceModule      `json:"source_module"`
	Splits          []postLedgerSplitRequest `json:"splits" binding:"required,min=2"`
}

type postLedgerSplitRequest struct {
	AccountID               string `json:"account_id" binding:"required"`
	Memo                    string `json:"memo"`
	DebitMinor              int64  `json:"debit_minor"`
	CreditMinor             int64  `json:"credit_minor"`
	BaseDebitMinor          int64  `json:"base_debit_minor"`
	BaseCreditMinor         int64  `json:"base_credit_minor"`
	Currency                string `json:"currency"`
	ExchangeRateNumerator   int64  `json:"exchange_rate_numerator"`
	ExchangeRateDenominator int64  `json:"exchange_rate_denominator"`
}

func NewLedgerHandler(ledger services.LedgerService) LedgerHandler {
	return LedgerHandler{ledger: ledger}
}

func (h LedgerHandler) RegisterRoutes(router gin.IRoutes) {
	router.GET("/ledger/transactions", h.ListTransactions)
	router.POST("/ledger/transactions", h.PostTransaction)
	router.GET("/ledger/accounts/:accountId/register", h.AccountRegister)
}

func (h LedgerHandler) RegisterReadRoutes(router gin.IRoutes) {
	router.GET("/ledger/transactions", h.ListTransactions)
	router.GET("/ledger/accounts/:accountId/register", h.AccountRegister)
}

func (h LedgerHandler) RegisterWriteRoutes(router gin.IRoutes) {
	router.POST("/ledger/transactions", h.PostTransaction)
}

func (h LedgerHandler) ListTransactions(c *gin.Context) {
	organizationID := c.Param("organizationId")

	transactions, err := h.ledger.ListTransactions(c.Request.Context(), organizationID)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_transactions_failed", err.Error())
		return
	}

	c.JSON(http.StatusOK, transactions)
}

func (h LedgerHandler) PostTransaction(c *gin.Context) {
	organizationID := c.Param("organizationId")

	var request postJournalTransactionRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	transactionDate, err := time.Parse("2006-01-02", request.TransactionDate)
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_transaction_date", "transaction_date must use YYYY-MM-DD format")
		return
	}

	splits := make([]services.PostLedgerSplitInput, 0, len(request.Splits))
	for _, split := range request.Splits {
		splits = append(splits, services.PostLedgerSplitInput{
			AccountID:               split.AccountID,
			Memo:                    split.Memo,
			DebitMinor:              split.DebitMinor,
			CreditMinor:             split.CreditMinor,
			BaseDebitMinor:          split.BaseDebitMinor,
			BaseCreditMinor:         split.BaseCreditMinor,
			Currency:                split.Currency,
			ExchangeRateNumerator:   split.ExchangeRateNumerator,
			ExchangeRateDenominator: split.ExchangeRateDenominator,
		})
	}

	transaction, err := h.ledger.PostTransaction(c.Request.Context(), services.PostJournalTransactionInput{
		OrganizationID:  organizationID,
		TransactionDate: transactionDate,
		Memo:            request.Memo,
		SourceModule:    request.SourceModule,
		Splits:          splits,
	})
	if err != nil {
		status, code := ledgerErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}

	c.JSON(http.StatusCreated, transaction)
}

func (h LedgerHandler) AccountRegister(c *gin.Context) {
	organizationID := c.Param("organizationId")
	accountID := c.Param("accountId")

	splits, err := h.ledger.AccountRegister(c.Request.Context(), organizationID, accountID)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "account_register_failed", err.Error())
		return
	}

	c.JSON(http.StatusOK, splits)
}

func ledgerErrorStatus(err error) (int, string) {
	switch {
	case services.IsLedgerValidationError(err):
		return http.StatusBadRequest, "invalid_journal_transaction"
	default:
		return http.StatusInternalServerError, "post_transaction_failed"
	}
}
