package services

import (
	"context"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

func TestJobServiceGenerateDueRecurringInvoicesAcrossOrganizations(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	orgOne := createRecurringInvoiceJobFixture(t, db, ctx, "Acme One", "DUE", time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC))
	createRecurringInvoiceJobFixture(t, db, ctx, "Acme Two", "FUT", time.Date(2026, 8, 1, 0, 0, 0, 0, time.UTC))

	result, err := NewJobService(db).GenerateDueRecurringInvoices(ctx, time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("GenerateDueRecurringInvoices() error = %v", err)
	}
	if result.OrganizationsProcessed != 2 {
		t.Fatalf("organizations processed = %d, want 2", result.OrganizationsProcessed)
	}
	if result.GeneratedCount != 1 {
		t.Fatalf("generated count = %d, want 1", result.GeneratedCount)
	}

	var invoices []domain.Invoice
	if err := db.Where("organization_id = ?", orgOne.ID).Find(&invoices).Error; err != nil {
		t.Fatalf("find org one invoices: %v", err)
	}
	if len(invoices) != 1 {
		t.Fatalf("org one invoices = %d, want 1", len(invoices))
	}
}

func TestJobServiceRunDueScheduledReports(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Scheduled Job Co", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create org: %v", err)
	}
	if _, err := NewReportService(db).CreateScheduledReport(ctx, CreateScheduledReportInput{
		OrganizationID: org.ID,
		Name:           "Daily Trial Balance",
		ReportType:     domain.ScheduledReportTrialBalance,
		Frequency:      domain.ScheduledReportFrequencyDaily,
		NextRunAt:      time.Date(2026, 7, 15, 0, 0, 0, 0, time.UTC),
	}); err != nil {
		t.Fatalf("create scheduled report: %v", err)
	}

	result, err := NewJobService(db).RunDueScheduledReports(ctx, time.Date(2026, 7, 15, 12, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("RunDueScheduledReports() error = %v", err)
	}
	if result.ReportsProcessed != 1 || result.CompletedCount != 1 {
		t.Fatalf("unexpected scheduled report job result: %+v", result)
	}
}

func TestJobServiceImportScheduledMarketDataScopesOrganization(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	orgOne := domain.Organization{Name: "Acme One", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	orgTwo := domain.Organization{Name: "Acme Two", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&orgOne).Error; err != nil {
		t.Fatalf("create org one: %v", err)
	}
	if err := db.Create(&orgTwo).Error; err != nil {
		t.Fatalf("create org two: %v", err)
	}
	feedPath := filepath.Join(t.TempDir(), "amfi.txt")
	feed := "Scheme Code;ISIN Div Payout/ ISIN Growth;ISIN Div Reinvestment;Scheme Name;Net Asset Value;Date\n" +
		"INF204K01UN5;INF204K01UN5;;Nifty Index Fund Growth;123.45;31-Jul-2026\n"
	if err := os.WriteFile(feedPath, []byte(feed), 0o600); err != nil {
		t.Fatalf("write feed: %v", err)
	}

	result, err := NewJobService(db).ImportScheduledMarketData(ctx, MarketDataImportJobInput{
		Path:           feedPath,
		Format:         "amfi",
		SymbolMode:     "scheme_code",
		OrganizationID: orgOne.ID,
	})
	if err != nil {
		t.Fatalf("ImportScheduledMarketData() error = %v", err)
	}
	if result.OrganizationsProcessed != 1 || result.ImportedCount != 1 || result.SkippedCount != 0 {
		t.Fatalf("unexpected import result: %+v", result)
	}

	var orgOnePrices int64
	if err := db.Model(&domain.InvestmentPrice{}).Where("organization_id = ?", orgOne.ID).Count(&orgOnePrices).Error; err != nil {
		t.Fatalf("count org one prices: %v", err)
	}
	var orgTwoPrices int64
	if err := db.Model(&domain.InvestmentPrice{}).Where("organization_id = ?", orgTwo.ID).Count(&orgTwoPrices).Error; err != nil {
		t.Fatalf("count org two prices: %v", err)
	}
	if orgOnePrices != 1 || orgTwoPrices != 0 {
		t.Fatalf("price counts orgOne=%d orgTwo=%d, want 1 and 0", orgOnePrices, orgTwoPrices)
	}
}

func TestJobServiceImportScheduledMarketDataFetchesProviderURL(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme One", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create org: %v", err)
	}
	previousTransport := marketDataHTTPTransport
	t.Cleanup(func() { marketDataHTTPTransport = previousTransport })
	marketDataHTTPTransport = roundTripFunc(func(r *http.Request) (*http.Response, error) {
		if r.Header.Get("Authorization") != "Bearer test-token" {
			return &http.Response{
				StatusCode: http.StatusUnauthorized,
				Body:       io.NopCloser(strings.NewReader("missing bearer token")),
				Header:     make(http.Header),
			}, nil
		}
		return &http.Response{
			StatusCode: http.StatusOK,
			Body:       io.NopCloser(strings.NewReader("symbol,price_date,price_minor,currency\nNIFTYBEES,2026-07-31,7200,INR\n")),
			Header:     make(http.Header),
		}, nil
	})

	result, err := NewJobService(db).ImportScheduledMarketData(ctx, MarketDataImportJobInput{
		URL:            "https://prices.example.test/feed.csv",
		BearerToken:    "test-token",
		TimeoutSeconds: 5,
		Format:         "csv",
		Source:         "provider_csv",
		OrganizationID: org.ID,
	})
	if err != nil {
		t.Fatalf("ImportScheduledMarketData() error = %v", err)
	}
	if result.OrganizationsProcessed != 1 || result.ImportedCount != 1 {
		t.Fatalf("unexpected import result: %+v", result)
	}
	var price domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ?", org.ID, "NIFTYBEES").First(&price).Error; err != nil {
		t.Fatalf("load provider price: %v", err)
	}
	if price.Source != "provider_csv" || price.PriceMinor != 7200 {
		t.Fatalf("unexpected provider price: %+v", price)
	}
}

