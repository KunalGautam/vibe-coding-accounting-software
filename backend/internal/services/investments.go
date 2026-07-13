package services

import (
	"context"
	"errors"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

var (
	ErrInvestmentLotInvalid           = errors.New("investment lot requires positive quantity and cost basis")
	ErrInvestmentDispositionInvalid   = errors.New("investment disposition requires positive quantity and proceeds")
	ErrInvestmentLotInsufficientUnits = errors.New("investment lot does not have enough remaining quantity")
	ErrInvestmentPriceInvalid         = errors.New("investment price requires symbol, date, and positive price")
	ErrInvestmentPriceMissing         = errors.New("investment valuation requires a market price on or before the as-of date")
	ErrInvestmentPostingAccounts      = errors.New("investment sale posting requires both proceeds and gain/loss accounts")
	ErrInvestmentAverageCostInvalid   = errors.New("average-cost sale requires account, symbol, quantity, and proceeds")
)

type InvestmentService struct {
	db *gorm.DB
}

type CreateInvestmentLotInput struct {
	OrganizationID  string
	AccountID       string
	Symbol          string
	SecurityName    string
	AcquisitionDate time.Time
	QuantityMillis  int64
	CostBasisMinor  int64
	Currency        string
	CostMethod      domain.InvestmentCostMethod
	Notes           string
}

type SellInvestmentLotInput struct {
	OrganizationID    string
	LotID             string
	SaleDate          time.Time
	QuantityMillis    int64
	ProceedsMinor     int64
	ProceedsAccountID string
	GainLossAccountID string
	Notes             string
}

type SellAverageCostInput struct {
	OrganizationID    string
	AccountID         string
	Symbol            string
	Currency          string
	SaleDate          time.Time
	QuantityMillis    int64
	ProceedsMinor     int64
	ProceedsAccountID string
	GainLossAccountID string
	Notes             string
}

type CreateInvestmentPriceInput struct {
	OrganizationID string
	Symbol         string
	PriceDate      time.Time
	PriceMinor     int64
	Currency       string
	Source         string
}

type AverageCostSaleResult struct {
	Dispositions            []domain.InvestmentDisposition `json:"dispositions"`
	QuantityMillis          int64                          `json:"quantity_millis"`
	ProceedsMinor           int64                          `json:"proceeds_minor"`
	AllocatedCostBasisMinor int64                          `json:"allocated_cost_basis_minor"`
	RealizedGainLossMinor   int64                          `json:"realized_gain_loss_minor"`
	JournalTransactionID    *string                        `json:"journal_transaction_id,omitempty"`
}

type RealizedGainsReport struct {
	FromDate      time.Time                      `json:"from_date"`
	ToDate        time.Time                      `json:"to_date"`
	Rows          []domain.InvestmentDisposition `json:"rows"`
	TotalProceeds int64                          `json:"total_proceeds_minor"`
	TotalCost     int64                          `json:"total_cost_basis_minor"`
	TotalGainLoss int64                          `json:"total_gain_loss_minor"`
}

type InvestmentValuationReport struct {
	AsOfDate              time.Time                `json:"as_of_date"`
	Rows                  []InvestmentValuationRow `json:"rows"`
	TotalCostBasisMinor   int64                    `json:"total_cost_basis_minor"`
	TotalMarketValueMinor int64                    `json:"total_market_value_minor"`
	TotalUnrealizedMinor  int64                    `json:"total_unrealized_gain_loss_minor"`
}

type InvestmentValuationRow struct {
	LotID                   string    `json:"lot_id"`
	AccountID               string    `json:"account_id"`
	Symbol                  string    `json:"symbol"`
	SecurityName            string    `json:"security_name"`
	AcquisitionDate         time.Time `json:"acquisition_date"`
	RemainingQuantityMillis int64     `json:"remaining_quantity_millis"`
	RemainingCostBasisMinor int64     `json:"remaining_cost_basis_minor"`
	MarketPriceMinor        int64     `json:"market_price_minor"`
	MarketValueMinor        int64     `json:"market_value_minor"`
	UnrealizedGainLossMinor int64     `json:"unrealized_gain_loss_minor"`
	Currency                string    `json:"currency"`
	PriceDate               time.Time `json:"price_date"`
}

func NewInvestmentService(db *gorm.DB) InvestmentService {
	return InvestmentService{db: db}
}

func (s InvestmentService) ListPrices(ctx context.Context, organizationID string) ([]domain.InvestmentPrice, error) {
	var prices []domain.InvestmentPrice
	err := s.db.WithContext(ctx).
		Where("organization_id = ?", organizationID).
		Order("symbol ASC, price_date DESC").
		Find(&prices).
		Error
	return prices, err
}

func (s InvestmentService) CreatePrice(ctx context.Context, input CreateInvestmentPriceInput) (domain.InvestmentPrice, error) {
	if input.Symbol == "" || input.PriceDate.IsZero() || input.PriceMinor <= 0 {
		return domain.InvestmentPrice{}, ErrInvestmentPriceInvalid
	}
	price := domain.InvestmentPrice{
		OrganizationID: input.OrganizationID,
		Symbol:         input.Symbol,
		PriceDate:      input.PriceDate,
		PriceMinor:     input.PriceMinor,
		Currency:       input.Currency,
		Source:         input.Source,
	}
	if price.Currency == "" {
		price.Currency = "INR"
	}
	err := s.db.WithContext(ctx).Create(&price).Error
	return price, err
}

func (s InvestmentService) ListLots(ctx context.Context, organizationID string) ([]domain.InvestmentLot, error) {
	var lots []domain.InvestmentLot
	err := s.db.WithContext(ctx).
		Preload("Account").
		Where("organization_id = ?", organizationID).
		Order("symbol ASC, acquisition_date ASC").
		Find(&lots).
		Error
	return lots, err
}

func (s InvestmentService) CreateLot(ctx context.Context, input CreateInvestmentLotInput) (domain.InvestmentLot, error) {
	if input.QuantityMillis <= 0 || input.CostBasisMinor <= 0 {
		return domain.InvestmentLot{}, ErrInvestmentLotInvalid
	}
	if input.CostMethod == "" {
		input.CostMethod = domain.InvestmentCostMethodSpecificLot
	}

	var account domain.Account
	if err := s.db.WithContext(ctx).
		Where("organization_id = ? AND id = ?", input.OrganizationID, input.AccountID).
		First(&account).
		Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return domain.InvestmentLot{}, domain.ErrTenantScope
		}
		return domain.InvestmentLot{}, err
	}

	lot := domain.InvestmentLot{
		OrganizationID:          input.OrganizationID,
		AccountID:               input.AccountID,
		Symbol:                  input.Symbol,
		SecurityName:            input.SecurityName,
		AcquisitionDate:         input.AcquisitionDate,
		QuantityMillis:          input.QuantityMillis,
		RemainingQuantityMillis: input.QuantityMillis,
		CostBasisMinor:          input.CostBasisMinor,
		Currency:                input.Currency,
		CostMethod:              input.CostMethod,
		Notes:                   input.Notes,
	}
	if lot.Currency == "" {
		lot.Currency = account.Currency
	}

	err := s.db.WithContext(ctx).Create(&lot).Error
	return lot, err
}

