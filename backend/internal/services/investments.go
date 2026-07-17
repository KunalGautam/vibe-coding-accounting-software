package services

import (
	"bytes"
	"context"
	"encoding/csv"
	"errors"
	"io"
	"strconv"
	"strings"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

var (
	ErrInvestmentLotInvalid             = errors.New("investment lot requires positive quantity and cost basis")
	ErrInvestmentDispositionInvalid     = errors.New("investment disposition requires positive quantity and proceeds")
	ErrInvestmentLotInsufficientUnits   = errors.New("investment lot does not have enough remaining quantity")
	ErrInvestmentPriceInvalid           = errors.New("investment price requires symbol, date, and positive price")
	ErrInvestmentPriceImportInvalid     = errors.New("investment price import requires CSV rows")
	ErrInvestmentPriceMissing           = errors.New("investment valuation requires a market price on or before the as-of date")
	ErrInvestmentPostingAccounts        = errors.New("investment sale posting requires both proceeds and gain/loss accounts")
	ErrInvestmentAverageCostInvalid     = errors.New("average-cost sale requires account, symbol, quantity, and proceeds")
	ErrInvestmentDividendInvalid        = errors.New("investment dividend requires account, symbol, date, and positive amount")
	ErrInvestmentCorporateActionInvalid = errors.New("investment corporate action requires account, symbol, date, type, and positive ratio")
	ErrInvestmentCorporateActionNoLots  = errors.New("investment corporate action did not match any open lots")
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

type ImportInvestmentPricesInput struct {
	OrganizationID string
	CSV            string
	Source         string
	Symbol         string
}

type ImportAMFINAVInput struct {
	OrganizationID string
	Text           string
	SymbolMode     string
}

type CreateInvestmentDividendInput struct {
	OrganizationID  string
	AccountID       string
	Symbol          string
	DividendDate    time.Time
	AmountMinor     int64
	Currency        string
	CashAccountID   string
	IncomeAccountID string
	Notes           string
}

type CreateInvestmentCorporateActionInput struct {
	OrganizationID   string
	AccountID        string
	Symbol           string
	ActionType       domain.InvestmentCorporateActionType
	ActionDate       time.Time
	RatioNumerator   int64
	RatioDenominator int64
	Notes            string
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

type InvestmentPriceImportResult struct {
	Imported int                      `json:"imported"`
	Skipped  int                      `json:"skipped"`
	Errors   []string                 `json:"errors"`
	Prices   []domain.InvestmentPrice `json:"prices"`
}

type InvestmentDividendReport struct {
	FromDate         time.Time                   `json:"from_date"`
	ToDate           time.Time                   `json:"to_date"`
	Rows             []domain.InvestmentDividend `json:"rows"`
	TotalAmountMinor int64                       `json:"total_amount_minor"`
}

type InvestmentTaxLotReport struct {
	AsOfDate                time.Time             `json:"as_of_date"`
	Rows                    []InvestmentTaxLotRow `json:"rows"`
	TotalQuantityMillis     int64                 `json:"total_quantity_millis"`
	TotalRemainingMillis    int64                 `json:"total_remaining_quantity_millis"`
	TotalCostBasisMinor     int64                 `json:"total_cost_basis_minor"`
	TotalRemainingCostMinor int64                 `json:"total_remaining_cost_basis_minor"`
	TotalProceedsMinor      int64                 `json:"total_proceeds_minor"`
	TotalRealizedMinor      int64                 `json:"total_realized_gain_loss_minor"`
}

type InvestmentCorporateActionReport struct {
	FromDate                 time.Time                          `json:"from_date"`
	ToDate                   time.Time                          `json:"to_date"`
	Rows                     []domain.InvestmentCorporateAction `json:"rows"`
	TotalActions             int                                `json:"total_actions"`
	TotalAffectedLots        int64                              `json:"total_affected_lots"`
	TotalQuantityDeltaMillis int64                              `json:"total_quantity_delta_millis"`
	TotalCostBasisDeltaMinor int64                              `json:"total_cost_basis_delta_minor"`
}

type InvestmentTaxAdjustmentReport struct {
	FromDate                 time.Time                    `json:"from_date"`
	ToDate                   time.Time                    `json:"to_date"`
	Rule                     string                       `json:"rule"`
	WindowDays               int                          `json:"window_days"`
	Rows                     []InvestmentTaxAdjustmentRow `json:"rows"`
	TotalLossMinor           int64                        `json:"total_loss_minor"`
	TotalDeferredLossMinor   int64                        `json:"total_deferred_loss_minor"`
	TotalReplacementQuantity int64                        `json:"total_replacement_quantity_millis"`
}

type InvestmentTaxAdjustmentRow struct {
	DispositionID             string    `json:"disposition_id"`
	LotID                     string    `json:"lot_id"`
	AccountID                 string    `json:"account_id"`
	Symbol                    string    `json:"symbol"`
	SaleDate                  time.Time `json:"sale_date"`
	QuantityMillis            int64     `json:"quantity_millis"`
	ProceedsMinor             int64     `json:"proceeds_minor"`
	AllocatedCostBasisMinor   int64     `json:"allocated_cost_basis_minor"`
	RealizedLossMinor         int64     `json:"realized_loss_minor"`
	ReplacementQuantityMillis int64     `json:"replacement_quantity_millis"`
	DeferredLossMinor         int64     `json:"deferred_loss_minor"`
	ReplacementLotIDs         []string  `json:"replacement_lot_ids"`
	WindowStart               time.Time `json:"window_start"`
	WindowEnd                 time.Time `json:"window_end"`
	Currency                  string    `json:"currency"`
	Notes                     string    `json:"notes"`
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

type InvestmentTaxLotRow struct {
	LotID                   string                      `json:"lot_id"`
	AccountID               string                      `json:"account_id"`
	Symbol                  string                      `json:"symbol"`
	SecurityName            string                      `json:"security_name"`
	AcquisitionDate         time.Time                   `json:"acquisition_date"`
	QuantityMillis          int64                       `json:"quantity_millis"`
	RemainingQuantityMillis int64                       `json:"remaining_quantity_millis"`
	DisposedQuantityMillis  int64                       `json:"disposed_quantity_millis"`
	CostBasisMinor          int64                       `json:"cost_basis_minor"`
	RemainingCostBasisMinor int64                       `json:"remaining_cost_basis_minor"`
	DisposedCostBasisMinor  int64                       `json:"disposed_cost_basis_minor"`
	ProceedsMinor           int64                       `json:"proceeds_minor"`
	RealizedGainLossMinor   int64                       `json:"realized_gain_loss_minor"`
	UnitCostMinor           int64                       `json:"unit_cost_minor"`
	Currency                string                      `json:"currency"`
	CostMethod              domain.InvestmentCostMethod `json:"cost_method"`
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

func (s InvestmentService) ListDividends(ctx context.Context, organizationID string) ([]domain.InvestmentDividend, error) {
	var dividends []domain.InvestmentDividend
	err := s.db.WithContext(ctx).
		Preload("Account").
		Where("organization_id = ?", organizationID).
		Order("dividend_date DESC, created_at DESC").
		Find(&dividends).
		Error
	return dividends, err
}

func (s InvestmentService) ListCorporateActions(ctx context.Context, organizationID string) ([]domain.InvestmentCorporateAction, error) {
	var actions []domain.InvestmentCorporateAction
	err := s.db.WithContext(ctx).
		Preload("Account").
		Where("organization_id = ?", organizationID).
		Order("action_date DESC, created_at DESC").
		Find(&actions).
		Error
	return actions, err
}

func (s InvestmentService) CorporateActionReport(ctx context.Context, organizationID string, from time.Time, to time.Time) (InvestmentCorporateActionReport, error) {
	var actions []domain.InvestmentCorporateAction
	if err := s.db.WithContext(ctx).
		Preload("Account").
		Where("organization_id = ? AND action_date >= ? AND action_date <= ?", organizationID, from, to).
		Order("action_date ASC, symbol ASC, created_at ASC").
		Find(&actions).
		Error; err != nil {
		return InvestmentCorporateActionReport{}, err
	}

	report := InvestmentCorporateActionReport{FromDate: from, ToDate: to, Rows: actions, TotalActions: len(actions)}
	for _, action := range actions {
		report.TotalAffectedLots += action.AffectedLots
		report.TotalQuantityDeltaMillis += action.QuantityDeltaMillis
		report.TotalCostBasisDeltaMinor += action.CostBasisDeltaMinor
	}
	return report, nil
}

func (s InvestmentService) CorporateActionReportCSV(ctx context.Context, organizationID string, from time.Time, to time.Time) ([]byte, string, error) {
	report, err := s.CorporateActionReport(ctx, organizationID, from, to)
	if err != nil {
		return nil, "", err
	}

	var buffer bytes.Buffer
	writer := csv.NewWriter(&buffer)
	_ = writer.Write([]string{"Date", "Symbol", "Action type", "Ratio numerator", "Ratio denominator", "Affected lots", "Quantity delta millis", "Cost basis delta minor", "Account", "Notes"})
	for _, action := range report.Rows {
		_ = writer.Write([]string{
			action.ActionDate.Format("2006-01-02"),
			action.Symbol,
			string(action.ActionType),
			strconv.FormatInt(action.RatioNumerator, 10),
			strconv.FormatInt(action.RatioDenominator, 10),
			strconv.FormatInt(action.AffectedLots, 10),
			strconv.FormatInt(action.QuantityDeltaMillis, 10),
			strconv.FormatInt(action.CostBasisDeltaMinor, 10),
			action.Account.Code + " " + action.Account.Name,
			action.Notes,
		})
	}
	_ = writer.Write([]string{"Total", "", "", "", "", strconv.FormatInt(report.TotalAffectedLots, 10), strconv.FormatInt(report.TotalQuantityDeltaMillis, 10), strconv.FormatInt(report.TotalCostBasisDeltaMinor, 10), "", ""})
	writer.Flush()
	if err := writer.Error(); err != nil {
		return nil, "", err
	}
	filename := "investment-corporate-actions-" + from.Format("2006-01-02") + "-to-" + to.Format("2006-01-02") + ".csv"
	return buffer.Bytes(), filename, nil
}

func (s InvestmentService) CreateCorporateAction(ctx context.Context, input CreateInvestmentCorporateActionInput) (domain.InvestmentCorporateAction, error) {
	if input.AccountID == "" || input.Symbol == "" || input.ActionDate.IsZero() || input.RatioNumerator <= 0 || input.RatioDenominator <= 0 ||
		(input.ActionType != domain.InvestmentCorporateActionSplit && input.ActionType != domain.InvestmentCorporateActionBonus) {
		return domain.InvestmentCorporateAction{}, ErrInvestmentCorporateActionInvalid
	}

	action := domain.InvestmentCorporateAction{
		OrganizationID:      input.OrganizationID,
		AccountID:           input.AccountID,
		Symbol:              input.Symbol,
		ActionType:          input.ActionType,
		ActionDate:          input.ActionDate,
		RatioNumerator:      input.RatioNumerator,
		RatioDenominator:    input.RatioDenominator,
		CostBasisDeltaMinor: 0,
		Notes:               input.Notes,
	}

	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var account domain.Account
		if err := tx.Where("organization_id = ? AND id = ?", input.OrganizationID, input.AccountID).First(&account).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return domain.ErrTenantScope
			}
			return err
		}

		var lots []domain.InvestmentLot
		if err := tx.
			Where("organization_id = ? AND account_id = ? AND symbol = ? AND remaining_quantity_millis > 0 AND acquisition_date <= ?",
				input.OrganizationID, input.AccountID, input.Symbol, input.ActionDate).
			Order("acquisition_date ASC, created_at ASC").
			Find(&lots).
			Error; err != nil {
			return err
		}
		if len(lots) == 0 {
			return ErrInvestmentCorporateActionNoLots
		}

		for index := range lots {
			originalQuantity := lots[index].QuantityMillis
			originalRemaining := lots[index].RemainingQuantityMillis
			lots[index].QuantityMillis = originalQuantity * input.RatioNumerator / input.RatioDenominator
			lots[index].RemainingQuantityMillis = originalRemaining * input.RatioNumerator / input.RatioDenominator
			if lots[index].QuantityMillis <= 0 || lots[index].RemainingQuantityMillis <= 0 {
				return ErrInvestmentCorporateActionInvalid
			}
			action.AffectedLots++
			action.QuantityDeltaMillis += lots[index].RemainingQuantityMillis - originalRemaining
			if err := tx.Save(&lots[index]).Error; err != nil {
				return err
			}
		}
		return tx.Create(&action).Error
	})
	return action, err
}

func (s InvestmentService) CreateDividend(ctx context.Context, input CreateInvestmentDividendInput) (domain.InvestmentDividend, error) {
	if input.AccountID == "" || input.Symbol == "" || input.DividendDate.IsZero() || input.AmountMinor <= 0 {
		return domain.InvestmentDividend{}, ErrInvestmentDividendInvalid
	}
	dividend := domain.InvestmentDividend{
		OrganizationID:  input.OrganizationID,
		AccountID:       input.AccountID,
		Symbol:          input.Symbol,
		DividendDate:    input.DividendDate,
		AmountMinor:     input.AmountMinor,
		Currency:        input.Currency,
		CashAccountID:   input.CashAccountID,
		IncomeAccountID: input.IncomeAccountID,
		Notes:           input.Notes,
	}

	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var account domain.Account
		if err := tx.Where("organization_id = ? AND id = ?", input.OrganizationID, input.AccountID).First(&account).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return domain.ErrTenantScope
			}
			return err
		}
		if dividend.Currency == "" {
			dividend.Currency = account.Currency
		}
		if err := tx.Create(&dividend).Error; err != nil {
			return err
		}
		if input.CashAccountID == "" && input.IncomeAccountID == "" {
			return nil
		}
		if input.CashAccountID == "" || input.IncomeAccountID == "" {
			return ErrInvestmentPostingAccounts
		}
		transaction, err := buildInvestmentDividendJournal(input, dividend)
		if err != nil {
			return err
		}
		if err := validateSplitAccounts(ctx, tx, input.OrganizationID, transaction.Splits); err != nil {
			return err
		}
		if err := tx.Create(&transaction).Error; err != nil {
			return err
		}
		dividend.JournalTransactionID = &transaction.ID
		return tx.Model(&dividend).Update("journal_transaction_id", transaction.ID).Error
	})
	return dividend, err
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

