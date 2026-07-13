package services

import (
	"context"
	"errors"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

var (
	ErrBudgetHasNoLines   = errors.New("budget must contain at least one line")
	ErrBudgetAccountScope = errors.New("budget accounts must belong to the organization")
)

type BudgetService struct {
	db *gorm.DB
}

type CreateBudgetInput struct {
	OrganizationID string
	Name           string
	StartDate      time.Time
	EndDate        time.Time
	Status         domain.BudgetStatus
	Lines          []CreateBudgetLineInput
}

type CreateBudgetLineInput struct {
	AccountID   string
	PeriodStart time.Time
	PeriodEnd   time.Time
	AmountMinor int64
}

type BudgetVsActualReport struct {
	BudgetID string                    `json:"budget_id"`
	Rows     []BudgetVsActualReportRow `json:"rows"`
}

type BudgetVsActualReportRow struct {
	AccountID            string    `json:"account_id"`
	AccountCode          string    `json:"account_code"`
	AccountName          string    `json:"account_name"`
	PeriodStart          time.Time `json:"period_start"`
	PeriodEnd            time.Time `json:"period_end"`
	BudgetMinor          int64     `json:"budget_minor"`
	ActualMinor          int64     `json:"actual_minor"`
	VarianceMinor        int64     `json:"variance_minor"`
	VariancePercentBasis int64     `json:"variance_percent_basis"`
}

func NewBudgetService(db *gorm.DB) BudgetService {
	return BudgetService{db: db}
}

func (s BudgetService) List(ctx context.Context, organizationID string) ([]domain.Budget, error) {
	var budgets []domain.Budget
	err := s.db.WithContext(ctx).
		Preload("Lines.Account").
		Where("organization_id = ?", organizationID).
		Order("start_date DESC, created_at DESC").
		Find(&budgets).
		Error
	return budgets, err
}

func (s BudgetService) Create(ctx context.Context, input CreateBudgetInput) (domain.Budget, error) {
	if len(input.Lines) == 0 {
		return domain.Budget{}, ErrBudgetHasNoLines
	}

	status := input.Status
	if status == "" {
		status = domain.BudgetStatusActive
	}

	budget := domain.Budget{
		OrganizationID: input.OrganizationID,
		Name:           input.Name,
		StartDate:      input.StartDate,
		EndDate:        input.EndDate,
		Status:         status,
		Lines:          make([]domain.BudgetLine, 0, len(input.Lines)),
	}
	for _, line := range input.Lines {
		budget.Lines = append(budget.Lines, domain.BudgetLine{
			OrganizationID: input.OrganizationID,
			AccountID:      line.AccountID,
			PeriodStart:    line.PeriodStart,
			PeriodEnd:      line.PeriodEnd,
			AmountMinor:    line.AmountMinor,
		})
	}

	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := validateBudgetAccountScope(ctx, tx, input.OrganizationID, budget.Lines); err != nil {
			return err
		}
		return tx.Create(&budget).Error
	})
	return budget, err
}

func (s BudgetService) BudgetVsActual(ctx context.Context, organizationID string, budgetID string) (BudgetVsActualReport, error) {
	var budget domain.Budget
	if err := s.db.WithContext(ctx).
		Preload("Lines.Account").
		Where("organization_id = ? AND id = ?", organizationID, budgetID).
		First(&budget).
		Error; err != nil {
		return BudgetVsActualReport{}, err
	}

	report := BudgetVsActualReport{BudgetID: budget.ID, Rows: make([]BudgetVsActualReportRow, 0, len(budget.Lines))}
	for _, line := range budget.Lines {
		actual, err := s.accountActual(ctx, organizationID, line.Account, line.PeriodStart, line.PeriodEnd)
		if err != nil {
			return BudgetVsActualReport{}, err
		}
		variance := actual - line.AmountMinor
		var varianceBasis int64
		if line.AmountMinor != 0 {
			varianceBasis = roundDiv(variance*1000000, line.AmountMinor)
		}

		report.Rows = append(report.Rows, BudgetVsActualReportRow{
			AccountID:            line.AccountID,
			AccountCode:          line.Account.Code,
			AccountName:          line.Account.Name,
			PeriodStart:          line.PeriodStart,
			PeriodEnd:            line.PeriodEnd,
			BudgetMinor:          line.AmountMinor,
			ActualMinor:          actual,
			VarianceMinor:        variance,
			VariancePercentBasis: varianceBasis,
		})
	}
	return report, nil
}

func (s BudgetService) accountActual(ctx context.Context, organizationID string, account domain.Account, from time.Time, to time.Time) (int64, error) {
	var splits []domain.LedgerSplit
	if err := s.db.WithContext(ctx).
		Joins("JOIN journal_transactions ON journal_transactions.id = ledger_splits.journal_transaction_id").
		Where("ledger_splits.organization_id = ? AND ledger_splits.account_id = ?", organizationID, account.ID).
		Where("journal_transactions.status = ?", domain.JournalStatusPosted).
		Where("journal_transactions.transaction_date >= ? AND journal_transactions.transaction_date <= ?", from, to).
		Find(&splits).
		Error; err != nil {
		return 0, err
	}

	var debit int64
	var credit int64
	for _, split := range splits {
		debit += effectiveDebitMinor(split)
		credit += effectiveCreditMinor(split)
	}
	if account.Type == domain.AccountTypeIncome || account.Type == domain.AccountTypeLiability || account.Type == domain.AccountTypeEquity {
		return credit - debit, nil
	}
	return debit - credit, nil
}

func validateBudgetAccountScope(ctx context.Context, tx *gorm.DB, organizationID string, lines []domain.BudgetLine) error {
	accountIDs := make([]string, 0, len(lines))
	for _, line := range lines {
		accountIDs = append(accountIDs, line.AccountID)
	}

	var count int64
	if err := tx.WithContext(ctx).Model(&domain.Account{}).Where("organization_id = ? AND id IN ?", organizationID, accountIDs).Count(&count).Error; err != nil {
		return err
	}
	if count != int64(len(uniqueStrings(accountIDs))) {
		return ErrBudgetAccountScope
	}
	return nil
}
