package services

import (
	"bytes"
	"context"
	"strings"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/domain"
)

func TestPayrollServiceCreateAndPostRun(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if _, err := NewSeedService(db).SeedIndiaDefaults(ctx, org.ID); err != nil {
		t.Fatalf("seed defaults: %v", err)
	}

	employee := domain.Employee{OrganizationID: org.ID, DisplayName: "Employee One", EmployeeCode: "E001", IsActive: true}
	if err := db.Create(&employee).Error; err != nil {
		t.Fatalf("create employee: %v", err)
	}

	payrollExpense := mustAccountByCode(t, db, org.ID, "6100")
	payrollLiability := mustAccountByCode(t, db, org.ID, "2200")

	service := NewPayrollService(db)
	run, err := service.CreateRun(ctx, CreatePayrollRunInput{
		OrganizationID:              org.ID,
		RunNumber:                   "PAY-2026-07",
		PeriodStart:                 time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		PeriodEnd:                   time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC),
		PayDate:                     time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC),
		PayrollExpenseAccountID:     payrollExpense.ID,
		PayrollLiabilityAccountID:   payrollLiability.ID,
		DeductionLiabilityAccountID: payrollLiability.ID,
		EmployerExpenseAccountID:    payrollExpense.ID,
		EmployerLiabilityAccountID:  payrollLiability.ID,
		EmployerContributionsMinor:  12000,
		Items: []CreatePayrollItemInput{
			{
				EmployeeID:      employee.ID,
				GrossPayMinor:   100000,
				DeductionsMinor: 10000,
				Components: []CreatePayrollComponentInput{
					{Code: "BASIC", Name: "Basic Pay", Type: domain.PayrollComponentEarning, AmountMinor: 70000},
					{Code: "HRA", Name: "House Rent Allowance", Type: domain.PayrollComponentEarning, AmountMinor: 30000},
					{Code: "PF", Name: "Provident Fund", Type: domain.PayrollComponentDeduction, AmountMinor: 10000, IsStatutory: true},
				},
			},
		},
	})
	if err != nil {
		t.Fatalf("CreateRun() error = %v", err)
	}
	if run.GrossPayMinor != 100000 || run.DeductionsMinor != 10000 || run.NetPayMinor != 90000 {
		t.Fatalf("unexpected payroll totals: %+v", run)
	}
	if run.EmployerContributionsMinor != 12000 || run.PayrollCostMinor != 112000 {
		t.Fatalf("unexpected employer payroll totals: %+v", run)
	}
	if len(run.Items) != 1 || len(run.Items[0].Components) != 3 {
		t.Fatalf("expected payroll components to be persisted on the draft run: %+v", run.Items)
	}

	payslip, err := service.PayslipPreview(ctx, org.ID, run.ID, run.Items[0].ID)
	if err != nil {
		t.Fatalf("PayslipPreview() error = %v", err)
	}
	if payslip.Employee.DisplayName != employee.DisplayName {
		t.Fatalf("employee = %+v, want %s", payslip.Employee, employee.DisplayName)
	}
	if payslip.GrossPayMinor != 100000 || payslip.DeductionsMinor != 10000 || payslip.NetPayMinor != 90000 {
		t.Fatalf("unexpected payslip totals: %+v", payslip)
	}
	if len(payslip.Earnings) != 2 || len(payslip.Deductions) != 1 || len(payslip.Components) != 3 {
		t.Fatalf("unexpected payslip component grouping: %+v", payslip)
	}
	pdf, filename, err := service.PayslipPDF(ctx, org.ID, run.ID, run.Items[0].ID)
	if err != nil {
		t.Fatalf("PayslipPDF() error = %v", err)
	}
	if !bytes.HasPrefix(pdf, []byte("%PDF-1.4")) || !bytes.Contains(pdf, []byte("%%EOF")) {
		t.Fatalf("generated payslip is not a complete PDF: %q", string(pdf[:min(len(pdf), 32)]))
	}
	if !strings.HasSuffix(filename, ".pdf") || !strings.Contains(filename, "PAY-2026-07") || !strings.Contains(filename, "E001") {
		t.Fatalf("filename = %q, want payslip run and employee PDF filename", filename)
	}

	posted, err := service.PostRun(ctx, org.ID, run.ID)
	if err != nil {
		t.Fatalf("PostRun() error = %v", err)
	}
	if posted.Status != domain.PayrollRunStatusPosted {
		t.Fatalf("status = %s, want posted", posted.Status)
	}
	if posted.JournalTransactionID == nil {
		t.Fatalf("journal transaction id is nil")
	}

	var splits []domain.LedgerSplit
	if err := db.Where("journal_transaction_id = ?", *posted.JournalTransactionID).Find(&splits).Error; err != nil {
		t.Fatalf("find splits: %v", err)
	}
	assertSplit(t, splits, payrollExpense.ID, 100000, 0)
	assertSplit(t, splits, payrollExpense.ID, 12000, 0)
	assertSplit(t, splits, payrollLiability.ID, 0, 90000)
	assertSplit(t, splits, payrollLiability.ID, 0, 10000)
	assertSplit(t, splits, payrollLiability.ID, 0, 12000)
}