func TestJobServiceImportScheduledMarketDataSupportsNSEEquityCSV(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme NSE", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create org: %v", err)
	}
	feedPath := filepath.Join(t.TempDir(), "nse.csv")
	feed := "SYMBOL,SERIES,DATE1,CLOSE_PRICE\n" +
		"NIFTYBEES,EQ,31-Jul-2026,72.35\n" +
		"NIFTYBEES,BE,31-Jul-2026,70.00\n"
	if err := os.WriteFile(feedPath, []byte(feed), 0o600); err != nil {
		t.Fatalf("write feed: %v", err)
	}

	result, err := NewJobService(db).ImportScheduledMarketData(ctx, MarketDataImportJobInput{
		Path:           feedPath,
		Format:         "nse_equity_csv",
		Source:         "nse_bhavcopy",
		OrganizationID: org.ID,
	})
	if err != nil {
		t.Fatalf("ImportScheduledMarketData() error = %v", err)
	}
	if result.OrganizationsProcessed != 1 || result.ImportedCount != 1 || result.SkippedCount != 0 {
		t.Fatalf("unexpected import result: %+v", result)
	}
	var price domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ?", org.ID, "NIFTYBEES").First(&price).Error; err != nil {
		t.Fatalf("load NSE price: %v", err)
	}
	if price.PriceMinor != 7235 || price.Source != "nse_bhavcopy" {
		t.Fatalf("unexpected NSE price: %+v", price)
	}
}

func TestJobServiceImportScheduledMarketDataSupportsYahooFinanceCSV(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme Yahoo", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create org: %v", err)
	}
	feedPath := filepath.Join(t.TempDir(), "yahoo.csv")
	feed := "Date,Open,High,Low,Close,Adj Close,Volume\n" +
		"2026-07-31,1400.00,1425.00,1395.00,1410.55,1410.55,123456\n"
	if err := os.WriteFile(feedPath, []byte(feed), 0o600); err != nil {
		t.Fatalf("write feed: %v", err)
	}

	result, err := NewJobService(db).ImportScheduledMarketData(ctx, MarketDataImportJobInput{
		Path:           feedPath,
		Format:         "yahoo_finance_csv",
		Symbol:         "RELIANCE",
		OrganizationID: org.ID,
	})
	if err != nil {
		t.Fatalf("ImportScheduledMarketData() error = %v", err)
	}
	if result.OrganizationsProcessed != 1 || result.ImportedCount != 1 || result.SkippedCount != 0 {
		t.Fatalf("unexpected import result: %+v", result)
	}
	var price domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ?", org.ID, "RELIANCE").First(&price).Error; err != nil {
		t.Fatalf("load Yahoo price: %v", err)
	}
	if price.PriceMinor != 141055 || price.Source != "yahoo_finance_csv" {
		t.Fatalf("unexpected Yahoo price: %+v", price)
	}
}

