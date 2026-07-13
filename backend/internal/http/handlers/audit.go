package handlers

import (
	"net/http"

	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type AuditHandler struct {
	audit services.AuditService
}

func NewAuditHandler(audit services.AuditService) AuditHandler {
	return AuditHandler{audit: audit}
}

func (h AuditHandler) RegisterRoutes(router gin.IRoutes) {
	router.GET("/audit-logs", h.List)
}

func (h AuditHandler) List(c *gin.Context) {
	logs, err := h.audit.List(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_audit_logs_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, logs)
}