func TestPayrollServicePreviewIndiaPayroll(t *testing.T) {
	service := NewPayrollService(nil)

	preview := service.PreviewIndiaPayroll(IndiaPayrollPreviewInput{
		BasicMinor:           2000000,
		HRAMinor:             500000,
		SpecialMinor:         250000,
		EmployeePFEnabled:    true,
		EmployerPFEnabled:    true,
		EmployeeESIEnabled:   true,
		EmployerESIEnabled:   true,
		ProfessionalTaxMinor: 20000,
		TDSMinor:             150000,
	})

	if preview.GrossPayMinor != 2750000 {
		t.Fatalf("gross = %d, want 2750000", preview.GrossPayMinor)
	}
	if preview.DeductionsMinor != 350000 {
		t.Fatalf("deductions = %d, want 350000", preview.DeductionsMinor)
	}
	if preview.NetPayMinor != 2400000 {
		t.Fatalf("net = %d, want 2400000", preview.NetPayMinor)
	}
	if preview.EmployerContributionsMinor != 180000 {
		t.Fatalf("employer contributions = %d, want 180000", preview.EmployerContributionsMinor)
	}
	if preview.PayrollCostMinor != 2930000 {
		t.Fatalf("payroll cost = %d, want 2930000", preview.PayrollCostMinor)
	}
	if preview.RuleSummary.EmployeePFRateBps != 1200 || preview.RuleSummary.PFWageCeilingMinor != 1500000 {
		t.Fatalf("unexpected PF defaults: %+v", preview.RuleSummary)
	}
	if preview.RuleSummary.EmployerPFRateBps != 1200 {
		t.Fatalf("unexpected employer PF defaults: %+v", preview.RuleSummary)
	}
	if preview.RuleSummary.EmployeeESIRateBps != 75 || preview.RuleSummary.ESIGrossLimitMinor != 2100000 {
		t.Fatalf("unexpected ESI defaults: %+v", preview.RuleSummary)
	}
	if preview.RuleSummary.EmployerESIRateBps != 325 {
		t.Fatalf("unexpected employer ESI defaults: %+v", preview.RuleSummary)
	}
	assertPayrollComponent(t, preview.Components, "PF", domain.PayrollComponentDeduction, 180000, true)
	assertPayrollComponent(t, preview.Components, "PT", domain.PayrollComponentDeduction, 20000, true)
	assertPayrollComponent(t, preview.Components, "TDS", domain.PayrollComponentDeduction, 150000, true)
	assertEmployerPayrollContribution(t, preview.EmployerContributions, "ER_PF", 180000, true)
}

func TestPayrollServicePreviewIndiaPayrollCalculatesTDSFromRate(t *testing.T) {
	service := NewPayrollService(nil)

	preview := service.PreviewIndiaPayroll(IndiaPayrollPreviewInput{
		BasicMinor: 1000000,
		TDSRateBps: 1000,
	})

	if preview.DeductionsMinor != 100000 {
		t.Fatalf("deductions = %d, want 100000", preview.DeductionsMinor)
	}
	if preview.NetPayMinor != 900000 {
		t.Fatalf("net = %d, want 900000", preview.NetPayMinor)
	}
	if preview.RuleSummary.TDSRateBps != 1000 {
		t.Fatalf("tds rate = %d, want 1000", preview.RuleSummary.TDSRateBps)
	}
	assertPayrollComponent(t, preview.Components, "TDS", domain.PayrollComponentDeduction, 100000, true)
}

