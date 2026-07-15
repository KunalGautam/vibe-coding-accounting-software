package handlers

import (
	"errors"
	"net/http"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
)

type PayrollHandler struct {
	payroll services.PayrollService
}

type createPayrollRunRequest struct {
	RunNumber                   string                     `json:"run_number" binding:"required"`
	PeriodStart                 string                     `json:"period_start" binding:"required"`
	PeriodEnd                   string                     `json:"period_end" binding:"required"`
	PayDate                     string                     `json:"pay_date" binding:"required"`
	Currency                    string                     `json:"currency"`
	PayrollExpenseAccountID     string                     `json:"payroll_expense_account_id" binding:"required"`
	PayrollLiabilityAccountID   string                     `json:"payroll_liability_account_id" binding:"required"`
	DeductionLiabilityAccountID string                     `json:"deduction_liability_account_id" binding:"required"`
	EmployerExpenseAccountID    string                     `json:"employer_expense_account_id"`
	EmployerLiabilityAccountID  string                     `json:"employer_liability_account_id"`
	EmployerContributionsMinor  int64                      `json:"employer_contributions_minor" binding:"min=0"`
	Items                       []createPayrollItemRequest `json:"items" binding:"required,min=1"`
}

type createPayrollItemRequest struct {
	EmployeeID      string                          `json:"employee_id" binding:"required"`
	GrossPayMinor   int64                           `json:"gross_pay_minor" binding:"min=0"`
	DeductionsMinor int64                           `json:"deductions_minor" binding:"min=0"`
	PayslipKey      string                          `json:"payslip_key"`
	Components      []createPayrollComponentRequest `json:"components"`
}

type createPayrollComponentRequest struct {
	Code        string                      `json:"code" binding:"required"`
	Name        string                      `json:"name" binding:"required"`
	Type        domain.PayrollComponentType `json:"type" binding:"required"`
	AmountMinor int64                       `json:"amount_minor" binding:"min=0"`
	IsStatutory bool                        `json:"is_statutory"`
}

type previewIndiaPayrollRequest struct {
	BasicMinor           int64                        `json:"basic_minor" binding:"min=0"`
	HRAMinor             int64                        `json:"hra_minor" binding:"min=0"`
	SpecialMinor         int64                        `json:"special_minor" binding:"min=0"`
	BonusMinor           int64                        `json:"bonus_minor" binding:"min=0"`
	ReimbursementMinor   int64                        `json:"reimbursement_minor" binding:"min=0"`
	EmployeePFEnabled    bool                         `json:"employee_pf_enabled"`
	EmployeePFRateBps    int64                        `json:"employee_pf_rate_bps" binding:"min=0"`
	PFWageCeilingMinor   int64                        `json:"pf_wage_ceiling_minor" binding:"min=0"`
	EmployerPFEnabled    bool                         `json:"employer_pf_enabled"`
	EmployerPFRateBps    int64                        `json:"employer_pf_rate_bps" binding:"min=0"`
	EmployeeESIEnabled   bool                         `json:"employee_esi_enabled"`
	EmployeeESIRateBps   int64                        `json:"employee_esi_rate_bps" binding:"min=0"`
	EmployerESIEnabled   bool                         `json:"employer_esi_enabled"`
	EmployerESIRateBps   int64                        `json:"employer_esi_rate_bps" binding:"min=0"`
	ESIGrossLimitMinor   int64                        `json:"esi_gross_limit_minor" binding:"min=0"`
	ProfessionalTaxMinor int64                        `json:"professional_tax_minor" binding:"min=0"`
	TDSRateBps           int64                        `json:"tds_rate_bps" binding:"min=0"`
	TDSMinor             int64                        `json:"tds_minor" binding:"min=0"`
	TDSAnnualIncomeMinor int64                        `json:"tds_annual_income_minor" binding:"min=0"`
	TDSPeriodsInYear     int64                        `json:"tds_periods_in_year" binding:"min=0"`
	TDSSlabs             []previewIndiaTDSSlabRequest `json:"tds_slabs"`
}

