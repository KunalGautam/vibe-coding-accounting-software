package services

import (
	"context"
	"errors"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

type SeedService struct {
	db *gorm.DB
}

type IndiaSeedResult struct {
	AccountsCreated     int
	TaxRatesCreated     int
	TaxGroupsCreated    int
	TaxAuthorityCreated bool
}

type accountSeed struct {
	Code    string
	Name    string
	Type    domain.AccountType
	Subtype string
}

type gstRateSeed struct {
	Name            string
	PercentageBasis int64
}

func NewSeedService(db *gorm.DB) SeedService {
	return SeedService{db: db}
}

func (s SeedService) SeedIndiaDefaults(ctx context.Context, organizationID string) (IndiaSeedResult, error) {
	var result IndiaSeedResult

	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		accountsByCode := make(map[string]domain.Account)
		for _, seed := range indiaAccountSeeds() {
			account, created, err := findOrCreateAccount(ctx, tx, organizationID, seed)
			if err != nil {
				return err
			}
			if created {
				result.AccountsCreated++
			}
			accountsByCode[seed.Code] = account
		}

		authority, created, err := findOrCreateTaxAuthority(ctx, tx, organizationID)
		if err != nil {
			return err
		}
		result.TaxAuthorityCreated = created

		outputGST := accountsByCode["2100"]
		inputGST := accountsByCode["1400"]
		ratesByName := make(map[string]domain.TaxRate)
		for _, seed := range indiaGSTRateSeeds() {
			rate, created, err := findOrCreateTaxRate(ctx, tx, organizationID, authority.ID, outputGST.ID, inputGST.ID, seed)
			if err != nil {
				return err
			}
			if created {
				result.TaxRatesCreated++
			}
			ratesByName[seed.Name] = rate
		}

		for _, group := range indiaGSTGroupSeeds() {
			created, err := findOrCreateTaxGroup(ctx, tx, organizationID, group.name, group.description, group.rateNames, ratesByName)
			if err != nil {
				return err
			}
			if created {
				result.TaxGroupsCreated++
			}
		}

		return nil
	})

	return result, err
}

func indiaAccountSeeds() []accountSeed {
	return []accountSeed{
		{Code: "1000", Name: "Cash", Type: domain.AccountTypeAsset, Subtype: "cash"},
		{Code: "1010", Name: "Bank Account", Type: domain.AccountTypeAsset, Subtype: "bank"},
		{Code: "1100", Name: "Accounts Receivable", Type: domain.AccountTypeAsset, Subtype: "receivable"},
		{Code: "1400", Name: "Input GST Receivable", Type: domain.AccountTypeAsset, Subtype: "tax_receivable"},
		{Code: "2000", Name: "Accounts Payable", Type: domain.AccountTypeLiability, Subtype: "payable"},
		{Code: "2100", Name: "Output GST Payable", Type: domain.AccountTypeLiability, Subtype: "tax_payable"},
		{Code: "2200", Name: "Payroll Liabilities", Type: domain.AccountTypeLiability, Subtype: "payroll"},
		{Code: "3000", Name: "Owner Equity", Type: domain.AccountTypeEquity, Subtype: "equity"},
		{Code: "4000", Name: "Sales Revenue", Type: domain.AccountTypeIncome, Subtype: "sales"},
		{Code: "5000", Name: "Cost of Goods Sold", Type: domain.AccountTypeExpense, Subtype: "cogs"},
		{Code: "6000", Name: "Office Expenses", Type: domain.AccountTypeExpense, Subtype: "operating_expense"},
		{Code: "6100", Name: "Payroll Expense", Type: domain.AccountTypeExpense, Subtype: "payroll"},
	}
}

func indiaGSTRateSeeds() []gstRateSeed {
	return []gstRateSeed{
		{Name: "CGST 0%", PercentageBasis: 0},
		{Name: "SGST 0%", PercentageBasis: 0},
		{Name: "CGST 2.5%", PercentageBasis: 25000},
		{Name: "SGST 2.5%", PercentageBasis: 25000},
		{Name: "CGST 6%", PercentageBasis: 60000},
		{Name: "SGST 6%", PercentageBasis: 60000},
		{Name: "CGST 9%", PercentageBasis: 90000},
		{Name: "SGST 9%", PercentageBasis: 90000},
		{Name: "CGST 14%", PercentageBasis: 140000},
		{Name: "SGST 14%", PercentageBasis: 140000},
		{Name: "IGST 5%", PercentageBasis: 50000},
		{Name: "IGST 12%", PercentageBasis: 120000},
		{Name: "IGST 18%", PercentageBasis: 180000},
		{Name: "IGST 28%", PercentageBasis: 280000},
	}
}

