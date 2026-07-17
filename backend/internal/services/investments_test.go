package services

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/domain"
)

func TestInvestmentServiceSellLotCalculatesRealizedGain(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	account := domain.Account{OrganizationID: org.ID, Code: "1500", Name: "Brokerage", Type: domain.AccountTypeAsset, Subtype: "Stock", Currency: "INR", IsActive: true}
	if err := db.Create(&account).Error; err != nil {
		t.Fatalf("create account: %v", err)
	}
	cashAccount := domain.Account{OrganizationID: org.ID, Code: "1010", Name: "Settlement Cash", Type: domain.AccountTypeAsset, Subtype: "Bank", Currency: "INR", IsActive: true}
	if err := db.Create(&cashAccount).Error; err != nil {
		t.Fatalf("create cash account: %v", err)
	}
	gainAccount := domain.Account{OrganizationID: org.ID, Code: "4100", Name: "Investment Gains", Type: domain.AccountTypeIncome, Currency: "INR", IsActive: true}
	if err := db.Create(&gainAccount).Error; err != nil {
		t.Fatalf("create gain account: %v", err)
	}

	service := NewInvestmentService(db)
	lot, err := service.CreateLot(ctx, CreateInvestmentLotInput{
		OrganizationID:  org.ID,
		AccountID:       account.ID,
		Symbol:          "NIFTYBEES",
		SecurityName:    "Nippon India ETF Nifty BeES",
		AcquisitionDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC),
		QuantityMillis:  100000,
		CostBasisMinor:  1000000,
	})
	if err != nil {
		t.Fatalf("CreateLot() error = %v", err)
	}

	disposition, err := service.SellLot(ctx, SellInvestmentLotInput{
		OrganizationID:    org.ID,
		LotID:             lot.ID,
		SaleDate:          time.Date(2026, 7, 12, 0, 0, 0, 0, time.UTC),
		QuantityMillis:    40000,
		ProceedsMinor:     520000,
		ProceedsAccountID: cashAccount.ID,
		GainLossAccountID: gainAccount.ID,
	})
	if err != nil {
		t.Fatalf("SellLot() error = %v", err)
	}
	if disposition.AllocatedCostBasisMinor != 400000 {
		t.Fatalf("allocated cost = %d, want 400000", disposition.AllocatedCostBasisMinor)
	}
	if disposition.RealizedGainLossMinor != 120000 {
		t.Fatalf("gain = %d, want 120000", disposition.RealizedGainLossMinor)
	}
	if disposition.JournalTransactionID == nil {
		t.Fatalf("expected investment sale to post a journal transaction")
	}
	var saleSplits []domain.LedgerSplit
	if err := db.Where("journal_transaction_id = ?", *disposition.JournalTransactionID).Find(&saleSplits).Error; err != nil {
		t.Fatalf("find sale splits: %v", err)
	}
	assertSplit(t, saleSplits, cashAccount.ID, 520000, 0)
	assertSplit(t, saleSplits, account.ID, 0, 400000)
	assertSplit(t, saleSplits, gainAccount.ID, 0, 120000)

	var updated domain.InvestmentLot
	if err := db.First(&updated, "id = ?", lot.ID).Error; err != nil {
		t.Fatalf("load updated lot: %v", err)
	}
	if updated.RemainingQuantityMillis != 60000 {
		t.Fatalf("remaining quantity = %d, want 60000", updated.RemainingQuantityMillis)
	}

	report, err := service.RealizedGains(ctx, org.ID, time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("RealizedGains() error = %v", err)
	}
	if report.TotalGainLoss != 120000 || len(report.Rows) != 1 {
		t.Fatalf("unexpected realized gains report: %+v", report)
	}

	dividend, err := service.CreateDividend(ctx, CreateInvestmentDividendInput{
		OrganizationID:  org.ID,
		AccountID:       account.ID,
		Symbol:          "NIFTYBEES",
		DividendDate:    time.Date(2026, 7, 20, 0, 0, 0, 0, time.UTC),
		AmountMinor:     25000,
		CashAccountID:   cashAccount.ID,
		IncomeAccountID: gainAccount.ID,
	})
	if err != nil {
		t.Fatalf("CreateDividend() error = %v", err)
	}
	if dividend.JournalTransactionID == nil {
		t.Fatalf("expected dividend to post a journal transaction")
	}
	var dividendSplits []domain.LedgerSplit
	if err := db.Where("journal_transaction_id = ?", *dividend.JournalTransactionID).Find(&dividendSplits).Error; err != nil {
		t.Fatalf("find dividend splits: %v", err)
	}
	assertSplit(t, dividendSplits, cashAccount.ID, 25000, 0)
	assertSplit(t, dividendSplits, gainAccount.ID, 0, 25000)
	dividendReport, err := service.DividendReport(ctx, org.ID, time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("DividendReport() error = %v", err)
	}
	if dividendReport.TotalAmountMinor != 25000 || len(dividendReport.Rows) != 1 {
		t.Fatalf("unexpected dividend report: %+v", dividendReport)
	}

	action, err := service.CreateCorporateAction(ctx, CreateInvestmentCorporateActionInput{
		OrganizationID:   org.ID,
		AccountID:        account.ID,
		Symbol:           "NIFTYBEES",
		ActionType:       domain.InvestmentCorporateActionSplit,
		ActionDate:       time.Date(2026, 7, 25, 0, 0, 0, 0, time.UTC),
		RatioNumerator:   2,
		RatioDenominator: 1,
		Notes:            "2-for-1 split",
	})
	if err != nil {
		t.Fatalf("CreateCorporateAction() error = %v", err)
	}
	if action.AffectedLots != 1 || action.QuantityDeltaMillis != 60000 || action.CostBasisDeltaMinor != 0 {
		t.Fatalf("unexpected corporate action summary: %+v", action)
	}
	if err := db.First(&updated, "id = ?", lot.ID).Error; err != nil {
		t.Fatalf("reload split lot: %v", err)
	}
	if updated.QuantityMillis != 200000 || updated.RemainingQuantityMillis != 120000 || updated.CostBasisMinor != 1000000 {
		t.Fatalf("unexpected split lot values: %+v", updated)
	}
	actions, err := service.ListCorporateActions(ctx, org.ID)
	if err != nil {
		t.Fatalf("ListCorporateActions() error = %v", err)
	}
	if len(actions) != 1 || actions[0].ID != action.ID {
		t.Fatalf("unexpected corporate actions list: %+v", actions)
	}
	corporateActionReport, err := service.CorporateActionReport(ctx, org.ID, time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("CorporateActionReport() error = %v", err)
	}
	if corporateActionReport.TotalActions != 1 || corporateActionReport.TotalAffectedLots != 1 || corporateActionReport.TotalQuantityDeltaMillis != 60000 {
		t.Fatalf("unexpected corporate action report: %+v", corporateActionReport)
	}
	corporateActionCSV, corporateActionFilename, err := service.CorporateActionReportCSV(ctx, org.ID, time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("CorporateActionReportCSV() error = %v", err)
	}
	if corporateActionFilename != "investment-corporate-actions-2026-07-01-to-2026-07-31.csv" {
		t.Fatalf("corporate action filename = %q", corporateActionFilename)
	}
	if csvText := string(corporateActionCSV); !strings.Contains(csvText, "NIFTYBEES,split,2,1,1,60000,0") || !strings.Contains(csvText, "Total,,,,,1,60000,0,,") {
		t.Fatalf("unexpected corporate action csv:\n%s", csvText)
	}

	price, err := service.CreatePrice(ctx, CreateInvestmentPriceInput{
		OrganizationID: org.ID,
		Symbol:         "NIFTYBEES",
		PriceDate:      time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC),
		PriceMinor:     7000,
		Currency:       "INR",
		Source:         "manual",
	})
	if err != nil {
		t.Fatalf("CreatePrice() error = %v", err)
	}
	if price.Symbol != "NIFTYBEES" {
		t.Fatalf("price symbol = %s, want NIFTYBEES", price.Symbol)
	}

	importResult, err := service.ImportPricesCSV(ctx, ImportInvestmentPricesInput{
		OrganizationID: org.ID,
		Source:         "amfi_nav",
		CSV: "symbol,price_date,price_minor,currency\n" +
			"NIFTYBEES,2026-07-31,7200,INR\n" +
			"LIQUIDFUND,2026-07-31,10500,INR\n",
	})
	if err != nil {
		t.Fatalf("ImportPricesCSV() error = %v", err)
	}
	if importResult.Imported != 2 || importResult.Skipped != 0 {
		t.Fatalf("unexpected import result: %+v", importResult)
	}
	var updatedPrice domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ? AND price_date = ?", org.ID, "NIFTYBEES", time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC)).First(&updatedPrice).Error; err != nil {
		t.Fatalf("load imported price: %v", err)
	}
	if updatedPrice.PriceMinor != 7200 || updatedPrice.Source != "amfi_nav" {
		t.Fatalf("unexpected imported price: %+v", updatedPrice)
	}

	amfiResult, err := service.ImportAMFINAV(ctx, ImportAMFINAVInput{
		OrganizationID: org.ID,
		SymbolMode:     "scheme_code",
		Text: "Scheme Code;ISIN Div Payout/ ISIN Growth;ISIN Div Reinvestment;Scheme Name;Net Asset Value;Date\n" +
			"INF204K01UN5;INF204K01UN5;;Nifty Index Fund Growth;123.4567;31-Jul-2026\n" +
			"INF204K01UO3;INF204K01UO3;;Liquid Fund Growth;N.A.;31-Jul-2026\n",
	})
	if err != nil {
		t.Fatalf("ImportAMFINAV() error = %v", err)
	}
	if amfiResult.Imported != 1 || amfiResult.Skipped != 0 {
		t.Fatalf("unexpected AMFI import result: %+v", amfiResult)
	}
	var amfiPrice domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ? AND price_date = ?", org.ID, "INF204K01UN5", time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC)).First(&amfiPrice).Error; err != nil {
		t.Fatalf("load AMFI price: %v", err)
	}
	if amfiPrice.PriceMinor != 12345 || amfiPrice.Source != "amfi_nav" {
		t.Fatalf("unexpected AMFI price: %+v", amfiPrice)
	}

	nseResult, err := service.ImportNSEEquityCSV(ctx, ImportInvestmentPricesInput{
		OrganizationID: org.ID,
		Source:         "nse_bhavcopy",
		CSV: "SYMBOL,SERIES,DATE1,CLOSE_PRICE\n" +
			"INFY,EQ,31-Jul-2026,1720.35\n" +
			"INFY,BE,31-Jul-2026,1700.00\n",
	})
	if err != nil {
		t.Fatalf("ImportNSEEquityCSV() error = %v", err)
	}
	if nseResult.Imported != 1 || nseResult.Skipped != 0 {
		t.Fatalf("unexpected NSE import result: %+v", nseResult)
	}
	var nsePrice domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ? AND price_date = ?", org.ID, "INFY", time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC)).First(&nsePrice).Error; err != nil {
		t.Fatalf("load NSE price: %v", err)
	}
	if nsePrice.PriceMinor != 172035 || nsePrice.Source != "nse_bhavcopy" {
		t.Fatalf("unexpected NSE price: %+v", nsePrice)
	}

	yahooResult, err := service.ImportYahooFinanceCSV(ctx, ImportInvestmentPricesInput{
		OrganizationID: org.ID,
		Symbol:         "RELIANCE",
		CSV: "Date,Open,High,Low,Close,Adj Close,Volume\n" +
			"2026-07-31,1400.00,1425.00,1395.00,1410.55,1410.55,123456\n",
	})
	if err != nil {
		t.Fatalf("ImportYahooFinanceCSV() error = %v", err)
	}
	if yahooResult.Imported != 1 || yahooResult.Skipped != 0 {
		t.Fatalf("unexpected Yahoo import result: %+v", yahooResult)
	}
	var yahooPrice domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ? AND price_date = ?", org.ID, "RELIANCE", time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC)).First(&yahooPrice).Error; err != nil {
		t.Fatalf("load Yahoo price: %v", err)
	}
	if yahooPrice.PriceMinor != 141055 || yahooPrice.Source != "yahoo_finance_csv" {
		t.Fatalf("unexpected Yahoo price: %+v", yahooPrice)
	}

	alphaResult, err := service.ImportAlphaVantageCSV(ctx, ImportInvestmentPricesInput{
		OrganizationID: org.ID,
		Symbol:         "MSFT",
		CSV: "timestamp,open,high,low,close,volume\n" +
			"2026-07-31,500.00,520.00,495.00,510.25,987654\n",
	})
	if err != nil {
		t.Fatalf("ImportAlphaVantageCSV() error = %v", err)
	}
	if alphaResult.Imported != 1 || alphaResult.Skipped != 0 {
		t.Fatalf("unexpected Alpha Vantage import result: %+v", alphaResult)
	}
	var alphaPrice domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ? AND price_date = ?", org.ID, "MSFT", time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC)).First(&alphaPrice).Error; err != nil {
		t.Fatalf("load Alpha Vantage price: %v", err)
	}
	if alphaPrice.PriceMinor != 51025 || alphaPrice.Source != "alpha_vantage_csv" {
		t.Fatalf("unexpected Alpha Vantage price: %+v", alphaPrice)
	}

	brokerResult, err := service.ImportBrokerHoldingsCSV(ctx, ImportInvestmentPricesInput{
		OrganizationID: org.ID,
		Source:         "zerodha_holdings_csv",
		CSV: "Symbol,ISIN,As of Date,Last Traded Price,Quantity\n" +
			"TCS,INE467B01029,31-Jul-2026,\"₹3,450.75\",10\n" +
			",INF204K01UN5,31-Jul-2026,123.45,20\n",
	})
	if err != nil {
		t.Fatalf("ImportBrokerHoldingsCSV() error = %v", err)
	}
	if brokerResult.Imported != 2 || brokerResult.Skipped != 0 {
		t.Fatalf("unexpected broker holdings import result: %+v", brokerResult)
	}
	var brokerPrice domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ? AND price_date = ?", org.ID, "TCS", time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC)).First(&brokerPrice).Error; err != nil {
		t.Fatalf("load broker price: %v", err)
	}
	if brokerPrice.PriceMinor != 345075 || brokerPrice.Source != "zerodha_holdings_csv" {
		t.Fatalf("unexpected broker price: %+v", brokerPrice)
	}
	var isinFallbackPrice domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ? AND price_date = ?", org.ID, "INF204K01UN5", time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC)).First(&isinFallbackPrice).Error; err != nil {
		t.Fatalf("load broker ISIN fallback price: %v", err)
	}
	if isinFallbackPrice.PriceMinor != 12345 || isinFallbackPrice.Source != "zerodha_holdings_csv" {
		t.Fatalf("unexpected broker ISIN fallback price: %+v", isinFallbackPrice)
	}

	zerodhaResult, err := service.ImportZerodhaHoldingsCSV(ctx, ImportInvestmentPricesInput{
		OrganizationID: org.ID,
		CSV: "Instrument,ISIN,Date,LTP,Qty.\n" +
			"HDFCBANK,INE040A01034,2026-07-31,1575.20,4\n",
	})
	if err != nil {
		t.Fatalf("ImportZerodhaHoldingsCSV() error = %v", err)
	}
	if zerodhaResult.Imported != 1 || zerodhaResult.Skipped != 0 {
		t.Fatalf("unexpected Zerodha holdings import result: %+v", zerodhaResult)
	}
	var zerodhaPrice domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ? AND price_date = ?", org.ID, "HDFCBANK", time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC)).First(&zerodhaPrice).Error; err != nil {
		t.Fatalf("load Zerodha price: %v", err)
	}
	if zerodhaPrice.PriceMinor != 157520 || zerodhaPrice.Source != "zerodha_holdings_csv" {
		t.Fatalf("unexpected Zerodha price: %+v", zerodhaPrice)
	}

	growwResult, err := service.ImportGrowwHoldingsCSV(ctx, ImportInvestmentPricesInput{
		OrganizationID: org.ID,
		CSV: "Company Name,ISIN,Date,LTP,Quantity\n" +
			"Reliance Industries,INE002A01018,2026-07-31,1410.55,3\n",
	})
	if err != nil {
		t.Fatalf("ImportGrowwHoldingsCSV() error = %v", err)
	}
	if growwResult.Imported != 1 || growwResult.Skipped != 0 {
		t.Fatalf("unexpected Groww holdings import result: %+v", growwResult)
	}
	var growwPrice domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ? AND price_date = ?", org.ID, "INE002A01018", time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC)).First(&growwPrice).Error; err != nil {
		t.Fatalf("load Groww price: %v", err)
	}
	if growwPrice.PriceMinor != 141055 || growwPrice.Source != "groww_holdings_csv" {
		t.Fatalf("unexpected Groww price: %+v", growwPrice)
	}

	upstoxResult, err := service.ImportUpstoxHoldingsCSV(ctx, ImportInvestmentPricesInput{
		OrganizationID: org.ID,
		CSV: "Symbol,ISIN,Date,Current Price,Quantity\n" +
			"SBIN,INE062A01020,2026-07-31,615.25,12\n",
	})
	if err != nil {
		t.Fatalf("ImportUpstoxHoldingsCSV() error = %v", err)
	}
	if upstoxResult.Imported != 1 || upstoxResult.Skipped != 0 {
		t.Fatalf("unexpected Upstox holdings import result: %+v", upstoxResult)
	}
	var upstoxPrice domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ? AND price_date = ?", org.ID, "SBIN", time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC)).First(&upstoxPrice).Error; err != nil {
		t.Fatalf("load Upstox price: %v", err)
	}
	if upstoxPrice.PriceMinor != 61525 || upstoxPrice.Source != "upstox_holdings_csv" {
		t.Fatalf("unexpected Upstox price: %+v", upstoxPrice)
	}

	angelOneResult, err := service.ImportAngelOneHoldingsCSV(ctx, ImportInvestmentPricesInput{
		OrganizationID: org.ID,
		CSV: "Scrip,ISIN,Date,LTP,Quantity\n" +
			"ICICIBANK,INE090A01021,2026-07-31,1245.30,5\n",
	})
	if err != nil {
		t.Fatalf("ImportAngelOneHoldingsCSV() error = %v", err)
	}
	if angelOneResult.Imported != 1 || angelOneResult.Skipped != 0 {
		t.Fatalf("unexpected Angel One holdings import result: %+v", angelOneResult)
	}
	var angelOnePrice domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ? AND price_date = ?", org.ID, "ICICIBANK", time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC)).First(&angelOnePrice).Error; err != nil {
		t.Fatalf("load Angel One price: %v", err)
	}
	if angelOnePrice.PriceMinor != 124530 || angelOnePrice.Source != "angelone_holdings_csv" {
		t.Fatalf("unexpected Angel One price: %+v", angelOnePrice)
	}

	dhanResult, err := service.ImportDhanHoldingsCSV(ctx, ImportInvestmentPricesInput{
		OrganizationID: org.ID,
		CSV: "Trading Symbol,ISIN,Date,LTP,Quantity\n" +
			"AXISBANK,INE238A01034,2026-07-31,1188.40,8\n",
	})
	if err != nil {
		t.Fatalf("ImportDhanHoldingsCSV() error = %v", err)
	}
	if dhanResult.Imported != 1 || dhanResult.Skipped != 0 {
		t.Fatalf("unexpected Dhan holdings import result: %+v", dhanResult)
	}
	var dhanPrice domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ? AND price_date = ?", org.ID, "AXISBANK", time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC)).First(&dhanPrice).Error; err != nil {
		t.Fatalf("load Dhan price: %v", err)
	}
	if dhanPrice.PriceMinor != 118840 || dhanPrice.Source != "dhan_holdings_csv" {
		t.Fatalf("unexpected Dhan price: %+v", dhanPrice)
	}

	iciciDirectResult, err := service.ImportICICIDirectHoldingsCSV(ctx, ImportInvestmentPricesInput{
		OrganizationID: org.ID,
		CSV: "Symbol,ISIN,Date,Market Price,Quantity\n" +
			"LT,INE018A01030,2026-07-31,3620.80,2\n",
	})
	if err != nil {
		t.Fatalf("ImportICICIDirectHoldingsCSV() error = %v", err)
	}
	if iciciDirectResult.Imported != 1 || iciciDirectResult.Skipped != 0 {
		t.Fatalf("unexpected ICICI Direct holdings import result: %+v", iciciDirectResult)
	}
	var iciciDirectPrice domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ? AND price_date = ?", org.ID, "LT", time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC)).First(&iciciDirectPrice).Error; err != nil {
		t.Fatalf("load ICICI Direct price: %v", err)
	}
	if iciciDirectPrice.PriceMinor != 362080 || iciciDirectPrice.Source != "icicidirect_holdings_csv" {
		t.Fatalf("unexpected ICICI Direct price: %+v", iciciDirectPrice)
	}

	hdfcSkyResult, err := service.ImportHDFCSkyHoldingsCSV(ctx, ImportInvestmentPricesInput{
		OrganizationID: org.ID,
		CSV: "Symbol,ISIN,Date,LTP,Quantity\n" +
			"MARUTI,INE585B01010,2026-07-31,12875.65,1\n",
	})
	if err != nil {
		t.Fatalf("ImportHDFCSkyHoldingsCSV() error = %v", err)
	}
	if hdfcSkyResult.Imported != 1 || hdfcSkyResult.Skipped != 0 {
		t.Fatalf("unexpected HDFC Sky holdings import result: %+v", hdfcSkyResult)
	}
	var hdfcSkyPrice domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ? AND price_date = ?", org.ID, "MARUTI", time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC)).First(&hdfcSkyPrice).Error; err != nil {
		t.Fatalf("load HDFC Sky price: %v", err)
	}
	if hdfcSkyPrice.PriceMinor != 1287565 || hdfcSkyPrice.Source != "hdfcsky_holdings_csv" {
		t.Fatalf("unexpected HDFC Sky price: %+v", hdfcSkyPrice)
	}

	kotakNeoResult, err := service.ImportKotakNeoHoldingsCSV(ctx, ImportInvestmentPricesInput{
		OrganizationID: org.ID,
		CSV: "Trading Symbol,ISIN,Date,LTP,Quantity\n" +
			"BAJFINANCE,INE296A01024,2026-07-31,9342.10,2\n",
	})
	if err != nil {
		t.Fatalf("ImportKotakNeoHoldingsCSV() error = %v", err)
	}
	if kotakNeoResult.Imported != 1 || kotakNeoResult.Skipped != 0 {
		t.Fatalf("unexpected Kotak Neo holdings import result: %+v", kotakNeoResult)
	}
	var kotakNeoPrice domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ? AND price_date = ?", org.ID, "BAJFINANCE", time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC)).First(&kotakNeoPrice).Error; err != nil {
		t.Fatalf("load Kotak Neo price: %v", err)
	}
	if kotakNeoPrice.PriceMinor != 934210 || kotakNeoPrice.Source != "kotakneo_holdings_csv" {
		t.Fatalf("unexpected Kotak Neo price: %+v", kotakNeoPrice)
	}

	bseResult, err := service.ImportBSEEquityCSV(ctx, ImportInvestmentPricesInput{
		OrganizationID: org.ID,
		Source:         "bse_bhavcopy",
		CSV: "SC_CODE,SC_GROUP,TRADING_DATE,CLOSE\n" +
			"500325,A,31-Jul-2026,1410.55\n" +
			"500325,Q,31-Jul-2026,1399.00\n",
	})
	if err != nil {
		t.Fatalf("ImportBSEEquityCSV() error = %v", err)
	}
	if bseResult.Imported != 1 || bseResult.Skipped != 0 {
		t.Fatalf("unexpected BSE import result: %+v", bseResult)
	}
	var bsePrice domain.InvestmentPrice
	if err := db.Where("organization_id = ? AND symbol = ? AND price_date = ?", org.ID, "500325", time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC)).First(&bsePrice).Error; err != nil {
		t.Fatalf("load BSE price: %v", err)
	}
	if bsePrice.PriceMinor != 141055 || bsePrice.Source != "bse_bhavcopy" {
		t.Fatalf("unexpected BSE price: %+v", bsePrice)
	}

	taxLots, err := service.TaxLotReport(ctx, org.ID, time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("TaxLotReport() error = %v", err)
	}
	if len(taxLots.Rows) != 1 {
		t.Fatalf("tax lot rows = %d, want 1", len(taxLots.Rows))
	}
	taxLot := taxLots.Rows[0]
	if taxLot.QuantityMillis != 200000 || taxLot.RemainingQuantityMillis != 120000 || taxLot.DisposedQuantityMillis != 80000 {
		t.Fatalf("unexpected tax lot quantities: %+v", taxLot)
	}
	if taxLot.RemainingCostBasisMinor != 600000 || taxLot.ProceedsMinor != 520000 || taxLot.RealizedGainLossMinor != 120000 {
		t.Fatalf("unexpected tax lot money values: %+v", taxLot)
	}
	if taxLots.TotalRemainingCostMinor != 600000 || taxLots.TotalRealizedMinor != 120000 {
		t.Fatalf("unexpected tax lot totals: %+v", taxLots)
	}

	valuation, err := service.Valuation(ctx, org.ID, time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("Valuation() error = %v", err)
	}
	if len(valuation.Rows) != 1 {
		t.Fatalf("valuation rows = %d, want 1", len(valuation.Rows))
	}
	if valuation.TotalCostBasisMinor != 600000 || valuation.TotalMarketValueMinor != 864000 || valuation.TotalUnrealizedMinor != 264000 {
		t.Fatalf("unexpected valuation totals: %+v", valuation)
	}
}

