package services

import (
	"context"
	"errors"

	"accounting.abhashtech.com/internal/domain"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

var (
	ErrBootstrapAlreadyCompleted = errors.New("bootstrap has already been completed")
	ErrRegistrationEmailExists   = errors.New("a user with this email already exists")
)

type BootstrapService struct {
	db *gorm.DB
}

type BootstrapInput struct {
	OrganizationName string
	AdminName        string
	AdminEmail       string
	AdminPassword    string
	BaseCurrency     string
	CountryCode      string
}

type BootstrapResult struct {
	Organization domain.Organization
	User         domain.User
	Membership   domain.OrganizationMembership
}

func NewBootstrapService(db *gorm.DB) BootstrapService {
	return BootstrapService{db: db}
}

func (s BootstrapService) IsAllowed(ctx context.Context) (bool, error) {
	var count int64
	err := s.db.WithContext(ctx).Model(&domain.User{}).Count(&count).Error
	return count == 0, err
}

func (s BootstrapService) CreateFirstAdmin(ctx context.Context, input BootstrapInput) (BootstrapResult, error) {
	allowed, err := s.IsAllowed(ctx)
	if err != nil {
		return BootstrapResult{}, err
	}
	if !allowed {
		return BootstrapResult{}, ErrBootstrapAlreadyCompleted
	}

	baseCurrency := input.BaseCurrency
	if baseCurrency == "" {
		baseCurrency = "INR"
	}
	countryCode := input.CountryCode
	if countryCode == "" {
		countryCode = "IN"
	}

	passwordHash, err := bcrypt.GenerateFromPassword([]byte(input.AdminPassword), bcrypt.DefaultCost)
	if err != nil {
		return BootstrapResult{}, err
	}

	var result BootstrapResult
	err = s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		organization := domain.Organization{
			Name:                 input.OrganizationName,
			BaseCurrency:         baseCurrency,
			CountryCode:          countryCode,
			FiscalYearStartMonth: 4,
		}
		if err := tx.Create(&organization).Error; err != nil {
			return err
		}

		user := domain.User{
			Email:        input.AdminEmail,
			Name:         input.AdminName,
			PasswordHash: string(passwordHash),
			IsActive:     true,
		}
		if err := tx.Create(&user).Error; err != nil {
			return err
		}

		membership := domain.OrganizationMembership{
			OrganizationID: organization.ID,
			UserID:         user.ID,
			Role:           domain.RoleAdmin,
		}
		if err := tx.Create(&membership).Error; err != nil {
			return err
		}

		result = BootstrapResult{
			Organization: organization,
			User:         user,
			Membership:   membership,
		}
		return nil
	})
	return result, err
}

func (s BootstrapService) RegisterOrganization(ctx context.Context, input BootstrapInput) (BootstrapResult, error) {
	baseCurrency := input.BaseCurrency
	if baseCurrency == "" {
		baseCurrency = "INR"
	}
	countryCode := input.CountryCode
	if countryCode == "" {
		countryCode = "IN"
	}

	passwordHash, err := bcrypt.GenerateFromPassword([]byte(input.AdminPassword), bcrypt.DefaultCost)
	if err != nil {
		return BootstrapResult{}, err
	}

	var result BootstrapResult
	err = s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var existing int64
		if err := tx.Model(&domain.User{}).Where("email = ?", input.AdminEmail).Count(&existing).Error; err != nil {
			return err
		}
		if existing > 0 {
			return ErrRegistrationEmailExists
		}

		organization := domain.Organization{
			Name:                 input.OrganizationName,
			BaseCurrency:         baseCurrency,
			CountryCode:          countryCode,
			FiscalYearStartMonth: 4,
		}
		if err := tx.Create(&organization).Error; err != nil {
			return err
		}

		user := domain.User{
			Email:        input.AdminEmail,
			Name:         input.AdminName,
			PasswordHash: string(passwordHash),
			IsActive:     true,
		}
		if err := tx.Create(&user).Error; err != nil {
			return err
		}

		membership := domain.OrganizationMembership{
			OrganizationID: organization.ID,
			UserID:         user.ID,
			Role:           domain.RoleAdmin,
		}
		if err := tx.Create(&membership).Error; err != nil {
			return err
		}

		result = BootstrapResult{
			Organization: organization,
			User:         user,
			Membership:   membership,
		}
		return nil
	})
	return result, err
}