func (s InvestmentService) SellLot(ctx context.Context, input SellInvestmentLotInput) (domain.InvestmentDisposition, error) {
	if input.QuantityMillis <= 0 || input.ProceedsMinor <= 0 {
		return domain.InvestmentDisposition{}, ErrInvestmentDispositionInvalid
	}

	var disposition domain.InvestmentDisposition
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var lot domain.InvestmentLot
		if err := tx.Where("organization_id = ? AND id = ?", input.OrganizationID, input.LotID).First(&lot).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return domain.ErrTenantScope
			}
			return err
		}
		if lot.RemainingQuantityMillis < input.QuantityMillis {
			return ErrInvestmentLotInsufficientUnits
		}

		allocatedCost := proportionalCost(lot.CostBasisMinor, input.QuantityMillis, lot.QuantityMillis)
		disposition = domain.InvestmentDisposition{
			OrganizationID:          input.OrganizationID,
			InvestmentLotID:         lot.ID,
			SaleDate:                input.SaleDate,
			QuantityMillis:          input.QuantityMillis,
			ProceedsMinor:           input.ProceedsMinor,
			AllocatedCostBasisMinor: allocatedCost,
			RealizedGainLossMinor:   input.ProceedsMinor - allocatedCost,
			Currency:                lot.Currency,
			Notes:                   input.Notes,
		}
		if err := tx.Create(&disposition).Error; err != nil {
			return err
		}

		lot.RemainingQuantityMillis -= input.QuantityMillis
		if err := tx.Save(&lot).Error; err != nil {
			return err
		}

		if input.ProceedsAccountID == "" && input.GainLossAccountID == "" {
			return nil
		}
		if input.ProceedsAccountID == "" || input.GainLossAccountID == "" {
			return ErrInvestmentPostingAccounts
		}
		transaction, err := buildInvestmentSaleJournal(input, lot, disposition)
		if err != nil {
			return err
		}
		if err := validateSplitAccounts(ctx, tx, input.OrganizationID, transaction.Splits); err != nil {
			return err
		}
		if err := tx.Create(&transaction).Error; err != nil {
			return err
		}
		disposition.JournalTransactionID = &transaction.ID
		return tx.Model(&disposition).Update("journal_transaction_id", transaction.ID).Error
	})
	return disposition, err
}