func TestJobServiceImportScheduledMarketDataSupportsBSEEquityCSV(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme BSE", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create org: %v", err)
	}
	feedPath := filepath.Join(t.TempDir(), "bse.csv")
	feed := "SC_CODE,SC_GROUP,TRADING_DATE,CLOSE\n" +
		"500325,A,31-Jul-2026,1410.55\n" +
		"500325,Q,31-Jul-2026,1399.00\n"
	if err := os.WriteFile(feedPath, []byte(feed), 0o600); err != nil {
		t.Fatalf("write feed: %v", err)
	}

	result, err := NewJobService(db).ImportScheduledMarketData(ctx, MarketDataImportJobInput{
		Path:           feedPath,
		Format:         "bse_equity_csv",
		Source:         "bse_bhavcopy",
		OrganizationID: org.ID,
	})
	if err != nil {
		t.Fatalf("ImportScheduledMarketData() error = %v", err)
	}
	if result.OrganizationsProcessed != 1 || result.ImportedCount != 1 || result.SkippedCount != 0 {
		t.Fatalf("unexpected import result: %+v", result)
	}
	var price domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ?", org.ID, "500325").First(&price).Error; err != nil {
		t.Fatalf("load BSE price: %v", err)
	}
	if price.PriceMinor != 141055 || price.Source != "bse_bhavcopy" {
		t.Fatalf("unexpected BSE price: %+v", price)
	}
}

func TestJobServiceImportScheduledMarketDataSupportsAlphaVantageCSV(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme Alpha", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create org: %v", err)
	}
	feedPath := filepath.Join(t.TempDir(), "alpha-vantage.csv")
	feed := "timestamp,open,high,low,close,volume\n" +
		"2026-07-31,500.00,520.00,495.00,510.25,987654\n"
	if err := os.WriteFile(feedPath, []byte(feed), 0o600); err != nil {
		t.Fatalf("write feed: %v", err)
	}

	result, err := NewJobService(db).ImportScheduledMarketData(ctx, MarketDataImportJobInput{
		Path:           feedPath,
		Format:         "alpha_vantage_csv",
		Symbol:         "MSFT",
		OrganizationID: org.ID,
	})
	if err != nil {
		t.Fatalf("ImportScheduledMarketData() error = %v", err)
	}
	if result.OrganizationsProcessed != 1 || result.ImportedCount != 1 || result.SkippedCount != 0 {
		t.Fatalf("unexpected import result: %+v", result)
	}
	var price domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ?", org.ID, "MSFT").First(&price).Error; err != nil {
		t.Fatalf("load Alpha Vantage price: %v", err)
	}
	if price.PriceMinor != 51025 || price.Source != "alpha_vantage_csv" {
		t.Fatalf("unexpected Alpha Vantage price: %+v", price)
	}
}

func TestJobServiceImportScheduledMarketDataSupportsBrokerHoldingsCSV(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Acme Broker", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "holdings.csv")
	if err := os.WriteFile(path, []byte("Trading Symbol,As of Date,LTP\nTCS,31-Jul-2026,\"₹3,450.75\"\n"), 0o600); err != nil {
		t.Fatalf("write broker CSV: %v", err)
	}

	result, err := NewJobService(db).ImportScheduledMarketData(ctx, MarketDataImportJobInput{
		OrganizationID: org.ID,
		Path:           path,
		Format:         "broker_holdings_csv",
	})
	if err != nil {
		t.Fatalf("ImportScheduledMarketData() error = %v", err)
	}
	if result.ImportedCount != 1 || result.SkippedCount != 0 {
		t.Fatalf("unexpected job result: %+v", result)
	}
	var price domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ?", org.ID, "TCS").First(&price).Error; err != nil {
		t.Fatalf("load broker price: %v", err)
	}
	if price.PriceMinor != 345075 || price.Source != "broker_holdings_csv" {
		t.Fatalf("unexpected broker price: %+v", price)
	}
}

