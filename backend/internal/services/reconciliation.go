package services

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

var (
	ErrBankAccountScope       = errors.New("bank account must belong to the organization")
	ErrBankStatementLineScope = errors.New("bank statement line must belong to the organization")
	ErrLedgerSplitScope       = errors.New("ledger split must belong to the organization and account")
	ErrQIFNoLines             = errors.New("qif import did not contain any bank statement lines")
	ErrQIFParse               = errors.New("invalid qif bank statement")
	ErrOFXNoLines             = errors.New("ofx import did not contain any bank statement lines")
	ErrOFXParse               = errors.New("invalid ofx bank statement")
)

type ReconciliationService struct {
	db *gorm.DB
}

type ImportBankStatementInput struct {
	OrganizationID string
	AccountID      string
	FileName       string
	Format         string
	Lines          []ImportBankStatementLineInput
}

type ImportQIFBankStatementInput struct {
	OrganizationID string
	AccountID      string
	FileName       string
	Content        string
}

type ImportOFXBankStatementInput struct {
	OrganizationID string
	AccountID      string
	FileName       string
	Content        string
}

type ImportBankStatementLineInput struct {
	PostedDate  time.Time
	Description string
	AmountMinor int64
	Reference   string
}

type MatchStatementLineInput struct {
	OrganizationID  string
	StatementLineID string
	LedgerSplitID   string
}

func NewReconciliationService(db *gorm.DB) ReconciliationService {
	return ReconciliationService{db: db}
}

func (s ReconciliationService) ImportBankStatement(ctx context.Context, input ImportBankStatementInput) (domain.BankStatementImport, error) {
	format := input.Format
	if format == "" {
		format = "csv"
	}

	statementImport := domain.BankStatementImport{
		OrganizationID: input.OrganizationID,
		AccountID:      input.AccountID,
		FileName:       input.FileName,
		Format:         format,
		Status:         domain.BankImportStatusCompleted,
		LineCount:      len(input.Lines),
		Lines:          make([]domain.BankStatementLine, 0, len(input.Lines)),
	}
	for _, line := range input.Lines {
		statementImport.Lines = append(statementImport.Lines, domain.BankStatementLine{
			OrganizationID: input.OrganizationID,
			AccountID:      input.AccountID,
			PostedDate:     line.PostedDate,
			Description:    line.Description,
			AmountMinor:    line.AmountMinor,
			Reference:      line.Reference,
		})
	}

	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := validateAccountScope(ctx, tx, input.OrganizationID, input.AccountID); err != nil {
			return err
		}
		return tx.Create(&statementImport).Error
	})
	return statementImport, err
}

func (s ReconciliationService) ImportQIFBankStatement(ctx context.Context, input ImportQIFBankStatementInput) (domain.BankStatementImport, error) {
	lines, err := ParseQIFBankStatement(input.Content)
	if err != nil {
		return domain.BankStatementImport{}, err
	}
	return s.ImportBankStatement(ctx, ImportBankStatementInput{
		OrganizationID: input.OrganizationID,
		AccountID:      input.AccountID,
		FileName:       input.FileName,
		Format:         "qif",
		Lines:          lines,
	})
}

func (s ReconciliationService) ImportOFXBankStatement(ctx context.Context, input ImportOFXBankStatementInput) (domain.BankStatementImport, error) {
	lines, err := ParseOFXBankStatement(input.Content)
	if err != nil {
		return domain.BankStatementImport{}, err
	}
	return s.ImportBankStatement(ctx, ImportBankStatementInput{
		OrganizationID: input.OrganizationID,
		AccountID:      input.AccountID,
		FileName:       input.FileName,
		Format:         "ofx",
		Lines:          lines,
	})
}

func ParseQIFBankStatement(content string) ([]ImportBankStatementLineInput, error) {
	records := strings.Split(strings.ReplaceAll(content, "\r\n", "\n"), "^")
	lines := make([]ImportBankStatementLineInput, 0, len(records))
	for _, record := range records {
		line, ok, err := parseQIFRecord(record)
		if err != nil {
			return nil, err
		}
		if ok {
			lines = append(lines, line)
		}
	}
	if len(lines) == 0 {
		return nil, ErrQIFNoLines
	}
	return lines, nil
}

