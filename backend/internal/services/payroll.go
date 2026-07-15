package services

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"
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
	EmployerExpenseAccountID    string
	EmployerLiabilityAccountID  string
	EmployerContributionsMinor  int64
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
	EmployerPFEnabled    bool
	EmployerPFRateBps    int64
	EmployeeESIEnabled   bool
	EmployeeESIRateBps   int64
	EmployerESIEnabled   bool
	EmployerESIRateBps   int64
	ESIGrossLimitMinor   int64
	ProfessionalTaxMinor int64
	TDSRateBps           int64
	TDSMinor             int64
	TDSAnnualIncomeMinor int64
	TDSPeriodsInYear     int64
	TDSSlabs             []IndiaTDSSlabInput
}

type IndiaPayrollPreview struct {
	GrossPayMinor              int64                              `json:"gross_pay_minor"`
	DeductionsMinor            int64                              `json:"deductions_minor"`
	NetPayMinor                int64                              `json:"net_pay_minor"`
	EmployerContributionsMinor int64                              `json:"employer_contributions_minor"`
	PayrollCostMinor           int64                              `json:"payroll_cost_minor"`
	Components                 []CreatePayrollComponentInput      `json:"components"`
	EmployerContributions      []IndiaPayrollEmployerContribution `json:"employer_contributions"`
	RuleSummary                IndiaPayrollRuleSummary            `json:"rule_summary"`
}

type IndiaPayrollRuleSummary struct {
	EmployeePFEnabled    bool  `json:"employee_pf_enabled"`
	EmployeePFRateBps    int64 `json:"employee_pf_rate_bps"`
	PFWageCeilingMinor   int64 `json:"pf_wage_ceiling_minor"`
	EmployerPFEnabled    bool  `json:"employer_pf_enabled"`
	EmployerPFRateBps    int64 `json:"employer_pf_rate_bps"`
	EmployeeESIEnabled   bool  `json:"employee_esi_enabled"`
	EmployeeESIRateBps   int64 `json:"employee_esi_rate_bps"`
	EmployerESIEnabled   bool  `json:"employer_esi_enabled"`
	EmployerESIRateBps   int64 `json:"employer_esi_rate_bps"`
	ESIGrossLimitMinor   int64 `json:"esi_gross_limit_minor"`
	ProfessionalTaxMinor int64 `json:"professional_tax_minor"`
	TDSRateBps           int64 `json:"tds_rate_bps"`
	TDSMinor             int64 `json:"tds_minor"`
	TDSAnnualIncomeMinor int64 `json:"tds_annual_income_minor"`
	TDSAnnualTaxMinor    int64 `json:"tds_annual_tax_minor"`
	TDSPeriodsInYear     int64 `json:"tds_periods_in_year"`
	TDSSlabCount         int   `json:"tds_slab_count"`
}

type IndiaTDSSlabInput struct {
	FromMinor int64 `json:"from_minor"`
	ToMinor   int64 `json:"to_minor"`
	RateBps   int64 `json:"rate_bps"`
}

type IndiaPayrollEmployerContribution struct {
	Code        string `json:"code"`
	Name        string `json:"name"`
	AmountMinor int64  `json:"amount_minor"`
	IsStatutory bool   `json:"is_statutory"`
}