func TestJobServiceImportScheduledMarketDataSupportsZerodhaHoldingsCSV(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Acme Zerodha", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "zerodha.csv")
	if err := os.WriteFile(path, []byte("Instrument,ISIN,Date,LTP,Qty.\nHDFCBANK,INE040A01034,2026-07-31,1575.20,4\n"), 0o600); err != nil {
		t.Fatalf("write Zerodha CSV: %v", err)
	}

	result, err := NewJobService(db).ImportScheduledMarketData(ctx, MarketDataImportJobInput{
		OrganizationID: org.ID,
		Path:           path,
		Format:         "zerodha_holdings_csv",
	})
	if err != nil {
		t.Fatalf("ImportScheduledMarketData() error = %v", err)
	}
	if result.ImportedCount != 1 || result.SkippedCount != 0 {
		t.Fatalf("unexpected job result: %+v", result)
	}
	var price domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ?", org.ID, "HDFCBANK").First(&price).Error; err != nil {
		t.Fatalf("load Zerodha price: %v", err)
	}
	if price.PriceMinor != 157520 || price.Source != "zerodha_holdings_csv" {
		t.Fatalf("unexpected Zerodha price: %+v", price)
	}
}

func TestJobServiceImportScheduledMarketDataSupportsGrowwHoldingsCSV(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Acme Groww", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "groww.csv")
	if err := os.WriteFile(path, []byte("Company Name,ISIN,Date,LTP,Quantity\nReliance Industries,INE002A01018,2026-07-31,1410.55,3\n"), 0o600); err != nil {
		t.Fatalf("write Groww CSV: %v", err)
	}

	result, err := NewJobService(db).ImportScheduledMarketData(ctx, MarketDataImportJobInput{
		OrganizationID: org.ID,
		Path:           path,
		Format:         "groww_holdings_csv",
	})
	if err != nil {
		t.Fatalf("ImportScheduledMarketData() error = %v", err)
	}
	if result.ImportedCount != 1 || result.SkippedCount != 0 {
		t.Fatalf("unexpected job result: %+v", result)
	}
	var price domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ?", org.ID, "INE002A01018").First(&price).Error; err != nil {
		t.Fatalf("load Groww price: %v", err)
	}
	if price.PriceMinor != 141055 || price.Source != "groww_holdings_csv" {
		t.Fatalf("unexpected Groww price: %+v", price)
	}
}

func TestJobServiceImportScheduledMarketDataSupportsUpstoxHoldingsCSV(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Acme Upstox", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "upstox.csv")
	if err := os.WriteFile(path, []byte("Symbol,ISIN,Date,Current Price,Quantity\nSBIN,INE062A01020,2026-07-31,615.25,12\n"), 0o600); err != nil {
		t.Fatalf("write Upstox CSV: %v", err)
	}

	result, err := NewJobService(db).ImportScheduledMarketData(ctx, MarketDataImportJobInput{
		OrganizationID: org.ID,
		Path:           path,
		Format:         "upstox_holdings_csv",
	})
	if err != nil {
		t.Fatalf("ImportScheduledMarketData() error = %v", err)
	}
	if result.ImportedCount != 1 || result.SkippedCount != 0 {
		t.Fatalf("unexpected job result: %+v", result)
	}
	var price domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ?", org.ID, "SBIN").First(&price).Error; err != nil {
		t.Fatalf("load Upstox price: %v", err)
	}
	if price.PriceMinor != 61525 || price.Source != "upstox_holdings_csv" {
		t.Fatalf("unexpected Upstox price: %+v", price)
	}
}