func TestInvestmentServiceSellLotRejectsOversell(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	account := domain.Account{OrganizationID: org.ID, Code: "1500", Name: "Brokerage", Type: domain.AccountTypeAsset, Subtype: "Stock", Currency: "INR", IsActive: true}
	if err := db.Create(&account).Error; err != nil {
		t.Fatalf("create account: %v", err)
	}

	service := NewInvestmentService(db)
	lot, err := service.CreateLot(ctx, CreateInvestmentLotInput{
		OrganizationID:  org.ID,
		AccountID:       account.ID,
		Symbol:          "NIFTYBEES",
		AcquisitionDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC),
		QuantityMillis:  1000,
		CostBasisMinor:  10000,
	})
	if err != nil {
		t.Fatalf("CreateLot() error = %v", err)
	}

	_, err = service.SellLot(ctx, SellInvestmentLotInput{
		OrganizationID: org.ID,
		LotID:          lot.ID,
		SaleDate:       time.Date(2026, 7, 12, 0, 0, 0, 0, time.UTC),
		QuantityMillis: 2000,
		ProceedsMinor:  20000,
	})
	if !errors.Is(err, ErrInvestmentLotInsufficientUnits) {
		t.Fatalf("SellLot() error = %v, want %v", err, ErrInvestmentLotInsufficientUnits)
	}
}

