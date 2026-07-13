package services

import (
	"context"
	"errors"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

var (
	ErrPayrollRunHasNoItems = errors.New("payroll run must contain at least one item")
	ErrPayrollAlreadyPosted = errors.New("payroll run has already been posted")
	ErrPayrollAccountScope  = errors.New("payroll accounts must belong to the organization")
	ErrPayrollEmployeeScope = errors.New("payroll employees must belong to the organization")
	ErrPayrollComponentType = errors.New("payroll component type must be earning or deduction")
	ErrPayrollComponentSum  = errors.New("payroll component totals must match gross pay and deductions")
	ErrPayrollItemScope     = errors.New("payroll item must belong to the payroll run and organization")
)

type PayrollService struct {
	db *gorm.DB
}

type CreatePayrollRunInput struct {
	OrganizationID              string
	RunNumber                   string
	PeriodStart                 time.Time
	PeriodEnd                   time.Time
	PayDate                     time.Time
	Currency                    string
	PayrollExpenseAccountID     string
	PayrollLiabilityAccountID   string
	DeductionLiabilityAccountID string
	Items                       []CreatePayrollItemInput
}

type CreatePayrollItemInput struct {
	EmployeeID      string
	GrossPayMinor   int64
	DeductionsMinor int64
	PayslipKey      string
	Components      []CreatePayrollComponentInput
}

type CreatePayrollComponentInput struct {
	Code        string
	Name        string
	Type        domain.PayrollComponentType
	AmountMinor int64
	IsStatutory bool
}

type IndiaPayrollPreviewInput struct {
	BasicMinor           int64
	HRAMinor             int64
	SpecialMinor         int64
	BonusMinor           int64
	ReimbursementMinor   int64
	EmployeePFEnabled    bool
	EmployeePFRateBps    int64
	PFWageCeilingMinor   int64
	EmployeeESIEnabled   bool
	EmployeeESIRateBps   int64
	ESIGrossLimitMinor   int64
	ProfessionalTaxMinor int64
	TDSMinor             int64
}

type IndiaPayrollPreview struct {
	GrossPayMinor   int64                         `json:"gross_pay_minor"`
	DeductionsMinor int64                         `json:"deductions_minor"`
	NetPayMinor     int64                         `json:"net_pay_minor"`
	Components      []CreatePayrollComponentInput `json:"components"`
	RuleSummary     IndiaPayrollRuleSummary       `json:"rule_summary"`
}

type IndiaPayrollRuleSummary struct {
	EmployeePFEnabled    bool  `json:"employee_pf_enabled"`
	EmployeePFRateBps    int64 `json:"employee_pf_rate_bps"`
	PFWageCeilingMinor   int64 `json:"pf_wage_ceiling_minor"`
	EmployeeESIEnabled   bool  `json:"employee_esi_enabled"`
	EmployeeESIRateBps   int64 `json:"employee_esi_rate_bps"`
	ESIGrossLimitMinor   int64 `json:"esi_gross_limit_minor"`
	ProfessionalTaxMinor int64 `json:"professional_tax_minor"`
	TDSMinor             int64 `json:"tds_minor"`
}

type PayslipPreview struct {
	OrganizationID  string                    `json:"organization_id"`
	PayrollRunID    string                    `json:"payroll_run_id"`
	PayrollItemID   string                    `json:"payroll_item_id"`
	RunNumber       string                    `json:"run_number"`
	PeriodStart     time.Time                 `json:"period_start"`
	PeriodEnd       time.Time                 `json:"period_end"`
	PayDate         time.Time                 `json:"pay_date"`
	Status          domain.PayrollRunStatus   `json:"status"`
	Currency        string                    `json:"currency"`
	Employee        domain.Employee           `json:"employee"`
	GrossPayMinor   int64                     `json:"gross_pay_minor"`
	DeductionsMinor int64                     `json:"deductions_minor"`
	NetPayMinor     int64                     `json:"net_pay_minor"`
	PayslipKey      string                    `json:"payslip_key"`
	Earnings        []domain.PayrollComponent `json:"earnings"`
	Deductions      []domain.PayrollComponent `json:"deductions"`
	Components      []domain.PayrollComponent `json:"components"`
}

func NewPayrollService(db *gorm.DB) PayrollService {
	return PayrollService{db: db}
}

func (s PayrollService) PreviewIndiaPayroll(input IndiaPayrollPreviewInput) IndiaPayrollPreview {
	input = withIndiaPayrollDefaults(input)
	components := make([]CreatePayrollComponentInput, 0, 8)
	addComponent := func(code string, name string, componentType domain.PayrollComponentType, amount int64, statutory bool) {
		if amount <= 0 {
			return
		}
		components = append(components, CreatePayrollComponentInput{
			Code:        code,
			Name:        name,
			Type:        componentType,
			AmountMinor: amount,
			IsStatutory: statutory,
		})
	}

	addComponent("BASIC", "Basic Pay", domain.PayrollComponentEarning, input.BasicMinor, false)
	addComponent("HRA", "House Rent Allowance", domain.PayrollComponentEarning, input.HRAMinor, false)
	addComponent("SPECIAL", "Special Allowance", domain.PayrollComponentEarning, input.SpecialMinor, false)
	addComponent("BONUS", "Bonus", domain.PayrollComponentEarning, input.BonusMinor, false)
	addComponent("REIMB", "Reimbursement", domain.PayrollComponentEarning, input.ReimbursementMinor, false)

	grossPay := input.BasicMinor + input.HRAMinor + input.SpecialMinor + input.BonusMinor + input.ReimbursementMinor
	var deductions int64

	if input.EmployeePFEnabled {
		pfBase := input.BasicMinor
		if input.PFWageCeilingMinor > 0 && pfBase > input.PFWageCeilingMinor {
			pfBase = input.PFWageCeilingMinor
		}
		pf := percentageMinor(pfBase, input.EmployeePFRateBps)
		deductions += pf
		addComponent("PF", "Employee Provident Fund", domain.PayrollComponentDeduction, pf, true)
	}

	if input.EmployeeESIEnabled && input.ESIGrossLimitMinor > 0 && grossPay <= input.ESIGrossLimitMinor {
		esi := percentageMinor(grossPay, input.EmployeeESIRateBps)
		deductions += esi
		addComponent("ESI", "Employee State Insurance", domain.PayrollComponentDeduction, esi, true)
	}

	deductions += input.ProfessionalTaxMinor
	addComponent("PT", "Professional Tax", domain.PayrollComponentDeduction, input.ProfessionalTaxMinor, true)
	deductions += input.TDSMinor
	addComponent("TDS", "Tax Deducted at Source", domain.PayrollComponentDeduction, input.TDSMinor, true)

	return IndiaPayrollPreview{
		GrossPayMinor:   grossPay,
		DeductionsMinor: deductions,
		NetPayMinor:     grossPay - deductions,
		Components:      components,
		RuleSummary: IndiaPayrollRuleSummary{
			EmployeePFEnabled:    input.EmployeePFEnabled,
			EmployeePFRateBps:    input.EmployeePFRateBps,
			PFWageCeilingMinor:   input.PFWageCeilingMinor,
			EmployeeESIEnabled:   input.EmployeeESIEnabled,
			EmployeeESIRateBps:   input.EmployeeESIRateBps,
			ESIGrossLimitMinor:   input.ESIGrossLimitMinor,
			ProfessionalTaxMinor: input.ProfessionalTaxMinor,
			TDSMinor:             input.TDSMinor,
		},
	}
}

func withIndiaPayrollDefaults(input IndiaPayrollPreviewInput) IndiaPayrollPreviewInput {
	if input.EmployeePFRateBps == 0 {
		input.EmployeePFRateBps = 1200
	}
	if input.PFWageCeilingMinor == 0 {
		input.PFWageCeilingMinor = 1500000
	}
	if input.EmployeeESIRateBps == 0 {
		input.EmployeeESIRateBps = 75
	}
	if input.ESIGrossLimitMinor == 0 {
		input.ESIGrossLimitMinor = 2100000
	}
	return input
}

func percentageMinor(amountMinor int64, basisPoints int64) int64 {
	if amountMinor <= 0 || basisPoints <= 0 {
		return 0
	}
	return (amountMinor*basisPoints + 5000) / 10000
}

func (s PayrollService) ListRuns(ctx context.Context, organizationID string) ([]domain.PayrollRun, error) {
	var runs []domain.PayrollRun
	err := s.db.WithContext(ctx).
		Preload("Items.Employee").
		Preload("Items.Components").
		Where("organization_id = ?", organizationID).
		Order("pay_date DESC, created_at DESC").
		Find(&runs).
		Error
	return runs, err
}

func (s PayrollService) PayslipPreview(ctx context.Context, organizationID string, payrollRunID string, payrollItemID string) (PayslipPreview, error) {
	var run domain.PayrollRun
	if err := s.db.WithContext(ctx).
		Preload("Items.Employee").
		Preload("Items.Components").
		Where("organization_id = ? AND id = ?", organizationID, payrollRunID).
		First(&run).Error; err != nil {
		return PayslipPreview{}, err
	}

	for _, item := range run.Items {
		if item.ID != payrollItemID || item.OrganizationID != organizationID {
			continue
		}
		earnings := make([]domain.PayrollComponent, 0)
		deductions := make([]domain.PayrollComponent, 0)
		for _, component := range item.Components {
			if component.Type == domain.PayrollComponentEarning {
				earnings = append(earnings, component)
			}
			if component.Type == domain.PayrollComponentDeduction {
				deductions = append(deductions, component)
			}
		}
		return PayslipPreview{
			OrganizationID:  run.OrganizationID,
			PayrollRunID:    run.ID,
			PayrollItemID:   item.ID,
			RunNumber:       run.RunNumber,
			PeriodStart:     run.PeriodStart,
			PeriodEnd:       run.PeriodEnd,
			PayDate:         run.PayDate,
			Status:          run.Status,
			Currency:        run.Currency,
			Employee:        item.Employee,
			GrossPayMinor:   item.GrossPayMinor,
			DeductionsMinor: item.DeductionsMinor,
			NetPayMinor:     item.NetPayMinor,
			PayslipKey:      item.PayslipKey,
			Earnings:        earnings,
			Deductions:      deductions,
			Components:      item.Components,
		}, nil
	}

	return PayslipPreview{}, ErrPayrollItemScope
}

func (s PayrollService) CreateRun(ctx context.Context, input CreatePayrollRunInput) (domain.PayrollRun, error) {
	if len(input.Items) == 0 {
		return domain.PayrollRun{}, ErrPayrollRunHasNoItems
	}

	currency := input.Currency
	if currency == "" {
		currency = "INR"
	}

	run := domain.PayrollRun{
		OrganizationID:              input.OrganizationID,
		RunNumber:                   input.RunNumber,
		PeriodStart:                 input.PeriodStart,
		PeriodEnd:                   input.PeriodEnd,
		PayDate:                     input.PayDate,
		Status:                      domain.PayrollRunStatusDraft,
		Currency:                    currency,
		PayrollExpenseAccountID:     input.PayrollExpenseAccountID,
		PayrollLiabilityAccountID:   input.PayrollLiabilityAccountID,
		DeductionLiabilityAccountID: input.DeductionLiabilityAccountID,
		Items:                       make([]domain.PayrollItem, 0, len(input.Items)),
	}

	for _, itemInput := range input.Items {
		item, err := buildPayrollItem(input.OrganizationID, itemInput)
		if err != nil {
			return domain.PayrollRun{}, err
		}
		run.GrossPayMinor += item.GrossPayMinor
		run.DeductionsMinor += item.DeductionsMinor
		run.NetPayMinor += item.NetPayMinor
		run.Items = append(run.Items, item)
	}

	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := validatePayrollScope(ctx, tx, input.OrganizationID, run); err != nil {
			return err
		}
		return tx.Create(&run).Error
	})
	return run, err
}

