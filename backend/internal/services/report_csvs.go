package services

import (
	"bytes"
	"context"
	"encoding/csv"
	"strconv"
	"time"
)

func (s ReportService) TrialBalanceCSV(ctx context.Context, organizationID string, asOf time.Time) ([]byte, string, error) {
	report, err := s.TrialBalance(ctx, organizationID, asOf)
	if err != nil {
		return nil, "", err
	}
	rows := [][]string{{"Code", "Account", "Type", "Debit minor", "Credit minor", "Balance minor"}}
	for _, row := range report.Rows {
		rows = append(rows, []string{row.AccountCode, row.AccountName, string(row.AccountType), formatCSVInt(row.DebitMinor), formatCSVInt(row.CreditMinor), formatCSVInt(row.BalanceMinor)})
	}
	rows = append(rows, []string{"Total", "", "", formatCSVInt(report.TotalDebitMinor), formatCSVInt(report.TotalCreditMinor), ""})
	payload, _, err := renderReportCSV(rows)
	return payload, "trial-balance-" + report.AsOfDate.Format("2006-01-02") + ".csv", err
}

func (s ReportService) ProfitAndLossCSV(ctx context.Context, organizationID string, from time.Time, to time.Time) ([]byte, string, error) {
	report, err := s.ProfitAndLoss(ctx, organizationID, from, to)
	if err != nil {
		return nil, "", err
	}
	rows := [][]string{{"Section", "Code", "Account", "Amount minor"}}
	for _, row := range report.IncomeRows {
		rows = append(rows, []string{"Income", row.AccountCode, row.AccountName, formatCSVInt(row.BalanceMinor)})
	}
	for _, row := range report.ExpenseRows {
		rows = append(rows, []string{"Expense", row.AccountCode, row.AccountName, formatCSVInt(row.BalanceMinor)})
	}
	rows = append(rows,
		[]string{"Total income", "", "", formatCSVInt(report.TotalIncomeMinor)},
		[]string{"Total expense", "", "", formatCSVInt(report.TotalExpenseMinor)},
		[]string{"Net income", "", "", formatCSVInt(report.NetIncomeMinor)},
	)
	payload, _, err := renderReportCSV(rows)
	return payload, "profit-and-loss-" + report.FromDate.Format("2006-01-02") + "-to-" + report.ToDate.Format("2006-01-02") + ".csv", err
}

func (s ReportService) BalanceSheetCSV(ctx context.Context, organizationID string, asOf time.Time) ([]byte, string, error) {
	report, err := s.BalanceSheet(ctx, organizationID, asOf)
	if err != nil {
		return nil, "", err
	}
	rows := [][]string{{"Section", "Code", "Account", "Balance minor"}}
	for _, row := range report.AssetRows {
		rows = append(rows, []string{"Assets", row.AccountCode, row.AccountName, formatCSVInt(row.BalanceMinor)})
	}
	for _, row := range report.LiabilityRows {
		rows = append(rows, []string{"Liabilities", row.AccountCode, row.AccountName, formatCSVInt(row.BalanceMinor)})
	}
	for _, row := range report.EquityRows {
		rows = append(rows, []string{"Equity", row.AccountCode, row.AccountName, formatCSVInt(row.BalanceMinor)})
	}
	rows = append(rows,
		[]string{"Total assets", "", "", formatCSVInt(report.TotalAssetsMinor)},
		[]string{"Total liabilities", "", "", formatCSVInt(report.TotalLiabilitiesMinor)},
		[]string{"Total equity", "", "", formatCSVInt(report.TotalEquityMinor)},
	)
	payload, _, err := renderReportCSV(rows)
	return payload, "balance-sheet-" + report.AsOfDate.Format("2006-01-02") + ".csv", err
}

func (s ReportService) CashFlowCSV(ctx context.Context, organizationID string, from time.Time, to time.Time) ([]byte, string, error) {
	report, err := s.CashFlow(ctx, organizationID, from, to)
	if err != nil {
		return nil, "", err
	}
	rows := [][]string{{"Code", "Cash account", "Source", "Inflow minor", "Outflow minor", "Net cash flow minor"}}
	for _, row := range report.Rows {
		rows = append(rows, []string{row.AccountCode, row.AccountName, string(row.SourceModule), formatCSVInt(row.InflowMinor), formatCSVInt(row.OutflowMinor), formatCSVInt(row.NetCashFlowMinor)})
	}
	rows = append(rows,
		[]string{"Opening cash", "", "", "", "", formatCSVInt(report.OpeningCashMinor)},
		[]string{"Total inflows", "", "", formatCSVInt(report.TotalInflowsMinor), "", ""},
		[]string{"Total outflows", "", "", "", formatCSVInt(report.TotalOutflowsMinor), ""},
		[]string{"Net cash flow", "", "", "", "", formatCSVInt(report.NetCashFlowMinor)},
		[]string{"Closing cash", "", "", "", "", formatCSVInt(report.ClosingCashMinor)},
	)
	payload, _, err := renderReportCSV(rows)
	return payload, "cash-flow-" + report.FromDate.Format("2006-01-02") + "-to-" + report.ToDate.Format("2006-01-02") + ".csv", err
}

