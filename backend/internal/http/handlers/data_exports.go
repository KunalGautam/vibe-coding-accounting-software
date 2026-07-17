package handlers

import (
	"fmt"
	"net/http"
	"time"

	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type DataExportHandler struct {
	exports services.DataExportService
}

type createBackupSnapshotRequest struct {
	StoragePath    string `json:"storage_path"`
	MirrorPath     string `json:"mirror_path"`
	RetentionCount int    `json:"retention_count"`
}

func NewDataExportHandler(exports services.DataExportService) DataExportHandler {
	return DataExportHandler{exports: exports}
}

func (h DataExportHandler) RegisterRoutes(router gin.IRoutes) {
	router.GET("/data/export", h.ExportOrganization)
	router.GET("/data/backups", h.ListBackups)
	router.POST("/data/backups", h.CreateBackup)
}

func (h DataExportHandler) ExportOrganization(c *gin.Context) {
	export, err := h.exports.ExportOrganization(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "data_export_failed", err.Error())
		return
	}

	filename := fmt.Sprintf(
		"organization-%s-export-%s.json",
		c.Param("organizationId"),
		time.Now().UTC().Format("20060102T150405Z"),
	)
	c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=%q", filename))
	c.JSON(http.StatusOK, export)
}

func (h DataExportHandler) ListBackups(c *gin.Context) {
	snapshots, err := h.exports.ListBackupSnapshots(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_backups_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, snapshots)
}

func (h DataExportHandler) CreateBackup(c *gin.Context) {
	var request createBackupSnapshotRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	snapshot, err := h.exports.CreateBackupSnapshot(c.Request.Context(), services.CreateBackupSnapshotInput{
		OrganizationID: c.Param("organizationId"),
		StoragePath:    request.StoragePath,
		MirrorPath:     request.MirrorPath,
		RetentionCount: request.RetentionCount,
	})
	if err != nil {
		respondError(c, http.StatusInternalServerError, "create_backup_failed", err.Error())
		return
	}
	c.JSON(http.StatusCreated, snapshot)
}
