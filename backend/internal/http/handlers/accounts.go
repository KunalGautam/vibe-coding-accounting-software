package handlers

import (
	"net/http"

	"accounting.abhashtech.com/internal/domain"
	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type AccountHandler struct {
	accounts services.AccountService
}

type createAccountRequest struct {
	ParentID      *string            `json:"parent_id"`
	Code          string             `json:"code" binding:"required"`
	Name          string             `json:"name" binding:"required"`
	Type          domain.AccountType `json:"type" binding:"required"`
	Subtype       string             `json:"subtype"`
	Currency      string             `json:"currency"`
	IsPlaceholder bool               `json:"is_placeholder"`
}

func NewAccountHandler(accounts services.AccountService) AccountHandler {
	return AccountHandler{accounts: accounts}
}

func (h AccountHandler) RegisterRoutes(router gin.IRoutes) {
	router.GET("/accounts", h.List)
	router.POST("/accounts", h.Create)
}

func (h AccountHandler) RegisterReadRoutes(router gin.IRoutes) {
	router.GET("/accounts", h.List)
}

func (h AccountHandler) RegisterWriteRoutes(router gin.IRoutes) {
	router.POST("/accounts", h.Create)
}

func (h AccountHandler) List(c *gin.Context) {
	organizationID := c.Param("organizationId")

	accounts, err := h.accounts.List(c.Request.Context(), organizationID)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_accounts_failed", err.Error())
		return
	}

	c.JSON(http.StatusOK, accounts)
}

func (h AccountHandler) Create(c *gin.Context) {
	organizationID := c.Param("organizationId")

	var request createAccountRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	account, err := h.accounts.Create(c.Request.Context(), services.CreateAccountInput{
		OrganizationID: organizationID,
		ParentID:       request.ParentID,
		Code:           request.Code,
		Name:           request.Name,
		Type:           request.Type,
		Subtype:        request.Subtype,
		Currency:       request.Currency,
		IsPlaceholder:  request.IsPlaceholder,
	})
	if err != nil {
		respondError(c, http.StatusInternalServerError, "create_account_failed", err.Error())
		return
	}

	c.JSON(http.StatusCreated, account)
}
