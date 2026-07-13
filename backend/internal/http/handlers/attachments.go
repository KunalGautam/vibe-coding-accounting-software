package handlers

import (
	"errors"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type AttachmentHandler struct {
	attachments   services.AttachmentService
	storageDriver string
	storagePath   string
}

type createAttachmentRequest struct {
	FileName      string `json:"file_name" binding:"required"`
	ContentType   string `json:"content_type"`
	StorageDriver string `json:"storage_driver"`
	StorageKey    string `json:"storage_key" binding:"required"`
	SizeBytes     int64  `json:"size_bytes" binding:"min=0"`
}

func NewAttachmentHandler(attachments services.AttachmentService, storageDriver string, storagePath string) AttachmentHandler {
	if storageDriver == "" {
		storageDriver = "local"
	}
	if storagePath == "" {
		storagePath = "./storage"
	}
	return AttachmentHandler{
		attachments:   attachments,
		storageDriver: storageDriver,
		storagePath:   storagePath,
	}
}

func (h AttachmentHandler) RegisterReadRoutes(router gin.IRoutes) {
	router.GET("/attachments", h.List)
	router.GET("/attachments/:attachmentId/download", h.Download)
}

func (h AttachmentHandler) RegisterWriteRoutes(router gin.IRoutes) {
	router.POST("/attachments", h.Create)
	router.POST("/attachments/upload", h.Upload)
}

func (h AttachmentHandler) List(c *gin.Context) {
	attachments, err := h.attachments.List(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_attachments_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, attachments)
}

func (h AttachmentHandler) Create(c *gin.Context) {
	var request createAttachmentRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	attachment, err := h.attachments.Create(c.Request.Context(), services.CreateAttachmentInput{
		OrganizationID: c.Param("organizationId"),
		FileName:       request.FileName,
		ContentType:    request.ContentType,
		StorageDriver:  request.StorageDriver,
		StorageKey:     request.StorageKey,
		SizeBytes:      request.SizeBytes,
	})
	if err != nil {
		respondError(c, http.StatusInternalServerError, "create_attachment_failed", err.Error())
		return
	}
	c.JSON(http.StatusCreated, attachment)
}

func (h AttachmentHandler) Upload(c *gin.Context) {
	if h.storageDriver != "local" {
		respondError(c, http.StatusBadRequest, "unsupported_attachment_storage", "only local attachment storage is currently supported for direct uploads")
		return
	}

	fileHeader, err := c.FormFile("file")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_file", err.Error())
		return
	}

	source, err := fileHeader.Open()
	if err != nil {
		respondError(c, http.StatusBadRequest, "open_file_failed", err.Error())
		return
	}
	defer source.Close()

	attachmentID := uuid.NewString()
	fileName := filepath.Base(fileHeader.Filename)
	storageKey := filepath.ToSlash(filepath.Join(c.Param("organizationId"), attachmentID, fileName))
	destinationPath, err := h.localStoragePath(storageKey)
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_storage_key", err.Error())
		return
	}
	if err := os.MkdirAll(filepath.Dir(destinationPath), 0o755); err != nil {
		respondError(c, http.StatusInternalServerError, "create_attachment_directory_failed", err.Error())
		return
	}

	destination, err := os.Create(destinationPath)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "create_attachment_file_failed", err.Error())
		return
	}
	defer destination.Close()

	sizeBytes, err := io.Copy(destination, source)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "write_attachment_file_failed", err.Error())
		return
	}

	attachment, err := h.attachments.Create(c.Request.Context(), services.CreateAttachmentInput{
		ID:             attachmentID,
		OrganizationID: c.Param("organizationId"),
		FileName:       fileName,
		ContentType:    fileHeader.Header.Get("Content-Type"),
		StorageDriver:  h.storageDriver,
		StorageKey:     storageKey,
		SizeBytes:      sizeBytes,
	})
	if err != nil {
		respondError(c, http.StatusInternalServerError, "create_attachment_failed", err.Error())
		return
	}
	c.JSON(http.StatusCreated, attachment)
}

func (h AttachmentHandler) Download(c *gin.Context) {
	attachment, err := h.attachments.Get(c.Request.Context(), c.Param("organizationId"), c.Param("attachmentId"))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			respondError(c, http.StatusNotFound, "attachment_not_found", "attachment not found")
			return
		}
		respondError(c, http.StatusInternalServerError, "get_attachment_failed", err.Error())
		return
	}
	if attachment.StorageDriver != "local" {
		respondError(c, http.StatusBadRequest, "unsupported_attachment_storage", "only local attachment storage is currently supported for direct downloads")
		return
	}

	path, err := h.localStoragePath(attachment.StorageKey)
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_storage_key", err.Error())
		return
	}
	c.FileAttachment(path, attachment.FileName)
}

func (h AttachmentHandler) localStoragePath(storageKey string) (string, error) {
	cleanKey := filepath.Clean(storageKey)
	if filepath.IsAbs(cleanKey) || cleanKey == "." || strings.HasPrefix(cleanKey, ".."+string(filepath.Separator)) || cleanKey == ".." {
		return "", errors.New("storage key must be relative")
	}
	return filepath.Join(h.storagePath, cleanKey), nil
}