func (s InvestmentService) SellAverageCost(ctx context.Context, input SellAverageCostInput) (AverageCostSaleResult, error) {
	if input.AccountID == "" || input.Symbol == "" || input.QuantityMillis <= 0 || input.ProceedsMinor <= 0 {
		return AverageCostSaleResult{}, ErrInvestmentAverageCostInvalid
	}
	currency := input.Currency
	if currency == "" {
		currency = "INR"
	}

	result := AverageCostSaleResult{
		QuantityMillis: input.QuantityMillis,
		ProceedsMinor:  input.ProceedsMinor,
	}
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var lots []domain.InvestmentLot
		if err := tx.
			Where("organization_id = ? AND account_id = ? AND symbol = ? AND currency = ? AND cost_method = ? AND remaining_quantity_millis > 0 AND acquisition_date <= ?",
				input.OrganizationID, input.AccountID, input.Symbol, currency, domain.InvestmentCostMethodAverageCost, input.SaleDate).
			Order("acquisition_date ASC, created_at ASC").
			Find(&lots).
			Error; err != nil {
			return err
		}

		var totalQuantity int64
		var totalCost int64
		for _, lot := range lots {
			totalQuantity += lot.RemainingQuantityMillis
			totalCost += proportionalCost(lot.CostBasisMinor, lot.RemainingQuantityMillis, lot.QuantityMillis)
		}
		if totalQuantity < input.QuantityMillis {
			return ErrInvestmentLotInsufficientUnits
		}

		allocatedCost := totalCost * input.QuantityMillis / totalQuantity
		result.AllocatedCostBasisMinor = allocatedCost
		result.RealizedGainLossMinor = input.ProceedsMinor - allocatedCost

		remainingToSell := input.QuantityMillis
		remainingCostToAllocate := allocatedCost
		remainingProceedsToAllocate := input.ProceedsMinor
		dispositions := make([]domain.InvestmentDisposition, 0, len(lots))
		for _, lot := range lots {
			if remainingToSell == 0 {
				break
			}
			soldQuantity := lot.RemainingQuantityMillis
			if soldQuantity > remainingToSell {
				soldQuantity = remainingToSell
			}

			dispositionCost := allocatedCost * soldQuantity / input.QuantityMillis
			dispositionProceeds := input.ProceedsMinor * soldQuantity / input.QuantityMillis
			if soldQuantity == remainingToSell {
				dispositionCost = remainingCostToAllocate
				dispositionProceeds = remainingProceedsToAllocate
			}

			disposition := domain.InvestmentDisposition{
				OrganizationID:          input.OrganizationID,
				InvestmentLotID:         lot.ID,
				SaleDate:                input.SaleDate,
				QuantityMillis:          soldQuantity,
				ProceedsMinor:           dispositionProceeds,
				AllocatedCostBasisMinor: dispositionCost,
				RealizedGainLossMinor:   dispositionProceeds - dispositionCost,
				Currency:                currency,
				Notes:                   input.Notes,
			}
			if err := tx.Create(&disposition).Error; err != nil {
				return err
			}
			lot.RemainingQuantityMillis -= soldQuantity
			if err := tx.Save(&lot).Error; err != nil {
				return err
			}

			dispositions = append(dispositions, disposition)
			remainingToSell -= soldQuantity
			remainingCostToAllocate -= dispositionCost
			remainingProceedsToAllocate -= dispositionProceeds
		}

		if input.ProceedsAccountID != "" || input.GainLossAccountID != "" {
			if input.ProceedsAccountID == "" || input.GainLossAccountID == "" {
				return ErrInvestmentPostingAccounts
			}
			transaction, err := buildAverageCostSaleJournal(input, result)
			if err != nil {
				return err
			}
			if err := validateSplitAccounts(ctx, tx, input.OrganizationID, transaction.Splits); err != nil {
				return err
			}
			if err := tx.Create(&transaction).Error; err != nil {
				return err
			}
			result.JournalTransactionID = &transaction.ID
			for index := range dispositions {
				dispositions[index].JournalTransactionID = &transaction.ID
				if err := tx.Model(&dispositions[index]).Update("journal_transaction_id", transaction.ID).Error; err != nil {
					return err
				}
			}
		}

		result.Dispositions = dispositions
		return nil
	})
	return result, err
}

