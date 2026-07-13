package services

import (
	"context"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

type AccountService struct {
	db *gorm.DB
}

type CreateAccountInput struct {
	OrganizationID string
	ParentID       *string
	Code           string
	Name           string
	Type           domain.AccountType
	Subtype        string
	Currency       string
	IsPlaceholder  bool
}

func NewAccountService(db *gorm.DB) AccountService {
	return AccountService{db: db}
}

func (s AccountService) List(ctx context.Context, organizationID string) ([]domain.Account, error) {
	var accounts []domain.Account
	err := s.db.WithContext(ctx).
		Where("organization_id = ?", organizationID).
		Order("code ASC").
		Find(&accounts).
		Error
	return accounts, err
}

func (s AccountService) Create(ctx context.Context, input CreateAccountInput) (domain.Account, error) {
	currency := input.Currency
	if currency == "" {
		currency = "INR"
	}

	account := domain.Account{
		OrganizationID: input.OrganizationID,
		ParentID:       input.ParentID,
		Code:           input.Code,
		Name:           input.Name,
		Type:           input.Type,
		Subtype:        input.Subtype,
		Currency:       currency,
		IsPlaceholder:  input.IsPlaceholder,
		IsActive:       true,
	}

	err := s.db.WithContext(ctx).Create(&account).Error
	return account, err
}