func TestJobServiceImportScheduledMarketDataSupportsAngelOneHoldingsCSV(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Acme Angel One", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "angelone.csv")
	if err := os.WriteFile(path, []byte("Scrip,ISIN,Date,LTP,Quantity\nICICIBANK,INE090A01021,2026-07-31,1245.30,5\n"), 0o600); err != nil {
		t.Fatalf("write Angel One CSV: %v", err)
	}

	result, err := NewJobService(db).ImportScheduledMarketData(ctx, MarketDataImportJobInput{
		OrganizationID: org.ID,
		Path:           path,
		Format:         "angelone_holdings_csv",
	})
	if err != nil {
		t.Fatalf("ImportScheduledMarketData() error = %v", err)
	}
	if result.ImportedCount != 1 || result.SkippedCount != 0 {
		t.Fatalf("unexpected job result: %+v", result)
	}
	var price domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ?", org.ID, "ICICIBANK").First(&price).Error; err != nil {
		t.Fatalf("load Angel One price: %v", err)
	}
	if price.PriceMinor != 124530 || price.Source != "angelone_holdings_csv" {
		t.Fatalf("unexpected Angel One price: %+v", price)
	}
}

func TestJobServiceImportScheduledMarketDataSupportsDhanHoldingsCSV(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Acme Dhan", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "dhan.csv")
	if err := os.WriteFile(path, []byte("Trading Symbol,ISIN,Date,LTP,Quantity\nAXISBANK,INE238A01034,2026-07-31,1188.40,8\n"), 0o600); err != nil {
		t.Fatalf("write Dhan CSV: %v", err)
	}

	result, err := NewJobService(db).ImportScheduledMarketData(ctx, MarketDataImportJobInput{
		OrganizationID: org.ID,
		Path:           path,
		Format:         "dhan_holdings_csv",
	})
	if err != nil {
		t.Fatalf("ImportScheduledMarketData() error = %v", err)
	}
	if result.ImportedCount != 1 || result.SkippedCount != 0 {
		t.Fatalf("unexpected job result: %+v", result)
	}
	var price domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ?", org.ID, "AXISBANK").First(&price).Error; err != nil {
		t.Fatalf("load Dhan price: %v", err)
	}
	if price.PriceMinor != 118840 || price.Source != "dhan_holdings_csv" {
		t.Fatalf("unexpected Dhan price: %+v", price)
	}
}

func TestJobServiceImportScheduledMarketDataSupportsICICIDirectHoldingsCSV(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Acme ICICI Direct", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "icicidirect.csv")
	if err := os.WriteFile(path, []byte("Symbol,ISIN,Date,Market Price,Quantity\nLT,INE018A01030,2026-07-31,3620.80,2\n"), 0o600); err != nil {
		t.Fatalf("write ICICI Direct CSV: %v", err)
	}

	result, err := NewJobService(db).ImportScheduledMarketData(ctx, MarketDataImportJobInput{
		OrganizationID: org.ID,
		Path:           path,
		Format:         "icicidirect_holdings_csv",
	})
	if err != nil {
		t.Fatalf("ImportScheduledMarketData() error = %v", err)
	}
	if result.ImportedCount != 1 || result.SkippedCount != 0 {
		t.Fatalf("unexpected job result: %+v", result)
	}
	var price domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ?", org.ID, "LT").First(&price).Error; err != nil {
		t.Fatalf("load ICICI Direct price: %v", err)
	}
	if price.PriceMinor != 362080 || price.Source != "icicidirect_holdings_csv" {
		t.Fatalf("unexpected ICICI Direct price: %+v", price)
	}
}

func TestJobServiceImportScheduledMarketDataSupportsHDFCSkyHoldingsCSV(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Acme HDFC Sky", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "hdfcsky.csv")
	if err := os.WriteFile(path, []byte("Symbol,ISIN,Date,LTP,Quantity\nMARUTI,INE585B01010,2026-07-31,12875.65,1\n"), 0o600); err != nil {
		t.Fatalf("write HDFC Sky CSV: %v", err)
	}

	result, err := NewJobService(db).ImportScheduledMarketData(ctx, MarketDataImportJobInput{
		OrganizationID: org.ID,
		Path:           path,
		Format:         "hdfcsky_holdings_csv",
	})
	if err != nil {
		t.Fatalf("ImportScheduledMarketData() error = %v", err)
	}
	if result.ImportedCount != 1 || result.SkippedCount != 0 {
		t.Fatalf("unexpected job result: %+v", result)
	}
	var price domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ?", org.ID, "MARUTI").First(&price).Error; err != nil {
		t.Fatalf("load HDFC Sky price: %v", err)
	}
	if price.PriceMinor != 1287565 || price.Source != "hdfcsky_holdings_csv" {
		t.Fatalf("unexpected HDFC Sky price: %+v", price)
	}
}

