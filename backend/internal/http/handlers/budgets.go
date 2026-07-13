package handlers

import (
	"errors"
	"net/http"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type BudgetHandler struct {
	budgets services.BudgetService
}

type createBudgetRequest struct {
	Name      string                    `json:"name" binding:"required"`
	StartDate string                    `json:"start_date" binding:"required"`
	EndDate   string                    `json:"end_date" binding:"required"`
	Status    domain.BudgetStatus       `json:"status"`
	Lines     []createBudgetLineRequest `json:"lines" binding:"required,min=1"`
}

type createBudgetLineRequest struct {
	AccountID   string `json:"account_id" binding:"required"`
	PeriodStart string `json:"period_start" binding:"required"`
	PeriodEnd   string `json:"period_end" binding:"required"`
	AmountMinor int64  `json:"amount_minor"`
}

func NewBudgetHandler(budgets services.BudgetService) BudgetHandler {
	return BudgetHandler{budgets: budgets}
}

func (h BudgetHandler) RegisterReadRoutes(router gin.IRoutes) {
	router.GET("/budgets", h.List)
	router.GET("/budgets/:budgetId/vs-actual", h.BudgetVsActual)
}

func (h BudgetHandler) RegisterWriteRoutes(router gin.IRoutes) {
	router.POST("/budgets", h.Create)
}

func (h BudgetHandler) List(c *gin.Context) {
	budgets, err := h.budgets.List(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_budgets_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, budgets)
}

func (h BudgetHandler) Create(c *gin.Context) {
	var request createBudgetRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	startDate, err := parseDateField(request.StartDate, "start_date")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_start_date", err.Error())
		return
	}
	endDate, err := parseDateField(request.EndDate, "end_date")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_end_date", err.Error())
		return
	}

	lines := make([]services.CreateBudgetLineInput, 0, len(request.Lines))
	for _, line := range request.Lines {
		periodStart, err := time.Parse("2006-01-02", line.PeriodStart)
		if err != nil {
			respondError(c, http.StatusBadRequest, "invalid_period_start", "period_start must use YYYY-MM-DD format")
			return
		}
		periodEnd, err := time.Parse("2006-01-02", line.PeriodEnd)
		if err != nil {
			respondError(c, http.StatusBadRequest, "invalid_period_end", "period_end must use YYYY-MM-DD format")
			return
		}
		lines = append(lines, services.CreateBudgetLineInput{
			AccountID:   line.AccountID,
			PeriodStart: periodStart,
			PeriodEnd:   periodEnd,
			AmountMinor: line.AmountMinor,
		})
	}

	budget, err := h.budgets.Create(c.Request.Context(), services.CreateBudgetInput{
		OrganizationID: c.Param("organizationId"),
		Name:           request.Name,
		StartDate:      startDate,
		EndDate:        endDate,
		Status:         request.Status,
		Lines:          lines,
	})
	if err != nil {
		status, code := budgetErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, budget)
}

func (h BudgetHandler) BudgetVsActual(c *gin.Context) {
	report, err := h.budgets.BudgetVsActual(c.Request.Context(), c.Param("organizationId"), c.Param("budgetId"))
	if err != nil {
		status, code := budgetErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusOK, report)
}

func budgetErrorStatus(err error) (int, string) {
	switch {
	case errors.Is(err, services.ErrBudgetHasNoLines),
		errors.Is(err, services.ErrBudgetAccountScope):
		return http.StatusBadRequest, "invalid_budget"
	default:
		return http.StatusInternalServerError, "budget_request_failed"
	}
}
