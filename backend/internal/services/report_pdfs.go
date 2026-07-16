package services

import (
	"bytes"
	"context"
	"fmt"
	"time"
)

func (s ReportService) TrialBalancePDF(ctx context.Context, organizationID string, asOf time.Time) ([]byte, string, error) {
	report, err := s.TrialBalance(ctx, organizationID, asOf)
	if err != nil {
		return nil, "", err
	}
	lines := []string{
		"Trial Balance",
		"As of " + formatPDFDate(report.AsOfDate),
		fmt.Sprintf("Total debit: %s | Total credit: %s | Balanced: %t", formatPDFMinor(report.TotalDebitMinor), formatPDFMinor(report.TotalCreditMinor), report.Balanced),
		"",
		"Code | Account | Type | Debit | Credit | Balance",
	}
	for _, row := range report.Rows {
		lines = append(lines, fmt.Sprintf("%s | %s | %s | %s | %s | %s", row.AccountCode, row.AccountName, row.AccountType, formatPDFMinor(row.DebitMinor), formatPDFMinor(row.CreditMinor), formatPDFMinor(row.BalanceMinor)))
	}
	return renderReportPDF(lines), "trial-balance-" + report.AsOfDate.Format("2006-01-02") + ".pdf", nil
}

func (s ReportService) ProfitAndLossPDF(ctx context.Context, organizationID string, from time.Time, to time.Time) ([]byte, string, error) {
	report, err := s.ProfitAndLoss(ctx, organizationID, from, to)
	if err != nil {
		return nil, "", err
	}
	lines := []string{
		"Profit and Loss",
		formatPDFDate(report.FromDate) + " to " + formatPDFDate(report.ToDate),
		fmt.Sprintf("Income: %s | Expenses: %s | Net income: %s", formatPDFMinor(report.TotalIncomeMinor), formatPDFMinor(report.TotalExpenseMinor), formatPDFMinor(report.NetIncomeMinor)),
		"",
		"Income",
		"Code | Account | Amount",
	}
	for _, row := range report.IncomeRows {
		lines = append(lines, fmt.Sprintf("%s | %s | %s", row.AccountCode, row.AccountName, formatPDFMinor(row.BalanceMinor)))
	}
	lines = append(lines, "", "Expenses", "Code | Account | Amount")
	for _, row := range report.ExpenseRows {
		lines = append(lines, fmt.Sprintf("%s | %s | %s", row.AccountCode, row.AccountName, formatPDFMinor(row.BalanceMinor)))
	}
	return renderReportPDF(lines), "profit-and-loss-" + report.FromDate.Format("2006-01-02") + "-to-" + report.ToDate.Format("2006-01-02") + ".pdf", nil
}

func (s ReportService) BalanceSheetPDF(ctx context.Context, organizationID string, asOf time.Time) ([]byte, string, error) {
	report, err := s.BalanceSheet(ctx, organizationID, asOf)
	if err != nil {
		return nil, "", err
	}
	lines := []string{
		"Balance Sheet",
		"As of " + formatPDFDate(report.AsOfDate),
		fmt.Sprintf("Assets: %s | Liabilities: %s | Equity: %s | Balanced: %t", formatPDFMinor(report.TotalAssetsMinor), formatPDFMinor(report.TotalLiabilitiesMinor), formatPDFMinor(report.TotalEquityMinor), report.Balanced),
		"",
		"Assets",
		"Code | Account | Balance",
	}
	for _, row := range report.AssetRows {
		lines = append(lines, fmt.Sprintf("%s | %s | %s", row.AccountCode, row.AccountName, formatPDFMinor(row.BalanceMinor)))
	}
	lines = append(lines, "", "Liabilities", "Code | Account | Balance")
	for _, row := range report.LiabilityRows {
		lines = append(lines, fmt.Sprintf("%s | %s | %s", row.AccountCode, row.AccountName, formatPDFMinor(row.BalanceMinor)))
	}
	lines = append(lines, "", "Equity", "Code | Account | Balance")
	for _, row := range report.EquityRows {
		lines = append(lines, fmt.Sprintf("%s | %s | %s", row.AccountCode, row.AccountName, formatPDFMinor(row.BalanceMinor)))
	}
	return renderReportPDF(lines), "balance-sheet-" + report.AsOfDate.Format("2006-01-02") + ".pdf", nil
}