func buildPayrollItem(organizationID string, input CreatePayrollItemInput) (domain.PayrollItem, error) {
	grossPay := input.GrossPayMinor
	deductions := input.DeductionsMinor
	components := make([]domain.PayrollComponent, 0, len(input.Components))
	var componentGross int64
	var componentDeductions int64
	for _, componentInput := range input.Components {
		if componentInput.Type != domain.PayrollComponentEarning && componentInput.Type != domain.PayrollComponentDeduction {
			return domain.PayrollItem{}, ErrPayrollComponentType
		}
		component := domain.PayrollComponent{
			OrganizationID: organizationID,
			Code:           componentInput.Code,
			Name:           componentInput.Name,
			Type:           componentInput.Type,
			AmountMinor:    componentInput.AmountMinor,
			IsStatutory:    componentInput.IsStatutory,
		}
		if component.Type == domain.PayrollComponentEarning {
			componentGross += component.AmountMinor
		} else {
			componentDeductions += component.AmountMinor
		}
		components = append(components, component)
	}
	if len(components) > 0 {
		if grossPay == 0 {
			grossPay = componentGross
		}
		if deductions == 0 {
			deductions = componentDeductions
		}
		if grossPay != componentGross || deductions != componentDeductions {
			return domain.PayrollItem{}, ErrPayrollComponentSum
		}
	}

	netPay := grossPay - deductions
	return domain.PayrollItem{
		OrganizationID:  organizationID,
		EmployeeID:      input.EmployeeID,
		GrossPayMinor:   grossPay,
		DeductionsMinor: deductions,
		NetPayMinor:     netPay,
		PayslipKey:      input.PayslipKey,
		Components:      components,
	}, nil
}

