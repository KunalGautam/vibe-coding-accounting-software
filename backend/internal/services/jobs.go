package services

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

type JobService struct {
	db          *gorm.DB
	emailSender EmailSender
}

var marketDataHTTPTransport http.RoundTripper = http.DefaultTransport

type RecurringInvoiceJobResult struct {
	OrganizationsProcessed int `json:"organizations_processed"`
	GeneratedCount         int `json:"generated_count"`
}

type BackupJobResult struct {
	OrganizationsProcessed int `json:"organizations_processed"`
	CreatedCount           int `json:"created_count"`
}

type ScheduledReportJobResult = ScheduledReportRunResult

type MarketDataImportJobInput struct {
	Path           string
	URL            string
	BearerToken    string
	TimeoutSeconds int
	Format         string
	SymbolMode     string
	Source         string
	Symbol         string
	OrganizationID string
}

type MarketDataImportJobResult struct {
	OrganizationsProcessed int      `json:"organizations_processed"`
	ImportedCount          int      `json:"imported_count"`
	SkippedCount           int      `json:"skipped_count"`
	Errors                 []string `json:"errors"`
}

func NewJobService(db *gorm.DB) JobService {
	return JobService{db: db}
}

func NewJobServiceWithEmail(db *gorm.DB, emailSender EmailSender) JobService {
	return JobService{db: db, emailSender: emailSender}
}

func (s JobService) GenerateDueRecurringInvoices(ctx context.Context, asOf time.Time) (RecurringInvoiceJobResult, error) {
	var organizations []domain.Organization
	if err := s.db.WithContext(ctx).Order("name ASC").Find(&organizations).Error; err != nil {
		return RecurringInvoiceJobResult{}, err
	}

	recurringInvoices := NewRecurringInvoiceService(s.db, NewTaxService(s.db))
	result := RecurringInvoiceJobResult{OrganizationsProcessed: len(organizations)}
	for _, organization := range organizations {
		generated, err := recurringInvoices.GenerateDue(ctx, organization.ID, asOf)
		if err != nil {
			return RecurringInvoiceJobResult{}, err
		}
		result.GeneratedCount += generated.GeneratedCount
	}
	return result, nil
}

func (s JobService) RunDueScheduledReports(ctx context.Context, asOf time.Time) (ScheduledReportJobResult, error) {
	return NewReportServiceWithEmail(s.db, s.emailSender).RunDueScheduledReports(ctx, asOf)
}