func (s ReportService) ARAgingCSV(ctx context.Context, organizationID string, asOf time.Time) ([]byte, string, error) {
	report, err := s.ARAging(ctx, organizationID, asOf)
	if err != nil {
		return nil, "", err
	}
	rows := [][]string{{"Customer", "Invoice", "Due date", "Days overdue", "Current minor", "1-30 minor", "31-60 minor", "61-90 minor", "90+ minor", "Outstanding minor"}}
	for _, row := range report.Rows {
		rows = append(rows, []string{row.CustomerName, row.InvoiceNumber, formatReportDate(row.DueDate), strconv.Itoa(row.DaysOverdue), formatCSVInt(row.CurrentMinor), formatCSVInt(row.OneToThirtyMinor), formatCSVInt(row.ThirtyOneToSixtyMinor), formatCSVInt(row.SixtyOneToNinetyMinor), formatCSVInt(row.OverNinetyMinor), formatCSVInt(row.OutstandingMinor)})
	}
	rows = append(rows, agingCSVTotalRow(report.TotalCurrentMinor, report.TotalOneToThirtyMinor, report.TotalThirtyOneToSixtyMinor, report.TotalSixtyOneToNinetyMinor, report.TotalOverNinetyMinor, report.TotalOutstandingMinor))
	payload, _, err := renderReportCSV(rows)
	return payload, "ar-aging-" + report.AsOfDate.Format("2006-01-02") + ".csv", err
}

func (s ReportService) APAgingCSV(ctx context.Context, organizationID string, asOf time.Time) ([]byte, string, error) {
	report, err := s.APAging(ctx, organizationID, asOf)
	if err != nil {
		return nil, "", err
	}
	rows := [][]string{{"Vendor", "Bill", "Due date", "Days overdue", "Current minor", "1-30 minor", "31-60 minor", "61-90 minor", "90+ minor", "Outstanding minor"}}
	for _, row := range report.Rows {
		rows = append(rows, []string{row.VendorName, row.BillNumber, formatReportDate(row.DueDate), strconv.Itoa(row.DaysOverdue), formatCSVInt(row.CurrentMinor), formatCSVInt(row.OneToThirtyMinor), formatCSVInt(row.ThirtyOneToSixtyMinor), formatCSVInt(row.SixtyOneToNinetyMinor), formatCSVInt(row.OverNinetyMinor), formatCSVInt(row.OutstandingMinor)})
	}
	rows = append(rows, agingCSVTotalRow(report.TotalCurrentMinor, report.TotalOneToThirtyMinor, report.TotalThirtyOneToSixtyMinor, report.TotalSixtyOneToNinetyMinor, report.TotalOverNinetyMinor, report.TotalOutstandingMinor))
	payload, _, err := renderReportCSV(rows)
	return payload, "ap-aging-" + report.AsOfDate.Format("2006-01-02") + ".csv", err
}

func (s ReportService) TaxLiabilityCSV(ctx context.Context, organizationID string, from time.Time, to time.Time) ([]byte, string, error) {
	report, err := s.TaxLiability(ctx, organizationID, from, to)
	if err != nil {
		return nil, "", err
	}
	rows := taxReportCSVRows(report.Rows)
	rows = append(rows, []string{"Total", formatCSVInt(report.OutputTaxMinor), formatCSVInt(report.InputTaxMinor), formatCSVInt(report.NetPayableMinor)})
	payload, _, err := renderReportCSV(rows)
	return payload, "tax-liability-" + report.FromDate.Format("2006-01-02") + "-to-" + report.ToDate.Format("2006-01-02") + ".csv", err
}

func (s ReportService) TaxSummaryCSV(ctx context.Context, organizationID string, from time.Time, to time.Time) ([]byte, string, error) {
	report, err := s.TaxSummary(ctx, organizationID, from, to)
	if err != nil {
		return nil, "", err
	}
	payload, _, err := renderReportCSV(taxReportCSVRows(report.Rows))
	return payload, "tax-summary-" + report.FromDate.Format("2006-01-02") + "-to-" + report.ToDate.Format("2006-01-02") + ".csv", err
}

func renderReportCSV(rows [][]string) ([]byte, string, error) {
	var buffer bytes.Buffer
	writer := csv.NewWriter(&buffer)
	if err := writer.WriteAll(rows); err != nil {
		return nil, "", err
	}
	return buffer.Bytes(), "", writer.Error()
}

func agingCSVTotalRow(currentMinor int64, oneToThirtyMinor int64, thirtyOneToSixtyMinor int64, sixtyOneToNinetyMinor int64, overNinetyMinor int64, outstandingMinor int64) []string {
	return []string{"Total", "", "", "", formatCSVInt(currentMinor), formatCSVInt(oneToThirtyMinor), formatCSVInt(thirtyOneToSixtyMinor), formatCSVInt(sixtyOneToNinetyMinor), formatCSVInt(overNinetyMinor), formatCSVInt(outstandingMinor)}
}

func taxReportCSVRows(rows []TaxReportRow) [][]string {
	csvRows := [][]string{{"Tax", "Output tax minor", "Input tax minor", "Net payable minor"}}
	for _, row := range rows {
		csvRows = append(csvRows, []string{row.Name, formatCSVInt(row.OutputTaxMinor), formatCSVInt(row.InputTaxMinor), formatCSVInt(row.NetPayableMinor)})
	}
	return csvRows
}

func formatCSVInt(value int64) string {
	return strconv.FormatInt(value, 10)
}
