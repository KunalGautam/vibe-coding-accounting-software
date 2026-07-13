package services

import (
	"context"
	"errors"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

var (
	ErrTaxGroupHasNoRates           = errors.New("tax group must contain at least one tax rate")
	ErrTaxCalculationTargetMissing  = errors.New("tax calculation requires either tax_rate_id or tax_group_id")
	ErrTaxCalculationTargetConflict = errors.New("tax calculation accepts only one of tax_rate_id or tax_group_id")
)

type TaxService struct {
	db *gorm.DB
}

type CreateTaxAuthorityInput struct {
	OrganizationID string
	Name           string
	CountryCode    string
	RegionCode     string
}

type CreateTaxRateInput struct {
	OrganizationID  string
	TaxAuthorityID  string
	Name            string
	PercentageBasis int64
	Type            domain.TaxType
	OutputAccountID *string
	InputAccountID  *string
	EffectiveFrom   time.Time
	EffectiveTo     *time.Time
	IsCompound      bool
}

type CreateTaxGroupInput struct {
	OrganizationID string
	Name           string
	Description    string
	TaxRateIDs     []string
}

type CalculateTaxInput struct {
	OrganizationID  string
	BaseAmountMinor int64
	TaxInclusive    bool
	TaxRateID       *string
	TaxGroupID      *string
}

type CalculateTaxResult struct {
	BaseAmountMinor  int64                     `json:"base_amount_minor"`
	TaxAmountMinor   int64                     `json:"tax_amount_minor"`
	TotalAmountMinor int64                     `json:"total_amount_minor"`
	Components       []TaxCalculationComponent `json:"components"`
}

type TaxCalculationComponent struct {
	TaxRateID       string `json:"tax_rate_id"`
	Name            string `json:"name"`
	PercentageBasis int64  `json:"percentage_basis"`
	TaxAmountMinor  int64  `json:"tax_amount_minor"`
}

func NewTaxService(db *gorm.DB) TaxService {
	return TaxService{db: db}
}

func (s TaxService) ListAuthorities(ctx context.Context, organizationID string) ([]domain.TaxAuthority, error) {
	var authorities []domain.TaxAuthority
	err := s.db.WithContext(ctx).
		Where("organization_id = ?", organizationID).
		Order("name ASC").
		Find(&authorities).
		Error
	return authorities, err
}

func (s TaxService) CreateAuthority(ctx context.Context, input CreateTaxAuthorityInput) (domain.TaxAuthority, error) {
	countryCode := input.CountryCode
	if countryCode == "" {
		countryCode = "IN"
	}

	authority := domain.TaxAuthority{
		OrganizationID: input.OrganizationID,
		Name:           input.Name,
		CountryCode:    countryCode,
		RegionCode:     input.RegionCode,
		IsActive:       true,
	}
	err := s.db.WithContext(ctx).Create(&authority).Error
	return authority, err
}

func (s TaxService) ListRates(ctx context.Context, organizationID string) ([]domain.TaxRate, error) {
	var rates []domain.TaxRate
	err := s.db.WithContext(ctx).
		Where("organization_id = ?", organizationID).
		Order("name ASC").
		Find(&rates).
		Error
	return rates, err
}

func (s TaxService) CreateRate(ctx context.Context, input CreateTaxRateInput) (domain.TaxRate, error) {
	taxType := input.Type
	if taxType == "" {
		taxType = domain.TaxTypeGST
	}

	rate := domain.TaxRate{
		OrganizationID:  input.OrganizationID,
		TaxAuthorityID:  input.TaxAuthorityID,
		Name:            input.Name,
		PercentageBasis: input.PercentageBasis,
		Type:            taxType,
		OutputAccountID: input.OutputAccountID,
		InputAccountID:  input.InputAccountID,
		EffectiveFrom:   input.EffectiveFrom,
		EffectiveTo:     input.EffectiveTo,
		IsCompound:      input.IsCompound,
		IsActive:        true,
	}
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := validateTaxRateScope(ctx, tx, input); err != nil {
			return err
		}
		return tx.Create(&rate).Error
	})
	return rate, err
}

func (s TaxService) ListGroups(ctx context.Context, organizationID string) ([]domain.TaxGroup, error) {
	var groups []domain.TaxGroup
	err := s.db.WithContext(ctx).
		Preload("Components.TaxRate").
		Where("organization_id = ?", organizationID).
		Order("name ASC").
		Find(&groups).
		Error
	return groups, err
}

func (s TaxService) CreateGroup(ctx context.Context, input CreateTaxGroupInput) (domain.TaxGroup, error) {
	if len(input.TaxRateIDs) == 0 {
		return domain.TaxGroup{}, ErrTaxGroupHasNoRates
	}

	var group domain.TaxGroup
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := validateTaxRateIDsScope(ctx, tx, input.OrganizationID, input.TaxRateIDs); err != nil {
			return err
		}

		group = domain.TaxGroup{
			OrganizationID: input.OrganizationID,
			Name:           input.Name,
			Description:    input.Description,
			IsActive:       true,
		}
		if err := tx.Create(&group).Error; err != nil {
			return err
		}

		for index, taxRateID := range input.TaxRateIDs {
			component := domain.TaxGroupComponent{
				OrganizationID: input.OrganizationID,
				TaxGroupID:     group.ID,
				TaxRateID:      taxRateID,
				SortOrder:      index + 1,
			}
			if err := tx.Create(&component).Error; err != nil {
				return err
			}
		}
		return tx.Preload("Components.TaxRate").First(&group, "id = ?", group.ID).Error
	})
	return group, err
}

