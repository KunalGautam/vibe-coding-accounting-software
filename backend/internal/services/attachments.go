package services

import (
	"context"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

type AttachmentService struct {
	db *gorm.DB
}

type CreateAttachmentInput struct {
	ID             string
	OrganizationID string
	FileName       string
	ContentType    string
	StorageDriver  string
	StorageKey     string
	SizeBytes      int64
	ChecksumSHA256 string
}

func NewAttachmentService(db *gorm.DB) AttachmentService {
	return AttachmentService{db: db}
}

func (s AttachmentService) List(ctx context.Context, organizationID string) ([]domain.Attachment, error) {
	var attachments []domain.Attachment
	err := s.db.WithContext(ctx).
		Where("organization_id = ?", organizationID).
		Order("created_at DESC").
		Find(&attachments).
		Error
	return attachments, err
}

func (s AttachmentService) Create(ctx context.Context, input CreateAttachmentInput) (domain.Attachment, error) {
	storageDriver := input.StorageDriver
	if storageDriver == "" {
		storageDriver = "local"
	}

	attachment := domain.Attachment{
		BaseModel:      domain.BaseModel{ID: input.ID},
		OrganizationID: input.OrganizationID,
		FileName:       input.FileName,
		ContentType:    input.ContentType,
		StorageDriver:  storageDriver,
		StorageKey:     input.StorageKey,
		SizeBytes:      input.SizeBytes,
		ChecksumSHA256: input.ChecksumSHA256,
	}
	err := s.db.WithContext(ctx).Create(&attachment).Error
	return attachment, err
}

func (s AttachmentService) Get(ctx context.Context, organizationID string, attachmentID string) (domain.Attachment, error) {
	var attachment domain.Attachment
	err := s.db.WithContext(ctx).
		Where("organization_id = ? AND id = ?", organizationID, attachmentID).
		First(&attachment).
		Error
	return attachment, err
}