func TestJobServiceImportScheduledMarketDataSupportsKotakNeoHoldingsCSV(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Acme Kotak Neo", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "kotakneo.csv")
	if err := os.WriteFile(path, []byte("Trading Symbol,ISIN,Date,LTP,Quantity\nBAJFINANCE,INE296A01024,2026-07-31,9342.10,2\n"), 0o600); err != nil {
		t.Fatalf("write Kotak Neo CSV: %v", err)
	}

	result, err := NewJobService(db).ImportScheduledMarketData(ctx, MarketDataImportJobInput{
		OrganizationID: org.ID,
		Path:           path,
		Format:         "kotakneo_holdings_csv",
	})
	if err != nil {
		t.Fatalf("ImportScheduledMarketData() error = %v", err)
	}
	if result.ImportedCount != 1 || result.SkippedCount != 0 {
		t.Fatalf("unexpected job result: %+v", result)
	}
	var price domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ?", org.ID, "BAJFINANCE").First(&price).Error; err != nil {
		t.Fatalf("load Kotak Neo price: %v", err)
	}
	if price.PriceMinor != 934210 || price.Source != "kotakneo_holdings_csv" {
		t.Fatalf("unexpected Kotak Neo price: %+v", price)
	}
}

func TestJobServiceImportScheduledMarketDataSupportsPaytmMoneyHoldingsCSV(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Acme Paytm Money", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "paytmmoney.csv")
	if err := os.WriteFile(path, []byte("Symbol,ISIN,Date,LTP,Quantity\nTATAMOTORS,INE155A01022,2026-07-31,1098.45,5\n"), 0o600); err != nil {
		t.Fatalf("write Paytm Money CSV: %v", err)
	}

	result, err := NewJobService(db).ImportScheduledMarketData(ctx, MarketDataImportJobInput{
		OrganizationID: org.ID,
		Path:           path,
		Format:         "paytmmoney_holdings_csv",
	})
	if err != nil {
		t.Fatalf("ImportScheduledMarketData() error = %v", err)
	}
	if result.ImportedCount != 1 || result.SkippedCount != 0 {
		t.Fatalf("unexpected job result: %+v", result)
	}
	var price domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ?", org.ID, "TATAMOTORS").First(&price).Error; err != nil {
		t.Fatalf("load Paytm Money price: %v", err)
	}
	if price.PriceMinor != 109845 || price.Source != "paytmmoney_holdings_csv" {
		t.Fatalf("unexpected Paytm Money price: %+v", price)
	}
}

func TestJobServiceImportScheduledMarketDataSupportsMotilalOswalHoldingsCSV(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Acme Motilal Oswal", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "motilaloswal.csv")
	if err := os.WriteFile(path, []byte("Symbol,ISIN,Date,LTP,Quantity\nASIANPAINT,INE021A01026,2026-07-31,2987.60,3\n"), 0o600); err != nil {
		t.Fatalf("write Motilal Oswal CSV: %v", err)
	}

	result, err := NewJobService(db).ImportScheduledMarketData(ctx, MarketDataImportJobInput{
		OrganizationID: org.ID,
		Path:           path,
		Format:         "motilaloswal_holdings_csv",
	})
	if err != nil {
		t.Fatalf("ImportScheduledMarketData() error = %v", err)
	}
	if result.ImportedCount != 1 || result.SkippedCount != 0 {
		t.Fatalf("unexpected job result: %+v", result)
	}
	var price domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ?", org.ID, "ASIANPAINT").First(&price).Error; err != nil {
		t.Fatalf("load Motilal Oswal price: %v", err)
	}
	if price.PriceMinor != 298760 || price.Source != "motilaloswal_holdings_csv" {
		t.Fatalf("unexpected Motilal Oswal price: %+v", price)
	}
}