type previewIndiaTDSSlabRequest struct {
	FromMinor int64 `json:"from_minor" binding:"min=0"`
	ToMinor   int64 `json:"to_minor" binding:"min=0"`
	RateBps   int64 `json:"rate_bps" binding:"min=0"`
}

func NewPayrollHandler(payroll services.PayrollService) PayrollHandler {
	return PayrollHandler{payroll: payroll}
}

func (h PayrollHandler) RegisterReadRoutes(router gin.IRoutes) {
	router.GET("/payroll/runs", h.ListRuns)
	router.GET("/payroll/india-professional-tax-presets", h.IndiaProfessionalTaxPresets)
	router.GET("/payroll/runs/:payrollRunId/items/:payrollItemId/payslip", h.PayslipPreview)
	router.GET("/payroll/runs/:payrollRunId/items/:payrollItemId/payslip.pdf", h.DownloadPayslipPDF)
}

func (h PayrollHandler) RegisterWriteRoutes(router gin.IRoutes) {
	router.POST("/payroll/india-preview", h.PreviewIndiaPayroll)
	router.POST("/payroll/runs", h.CreateRun)
	router.POST("/payroll/runs/:payrollRunId/post", h.PostRun)
}

func (h PayrollHandler) ListRuns(c *gin.Context) {
	runs, err := h.payroll.ListRuns(c.Request.Context(), c.Param("organizationId"))
	if err != nil {
		respondError(c, http.StatusInternalServerError, "list_payroll_runs_failed", err.Error())
		return
	}
	c.JSON(http.StatusOK, runs)
}

func (h PayrollHandler) IndiaProfessionalTaxPresets(c *gin.Context) {
	c.JSON(http.StatusOK, h.payroll.IndiaProfessionalTaxPresets())
}

func (h PayrollHandler) PayslipPreview(c *gin.Context) {
	preview, err := h.payroll.PayslipPreview(
		c.Request.Context(),
		c.Param("organizationId"),
		c.Param("payrollRunId"),
		c.Param("payrollItemId"),
	)
	if err != nil {
		status, code := payrollErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusOK, preview)
}

func (h PayrollHandler) DownloadPayslipPDF(c *gin.Context) {
	pdf, filename, err := h.payroll.PayslipPDF(
		c.Request.Context(),
		c.Param("organizationId"),
		c.Param("payrollRunId"),
		c.Param("payrollItemId"),
	)
	if err != nil {
		status, code := payrollErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.Header("Content-Disposition", `attachment; filename="`+filename+`"`)
	c.Header("Cache-Control", "no-store")
	c.Data(http.StatusOK, "application/pdf", pdf)
}

func (h PayrollHandler) CreateRun(c *gin.Context) {
	var request createPayrollRunRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	periodStart, err := parseDateField(request.PeriodStart, "period_start")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_period_start", err.Error())
		return
	}
	periodEnd, err := parseDateField(request.PeriodEnd, "period_end")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_period_end", err.Error())
		return
	}
	payDate, err := parseDateField(request.PayDate, "pay_date")
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid_pay_date", err.Error())
		return
	}

	items := make([]services.CreatePayrollItemInput, 0, len(request.Items))
	for _, item := range request.Items {
		components := make([]services.CreatePayrollComponentInput, 0, len(item.Components))
		for _, component := range item.Components {
			components = append(components, services.CreatePayrollComponentInput{
				Code:        component.Code,
				Name:        component.Name,
				Type:        component.Type,
				AmountMinor: component.AmountMinor,
				IsStatutory: component.IsStatutory,
			})
		}
		items = append(items, services.CreatePayrollItemInput{
			EmployeeID:      item.EmployeeID,
			GrossPayMinor:   item.GrossPayMinor,
			DeductionsMinor: item.DeductionsMinor,
			PayslipKey:      item.PayslipKey,
			Components:      components,
		})
	}

	run, err := h.payroll.CreateRun(c.Request.Context(), services.CreatePayrollRunInput{
		OrganizationID:              c.Param("organizationId"),
		RunNumber:                   request.RunNumber,
		PeriodStart:                 periodStart,
		PeriodEnd:                   periodEnd,
		PayDate:                     payDate,
		Currency:                    request.Currency,
		PayrollExpenseAccountID:     request.PayrollExpenseAccountID,
		PayrollLiabilityAccountID:   request.PayrollLiabilityAccountID,
		DeductionLiabilityAccountID: request.DeductionLiabilityAccountID,
		EmployerExpenseAccountID:    request.EmployerExpenseAccountID,
		EmployerLiabilityAccountID:  request.EmployerLiabilityAccountID,
		EmployerContributionsMinor:  request.EmployerContributionsMinor,
		Items:                       items,
	})
	if err != nil {
		status, code := payrollErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusCreated, run)
}