func (s InvestmentService) ImportPricesCSV(ctx context.Context, input ImportInvestmentPricesInput) (InvestmentPriceImportResult, error) {
	if strings.TrimSpace(input.CSV) == "" {
		return InvestmentPriceImportResult{}, ErrInvestmentPriceImportInvalid
	}
	source := strings.TrimSpace(input.Source)
	if source == "" {
		source = "csv_import"
	}

	reader := csv.NewReader(strings.NewReader(input.CSV))
	reader.TrimLeadingSpace = true
	reader.FieldsPerRecord = -1
	result := InvestmentPriceImportResult{Errors: []string{}, Prices: []domain.InvestmentPrice{}}
	rowNumber := 0
	for {
		record, err := reader.Read()
		if errors.Is(err, io.EOF) {
			break
		}
		rowNumber++
		if err != nil {
			result.Skipped++
			result.Errors = append(result.Errors, "row "+strconv.Itoa(rowNumber)+": "+err.Error())
			continue
		}
		if isBlankCSVRecord(record) {
			continue
		}
		if rowNumber == 1 && isInvestmentPriceHeader(record) {
			continue
		}

		price, err := parseInvestmentPriceRecord(input.OrganizationID, record, source)
		if err != nil {
			result.Skipped++
			result.Errors = append(result.Errors, "row "+strconv.Itoa(rowNumber)+": "+err.Error())
			continue
		}
		if err := s.upsertPrice(ctx, price); err != nil {
			result.Skipped++
			result.Errors = append(result.Errors, "row "+strconv.Itoa(rowNumber)+": "+err.Error())
			continue
		}
		result.Imported++
		result.Prices = append(result.Prices, price)
	}
	if result.Imported == 0 && result.Skipped == 0 {
		return result, ErrInvestmentPriceImportInvalid
	}
	return result, nil
}

