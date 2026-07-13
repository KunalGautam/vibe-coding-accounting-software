package handlers

import (
	"errors"
	"net/http"

	"accounting.abhashtech.com/internal/domain"
	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type UserHandler struct {
	users services.UserService
}

type createOrganizationUserRequest struct {
	Name     string      `json:"name" binding:"required"`
	Email    string      `json:"email" binding:"required,email"`
	Password string      `json:"password" binding:"required,min=12"`
	Role     domain.Role `json:"role" binding:"required"`
}

func NewUserHandler(users services.UserService) UserHandler {
	return UserHandler{users: users}
}

func (h UserHandler) RegisterReadRoutes(router gin.IRoutes) {
	router.GET("/users", h.List)
}

func (h UserHandler) RegisterWriteRoutes(router gin.IRoutes) {
	router.POST("/users", h.Create)
}

func (h UserHandler) List(c *gin.Context) {
	users, err := h.users.ListOrganizationUsers(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_users_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, users)
}

func (h UserHandler) Create(c *gin.Context) {
	var request createOrganizationUserRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	user, err := h.users.CreateOrganizationUser(c.Request.Context(), services.CreateOrganizationUserInput{
		OrganizationID: c.Param("organizationId"),
		Name:           request.Name,
		Email:          request.Email,
		Password:       request.Password,
		Role:           request.Role,
	})
	if err != nil {
		status, code := userErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, user)
}

func userErrorStatus(err error) (int, string) {
	switch {
	case errors.Is(err, services.ErrUserAlreadyMember):
		return http.StatusConflict, "user_already_member"
	default:
		return http.StatusInternalServerError, "user_request_failed"
	}
}