func ParseOFXBankStatement(content string) ([]ImportBankStatementLineInput, error) {
	records := ofxTransactionRecords(normalizeOFXContent(content))
	lines := make([]ImportBankStatementLineInput, 0, len(records))
	for _, record := range records {
		line, ok, err := parseOFXRecord(record)
		if err != nil {
			return nil, err
		}
		if ok {
			lines = append(lines, line)
		}
	}
	if len(lines) == 0 {
		return nil, ErrOFXNoLines
	}
	return lines, nil
}

func ofxTransactionRecords(content string) []string {
	upperContent := strings.ToUpper(content)
	records := []string{}
	searchFrom := 0
	for {
		start := strings.Index(upperContent[searchFrom:], "<STMTTRN>")
		if start == -1 {
			break
		}
		start += searchFrom
		valueStart := start + len("<STMTTRN>")
		end := strings.Index(upperContent[valueStart:], "</STMTTRN>")
		if end == -1 {
			next := strings.Index(upperContent[valueStart:], "<STMTTRN>")
			if next == -1 {
				records = append(records, content[valueStart:])
				break
			}
			records = append(records, content[valueStart:valueStart+next])
			searchFrom = valueStart + next
			continue
		}
		records = append(records, content[valueStart:valueStart+end])
		searchFrom = valueStart + end + len("</STMTTRN>")
	}
	return records
}

func (s ReconciliationService) ListStatementLines(ctx context.Context, organizationID string, accountID string) ([]domain.BankStatementLine, error) {
	var lines []domain.BankStatementLine
	err := s.db.WithContext(ctx).
		Where("organization_id = ? AND account_id = ?", organizationID, accountID).
		Order("posted_date DESC, created_at DESC").
		Find(&lines).
		Error
	return lines, err
}

func (s ReconciliationService) MatchStatementLine(ctx context.Context, input MatchStatementLineInput) (domain.BankStatementLine, error) {
	var line domain.BankStatementLine
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("organization_id = ? AND id = ?", input.OrganizationID, input.StatementLineID).First(&line).Error; err != nil {
			return err
		}

		var split domain.LedgerSplit
		if err := tx.Where("organization_id = ? AND id = ? AND account_id = ?", input.OrganizationID, input.LedgerSplitID, line.AccountID).First(&split).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return ErrLedgerSplitScope
			}
			return err
		}

		now := time.Now().UTC()
		if err := tx.Model(&line).Updates(map[string]any{
			"matched_split_id": input.LedgerSplitID,
			"matched_at":       now,
		}).Error; err != nil {
			return err
		}
		if err := tx.Model(&split).Updates(map[string]any{
			"cleared":       true,
			"reconciled":    true,
			"reconciled_at": now,
		}).Error; err != nil {
			return err
		}
		line.MatchedSplitID = &input.LedgerSplitID
		line.MatchedAt = &now
		if err := recordAuditWithTx(ctx, tx, RecordAuditInput{
			OrganizationID: line.OrganizationID,
			EntityType:     "bank_statement_line",
			EntityID:       line.ID,
			Action:         "match",
			After:          line,
		}); err != nil {
			return err
		}
		return nil
	})
	return line, err
}

func (s ReconciliationService) MarkSplitReconciled(ctx context.Context, organizationID string, splitID string) (domain.LedgerSplit, error) {
	var split domain.LedgerSplit
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("organization_id = ? AND id = ?", organizationID, splitID).First(&split).Error; err != nil {
			return err
		}
		now := time.Now().UTC()
		if err := tx.Model(&split).Updates(map[string]any{
			"cleared":       true,
			"reconciled":    true,
			"reconciled_at": now,
		}).Error; err != nil {
			return err
		}
		split.Cleared = true
		split.Reconciled = true
		split.ReconciledAt = &now
		if err := recordAuditWithTx(ctx, tx, RecordAuditInput{
			OrganizationID: split.OrganizationID,
			EntityType:     "ledger_split",
			EntityID:       split.ID,
			Action:         "reconcile",
			After:          split,
		}); err != nil {
			return err
		}
		return nil
	})
	return split, err
}