func (s PayrollService) PostRun(ctx context.Context, organizationID string, payrollRunID string) (domain.PayrollRun, error) {
	var run domain.PayrollRun
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("organization_id = ? AND id = ?", organizationID, payrollRunID).First(&run).Error; err != nil {
			return err
		}
		if run.Status != domain.PayrollRunStatusDraft {
			return ErrPayrollAlreadyPosted
		}

		splits := []domain.LedgerSplit{
			{
				OrganizationID: run.OrganizationID,
				AccountID:      run.PayrollExpenseAccountID,
				DebitMinor:     run.GrossPayMinor,
				Currency:       run.Currency,
			},
			{
				OrganizationID: run.OrganizationID,
				AccountID:      run.PayrollLiabilityAccountID,
				CreditMinor:    run.NetPayMinor,
				Currency:       run.Currency,
			},
		}
		if run.DeductionsMinor > 0 {
			splits = append(splits, domain.LedgerSplit{
				OrganizationID: run.OrganizationID,
				AccountID:      run.DeductionLiabilityAccountID,
				CreditMinor:    run.DeductionsMinor,
				Currency:       run.Currency,
			})
		}

		now := time.Now().UTC()
		transaction := domain.JournalTransaction{
			OrganizationID:  run.OrganizationID,
			TransactionDate: run.PayDate,
			Memo:            "Payroll " + run.RunNumber,
			SourceModule:    domain.SourceModulePayroll,
			Status:          domain.JournalStatusPosted,
			PostedAt:        &now,
			Splits:          splits,
		}
		if err := transaction.ValidateBalanced(); err != nil {
			return err
		}
		if err := validateSplitAccounts(ctx, tx, run.OrganizationID, transaction.Splits); err != nil {
			return err
		}
		if err := tx.Create(&transaction).Error; err != nil {
			return err
		}
		if err := tx.Model(&run).Updates(map[string]any{
			"status":                 domain.PayrollRunStatusPosted,
			"journal_transaction_id": transaction.ID,
		}).Error; err != nil {
			return err
		}
		run.Status = domain.PayrollRunStatusPosted
		run.JournalTransactionID = &transaction.ID
		if err := recordAuditWithTx(ctx, tx, RecordAuditInput{
			OrganizationID: run.OrganizationID,
			EntityType:     "payroll_run",
			EntityID:       run.ID,
			Action:         "post",
			After:          run,
		}); err != nil {
			return err
		}
		return nil
	})
	return run, err
}

func validatePayrollScope(ctx context.Context, tx *gorm.DB, organizationID string, run domain.PayrollRun) error {
	accountIDs := []string{run.PayrollExpenseAccountID, run.PayrollLiabilityAccountID, run.DeductionLiabilityAccountID}
	var accountCount int64
	if err := tx.WithContext(ctx).Model(&domain.Account{}).Where("organization_id = ? AND id IN ?", organizationID, accountIDs).Count(&accountCount).Error; err != nil {
		return err
	}
	if accountCount != int64(len(uniqueStrings(accountIDs))) {
		return ErrPayrollAccountScope
	}

	employeeIDs := make([]string, 0, len(run.Items))
	for _, item := range run.Items {
		employeeIDs = append(employeeIDs, item.EmployeeID)
	}
	var employeeCount int64
	if err := tx.WithContext(ctx).Model(&domain.Employee{}).Where("organization_id = ? AND id IN ?", organizationID, employeeIDs).Count(&employeeCount).Error; err != nil {
		return err
	}
	if employeeCount != int64(len(uniqueStrings(employeeIDs))) {
		return ErrPayrollEmployeeScope
	}
	return nil
}