func TestInvestmentServiceTaxAdjustmentReportFlagsReplacementBuys(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	account := domain.Account{OrganizationID: org.ID, Code: "1500", Name: "Brokerage", Type: domain.AccountTypeAsset, Subtype: "Stock", Currency: "INR", IsActive: true}
	if err := db.Create(&account).Error; err != nil {
		t.Fatalf("create account: %v", err)
	}

	service := NewInvestmentService(db)
	soldLot, err := service.CreateLot(ctx, CreateInvestmentLotInput{
		OrganizationID:  org.ID,
		AccountID:       account.ID,
		Symbol:          "LOSSCO",
		AcquisitionDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC),
		QuantityMillis:  100000,
		CostBasisMinor:  1000000,
	})
	if err != nil {
		t.Fatalf("CreateLot() sold lot error = %v", err)
	}
	disposition, err := service.SellLot(ctx, SellInvestmentLotInput{
		OrganizationID: org.ID,
		LotID:          soldLot.ID,
		SaleDate:       time.Date(2026, 7, 10, 0, 0, 0, 0, time.UTC),
		QuantityMillis: 50000,
		ProceedsMinor:  300000,
	})
	if err != nil {
		t.Fatalf("SellLot() error = %v", err)
	}
	if disposition.RealizedGainLossMinor != -200000 {
		t.Fatalf("loss = %d, want -200000", disposition.RealizedGainLossMinor)
	}
	replacementLot, err := service.CreateLot(ctx, CreateInvestmentLotInput{
		OrganizationID:  org.ID,
		AccountID:       account.ID,
		Symbol:          "LOSSCO",
		AcquisitionDate: time.Date(2026, 7, 20, 0, 0, 0, 0, time.UTC),
		QuantityMillis:  25000,
		CostBasisMinor:  160000,
	})
	if err != nil {
		t.Fatalf("CreateLot() replacement error = %v", err)
	}

	report, err := service.TaxAdjustmentReport(ctx, org.ID, time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC), time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC), 30)
	if err != nil {
		t.Fatalf("TaxAdjustmentReport() error = %v", err)
	}
	if report.Rule != "loss_repurchase_window" || report.WindowDays != 30 || len(report.Rows) != 1 {
		t.Fatalf("unexpected tax adjustment report: %+v", report)
	}
	row := report.Rows[0]
	if row.DeferredLossMinor != 100000 || row.ReplacementQuantityMillis != 25000 || report.TotalDeferredLossMinor != 100000 {
		t.Fatalf("unexpected deferred loss row: %+v report=%+v", row, report)
	}
	if len(row.ReplacementLotIDs) != 1 || row.ReplacementLotIDs[0] != replacementLot.ID {
		t.Fatalf("replacement lot IDs = %+v, want %s", row.ReplacementLotIDs, replacementLot.ID)
	}
}