func TestPayrollServicePreviewIndiaPayrollCalculatesTDSFromSlabs(t *testing.T) {
	service := NewPayrollService(nil)

	preview := service.PreviewIndiaPayroll(IndiaPayrollPreviewInput{
		BasicMinor:           10000000,
		TDSAnnualIncomeMinor: 90000000,
		TDSSlabs: []IndiaTDSSlabInput{
			{FromMinor: 0, ToMinor: 30000000, RateBps: 0},
			{FromMinor: 30000000, ToMinor: 60000000, RateBps: 500},
			{FromMinor: 60000000, RateBps: 1000},
		},
	})

	if preview.RuleSummary.TDSAnnualTaxMinor != 4500000 {
		t.Fatalf("annual slab tax = %d, want 4500000", preview.RuleSummary.TDSAnnualTaxMinor)
	}
	if preview.RuleSummary.TDSPeriodsInYear != 12 || preview.RuleSummary.TDSSlabCount != 3 {
		t.Fatalf("unexpected tds policy summary: %+v", preview.RuleSummary)
	}
	assertPayrollComponent(t, preview.Components, "TDS", domain.PayrollComponentDeduction, 375000, true)
}

func TestPayrollServicePreviewIndiaPayrollFixedTDSOverridesSlabs(t *testing.T) {
	service := NewPayrollService(nil)

	preview := service.PreviewIndiaPayroll(IndiaPayrollPreviewInput{
		BasicMinor:           10000000,
		TDSMinor:             12345,
		TDSAnnualIncomeMinor: 90000000,
		TDSSlabs:             []IndiaTDSSlabInput{{FromMinor: 0, RateBps: 3000}},
	})

	if preview.RuleSummary.TDSAnnualTaxMinor != 0 {
		t.Fatalf("fixed tds should skip slab tax summary, got %+v", preview.RuleSummary)
	}
	assertPayrollComponent(t, preview.Components, "TDS", domain.PayrollComponentDeduction, 12345, true)
}

func TestPayrollServiceIndiaProfessionalTaxPresets(t *testing.T) {
	service := NewPayrollService(nil)

	presets := service.IndiaProfessionalTaxPresets()
	if len(presets) < 5 {
		t.Fatalf("preset count = %d, want starter coverage for common India PT states", len(presets))
	}
	var foundKarnataka bool
	var foundDelhi bool
	for _, preset := range presets {
		if preset.StateCode == "" || preset.StateName == "" || preset.Notes == "" {
			t.Fatalf("preset should include code, name, and notes: %+v", preset)
		}
		if preset.StateCode == "KA" && preset.MonthlyAmountMinor == 20000 {
			foundKarnataka = true
		}
		if preset.StateCode == "DL" && preset.MonthlyAmountMinor == 0 {
			foundDelhi = true
		}
	}
	if !foundKarnataka || !foundDelhi {
		t.Fatalf("expected Karnataka paid and Delhi zero PT presets, got %+v", presets)
	}
}

func assertPayrollComponent(t *testing.T, components []CreatePayrollComponentInput, code string, componentType domain.PayrollComponentType, amount int64, statutory bool) {
	t.Helper()
	for _, component := range components {
		if component.Code == code {
			if component.Type != componentType || component.AmountMinor != amount || component.IsStatutory != statutory {
				t.Fatalf("component %s = %+v, want type=%s amount=%d statutory=%t", code, component, componentType, amount, statutory)
			}
			return
		}
	}
	t.Fatalf("component %s not found in %+v", code, components)
}

func assertEmployerPayrollContribution(t *testing.T, contributions []IndiaPayrollEmployerContribution, code string, amount int64, statutory bool) {
	t.Helper()
	for _, contribution := range contributions {
		if contribution.Code == code {
			if contribution.AmountMinor != amount || contribution.IsStatutory != statutory {
				t.Fatalf("employer contribution %s = %+v, want amount=%d statutory=%t", code, contribution, amount, statutory)
			}
			return
		}
	}
	t.Fatalf("employer contribution %s not found in %+v", code, contributions)
}