func (s JobService) ImportScheduledMarketData(ctx context.Context, input MarketDataImportJobInput) (MarketDataImportJobResult, error) {
	payload, err := marketDataPayload(ctx, input)
	if err != nil {
		return MarketDataImportJobResult{}, err
	}

	query := s.db.WithContext(ctx).Order("name ASC")
	if input.OrganizationID != "" {
		query = query.Where("id = ?", input.OrganizationID)
	}
	var organizations []domain.Organization
	if err := query.Find(&organizations).Error; err != nil {
		return MarketDataImportJobResult{}, err
	}

	investments := NewInvestmentService(s.db)
	result := MarketDataImportJobResult{OrganizationsProcessed: len(organizations), Errors: []string{}}
	format := input.Format
	if format == "" {
		format = "amfi"
	}
	for _, organization := range organizations {
		var importResult InvestmentPriceImportResult
		var err error
		switch format {
		case "yahoo_finance_csv":
			source := input.Source
			if source == "" {
				source = "yahoo_finance_csv"
			}
			importResult, err = investments.ImportYahooFinanceCSV(ctx, ImportInvestmentPricesInput{
				OrganizationID: organization.ID,
				CSV:            string(payload),
				Source:         source,
				Symbol:         input.Symbol,
			})
		case "alpha_vantage_csv":
			source := input.Source
			if source == "" {
				source = "alpha_vantage_csv"
			}
			importResult, err = investments.ImportAlphaVantageCSV(ctx, ImportInvestmentPricesInput{
				OrganizationID: organization.ID,
				CSV:            string(payload),
				Source:         source,
				Symbol:         input.Symbol,
			})
		case "broker_holdings_csv":
			source := input.Source
			if source == "" {
				source = "broker_holdings_csv"
			}
			importResult, err = investments.ImportBrokerHoldingsCSV(ctx, ImportInvestmentPricesInput{
				OrganizationID: organization.ID,
				CSV:            string(payload),
				Source:         source,
			})
		case "zerodha_holdings_csv":
			source := input.Source
			if source == "" {
				source = "zerodha_holdings_csv"
			}
			importResult, err = investments.ImportZerodhaHoldingsCSV(ctx, ImportInvestmentPricesInput{
				OrganizationID: organization.ID,
				CSV:            string(payload),
				Source:         source,
			})
		case "groww_holdings_csv":
			source := input.Source
			if source == "" {
				source = "groww_holdings_csv"
			}
			importResult, err = investments.ImportGrowwHoldingsCSV(ctx, ImportInvestmentPricesInput{
				OrganizationID: organization.ID,
				CSV:            string(payload),
				Source:         source,
			})
		case "upstox_holdings_csv":
			source := input.Source
			if source == "" {
				source = "upstox_holdings_csv"
			}
			importResult, err = investments.ImportUpstoxHoldingsCSV(ctx, ImportInvestmentPricesInput{
				OrganizationID: organization.ID,
				CSV:            string(payload),
				Source:         source,
			})
		case "angelone_holdings_csv":
			source := input.Source
			if source == "" {
				source = "angelone_holdings_csv"
			}
			importResult, err = investments.ImportAngelOneHoldingsCSV(ctx, ImportInvestmentPricesInput{
				OrganizationID: organization.ID,
				CSV:            string(payload),
				Source:         source,
			})
		case "dhan_holdings_csv":
			source := input.Source
			if source == "" {
				source = "dhan_holdings_csv"
			}
			importResult, err = investments.ImportDhanHoldingsCSV(ctx, ImportInvestmentPricesInput{
				OrganizationID: organization.ID,
				CSV:            string(payload),
				Source:         source,
			})
		case "icicidirect_holdings_csv":
			source := input.Source
			if source == "" {
				source = "icicidirect_holdings_csv"
			}
			importResult, err = investments.ImportICICIDirectHoldingsCSV(ctx, ImportInvestmentPricesInput{
				OrganizationID: organization.ID,
				CSV:            string(payload),
				Source:         source,
			})
		case "hdfcsky_holdings_csv":
			source := input.Source
			if source == "" {
				source = "hdfcsky_holdings_csv"
			}
			importResult, err = investments.ImportHDFCSkyHoldingsCSV(ctx, ImportInvestmentPricesInput{
				OrganizationID: organization.ID,
				CSV:            string(payload),
				Source:         source,
			})
		case "nse_equity_csv":
			source := input.Source
			if source == "" {
				source = "nse_equity_csv"
			}
			importResult, err = investments.ImportNSEEquityCSV(ctx, ImportInvestmentPricesInput{
				OrganizationID: organization.ID,
				CSV:            string(payload),
				Source:         source,
			})
		case "bse_equity_csv":
			source := input.Source
			if source == "" {
				source = "bse_equity_csv"
			}
			importResult, err = investments.ImportBSEEquityCSV(ctx, ImportInvestmentPricesInput{
				OrganizationID: organization.ID,
				CSV:            string(payload),
				Source:         source,
			})
		case "csv":
			source := input.Source
			if source == "" {
				source = "scheduled_csv"
			}
			importResult, err = investments.ImportPricesCSV(ctx, ImportInvestmentPricesInput{
				OrganizationID: organization.ID,
				CSV:            string(payload),
				Source:         source,
			})
		default:
			importResult, err = investments.ImportAMFINAV(ctx, ImportAMFINAVInput{
				OrganizationID: organization.ID,
				Text:           string(payload),
				SymbolMode:     input.SymbolMode,
			})
		}
		if err != nil {
			return MarketDataImportJobResult{}, err
		}
		result.ImportedCount += importResult.Imported
		result.SkippedCount += importResult.Skipped
		result.Errors = append(result.Errors, importResult.Errors...)
	}
	return result, nil
}

func marketDataPayload(ctx context.Context, input MarketDataImportJobInput) ([]byte, error) {
	if input.URL == "" {
		return os.ReadFile(input.Path)
	}
	timeout := time.Duration(input.TimeoutSeconds) * time.Second
	if timeout <= 0 {
		timeout = 30 * time.Second
	}
	client := http.Client{Timeout: timeout, Transport: marketDataHTTPTransport}
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, input.URL, nil)
	if err != nil {
		return nil, err
	}
	if input.BearerToken != "" {
		request.Header.Set("Authorization", "Bearer "+input.BearerToken)
	}
	response, err := client.Do(request)
	if err != nil {
		return nil, err
	}
	defer response.Body.Close()
	if response.StatusCode < http.StatusOK || response.StatusCode >= http.StatusMultipleChoices {
		return nil, fmt.Errorf("market data provider returned HTTP %d", response.StatusCode)
	}
	return io.ReadAll(response.Body)
}

func (s JobService) CreateScheduledBackups(ctx context.Context, storagePath string, retentionCount int) (BackupJobResult, error) {
	var organizations []domain.Organization
	if err := s.db.WithContext(ctx).Order("name ASC").Find(&organizations).Error; err != nil {
		return BackupJobResult{}, err
	}

	exports := NewDataExportService(s.db)
	result := BackupJobResult{OrganizationsProcessed: len(organizations)}
	for _, organization := range organizations {
		if _, err := exports.CreateBackupSnapshot(ctx, CreateBackupSnapshotInput{
			OrganizationID: organization.ID,
			StoragePath:    storagePath,
			RetentionCount: retentionCount,
		}); err != nil {
			return BackupJobResult{}, err
		}
		result.CreatedCount++
	}
	return result, nil
}