func parseOFXRecord(record string) (ImportBankStatementLineInput, bool, error) {
	record = strings.Split(record, "</STMTTRN>")[0]
	dateValue := ofxTagValue(record, "DTPOSTED")
	amountValue := ofxTagValue(record, "TRNAMT")
	if dateValue == "" && amountValue == "" {
		return ImportBankStatementLineInput{}, false, nil
	}
	if dateValue == "" {
		return ImportBankStatementLineInput{}, false, fmt.Errorf("%w: record missing DTPOSTED", ErrOFXParse)
	}
	if amountValue == "" {
		return ImportBankStatementLineInput{}, false, fmt.Errorf("%w: record missing TRNAMT", ErrOFXParse)
	}
	postedDate, err := parseOFXDate(dateValue)
	if err != nil {
		return ImportBankStatementLineInput{}, false, err
	}
	amountMinor, err := parseOFXAmountMinor(amountValue)
	if err != nil {
		return ImportBankStatementLineInput{}, false, err
	}

	descriptionParts := make([]string, 0, 2)
	if name := ofxTagValue(record, "NAME"); name != "" {
		descriptionParts = append(descriptionParts, name)
	}
	if memo := ofxTagValue(record, "MEMO"); memo != "" {
		descriptionParts = append(descriptionParts, memo)
	}
	return ImportBankStatementLineInput{
		PostedDate:  postedDate,
		Description: strings.Join(descriptionParts, " - "),
		AmountMinor: amountMinor,
		Reference:   ofxTagValue(record, "FITID"),
	}, true, nil
}

func normalizeOFXContent(content string) string {
	return strings.ReplaceAll(content, "\r\n", "\n")
}

func ofxTagValue(record string, tag string) string {
	upperRecord := strings.ToUpper(record)
	upperTag := strings.ToUpper(tag)
	start := strings.Index(upperRecord, "<"+upperTag+">")
	if start == -1 {
		return ""
	}
	valueStart := start + len(upperTag) + 2
	remainder := record[valueStart:]
	upperRemainder := upperRecord[valueStart:]
	if end := strings.Index(upperRemainder, "</"+upperTag+">"); end != -1 {
		return strings.TrimSpace(remainder[:end])
	}
	if end := strings.Index(remainder, "\n"); end != -1 {
		return strings.TrimSpace(remainder[:end])
	}
	if end := strings.Index(remainder, "<"); end != -1 {
		return strings.TrimSpace(remainder[:end])
	}
	return strings.TrimSpace(remainder)
}

func parseOFXDate(value string) (time.Time, error) {
	cleaned := strings.TrimSpace(value)
	if bracket := strings.Index(cleaned, "["); bracket != -1 {
		cleaned = cleaned[:bracket]
	}
	cleaned = strings.TrimSpace(cleaned)
	formats := []string{
		"20060102150405",
		"200601021504",
		"20060102",
	}
	for _, format := range formats {
		if len(cleaned) < len(format) {
			continue
		}
		parsed, err := time.Parse(format, cleaned[:len(format)])
		if err == nil {
			return parsed, nil
		}
	}
	return time.Time{}, fmt.Errorf("%w: invalid DTPOSTED %q", ErrOFXParse, value)
}

func parseOFXAmountMinor(value string) (int64, error) {
	return parseDecimalAmountMinor(value, ErrOFXParse)
}