func (s InvestmentService) ImportAMFINAV(ctx context.Context, input ImportAMFINAVInput) (InvestmentPriceImportResult, error) {
	if strings.TrimSpace(input.Text) == "" {
		return InvestmentPriceImportResult{}, ErrInvestmentPriceImportInvalid
	}
	symbolMode := strings.TrimSpace(input.SymbolMode)
	if symbolMode == "" {
		symbolMode = "scheme_code"
	}
	if symbolMode != "scheme_code" && symbolMode != "isin_growth" && symbolMode != "scheme_name" {
		return InvestmentPriceImportResult{}, ErrInvestmentPriceImportInvalid
	}

	result := InvestmentPriceImportResult{Errors: []string{}, Prices: []domain.InvestmentPrice{}}
	for index, line := range strings.Split(input.Text, "\n") {
		rowNumber := index + 1
		price, skip, err := parseAMFINAVLine(input.OrganizationID, line, symbolMode)
		if skip {
			continue
		}
		if err != nil {
			result.Skipped++
			result.Errors = append(result.Errors, "row "+strconv.Itoa(rowNumber)+": "+err.Error())
			continue
		}
		if err := s.upsertPrice(ctx, price); err != nil {
			result.Skipped++
			result.Errors = append(result.Errors, "row "+strconv.Itoa(rowNumber)+": "+err.Error())
			continue
		}
		result.Imported++
		result.Prices = append(result.Prices, price)
	}
	if result.Imported == 0 && result.Skipped == 0 {
		return result, ErrInvestmentPriceImportInvalid
	}
	return result, nil
}

func (s InvestmentService) ImportNSEEquityCSV(ctx context.Context, input ImportInvestmentPricesInput) (InvestmentPriceImportResult, error) {
	if strings.TrimSpace(input.CSV) == "" {
		return InvestmentPriceImportResult{}, ErrInvestmentPriceImportInvalid
	}
	source := strings.TrimSpace(input.Source)
	if source == "" {
		source = "nse_equity_csv"
	}

	reader := csv.NewReader(strings.NewReader(input.CSV))
	reader.TrimLeadingSpace = true
	reader.FieldsPerRecord = -1
	header, err := reader.Read()
	if err != nil {
		return InvestmentPriceImportResult{}, ErrInvestmentPriceImportInvalid
	}
	columns := nseEquityColumnMap(header)
	symbolIndex, okSymbol := firstColumn(columns, "SYMBOL", "TCKRSYMB", "TICKER", "SECURITY")
	dateIndex, okDate := firstColumn(columns, "DATE1", "TRADDT", "TRADEDATE", "PRICE_DATE", "DATE")
	priceIndex, okPrice := firstColumn(columns, "CLOSE_PRICE", "CLSPRIC", "CLOSE", "LAST_PRICE", "LAST")
	seriesIndex, hasSeries := firstColumn(columns, "SERIES", "SCTYSRS")
	if !okSymbol || !okDate || !okPrice {
		return InvestmentPriceImportResult{}, ErrInvestmentPriceImportInvalid
	}

	result := InvestmentPriceImportResult{Errors: []string{}, Prices: []domain.InvestmentPrice{}}
	rowNumber := 1
	for {
		record, err := reader.Read()
		if errors.Is(err, io.EOF) {
			break
		}
		rowNumber++
		if err != nil {
			result.Skipped++
			result.Errors = append(result.Errors, "row "+strconv.Itoa(rowNumber)+": "+err.Error())
			continue
		}
		if isBlankCSVRecord(record) {
			continue
		}
		if hasSeries && strings.ToUpper(strings.TrimSpace(csvValue(record, seriesIndex))) != "EQ" {
			continue
		}
		price, err := parseNSEEquityPriceRecord(input.OrganizationID, record, symbolIndex, dateIndex, priceIndex, source)
		if err != nil {
			result.Skipped++
			result.Errors = append(result.Errors, "row "+strconv.Itoa(rowNumber)+": "+err.Error())
			continue
		}
		if err := s.upsertPrice(ctx, price); err != nil {
			result.Skipped++
			result.Errors = append(result.Errors, "row "+strconv.Itoa(rowNumber)+": "+err.Error())
			continue
		}
		result.Imported++
		result.Prices = append(result.Prices, price)
	}
	if result.Imported == 0 && result.Skipped == 0 {
		return result, ErrInvestmentPriceImportInvalid
	}
	return result, nil
}

