package services

import (
	"context"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

type VendorService struct {
	db *gorm.DB
}

type CreateVendorInput struct {
	OrganizationID string
	DisplayName    string
	Email          string
	Phone          string
	BillingAddress string
	GSTIN          string
}

func NewVendorService(db *gorm.DB) VendorService {
	return VendorService{db: db}
}

func (s VendorService) List(ctx context.Context, organizationID string) ([]domain.Vendor, error) {
	var vendors []domain.Vendor
	err := s.db.WithContext(ctx).
		Where("organization_id = ? AND is_active = ?", organizationID, true).
		Order("display_name ASC").
		Find(&vendors).
		Error
	return vendors, err
}

func (s VendorService) Create(ctx context.Context, input CreateVendorInput) (domain.Vendor, error) {
	vendor := domain.Vendor{
		OrganizationID: input.OrganizationID,
		DisplayName:    input.DisplayName,
		Email:          input.Email,
		Phone:          input.Phone,
		BillingAddress: input.BillingAddress,
		GSTIN:          input.GSTIN,
		IsActive:       true,
	}
	err := s.db.WithContext(ctx).Create(&vendor).Error
	return vendor, err
}