func parseQIFRecord(record string) (ImportBankStatementLineInput, bool, error) {
	var line ImportBankStatementLineInput
	var descriptionParts []string
	for _, rawField := range strings.Split(record, "\n") {
		field := strings.TrimSpace(rawField)
		if field == "" || strings.HasPrefix(field, "!") {
			continue
		}
		if len(field) < 2 {
			continue
		}
		value := strings.TrimSpace(field[1:])
		switch field[0] {
		case 'D':
			postedDate, err := parseQIFDate(value)
			if err != nil {
				return ImportBankStatementLineInput{}, false, err
			}
			line.PostedDate = postedDate
		case 'T':
			amountMinor, err := parseQIFAmountMinor(value)
			if err != nil {
				return ImportBankStatementLineInput{}, false, err
			}
			line.AmountMinor = amountMinor
		case 'P', 'M', 'L':
			if value != "" {
				descriptionParts = append(descriptionParts, value)
			}
		case 'N':
			line.Reference = value
		}
	}
	if line.PostedDate.IsZero() && line.AmountMinor == 0 && len(descriptionParts) == 0 && line.Reference == "" {
		return ImportBankStatementLineInput{}, false, nil
	}
	if line.PostedDate.IsZero() {
		return ImportBankStatementLineInput{}, false, fmt.Errorf("%w: record missing date", ErrQIFParse)
	}
	line.Description = strings.Join(descriptionParts, " - ")
	return line, true, nil
}

func parseQIFDate(value string) (time.Time, error) {
	cleaned := strings.ReplaceAll(strings.TrimSpace(value), "'", "/")
	formats := []string{
		"2006-01-02",
		"02/01/2006",
		"2/1/2006",
		"01/02/2006",
		"1/2/2006",
		"02/01/06",
		"2/1/06",
		"01/02/06",
		"1/2/06",
	}
	for _, format := range formats {
		parsed, err := time.Parse(format, cleaned)
		if err == nil {
			return parsed, nil
		}
	}
	return time.Time{}, fmt.Errorf("%w: invalid date %q", ErrQIFParse, value)
}

func parseQIFAmountMinor(value string) (int64, error) {
	return parseDecimalAmountMinor(value, ErrQIFParse)
}

func parseDecimalAmountMinor(value string, sentinel error) (int64, error) {
	cleaned := strings.TrimSpace(strings.ReplaceAll(value, ",", ""))
	if cleaned == "" {
		return 0, fmt.Errorf("%w: invalid amount %q", sentinel, value)
	}
	negative := strings.HasPrefix(cleaned, "-")
	if strings.HasPrefix(cleaned, "(") && strings.HasSuffix(cleaned, ")") {
		negative = true
		cleaned = strings.TrimSuffix(strings.TrimPrefix(cleaned, "("), ")")
	}
	cleaned = strings.TrimPrefix(cleaned, "+")
	cleaned = strings.TrimPrefix(cleaned, "-")
	parts := strings.Split(cleaned, ".")
	if len(parts) > 2 || parts[0] == "" {
		return 0, fmt.Errorf("%w: invalid amount %q", sentinel, value)
	}
	major, ok := parseDigits(parts[0])
	if !ok {
		return 0, fmt.Errorf("%w: invalid amount %q", sentinel, value)
	}
	var minor int64
	if len(parts) == 2 {
		cents := parts[1]
		if len(cents) > 2 {
			return 0, fmt.Errorf("%w: invalid amount %q", sentinel, value)
		}
		for len(cents) < 2 {
			cents += "0"
		}
		var centsValue int64
		centsValue, ok = parseDigits(cents)
		if !ok {
			return 0, fmt.Errorf("%w: invalid amount %q", sentinel, value)
		}
		minor = centsValue
	}
	amount := major*100 + minor
	if negative {
		amount = -amount
	}
	return amount, nil
}

func parseDigits(value string) (int64, bool) {
	var result int64
	for _, digit := range value {
		if digit < '0' || digit > '9' {
			return 0, false
		}
		result = result*10 + int64(digit-'0')
	}
	return result, true
}

func validateAccountScope(ctx context.Context, tx *gorm.DB, organizationID string, accountID string) error {
	var count int64
	if err := tx.WithContext(ctx).Model(&domain.Account{}).Where("organization_id = ? AND id = ?", organizationID, accountID).Count(&count).Error; err != nil {
		return err
	}
	if count != 1 {
		return ErrBankAccountScope
	}
	return nil
}