func (s InvestmentService) ImportYahooFinanceCSV(ctx context.Context, input ImportInvestmentPricesInput) (InvestmentPriceImportResult, error) {
	if strings.TrimSpace(input.CSV) == "" {
		return InvestmentPriceImportResult{}, ErrInvestmentPriceImportInvalid
	}
	source := strings.TrimSpace(input.Source)
	if source == "" {
		source = "yahoo_finance_csv"
	}

	reader := csv.NewReader(strings.NewReader(input.CSV))
	reader.TrimLeadingSpace = true
	reader.FieldsPerRecord = -1
	header, err := reader.Read()
	if err != nil {
		return InvestmentPriceImportResult{}, ErrInvestmentPriceImportInvalid
	}
	columns := nseEquityColumnMap(header)
	dateIndex, okDate := firstColumn(columns, "DATE", "PRICE_DATE")
	priceIndex, okPrice := firstColumn(columns, "CLOSE", "ADJ_CLOSE", "ADJ_CLOSE_PRICE")
	symbolIndex, hasSymbol := firstColumn(columns, "SYMBOL", "TICKER")
	if !okDate || !okPrice {
		return InvestmentPriceImportResult{}, ErrInvestmentPriceImportInvalid
	}

	result := InvestmentPriceImportResult{Errors: []string{}, Prices: []domain.InvestmentPrice{}}
	rowNumber := 1
	for {
		record, err := reader.Read()
		if errors.Is(err, io.EOF) {
			break
		}
		rowNumber++
		if err != nil {
			result.Skipped++
			result.Errors = append(result.Errors, "row "+strconv.Itoa(rowNumber)+": "+err.Error())
			continue
		}
		if isBlankCSVRecord(record) {
			continue
		}
		symbol := strings.ToUpper(strings.TrimSpace(input.Symbol))
		if hasSymbol {
			symbol = strings.ToUpper(csvValue(record, symbolIndex))
		}
		price, err := parseYahooFinancePriceRecord(input.OrganizationID, record, symbol, dateIndex, priceIndex, source)
		if err != nil {
			result.Skipped++
			result.Errors = append(result.Errors, "row "+strconv.Itoa(rowNumber)+": "+err.Error())
			continue
		}
		if err := s.upsertPrice(ctx, price); err != nil {
			result.Skipped++
			result.Errors = append(result.Errors, "row "+strconv.Itoa(rowNumber)+": "+err.Error())
			continue
		}
		result.Imported++
		result.Prices = append(result.Prices, price)
	}
	if result.Imported == 0 && result.Skipped == 0 {
		return result, ErrInvestmentPriceImportInvalid
	}
	return result, nil
}

func (s InvestmentService) ImportAlphaVantageCSV(ctx context.Context, input ImportInvestmentPricesInput) (InvestmentPriceImportResult, error) {
	if strings.TrimSpace(input.CSV) == "" {
		return InvestmentPriceImportResult{}, ErrInvestmentPriceImportInvalid
	}
	source := strings.TrimSpace(input.Source)
	if source == "" {
		source = "alpha_vantage_csv"
	}

	reader := csv.NewReader(strings.NewReader(input.CSV))
	reader.TrimLeadingSpace = true
	reader.FieldsPerRecord = -1
	header, err := reader.Read()
	if err != nil {
		return InvestmentPriceImportResult{}, ErrInvestmentPriceImportInvalid
	}
	columns := nseEquityColumnMap(header)
	dateIndex, okDate := firstColumn(columns, "TIMESTAMP", "DATE", "PRICE_DATE")
	priceIndex, okPrice := firstColumn(columns, "CLOSE", "ADJUSTED_CLOSE", "ADJ_CLOSE", "ADJ_CLOSE_PRICE")
	symbolIndex, hasSymbol := firstColumn(columns, "SYMBOL", "TICKER")
	if !okDate || !okPrice {
		return InvestmentPriceImportResult{}, ErrInvestmentPriceImportInvalid
	}

	result := InvestmentPriceImportResult{Errors: []string{}, Prices: []domain.InvestmentPrice{}}
	rowNumber := 1
	for {
		record, err := reader.Read()
		if errors.Is(err, io.EOF) {
			break
		}
		rowNumber++
		if err != nil {
			result.Skipped++
			result.Errors = append(result.Errors, "row "+strconv.Itoa(rowNumber)+": "+err.Error())
			continue
		}
		if isBlankCSVRecord(record) {
			continue
		}
		symbol := strings.ToUpper(strings.TrimSpace(input.Symbol))
		if hasSymbol {
			symbol = strings.ToUpper(csvValue(record, symbolIndex))
		}
		price, err := parseAlphaVantagePriceRecord(input.OrganizationID, record, symbol, dateIndex, priceIndex, source)
		if err != nil {
			result.Skipped++
			result.Errors = append(result.Errors, "row "+strconv.Itoa(rowNumber)+": "+err.Error())
			continue
		}
		if err := s.upsertPrice(ctx, price); err != nil {
			result.Skipped++
			result.Errors = append(result.Errors, "row "+strconv.Itoa(rowNumber)+": "+err.Error())
			continue
		}
		result.Imported++
		result.Prices = append(result.Prices, price)
	}
	if result.Imported == 0 && result.Skipped == 0 {
		return result, ErrInvestmentPriceImportInvalid
	}
	return result, nil
}

func (s InvestmentService) ImportBrokerHoldingsCSV(ctx context.Context, input ImportInvestmentPricesInput) (InvestmentPriceImportResult, error) {
	if strings.TrimSpace(input.CSV) == "" {
		return InvestmentPriceImportResult{}, ErrInvestmentPriceImportInvalid
	}
	source := strings.TrimSpace(input.Source)
	if source == "" {
		source = "broker_holdings_csv"
	}

	reader := csv.NewReader(strings.NewReader(input.CSV))
	reader.TrimLeadingSpace = true
	reader.FieldsPerRecord = -1
	header, err := reader.Read()
	if err != nil {
		return InvestmentPriceImportResult{}, ErrInvestmentPriceImportInvalid
	}
	columns := nseEquityColumnMap(header)
	symbolIndex, okSymbol := firstColumn(columns, "SYMBOL", "TRADING_SYMBOL", "TRADINGSYMBOL", "TICKER", "INSTRUMENT", "STOCK", "SCRIP")
	isinIndex, hasISIN := firstColumn(columns, "ISIN", "ISIN_CODE")
	dateIndex, hasDate := firstColumn(columns, "PRICE_DATE", "AS_OF_DATE", "DATE", "HOLDING_DATE", "TRADE_DATE")
	priceIndex, okPrice := firstColumn(columns, "LAST_TRADED_PRICE", "LAST_TRADED_PRICE_LTP", "LTP", "LAST_PRICE", "CURRENT_PRICE", "MARKET_PRICE", "CLOSE", "CLOSING_PRICE")
	if !okSymbol && !hasISIN {
		return InvestmentPriceImportResult{}, ErrInvestmentPriceImportInvalid
	}
	if !okPrice {
		return InvestmentPriceImportResult{}, ErrInvestmentPriceImportInvalid
	}

	defaultDate := time.Now().UTC().Truncate(24 * time.Hour)
	result := InvestmentPriceImportResult{Errors: []string{}, Prices: []domain.InvestmentPrice{}}
	rowNumber := 1
	for {
		record, err := reader.Read()
		if errors.Is(err, io.EOF) {
			break
		}
		rowNumber++
		if err != nil {
			result.Skipped++
			result.Errors = append(result.Errors, "row "+strconv.Itoa(rowNumber)+": "+err.Error())
			continue
		}
		if isBlankCSVRecord(record) {
			continue
		}
		price, err := parseBrokerHoldingPriceRecord(input.OrganizationID, record, symbolIndex, okSymbol, isinIndex, hasISIN, dateIndex, hasDate, priceIndex, source, defaultDate)
		if err != nil {
			result.Skipped++
			result.Errors = append(result.Errors, "row "+strconv.Itoa(rowNumber)+": "+err.Error())
			continue
		}
		if err := s.upsertPrice(ctx, price); err != nil {
			result.Skipped++
			result.Errors = append(result.Errors, "row "+strconv.Itoa(rowNumber)+": "+err.Error())
			continue
		}
		result.Imported++
		result.Prices = append(result.Prices, price)
	}
	if result.Imported == 0 && result.Skipped == 0 {
		return result, ErrInvestmentPriceImportInvalid
	}
	return result, nil
}