func TestInvestmentServiceSellAverageCostConsumesPooledLots(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	investmentAccount := domain.Account{OrganizationID: org.ID, Code: "1500", Name: "Mutual Funds", Type: domain.AccountTypeAsset, Subtype: "Mutual Fund", Currency: "INR", IsActive: true}
	if err := db.Create(&investmentAccount).Error; err != nil {
		t.Fatalf("create investment account: %v", err)
	}
	cashAccount := domain.Account{OrganizationID: org.ID, Code: "1010", Name: "Settlement Cash", Type: domain.AccountTypeAsset, Subtype: "Bank", Currency: "INR", IsActive: true}
	if err := db.Create(&cashAccount).Error; err != nil {
		t.Fatalf("create cash account: %v", err)
	}
	gainAccount := domain.Account{OrganizationID: org.ID, Code: "4100", Name: "Investment Gains", Type: domain.AccountTypeIncome, Currency: "INR", IsActive: true}
	if err := db.Create(&gainAccount).Error; err != nil {
		t.Fatalf("create gain account: %v", err)
	}

	service := NewInvestmentService(db)
	firstLot, err := service.CreateLot(ctx, CreateInvestmentLotInput{
		OrganizationID:  org.ID,
		AccountID:       investmentAccount.ID,
		Symbol:          "LIQUIDFUND",
		AcquisitionDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC),
		QuantityMillis:  100000,
		CostBasisMinor:  1000000,
		CostMethod:      domain.InvestmentCostMethodAverageCost,
	})
	if err != nil {
		t.Fatalf("CreateLot(first) error = %v", err)
	}
	secondLot, err := service.CreateLot(ctx, CreateInvestmentLotInput{
		OrganizationID:  org.ID,
		AccountID:       investmentAccount.ID,
		Symbol:          "LIQUIDFUND",
		AcquisitionDate: time.Date(2026, 5, 1, 0, 0, 0, 0, time.UTC),
		QuantityMillis:  100000,
		CostBasisMinor:  2000000,
		CostMethod:      domain.InvestmentCostMethodAverageCost,
	})
	if err != nil {
		t.Fatalf("CreateLot(second) error = %v", err)
	}

	result, err := service.SellAverageCost(ctx, SellAverageCostInput{
		OrganizationID:    org.ID,
		AccountID:         investmentAccount.ID,
		Symbol:            "LIQUIDFUND",
		Currency:          "INR",
		SaleDate:          time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC),
		QuantityMillis:    150000,
		ProceedsMinor:     2400000,
		ProceedsAccountID: cashAccount.ID,
		GainLossAccountID: gainAccount.ID,
	})
	if err != nil {
		t.Fatalf("SellAverageCost() error = %v", err)
	}
	if result.AllocatedCostBasisMinor != 2250000 || result.RealizedGainLossMinor != 150000 {
		t.Fatalf("unexpected average-cost result: %+v", result)
	}
	if len(result.Dispositions) != 2 {
		t.Fatalf("dispositions = %d, want 2", len(result.Dispositions))
	}
	if result.JournalTransactionID == nil {
		t.Fatalf("journal transaction id is nil")
	}

	var updatedFirst domain.InvestmentLot
	if err := db.First(&updatedFirst, "id = ?", firstLot.ID).Error; err != nil {
		t.Fatalf("load first lot: %v", err)
	}
	if updatedFirst.RemainingQuantityMillis != 0 {
		t.Fatalf("first remaining = %d, want 0", updatedFirst.RemainingQuantityMillis)
	}
	var updatedSecond domain.InvestmentLot
	if err := db.First(&updatedSecond, "id = ?", secondLot.ID).Error; err != nil {
		t.Fatalf("load second lot: %v", err)
	}
	if updatedSecond.RemainingQuantityMillis != 50000 {
		t.Fatalf("second remaining = %d, want 50000", updatedSecond.RemainingQuantityMillis)
	}

	var splits []domain.LedgerSplit
	if err := db.Where("journal_transaction_id = ?", *result.JournalTransactionID).Find(&splits).Error; err != nil {
		t.Fatalf("find sale splits: %v", err)
	}
	assertSplit(t, splits, cashAccount.ID, 2400000, 0)
	assertSplit(t, splits, investmentAccount.ID, 0, 2250000)
	assertSplit(t, splits, gainAccount.ID, 0, 150000)
}