func (s ReportService) CashFlowPDF(ctx context.Context, organizationID string, from time.Time, to time.Time) ([]byte, string, error) {
	report, err := s.CashFlow(ctx, organizationID, from, to)
	if err != nil {
		return nil, "", err
	}
	lines := []string{
		"Cash Flow",
		formatPDFDate(report.FromDate) + " to " + formatPDFDate(report.ToDate),
		fmt.Sprintf("Opening cash: %s | Inflows: %s | Outflows: %s | Net: %s | Closing cash: %s", formatPDFMinor(report.OpeningCashMinor), formatPDFMinor(report.TotalInflowsMinor), formatPDFMinor(report.TotalOutflowsMinor), formatPDFMinor(report.NetCashFlowMinor), formatPDFMinor(report.ClosingCashMinor)),
		"",
		"Code | Account | Source | Inflow | Outflow | Net",
	}
	for _, row := range report.Rows {
		lines = append(lines, fmt.Sprintf("%s | %s | %s | %s | %s | %s", row.AccountCode, row.AccountName, row.SourceModule, formatPDFMinor(row.InflowMinor), formatPDFMinor(row.OutflowMinor), formatPDFMinor(row.NetCashFlowMinor)))
	}
	return renderReportPDF(lines), "cash-flow-" + report.FromDate.Format("2006-01-02") + "-to-" + report.ToDate.Format("2006-01-02") + ".pdf", nil
}

func (s ReportService) ARAgingPDF(ctx context.Context, organizationID string, asOf time.Time) ([]byte, string, error) {
	report, err := s.ARAging(ctx, organizationID, asOf)
	if err != nil {
		return nil, "", err
	}
	lines := agingPDFLines(
		"Accounts Receivable Aging",
		report.AsOfDate,
		report.TotalCurrentMinor,
		report.TotalOneToThirtyMinor,
		report.TotalThirtyOneToSixtyMinor,
		report.TotalSixtyOneToNinetyMinor,
		report.TotalOverNinetyMinor,
		report.TotalOutstandingMinor,
	)
	lines = append(lines, "Invoice | Customer | Due | Days overdue | Outstanding")
	for _, row := range report.Rows {
		lines = append(lines, fmt.Sprintf("%s | %s | %s | %d | %s", row.InvoiceNumber, row.CustomerName, formatPDFDate(row.DueDate), row.DaysOverdue, formatPDFMinor(row.OutstandingMinor)))
	}
	return renderReportPDF(lines), "ar-aging-" + report.AsOfDate.Format("2006-01-02") + ".pdf", nil
}

func (s ReportService) APAgingPDF(ctx context.Context, organizationID string, asOf time.Time) ([]byte, string, error) {
	report, err := s.APAging(ctx, organizationID, asOf)
	if err != nil {
		return nil, "", err
	}
	lines := agingPDFLines(
		"Accounts Payable Aging",
		report.AsOfDate,
		report.TotalCurrentMinor,
		report.TotalOneToThirtyMinor,
		report.TotalThirtyOneToSixtyMinor,
		report.TotalSixtyOneToNinetyMinor,
		report.TotalOverNinetyMinor,
		report.TotalOutstandingMinor,
	)
	lines = append(lines, "Bill | Vendor | Due | Days overdue | Outstanding")
	for _, row := range report.Rows {
		lines = append(lines, fmt.Sprintf("%s | %s | %s | %d | %s", row.BillNumber, row.VendorName, formatPDFDate(row.DueDate), row.DaysOverdue, formatPDFMinor(row.OutstandingMinor)))
	}
	return renderReportPDF(lines), "ap-aging-" + report.AsOfDate.Format("2006-01-02") + ".pdf", nil
}