func (s InvestmentService) ImportZerodhaHoldingsCSV(ctx context.Context, input ImportInvestmentPricesInput) (InvestmentPriceImportResult, error) {
	if strings.TrimSpace(input.Source) == "" {
		input.Source = "zerodha_holdings_csv"
	}
	return s.ImportBrokerHoldingsCSV(ctx, input)
}

func (s InvestmentService) ImportGrowwHoldingsCSV(ctx context.Context, input ImportInvestmentPricesInput) (InvestmentPriceImportResult, error) {
	if strings.TrimSpace(input.Source) == "" {
		input.Source = "groww_holdings_csv"
	}
	return s.ImportBrokerHoldingsCSV(ctx, input)
}

func (s InvestmentService) ImportUpstoxHoldingsCSV(ctx context.Context, input ImportInvestmentPricesInput) (InvestmentPriceImportResult, error) {
	if strings.TrimSpace(input.Source) == "" {
		input.Source = "upstox_holdings_csv"
	}
	return s.ImportBrokerHoldingsCSV(ctx, input)
}

func (s InvestmentService) ImportAngelOneHoldingsCSV(ctx context.Context, input ImportInvestmentPricesInput) (InvestmentPriceImportResult, error) {
	if strings.TrimSpace(input.Source) == "" {
		input.Source = "angelone_holdings_csv"
	}
	return s.ImportBrokerHoldingsCSV(ctx, input)
}

func (s InvestmentService) ImportDhanHoldingsCSV(ctx context.Context, input ImportInvestmentPricesInput) (InvestmentPriceImportResult, error) {
	if strings.TrimSpace(input.Source) == "" {
		input.Source = "dhan_holdings_csv"
	}
	return s.ImportBrokerHoldingsCSV(ctx, input)
}

func (s InvestmentService) ImportICICIDirectHoldingsCSV(ctx context.Context, input ImportInvestmentPricesInput) (InvestmentPriceImportResult, error) {
	if strings.TrimSpace(input.Source) == "" {
		input.Source = "icicidirect_holdings_csv"
	}
	return s.ImportBrokerHoldingsCSV(ctx, input)
}

func (s InvestmentService) ImportHDFCSkyHoldingsCSV(ctx context.Context, input ImportInvestmentPricesInput) (InvestmentPriceImportResult, error) {
	if strings.TrimSpace(input.Source) == "" {
		input.Source = "hdfcsky_holdings_csv"
	}
	return s.ImportBrokerHoldingsCSV(ctx, input)
}

func (s InvestmentService) ImportKotakNeoHoldingsCSV(ctx context.Context, input ImportInvestmentPricesInput) (InvestmentPriceImportResult, error) {
	if strings.TrimSpace(input.Source) == "" {
		input.Source = "kotakneo_holdings_csv"
	}
	return s.ImportBrokerHoldingsCSV(ctx, input)
}

func (s InvestmentService) ImportPaytmMoneyHoldingsCSV(ctx context.Context, input ImportInvestmentPricesInput) (InvestmentPriceImportResult, error) {
	if strings.TrimSpace(input.Source) == "" {
		input.Source = "paytmmoney_holdings_csv"
	}
	return s.ImportBrokerHoldingsCSV(ctx, input)
}

func (s InvestmentService) ImportMotilalOswalHoldingsCSV(ctx context.Context, input ImportInvestmentPricesInput) (InvestmentPriceImportResult, error) {
	if strings.TrimSpace(input.Source) == "" {
		input.Source = "motilaloswal_holdings_csv"
	}
	return s.ImportBrokerHoldingsCSV(ctx, input)
}

func (s InvestmentService) ImportSharekhanHoldingsCSV(ctx context.Context, input ImportInvestmentPricesInput) (InvestmentPriceImportResult, error) {
	if strings.TrimSpace(input.Source) == "" {
		input.Source = "sharekhan_holdings_csv"
	}
	return s.ImportBrokerHoldingsCSV(ctx, input)
}

func (s InvestmentService) ImportFivePaisaHoldingsCSV(ctx context.Context, input ImportInvestmentPricesInput) (InvestmentPriceImportResult, error) {
	if strings.TrimSpace(input.Source) == "" {
		input.Source = "fivepaisa_holdings_csv"
	}
	return s.ImportBrokerHoldingsCSV(ctx, input)
}

func (s InvestmentService) ImportAxisDirectHoldingsCSV(ctx context.Context, input ImportInvestmentPricesInput) (InvestmentPriceImportResult, error) {
	if strings.TrimSpace(input.Source) == "" {
		input.Source = "axisdirect_holdings_csv"
	}
	return s.ImportBrokerHoldingsCSV(ctx, input)
}

func (s InvestmentService) ImportSBISecuritiesHoldingsCSV(ctx context.Context, input ImportInvestmentPricesInput) (InvestmentPriceImportResult, error) {
	if strings.TrimSpace(input.Source) == "" {
		input.Source = "sbisecurities_holdings_csv"
	}
	return s.ImportBrokerHoldingsCSV(ctx, input)
}

func (s InvestmentService) ImportNuvamaHoldingsCSV(ctx context.Context, input ImportInvestmentPricesInput) (InvestmentPriceImportResult, error) {
	if strings.TrimSpace(input.Source) == "" {
		input.Source = "nuvama_holdings_csv"
	}
	return s.ImportBrokerHoldingsCSV(ctx, input)
}

func (s InvestmentService) ImportGeojitHoldingsCSV(ctx context.Context, input ImportInvestmentPricesInput) (InvestmentPriceImportResult, error) {
	if strings.TrimSpace(input.Source) == "" {
		input.Source = "geojit_holdings_csv"
	}
	return s.ImportBrokerHoldingsCSV(ctx, input)
}

