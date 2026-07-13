package services

import (
	"context"
	"errors"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

type LedgerService struct {
	db *gorm.DB
}

type PostJournalTransactionInput struct {
	OrganizationID  string
	TransactionDate time.Time
	Memo            string
	SourceModule    domain.SourceModule
	PostedByUserID  *string
	Splits          []PostLedgerSplitInput
}

type PostLedgerSplitInput struct {
	AccountID               string
	Memo                    string
	DebitMinor              int64
	CreditMinor             int64
	BaseDebitMinor          int64
	BaseCreditMinor         int64
	Currency                string
	ExchangeRateNumerator   int64
	ExchangeRateDenominator int64
}

func NewLedgerService(db *gorm.DB) LedgerService {
	return LedgerService{db: db}
}

func (s LedgerService) ListTransactions(ctx context.Context, organizationID string) ([]domain.JournalTransaction, error) {
	var transactions []domain.JournalTransaction
	err := s.db.WithContext(ctx).
		Preload("Splits").
		Where("organization_id = ?", organizationID).
		Order("transaction_date DESC, created_at DESC").
		Find(&transactions).
		Error
	return transactions, err
}

func (s LedgerService) PostTransaction(ctx context.Context, input PostJournalTransactionInput) (domain.JournalTransaction, error) {
	now := time.Now().UTC()
	sourceModule := input.SourceModule
	if sourceModule == "" {
		sourceModule = domain.SourceModuleManual
	}

	transaction := domain.JournalTransaction{
		OrganizationID:  input.OrganizationID,
		TransactionDate: input.TransactionDate,
		Memo:            input.Memo,
		SourceModule:    sourceModule,
		Status:          domain.JournalStatusPosted,
		PostedAt:        &now,
		PostedByUserID:  input.PostedByUserID,
		Splits:          make([]domain.LedgerSplit, 0, len(input.Splits)),
	}

	for _, splitInput := range input.Splits {
		currency := splitInput.Currency
		if currency == "" {
			currency = "INR"
		}

		transaction.Splits = append(transaction.Splits, domain.LedgerSplit{
			OrganizationID:          input.OrganizationID,
			AccountID:               splitInput.AccountID,
			Memo:                    splitInput.Memo,
			DebitMinor:              splitInput.DebitMinor,
			CreditMinor:             splitInput.CreditMinor,
			BaseDebitMinor:          splitInput.BaseDebitMinor,
			BaseCreditMinor:         splitInput.BaseCreditMinor,
			Currency:                currency,
			ExchangeRateNumerator:   defaultInt64(splitInput.ExchangeRateNumerator, 1),
			ExchangeRateDenominator: defaultInt64(splitInput.ExchangeRateDenominator, 1),
		})
	}

	if err := transaction.ValidateBalanced(); err != nil {
		return domain.JournalTransaction{}, err
	}

	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := validateSplitAccounts(ctx, tx, input.OrganizationID, transaction.Splits); err != nil {
			return err
		}
		return tx.Create(&transaction).Error
	})
	return transaction, err
}

func defaultInt64(value int64, fallback int64) int64 {
	if value == 0 {
		return fallback
	}
	return value
}

func (s LedgerService) AccountRegister(ctx context.Context, organizationID string, accountID string) ([]domain.LedgerSplit, error) {
	var splits []domain.LedgerSplit
	err := s.db.WithContext(ctx).
		Joins("JOIN journal_transactions ON journal_transactions.id = ledger_splits.journal_transaction_id").
		Where("ledger_splits.organization_id = ? AND ledger_splits.account_id = ?", organizationID, accountID).
		Where("journal_transactions.status = ?", domain.JournalStatusPosted).
		Order("journal_transactions.transaction_date ASC, ledger_splits.created_at ASC").
		Find(&splits).
		Error
	return splits, err
}

func validateSplitAccounts(ctx context.Context, tx *gorm.DB, organizationID string, splits []domain.LedgerSplit) error {
	accountIDs := make([]string, 0, len(splits))
	seen := make(map[string]struct{}, len(splits))
	for _, split := range splits {
		if _, exists := seen[split.AccountID]; exists {
			continue
		}
		seen[split.AccountID] = struct{}{}
		accountIDs = append(accountIDs, split.AccountID)
	}

	var count int64
	if err := tx.WithContext(ctx).
		Model(&domain.Account{}).
		Where("organization_id = ? AND id IN ?", organizationID, accountIDs).
		Count(&count).
		Error; err != nil {
		return err
	}

	if count != int64(len(accountIDs)) {
		return domain.ErrLedgerAccountScope
	}
	return nil
}

func IsLedgerValidationError(err error) bool {
	return errors.Is(err, domain.ErrJournalRequiresSplits) ||
		errors.Is(err, domain.ErrSplitHasBothSides) ||
		errors.Is(err, domain.ErrSplitHasNoAmount) ||
		errors.Is(err, domain.ErrJournalNotBalanced) ||
		errors.Is(err, domain.ErrLedgerAccountScope)
}
