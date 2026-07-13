package services

import (
	"context"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

type CustomerService struct {
	db *gorm.DB
}

type CreateCustomerInput struct {
	OrganizationID string
	DisplayName    string
	Email          string
	Phone          string
	BillingAddress string
	GSTIN          string
}

func NewCustomerService(db *gorm.DB) CustomerService {
	return CustomerService{db: db}
}

func (s CustomerService) List(ctx context.Context, organizationID string) ([]domain.Customer, error) {
	var customers []domain.Customer
	err := s.db.WithContext(ctx).
		Where("organization_id = ? AND is_active = ?", organizationID, true).
		Order("display_name ASC").
		Find(&customers).
		Error
	return customers, err
}

func (s CustomerService) Create(ctx context.Context, input CreateCustomerInput) (domain.Customer, error) {
	customer := domain.Customer{
		OrganizationID: input.OrganizationID,
		DisplayName:    input.DisplayName,
		Email:          input.Email,
		Phone:          input.Phone,
		BillingAddress: input.BillingAddress,
		GSTIN:          input.GSTIN,
		IsActive:       true,
	}
	err := s.db.WithContext(ctx).Create(&customer).Error
	return customer, err
}