func (s InvestmentService) ImportBSEEquityCSV(ctx context.Context, input ImportInvestmentPricesInput) (InvestmentPriceImportResult, error) {
	if strings.TrimSpace(input.CSV) == "" {
		return InvestmentPriceImportResult{}, ErrInvestmentPriceImportInvalid
	}
	source := strings.TrimSpace(input.Source)
	if source == "" {
		source = "bse_equity_csv"
	}

	reader := csv.NewReader(strings.NewReader(input.CSV))
	reader.TrimLeadingSpace = true
	reader.FieldsPerRecord = -1
	header, err := reader.Read()
	if err != nil {
		return InvestmentPriceImportResult{}, ErrInvestmentPriceImportInvalid
	}
	columns := nseEquityColumnMap(header)
	symbolIndex, okSymbol := firstColumn(columns, "SC_CODE", "SCRIP_CODE", "SECURITY_CODE", "CODE", "SYMBOL", "TICKER")
	dateIndex, okDate := firstColumn(columns, "TRADING_DATE", "TRADE_DATE", "TRADDT", "DATE", "PRICE_DATE")
	priceIndex, okPrice := firstColumn(columns, "CLOSE", "CLOSE_PRICE", "CLOSEPRICE", "CLS_PR", "CLSPRIC")
	seriesIndex, hasSeries := firstColumn(columns, "SERIES", "SC_GROUP", "GROUP")
	if !okSymbol || !okDate || !okPrice {
		return InvestmentPriceImportResult{}, ErrInvestmentPriceImportInvalid
	}

	result := InvestmentPriceImportResult{Errors: []string{}, Prices: []domain.InvestmentPrice{}}
	rowNumber := 1
	for {
		record, err := reader.Read()
		if errors.Is(err, io.EOF) {
			break
		}
		rowNumber++
		if err != nil {
			result.Skipped++
			result.Errors = append(result.Errors, "row "+strconv.Itoa(rowNumber)+": "+err.Error())
			continue
		}
		if isBlankCSVRecord(record) {
			continue
		}
		if hasSeries && shouldSkipBSESeries(csvValue(record, seriesIndex)) {
			continue
		}
		price, err := parseBSEEquityPriceRecord(input.OrganizationID, record, symbolIndex, dateIndex, priceIndex, source)
		if err != nil {
			result.Skipped++
			result.Errors = append(result.Errors, "row "+strconv.Itoa(rowNumber)+": "+err.Error())
			continue
		}
		if err := s.upsertPrice(ctx, price); err != nil {
			result.Skipped++
			result.Errors = append(result.Errors, "row "+strconv.Itoa(rowNumber)+": "+err.Error())
			continue
		}
		result.Imported++
		result.Prices = append(result.Prices, price)
	}
	if result.Imported == 0 && result.Skipped == 0 {
		return result, ErrInvestmentPriceImportInvalid
	}
	return result, nil
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

func buildInvestmentDividendJournal(input CreateInvestmentDividendInput, dividend domain.InvestmentDividend) (domain.JournalTransaction, error) {
	now := time.Now().UTC()
	transaction := domain.JournalTransaction{
		OrganizationID:  input.OrganizationID,
		TransactionDate: input.DividendDate,
		Memo:            "Investment dividend " + input.Symbol,
		SourceModule:    domain.SourceModuleManual,
		Status:          domain.JournalStatusPosted,
		PostedAt:        &now,
		Splits: []domain.LedgerSplit{
			{
				OrganizationID: input.OrganizationID,
				AccountID:      input.CashAccountID,
				DebitMinor:     dividend.AmountMinor,
				Currency:       dividend.Currency,
			},
			{
				OrganizationID: input.OrganizationID,
				AccountID:      input.IncomeAccountID,
				CreditMinor:    dividend.AmountMinor,
				Currency:       dividend.Currency,
			},
		},
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

func (s InvestmentService) DividendReport(ctx context.Context, organizationID string, from time.Time, to time.Time) (InvestmentDividendReport, error) {
	var rows []domain.InvestmentDividend
	err := s.db.WithContext(ctx).
		Preload("Account").
		Where("organization_id = ? AND dividend_date BETWEEN ? AND ?", organizationID, from, to).
		Order("dividend_date ASC, created_at ASC").
		Find(&rows).
		Error
	if err != nil {
		return InvestmentDividendReport{}, err
	}

	report := InvestmentDividendReport{FromDate: from, ToDate: to, Rows: rows}
	for _, row := range rows {
		report.TotalAmountMinor += row.AmountMinor
	}
	return report, nil
}

func (s InvestmentService) TaxLotReport(ctx context.Context, organizationID string, asOf time.Time) (InvestmentTaxLotReport, error) {
	var lots []domain.InvestmentLot
	if err := s.db.WithContext(ctx).
		Where("organization_id = ? AND acquisition_date <= ?", organizationID, asOf).
		Order("symbol ASC, acquisition_date ASC, created_at ASC").
		Find(&lots).
		Error; err != nil {
		return InvestmentTaxLotReport{}, err
	}

	report := InvestmentTaxLotReport{AsOfDate: asOf, Rows: make([]InvestmentTaxLotRow, 0, len(lots))}
	for _, lot := range lots {
		var dispositions []domain.InvestmentDisposition
		if err := s.db.WithContext(ctx).
			Where("organization_id = ? AND investment_lot_id = ? AND sale_date <= ?", organizationID, lot.ID, asOf).
			Find(&dispositions).
			Error; err != nil {
			return InvestmentTaxLotReport{}, err
		}

		row := InvestmentTaxLotRow{
			LotID:                   lot.ID,
			AccountID:               lot.AccountID,
			Symbol:                  lot.Symbol,
			SecurityName:            lot.SecurityName,
			AcquisitionDate:         lot.AcquisitionDate,
			QuantityMillis:          lot.QuantityMillis,
			RemainingQuantityMillis: lot.RemainingQuantityMillis,
			DisposedQuantityMillis:  lot.QuantityMillis - lot.RemainingQuantityMillis,
			CostBasisMinor:          lot.CostBasisMinor,
			RemainingCostBasisMinor: proportionalCost(lot.CostBasisMinor, lot.RemainingQuantityMillis, lot.QuantityMillis),
			Currency:                lot.Currency,
			CostMethod:              lot.CostMethod,
		}
		if lot.QuantityMillis > 0 {
			row.UnitCostMinor = lot.CostBasisMinor * 1000 / lot.QuantityMillis
		}
		for _, disposition := range dispositions {
			row.DisposedCostBasisMinor += disposition.AllocatedCostBasisMinor
			row.ProceedsMinor += disposition.ProceedsMinor
			row.RealizedGainLossMinor += disposition.RealizedGainLossMinor
		}

		report.TotalQuantityMillis += row.QuantityMillis
		report.TotalRemainingMillis += row.RemainingQuantityMillis
		report.TotalCostBasisMinor += row.CostBasisMinor
		report.TotalRemainingCostMinor += row.RemainingCostBasisMinor
		report.TotalProceedsMinor += row.ProceedsMinor
		report.TotalRealizedMinor += row.RealizedGainLossMinor
		report.Rows = append(report.Rows, row)
	}
	return report, nil
}

func (s InvestmentService) TaxAdjustmentReport(ctx context.Context, organizationID string, from time.Time, to time.Time, windowDays int) (InvestmentTaxAdjustmentReport, error) {
	if windowDays <= 0 {
		windowDays = 30
	}
	var dispositions []domain.InvestmentDisposition
	if err := s.db.WithContext(ctx).
		Preload("InvestmentLot").
		Where("organization_id = ? AND sale_date >= ? AND sale_date <= ? AND realized_gain_loss_minor < 0", organizationID, from, to).
		Order("sale_date ASC, created_at ASC").
		Find(&dispositions).
		Error; err != nil {
		return InvestmentTaxAdjustmentReport{}, err
	}

	report := InvestmentTaxAdjustmentReport{
		FromDate:   from,
		ToDate:     to,
		Rule:       "loss_repurchase_window",
		WindowDays: windowDays,
		Rows:       []InvestmentTaxAdjustmentRow{},
	}
	for _, disposition := range dispositions {
		lot := disposition.InvestmentLot
		if lot.ID == "" {
			continue
		}
		windowStart := disposition.SaleDate
		windowEnd := disposition.SaleDate.AddDate(0, 0, windowDays)
		var replacements []domain.InvestmentLot
		if err := s.db.WithContext(ctx).
			Where("organization_id = ? AND account_id = ? AND symbol = ? AND id <> ? AND acquisition_date >= ? AND acquisition_date <= ?",
				organizationID, lot.AccountID, lot.Symbol, lot.ID, windowStart, windowEnd).
			Order("acquisition_date ASC, created_at ASC").
			Find(&replacements).
			Error; err != nil {
			return InvestmentTaxAdjustmentReport{}, err
		}
		var replacementQuantity int64
		replacementIDs := make([]string, 0, len(replacements))
		for _, replacement := range replacements {
			if replacementQuantity >= disposition.QuantityMillis {
				break
			}
			quantity := replacement.QuantityMillis
			if replacementQuantity+quantity > disposition.QuantityMillis {
				quantity = disposition.QuantityMillis - replacementQuantity
			}
			replacementQuantity += quantity
			replacementIDs = append(replacementIDs, replacement.ID)
		}
		if replacementQuantity == 0 {
			continue
		}
		realizedLoss := -disposition.RealizedGainLossMinor
		deferredLoss := realizedLoss * replacementQuantity / disposition.QuantityMillis
		row := InvestmentTaxAdjustmentRow{
			DispositionID:             disposition.ID,
			LotID:                     lot.ID,
			AccountID:                 lot.AccountID,
			Symbol:                    lot.Symbol,
			SaleDate:                  disposition.SaleDate,
			QuantityMillis:            disposition.QuantityMillis,
			ProceedsMinor:             disposition.ProceedsMinor,
			AllocatedCostBasisMinor:   disposition.AllocatedCostBasisMinor,
			RealizedLossMinor:         realizedLoss,
			ReplacementQuantityMillis: replacementQuantity,
			DeferredLossMinor:         deferredLoss,
			ReplacementLotIDs:         replacementIDs,
			WindowStart:               windowStart,
			WindowEnd:                 windowEnd,
			Currency:                  disposition.Currency,
			Notes:                     disposition.Notes,
		}
		report.TotalLossMinor += realizedLoss
		report.TotalDeferredLossMinor += deferredLoss
		report.TotalReplacementQuantity += replacementQuantity
		report.Rows = append(report.Rows, row)
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

func parseInvestmentPriceRecord(organizationID string, record []string, defaultSource string) (domain.InvestmentPrice, error) {
	if len(record) < 3 {
		return domain.InvestmentPrice{}, errors.New("expected symbol, price_date, price_minor")
	}
	symbol := strings.ToUpper(strings.TrimSpace(record[0]))
	priceDate, err := time.Parse("2006-01-02", strings.TrimSpace(record[1]))
	if err != nil {
		return domain.InvestmentPrice{}, errors.New("invalid price_date")
	}
	priceMinor, err := strconv.ParseInt(strings.TrimSpace(record[2]), 10, 64)
	if err != nil || priceMinor <= 0 {
		return domain.InvestmentPrice{}, errors.New("invalid price_minor")
	}
	currency := "INR"
	if len(record) >= 4 && strings.TrimSpace(record[3]) != "" {
		currency = strings.ToUpper(strings.TrimSpace(record[3]))
	}
	source := defaultSource
	if len(record) >= 5 && strings.TrimSpace(record[4]) != "" {
		source = strings.TrimSpace(record[4])
	}
	if symbol == "" {
		return domain.InvestmentPrice{}, errors.New("missing symbol")
	}
	return domain.InvestmentPrice{
		OrganizationID: organizationID,
		Symbol:         symbol,
		PriceDate:      priceDate,
		PriceMinor:     priceMinor,
		Currency:       currency,
		Source:         source,
	}, nil
}

func parseNSEEquityPriceRecord(organizationID string, record []string, symbolIndex int, dateIndex int, priceIndex int, source string) (domain.InvestmentPrice, error) {
	symbol := strings.ToUpper(strings.TrimSpace(csvValue(record, symbolIndex)))
	if symbol == "" {
		return domain.InvestmentPrice{}, errors.New("missing symbol")
	}
	priceDate, err := parseNSEMarketDate(csvValue(record, dateIndex))
	if err != nil {
		return domain.InvestmentPrice{}, err
	}
	priceMinor, err := parseDecimalMinor(csvValue(record, priceIndex))
	if err != nil || priceMinor <= 0 {
		return domain.InvestmentPrice{}, errors.New("invalid close price")
	}
	return domain.InvestmentPrice{
		OrganizationID: organizationID,
		Symbol:         symbol,
		PriceDate:      priceDate,
		PriceMinor:     priceMinor,
		Currency:       "INR",
		Source:         source,
	}, nil
}

func parseYahooFinancePriceRecord(organizationID string, record []string, symbol string, dateIndex int, priceIndex int, source string) (domain.InvestmentPrice, error) {
	symbol = strings.ToUpper(strings.TrimSpace(symbol))
	if symbol == "" {
		return domain.InvestmentPrice{}, errors.New("missing symbol")
	}
	priceDate, err := parseNSEMarketDate(csvValue(record, dateIndex))
	if err != nil {
		return domain.InvestmentPrice{}, err
	}
	priceMinor, err := parseDecimalMinor(csvValue(record, priceIndex))
	if err != nil || priceMinor <= 0 {
		return domain.InvestmentPrice{}, errors.New("invalid close price")
	}
	return domain.InvestmentPrice{
		OrganizationID: organizationID,
		Symbol:         symbol,
		PriceDate:      priceDate,
		PriceMinor:     priceMinor,
		Currency:       "INR",
		Source:         source,
	}, nil
}

func parseAlphaVantagePriceRecord(organizationID string, record []string, symbol string, dateIndex int, priceIndex int, source string) (domain.InvestmentPrice, error) {
	symbol = strings.ToUpper(strings.TrimSpace(symbol))
	if symbol == "" {
		return domain.InvestmentPrice{}, errors.New("missing symbol")
	}
	priceDate, err := parseNSEMarketDate(csvValue(record, dateIndex))
	if err != nil {
		return domain.InvestmentPrice{}, err
	}
	priceMinor, err := parseDecimalMinor(csvValue(record, priceIndex))
	if err != nil || priceMinor <= 0 {
		return domain.InvestmentPrice{}, errors.New("invalid close price")
	}
	return domain.InvestmentPrice{
		OrganizationID: organizationID,
		Symbol:         symbol,
		PriceDate:      priceDate,
		PriceMinor:     priceMinor,
		Currency:       "INR",
		Source:         source,
	}, nil
}

func parseBSEEquityPriceRecord(organizationID string, record []string, symbolIndex int, dateIndex int, priceIndex int, source string) (domain.InvestmentPrice, error) {
	symbol := strings.ToUpper(strings.TrimSpace(csvValue(record, symbolIndex)))
	if symbol == "" {
		return domain.InvestmentPrice{}, errors.New("missing symbol")
	}
	priceDate, err := parseNSEMarketDate(csvValue(record, dateIndex))
	if err != nil {
		return domain.InvestmentPrice{}, err
	}
	priceMinor, err := parseDecimalMinor(csvValue(record, priceIndex))
	if err != nil || priceMinor <= 0 {
		return domain.InvestmentPrice{}, errors.New("invalid close price")
	}
	return domain.InvestmentPrice{
		OrganizationID: organizationID,
		Symbol:         symbol,
		PriceDate:      priceDate,
		PriceMinor:     priceMinor,
		Currency:       "INR",
		Source:         source,
	}, nil
}

func parseBrokerHoldingPriceRecord(organizationID string, record []string, symbolIndex int, hasSymbol bool, isinIndex int, hasISIN bool, dateIndex int, hasDate bool, priceIndex int, source string, defaultDate time.Time) (domain.InvestmentPrice, error) {
	symbol := ""
	if hasSymbol {
		symbol = strings.ToUpper(strings.TrimSpace(csvValue(record, symbolIndex)))
	}
	if symbol == "" && hasISIN {
		symbol = strings.ToUpper(strings.TrimSpace(csvValue(record, isinIndex)))
	}
	if symbol == "" {
		return domain.InvestmentPrice{}, errors.New("missing symbol")
	}
	priceDate := defaultDate
	if hasDate && strings.TrimSpace(csvValue(record, dateIndex)) != "" {
		parsedDate, err := parseNSEMarketDate(csvValue(record, dateIndex))
		if err != nil {
			return domain.InvestmentPrice{}, err
		}
		priceDate = parsedDate
	}
	priceMinor, err := parseDecimalMinor(csvValue(record, priceIndex))
	if err != nil || priceMinor <= 0 {
		return domain.InvestmentPrice{}, errors.New("invalid broker price")
	}
	return domain.InvestmentPrice{
		OrganizationID: organizationID,
		Symbol:         symbol,
		PriceDate:      priceDate,
		PriceMinor:     priceMinor,
		Currency:       "INR",
		Source:         source,
	}, nil
}

func shouldSkipBSESeries(value string) bool {
	series := strings.ToUpper(strings.TrimSpace(value))
	if series == "" {
		return false
	}
	switch series {
	case "A", "B", "E", "F", "IF", "M", "MS", "MT", "P", "R", "T", "X", "XT", "Z":
		return false
	default:
		return true
	}
}

func nseEquityColumnMap(header []string) map[string]int {
	columns := make(map[string]int, len(header))
	for index, value := range header {
		key := normalizeProviderColumn(value)
		if key != "" {
			columns[key] = index
		}
	}
	return columns
}

func normalizeProviderColumn(value string) string {
	value = strings.ToUpper(strings.TrimSpace(value))
	value = strings.ReplaceAll(value, " ", "_")
	value = strings.ReplaceAll(value, "-", "_")
	return value
}

func firstColumn(columns map[string]int, names ...string) (int, bool) {
	for _, name := range names {
		if index, ok := columns[normalizeProviderColumn(name)]; ok {
			return index, true
		}
	}
	return 0, false
}

func csvValue(record []string, index int) string {
	if index < 0 || index >= len(record) {
		return ""
	}
	return strings.TrimSpace(record[index])
}

func parseNSEMarketDate(value string) (time.Time, error) {
	value = strings.TrimSpace(value)
	for _, layout := range []string{"2006-01-02", "02-Jan-2006", "02-Jan-06", "02/01/2006", "02-01-2006"} {
		if parsed, err := time.Parse(layout, value); err == nil {
			return parsed, nil
		}
	}
	return time.Time{}, errors.New("invalid trade date")
}

func parseDecimalMinor(value string) (int64, error) {
	normalized := strings.ToUpper(strings.TrimSpace(value))
	normalized = strings.ReplaceAll(normalized, "₹", "")
	normalized = strings.ReplaceAll(normalized, "INR", "")
	normalized = strings.ReplaceAll(normalized, "RS.", "")
	normalized = strings.ReplaceAll(normalized, "RS", "")
	normalized = strings.ReplaceAll(normalized, ",", "")
	amount, err := strconv.ParseFloat(strings.TrimSpace(normalized), 64)
	if err != nil {
		return 0, err
	}
	return int64(amount*100 + 0.5), nil
}

func parseAMFINAVLine(organizationID string, line string, symbolMode string) (domain.InvestmentPrice, bool, error) {
	line = strings.TrimSpace(line)
	if line == "" || strings.HasPrefix(line, "Scheme Code") || strings.HasPrefix(line, "Open Ended") || strings.HasPrefix(line, "Close Ended") {
		return domain.InvestmentPrice{}, true, nil
	}
	record := strings.Split(line, ";")
	if len(record) < 6 {
		return domain.InvestmentPrice{}, true, nil
	}
	schemeCode := strings.TrimSpace(record[0])
	isinGrowth := strings.TrimSpace(record[2])
	schemeName := strings.TrimSpace(record[3])
	navText := strings.TrimSpace(record[4])
	dateText := strings.TrimSpace(record[5])
	if schemeCode == "" || strings.EqualFold(navText, "N.A.") || strings.EqualFold(navText, "NA") {
		return domain.InvestmentPrice{}, true, nil
	}

	symbol := schemeCode
	switch symbolMode {
	case "isin_growth":
		symbol = isinGrowth
	case "scheme_name":
		symbol = schemeName
	}
	symbol = strings.ToUpper(strings.TrimSpace(symbol))
	if symbol == "" {
		return domain.InvestmentPrice{}, false, errors.New("missing symbol for selected AMFI symbol mode")
	}
	priceMinor, err := decimalToMinor(navText)
	if err != nil || priceMinor <= 0 {
		return domain.InvestmentPrice{}, false, errors.New("invalid net asset value")
	}
	priceDate, err := parseAMFIDate(dateText)
	if err != nil {
		return domain.InvestmentPrice{}, false, errors.New("invalid NAV date")
	}
	return domain.InvestmentPrice{
		OrganizationID: organizationID,
		Symbol:         symbol,
		PriceDate:      priceDate,
		PriceMinor:     priceMinor,
		Currency:       "INR",
		Source:         "amfi_nav",
	}, false, nil
}

func parseAMFIDate(value string) (time.Time, error) {
	value = strings.TrimSpace(value)
	layouts := []string{"02-Jan-2006", "2-Jan-2006", "02/01/2006", "2006-01-02"}
	for _, layout := range layouts {
		parsed, err := time.Parse(layout, value)
		if err == nil {
			return parsed, nil
		}
	}
	return time.Time{}, errors.New("invalid AMFI date")
}

func decimalToMinor(value string) (int64, error) {
	value = strings.TrimSpace(strings.ReplaceAll(value, ",", ""))
	if value == "" {
		return 0, errors.New("empty decimal")
	}
	parts := strings.SplitN(value, ".", 2)
	whole, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil {
		return 0, err
	}
	fraction := "00"
	if len(parts) == 2 {
		fraction = parts[1]
	}
	if len(fraction) > 2 {
		fraction = fraction[:2]
	}
	for len(fraction) < 2 {
		fraction += "0"
	}
	cents, err := strconv.ParseInt(fraction, 10, 64)
	if err != nil {
		return 0, err
	}
	return whole*100 + cents, nil
}

func (s InvestmentService) upsertPrice(ctx context.Context, price domain.InvestmentPrice) error {
	return s.db.WithContext(ctx).Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "organization_id"}, {Name: "symbol"}, {Name: "price_date"}},
		DoUpdates: clause.AssignmentColumns([]string{"price_minor", "currency", "source", "updated_at"}),
	}).Create(&price).Error
}

func isBlankCSVRecord(record []string) bool {
	for _, field := range record {
		if strings.TrimSpace(field) != "" {
			return false
		}
	}
	return true
}

func isInvestmentPriceHeader(record []string) bool {
	if len(record) < 3 {
		return false
	}
	return strings.EqualFold(strings.TrimSpace(record[0]), "symbol") &&
		strings.EqualFold(strings.TrimSpace(record[1]), "price_date")
}
