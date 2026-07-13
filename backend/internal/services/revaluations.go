package services

import (
	"context"
	"errors"
	"fmt"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

var (
	ErrRevaluationMissingRate     = errors.New("missing exchange rate for revaluation")
	ErrRevaluationNoAdjustments   = errors.New("no revaluation adjustments to post")
	ErrRevaluationGainLossAccount = errors.New("gain/loss account must belong to the organization")
)

type RevaluationService struct {
	db *gorm.DB
}

type RevaluationPreview struct {
	AsOfDate             time.Time        `json:"as_of_date"`
	BaseCurrency         string           `json:"base_currency"`
	Rows                 []RevaluationRow `json:"rows"`
	TotalAdjustmentMinor int64            `json:"total_adjustment_minor"`
}

type RevaluationRow struct {
	AccountID               string `json:"account_id"`
	AccountCode             string `json:"account_code"`
	AccountName             string `json:"account_name"`
	Currency                string `json:"currency"`
	ForeignBalanceMinor     int64  `json:"foreign_balance_minor"`
	CarryingBaseMinor       int64  `json:"carrying_base_minor"`
	RevaluedBaseMinor       int64  `json:"revalued_base_minor"`
	AdjustmentMinor         int64  `json:"adjustment_minor"`
	ExchangeRateNumerator   int64  `json:"exchange_rate_numerator"`
	ExchangeRateDenominator int64  `json:"exchange_rate_denominator"`
}

type PostRevaluationInput struct {
	OrganizationID    string
	AsOfDate          time.Time
	GainLossAccountID string
	PostedByUserID    *string
}

func NewRevaluationService(db *gorm.DB) RevaluationService {
	return RevaluationService{db: db}
}

func (s RevaluationService) Preview(ctx context.Context, organizationID string, asOf time.Time) (RevaluationPreview, error) {
	var org domain.Organization
	if err := s.db.WithContext(ctx).Where("id = ?", organizationID).First(&org).Error; err != nil {
		return RevaluationPreview{}, err
	}

	var splits []domain.LedgerSplit
	if err := s.db.WithContext(ctx).
		Preload("Account").
		Joins("JOIN journal_transactions ON journal_transactions.id = ledger_splits.journal_transaction_id").
		Where("ledger_splits.organization_id = ?", organizationID).
		Where("journal_transactions.status = ?", domain.JournalStatusPosted).
		Where("journal_transactions.transaction_date <= ?", asOf).
		Find(&splits).Error; err != nil {
		return RevaluationPreview{}, err
	}

	type balanceKey struct {
		accountID string
		currency  string
	}
	type balance struct {
		account           domain.Account
		foreignMinor      int64
		carryingBaseMinor int64
	}

	balances := map[balanceKey]balance{}
	for _, split := range splits {
		if split.Currency == "" || split.Currency == org.BaseCurrency {
			continue
		}
		key := balanceKey{accountID: split.AccountID, currency: split.Currency}
		current := balances[key]
		current.account = split.Account
		current.foreignMinor += split.DebitMinor - split.CreditMinor
		current.carryingBaseMinor += split.BaseDebitMinor - split.BaseCreditMinor
		balances[key] = current
	}

	preview := RevaluationPreview{AsOfDate: asOf, BaseCurrency: org.BaseCurrency}
	for key, current := range balances {
		if current.foreignMinor == 0 {
			continue
		}

		rate, err := s.latestRate(ctx, organizationID, key.currency, org.BaseCurrency, asOf)
		if err != nil {
			return RevaluationPreview{}, err
		}
		revalued := current.foreignMinor * rate.Numerator / rate.Denominator
		adjustment := revalued - current.carryingBaseMinor
		if adjustment == 0 {
			continue
		}

		preview.Rows = append(preview.Rows, RevaluationRow{
			AccountID:               key.accountID,
			AccountCode:             current.account.Code,
			AccountName:             current.account.Name,
			Currency:                key.currency,
			ForeignBalanceMinor:     current.foreignMinor,
			CarryingBaseMinor:       current.carryingBaseMinor,
			RevaluedBaseMinor:       revalued,
			AdjustmentMinor:         adjustment,
			ExchangeRateNumerator:   rate.Numerator,
			ExchangeRateDenominator: rate.Denominator,
		})
		preview.TotalAdjustmentMinor += adjustment
	}

	return preview, nil
}

func (s RevaluationService) Post(ctx context.Context, input PostRevaluationInput) (domain.JournalTransaction, error) {
	preview, err := s.Preview(ctx, input.OrganizationID, input.AsOfDate)
	if err != nil {
		return domain.JournalTransaction{}, err
	}
	if len(preview.Rows) == 0 {
		return domain.JournalTransaction{}, ErrRevaluationNoAdjustments
	}

	var gainLossAccount domain.Account
	if err := s.db.WithContext(ctx).
		Where("organization_id = ? AND id = ?", input.OrganizationID, input.GainLossAccountID).
		First(&gainLossAccount).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return domain.JournalTransaction{}, ErrRevaluationGainLossAccount
		}
		return domain.JournalTransaction{}, err
	}

	splits := make([]PostLedgerSplitInput, 0, len(preview.Rows)+1)
	for _, row := range preview.Rows {
		amount := absInt64(row.AdjustmentMinor)
		if row.AdjustmentMinor > 0 {
			splits = append(splits, PostLedgerSplitInput{
				AccountID:      row.AccountID,
				Memo:           fmt.Sprintf("FX revaluation %s at %d/%d", row.Currency, row.ExchangeRateNumerator, row.ExchangeRateDenominator),
				DebitMinor:     amount,
				BaseDebitMinor: amount,
				Currency:       preview.BaseCurrency,
			})
		} else {
			splits = append(splits, PostLedgerSplitInput{
				AccountID:       row.AccountID,
				Memo:            fmt.Sprintf("FX revaluation %s at %d/%d", row.Currency, row.ExchangeRateNumerator, row.ExchangeRateDenominator),
				CreditMinor:     amount,
				BaseCreditMinor: amount,
				Currency:        preview.BaseCurrency,
			})
		}
	}

	if preview.TotalAdjustmentMinor != 0 {
		amount := absInt64(preview.TotalAdjustmentMinor)
		counter := PostLedgerSplitInput{
			AccountID: input.GainLossAccountID,
			Memo:      "Unrealized FX revaluation offset",
			Currency:  preview.BaseCurrency,
		}
		if preview.TotalAdjustmentMinor > 0 {
			counter.CreditMinor = amount
			counter.BaseCreditMinor = amount
		} else {
			counter.DebitMinor = amount
			counter.BaseDebitMinor = amount
		}
		splits = append(splits, counter)
	}

	return NewLedgerService(s.db).PostTransaction(ctx, PostJournalTransactionInput{
		OrganizationID:  input.OrganizationID,
		TransactionDate: input.AsOfDate,
		Memo:            "Unrealized foreign currency revaluation",
		SourceModule:    domain.SourceModuleRevalue,
		PostedByUserID:  input.PostedByUserID,
		Splits:          splits,
	})
}

func (s RevaluationService) latestRate(ctx context.Context, organizationID string, fromCurrency string, toCurrency string, asOf time.Time) (domain.ExchangeRate, error) {
	var rate domain.ExchangeRate
	if err := s.db.WithContext(ctx).
		Where("organization_id = ? AND from_currency = ? AND to_currency = ? AND rate_date <= ?", organizationID, fromCurrency, toCurrency, asOf).
		Order("rate_date DESC").
		First(&rate).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return domain.ExchangeRate{}, fmt.Errorf("%w: %s to %s as of %s", ErrRevaluationMissingRate, fromCurrency, toCurrency, asOf.Format("2006-01-02"))
		}
		return domain.ExchangeRate{}, err
	}
	return rate, nil
}

func absInt64(value int64) int64 {
	if value < 0 {
		return -value
	}
	return value
}
