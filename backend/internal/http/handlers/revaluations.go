package handlers

import (
	"errors"
	"net/http"

	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type RevaluationHandler struct {
	revaluations services.RevaluationService
}

type postRevaluationRequest struct {
	AsOfDate          string `json:"as_of_date" binding:"required"`
	GainLossAccountID string `json:"gain_loss_account_id" binding:"required"`
}

func NewRevaluationHandler(revaluations services.RevaluationService) RevaluationHandler {
	return RevaluationHandler{revaluations: revaluations}
}

func (h RevaluationHandler) RegisterReadRoutes(router gin.IRoutes) {
	router.GET("/revaluations/preview", h.Preview)
}

func (h RevaluationHandler) RegisterWriteRoutes(router gin.IRoutes) {
	router.POST("/revaluations", h.Post)
}

func (h RevaluationHandler) Preview(c *gin.Context) {
	asOf, err := requiredDateQuery(c, "as_of")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_as_of", err.Error())
		return
	}

	preview, err := h.revaluations.Preview(c.Request.Context(), c.Param("organizationId"), asOf)
	if err != nil {
		status, code := revaluationErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusOK, preview)
}

func (h RevaluationHandler) Post(c *gin.Context) {
	var request postRevaluationRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	asOf, err := parseDateField(request.AsOfDate, "as_of_date")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_as_of_date", err.Error())
		return
	}

	transaction, err := h.revaluations.Post(c.Request.Context(), services.PostRevaluationInput{
		OrganizationID:    c.Param("organizationId"),
		AsOfDate:          asOf,
		GainLossAccountID: request.GainLossAccountID,
	})
	if err != nil {
		status, code := revaluationErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, transaction)
}

func revaluationErrorStatus(err error) (int, string) {
	switch {
	case errors.Is(err, services.ErrRevaluationMissingRate):
		return http.StatusBadRequest, "missing_exchange_rate"
	case errors.Is(err, services.ErrRevaluationNoAdjustments):
		return http.StatusBadRequest, "no_revaluation_adjustments"
	case errors.Is(err, services.ErrRevaluationGainLossAccount):
		return http.StatusBadRequest, "invalid_gain_loss_account"
	default:
		return http.StatusInternalServerError, "revaluation_failed"
	}
}