func (s ReportService) TaxLiabilityPDF(ctx context.Context, organizationID string, from time.Time, to time.Time) ([]byte, string, error) {
	report, err := s.TaxLiability(ctx, organizationID, from, to)
	if err != nil {
		return nil, "", err
	}
	lines := []string{
		"Tax Liability",
		formatPDFDate(report.FromDate) + " to " + formatPDFDate(report.ToDate),
		fmt.Sprintf("Output tax: %s | Input tax: %s | Net payable: %s", formatPDFMinor(report.OutputTaxMinor), formatPDFMinor(report.InputTaxMinor), formatPDFMinor(report.NetPayableMinor)),
		"",
		"Rate/group | Output | Input | Net payable",
	}
	for _, row := range report.Rows {
		lines = append(lines, fmt.Sprintf("%s | %s | %s | %s", row.Name, formatPDFMinor(row.OutputTaxMinor), formatPDFMinor(row.InputTaxMinor), formatPDFMinor(row.NetPayableMinor)))
	}
	return renderReportPDF(lines), "tax-liability-" + report.FromDate.Format("2006-01-02") + "-to-" + report.ToDate.Format("2006-01-02") + ".pdf", nil
}

func (s ReportService) TaxSummaryPDF(ctx context.Context, organizationID string, from time.Time, to time.Time) ([]byte, string, error) {
	report, err := s.TaxSummary(ctx, organizationID, from, to)
	if err != nil {
		return nil, "", err
	}
	outputTaxMinor, inputTaxMinor, netPayableMinor := taxReportTotals(report.Rows)
	lines := []string{
		"Tax Summary",
		formatPDFDate(report.FromDate) + " to " + formatPDFDate(report.ToDate),
		fmt.Sprintf("Output tax: %s | Input tax: %s | Net payable: %s", formatPDFMinor(outputTaxMinor), formatPDFMinor(inputTaxMinor), formatPDFMinor(netPayableMinor)),
		"",
		"Rate/group | Output | Input | Net payable",
	}
	for _, row := range report.Rows {
		lines = append(lines, fmt.Sprintf("%s | %s | %s | %s", row.Name, formatPDFMinor(row.OutputTaxMinor), formatPDFMinor(row.InputTaxMinor), formatPDFMinor(row.NetPayableMinor)))
	}
	return renderReportPDF(lines), "tax-summary-" + report.FromDate.Format("2006-01-02") + "-to-" + report.ToDate.Format("2006-01-02") + ".pdf", nil
}

func agingPDFLines(title string, asOf time.Time, currentMinor int64, oneToThirtyMinor int64, thirtyOneToSixtyMinor int64, sixtyOneToNinetyMinor int64, overNinetyMinor int64, outstandingMinor int64) []string {
	return []string{
		title,
		"As of " + formatPDFDate(asOf),
		fmt.Sprintf("Outstanding: %s | Current: %s | 1-30: %s | 31-60: %s | 61-90: %s | 90+: %s", formatPDFMinor(outstandingMinor), formatPDFMinor(currentMinor), formatPDFMinor(oneToThirtyMinor), formatPDFMinor(thirtyOneToSixtyMinor), formatPDFMinor(sixtyOneToNinetyMinor), formatPDFMinor(overNinetyMinor)),
		"",
	}
}

func taxReportTotals(rows []TaxReportRow) (int64, int64, int64) {
	var outputTaxMinor, inputTaxMinor, netPayableMinor int64
	for _, row := range rows {
		outputTaxMinor += row.OutputTaxMinor
		inputTaxMinor += row.InputTaxMinor
		netPayableMinor += row.NetPayableMinor
	}
	return outputTaxMinor, inputTaxMinor, netPayableMinor
}

func renderReportPDF(lines []string) []byte {
	var content bytes.Buffer
	y := 780
	for index, line := range lines {
		size := 10
		if index == 0 {
			size = 18
		}
		if line == "" {
			y -= 12
			continue
		}
		fmt.Fprintf(&content, "BT /F1 %d Tf 40 %d Td (%s) Tj ET\n", size, y, escapePDFText(truncatePDFLine(line)))
		y -= 16
		if y < 48 {
			break
		}
	}
	return buildSimplePDF(content.Bytes())
}

func truncatePDFLine(value string) string {
	if len(value) <= 120 {
		return value
	}
	return value[:117] + "..."
}

func formatPDFMinor(amountMinor int64) string {
	sign := ""
	if amountMinor < 0 {
		sign = "-"
		amountMinor = -amountMinor
	}
	return fmt.Sprintf("%sINR %d.%02d", sign, amountMinor/100, amountMinor%100)
}
