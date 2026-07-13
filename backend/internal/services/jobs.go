package services

import (
	"context"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

type JobService struct {
	db *gorm.DB
}

type RecurringInvoiceJobResult struct {
	OrganizationsProcessed int `json:"organizations_processed"`
	GeneratedCount         int `json:"generated_count"`
}

type BackupJobResult struct {
	OrganizationsProcessed int `json:"organizations_processed"`
	CreatedCount           int `json:"created_count"`
}

func NewJobService(db *gorm.DB) JobService {
	return JobService{db: db}
}

func (s JobService) GenerateDueRecurringInvoices(ctx context.Context, asOf time.Time) (RecurringInvoiceJobResult, error) {
	var organizations []domain.Organization
	if err := s.db.WithContext(ctx).Order("name ASC").Find(&organizations).Error; err != nil {
		return RecurringInvoiceJobResult{}, err
	}

	recurringInvoices := NewRecurringInvoiceService(s.db, NewTaxService(s.db))
	result := RecurringInvoiceJobResult{OrganizationsProcessed: len(organizations)}
	for _, organization := range organizations {
		generated, err := recurringInvoices.GenerateDue(ctx, organization.ID, asOf)
		if err != nil {
			return RecurringInvoiceJobResult{}, err
		}
		result.GeneratedCount += generated.GeneratedCount
	}
	return result, nil
}

func (s JobService) CreateScheduledBackups(ctx context.Context, storagePath string, retentionCount int) (BackupJobResult, error) {
	var organizations []domain.Organization
	if err := s.db.WithContext(ctx).Order("name ASC").Find(&organizations).Error; err != nil {
		return BackupJobResult{}, err
	}

	exports := NewDataExportService(s.db)
	result := BackupJobResult{OrganizationsProcessed: len(organizations)}
	for _, organization := range organizations {
		if _, err := exports.CreateBackupSnapshot(ctx, CreateBackupSnapshotInput{
			OrganizationID: organization.ID,
			StoragePath:    storagePath,
			RetentionCount: retentionCount,
		}); err != nil {
			return BackupJobResult{}, err
		}
		result.CreatedCount++
	}
	return result, nil
}
