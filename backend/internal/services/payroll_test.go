package services

import (
	"context"
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
	assertSplit(t, splits, payrollLiability.ID, 0, 90000)
	assertSplit(t, splits, payrollLiability.ID, 0, 10000)
}

func TestPayrollServicePreviewIndiaPayroll(t *testing.T) {
	service := NewPayrollService(nil)

	preview := service.PreviewIndiaPayroll(IndiaPayrollPreviewInput{
		BasicMinor:           2000000,
		HRAMinor:             500000,
		SpecialMinor:         250000,
		EmployeePFEnabled:    true,
		EmployeeESIEnabled:   true,
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
	if preview.RuleSummary.EmployeePFRateBps != 1200 || preview.RuleSummary.PFWageCeilingMinor != 1500000 {
		t.Fatalf("unexpected PF defaults: %+v", preview.RuleSummary)
	}
	if preview.RuleSummary.EmployeeESIRateBps != 75 || preview.RuleSummary.ESIGrossLimitMinor != 2100000 {
		t.Fatalf("unexpected ESI defaults: %+v", preview.RuleSummary)
	}
	assertPayrollComponent(t, preview.Components, "PF", domain.PayrollComponentDeduction, 180000, true)
	assertPayrollComponent(t, preview.Components, "PT", domain.PayrollComponentDeduction, 20000, true)
	assertPayrollComponent(t, preview.Components, "TDS", domain.PayrollComponentDeduction, 150000, true)
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
