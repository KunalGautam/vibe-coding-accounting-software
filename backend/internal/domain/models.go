package domain

import (
	"errors"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type Role string

const (
	RoleAdmin               Role = "admin"
	RoleAccountant          Role = "accountant"
	RoleBookkeeper          Role = "bookkeeper"
	RolePayrollManager      Role = "payroll_manager"
	RoleViewer              Role = "viewer"
	RoleEmployeeSelfService Role = "employee_self_service"
)

type AccountType string

const (
	AccountTypeAsset     AccountType = "asset"
	AccountTypeLiability AccountType = "liability"
	AccountTypeEquity    AccountType = "equity"
	AccountTypeIncome    AccountType = "income"
	AccountTypeExpense   AccountType = "expense"
)

type JournalStatus string

const (
	JournalStatusDraft    JournalStatus = "draft"
	JournalStatusPosted   JournalStatus = "posted"
	JournalStatusReversed JournalStatus = "reversed"
)

type SourceModule string

const (
	SourceModuleManual  SourceModule = "manual"
	SourceModuleInvoice SourceModule = "invoice"
	SourceModuleCredit  SourceModule = "credit_note"
	SourceModuleBill    SourceModule = "bill"
	SourceModuleExpense SourceModule = "expense"
	SourceModulePayroll SourceModule = "payroll"
	SourceModuleImport  SourceModule = "import"
	SourceModuleClosing SourceModule = "closing"
	SourceModulePayment SourceModule = "payment"
	SourceModuleRevalue SourceModule = "revaluation"
)

type TaxType string

const (
	TaxTypeVAT         TaxType = "VAT"
	TaxTypeGST         TaxType = "GST"
	TaxTypeSalesTax    TaxType = "Sales Tax"
	TaxTypeWithholding TaxType = "Withholding"
)

type InvoiceStatus string

const (
	InvoiceStatusDraft  InvoiceStatus = "draft"
	InvoiceStatusPosted InvoiceStatus = "posted"
	InvoiceStatusPaid   InvoiceStatus = "paid"
	InvoiceStatusVoid   InvoiceStatus = "void"
)

type RecurrenceFrequency string

const (
	RecurrenceFrequencyWeekly  RecurrenceFrequency = "weekly"
	RecurrenceFrequencyMonthly RecurrenceFrequency = "monthly"
	RecurrenceFrequencyYearly  RecurrenceFrequency = "yearly"
)

type EstimateStatus string

const (
	EstimateStatusDraft     EstimateStatus = "draft"
	EstimateStatusSent      EstimateStatus = "sent"
	EstimateStatusAccepted  EstimateStatus = "accepted"
	EstimateStatusConverted EstimateStatus = "converted"
	EstimateStatusVoid      EstimateStatus = "void"
)

type CreditNoteStatus string

const (
	CreditNoteStatusDraft  CreditNoteStatus = "draft"
	CreditNoteStatusPosted CreditNoteStatus = "posted"
	CreditNoteStatusVoid   CreditNoteStatus = "void"
)

type ExpenseStatus string

const (
	ExpenseStatusDraft  ExpenseStatus = "draft"
	ExpenseStatusPosted ExpenseStatus = "posted"
	ExpenseStatusVoid   ExpenseStatus = "void"
)

type BillStatus string

const (
	BillStatusDraft  BillStatus = "draft"
	BillStatusPosted BillStatus = "posted"
	BillStatusPaid   BillStatus = "paid"
	BillStatusVoid   BillStatus = "void"
)

type PurchaseOrderStatus string

const (
	PurchaseOrderStatusDraft     PurchaseOrderStatus = "draft"
	PurchaseOrderStatusSent      PurchaseOrderStatus = "sent"
	PurchaseOrderStatusApproved  PurchaseOrderStatus = "approved"
	PurchaseOrderStatusConverted PurchaseOrderStatus = "converted"
	PurchaseOrderStatusVoid      PurchaseOrderStatus = "void"
)

type PayrollRunStatus string

const (
	PayrollRunStatusDraft  PayrollRunStatus = "draft"
	PayrollRunStatusPosted PayrollRunStatus = "posted"
	PayrollRunStatusVoid   PayrollRunStatus = "void"
)

type ScheduledReportType string

const (
	ScheduledReportTrialBalance  ScheduledReportType = "trial_balance"
	ScheduledReportProfitAndLoss ScheduledReportType = "profit_and_loss"
	ScheduledReportBalanceSheet  ScheduledReportType = "balance_sheet"
)

type ScheduledReportFrequency string

const (
	ScheduledReportFrequencyDaily   ScheduledReportFrequency = "daily"
	ScheduledReportFrequencyWeekly  ScheduledReportFrequency = "weekly"
	ScheduledReportFrequencyMonthly ScheduledReportFrequency = "monthly"
)

type ScheduledReportRunStatus string

const (
	ScheduledReportRunCompleted ScheduledReportRunStatus = "completed"
	ScheduledReportRunFailed    ScheduledReportRunStatus = "failed"
)

type PayrollComponentType string

const (
	PayrollComponentEarning   PayrollComponentType = "earning"
	PayrollComponentDeduction PayrollComponentType = "deduction"
)

type BankImportStatus string

const (
	BankImportStatusQueued    BankImportStatus = "queued"
	BankImportStatusCompleted BankImportStatus = "completed"
	BankImportStatusFailed    BankImportStatus = "failed"
)

type BudgetStatus string

const (
	BudgetStatusDraft  BudgetStatus = "draft"
	BudgetStatusActive BudgetStatus = "active"
	BudgetStatusClosed BudgetStatus = "closed"
)

type FiscalCloseStatus string

const (
	FiscalCloseStatusPosted   FiscalCloseStatus = "posted"
	FiscalCloseStatusReversed FiscalCloseStatus = "reversed"
)

type InvestmentCostMethod string

const (
	InvestmentCostMethodSpecificLot InvestmentCostMethod = "specific_lot"
	InvestmentCostMethodAverageCost InvestmentCostMethod = "average_cost"
)

type BaseModel struct {
	ID        string    `gorm:"type:char(36);primaryKey" json:"id"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (m *BaseModel) BeforeCreate(_ *gorm.DB) error {
	if m.ID == "" {
		m.ID = uuid.NewString()
	}
	return nil
}

type Organization struct {
	BaseModel
	Name                 string `gorm:"size:255;not null" json:"name"`
	BaseCurrency         string `gorm:"size:3;not null;default:INR" json:"base_currency"`
	CountryCode          string `gorm:"size:2;not null;default:IN" json:"country_code"`
	FiscalYearStartMonth int    `gorm:"not null;default:4" json:"fiscal_year_start_month"`
}

type User struct {
	BaseModel
	Email        string `gorm:"size:320;not null;uniqueIndex" json:"email"`
	Name         string `gorm:"size:255;not null" json:"name"`
	PasswordHash string `gorm:"size:255;not null" json:"-"`
	MFASecret    string `gorm:"size:128" json:"-"`
	MFAEnabled   bool   `gorm:"not null;default:false" json:"mfa_enabled"`
	IsActive     bool   `gorm:"not null;default:true" json:"is_active"`
}

type OrganizationMembership struct {
	BaseModel
	OrganizationID string       `gorm:"type:char(36);not null;index;uniqueIndex:idx_org_user" json:"organization_id"`
	Organization   Organization `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	UserID         string       `gorm:"type:char(36);not null;index;uniqueIndex:idx_org_user" json:"user_id"`
	User           User         `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Role           Role         `gorm:"size:64;not null" json:"role"`
}

type RefreshToken struct {
	BaseModel
	UserID    string     `gorm:"type:char(36);not null;index" json:"user_id"`
	User      User       `gorm:"constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"-"`
	TokenHash string     `gorm:"size:128;not null;uniqueIndex" json:"-"`
	ExpiresAt time.Time  `gorm:"not null;index" json:"expires_at"`
	RevokedAt *time.Time `json:"revoked_at,omitempty"`
}

type PasswordResetToken struct {
	BaseModel
	UserID    string     `gorm:"type:char(36);not null;index" json:"user_id"`
	User      User       `gorm:"constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"-"`
	TokenHash string     `gorm:"size:128;not null;uniqueIndex" json:"-"`
	ExpiresAt time.Time  `gorm:"not null;index" json:"expires_at"`
	UsedAt    *time.Time `json:"used_at,omitempty"`
}

type MFARecoveryCode struct {
	BaseModel
	UserID   string     `gorm:"type:char(36);not null;index" json:"user_id"`
	User     User       `gorm:"constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"-"`
	CodeHash string     `gorm:"size:128;not null;uniqueIndex" json:"-"`
	UsedAt   *time.Time `json:"used_at,omitempty"`
}

type BackupSnapshot struct {
	BaseModel
	OrganizationID string       `gorm:"type:char(36);not null;index" json:"organization_id"`
	Organization   Organization `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	FileName       string       `gorm:"size:255;not null" json:"file_name"`
	StoragePath    string       `gorm:"size:1000;not null" json:"storage_path"`
	SizeBytes      int64        `gorm:"not null;default:0" json:"size_bytes"`
	SHA256         string       `gorm:"size:64;not null" json:"sha256"`
	Status         string       `gorm:"size:32;not null;default:completed;index" json:"status"`
	CompletedAt    *time.Time   `json:"completed_at,omitempty"`
}

type Account struct {
	BaseModel
	OrganizationID string       `gorm:"type:char(36);not null;index;uniqueIndex:idx_org_account_code" json:"organization_id"`
	Organization   Organization `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	ParentID       *string      `gorm:"type:char(36);index" json:"parent_id,omitempty"`
	Parent         *Account     `gorm:"foreignKey:ParentID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Code           string       `gorm:"size:64;not null;uniqueIndex:idx_org_account_code" json:"code"`
	Name           string       `gorm:"size:255;not null" json:"name"`
	Type           AccountType  `gorm:"size:32;not null;index" json:"type"`
	Subtype        string       `gorm:"size:64" json:"subtype"`
	Currency       string       `gorm:"size:3;not null;default:INR" json:"currency"`
	IsPlaceholder  bool         `gorm:"not null;default:false" json:"is_placeholder"`
	IsActive       bool         `gorm:"not null;default:true" json:"is_active"`
}

type JournalTransaction struct {
	BaseModel
	OrganizationID        string        `gorm:"type:char(36);not null;index" json:"organization_id"`
	Organization          Organization  `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	TransactionDate       time.Time     `gorm:"not null;index" json:"transaction_date"`
	Memo                  string        `gorm:"size:1000" json:"memo"`
	SourceModule          SourceModule  `gorm:"size:64;not null;default:manual" json:"source_module"`
	Status                JournalStatus `gorm:"size:32;not null;default:draft;index" json:"status"`
	PostedAt              *time.Time    `json:"posted_at,omitempty"`
	PostedByUserID        *string       `gorm:"type:char(36)" json:"posted_by_user_id,omitempty"`
	ReversesTransactionID *string       `gorm:"type:char(36);index" json:"reverses_transaction_id,omitempty"`
	Splits                []LedgerSplit `gorm:"foreignKey:JournalTransactionID" json:"splits"`
}

type LedgerSplit struct {
	BaseModel
	OrganizationID          string             `gorm:"type:char(36);not null;index" json:"organization_id"`
	JournalTransactionID    string             `gorm:"type:char(36);not null;index" json:"journal_transaction_id"`
	JournalTransaction      JournalTransaction `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	AccountID               string             `gorm:"type:char(36);not null;index" json:"account_id"`
	Account                 Account            `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Memo                    string             `gorm:"size:1000" json:"memo"`
	DebitMinor              int64              `gorm:"not null;default:0" json:"debit_minor"`
	CreditMinor             int64              `gorm:"not null;default:0" json:"credit_minor"`
	BaseDebitMinor          int64              `gorm:"not null;default:0" json:"base_debit_minor"`
	BaseCreditMinor         int64              `gorm:"not null;default:0" json:"base_credit_minor"`
	Currency                string             `gorm:"size:3;not null;default:INR" json:"currency"`
	ExchangeRateNumerator   int64              `gorm:"not null;default:1" json:"exchange_rate_numerator"`
	ExchangeRateDenominator int64              `gorm:"not null;default:1" json:"exchange_rate_denominator"`
	Cleared                 bool               `gorm:"not null;default:false" json:"cleared"`
	Reconciled              bool               `gorm:"not null;default:false" json:"reconciled"`
	ReconciledAt            *time.Time         `json:"reconciled_at,omitempty"`
}

type AuditLog struct {
	BaseModel
	OrganizationID string `gorm:"type:char(36);index" json:"organization_id,omitempty"`
	ActorUserID    string `gorm:"type:char(36);index" json:"actor_user_id,omitempty"`
	EntityType     string `gorm:"size:128;not null;index" json:"entity_type"`
	EntityID       string `gorm:"type:char(36);not null;index" json:"entity_id"`
	Action         string `gorm:"size:128;not null" json:"action"`
	BeforeJSON     string `gorm:"type:text" json:"before_json,omitempty"`
	AfterJSON      string `gorm:"type:text" json:"after_json,omitempty"`
	IPAddress      string `gorm:"size:64" json:"ip_address,omitempty"`
	UserAgent      string `gorm:"size:512" json:"user_agent,omitempty"`
}

type TaxAuthority struct {
	BaseModel
	OrganizationID string       `gorm:"type:char(36);not null;index" json:"organization_id"`
	Organization   Organization `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Name           string       `gorm:"size:255;not null" json:"name"`
	CountryCode    string       `gorm:"size:2;not null;default:IN" json:"country_code"`
	RegionCode     string       `gorm:"size:32" json:"region_code"`
	IsActive       bool         `gorm:"not null;default:true" json:"is_active"`
}

type TaxRate struct {
	BaseModel
	OrganizationID  string       `gorm:"type:char(36);not null;index;uniqueIndex:idx_org_tax_rate_name" json:"organization_id"`
	Organization    Organization `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	TaxAuthorityID  string       `gorm:"type:char(36);not null;index" json:"tax_authority_id"`
	TaxAuthority    TaxAuthority `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Name            string       `gorm:"size:255;not null;uniqueIndex:idx_org_tax_rate_name" json:"name"`
	PercentageBasis int64        `gorm:"not null" json:"percentage_basis"`
	Type            TaxType      `gorm:"size:64;not null" json:"type"`
	OutputAccountID *string      `gorm:"type:char(36)" json:"output_account_id,omitempty"`
	InputAccountID  *string      `gorm:"type:char(36)" json:"input_account_id,omitempty"`
	EffectiveFrom   time.Time    `gorm:"not null" json:"effective_from"`
	EffectiveTo     *time.Time   `json:"effective_to,omitempty"`
	IsCompound      bool         `gorm:"not null;default:false" json:"is_compound"`
	IsActive        bool         `gorm:"not null;default:true" json:"is_active"`
}

type TaxGroup struct {
	BaseModel
	OrganizationID string              `gorm:"type:char(36);not null;index;uniqueIndex:idx_org_tax_group_name" json:"organization_id"`
	Organization   Organization        `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Name           string              `gorm:"size:255;not null;uniqueIndex:idx_org_tax_group_name" json:"name"`
	Description    string              `gorm:"size:1000" json:"description"`
	IsActive       bool                `gorm:"not null;default:true" json:"is_active"`
	Components     []TaxGroupComponent `gorm:"foreignKey:TaxGroupID" json:"components"`
}

type TaxGroupComponent struct {
	BaseModel
	OrganizationID string   `gorm:"type:char(36);not null;index" json:"organization_id"`
	TaxGroupID     string   `gorm:"type:char(36);not null;index;uniqueIndex:idx_tax_group_rate" json:"tax_group_id"`
	TaxGroup       TaxGroup `gorm:"constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"-"`
	TaxRateID      string   `gorm:"type:char(36);not null;index;uniqueIndex:idx_tax_group_rate" json:"tax_rate_id"`
	TaxRate        TaxRate  `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"tax_rate"`
	SortOrder      int      `gorm:"not null;default:0" json:"sort_order"`
}

type Customer struct {
	BaseModel
	OrganizationID string       `gorm:"type:char(36);not null;index" json:"organization_id"`
	Organization   Organization `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	DisplayName    string       `gorm:"size:255;not null;index" json:"display_name"`
	Email          string       `gorm:"size:320" json:"email"`
	Phone          string       `gorm:"size:64" json:"phone"`
	BillingAddress string       `gorm:"size:1000" json:"billing_address"`
	GSTIN          string       `gorm:"size:32" json:"gstin"`
	IsActive       bool         `gorm:"not null;default:true" json:"is_active"`
}

type Invoice struct {
	BaseModel
	OrganizationID       string        `gorm:"type:char(36);not null;index;uniqueIndex:idx_org_invoice_number" json:"organization_id"`
	Organization         Organization  `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	CustomerID           string        `gorm:"type:char(36);not null;index" json:"customer_id"`
	Customer             Customer      `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"customer,omitempty"`
	InvoiceNumber        string        `gorm:"size:64;not null;uniqueIndex:idx_org_invoice_number" json:"invoice_number"`
	IssueDate            time.Time     `gorm:"not null;index" json:"issue_date"`
	DueDate              time.Time     `gorm:"not null;index" json:"due_date"`
	Status               InvoiceStatus `gorm:"size:32;not null;default:draft;index" json:"status"`
	Currency             string        `gorm:"size:3;not null;default:INR" json:"currency"`
	TaxInclusive         bool          `gorm:"not null;default:false" json:"tax_inclusive"`
	SubtotalMinor        int64         `gorm:"not null;default:0" json:"subtotal_minor"`
	TaxTotalMinor        int64         `gorm:"not null;default:0" json:"tax_total_minor"`
	TotalMinor           int64         `gorm:"not null;default:0" json:"total_minor"`
	AccountsReceivableID string        `gorm:"type:char(36);not null" json:"accounts_receivable_id"`
	PDFAttachmentID      *string       `gorm:"type:char(36)" json:"pdf_attachment_id,omitempty"`
	JournalTransactionID *string       `gorm:"type:char(36);index" json:"journal_transaction_id,omitempty"`
	Lines                []InvoiceLine `gorm:"foreignKey:InvoiceID" json:"lines"`
}

type InvoiceLine struct {
	BaseModel
	OrganizationID    string  `gorm:"type:char(36);not null;index" json:"organization_id"`
	InvoiceID         string  `gorm:"type:char(36);not null;index" json:"invoice_id"`
	Invoice           Invoice `gorm:"constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"-"`
	Description       string  `gorm:"size:1000;not null" json:"description"`
	QuantityMillis    int64   `gorm:"not null;default:1000" json:"quantity_millis"`
	UnitPriceMinor    int64   `gorm:"not null" json:"unit_price_minor"`
	LineSubtotalMinor int64   `gorm:"not null" json:"line_subtotal_minor"`
	TaxAmountMinor    int64   `gorm:"not null;default:0" json:"tax_amount_minor"`
	LineTotalMinor    int64   `gorm:"not null" json:"line_total_minor"`
	IncomeAccountID   string  `gorm:"type:char(36);not null" json:"income_account_id"`
	TaxRateID         *string `gorm:"type:char(36)" json:"tax_rate_id,omitempty"`
	TaxGroupID        *string `gorm:"type:char(36)" json:"tax_group_id,omitempty"`
}

type RecurringInvoiceTemplate struct {
	BaseModel
	OrganizationID       string                 `gorm:"type:char(36);not null;index;uniqueIndex:idx_org_recurring_invoice_name" json:"organization_id"`
	Organization         Organization           `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	CustomerID           string                 `gorm:"type:char(36);not null;index" json:"customer_id"`
	Customer             Customer               `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"customer,omitempty"`
	Name                 string                 `gorm:"size:255;not null;uniqueIndex:idx_org_recurring_invoice_name" json:"name"`
	InvoiceNumberPrefix  string                 `gorm:"size:64;not null" json:"invoice_number_prefix"`
	StartDate            time.Time              `gorm:"not null;index" json:"start_date"`
	NextRunDate          time.Time              `gorm:"not null;index" json:"next_run_date"`
	Frequency            RecurrenceFrequency    `gorm:"size:32;not null;index" json:"frequency"`
	DueDays              int                    `gorm:"not null;default:30" json:"due_days"`
	Currency             string                 `gorm:"size:3;not null;default:INR" json:"currency"`
	TaxInclusive         bool                   `gorm:"not null;default:false" json:"tax_inclusive"`
	SubtotalMinor        int64                  `gorm:"not null;default:0" json:"subtotal_minor"`
	TaxTotalMinor        int64                  `gorm:"not null;default:0" json:"tax_total_minor"`
	TotalMinor           int64                  `gorm:"not null;default:0" json:"total_minor"`
	AccountsReceivableID string                 `gorm:"type:char(36);not null" json:"accounts_receivable_id"`
	IsActive             bool                   `gorm:"not null;default:true;index" json:"is_active"`
	LastGeneratedAt      *time.Time             `json:"last_generated_at,omitempty"`
	Lines                []RecurringInvoiceLine `gorm:"foreignKey:TemplateID" json:"lines"`
}

type RecurringInvoiceLine struct {
	BaseModel
	OrganizationID    string                   `gorm:"type:char(36);not null;index" json:"organization_id"`
	TemplateID        string                   `gorm:"type:char(36);not null;index" json:"template_id"`
	Template          RecurringInvoiceTemplate `gorm:"constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"-"`
	Description       string                   `gorm:"size:1000;not null" json:"description"`
	QuantityMillis    int64                    `gorm:"not null;default:1000" json:"quantity_millis"`
	UnitPriceMinor    int64                    `gorm:"not null" json:"unit_price_minor"`
	LineSubtotalMinor int64                    `gorm:"not null" json:"line_subtotal_minor"`
	TaxAmountMinor    int64                    `gorm:"not null;default:0" json:"tax_amount_minor"`
	LineTotalMinor    int64                    `gorm:"not null" json:"line_total_minor"`
	IncomeAccountID   string                   `gorm:"type:char(36);not null" json:"income_account_id"`
	TaxRateID         *string                  `gorm:"type:char(36)" json:"tax_rate_id,omitempty"`
	TaxGroupID        *string                  `gorm:"type:char(36)" json:"tax_group_id,omitempty"`
}

type Estimate struct {
	BaseModel
	OrganizationID string         `gorm:"type:char(36);not null;index;uniqueIndex:idx_org_estimate_number" json:"organization_id"`
	Organization   Organization   `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	CustomerID     string         `gorm:"type:char(36);not null;index" json:"customer_id"`
	Customer       Customer       `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"customer,omitempty"`
	EstimateNumber string         `gorm:"size:64;not null;uniqueIndex:idx_org_estimate_number" json:"estimate_number"`
	IssueDate      time.Time      `gorm:"not null;index" json:"issue_date"`
	ExpiryDate     time.Time      `gorm:"not null;index" json:"expiry_date"`
	Status         EstimateStatus `gorm:"size:32;not null;default:draft;index" json:"status"`
	Currency       string         `gorm:"size:3;not null;default:INR" json:"currency"`
	TaxInclusive   bool           `gorm:"not null;default:false" json:"tax_inclusive"`
	SubtotalMinor  int64          `gorm:"not null;default:0" json:"subtotal_minor"`
	TaxTotalMinor  int64          `gorm:"not null;default:0" json:"tax_total_minor"`
	TotalMinor     int64          `gorm:"not null;default:0" json:"total_minor"`
	Lines          []EstimateLine `gorm:"foreignKey:EstimateID" json:"lines"`
}

type EstimateLine struct {
	BaseModel
	OrganizationID    string   `gorm:"type:char(36);not null;index" json:"organization_id"`
	EstimateID        string   `gorm:"type:char(36);not null;index" json:"estimate_id"`
	Estimate          Estimate `gorm:"constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"-"`
	Description       string   `gorm:"size:1000;not null" json:"description"`
	QuantityMillis    int64    `gorm:"not null;default:1000" json:"quantity_millis"`
	UnitPriceMinor    int64    `gorm:"not null" json:"unit_price_minor"`
	LineSubtotalMinor int64    `gorm:"not null" json:"line_subtotal_minor"`
	TaxAmountMinor    int64    `gorm:"not null;default:0" json:"tax_amount_minor"`
	LineTotalMinor    int64    `gorm:"not null" json:"line_total_minor"`
	IncomeAccountID   string   `gorm:"type:char(36);not null" json:"income_account_id"`
	TaxRateID         *string  `gorm:"type:char(36)" json:"tax_rate_id,omitempty"`
	TaxGroupID        *string  `gorm:"type:char(36)" json:"tax_group_id,omitempty"`
}

type CreditNote struct {
	BaseModel
	OrganizationID       string           `gorm:"type:char(36);not null;index;uniqueIndex:idx_org_credit_note_number" json:"organization_id"`
	Organization         Organization     `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	CustomerID           string           `gorm:"type:char(36);not null;index" json:"customer_id"`
	Customer             Customer         `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"customer,omitempty"`
	InvoiceID            *string          `gorm:"type:char(36);index" json:"invoice_id,omitempty"`
	CreditNoteNumber     string           `gorm:"size:64;not null;uniqueIndex:idx_org_credit_note_number" json:"credit_note_number"`
	IssueDate            time.Time        `gorm:"not null;index" json:"issue_date"`
	Status               CreditNoteStatus `gorm:"size:32;not null;default:draft;index" json:"status"`
	Currency             string           `gorm:"size:3;not null;default:INR" json:"currency"`
	TaxInclusive         bool             `gorm:"not null;default:false" json:"tax_inclusive"`
	SubtotalMinor        int64            `gorm:"not null;default:0" json:"subtotal_minor"`
	TaxTotalMinor        int64            `gorm:"not null;default:0" json:"tax_total_minor"`
	TotalMinor           int64            `gorm:"not null;default:0" json:"total_minor"`
	AccountsReceivableID string           `gorm:"type:char(36);not null" json:"accounts_receivable_id"`
	JournalTransactionID *string          `gorm:"type:char(36);index" json:"journal_transaction_id,omitempty"`
	Lines                []CreditNoteLine `gorm:"foreignKey:CreditNoteID" json:"lines"`
}

type CreditNoteLine struct {
	BaseModel
	OrganizationID    string     `gorm:"type:char(36);not null;index" json:"organization_id"`
	CreditNoteID      string     `gorm:"type:char(36);not null;index" json:"credit_note_id"`
	CreditNote        CreditNote `gorm:"constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"-"`
	Description       string     `gorm:"size:1000;not null" json:"description"`
	QuantityMillis    int64      `gorm:"not null;default:1000" json:"quantity_millis"`
	UnitPriceMinor    int64      `gorm:"not null" json:"unit_price_minor"`
	LineSubtotalMinor int64      `gorm:"not null" json:"line_subtotal_minor"`
	TaxAmountMinor    int64      `gorm:"not null;default:0" json:"tax_amount_minor"`
	LineTotalMinor    int64      `gorm:"not null" json:"line_total_minor"`
	IncomeAccountID   string     `gorm:"type:char(36);not null" json:"income_account_id"`
	TaxRateID         *string    `gorm:"type:char(36)" json:"tax_rate_id,omitempty"`
	TaxGroupID        *string    `gorm:"type:char(36)" json:"tax_group_id,omitempty"`
}

type CustomerPayment struct {
	BaseModel
	OrganizationID       string             `gorm:"type:char(36);not null;index" json:"organization_id"`
	Organization         Organization       `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	InvoiceID            string             `gorm:"type:char(36);not null;index" json:"invoice_id"`
	Invoice              Invoice            `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"invoice,omitempty"`
	PaymentNumber        string             `gorm:"size:64;not null;uniqueIndex:idx_org_customer_payment_number" json:"payment_number"`
	PaymentDate          time.Time          `gorm:"not null;index" json:"payment_date"`
	PaymentMethod        string             `gorm:"size:64" json:"payment_method"`
	Reference            string             `gorm:"size:255" json:"reference"`
	Currency             string             `gorm:"size:3;not null;default:INR" json:"currency"`
	AmountMinor          int64              `gorm:"not null" json:"amount_minor"`
	PaymentAccountID     string             `gorm:"type:char(36);not null" json:"payment_account_id"`
	JournalTransactionID string             `gorm:"type:char(36);not null;index" json:"journal_transaction_id"`
	JournalTransaction   JournalTransaction `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
}

type Vendor struct {
	BaseModel
	OrganizationID string       `gorm:"type:char(36);not null;index" json:"organization_id"`
	Organization   Organization `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	DisplayName    string       `gorm:"size:255;not null;index" json:"display_name"`
	Email          string       `gorm:"size:320" json:"email"`
	Phone          string       `gorm:"size:64" json:"phone"`
	BillingAddress string       `gorm:"size:1000" json:"billing_address"`
	GSTIN          string       `gorm:"size:32" json:"gstin"`
	IsActive       bool         `gorm:"not null;default:true" json:"is_active"`
}

type Attachment struct {
	BaseModel
	OrganizationID string       `gorm:"type:char(36);not null;index" json:"organization_id"`
	Organization   Organization `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	FileName       string       `gorm:"size:255;not null" json:"file_name"`
	ContentType    string       `gorm:"size:255" json:"content_type"`
	StorageDriver  string       `gorm:"size:64;not null;default:local" json:"storage_driver"`
	StorageKey     string       `gorm:"size:1000;not null" json:"storage_key"`
	SizeBytes      int64        `gorm:"not null;default:0" json:"size_bytes"`
	ChecksumSHA256 string       `gorm:"size:64" json:"checksum_sha256,omitempty"`
}

type Expense struct {
	BaseModel
	OrganizationID       string        `gorm:"type:char(36);not null;index" json:"organization_id"`
	Organization         Organization  `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	VendorID             *string       `gorm:"type:char(36);index" json:"vendor_id,omitempty"`
	Vendor               *Vendor       `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"vendor,omitempty"`
	ExpenseNumber        string        `gorm:"size:64;not null;uniqueIndex:idx_org_expense_number" json:"expense_number"`
	ExpenseDate          time.Time     `gorm:"not null;index" json:"expense_date"`
	Status               ExpenseStatus `gorm:"size:32;not null;default:draft;index" json:"status"`
	Currency             string        `gorm:"size:3;not null;default:INR" json:"currency"`
	TaxInclusive         bool          `gorm:"not null;default:false" json:"tax_inclusive"`
	SubtotalMinor        int64         `gorm:"not null;default:0" json:"subtotal_minor"`
	TaxTotalMinor        int64         `gorm:"not null;default:0" json:"tax_total_minor"`
	TotalMinor           int64         `gorm:"not null;default:0" json:"total_minor"`
	ExpenseAccountID     string        `gorm:"type:char(36);not null" json:"expense_account_id"`
	PaymentAccountID     string        `gorm:"type:char(36);not null" json:"payment_account_id"`
	ReceiptAttachmentID  *string       `gorm:"type:char(36)" json:"receipt_attachment_id,omitempty"`
	JournalTransactionID *string       `gorm:"type:char(36);index" json:"journal_transaction_id,omitempty"`
	TaxRateID            *string       `gorm:"type:char(36)" json:"tax_rate_id,omitempty"`
	TaxGroupID           *string       `gorm:"type:char(36)" json:"tax_group_id,omitempty"`
	Reimbursable         bool          `gorm:"not null;default:false" json:"reimbursable"`
}

type Bill struct {
	BaseModel
	OrganizationID       string       `gorm:"type:char(36);not null;index;uniqueIndex:idx_org_bill_number" json:"organization_id"`
	Organization         Organization `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	VendorID             string       `gorm:"type:char(36);not null;index" json:"vendor_id"`
	Vendor               Vendor       `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"vendor,omitempty"`
	BillNumber           string       `gorm:"size:64;not null;uniqueIndex:idx_org_bill_number" json:"bill_number"`
	IssueDate            time.Time    `gorm:"not null;index" json:"issue_date"`
	DueDate              time.Time    `gorm:"not null;index" json:"due_date"`
	Status               BillStatus   `gorm:"size:32;not null;default:draft;index" json:"status"`
	Currency             string       `gorm:"size:3;not null;default:INR" json:"currency"`
	TaxInclusive         bool         `gorm:"not null;default:false" json:"tax_inclusive"`
	SubtotalMinor        int64        `gorm:"not null;default:0" json:"subtotal_minor"`
	TaxTotalMinor        int64        `gorm:"not null;default:0" json:"tax_total_minor"`
	TotalMinor           int64        `gorm:"not null;default:0" json:"total_minor"`
	AccountsPayableID    string       `gorm:"type:char(36);not null" json:"accounts_payable_id"`
	DocumentAttachmentID *string      `gorm:"type:char(36)" json:"document_attachment_id,omitempty"`
	JournalTransactionID *string      `gorm:"type:char(36);index" json:"journal_transaction_id,omitempty"`
	Lines                []BillLine   `gorm:"foreignKey:BillID" json:"lines"`
}

type BillLine struct {
	BaseModel
	OrganizationID    string  `gorm:"type:char(36);not null;index" json:"organization_id"`
	BillID            string  `gorm:"type:char(36);not null;index" json:"bill_id"`
	Bill              Bill    `gorm:"constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"-"`
	Description       string  `gorm:"size:1000;not null" json:"description"`
	QuantityMillis    int64   `gorm:"not null;default:1000" json:"quantity_millis"`
	UnitPriceMinor    int64   `gorm:"not null" json:"unit_price_minor"`
	LineSubtotalMinor int64   `gorm:"not null" json:"line_subtotal_minor"`
	TaxAmountMinor    int64   `gorm:"not null;default:0" json:"tax_amount_minor"`
	LineTotalMinor    int64   `gorm:"not null" json:"line_total_minor"`
	ExpenseAccountID  string  `gorm:"type:char(36);not null" json:"expense_account_id"`
	TaxRateID         *string `gorm:"type:char(36)" json:"tax_rate_id,omitempty"`
	TaxGroupID        *string `gorm:"type:char(36)" json:"tax_group_id,omitempty"`
}

type PurchaseOrder struct {
	BaseModel
	OrganizationID      string              `gorm:"type:char(36);not null;index;uniqueIndex:idx_org_purchase_order_number" json:"organization_id"`
	Organization        Organization        `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	VendorID            string              `gorm:"type:char(36);not null;index" json:"vendor_id"`
	Vendor              Vendor              `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"vendor,omitempty"`
	PurchaseOrderNumber string              `gorm:"size:64;not null;uniqueIndex:idx_org_purchase_order_number" json:"purchase_order_number"`
	IssueDate           time.Time           `gorm:"not null;index" json:"issue_date"`
	ExpectedDate        *time.Time          `json:"expected_date,omitempty"`
	Status              PurchaseOrderStatus `gorm:"size:32;not null;default:draft;index" json:"status"`
	Currency            string              `gorm:"size:3;not null;default:INR" json:"currency"`
	TaxInclusive        bool                `gorm:"not null;default:false" json:"tax_inclusive"`
	SubtotalMinor       int64               `gorm:"not null;default:0" json:"subtotal_minor"`
	TaxTotalMinor       int64               `gorm:"not null;default:0" json:"tax_total_minor"`
	TotalMinor          int64               `gorm:"not null;default:0" json:"total_minor"`
	Lines               []PurchaseOrderLine `gorm:"foreignKey:PurchaseOrderID" json:"lines"`
}

type PurchaseOrderLine struct {
	BaseModel
	OrganizationID    string        `gorm:"type:char(36);not null;index" json:"organization_id"`
	PurchaseOrderID   string        `gorm:"type:char(36);not null;index" json:"purchase_order_id"`
	PurchaseOrder     PurchaseOrder `gorm:"constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"-"`
	Description       string        `gorm:"size:1000;not null" json:"description"`
	QuantityMillis    int64         `gorm:"not null;default:1000" json:"quantity_millis"`
	UnitPriceMinor    int64         `gorm:"not null" json:"unit_price_minor"`
	LineSubtotalMinor int64         `gorm:"not null" json:"line_subtotal_minor"`
	TaxAmountMinor    int64         `gorm:"not null;default:0" json:"tax_amount_minor"`
	LineTotalMinor    int64         `gorm:"not null" json:"line_total_minor"`
	ExpenseAccountID  string        `gorm:"type:char(36);not null" json:"expense_account_id"`
	TaxRateID         *string       `gorm:"type:char(36)" json:"tax_rate_id,omitempty"`
	TaxGroupID        *string       `gorm:"type:char(36)" json:"tax_group_id,omitempty"`
}

type VendorPayment struct {
	BaseModel
	OrganizationID       string             `gorm:"type:char(36);not null;index" json:"organization_id"`
	Organization         Organization       `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	BillID               string             `gorm:"type:char(36);not null;index" json:"bill_id"`
	Bill                 Bill               `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"bill,omitempty"`
	PaymentNumber        string             `gorm:"size:64;not null;uniqueIndex:idx_org_vendor_payment_number" json:"payment_number"`
	PaymentDate          time.Time          `gorm:"not null;index" json:"payment_date"`
	PaymentMethod        string             `gorm:"size:64" json:"payment_method"`
	Reference            string             `gorm:"size:255" json:"reference"`
	Currency             string             `gorm:"size:3;not null;default:INR" json:"currency"`
	AmountMinor          int64              `gorm:"not null" json:"amount_minor"`
	PaymentAccountID     string             `gorm:"type:char(36);not null" json:"payment_account_id"`
	JournalTransactionID string             `gorm:"type:char(36);not null;index" json:"journal_transaction_id"`
	JournalTransaction   JournalTransaction `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
}

type Employee struct {
	BaseModel
	OrganizationID string       `gorm:"type:char(36);not null;index" json:"organization_id"`
	Organization   Organization `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	DisplayName    string       `gorm:"size:255;not null;index" json:"display_name"`
	Email          string       `gorm:"size:320" json:"email"`
	Phone          string       `gorm:"size:64" json:"phone"`
	EmployeeCode   string       `gorm:"size:64;uniqueIndex:idx_org_employee_code" json:"employee_code"`
	PAN            string       `gorm:"size:32" json:"pan"`
	UAN            string       `gorm:"size:32" json:"uan"`
	IsActive       bool         `gorm:"not null;default:true" json:"is_active"`
}

type PayrollRun struct {
	BaseModel
	OrganizationID              string           `gorm:"type:char(36);not null;index" json:"organization_id"`
	Organization                Organization     `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	RunNumber                   string           `gorm:"size:64;not null;uniqueIndex:idx_org_payroll_run_number" json:"run_number"`
	PeriodStart                 time.Time        `gorm:"not null" json:"period_start"`
	PeriodEnd                   time.Time        `gorm:"not null" json:"period_end"`
	PayDate                     time.Time        `gorm:"not null" json:"pay_date"`
	Status                      PayrollRunStatus `gorm:"size:32;not null;default:draft;index" json:"status"`
	Currency                    string           `gorm:"size:3;not null;default:INR" json:"currency"`
	PayrollExpenseAccountID     string           `gorm:"type:char(36);not null" json:"payroll_expense_account_id"`
	PayrollLiabilityAccountID   string           `gorm:"type:char(36);not null" json:"payroll_liability_account_id"`
	DeductionLiabilityAccountID string           `gorm:"type:char(36);not null" json:"deduction_liability_account_id"`
	EmployerExpenseAccountID    string           `gorm:"type:char(36)" json:"employer_expense_account_id,omitempty"`
	EmployerLiabilityAccountID  string           `gorm:"type:char(36)" json:"employer_liability_account_id,omitempty"`
	GrossPayMinor               int64            `gorm:"not null;default:0" json:"gross_pay_minor"`
	DeductionsMinor             int64            `gorm:"not null;default:0" json:"deductions_minor"`
	NetPayMinor                 int64            `gorm:"not null;default:0" json:"net_pay_minor"`
	EmployerContributionsMinor  int64            `gorm:"not null;default:0" json:"employer_contributions_minor"`
	PayrollCostMinor            int64            `gorm:"not null;default:0" json:"payroll_cost_minor"`
	JournalTransactionID        *string          `gorm:"type:char(36);index" json:"journal_transaction_id,omitempty"`
	Items                       []PayrollItem    `gorm:"foreignKey:PayrollRunID" json:"items"`
}

type PayrollItem struct {
	BaseModel
	OrganizationID  string             `gorm:"type:char(36);not null;index" json:"organization_id"`
	PayrollRunID    string             `gorm:"type:char(36);not null;index" json:"payroll_run_id"`
	PayrollRun      PayrollRun         `gorm:"constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"-"`
	EmployeeID      string             `gorm:"type:char(36);not null;index" json:"employee_id"`
	Employee        Employee           `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"employee,omitempty"`
	GrossPayMinor   int64              `gorm:"not null" json:"gross_pay_minor"`
	DeductionsMinor int64              `gorm:"not null;default:0" json:"deductions_minor"`
	NetPayMinor     int64              `gorm:"not null" json:"net_pay_minor"`
	PayslipKey      string             `gorm:"size:1000" json:"payslip_key"`
	Components      []PayrollComponent `gorm:"foreignKey:PayrollItemID" json:"components,omitempty"`
}

type PayrollComponent struct {
	BaseModel
	OrganizationID string               `gorm:"type:char(36);not null;index" json:"organization_id"`
	PayrollItemID  string               `gorm:"type:char(36);not null;index" json:"payroll_item_id"`
	PayrollItem    PayrollItem          `gorm:"constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"-"`
	Code           string               `gorm:"size:64;not null;index" json:"code"`
	Name           string               `gorm:"size:255;not null" json:"name"`
	Type           PayrollComponentType `gorm:"size:32;not null;index" json:"type"`
	AmountMinor    int64                `gorm:"not null" json:"amount_minor"`
	IsStatutory    bool                 `gorm:"not null;default:false" json:"is_statutory"`
}

type ScheduledReport struct {
	BaseModel
	OrganizationID  string                   `gorm:"type:char(36);not null;index" json:"organization_id"`
	Organization    Organization             `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Name            string                   `gorm:"size:255;not null;index" json:"name"`
	ReportType      ScheduledReportType      `gorm:"size:64;not null;index" json:"report_type"`
	Frequency       ScheduledReportFrequency `gorm:"size:32;not null;index" json:"frequency"`
	ParametersJSON  string                   `gorm:"type:text" json:"parameters_json"`
	EmailRecipients string                   `gorm:"type:text" json:"email_recipients,omitempty"`
	NextRunAt       time.Time                `gorm:"not null;index" json:"next_run_at"`
	LastRunAt       *time.Time               `json:"last_run_at,omitempty"`
	IsActive        bool                     `gorm:"not null;default:true;index" json:"is_active"`
	Runs            []ScheduledReportRun     `gorm:"foreignKey:ScheduledReportID" json:"runs,omitempty"`
}

type ScheduledReportRun struct {
	BaseModel
	OrganizationID    string                   `gorm:"type:char(36);not null;index" json:"organization_id"`
	ScheduledReportID string                   `gorm:"type:char(36);not null;index" json:"scheduled_report_id"`
	ScheduledReport   ScheduledReport          `gorm:"constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"-"`
	ReportType        ScheduledReportType      `gorm:"size:64;not null;index" json:"report_type"`
	Status            ScheduledReportRunStatus `gorm:"size:32;not null;index" json:"status"`
	PeriodStart       *time.Time               `json:"period_start,omitempty"`
	PeriodEnd         *time.Time               `json:"period_end,omitempty"`
	AsOfDate          *time.Time               `json:"as_of_date,omitempty"`
	ReportJSON        string                   `gorm:"type:longtext" json:"report_json,omitempty"`
	ErrorMessage      string                   `gorm:"size:1000" json:"error_message,omitempty"`
}

type BankStatementImport struct {
	BaseModel
	OrganizationID string              `gorm:"type:char(36);not null;index" json:"organization_id"`
	Organization   Organization        `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	AccountID      string              `gorm:"type:char(36);not null;index" json:"account_id"`
	Account        Account             `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	FileName       string              `gorm:"size:255" json:"file_name"`
	Format         string              `gorm:"size:32;not null;default:csv" json:"format"`
	Status         BankImportStatus    `gorm:"size:32;not null;default:completed" json:"status"`
	LineCount      int                 `gorm:"not null;default:0" json:"line_count"`
	ErrorMessage   string              `gorm:"size:1000" json:"error_message"`
	Lines          []BankStatementLine `gorm:"foreignKey:ImportID" json:"lines"`
}

type BankStatementLine struct {
	BaseModel
	OrganizationID string              `gorm:"type:char(36);not null;index" json:"organization_id"`
	ImportID       string              `gorm:"type:char(36);not null;index" json:"import_id"`
	Import         BankStatementImport `gorm:"constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"-"`
	AccountID      string              `gorm:"type:char(36);not null;index" json:"account_id"`
	PostedDate     time.Time           `gorm:"not null;index" json:"posted_date"`
	Description    string              `gorm:"size:1000" json:"description"`
	AmountMinor    int64               `gorm:"not null" json:"amount_minor"`
	Reference      string              `gorm:"size:255;index" json:"reference"`
	IsDuplicate    bool                `gorm:"not null;default:false;index" json:"is_duplicate"`
	DuplicateOfID  *string             `gorm:"type:char(36);index" json:"duplicate_of_id,omitempty"`
	DuplicateOf    *BankStatementLine  `gorm:"constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	MatchedSplitID *string             `gorm:"type:char(36);index" json:"matched_split_id,omitempty"`
	MatchedAt      *time.Time          `json:"matched_at,omitempty"`
}

type Budget struct {
	BaseModel
	OrganizationID string       `gorm:"type:char(36);not null;index" json:"organization_id"`
	Organization   Organization `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Name           string       `gorm:"size:255;not null;uniqueIndex:idx_org_budget_name" json:"name"`
	StartDate      time.Time    `gorm:"not null;index" json:"start_date"`
	EndDate        time.Time    `gorm:"not null;index" json:"end_date"`
	Status         BudgetStatus `gorm:"size:32;not null;default:active" json:"status"`
	Lines          []BudgetLine `gorm:"foreignKey:BudgetID" json:"lines"`
}

type BudgetLine struct {
	BaseModel
	OrganizationID string    `gorm:"type:char(36);not null;index" json:"organization_id"`
	BudgetID       string    `gorm:"type:char(36);not null;index" json:"budget_id"`
	Budget         Budget    `gorm:"constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"-"`
	AccountID      string    `gorm:"type:char(36);not null;index" json:"account_id"`
	Account        Account   `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"account,omitempty"`
	PeriodStart    time.Time `gorm:"not null;index" json:"period_start"`
	PeriodEnd      time.Time `gorm:"not null;index" json:"period_end"`
	AmountMinor    int64     `gorm:"not null" json:"amount_minor"`
}

type ExchangeRate struct {
	BaseModel
	OrganizationID string       `gorm:"type:char(36);not null;index;uniqueIndex:idx_org_rate_pair_date" json:"organization_id"`
	Organization   Organization `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	FromCurrency   string       `gorm:"size:3;not null;uniqueIndex:idx_org_rate_pair_date" json:"from_currency"`
	ToCurrency     string       `gorm:"size:3;not null;uniqueIndex:idx_org_rate_pair_date" json:"to_currency"`
	RateDate       time.Time    `gorm:"not null;uniqueIndex:idx_org_rate_pair_date" json:"rate_date"`
	Numerator      int64        `gorm:"not null" json:"numerator"`
	Denominator    int64        `gorm:"not null" json:"denominator"`
	Source         string       `gorm:"size:255" json:"source"`
}

type InvestmentLot struct {
	BaseModel
	OrganizationID          string               `gorm:"type:char(36);not null;index" json:"organization_id"`
	Organization            Organization         `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	AccountID               string               `gorm:"type:char(36);not null;index" json:"account_id"`
	Account                 Account              `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"account,omitempty"`
	Symbol                  string               `gorm:"size:64;not null;index" json:"symbol"`
	SecurityName            string               `gorm:"size:255" json:"security_name"`
	AcquisitionDate         time.Time            `gorm:"not null;index" json:"acquisition_date"`
	QuantityMillis          int64                `gorm:"not null" json:"quantity_millis"`
	RemainingQuantityMillis int64                `gorm:"not null;index" json:"remaining_quantity_millis"`
	CostBasisMinor          int64                `gorm:"not null" json:"cost_basis_minor"`
	Currency                string               `gorm:"size:3;not null;default:INR" json:"currency"`
	CostMethod              InvestmentCostMethod `gorm:"size:32;not null;default:specific_lot" json:"cost_method"`
	Notes                   string               `gorm:"size:1000" json:"notes"`
}

type InvestmentDisposition struct {
	BaseModel
	OrganizationID          string              `gorm:"type:char(36);not null;index" json:"organization_id"`
	Organization            Organization        `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	InvestmentLotID         string              `gorm:"type:char(36);not null;index" json:"investment_lot_id"`
	InvestmentLot           InvestmentLot       `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"lot,omitempty"`
	SaleDate                time.Time           `gorm:"not null;index" json:"sale_date"`
	QuantityMillis          int64               `gorm:"not null" json:"quantity_millis"`
	ProceedsMinor           int64               `gorm:"not null" json:"proceeds_minor"`
	AllocatedCostBasisMinor int64               `gorm:"not null" json:"allocated_cost_basis_minor"`
	RealizedGainLossMinor   int64               `gorm:"not null" json:"realized_gain_loss_minor"`
	Currency                string              `gorm:"size:3;not null;default:INR" json:"currency"`
	JournalTransactionID    *string             `gorm:"type:char(36);index" json:"journal_transaction_id,omitempty"`
	JournalTransaction      *JournalTransaction `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Notes                   string              `gorm:"size:1000" json:"notes"`
}

type InvestmentDividend struct {
	BaseModel
	OrganizationID       string              `gorm:"type:char(36);not null;index" json:"organization_id"`
	Organization         Organization        `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	AccountID            string              `gorm:"type:char(36);not null;index" json:"account_id"`
	Account              Account             `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"account,omitempty"`
	Symbol               string              `gorm:"size:64;not null;index" json:"symbol"`
	DividendDate         time.Time           `gorm:"not null;index" json:"dividend_date"`
	AmountMinor          int64               `gorm:"not null" json:"amount_minor"`
	Currency             string              `gorm:"size:3;not null;default:INR" json:"currency"`
	CashAccountID        string              `gorm:"type:char(36)" json:"cash_account_id,omitempty"`
	IncomeAccountID      string              `gorm:"type:char(36)" json:"income_account_id,omitempty"`
	JournalTransactionID *string             `gorm:"type:char(36);index" json:"journal_transaction_id,omitempty"`
	JournalTransaction   *JournalTransaction `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Notes                string              `gorm:"size:1000" json:"notes"`
}

type InvestmentCorporateActionType string

const (
	InvestmentCorporateActionSplit InvestmentCorporateActionType = "split"
	InvestmentCorporateActionBonus InvestmentCorporateActionType = "bonus"
)

type InvestmentCorporateAction struct {
	BaseModel
	OrganizationID      string                        `gorm:"type:char(36);not null;index" json:"organization_id"`
	Organization        Organization                  `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	AccountID           string                        `gorm:"type:char(36);not null;index" json:"account_id"`
	Account             Account                       `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"account,omitempty"`
	Symbol              string                        `gorm:"size:64;not null;index" json:"symbol"`
	ActionType          InvestmentCorporateActionType `gorm:"size:32;not null;index" json:"action_type"`
	ActionDate          time.Time                     `gorm:"not null;index" json:"action_date"`
	RatioNumerator      int64                         `gorm:"not null" json:"ratio_numerator"`
	RatioDenominator    int64                         `gorm:"not null" json:"ratio_denominator"`
	AffectedLots        int64                         `gorm:"not null" json:"affected_lots"`
	QuantityDeltaMillis int64                         `gorm:"not null" json:"quantity_delta_millis"`
	CostBasisDeltaMinor int64                         `gorm:"not null" json:"cost_basis_delta_minor"`
	Notes               string                        `gorm:"size:1000" json:"notes"`
}

type InvestmentPrice struct {
	BaseModel
	OrganizationID string       `gorm:"type:char(36);not null;index;uniqueIndex:idx_org_symbol_price_date" json:"organization_id"`
	Organization   Organization `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Symbol         string       `gorm:"size:64;not null;index;uniqueIndex:idx_org_symbol_price_date" json:"symbol"`
	PriceDate      time.Time    `gorm:"not null;index;uniqueIndex:idx_org_symbol_price_date" json:"price_date"`
	PriceMinor     int64        `gorm:"not null" json:"price_minor"`
	Currency       string       `gorm:"size:3;not null;default:INR" json:"currency"`
	Source         string       `gorm:"size:255" json:"source"`
}

type FiscalClose struct {
	BaseModel
	OrganizationID            string            `gorm:"type:char(36);not null;index" json:"organization_id"`
	Organization              Organization      `gorm:"constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	FiscalYearStart           time.Time         `gorm:"not null;index;uniqueIndex:idx_org_fiscal_close_period" json:"fiscal_year_start"`
	FiscalYearEnd             time.Time         `gorm:"not null;index;uniqueIndex:idx_org_fiscal_close_period" json:"fiscal_year_end"`
	RetainedEarningsAccountID string            `gorm:"type:char(36);not null" json:"retained_earnings_account_id"`
	NetIncomeMinor            int64             `gorm:"not null" json:"net_income_minor"`
	Status                    FiscalCloseStatus `gorm:"size:32;not null;default:posted" json:"status"`
	JournalTransactionID      string            `gorm:"type:char(36);not null;index" json:"journal_transaction_id"`
}

var (
	ErrJournalRequiresSplits = errors.New("journal transaction requires at least two splits")
	ErrSplitHasBothSides     = errors.New("ledger split cannot contain both debit and credit")
	ErrSplitHasNoAmount      = errors.New("ledger split must contain either debit or credit")
	ErrJournalNotBalanced    = errors.New("journal transaction debits and credits must balance")
	ErrLedgerAccountScope    = errors.New("all ledger split accounts must belong to the transaction organization")
	ErrTenantScope           = errors.New("referenced records must belong to the organization")
)

func (tx JournalTransaction) ValidateBalanced() error {
	if len(tx.Splits) < 2 {
		return ErrJournalRequiresSplits
	}

	var debits int64
	var credits int64
	var baseDebits int64
	var baseCredits int64
	hasBaseAmounts := false
	for _, split := range tx.Splits {
		if split.DebitMinor > 0 && split.CreditMinor > 0 {
			return ErrSplitHasBothSides
		}
		if split.DebitMinor == 0 && split.CreditMinor == 0 {
			return ErrSplitHasNoAmount
		}

		debits += split.DebitMinor
		credits += split.CreditMinor
		baseDebits += split.BaseDebitMinor
		baseCredits += split.BaseCreditMinor
		if split.BaseDebitMinor != 0 || split.BaseCreditMinor != 0 {
			hasBaseAmounts = true
		}
	}

	if hasBaseAmounts {
		if baseDebits != baseCredits {
			return ErrJournalNotBalanced
		}
		return nil
	}

	if debits != credits {
		return ErrJournalNotBalanced
	}
	return nil
}

func AllModels() []any {
	return []any{
		&Organization{},
		&User{},
		&OrganizationMembership{},
		&RefreshToken{},
		&PasswordResetToken{},
		&MFARecoveryCode{},
		&BackupSnapshot{},
		&Account{},
		&JournalTransaction{},
		&LedgerSplit{},
		&AuditLog{},
		&TaxAuthority{},
		&TaxRate{},
		&TaxGroup{},
		&TaxGroupComponent{},
		&Customer{},
		&Invoice{},
		&InvoiceLine{},
		&RecurringInvoiceTemplate{},
		&RecurringInvoiceLine{},
		&Estimate{},
		&EstimateLine{},
		&CreditNote{},
		&CreditNoteLine{},
		&CustomerPayment{},
		&Vendor{},
		&Attachment{},
		&Expense{},
		&Bill{},
		&BillLine{},
		&PurchaseOrder{},
		&PurchaseOrderLine{},
		&VendorPayment{},
		&Employee{},
		&PayrollRun{},
		&PayrollItem{},
		&PayrollComponent{},
		&ScheduledReport{},
		&ScheduledReportRun{},
		&BankStatementImport{},
		&BankStatementLine{},
		&Budget{},
		&BudgetLine{},
		&ExchangeRate{},
		&InvestmentLot{},
		&InvestmentDisposition{},
		&InvestmentDividend{},
		&InvestmentCorporateAction{},
		&InvestmentPrice{},
		&FiscalClose{},
	}
}