func TestJobServiceImportScheduledMarketDataSupportsSharekhanHoldingsCSV(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Acme Sharekhan", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "sharekhan.csv")
	if err := os.WriteFile(path, []byte("Symbol,ISIN,Date,LTP,Quantity\nHINDUNILVR,INE030A01027,2026-07-31,2567.35,4\n"), 0o600); err != nil {
		t.Fatalf("write Sharekhan CSV: %v", err)
	}

	result, err := NewJobService(db).ImportScheduledMarketData(ctx, MarketDataImportJobInput{
		OrganizationID: org.ID,
		Path:           path,
		Format:         "sharekhan_holdings_csv",
	})
	if err != nil {
		t.Fatalf("ImportScheduledMarketData() error = %v", err)
	}
	if result.ImportedCount != 1 || result.SkippedCount != 0 {
		t.Fatalf("unexpected job result: %+v", result)
	}
	var price domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ?", org.ID, "HINDUNILVR").First(&price).Error; err != nil {
		t.Fatalf("load Sharekhan price: %v", err)
	}
	if price.PriceMinor != 256735 || price.Source != "sharekhan_holdings_csv" {
		t.Fatalf("unexpected Sharekhan price: %+v", price)
	}
}

func TestJobServiceImportScheduledMarketDataSupportsFivePaisaHoldingsCSV(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Acme 5paisa", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "fivepaisa.csv")
	if err := os.WriteFile(path, []byte("Symbol,ISIN,Date,LTP,Quantity\nSBIN,INE062A01020,2026-07-31,845.70,10\n"), 0o600); err != nil {
		t.Fatalf("write 5paisa CSV: %v", err)
	}

	result, err := NewJobService(db).ImportScheduledMarketData(ctx, MarketDataImportJobInput{
		OrganizationID: org.ID,
		Path:           path,
		Format:         "fivepaisa_holdings_csv",
	})
	if err != nil {
		t.Fatalf("ImportScheduledMarketData() error = %v", err)
	}
	if result.ImportedCount != 1 || result.SkippedCount != 0 {
		t.Fatalf("unexpected job result: %+v", result)
	}
	var price domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ?", org.ID, "SBIN").First(&price).Error; err != nil {
		t.Fatalf("load 5paisa price: %v", err)
	}
	if price.PriceMinor != 84570 || price.Source != "fivepaisa_holdings_csv" {
		t.Fatalf("unexpected 5paisa price: %+v", price)
	}
}

func TestJobServiceImportScheduledMarketDataSupportsAxisDirectHoldingsCSV(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Acme Axis Direct", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "axisdirect.csv")
	if err := os.WriteFile(path, []byte("Symbol,ISIN,Date,LTP,Quantity\nTECHM,INE669C01036,2026-07-31,1543.25,6\n"), 0o600); err != nil {
		t.Fatalf("write Axis Direct CSV: %v", err)
	}

	result, err := NewJobService(db).ImportScheduledMarketData(ctx, MarketDataImportJobInput{
		OrganizationID: org.ID,
		Path:           path,
		Format:         "axisdirect_holdings_csv",
	})
	if err != nil {
		t.Fatalf("ImportScheduledMarketData() error = %v", err)
	}
	if result.ImportedCount != 1 || result.SkippedCount != 0 {
		t.Fatalf("unexpected job result: %+v", result)
	}
	var price domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ?", org.ID, "TECHM").First(&price).Error; err != nil {
		t.Fatalf("load Axis Direct price: %v", err)
	}
	if price.PriceMinor != 154325 || price.Source != "axisdirect_holdings_csv" {
		t.Fatalf("unexpected Axis Direct price: %+v", price)
	}
}

func TestJobServiceImportScheduledMarketDataSupportsSBISecuritiesHoldingsCSV(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Acme SBI Securities", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "sbisecurities.csv")
	if err := os.WriteFile(path, []byte("Symbol,ISIN,Date,LTP,Quantity\nINFY,INE009A01021,2026-07-31,1499.95,9\n"), 0o600); err != nil {
		t.Fatalf("write SBI Securities CSV: %v", err)
	}

	result, err := NewJobService(db).ImportScheduledMarketData(ctx, MarketDataImportJobInput{
		OrganizationID: org.ID,
		Path:           path,
		Format:         "sbisecurities_holdings_csv",
	})
	if err != nil {
		t.Fatalf("ImportScheduledMarketData() error = %v", err)
	}
	if result.ImportedCount != 1 || result.SkippedCount != 0 {
		t.Fatalf("unexpected job result: %+v", result)
	}
	var price domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ?", org.ID, "INFY").First(&price).Error; err != nil {
		t.Fatalf("load SBI Securities price: %v", err)
	}
	if price.PriceMinor != 149995 || price.Source != "sbisecurities_holdings_csv" {
		t.Fatalf("unexpected SBI Securities price: %+v", price)
	}
}

