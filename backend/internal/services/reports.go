package services

import (
	"bytes"
	"context"
	"encoding/csv"
	"strconv"
	"strings"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

type ReportService struct {
	db          *gorm.DB
	emailSender EmailSender
}

type ReportRow struct {
	AccountID    string             `json:"account_id"`
	AccountCode  string             `json:"account_code"`
	AccountName  string             `json:"account_name"`
	AccountType  domain.AccountType `json:"account_type"`
	DebitMinor   int64              `json:"debit_minor"`
	CreditMinor  int64              `json:"credit_minor"`
	BalanceMinor int64              `json:"balance_minor"`
}

type AccountDrilldownReport struct {
	AccountID           string                `json:"account_id"`
	AccountCode         string                `json:"account_code"`
	AccountName         string                `json:"account_name"`
	AccountType         domain.AccountType    `json:"account_type"`
	FromDate            time.Time             `json:"from_date"`
	ToDate              time.Time             `json:"to_date"`
	OpeningBalanceMinor int64                 `json:"opening_balance_minor"`
	ClosingBalanceMinor int64                 `json:"closing_balance_minor"`
	Rows                []AccountDrilldownRow `json:"rows"`
}

type AccountDrilldownRow struct {
	LedgerSplitID        string              `json:"ledger_split_id"`
	JournalTransactionID string              `json:"journal_transaction_id"`
	TransactionDate      time.Time           `json:"transaction_date"`
	SourceModule         domain.SourceModule `json:"source_module"`
	SourceDocumentType   string              `json:"source_document_type,omitempty"`
	SourceDocumentID     string              `json:"source_document_id,omitempty"`
	SourceDocumentNumber string              `json:"source_document_number,omitempty"`
	TransactionMemo      string              `json:"transaction_memo"`
	SplitMemo            string              `json:"split_memo"`
	DebitMinor           int64               `json:"debit_minor"`
	CreditMinor          int64               `json:"credit_minor"`
	BalanceMinor         int64               `json:"balance_minor"`
	Currency             string              `json:"currency"`
	Cleared              bool                `json:"cleared"`
	Reconciled           bool                `json:"reconciled"`
}

type accountDrilldownActivity struct {
	LedgerSplitID        string
	JournalTransactionID string
	TransactionDate      time.Time
	SourceModule         domain.SourceModule
	TransactionMemo      string
	SplitMemo            string
	DebitMinor           int64
	CreditMinor          int64
	Currency             string
	Cleared              bool
	Reconciled           bool
	CreatedAt            time.Time
}

type TrialBalanceReport struct {
	AsOfDate         time.Time   `json:"as_of_date"`
	Rows             []ReportRow `json:"rows"`
	TotalDebitMinor  int64       `json:"total_debit_minor"`
	TotalCreditMinor int64       `json:"total_credit_minor"`
	Balanced         bool        `json:"balanced"`
}

type ProfitAndLossReport struct {
	FromDate          time.Time   `json:"from_date"`
	ToDate            time.Time   `json:"to_date"`
	IncomeRows        []ReportRow `json:"income_rows"`
	ExpenseRows       []ReportRow `json:"expense_rows"`
	TotalIncomeMinor  int64       `json:"total_income_minor"`
	TotalExpenseMinor int64       `json:"total_expense_minor"`
	NetIncomeMinor    int64       `json:"net_income_minor"`
}

type BalanceSheetReport struct {
	AsOfDate              time.Time   `json:"as_of_date"`
	AssetRows             []ReportRow `json:"asset_rows"`
	LiabilityRows         []ReportRow `json:"liability_rows"`
	EquityRows            []ReportRow `json:"equity_rows"`
	TotalAssetsMinor      int64       `json:"total_assets_minor"`
	TotalLiabilitiesMinor int64       `json:"total_liabilities_minor"`
	TotalEquityMinor      int64       `json:"total_equity_minor"`
	Balanced              bool        `json:"balanced"`
}

type CashFlowReport struct {
	FromDate              time.Time     `json:"from_date"`
	ToDate                time.Time     `json:"to_date"`
	Rows                  []CashFlowRow `json:"rows"`
	TotalInflowsMinor     int64         `json:"total_inflows_minor"`
	TotalOutflowsMinor    int64         `json:"total_outflows_minor"`
	NetCashFlowMinor      int64         `json:"net_cash_flow_minor"`
	OpeningCashMinor      int64         `json:"opening_cash_minor"`
	ClosingCashMinor      int64         `json:"closing_cash_minor"`
	GeneratedFromSubtypes []string      `json:"generated_from_subtypes"`
}

type CashFlowRow struct {
	AccountID        string              `json:"account_id"`
	AccountCode      string              `json:"account_code"`
	AccountName      string              `json:"account_name"`
	SourceModule     domain.SourceModule `json:"source_module"`
	InflowMinor      int64               `json:"inflow_minor"`
	OutflowMinor     int64               `json:"outflow_minor"`
	NetCashFlowMinor int64               `json:"net_cash_flow_minor"`
}

type ARAgingReport struct {
	AsOfDate                   time.Time    `json:"as_of_date"`
	Rows                       []ARAgingRow `json:"rows"`
	TotalCurrentMinor          int64        `json:"total_current_minor"`
	TotalOneToThirtyMinor      int64        `json:"total_one_to_thirty_minor"`
	TotalThirtyOneToSixtyMinor int64        `json:"total_thirty_one_to_sixty_minor"`
	TotalSixtyOneToNinetyMinor int64        `json:"total_sixty_one_to_ninety_minor"`
	TotalOverNinetyMinor       int64        `json:"total_over_ninety_minor"`
	TotalOutstandingMinor      int64        `json:"total_outstanding_minor"`
}

type ARAgingRow struct {
	CustomerID            string    `json:"customer_id"`
	CustomerName          string    `json:"customer_name"`
	InvoiceID             string    `json:"invoice_id"`
	InvoiceNumber         string    `json:"invoice_number"`
	DueDate               time.Time `json:"due_date"`
	DaysOverdue           int       `json:"days_overdue"`
	OutstandingMinor      int64     `json:"outstanding_minor"`
	CurrentMinor          int64     `json:"current_minor"`
	OneToThirtyMinor      int64     `json:"one_to_thirty_minor"`
	ThirtyOneToSixtyMinor int64     `json:"thirty_one_to_sixty_minor"`
	SixtyOneToNinetyMinor int64     `json:"sixty_one_to_ninety_minor"`
	OverNinetyMinor       int64     `json:"over_ninety_minor"`
}

type APAgingReport struct {
	AsOfDate                   time.Time    `json:"as_of_date"`
	Rows                       []APAgingRow `json:"rows"`
	TotalCurrentMinor          int64        `json:"total_current_minor"`
	TotalOneToThirtyMinor      int64        `json:"total_one_to_thirty_minor"`
	TotalThirtyOneToSixtyMinor int64        `json:"total_thirty_one_to_sixty_minor"`
	TotalSixtyOneToNinetyMinor int64        `json:"total_sixty_one_to_ninety_minor"`
	TotalOverNinetyMinor       int64        `json:"total_over_ninety_minor"`
	TotalOutstandingMinor      int64        `json:"total_outstanding_minor"`
}

type APAgingRow struct {
	VendorID              string    `json:"vendor_id"`
	VendorName            string    `json:"vendor_name"`
	BillID                string    `json:"bill_id"`
	BillNumber            string    `json:"bill_number"`
	DueDate               time.Time `json:"due_date"`
	DaysOverdue           int       `json:"days_overdue"`
	OutstandingMinor      int64     `json:"outstanding_minor"`
	CurrentMinor          int64     `json:"current_minor"`
	OneToThirtyMinor      int64     `json:"one_to_thirty_minor"`
	ThirtyOneToSixtyMinor int64     `json:"thirty_one_to_sixty_minor"`
	SixtyOneToNinetyMinor int64     `json:"sixty_one_to_ninety_minor"`
	OverNinetyMinor       int64     `json:"over_ninety_minor"`
}

type TaxLiabilityReport struct {
	FromDate        time.Time      `json:"from_date"`
	ToDate          time.Time      `json:"to_date"`
	OutputTaxMinor  int64          `json:"output_tax_minor"`
	InputTaxMinor   int64          `json:"input_tax_minor"`
	NetPayableMinor int64          `json:"net_payable_minor"`
	Rows            []TaxReportRow `json:"rows"`
}

type TaxSummaryReport struct {
	FromDate time.Time      `json:"from_date"`
	ToDate   time.Time      `json:"to_date"`
	Rows     []TaxReportRow `json:"rows"`
}

type TaxReportRow struct {
	TaxRateID       string `json:"tax_rate_id"`
	TaxGroupID      string `json:"tax_group_id,omitempty"`
	Name            string `json:"name"`
	OutputTaxMinor  int64  `json:"output_tax_minor"`
	InputTaxMinor   int64  `json:"input_tax_minor"`
	NetPayableMinor int64  `json:"net_payable_minor"`
}

type PayrollSummaryReport struct {
	FromDate                        time.Time           `json:"from_date"`
	ToDate                          time.Time           `json:"to_date"`
	Rows                            []PayrollSummaryRow `json:"rows"`
	TotalRuns                       int                 `json:"total_runs"`
	TotalEmployees                  int                 `json:"total_employees"`
	TotalGrossPayMinor              int64               `json:"total_gross_pay_minor"`
	TotalDeductionsMinor            int64               `json:"total_deductions_minor"`
	TotalNetPayMinor                int64               `json:"total_net_pay_minor"`
	TotalEmployerContributionsMinor int64               `json:"total_employer_contributions_minor"`
	TotalPayrollCostMinor           int64               `json:"total_payroll_cost_minor"`
}

type PayrollSummaryRow struct {
	PayrollRunID               string    `json:"payroll_run_id"`
	RunNumber                  string    `json:"run_number"`
	PeriodStart                time.Time `json:"period_start"`
	PeriodEnd                  time.Time `json:"period_end"`
	PayDate                    time.Time `json:"pay_date"`
	Currency                   string    `json:"currency"`
	EmployeeCount              int       `json:"employee_count"`
	GrossPayMinor              int64     `json:"gross_pay_minor"`
	DeductionsMinor            int64     `json:"deductions_minor"`
	NetPayMinor                int64     `json:"net_pay_minor"`
	EmployerContributionsMinor int64     `json:"employer_contributions_minor"`
	PayrollCostMinor           int64     `json:"payroll_cost_minor"`
	JournalTransactionID       string    `json:"journal_transaction_id,omitempty"`
}

type accountActivity struct {
	AccountID   string
	AccountCode string
	AccountName string
	AccountType domain.AccountType
	DebitMinor  int64
	CreditMinor int64
}

func NewReportService(db *gorm.DB) ReportService {
	return ReportService{db: db}
}

func NewReportServiceWithEmail(db *gorm.DB, emailSender EmailSender) ReportService {
	return ReportService{db: db, emailSender: emailSender}
}

func (s ReportService) AccountDrilldown(ctx context.Context, organizationID string, accountID string, from time.Time, to time.Time) (AccountDrilldownReport, error) {
	var account domain.Account
	if err := s.db.WithContext(ctx).
		Where("organization_id = ? AND id = ?", organizationID, accountID).
		First(&account).Error; err != nil {
		return AccountDrilldownReport{}, err
	}

	openingBalance, err := s.accountNormalBalance(ctx, organizationID, account, nil, &from, true)
	if err != nil {
		return AccountDrilldownReport{}, err
	}

	var activities []accountDrilldownActivity
	if err := s.db.WithContext(ctx).
		Table("ledger_splits").
		Select(`ledger_splits.id AS ledger_split_id,
			ledger_splits.journal_transaction_id AS journal_transaction_id,
			journal_transactions.transaction_date AS transaction_date,
			journal_transactions.source_module AS source_module,
			journal_transactions.memo AS transaction_memo,
			ledger_splits.memo AS split_memo,
			CASE WHEN ledger_splits.base_debit_minor != 0 OR ledger_splits.base_credit_minor != 0 THEN ledger_splits.base_debit_minor ELSE ledger_splits.debit_minor END AS debit_minor,
			CASE WHEN ledger_splits.base_debit_minor != 0 OR ledger_splits.base_credit_minor != 0 THEN ledger_splits.base_credit_minor ELSE ledger_splits.credit_minor END AS credit_minor,
			ledger_splits.currency AS currency,
			ledger_splits.cleared AS cleared,
			ledger_splits.reconciled AS reconciled,
			ledger_splits.created_at AS created_at`).
		Joins("JOIN journal_transactions ON journal_transactions.id = ledger_splits.journal_transaction_id").
		Where("ledger_splits.organization_id = ? AND ledger_splits.account_id = ?", organizationID, account.ID).
		Where("journal_transactions.organization_id = ? AND journal_transactions.status = ?", organizationID, domain.JournalStatusPosted).
		Where("journal_transactions.transaction_date >= ? AND journal_transactions.transaction_date <= ?", from, to).
		Order("journal_transactions.transaction_date ASC, ledger_splits.created_at ASC").
		Scan(&activities).Error; err != nil {
		return AccountDrilldownReport{}, err
	}

	report := AccountDrilldownReport{
		AccountID:           account.ID,
		AccountCode:         account.Code,
		AccountName:         account.Name,
		AccountType:         account.Type,
		FromDate:            from,
		ToDate:              to,
		OpeningBalanceMinor: openingBalance,
		Rows:                make([]AccountDrilldownRow, 0, len(activities)),
	}
	sourceRefs, err := s.sourceDocumentRefsForTransactions(ctx, organizationID, drilldownTransactionIDs(activities))
	if err != nil {
		return AccountDrilldownReport{}, err
	}
	runningBalance := openingBalance
	for _, activity := range activities {
		runningBalance += normalBalanceDelta(account.Type, activity.DebitMinor, activity.CreditMinor)
		sourceRef := sourceRefs[activity.JournalTransactionID]
		report.Rows = append(report.Rows, AccountDrilldownRow{
			LedgerSplitID:        activity.LedgerSplitID,
			JournalTransactionID: activity.JournalTransactionID,
			TransactionDate:      activity.TransactionDate,
			SourceModule:         activity.SourceModule,
			SourceDocumentType:   sourceRef.DocumentType,
			SourceDocumentID:     sourceRef.DocumentID,
			SourceDocumentNumber: sourceRef.DocumentNumber,
			TransactionMemo:      activity.TransactionMemo,
			SplitMemo:            activity.SplitMemo,
			DebitMinor:           activity.DebitMinor,
			CreditMinor:          activity.CreditMinor,
			BalanceMinor:         runningBalance,
			Currency:             activity.Currency,
			Cleared:              activity.Cleared,
			Reconciled:           activity.Reconciled,
		})
	}
	report.ClosingBalanceMinor = runningBalance
	return report, nil
}

type sourceDocumentRef struct {
	DocumentType   string
	DocumentID     string
	DocumentNumber string
}

func drilldownTransactionIDs(activities []accountDrilldownActivity) []string {
	seen := map[string]bool{}
	ids := make([]string, 0, len(activities))
	for _, activity := range activities {
		transactionID := activity.JournalTransactionID
		if transactionID == "" || seen[transactionID] {
			continue
		}
		seen[transactionID] = true
		ids = append(ids, transactionID)
	}
	return ids
}

func (s ReportService) sourceDocumentRefsForTransactions(ctx context.Context, organizationID string, transactionIDs []string) (map[string]sourceDocumentRef, error) {
	refs := make(map[string]sourceDocumentRef, len(transactionIDs))
	if len(transactionIDs) == 0 {
		return refs, nil
	}

	type sourceRow struct {
		ID                   string
		JournalTransactionID string
		Number               string
	}
	load := func(table string, numberColumn string, documentType string) error {
		var rows []sourceRow
		err := s.db.WithContext(ctx).
			Table(table).
			Select("id, journal_transaction_id, "+numberColumn+" AS number").
			Where("organization_id = ? AND journal_transaction_id IN ?", organizationID, transactionIDs).
			Scan(&rows).Error
		if err != nil {
			return err
		}
		for _, row := range rows {
			if row.JournalTransactionID == "" {
				continue
			}
			refs[row.JournalTransactionID] = sourceDocumentRef{
				DocumentType:   documentType,
				DocumentID:     row.ID,
				DocumentNumber: row.Number,
			}
		}
		return nil
	}

	for _, source := range []struct {
		table        string
		numberColumn string
		documentType string
	}{
		{table: "invoices", numberColumn: "invoice_number", documentType: "invoice"},
		{table: "credit_notes", numberColumn: "credit_note_number", documentType: "credit_note"},
		{table: "customer_payments", numberColumn: "payment_number", documentType: "customer_payment"},
		{table: "expenses", numberColumn: "expense_number", documentType: "expense"},
		{table: "bills", numberColumn: "bill_number", documentType: "bill"},
		{table: "vendor_payments", numberColumn: "payment_number", documentType: "vendor_payment"},
		{table: "payroll_runs", numberColumn: "run_number", documentType: "payroll_run"},
	} {
		if err := load(source.table, source.numberColumn, source.documentType); err != nil {
			return nil, err
		}
	}

	return refs, nil
}

func (s ReportService) TrialBalance(ctx context.Context, organizationID string, asOf time.Time) (TrialBalanceReport, error) {
	activities, err := s.accountActivities(ctx, organizationID, nil, &asOf, []domain.AccountType{
		domain.AccountTypeAsset,
		domain.AccountTypeLiability,
		domain.AccountTypeEquity,
		domain.AccountTypeIncome,
		domain.AccountTypeExpense,
	})
	if err != nil {
		return TrialBalanceReport{}, err
	}

	report := TrialBalanceReport{AsOfDate: asOf, Rows: make([]ReportRow, 0, len(activities))}
	for _, activity := range activities {
		row := activity.toReportRow()
		report.Rows = append(report.Rows, row)
		report.TotalDebitMinor += row.DebitMinor
		report.TotalCreditMinor += row.CreditMinor
	}
	report.Balanced = report.TotalDebitMinor == report.TotalCreditMinor
	return report, nil
}

func (s ReportService) ProfitAndLoss(ctx context.Context, organizationID string, from time.Time, to time.Time) (ProfitAndLossReport, error) {
	activities, err := s.accountActivities(ctx, organizationID, &from, &to, []domain.AccountType{
		domain.AccountTypeIncome,
		domain.AccountTypeExpense,
	})
	if err != nil {
		return ProfitAndLossReport{}, err
	}

	report := ProfitAndLossReport{FromDate: from, ToDate: to}
	for _, activity := range activities {
		row := activity.toReportRow()
		switch activity.AccountType {
		case domain.AccountTypeIncome:
			report.IncomeRows = append(report.IncomeRows, row)
			report.TotalIncomeMinor += row.BalanceMinor
		case domain.AccountTypeExpense:
			report.ExpenseRows = append(report.ExpenseRows, row)
			report.TotalExpenseMinor += row.BalanceMinor
		}
	}
	report.NetIncomeMinor = report.TotalIncomeMinor - report.TotalExpenseMinor
	return report, nil
}

func (s ReportService) BalanceSheet(ctx context.Context, organizationID string, asOf time.Time) (BalanceSheetReport, error) {
	activities, err := s.accountActivities(ctx, organizationID, nil, &asOf, []domain.AccountType{
		domain.AccountTypeAsset,
		domain.AccountTypeLiability,
		domain.AccountTypeEquity,
	})
	if err != nil {
		return BalanceSheetReport{}, err
	}

	report := BalanceSheetReport{AsOfDate: asOf}
	for _, activity := range activities {
		row := activity.toReportRow()
		switch activity.AccountType {
		case domain.AccountTypeAsset:
			report.AssetRows = append(report.AssetRows, row)
			report.TotalAssetsMinor += row.BalanceMinor
		case domain.AccountTypeLiability:
			report.LiabilityRows = append(report.LiabilityRows, row)
			report.TotalLiabilitiesMinor += row.BalanceMinor
		case domain.AccountTypeEquity:
			report.EquityRows = append(report.EquityRows, row)
			report.TotalEquityMinor += row.BalanceMinor
		}
	}
	pnl, err := s.ProfitAndLoss(ctx, organizationID, time.Time{}, asOf)
	if err != nil {
		return BalanceSheetReport{}, err
	}
	if pnl.NetIncomeMinor != 0 {
		report.EquityRows = append(report.EquityRows, ReportRow{
			AccountName:  "Current Period Earnings",
			AccountType:  domain.AccountTypeEquity,
			BalanceMinor: pnl.NetIncomeMinor,
		})
		report.TotalEquityMinor += pnl.NetIncomeMinor
	}
	report.Balanced = report.TotalAssetsMinor == report.TotalLiabilitiesMinor+report.TotalEquityMinor
	return report, nil
}

func (s ReportService) CashFlow(ctx context.Context, organizationID string, from time.Time, to time.Time) (CashFlowReport, error) {
	rows, err := s.cashFlowRows(ctx, organizationID, from, to)
	if err != nil {
		return CashFlowReport{}, err
	}
	openingCash, err := s.cashBalance(ctx, organizationID, &from, nil)
	if err != nil {
		return CashFlowReport{}, err
	}
	closingCash, err := s.cashBalance(ctx, organizationID, nil, &to)
	if err != nil {
		return CashFlowReport{}, err
	}

	report := CashFlowReport{
		FromDate:              from,
		ToDate:                to,
		Rows:                  rows,
		OpeningCashMinor:      openingCash,
		ClosingCashMinor:      closingCash,
		GeneratedFromSubtypes: cashAccountSubtypes(),
	}
	for _, row := range rows {
		report.TotalInflowsMinor += row.InflowMinor
		report.TotalOutflowsMinor += row.OutflowMinor
	}
	report.NetCashFlowMinor = report.TotalInflowsMinor - report.TotalOutflowsMinor
	return report, nil
}

func (s ReportService) ARAging(ctx context.Context, organizationID string, asOf time.Time) (ARAgingReport, error) {
	var invoices []domain.Invoice
	if err := s.db.WithContext(ctx).
		Preload("Customer").
		Where("organization_id = ? AND status IN ?", organizationID, []domain.InvoiceStatus{domain.InvoiceStatusPosted, domain.InvoiceStatusPaid}).
		Order("due_date ASC, invoice_number ASC").
		Find(&invoices).
		Error; err != nil {
		return ARAgingReport{}, err
	}

	report := ARAgingReport{AsOfDate: asOf, Rows: make([]ARAgingRow, 0, len(invoices))}
	for _, invoice := range invoices {
		paidMinor, err := sumCustomerPayments(ctx, s.db, organizationID, invoice.ID, &asOf)
		if err != nil {
			return ARAgingReport{}, err
		}
		outstandingMinor := invoice.TotalMinor - paidMinor
		if outstandingMinor <= 0 {
			continue
		}
		row := arAgingRow(invoice, asOf, outstandingMinor)
		report.Rows = append(report.Rows, row)
		report.TotalCurrentMinor += row.CurrentMinor
		report.TotalOneToThirtyMinor += row.OneToThirtyMinor
		report.TotalThirtyOneToSixtyMinor += row.ThirtyOneToSixtyMinor
		report.TotalSixtyOneToNinetyMinor += row.SixtyOneToNinetyMinor
		report.TotalOverNinetyMinor += row.OverNinetyMinor
		report.TotalOutstandingMinor += row.OutstandingMinor
	}
	return report, nil
}

func (s ReportService) APAging(ctx context.Context, organizationID string, asOf time.Time) (APAgingReport, error) {
	var bills []domain.Bill
	if err := s.db.WithContext(ctx).
		Preload("Vendor").
		Where("organization_id = ? AND status IN ?", organizationID, []domain.BillStatus{domain.BillStatusPosted, domain.BillStatusPaid}).
		Order("due_date ASC, bill_number ASC").
		Find(&bills).
		Error; err != nil {
		return APAgingReport{}, err
	}

	report := APAgingReport{AsOfDate: asOf, Rows: make([]APAgingRow, 0, len(bills))}
	for _, bill := range bills {
		paidMinor, err := sumVendorPayments(ctx, s.db, organizationID, bill.ID, &asOf)
		if err != nil {
			return APAgingReport{}, err
		}
		outstandingMinor := bill.TotalMinor - paidMinor
		if outstandingMinor <= 0 {
			continue
		}
		row := apAgingRow(bill, asOf, outstandingMinor)
		report.Rows = append(report.Rows, row)
		report.TotalCurrentMinor += row.CurrentMinor
		report.TotalOneToThirtyMinor += row.OneToThirtyMinor
		report.TotalThirtyOneToSixtyMinor += row.ThirtyOneToSixtyMinor
		report.TotalSixtyOneToNinetyMinor += row.SixtyOneToNinetyMinor
		report.TotalOverNinetyMinor += row.OverNinetyMinor
		report.TotalOutstandingMinor += row.OutstandingMinor
	}
	return report, nil
}

func (s ReportService) TaxLiability(ctx context.Context, organizationID string, from time.Time, to time.Time) (TaxLiabilityReport, error) {
	summary, err := s.TaxSummary(ctx, organizationID, from, to)
	if err != nil {
		return TaxLiabilityReport{}, err
	}

	report := TaxLiabilityReport{
		FromDate: from,
		ToDate:   to,
		Rows:     summary.Rows,
	}
	for _, row := range summary.Rows {
		report.OutputTaxMinor += row.OutputTaxMinor
		report.InputTaxMinor += row.InputTaxMinor
	}
	report.NetPayableMinor = report.OutputTaxMinor - report.InputTaxMinor
	return report, nil
}

func (s ReportService) TaxSummary(ctx context.Context, organizationID string, from time.Time, to time.Time) (TaxSummaryReport, error) {
	rows := make(map[string]TaxReportRow)
	if err := s.addInvoiceTaxRows(ctx, organizationID, from, to, rows); err != nil {
		return TaxSummaryReport{}, err
	}
	if err := s.addExpenseTaxRows(ctx, organizationID, from, to, rows); err != nil {
		return TaxSummaryReport{}, err
	}
	if err := s.addBillTaxRows(ctx, organizationID, from, to, rows); err != nil {
		return TaxSummaryReport{}, err
	}

	report := TaxSummaryReport{FromDate: from, ToDate: to}
	for _, row := range rows {
		row.NetPayableMinor = row.OutputTaxMinor - row.InputTaxMinor
		report.Rows = append(report.Rows, row)
	}
	return report, nil
}

func (s ReportService) PayrollSummary(ctx context.Context, organizationID string, from time.Time, to time.Time) (PayrollSummaryReport, error) {
	var runs []domain.PayrollRun
	if err := s.db.WithContext(ctx).
		Preload("Items").
		Where("organization_id = ? AND status = ? AND pay_date >= ? AND pay_date <= ?", organizationID, domain.PayrollRunStatusPosted, from, to).
		Order("pay_date ASC, run_number ASC").
		Find(&runs).Error; err != nil {
		return PayrollSummaryReport{}, err
	}

	report := PayrollSummaryReport{FromDate: from, ToDate: to, Rows: make([]PayrollSummaryRow, 0, len(runs))}
	for _, run := range runs {
		payrollCost := run.PayrollCostMinor
		if payrollCost == 0 {
			payrollCost = run.GrossPayMinor + run.EmployerContributionsMinor
		}
		journalTransactionID := ""
		if run.JournalTransactionID != nil {
			journalTransactionID = *run.JournalTransactionID
		}
		row := PayrollSummaryRow{
			PayrollRunID:               run.ID,
			RunNumber:                  run.RunNumber,
			PeriodStart:                run.PeriodStart,
			PeriodEnd:                  run.PeriodEnd,
			PayDate:                    run.PayDate,
			Currency:                   run.Currency,
			EmployeeCount:              len(run.Items),
			GrossPayMinor:              run.GrossPayMinor,
			DeductionsMinor:            run.DeductionsMinor,
			NetPayMinor:                run.NetPayMinor,
			EmployerContributionsMinor: run.EmployerContributionsMinor,
			PayrollCostMinor:           payrollCost,
			JournalTransactionID:       journalTransactionID,
		}
		report.Rows = append(report.Rows, row)
		report.TotalRuns++
		report.TotalEmployees += row.EmployeeCount
		report.TotalGrossPayMinor += row.GrossPayMinor
		report.TotalDeductionsMinor += row.DeductionsMinor
		report.TotalNetPayMinor += row.NetPayMinor
		report.TotalEmployerContributionsMinor += row.EmployerContributionsMinor
		report.TotalPayrollCostMinor += row.PayrollCostMinor
	}
	return report, nil
}

func (s ReportService) PayrollSummaryCSV(ctx context.Context, organizationID string, from time.Time, to time.Time) ([]byte, string, error) {
	report, err := s.PayrollSummary(ctx, organizationID, from, to)
	if err != nil {
		return nil, "", err
	}

	var buffer bytes.Buffer
	writer := csv.NewWriter(&buffer)
	_ = writer.Write([]string{"Run", "Period start", "Period end", "Pay date", "Currency", "Employees", "Gross minor", "Deductions minor", "Net minor", "Employer contributions minor", "Payroll cost minor", "Journal transaction ID"})
	for _, row := range report.Rows {
		_ = writer.Write([]string{
			row.RunNumber,
			formatReportDate(row.PeriodStart),
			formatReportDate(row.PeriodEnd),
			formatReportDate(row.PayDate),
			row.Currency,
			strconv.Itoa(row.EmployeeCount),
			strconv.FormatInt(row.GrossPayMinor, 10),
			strconv.FormatInt(row.DeductionsMinor, 10),
			strconv.FormatInt(row.NetPayMinor, 10),
			strconv.FormatInt(row.EmployerContributionsMinor, 10),
			strconv.FormatInt(row.PayrollCostMinor, 10),
			row.JournalTransactionID,
		})
	}
	_ = writer.Write([]string{
		"Total",
		"",
		"",
		"",
		"",
		strconv.Itoa(report.TotalEmployees),
		strconv.FormatInt(report.TotalGrossPayMinor, 10),
		strconv.FormatInt(report.TotalDeductionsMinor, 10),
		strconv.FormatInt(report.TotalNetPayMinor, 10),
		strconv.FormatInt(report.TotalEmployerContributionsMinor, 10),
		strconv.FormatInt(report.TotalPayrollCostMinor, 10),
		"",
	})
	writer.Flush()
	if err := writer.Error(); err != nil {
		return nil, "", err
	}
	filename := "payroll-summary-" + from.Format("2006-01-02") + "-to-" + to.Format("2006-01-02") + ".csv"
	return buffer.Bytes(), filename, nil
}

func (s ReportService) PayrollStatutoryComponentCSV(ctx context.Context, organizationID string, from time.Time, to time.Time, componentCode string) ([]byte, string, error) {
	code := strings.ToUpper(strings.TrimSpace(componentCode))
	if code == "" {
		code = "TDS"
	}

	var runs []domain.PayrollRun
	if err := s.db.WithContext(ctx).
		Preload("Items.Employee").
		Preload("Items.Components").
		Where("organization_id = ? AND status = ? AND pay_date >= ? AND pay_date <= ?", organizationID, domain.PayrollRunStatusPosted, from, to).
		Order("pay_date ASC, run_number ASC").
		Find(&runs).Error; err != nil {
		return nil, "", err
	}

	var buffer bytes.Buffer
	writer := csv.NewWriter(&buffer)
	_ = writer.Write([]string{"Run", "Period start", "Period end", "Pay date", "Employee code", "Employee name", "PAN", "UAN", "Component code", "Component name", "Amount minor", "Gross pay minor", "Net pay minor"})
	var totalAmount int64
	for _, run := range runs {
		for _, item := range run.Items {
			for _, component := range item.Components {
				if !component.IsStatutory || strings.ToUpper(component.Code) != code {
					continue
				}
				totalAmount += component.AmountMinor
				_ = writer.Write([]string{
					run.RunNumber,
					formatReportDate(run.PeriodStart),
					formatReportDate(run.PeriodEnd),
					formatReportDate(run.PayDate),
					item.Employee.EmployeeCode,
					item.Employee.DisplayName,
					item.Employee.PAN,
					item.Employee.UAN,
					component.Code,
					component.Name,
					strconv.FormatInt(component.AmountMinor, 10),
					strconv.FormatInt(item.GrossPayMinor, 10),
					strconv.FormatInt(item.NetPayMinor, 10),
				})
			}
		}
	}
	_ = writer.Write([]string{"Total", "", "", "", "", "", "", "", code, "", strconv.FormatInt(totalAmount, 10), "", ""})
	writer.Flush()
	if err := writer.Error(); err != nil {
		return nil, "", err
	}
	filename := "payroll-" + strings.ToLower(code) + "-statutory-" + from.Format("2006-01-02") + "-to-" + to.Format("2006-01-02") + ".csv"
	return buffer.Bytes(), filename, nil
}

func formatReportDate(value time.Time) string {
	if value.IsZero() {
		return ""
	}
	return value.Format("2006-01-02")
}

func (s ReportService) cashFlowRows(ctx context.Context, organizationID string, from time.Time, to time.Time) ([]CashFlowRow, error) {
	type cashFlowActivity struct {
		AccountID    string
		AccountCode  string
		AccountName  string
		SourceModule domain.SourceModule
		DebitMinor   int64
		CreditMinor  int64
	}

	var activities []cashFlowActivity
	if err := s.db.WithContext(ctx).
		Table("ledger_splits").
		Select(`ledger_splits.account_id AS account_id,
			accounts.code AS account_code,
			accounts.name AS account_name,
			journal_transactions.source_module AS source_module,
			COALESCE(SUM(CASE WHEN ledger_splits.base_debit_minor != 0 OR ledger_splits.base_credit_minor != 0 THEN ledger_splits.base_debit_minor ELSE ledger_splits.debit_minor END), 0) AS debit_minor,
			COALESCE(SUM(CASE WHEN ledger_splits.base_debit_minor != 0 OR ledger_splits.base_credit_minor != 0 THEN ledger_splits.base_credit_minor ELSE ledger_splits.credit_minor END), 0) AS credit_minor`).
		Joins("JOIN accounts ON accounts.id = ledger_splits.account_id").
		Joins("JOIN journal_transactions ON journal_transactions.id = ledger_splits.journal_transaction_id").
		Where("ledger_splits.organization_id = ? AND accounts.organization_id = ? AND journal_transactions.organization_id = ?", organizationID, organizationID, organizationID).
		Where("journal_transactions.status = ?", domain.JournalStatusPosted).
		Where("journal_transactions.transaction_date >= ? AND journal_transactions.transaction_date <= ?", from, to).
		Where("accounts.type = ? AND accounts.subtype IN ?", domain.AccountTypeAsset, cashAccountSubtypes()).
		Group("ledger_splits.account_id, accounts.code, accounts.name, journal_transactions.source_module").
		Order("accounts.code ASC, journal_transactions.source_module ASC").
		Scan(&activities).Error; err != nil {
		return nil, err
	}

	rows := make([]CashFlowRow, 0, len(activities))
	for _, activity := range activities {
		rows = append(rows, CashFlowRow{
			AccountID:        activity.AccountID,
			AccountCode:      activity.AccountCode,
			AccountName:      activity.AccountName,
			SourceModule:     activity.SourceModule,
			InflowMinor:      activity.DebitMinor,
			OutflowMinor:     activity.CreditMinor,
			NetCashFlowMinor: activity.DebitMinor - activity.CreditMinor,
		})
	}
	return rows, nil
}

func (s ReportService) cashBalance(ctx context.Context, organizationID string, before *time.Time, through *time.Time) (int64, error) {
	var balance struct {
		DebitMinor  int64
		CreditMinor int64
	}
	query := s.db.WithContext(ctx).
		Table("ledger_splits").
		Select(`COALESCE(SUM(CASE WHEN ledger_splits.base_debit_minor != 0 OR ledger_splits.base_credit_minor != 0 THEN ledger_splits.base_debit_minor ELSE ledger_splits.debit_minor END), 0) AS debit_minor,
			COALESCE(SUM(CASE WHEN ledger_splits.base_debit_minor != 0 OR ledger_splits.base_credit_minor != 0 THEN ledger_splits.base_credit_minor ELSE ledger_splits.credit_minor END), 0) AS credit_minor`).
		Joins("JOIN accounts ON accounts.id = ledger_splits.account_id").
		Joins("JOIN journal_transactions ON journal_transactions.id = ledger_splits.journal_transaction_id").
		Where("ledger_splits.organization_id = ? AND accounts.organization_id = ? AND journal_transactions.organization_id = ?", organizationID, organizationID, organizationID).
		Where("journal_transactions.status = ?", domain.JournalStatusPosted).
		Where("accounts.type = ? AND accounts.subtype IN ?", domain.AccountTypeAsset, cashAccountSubtypes())
	if before != nil {
		query = query.Where("journal_transactions.transaction_date < ?", *before)
	}
	if through != nil {
		query = query.Where("journal_transactions.transaction_date <= ?", *through)
	}
	if err := query.Scan(&balance).Error; err != nil {
		return 0, err
	}
	return balance.DebitMinor - balance.CreditMinor, nil
}

func (s ReportService) accountNormalBalance(ctx context.Context, organizationID string, account domain.Account, from *time.Time, to *time.Time, exclusiveTo bool) (int64, error) {
	var balance struct {
		DebitMinor  int64
		CreditMinor int64
	}
	query := s.db.WithContext(ctx).
		Table("ledger_splits").
		Select(`COALESCE(SUM(CASE WHEN ledger_splits.base_debit_minor != 0 OR ledger_splits.base_credit_minor != 0 THEN ledger_splits.base_debit_minor ELSE ledger_splits.debit_minor END), 0) AS debit_minor,
			COALESCE(SUM(CASE WHEN ledger_splits.base_debit_minor != 0 OR ledger_splits.base_credit_minor != 0 THEN ledger_splits.base_credit_minor ELSE ledger_splits.credit_minor END), 0) AS credit_minor`).
		Joins("JOIN journal_transactions ON journal_transactions.id = ledger_splits.journal_transaction_id").
		Where("ledger_splits.organization_id = ? AND ledger_splits.account_id = ?", organizationID, account.ID).
		Where("journal_transactions.organization_id = ? AND journal_transactions.status = ?", organizationID, domain.JournalStatusPosted)
	if from != nil {
		query = query.Where("journal_transactions.transaction_date >= ?", *from)
	}
	if to != nil {
		if exclusiveTo {
			query = query.Where("journal_transactions.transaction_date < ?", *to)
		} else {
			query = query.Where("journal_transactions.transaction_date <= ?", *to)
		}
	}
	if err := query.Scan(&balance).Error; err != nil {
		return 0, err
	}
	return normalBalanceDelta(account.Type, balance.DebitMinor, balance.CreditMinor), nil
}

func normalBalanceDelta(accountType domain.AccountType, debitMinor int64, creditMinor int64) int64 {
	if accountType == domain.AccountTypeLiability || accountType == domain.AccountTypeEquity || accountType == domain.AccountTypeIncome {
		return creditMinor - debitMinor
	}
	return debitMinor - creditMinor
}

func cashAccountSubtypes() []string {
	return []string{"bank", "cash"}
}

func arAgingRow(invoice domain.Invoice, asOf time.Time, outstandingMinor int64) ARAgingRow {
	daysOverdue := int(asOf.Sub(invoice.DueDate).Hours() / 24)
	if daysOverdue < 0 {
		daysOverdue = 0
	}
	row := ARAgingRow{
		CustomerID:       invoice.CustomerID,
		CustomerName:     invoice.Customer.DisplayName,
		InvoiceID:        invoice.ID,
		InvoiceNumber:    invoice.InvoiceNumber,
		DueDate:          invoice.DueDate,
		DaysOverdue:      daysOverdue,
		OutstandingMinor: outstandingMinor,
	}
	switch {
	case !invoice.DueDate.Before(asOf):
		row.CurrentMinor = outstandingMinor
	case daysOverdue <= 30:
		row.OneToThirtyMinor = outstandingMinor
	case daysOverdue <= 60:
		row.ThirtyOneToSixtyMinor = outstandingMinor
	case daysOverdue <= 90:
		row.SixtyOneToNinetyMinor = outstandingMinor
	default:
		row.OverNinetyMinor = outstandingMinor
	}
	return row
}

func apAgingRow(bill domain.Bill, asOf time.Time, outstandingMinor int64) APAgingRow {
	daysOverdue := int(asOf.Sub(bill.DueDate).Hours() / 24)
	if daysOverdue < 0 {
		daysOverdue = 0
	}
	row := APAgingRow{
		VendorID:         bill.VendorID,
		VendorName:       bill.Vendor.DisplayName,
		BillID:           bill.ID,
		BillNumber:       bill.BillNumber,
		DueDate:          bill.DueDate,
		DaysOverdue:      daysOverdue,
		OutstandingMinor: outstandingMinor,
	}
	switch {
	case !bill.DueDate.Before(asOf):
		row.CurrentMinor = outstandingMinor
	case daysOverdue <= 30:
		row.OneToThirtyMinor = outstandingMinor
	case daysOverdue <= 60:
		row.ThirtyOneToSixtyMinor = outstandingMinor
	case daysOverdue <= 90:
		row.SixtyOneToNinetyMinor = outstandingMinor
	default:
		row.OverNinetyMinor = outstandingMinor
	}
	return row
}

func (s ReportService) addInvoiceTaxRows(ctx context.Context, organizationID string, from time.Time, to time.Time, rows map[string]TaxReportRow) error {
	var invoices []domain.Invoice
	if err := s.db.WithContext(ctx).
		Preload("Lines").
		Where("organization_id = ? AND status IN ? AND issue_date >= ? AND issue_date <= ?", organizationID, []domain.InvoiceStatus{domain.InvoiceStatusPosted, domain.InvoiceStatusPaid}, from, to).
		Find(&invoices).
		Error; err != nil {
		return err
	}

	for _, invoice := range invoices {
		for _, line := range invoice.Lines {
			if line.TaxAmountMinor == 0 {
				continue
			}
			key, name, err := s.taxReportKey(ctx, organizationID, line.TaxRateID, line.TaxGroupID)
			if err != nil {
				return err
			}
			row := rows[key]
			row.Name = name
			row.OutputTaxMinor += line.TaxAmountMinor
			if line.TaxRateID != nil {
				row.TaxRateID = *line.TaxRateID
			}
			if line.TaxGroupID != nil {
				row.TaxGroupID = *line.TaxGroupID
			}
			rows[key] = row
		}
	}
	return nil
}

func (s ReportService) addExpenseTaxRows(ctx context.Context, organizationID string, from time.Time, to time.Time, rows map[string]TaxReportRow) error {
	var expenses []domain.Expense
	if err := s.db.WithContext(ctx).
		Where("organization_id = ? AND status = ? AND expense_date >= ? AND expense_date <= ?", organizationID, domain.ExpenseStatusPosted, from, to).
		Find(&expenses).
		Error; err != nil {
		return err
	}

	for _, expense := range expenses {
		if expense.TaxTotalMinor == 0 {
			continue
		}
		key, name, err := s.taxReportKey(ctx, organizationID, expense.TaxRateID, expense.TaxGroupID)
		if err != nil {
			return err
		}
		row := rows[key]
		row.Name = name
		row.InputTaxMinor += expense.TaxTotalMinor
		if expense.TaxRateID != nil {
			row.TaxRateID = *expense.TaxRateID
		}
		if expense.TaxGroupID != nil {
			row.TaxGroupID = *expense.TaxGroupID
		}
		rows[key] = row
	}
	return nil
}

func (s ReportService) addBillTaxRows(ctx context.Context, organizationID string, from time.Time, to time.Time, rows map[string]TaxReportRow) error {
	var bills []domain.Bill
	if err := s.db.WithContext(ctx).
		Preload("Lines").
		Where("organization_id = ? AND status = ? AND issue_date >= ? AND issue_date <= ?", organizationID, domain.BillStatusPosted, from, to).
		Find(&bills).
		Error; err != nil {
		return err
	}

	for _, bill := range bills {
		for _, line := range bill.Lines {
			if line.TaxAmountMinor == 0 {
				continue
			}
			key, name, err := s.taxReportKey(ctx, organizationID, line.TaxRateID, line.TaxGroupID)
			if err != nil {
				return err
			}
			row := rows[key]
			row.Name = name
			row.InputTaxMinor += line.TaxAmountMinor
			if line.TaxRateID != nil {
				row.TaxRateID = *line.TaxRateID
			}
			if line.TaxGroupID != nil {
				row.TaxGroupID = *line.TaxGroupID
			}
			rows[key] = row
		}
	}
	return nil
}

func (s ReportService) taxReportKey(ctx context.Context, organizationID string, taxRateID *string, taxGroupID *string) (string, string, error) {
	if taxRateID != nil {
		var rate domain.TaxRate
		if err := s.db.WithContext(ctx).Where("organization_id = ? AND id = ?", organizationID, *taxRateID).First(&rate).Error; err != nil {
			return "", "", err
		}
		return "rate:" + rate.ID, rate.Name, nil
	}

	var group domain.TaxGroup
	if err := s.db.WithContext(ctx).Where("organization_id = ? AND id = ?", organizationID, *taxGroupID).First(&group).Error; err != nil {
		return "", "", err
	}
	return "group:" + group.ID, group.Name, nil
}

func (s ReportService) accountActivities(ctx context.Context, organizationID string, from *time.Time, to *time.Time, accountTypes []domain.AccountType) ([]accountActivity, error) {
	var accounts []domain.Account
	if err := s.db.WithContext(ctx).
		Where("organization_id = ? AND type IN ?", organizationID, accountTypes).
		Order("code ASC").
		Find(&accounts).
		Error; err != nil {
		return nil, err
	}

	activities := make([]accountActivity, 0, len(accounts))
	for _, account := range accounts {
		var splits []domain.LedgerSplit
		query := s.db.WithContext(ctx).
			Joins("JOIN journal_transactions ON journal_transactions.id = ledger_splits.journal_transaction_id").
			Where("ledger_splits.organization_id = ? AND ledger_splits.account_id = ?", organizationID, account.ID).
			Where("journal_transactions.status = ?", domain.JournalStatusPosted)
		if from != nil {
			query = query.Where("journal_transactions.transaction_date >= ?", *from)
		}
		if to != nil {
			query = query.Where("journal_transactions.transaction_date <= ?", *to)
		}
		if err := query.Find(&splits).Error; err != nil {
			return nil, err
		}

		activity := accountActivity{
			AccountID:   account.ID,
			AccountCode: account.Code,
			AccountName: account.Name,
			AccountType: account.Type,
		}
		for _, split := range splits {
			activity.DebitMinor += effectiveDebitMinor(split)
			activity.CreditMinor += effectiveCreditMinor(split)
		}
		if activity.DebitMinor != 0 || activity.CreditMinor != 0 {
			activities = append(activities, activity)
		}
	}
	return activities, nil
}

func effectiveDebitMinor(split domain.LedgerSplit) int64 {
	if split.BaseDebitMinor != 0 || split.BaseCreditMinor != 0 {
		return split.BaseDebitMinor
	}
	return split.DebitMinor
}

func effectiveCreditMinor(split domain.LedgerSplit) int64 {
	if split.BaseDebitMinor != 0 || split.BaseCreditMinor != 0 {
		return split.BaseCreditMinor
	}
	return split.CreditMinor
}

func (a accountActivity) toReportRow() ReportRow {
	return ReportRow{
		AccountID:    a.AccountID,
		AccountCode:  a.AccountCode,
		AccountName:  a.AccountName,
		AccountType:  a.AccountType,
		DebitMinor:   a.DebitMinor,
		CreditMinor:  a.CreditMinor,
		BalanceMinor: normalBalanceDelta(a.AccountType, a.DebitMinor, a.CreditMinor),
	}
}
