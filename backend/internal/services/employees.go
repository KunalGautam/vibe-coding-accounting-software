package services

import (
	"context"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

type EmployeeService struct {
	db *gorm.DB
}

type CreateEmployeeInput struct {
	OrganizationID string
	DisplayName    string
	Email          string
	Phone          string
	EmployeeCode   string
	PAN            string
	UAN            string
}

func NewEmployeeService(db *gorm.DB) EmployeeService {
	return EmployeeService{db: db}
}

func (s EmployeeService) List(ctx context.Context, organizationID string) ([]domain.Employee, error) {
	var employees []domain.Employee
	err := s.db.WithContext(ctx).
		Where("organization_id = ? AND is_active = ?", organizationID, true).
		Order("display_name ASC").
		Find(&employees).
		Error
	return employees, err
}

func (s EmployeeService) Create(ctx context.Context, input CreateEmployeeInput) (domain.Employee, error) {
	employee := domain.Employee{
		OrganizationID: input.OrganizationID,
		DisplayName:    input.DisplayName,
		Email:          input.Email,
		Phone:          input.Phone,
		EmployeeCode:   input.EmployeeCode,
		PAN:            input.PAN,
		UAN:            input.UAN,
		IsActive:       true,
	}
	err := s.db.WithContext(ctx).Create(&employee).Error
	return employee, err
}
