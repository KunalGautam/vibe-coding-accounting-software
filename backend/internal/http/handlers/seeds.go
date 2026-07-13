package handlers

import (
	"net/http"

	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type SeedHandler struct {
	seeds services.SeedService
}

func NewSeedHandler(seeds services.SeedService) SeedHandler {
	return SeedHandler{seeds: seeds}
}

func (h SeedHandler) RegisterIndiaRoutes(router gin.IRoutes) {
	router.POST("/seed/india-defaults", h.SeedIndiaDefaults)
}

func (h SeedHandler) SeedIndiaDefaults(c *gin.Context) {
	organizationID := c.Param("organizationId")

	result, err := h.seeds.SeedIndiaDefaults(c.Request.Context(), organizationID)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "seed_india_defaults_failed", err.Error())
		return
	}

	c.JSON(http.StatusOK, result)
}