func (h PayrollHandler) PreviewIndiaPayroll(c *gin.Context) {
	var request previewIndiaPayrollRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		respondError(c, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}

	tdsSlabs := make([]services.IndiaTDSSlabInput, 0, len(request.TDSSlabs))
	for _, slab := range request.TDSSlabs {
		tdsSlabs = append(tdsSlabs, services.IndiaTDSSlabInput{
			FromMinor: slab.FromMinor,
			ToMinor:   slab.ToMinor,
			RateBps:   slab.RateBps,
		})
	}

	preview := h.payroll.PreviewIndiaPayroll(services.IndiaPayrollPreviewInput{
		BasicMinor:           request.BasicMinor,
		HRAMinor:             request.HRAMinor,
		SpecialMinor:         request.SpecialMinor,
		BonusMinor:           request.BonusMinor,
		ReimbursementMinor:   request.ReimbursementMinor,
		EmployeePFEnabled:    request.EmployeePFEnabled,
		EmployeePFRateBps:    request.EmployeePFRateBps,
		PFWageCeilingMinor:   request.PFWageCeilingMinor,
		EmployerPFEnabled:    request.EmployerPFEnabled,
		EmployerPFRateBps:    request.EmployerPFRateBps,
		EmployeeESIEnabled:   request.EmployeeESIEnabled,
		EmployeeESIRateBps:   request.EmployeeESIRateBps,
		EmployerESIEnabled:   request.EmployerESIEnabled,
		EmployerESIRateBps:   request.EmployerESIRateBps,
		ESIGrossLimitMinor:   request.ESIGrossLimitMinor,
		ProfessionalTaxMinor: request.ProfessionalTaxMinor,
		TDSRateBps:           request.TDSRateBps,
		TDSMinor:             request.TDSMinor,
		TDSAnnualIncomeMinor: request.TDSAnnualIncomeMinor,
		TDSPeriodsInYear:     request.TDSPeriodsInYear,
		TDSSlabs:             tdsSlabs,
	})
	c.JSON(http.StatusOK, preview)
}

func (h PayrollHandler) PostRun(c *gin.Context) {
	run, err := h.payroll.PostRun(c.Request.Context(), c.Param("organizationId"), c.Param("payrollRunId"))
	if err != nil {
		status, code := payrollErrorStatus(err)
		respondError(c, status, code, err.Error())
		return
	}
	c.JSON(http.StatusOK, run)
}

func parseDateField(value string, name string) (time.Time, error) {
	parsed, err := time.Parse("2006-01-02", value)
	if err != nil {
		return time.Time{}, &dateQueryError{name: name}
	}
	return parsed, nil
}

func payrollErrorStatus(err error) (int, string) {
	switch {
	case errors.Is(err, services.ErrPayrollRunHasNoItems),
		errors.Is(err, services.ErrPayrollAlreadyPosted),
		errors.Is(err, services.ErrPayrollAccountScope),
		errors.Is(err, services.ErrPayrollEmployeeScope),
		errors.Is(err, services.ErrPayrollItemScope),
		errors.Is(err, services.ErrPayrollComponentType),
		errors.Is(err, services.ErrPayrollComponentSum),
		errors.Is(err, domain.ErrTenantScope):
		return http.StatusBadRequest, "invalid_payroll_run"
	default:
		return http.StatusInternalServerError, "payroll_request_failed"
	}
}
