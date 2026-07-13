package services

import (
	"context"
	"errors"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

var (
	ErrCloseAccountScope = errors.New("retained earnings account must belong to the organization")
	ErrCloseNoBalances   = errors.New("no income or expense balances found to close")
)

type ClosingService struct {
	db *gorm.DB
}

type CloseFiscalYearInput struct {
	OrganizationID            string
	FiscalYearStart           time.Time
	FiscalYearEnd             time.Time
	RetainedEarningsAccountID string
}

func NewClosingService(db *gorm.DB) ClosingService {
	return ClosingService{db: db}
}

func (s ClosingService) List(ctx context.Context, organizationID string) ([]domain.FiscalClose, error) {
	var closes []domain.FiscalClose
	err := s.db.WithContext(ctx).
		Where("organization_id = ?", organizationID).
		Order("fiscal_year_end DESC").
		Find(&closes).
		Error
	return closes, err
}

func (s ClosingService) CloseFiscalYear(ctx context.Context, input CloseFiscalYearInput) (domain.FiscalClose, error) {
	var fiscalClose domain.FiscalClose
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := validateAccountScope(ctx, tx, input.OrganizationID, input.RetainedEarningsAccountID); err != nil {
			return ErrCloseAccountScope
		}

		activities, err := NewReportService(tx).accountActivities(ctx, input.OrganizationID, &input.FiscalYearStart, &input.FiscalYearEnd, []domain.AccountType{
			domain.AccountTypeIncome,
			domain.AccountTypeExpense,
		})
		if err != nil {
			return err
		}
		if len(activities) == 0 {
			return ErrCloseNoBalances
		}

		splits := make([]domain.LedgerSplit, 0, len(activities)+1)
		var netIncome int64
		for _, activity := range activities {
			row := activity.toReportRow()
			if row.BalanceMinor == 0 {
				continue
			}
			switch activity.AccountType {
			case domain.AccountTypeIncome:
				netIncome += row.BalanceMinor
				splits = append(splits, domain.LedgerSplit{
					OrganizationID: input.OrganizationID,
					AccountID:      activity.AccountID,
					DebitMinor:     row.BalanceMinor,
					Currency:       "INR",
				})
			case domain.AccountTypeExpense:
				netIncome -= row.BalanceMinor
				splits = append(splits, domain.LedgerSplit{
					OrganizationID: input.OrganizationID,
					AccountID:      activity.AccountID,
					CreditMinor:    row.BalanceMinor,
					Currency:       "INR",
				})
			}
		}
		if len(splits) == 0 {
			return ErrCloseNoBalances
		}

		if netIncome >= 0 {
			splits = append(splits, domain.LedgerSplit{
				OrganizationID: input.OrganizationID,
				AccountID:      input.RetainedEarningsAccountID,
				CreditMinor:    netIncome,
				Currency:       "INR",
			})
		} else {
			splits = append(splits, domain.LedgerSplit{
				OrganizationID: input.OrganizationID,
				AccountID:      input.RetainedEarningsAccountID,
				DebitMinor:     -netIncome,
				Currency:       "INR",
			})
		}

		now := time.Now().UTC()
		transaction := domain.JournalTransaction{
			OrganizationID:  input.OrganizationID,
			TransactionDate: input.FiscalYearEnd,
			Memo:            "Fiscal year closing entry",
			SourceModule:    domain.SourceModuleClosing,
			Status:          domain.JournalStatusPosted,
			PostedAt:        &now,
			Splits:          splits,
		}
		if err := transaction.ValidateBalanced(); err != nil {
			return err
		}
		if err := validateSplitAccounts(ctx, tx, input.OrganizationID, transaction.Splits); err != nil {
			return err
		}
		if err := tx.Create(&transaction).Error; err != nil {
			return err
		}

		fiscalClose = domain.FiscalClose{
			OrganizationID:            input.OrganizationID,
			FiscalYearStart:           input.FiscalYearStart,
			FiscalYearEnd:             input.FiscalYearEnd,
			RetainedEarningsAccountID: input.RetainedEarningsAccountID,
			NetIncomeMinor:            netIncome,
			Status:                    domain.FiscalCloseStatusPosted,
			JournalTransactionID:      transaction.ID,
		}
		if err := tx.Create(&fiscalClose).Error; err != nil {
			return err
		}
		return recordAuditWithTx(ctx, tx, RecordAuditInput{
			OrganizationID: fiscalClose.OrganizationID,
			EntityType:     "fiscal_close",
			EntityID:       fiscalClose.ID,
			Action:         "post",
			After:          fiscalClose,
		})
	})
	return fiscalClose, err
}