type IndiaProfessionalTaxPreset struct {
	StateCode          string `json:"state_code"`
	StateName          string `json:"state_name"`
	MonthlyAmountMinor int64  `json:"monthly_amount_minor"`
	Notes              string `json:"notes"`
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

func (s PayrollService) IndiaProfessionalTaxPresets() []IndiaProfessionalTaxPreset {
	return []IndiaProfessionalTaxPreset{
		{StateCode: "KA", StateName: "Karnataka", MonthlyAmountMinor: 20000, Notes: "Starter monthly preset for employees above the common PT salary threshold; verify current slabs before filing."},
		{StateCode: "MH", StateName: "Maharashtra", MonthlyAmountMinor: 20000, Notes: "Starter monthly preset for most months; Maharashtra has month/slab nuances, so verify before filing."},
		{StateCode: "WB", StateName: "West Bengal", MonthlyAmountMinor: 20000, Notes: "Starter high-slab monthly preset; verify progressive slab applicability."},
		{StateCode: "TN", StateName: "Tamil Nadu", MonthlyAmountMinor: 20800, Notes: "Starter monthly equivalent of a common half-yearly PT slab; verify local body rules."},
		{StateCode: "TS", StateName: "Telangana", MonthlyAmountMinor: 20000, Notes: "Starter monthly preset for employees above the common PT salary threshold; verify current slabs."},
		{StateCode: "GJ", StateName: "Gujarat", MonthlyAmountMinor: 20000, Notes: "Starter monthly preset for employees above the common PT salary threshold; verify current slabs."},
		{StateCode: "DL", StateName: "Delhi", MonthlyAmountMinor: 0, Notes: "No professional tax preset because Delhi generally does not levy state professional tax."},
	}
}

func (s PayrollService) PreviewIndiaPayroll(input IndiaPayrollPreviewInput) IndiaPayrollPreview {
	input = withIndiaPayrollDefaults(input)
	components := make([]CreatePayrollComponentInput, 0, 8)
	employerContributions := make([]IndiaPayrollEmployerContribution, 0, 4)
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
	addEmployerContribution := func(code string, name string, amount int64, statutory bool) {
		if amount <= 0 {
			return
		}
		employerContributions = append(employerContributions, IndiaPayrollEmployerContribution{
			Code:        code,
			Name:        name,
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
	if input.EmployerPFEnabled {
		pfBase := input.BasicMinor
		if input.PFWageCeilingMinor > 0 && pfBase > input.PFWageCeilingMinor {
			pfBase = input.PFWageCeilingMinor
		}
		addEmployerContribution("ER_PF", "Employer Provident Fund", percentageMinor(pfBase, input.EmployerPFRateBps), true)
	}

	if input.EmployeeESIEnabled && input.ESIGrossLimitMinor > 0 && grossPay <= input.ESIGrossLimitMinor {
		esi := percentageMinor(grossPay, input.EmployeeESIRateBps)
		deductions += esi
		addComponent("ESI", "Employee State Insurance", domain.PayrollComponentDeduction, esi, true)
	}
	if input.EmployerESIEnabled && input.ESIGrossLimitMinor > 0 && grossPay <= input.ESIGrossLimitMinor {
		addEmployerContribution("ER_ESI", "Employer State Insurance", percentageMinor(grossPay, input.EmployerESIRateBps), true)
	}

	deductions += input.ProfessionalTaxMinor
	addComponent("PT", "Professional Tax", domain.PayrollComponentDeduction, input.ProfessionalTaxMinor, true)
	tds := input.TDSMinor
	if tds == 0 && input.TDSRateBps > 0 {
		tds = percentageMinor(grossPay, input.TDSRateBps)
	}
	tdsAnnualTax := int64(0)
	if tds == 0 && input.TDSAnnualIncomeMinor > 0 && len(input.TDSSlabs) > 0 {
		tdsAnnualTax = calculateProgressiveTaxMinor(input.TDSAnnualIncomeMinor, input.TDSSlabs)
		tds = divideRounded(tdsAnnualTax, input.TDSPeriodsInYear)
	}
	deductions += tds
	addComponent("TDS", "Tax Deducted at Source", domain.PayrollComponentDeduction, tds, true)

	var employerContributionTotal int64
	for _, contribution := range employerContributions {
		employerContributionTotal += contribution.AmountMinor
	}

	return IndiaPayrollPreview{
		GrossPayMinor:              grossPay,
		DeductionsMinor:            deductions,
		NetPayMinor:                grossPay - deductions,
		EmployerContributionsMinor: employerContributionTotal,
		PayrollCostMinor:           grossPay + employerContributionTotal,
		Components:                 components,
		EmployerContributions:      employerContributions,
		RuleSummary: IndiaPayrollRuleSummary{
			EmployeePFEnabled:    input.EmployeePFEnabled,
			EmployeePFRateBps:    input.EmployeePFRateBps,
			PFWageCeilingMinor:   input.PFWageCeilingMinor,
			EmployerPFEnabled:    input.EmployerPFEnabled,
			EmployerPFRateBps:    input.EmployerPFRateBps,
			EmployeeESIEnabled:   input.EmployeeESIEnabled,
			EmployeeESIRateBps:   input.EmployeeESIRateBps,
			EmployerESIEnabled:   input.EmployerESIEnabled,
			EmployerESIRateBps:   input.EmployerESIRateBps,
			ESIGrossLimitMinor:   input.ESIGrossLimitMinor,
			ProfessionalTaxMinor: input.ProfessionalTaxMinor,
			TDSRateBps:           input.TDSRateBps,
			TDSMinor:             input.TDSMinor,
			TDSAnnualIncomeMinor: input.TDSAnnualIncomeMinor,
			TDSAnnualTaxMinor:    tdsAnnualTax,
			TDSPeriodsInYear:     input.TDSPeriodsInYear,
			TDSSlabCount:         len(input.TDSSlabs),
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
	if input.EmployerPFRateBps == 0 {
		input.EmployerPFRateBps = 1200
	}
	if input.EmployeeESIRateBps == 0 {
		input.EmployeeESIRateBps = 75
	}
	if input.EmployerESIRateBps == 0 {
		input.EmployerESIRateBps = 325
	}
	if input.ESIGrossLimitMinor == 0 {
		input.ESIGrossLimitMinor = 2100000
	}
	if input.TDSPeriodsInYear == 0 {
		input.TDSPeriodsInYear = 12
	}
	return input
}

func percentageMinor(amountMinor int64, basisPoints int64) int64 {
	if amountMinor <= 0 || basisPoints <= 0 {
		return 0
	}
	return (amountMinor*basisPoints + 5000) / 10000
}

func calculateProgressiveTaxMinor(incomeMinor int64, slabs []IndiaTDSSlabInput) int64 {
	var taxMinor int64
	for _, slab := range slabs {
		if incomeMinor <= slab.FromMinor || slab.RateBps <= 0 {
			continue
		}
		taxableInSlab := incomeMinor - slab.FromMinor
		if slab.ToMinor > 0 && incomeMinor > slab.ToMinor {
			taxableInSlab = slab.ToMinor - slab.FromMinor
		}
		if taxableInSlab <= 0 {
			continue
		}
		taxMinor += percentageMinor(taxableInSlab, slab.RateBps)
	}
	return taxMinor
}

func divideRounded(amount int64, divisor int64) int64 {
	if amount <= 0 || divisor <= 0 {
		return 0
	}
	return (amount + divisor/2) / divisor
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

func (s PayrollService) PayslipPDF(ctx context.Context, organizationID string, payrollRunID string, payrollItemID string) ([]byte, string, error) {
	preview, err := s.PayslipPreview(ctx, organizationID, payrollRunID, payrollItemID)
	if err != nil {
		return nil, "", err
	}
	return renderPayslipPDF(preview), payslipPDFFilename(preview), nil
}

func renderPayslipPDF(preview PayslipPreview) []byte {
	var content bytes.Buffer
	lineY := 790
	addLine := func(size int, text string) {
		if lineY < 52 {
			return
		}
		fmt.Fprintf(&content, "BT /F1 %d Tf 50 %d Td (%s) Tj ET\n", size, lineY, escapePDFText(text))
		lineY -= size + 9
	}
	addGap := func(points int) {
		lineY -= points
	}

	currency := preview.Currency
	if currency == "" {
		currency = "INR"
	}

	addLine(18, "Payslip")
	addLine(11, "Run: "+preview.RunNumber+" | Status: "+string(preview.Status))
	addLine(11, "Period: "+formatPDFDate(preview.PeriodStart)+" to "+formatPDFDate(preview.PeriodEnd)+" | Pay date: "+formatPDFDate(preview.PayDate))
	addGap(6)
	addLine(13, "Employee")
	addLine(11, "Name: "+preview.Employee.DisplayName)
	addLine(11, "Code: "+emptyPDFValue(preview.Employee.EmployeeCode)+" | PAN: "+emptyPDFValue(preview.Employee.PAN)+" | UAN: "+emptyPDFValue(preview.Employee.UAN))
	addGap(6)
	addLine(13, "Earnings")
	for _, component := range preview.Earnings {
		addLine(10, component.Code+" - "+component.Name+": "+formatMinorCurrency(currency, component.AmountMinor))
	}
	addGap(4)
	addLine(13, "Deductions")
	if len(preview.Deductions) == 0 {
		addLine(10, "No deductions")
	}
	for _, component := range preview.Deductions {
		statutory := ""
		if component.IsStatutory {
			statutory = " (statutory)"
		}
		addLine(10, component.Code+" - "+component.Name+": "+formatMinorCurrency(currency, component.AmountMinor)+statutory)
	}
	addGap(8)
	addLine(13, "Totals")
	addLine(11, "Gross pay: "+formatMinorCurrency(currency, preview.GrossPayMinor))
	addLine(11, "Deductions: "+formatMinorCurrency(currency, preview.DeductionsMinor))
	addLine(12, "Net pay: "+formatMinorCurrency(currency, preview.NetPayMinor))
	addGap(8)
	addLine(9, "Generated by AbhashTech Accounting. This document is based on posted payroll data and should be reviewed before statutory filing.")

	return buildSimplePDF(content.Bytes())
}

func buildSimplePDF(content []byte) []byte {
	objects := []string{
		"<< /Type /Catalog /Pages 2 0 R >>",
		"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
		"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
		"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
		"<< /Length " + strconv.Itoa(len(content)) + " >>\nstream\n" + string(content) + "endstream",
	}

	var pdf bytes.Buffer
	pdf.WriteString("%PDF-1.4\n")
	offsets := make([]int, 0, len(objects)+1)
	offsets = append(offsets, 0)
	for index, object := range objects {
		offsets = append(offsets, pdf.Len())
		fmt.Fprintf(&pdf, "%d 0 obj\n%s\nendobj\n", index+1, object)
	}
	xrefOffset := pdf.Len()
	fmt.Fprintf(&pdf, "xref\n0 %d\n", len(objects)+1)
	pdf.WriteString("0000000000 65535 f \n")
	for _, offset := range offsets[1:] {
		fmt.Fprintf(&pdf, "%010d 00000 n \n", offset)
	}
	fmt.Fprintf(&pdf, "trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n", len(objects)+1, xrefOffset)
	return pdf.Bytes()
}

func payslipPDFFilename(preview PayslipPreview) string {
	employeePart := preview.Employee.EmployeeCode
	if employeePart == "" {
		employeePart = preview.Employee.DisplayName
	}
	return "payslip-" + safePDFNamePart(preview.RunNumber) + "-" + safePDFNamePart(employeePart) + ".pdf"
}

func safePDFNamePart(value string) string {
	value = strings.TrimSpace(value)
	var builder strings.Builder
	lastWasDash := false
	for _, r := range value {
		allowed := (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '_' || r == '-' || r == '.'
		if allowed {
			builder.WriteRune(r)
			lastWasDash = false
			continue
		}
		if !lastWasDash {
			builder.WriteByte('-')
			lastWasDash = true
		}
	}
	cleaned := strings.Trim(builder.String(), "-.")
	if cleaned == "" {
		return "employee"
	}
	return cleaned
}

func escapePDFText(value string) string {
	value = strings.ReplaceAll(value, "\\", "\\\\")
	value = strings.ReplaceAll(value, "(", "\\(")
	value = strings.ReplaceAll(value, ")", "\\)")
	value = strings.ReplaceAll(value, "\r", " ")
	value = strings.ReplaceAll(value, "\n", " ")
	if len(value) > 110 {
		value = value[:107] + "..."
	}
	return value
}

func formatPDFDate(value time.Time) string {
	if value.IsZero() {
		return "-"
	}
	return value.Format("2006-01-02")
}

func emptyPDFValue(value string) string {
	if strings.TrimSpace(value) == "" {
		return "-"
	}
	return value
}

func formatMinorCurrency(currency string, amountMinor int64) string {
	sign := ""
	if amountMinor < 0 {
		sign = "-"
		amountMinor = -amountMinor
	}
	return fmt.Sprintf("%s%s %d.%02d", sign, currency, amountMinor/100, amountMinor%100)
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
		EmployerExpenseAccountID:    input.EmployerExpenseAccountID,
		EmployerLiabilityAccountID:  input.EmployerLiabilityAccountID,
		EmployerContributionsMinor:  input.EmployerContributionsMinor,
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
	run.PayrollCostMinor = run.GrossPayMinor + run.EmployerContributionsMinor

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
		if run.EmployerContributionsMinor > 0 {
			splits = append(splits,
				domain.LedgerSplit{
					OrganizationID: run.OrganizationID,
					AccountID:      run.EmployerExpenseAccountID,
					DebitMinor:     run.EmployerContributionsMinor,
					Currency:       run.Currency,
				},
				domain.LedgerSplit{
					OrganizationID: run.OrganizationID,
					AccountID:      run.EmployerLiabilityAccountID,
					CreditMinor:    run.EmployerContributionsMinor,
					Currency:       run.Currency,
				},
			)
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
	if run.EmployerContributionsMinor > 0 {
		if run.EmployerExpenseAccountID == "" || run.EmployerLiabilityAccountID == "" {
			return ErrPayrollAccountScope
		}
		accountIDs = append(accountIDs, run.EmployerExpenseAccountID, run.EmployerLiabilityAccountID)
	}
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