func validateTaxRateScope(ctx context.Context, tx *gorm.DB, input CreateTaxRateInput) error {
	var authorityCount int64
	if err := tx.WithContext(ctx).
		Model(&domain.TaxAuthority{}).
		Where("organization_id = ? AND id = ?", input.OrganizationID, input.TaxAuthorityID).
		Count(&authorityCount).
		Error; err != nil {
		return err
	}
	if authorityCount != 1 {
		return domain.ErrTenantScope
	}

	accountIDs := make([]string, 0, 2)
	if input.OutputAccountID != nil {
		accountIDs = append(accountIDs, *input.OutputAccountID)
	}
	if input.InputAccountID != nil {
		accountIDs = append(accountIDs, *input.InputAccountID)
	}
	if len(accountIDs) == 0 {
		return nil
	}

	var accountCount int64
	if err := tx.WithContext(ctx).
		Model(&domain.Account{}).
		Where("organization_id = ? AND id IN ?", input.OrganizationID, accountIDs).
		Count(&accountCount).
		Error; err != nil {
		return err
	}
	if accountCount != int64(len(accountIDs)) {
		return domain.ErrTenantScope
	}
	return nil
}

func validateTaxRateIDsScope(ctx context.Context, tx *gorm.DB, organizationID string, taxRateIDs []string) error {
	uniqueIDs := make(map[string]struct{}, len(taxRateIDs))
	for _, taxRateID := range taxRateIDs {
		uniqueIDs[taxRateID] = struct{}{}
	}

	ids := make([]string, 0, len(uniqueIDs))
	for taxRateID := range uniqueIDs {
		ids = append(ids, taxRateID)
	}

	var count int64
	if err := tx.WithContext(ctx).
		Model(&domain.TaxRate{}).
		Where("organization_id = ? AND id IN ?", organizationID, ids).
		Count(&count).
		Error; err != nil {
		return err
	}
	if count != int64(len(ids)) {
		return domain.ErrTenantScope
	}
	return nil
}

func (s TaxService) Calculate(ctx context.Context, input CalculateTaxInput) (CalculateTaxResult, error) {
	if input.TaxRateID == nil && input.TaxGroupID == nil {
		return CalculateTaxResult{}, ErrTaxCalculationTargetMissing
	}
	if input.TaxRateID != nil && input.TaxGroupID != nil {
		return CalculateTaxResult{}, ErrTaxCalculationTargetConflict
	}

	rates, err := s.resolveCalculationRates(ctx, input)
	if err != nil {
		return CalculateTaxResult{}, err
	}

	totalBasis := int64(0)
	for _, rate := range rates {
		totalBasis += rate.PercentageBasis
	}

	baseAmount := input.BaseAmountMinor
	if input.TaxInclusive && totalBasis > 0 {
		baseAmount = roundDiv(input.BaseAmountMinor*1000000, 1000000+totalBasis)
	}

	result := CalculateTaxResult{
		BaseAmountMinor: baseAmount,
		Components:      make([]TaxCalculationComponent, 0, len(rates)),
	}

	for _, rate := range rates {
		taxAmount := roundDiv(baseAmount*rate.PercentageBasis, 1000000)
		result.TaxAmountMinor += taxAmount
		result.Components = append(result.Components, TaxCalculationComponent{
			TaxRateID:       rate.ID,
			Name:            rate.Name,
			PercentageBasis: rate.PercentageBasis,
			TaxAmountMinor:  taxAmount,
		})
	}

	if input.TaxInclusive {
		result.TotalAmountMinor = input.BaseAmountMinor
	} else {
		result.TotalAmountMinor = result.BaseAmountMinor + result.TaxAmountMinor
	}
	return result, nil
}

func (s TaxService) resolveCalculationRates(ctx context.Context, input CalculateTaxInput) ([]domain.TaxRate, error) {
	if input.TaxRateID != nil {
		var rate domain.TaxRate
		err := s.db.WithContext(ctx).
			Where("organization_id = ? AND id = ? AND is_active = ?", input.OrganizationID, *input.TaxRateID, true).
			First(&rate).
			Error
		if err != nil {
			return nil, err
		}
		return []domain.TaxRate{rate}, nil
	}

	var group domain.TaxGroup
	err := s.db.WithContext(ctx).
		Preload("Components.TaxRate").
		Where("organization_id = ? AND id = ? AND is_active = ?", input.OrganizationID, *input.TaxGroupID, true).
		First(&group).
		Error
	if err != nil {
		return nil, err
	}

	rates := make([]domain.TaxRate, 0, len(group.Components))
	for _, component := range group.Components {
		if component.TaxRate.IsActive {
			rates = append(rates, component.TaxRate)
		}
	}
	if len(rates) == 0 {
		return nil, ErrTaxGroupHasNoRates
	}
	return rates, nil
}

func roundDiv(numerator int64, denominator int64) int64 {
	if numerator >= 0 {
		return (numerator + denominator/2) / denominator
	}
	return (numerator - denominator/2) / denominator
}
