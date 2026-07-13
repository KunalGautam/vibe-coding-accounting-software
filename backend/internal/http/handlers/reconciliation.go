package handlers

import (
	"errors"
	"net/http"
	"time"

	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type ReconciliationHandler struct {
	reconciliation services.ReconciliationService
}

type importBankStatementRequest struct {
	AccountID string                           `json:"account_id" binding:"required"`
	FileName  string                           `json:"file_name"`
	Format    string                           `json:"format"`
	Lines     []importBankStatementLineRequest `json:"lines" binding:"required,min=1"`
}

type importQIFBankStatementRequest struct {
	AccountID  string `json:"account_id" binding:"required"`
	FileName   string `json:"file_name"`
	QIFContent string `json:"qif_content" binding:"required"`
}

type importOFXBankStatementRequest struct {
	AccountID  string `json:"account_id" binding:"required"`
	FileName   string `json:"file_name"`
	OFXContent string `json:"ofx_content" binding:"required"`
}

type importBankStatementLineRequest struct {
	PostedDate  string `json:"posted_date" binding:"required"`
	Description string `json:"description"`
	AmountMinor int64  `json:"amount_minor"`
	Reference   string `json:"reference"`
}

type matchStatementLineRequest struct {
	LedgerSplitID string `json:"ledger_split_id" binding:"required"`
}

func NewReconciliationHandler(reconciliation services.ReconciliationService) ReconciliationHandler {
	return ReconciliationHandler{reconciliation: reconciliation}
}

func (h ReconciliationHandler) RegisterReadRoutes(router gin.IRoutes) {
	router.GET("/bank-statement-lines", h.ListStatementLines)
}

func (h ReconciliationHandler) RegisterWriteRoutes(router gin.IRoutes) {
	router.POST("/imports/bank-statements", h.ImportBankStatement)
	router.POST("/bank-statements/import", h.ImportBankStatement)
	router.POST("/bank-statements/import/qif", h.ImportQIFBankStatement)
	router.POST("/bank-statements/import/ofx", h.ImportOFXBankStatement)
	router.POST("/bank-statement-lines/:statementLineId/match", h.MatchStatementLine)
	router.POST("/ledger/splits/:splitId/reconcile", h.MarkSplitReconciled)
}

func (h ReconciliationHandler) ImportBankStatement(c *gin.Context) {
	var request importBankStatementRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	lines := make([]services.ImportBankStatementLineInput, 0, len(request.Lines))
	for _, line := range request.Lines {
		postedDate, err := time.Parse("2006-01-02", line.PostedDate)
		if err != nil {
			respondError(c, http.StatusBadRequest, "invalid_posted_date", "posted_date must use YYYY-MM-DD format")
			return
		}
		lines = append(lines, services.ImportBankStatementLineInput{
			PostedDate:  postedDate,
			Description: line.Description,
			AmountMinor: line.AmountMinor,
			Reference:   line.Reference,
		})
	}

	result, err := h.reconciliation.ImportBankStatement(c.Request.Context(), services.ImportBankStatementInput{
		OrganizationID: c.Param("organizationId"),
		AccountID:      request.AccountID,
		FileName:       request.FileName,
		Format:         request.Format,
		Lines:          lines,
	})
	if err != nil {
		status, code := reconciliationErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, result)
}

func (h ReconciliationHandler) ImportQIFBankStatement(c *gin.Context) {
	var request importQIFBankStatementRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	result, err := h.reconciliation.ImportQIFBankStatement(c.Request.Context(), services.ImportQIFBankStatementInput{
		OrganizationID: c.Param("organizationId"),
		AccountID:      request.AccountID,
		FileName:       request.FileName,
		Content:        request.QIFContent,
	})
	if err != nil {
		status, code := reconciliationErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, result)
}

func (h ReconciliationHandler) ImportOFXBankStatement(c *gin.Context) {
	var request importOFXBankStatementRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	result, err := h.reconciliation.ImportOFXBankStatement(c.Request.Context(), services.ImportOFXBankStatementInput{
		OrganizationID: c.Param("organizationId"),
		AccountID:      request.AccountID,
		FileName:       request.FileName,
		Content:        request.OFXContent,
	})
	if err != nil {
		status, code := reconciliationErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, result)
}

func (h ReconciliationHandler) ListStatementLines(c *gin.Context) {
	accountID := c.Query("account_id")
	if accountID == "" {
		respondError(c, http.StatusBadRequest, "missing_account_id", "account_id query parameter is required")
		return
	}

	lines, err := h.reconciliation.ListStatementLines(c.Request.Context(), c.Param("organizationId"), accountID)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_statement_lines_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, lines)
}

func (h ReconciliationHandler) MatchStatementLine(c *gin.Context) {
	var request matchStatementLineRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	line, err := h.reconciliation.MatchStatementLine(c.Request.Context(), services.MatchStatementLineInput{
		OrganizationID:  c.Param("organizationId"),
		StatementLineID: c.Param("statementLineId"),
		LedgerSplitID:   request.LedgerSplitID,
	})
	if err != nil {
		status, code := reconciliationErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusOK, line)
}

func (h ReconciliationHandler) MarkSplitReconciled(c *gin.Context) {
	split, err := h.reconciliation.MarkSplitReconciled(c.Request.Context(), c.Param("organizationId"), c.Param("splitId"))
	if err != nil {
		status, code := reconciliationErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusOK, split)
}

func reconciliationErrorStatus(err error) (int, string) {
	switch {
	case errors.Is(err, services.ErrBankAccountScope),
		errors.Is(err, services.ErrBankStatementLineScope),
		errors.Is(err, services.ErrLedgerSplitScope),
		errors.Is(err, services.ErrQIFNoLines),
		errors.Is(err, services.ErrQIFParse),
		errors.Is(err, services.ErrOFXNoLines),
		errors.Is(err, services.ErrOFXParse):
		return http.StatusBadRequest, "invalid_reconciliation_request"
	default:
		return http.StatusInternalServerError, "reconciliation_request_failed"
	}
}
