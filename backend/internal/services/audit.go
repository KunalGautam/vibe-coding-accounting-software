package services

import (
	"context"
	"encoding/json"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

type AuditService struct {
	db *gorm.DB
}

type RecordAuditInput struct {
	OrganizationID string
	ActorUserID    string
	EntityType     string
	EntityID       string
	Action         string
	Before         any
	After          any
	IPAddress      string
	UserAgent      string
}

func NewAuditService(db *gorm.DB) AuditService {
	return AuditService{db: db}
}

func (s AuditService) List(ctx context.Context, organizationID string) ([]domain.AuditLog, error) {
	var logs []domain.AuditLog
	err := s.db.WithContext(ctx).
		Where("organization_id = ?", organizationID).
		Order("created_at DESC").
		Find(&logs).
		Error
	return logs, err
}

func (s AuditService) Record(ctx context.Context, input RecordAuditInput) error {
	beforeJSON, err := marshalAuditJSON(input.Before)
	if err != nil {
		return err
	}
	afterJSON, err := marshalAuditJSON(input.After)
	if err != nil {
		return err
	}

	log := domain.AuditLog{
		OrganizationID: input.OrganizationID,
		ActorUserID:    input.ActorUserID,
		EntityType:     input.EntityType,
		EntityID:       input.EntityID,
		Action:         input.Action,
		BeforeJSON:     beforeJSON,
		AfterJSON:      afterJSON,
		IPAddress:      input.IPAddress,
		UserAgent:      input.UserAgent,
	}
	return s.db.WithContext(ctx).Create(&log).Error
}

func recordAuditWithTx(ctx context.Context, tx *gorm.DB, input RecordAuditInput) error {
	return NewAuditService(tx).Record(ctx, input)
}

func marshalAuditJSON(value any) (string, error) {
	if value == nil {
		return "", nil
	}
	bytes, err := json.Marshal(value)
	if err != nil {
		return "", err
	}
	return string(bytes), nil
}