func TestJobServiceImportScheduledMarketDataSupportsNuvamaHoldingsCSV(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Acme Nuvama", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "nuvama.csv")
	if err := os.WriteFile(path, []byte("Symbol,ISIN,Date,LTP,Quantity\nWIPRO,INE075A01022,2026-07-31,512.40,11\n"), 0o600); err != nil {
		t.Fatalf("write Nuvama CSV: %v", err)
	}

	result, err := NewJobService(db).ImportScheduledMarketData(ctx, MarketDataImportJobInput{
		OrganizationID: org.ID,
		Path:           path,
		Format:         "nuvama_holdings_csv",
	})
	if err != nil {
		t.Fatalf("ImportScheduledMarketData() error = %v", err)
	}
	if result.ImportedCount != 1 || result.SkippedCount != 0 {
		t.Fatalf("unexpected job result: %+v", result)
	}
	var price domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ?", org.ID, "WIPRO").First(&price).Error; err != nil {
		t.Fatalf("load Nuvama price: %v", err)
	}
	if price.PriceMinor != 51240 || price.Source != "nuvama_holdings_csv" {
		t.Fatalf("unexpected Nuvama price: %+v", price)
	}
}

func TestJobServiceImportScheduledMarketDataSupportsGeojitHoldingsCSV(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Acme Geojit", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "geojit.csv")
	if err := os.WriteFile(path, []byte("Symbol,ISIN,Date,LTP,Quantity\nHCLTECH,INE860A01027,2026-07-31,1444.80,7\n"), 0o600); err != nil {
		t.Fatalf("write Geojit CSV: %v", err)
	}

	result, err := NewJobService(db).ImportScheduledMarketData(ctx, MarketDataImportJobInput{
		OrganizationID: org.ID,
		Path:           path,
		Format:         "geojit_holdings_csv",
	})
	if err != nil {
		t.Fatalf("ImportScheduledMarketData() error = %v", err)
	}
	if result.ImportedCount != 1 || result.SkippedCount != 0 {
		t.Fatalf("unexpected job result: %+v", result)
	}
	var price domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ?", org.ID, "HCLTECH").First(&price).Error; err != nil {
		t.Fatalf("load Geojit price: %v", err)
	}
	if price.PriceMinor != 144480 || price.Source != "geojit_holdings_csv" {
		t.Fatalf("unexpected Geojit price: %+v", price)
	}
}

type roundTripFunc func(*http.Request) (*http.Response, error)

func (fn roundTripFunc) RoundTrip(request *http.Request) (*http.Response, error) {
	return fn(request)
}

func createRecurringInvoiceJobFixture(t *testing.T, db *gorm.DB, ctx context.Context, orgName string, prefix string, startDate time.Time) domain.Organization {
	t.Helper()
	org := domain.Organization{Name: orgName, BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if _, err := NewSeedService(db).SeedIndiaDefaults(ctx, org.ID); err != nil {
		t.Fatalf("seed defaults: %v", err)
	}
	customer := domain.Customer{OrganizationID: org.ID, DisplayName: orgName + " Customer", IsActive: true}
	if err := db.Create(&customer).Error; err != nil {
		t.Fatalf("create customer: %v", err)
	}
	ar := mustAccountByCode(t, db, org.ID, "1100")
	income := mustAccountByCode(t, db, org.ID, "4000")

	if _, err := NewRecurringInvoiceService(db, NewTaxService(db)).Create(ctx, CreateRecurringInvoiceTemplateInput{
		OrganizationID:       org.ID,
		CustomerID:           customer.ID,
		Name:                 prefix + " template",
		InvoiceNumberPrefix:  prefix,
		StartDate:            startDate,
		Frequency:            domain.RecurrenceFrequencyMonthly,
		AccountsReceivableID: ar.ID,
		Lines: []CreateRecurringInvoiceLineInput{{
			Description:     "Retainer",
			QuantityMillis:  1000,
			UnitPriceMinor:  10000,
			IncomeAccountID: income.ID,
		}},
	}); err != nil {
		t.Fatalf("create recurring invoice template: %v", err)
	}
	return org
}
