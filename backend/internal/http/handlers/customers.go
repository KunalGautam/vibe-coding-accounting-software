package handlers

import (
	"net/http"

	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type CustomerHandler struct {
	customers services.CustomerService
}

type createCustomerRequest struct {
	DisplayName    string `json:"display_name" binding:"required"`
	Email          string `json:"email"`
	Phone          string `json:"phone"`
	BillingAddress string `json:"billing_address"`
	GSTIN          string `json:"gstin"`
}

func NewCustomerHandler(customers services.CustomerService) CustomerHandler {
	return CustomerHandler{customers: customers}
}

func (h CustomerHandler) RegisterReadRoutes(router gin.IRoutes) {
	router.GET("/customers", h.List)
}

func (h CustomerHandler) RegisterWriteRoutes(router gin.IRoutes) {
	router.POST("/customers", h.Create)
}

func (h CustomerHandler) List(c *gin.Context) {
	customers, err := h.customers.List(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_customers_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, customers)
}

func (h CustomerHandler) Create(c *gin.Context) {
	var request createCustomerRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	customer, err := h.customers.Create(c.Request.Context(), services.CreateCustomerInput{
		OrganizationID: c.Param("organizationId"),
		DisplayName:    request.DisplayName,
		Email:          request.Email,
		Phone:          request.Phone,
		BillingAddress: request.BillingAddress,
		GSTIN:          request.GSTIN,
	})
	if err != nil {
		respondError(c, http.StatusInternalServerError, "create_customer_failed", err.Error())
		return
	}
	c.JSON(http.StatusCreated, customer)
}
