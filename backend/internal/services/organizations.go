package services

import (
	"context"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

type OrganizationService struct {
	db *gorm.DB
}

type CreateOrganizationInput struct {
	Name         string
	BaseCurrency string
	CountryCode  string
}

func NewOrganizationService(db *gorm.DB) OrganizationService {
	return OrganizationService{db: db}
}

func (s OrganizationService) List(ctx context.Context) ([]domain.Organization, error) {
	var organizations []domain.Organization
	err := s.db.WithContext(ctx).
		Order("name ASC").
		Find(&organizations).
		Error
	return organizations, err
}

func (s OrganizationService) Create(ctx context.Context, input CreateOrganizationInput) (domain.Organization, error) {
	baseCurrency := input.BaseCurrency
	if baseCurrency == "" {
		baseCurrency = "INR"
	}

	countryCode := input.CountryCode
	if countryCode == "" {
		countryCode = "IN"
	}

	organization := domain.Organization{
		Name:                 input.Name,
		BaseCurrency:         baseCurrency,
		CountryCode:          countryCode,
		FiscalYearStartMonth: 4,
	}

	err := s.db.WithContext(ctx).Create(&organization).Error
	return organization, err
}