func buildInvestmentSaleJournal(input SellInvestmentLotInput, lot domain.InvestmentLot, disposition domain.InvestmentDisposition) (domain.JournalTransaction, error) {
	splits := []domain.LedgerSplit{
		{
			OrganizationID: input.OrganizationID,
			AccountID:      input.ProceedsAccountID,
			DebitMinor:     disposition.ProceedsMinor,
			Currency:       disposition.Currency,
		},
		{
			OrganizationID: input.OrganizationID,
			AccountID:      lot.AccountID,
			CreditMinor:    disposition.AllocatedCostBasisMinor,
			Currency:       disposition.Currency,
		},
	}
	if disposition.RealizedGainLossMinor > 0 {
		splits = append(splits, domain.LedgerSplit{
			OrganizationID: input.OrganizationID,
			AccountID:      input.GainLossAccountID,
			CreditMinor:    disposition.RealizedGainLossMinor,
			Currency:       disposition.Currency,
		})
	} else if disposition.RealizedGainLossMinor < 0 {
		splits = append(splits, domain.LedgerSplit{
			OrganizationID: input.OrganizationID,
			AccountID:      input.GainLossAccountID,
			DebitMinor:     -disposition.RealizedGainLossMinor,
			Currency:       disposition.Currency,
		})
	}
	now := time.Now().UTC()
	transaction := domain.JournalTransaction{
		OrganizationID:  input.OrganizationID,
		TransactionDate: input.SaleDate,
		Memo:            "Investment sale " + lot.Symbol,
		SourceModule:    domain.SourceModuleManual,
		Status:          domain.JournalStatusPosted,
		PostedAt:        &now,
		Splits:          splits,
	}
	if err := transaction.ValidateBalanced(); err != nil {
		return domain.JournalTransaction{}, err
	}
	return transaction, nil
}

func buildAverageCostSaleJournal(input SellAverageCostInput, result AverageCostSaleResult) (domain.JournalTransaction, error) {
	currency := input.Currency
	if currency == "" {
		currency = "INR"
	}
	splits := []domain.LedgerSplit{
		{
			OrganizationID: input.OrganizationID,
			AccountID:      input.ProceedsAccountID,
			DebitMinor:     result.ProceedsMinor,
			Currency:       currency,
		},
		{
			OrganizationID: input.OrganizationID,
			AccountID:      input.AccountID,
			CreditMinor:    result.AllocatedCostBasisMinor,
			Currency:       currency,
		},
	}
	if result.RealizedGainLossMinor > 0 {
		splits = append(splits, domain.LedgerSplit{
			OrganizationID: input.OrganizationID,
			AccountID:      input.GainLossAccountID,
			CreditMinor:    result.RealizedGainLossMinor,
			Currency:       currency,
		})
	} else if result.RealizedGainLossMinor < 0 {
		splits = append(splits, domain.LedgerSplit{
			OrganizationID: input.OrganizationID,
			AccountID:      input.GainLossAccountID,
			DebitMinor:     -result.RealizedGainLossMinor,
			Currency:       currency,
		})
	}
	now := time.Now().UTC()
	transaction := domain.JournalTransaction{
		OrganizationID:  input.OrganizationID,
		TransactionDate: input.SaleDate,
		Memo:            "Average-cost investment sale " + input.Symbol,
		SourceModule:    domain.SourceModuleManual,
		Status:          domain.JournalStatusPosted,
		PostedAt:        &now,
		Splits:          splits,
	}
	if err := transaction.ValidateBalanced(); err != nil {
		return domain.JournalTransaction{}, err
	}
	return transaction, nil
}

