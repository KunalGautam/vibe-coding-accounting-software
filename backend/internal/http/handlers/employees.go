package handlers

import (
	"net/http"

	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type EmployeeHandler struct {
	employees services.EmployeeService
}

type createEmployeeRequest struct {
	DisplayName  string `json:"display_name" binding:"required"`
	Email        string `json:"email"`
	Phone        string `json:"phone"`
	EmployeeCode string `json:"employee_code"`
	PAN          string `json:"pan"`
	UAN          string `json:"uan"`
}

func NewEmployeeHandler(employees services.EmployeeService) EmployeeHandler {
	return EmployeeHandler{employees: employees}
}

func (h EmployeeHandler) RegisterReadRoutes(router gin.IRoutes) {
	router.GET("/employees", h.List)
}

func (h EmployeeHandler) RegisterWriteRoutes(router gin.IRoutes) {
	router.POST("/employees", h.Create)
}

func (h EmployeeHandler) List(c *gin.Context) {
	employees, err := h.employees.List(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_employees_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, employees)
}

func (h EmployeeHandler) Create(c *gin.Context) {
	var request createEmployeeRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	employee, err := h.employees.Create(c.Request.Context(), services.CreateEmployeeInput{
		OrganizationID: c.Param("organizationId"),
		DisplayName:    request.DisplayName,
		Email:          request.Email,
		Phone:          request.Phone,
		EmployeeCode:   request.EmployeeCode,
		PAN:            request.PAN,
		UAN:            request.UAN,
	})
	if err != nil {
		respondError(c, http.StatusInternalServerError, "create_employee_failed", err.Error())
		return
	}
	c.JSON(http.StatusCreated, employee)
}