func indiaGSTGroupSeeds() []struct {
	name        string
	description string
	rateNames   []string
} {
	return []struct {
		name        string
		description string
		rateNames   []string
	}{
		{name: "GST 0%", description: "Intra-state GST 0%", rateNames: []string{"CGST 0%", "SGST 0%"}},
		{name: "GST 5%", description: "Intra-state GST split as CGST 2.5% + SGST 2.5%", rateNames: []string{"CGST 2.5%", "SGST 2.5%"}},
		{name: "GST 12%", description: "Intra-state GST split as CGST 6% + SGST 6%", rateNames: []string{"CGST 6%", "SGST 6%"}},
		{name: "GST 18%", description: "Intra-state GST split as CGST 9% + SGST 9%", rateNames: []string{"CGST 9%", "SGST 9%"}},
		{name: "GST 28%", description: "Intra-state GST split as CGST 14% + SGST 14%", rateNames: []string{"CGST 14%", "SGST 14%"}},
	}
}

func findOrCreateAccount(ctx context.Context, tx *gorm.DB, organizationID string, seed accountSeed) (domain.Account, bool, error) {
	var account domain.Account
	err := tx.WithContext(ctx).
		Where("organization_id = ? AND code = ?", organizationID, seed.Code).
		First(&account).
		Error
	if err == nil {
		return account, false, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return domain.Account{}, false, err
	}

	account = domain.Account{
		OrganizationID: organizationID,
		Code:           seed.Code,
		Name:           seed.Name,
		Type:           seed.Type,
		Subtype:        seed.Subtype,
		Currency:       "INR",
		IsActive:       true,
	}
	return account, true, tx.WithContext(ctx).Create(&account).Error
}

func findOrCreateTaxAuthority(ctx context.Context, tx *gorm.DB, organizationID string) (domain.TaxAuthority, bool, error) {
	var authority domain.TaxAuthority
	err := tx.WithContext(ctx).
		Where("organization_id = ? AND name = ?", organizationID, "Goods and Services Tax Network").
		First(&authority).
		Error
	if err == nil {
		return authority, false, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return domain.TaxAuthority{}, false, err
	}

	authority = domain.TaxAuthority{
		OrganizationID: organizationID,
		Name:           "Goods and Services Tax Network",
		CountryCode:    "IN",
		IsActive:       true,
	}
	return authority, true, tx.WithContext(ctx).Create(&authority).Error
}

func findOrCreateTaxRate(ctx context.Context, tx *gorm.DB, organizationID string, authorityID string, outputAccountID string, inputAccountID string, seed gstRateSeed) (domain.TaxRate, bool, error) {
	var rate domain.TaxRate
	err := tx.WithContext(ctx).
		Where("organization_id = ? AND name = ?", organizationID, seed.Name).
		First(&rate).
		Error
	if err == nil {
		return rate, false, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return domain.TaxRate{}, false, err
	}

	effectiveFrom := time.Date(2017, 7, 1, 0, 0, 0, 0, time.UTC)
	rate = domain.TaxRate{
		OrganizationID:  organizationID,
		TaxAuthorityID:  authorityID,
		Name:            seed.Name,
		PercentageBasis: seed.PercentageBasis,
		Type:            domain.TaxTypeGST,
		OutputAccountID: &outputAccountID,
		InputAccountID:  &inputAccountID,
		EffectiveFrom:   effectiveFrom,
		IsCompound:      false,
		IsActive:        true,
	}
	return rate, true, tx.WithContext(ctx).Create(&rate).Error
}

func findOrCreateTaxGroup(ctx context.Context, tx *gorm.DB, organizationID string, name string, description string, rateNames []string, ratesByName map[string]domain.TaxRate) (bool, error) {
	var group domain.TaxGroup
	err := tx.WithContext(ctx).
		Where("organization_id = ? AND name = ?", organizationID, name).
		First(&group).
		Error
	if err == nil {
		return false, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return false, err
	}

	group = domain.TaxGroup{
		OrganizationID: organizationID,
		Name:           name,
		Description:    description,
		IsActive:       true,
	}
	if err := tx.WithContext(ctx).Create(&group).Error; err != nil {
		return false, err
	}

	for index, rateName := range rateNames {
		rate := ratesByName[rateName]
		component := domain.TaxGroupComponent{
			OrganizationID: organizationID,
			TaxGroupID:     group.ID,
			TaxRateID:      rate.ID,
			SortOrder:      index + 1,
		}
		if err := tx.WithContext(ctx).Create(&component).Error; err != nil {
			return false, err
		}
	}

	return true, nil
}