func (s InvestmentService) RealizedGains(ctx context.Context, organizationID string, from time.Time, to time.Time) (RealizedGainsReport, error) {
	var rows []domain.InvestmentDisposition
	err := s.db.WithContext(ctx).
		Preload("InvestmentLot").
		Where("organization_id = ? AND sale_date BETWEEN ? AND ?", organizationID, from, to).
		Order("sale_date ASC, created_at ASC").
		Find(&rows).
		Error
	if err != nil {
		return RealizedGainsReport{}, err
	}

	report := RealizedGainsReport{FromDate: from, ToDate: to, Rows: rows}
	for _, row := range rows {
		report.TotalProceeds += row.ProceedsMinor
		report.TotalCost += row.AllocatedCostBasisMinor
		report.TotalGainLoss += row.RealizedGainLossMinor
	}
	return report, nil
}

func (s InvestmentService) Valuation(ctx context.Context, organizationID string, asOf time.Time) (InvestmentValuationReport, error) {
	var lots []domain.InvestmentLot
	if err := s.db.WithContext(ctx).
		Where("organization_id = ? AND remaining_quantity_millis > 0 AND acquisition_date <= ?", organizationID, asOf).
		Order("symbol ASC, acquisition_date ASC").
		Find(&lots).
		Error; err != nil {
		return InvestmentValuationReport{}, err
	}

	report := InvestmentValuationReport{AsOfDate: asOf, Rows: make([]InvestmentValuationRow, 0, len(lots))}
	for _, lot := range lots {
		var price domain.InvestmentPrice
		if err := s.db.WithContext(ctx).
			Where("organization_id = ? AND symbol = ? AND currency = ? AND price_date <= ?", organizationID, lot.Symbol, lot.Currency, asOf).
			Order("price_date DESC").
			First(&price).
			Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return InvestmentValuationReport{}, ErrInvestmentPriceMissing
			}
			return InvestmentValuationReport{}, err
		}

		remainingCost := proportionalCost(lot.CostBasisMinor, lot.RemainingQuantityMillis, lot.QuantityMillis)
		marketValue := lot.RemainingQuantityMillis * price.PriceMinor / 1000
		row := InvestmentValuationRow{
			LotID:                   lot.ID,
			AccountID:               lot.AccountID,
			Symbol:                  lot.Symbol,
			SecurityName:            lot.SecurityName,
			AcquisitionDate:         lot.AcquisitionDate,
			RemainingQuantityMillis: lot.RemainingQuantityMillis,
			RemainingCostBasisMinor: remainingCost,
			MarketPriceMinor:        price.PriceMinor,
			MarketValueMinor:        marketValue,
			UnrealizedGainLossMinor: marketValue - remainingCost,
			Currency:                lot.Currency,
			PriceDate:               price.PriceDate,
		}
		report.TotalCostBasisMinor += row.RemainingCostBasisMinor
		report.TotalMarketValueMinor += row.MarketValueMinor
		report.TotalUnrealizedMinor += row.UnrealizedGainLossMinor
		report.Rows = append(report.Rows, row)
	}
	return report, nil
}

func proportionalCost(totalCost int64, soldQuantity int64, totalQuantity int64) int64 {
	if totalQuantity == 0 {
		return 0
	}
	return totalCost * soldQuantity / totalQuantity
}
