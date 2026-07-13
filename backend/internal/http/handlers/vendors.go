package handlers

import (
	"net/http"

	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type VendorHandler struct {
	vendors services.VendorService
}

type createVendorRequest struct {
	DisplayName    string `json:"display_name" binding:"required"`
	Email          string `json:"email"`
	Phone          string `json:"phone"`
	BillingAddress string `json:"billing_address"`
	GSTIN          string `json:"gstin"`
}

func NewVendorHandler(vendors services.VendorService) VendorHandler {
	return VendorHandler{vendors: vendors}
}

func (h VendorHandler) RegisterReadRoutes(router gin.IRoutes) {
	router.GET("/vendors", h.List)
}

func (h VendorHandler) RegisterWriteRoutes(router gin.IRoutes) {
	router.POST("/vendors", h.Create)
}

func (h VendorHandler) List(c *gin.Context) {
	vendors, err := h.vendors.List(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_vendors_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, vendors)
}

func (h VendorHandler) Create(c *gin.Context) {
	var request createVendorRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	vendor, err := h.vendors.Create(c.Request.Context(), services.CreateVendorInput{
		OrganizationID: c.Param("organizationId"),
		DisplayName:    request.DisplayName,
		Email:          request.Email,
		Phone:          request.Phone,
		BillingAddress: request.BillingAddress,
		GSTIN:          request.GSTIN,
	})
	if err != nil {
		respondError(c, http.StatusInternalServerError, "create_vendor_failed", err.Error())
		return
	}
	c.JSON(http.StatusCreated, vendor)
}
