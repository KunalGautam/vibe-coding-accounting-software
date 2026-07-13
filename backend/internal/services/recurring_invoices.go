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
	ErrRecurringInvoiceHasNoLines           = errors.New("recurring invoice template must contain at least one line")
	ErrRecurringInvoiceFrequencyUnsupported = errors.New("recurring invoice frequency is not supported")
)

type RecurringInvoiceService struct {
	db  *gorm.DB
	tax TaxService
}

type CreateRecurringInvoiceTemplateInput struct {
	OrganizationID       string
	CustomerID           string
	Name                 string
	InvoiceNumberPrefix  string
	StartDate            time.Time
	NextRunDate          time.Time
	Frequency            domain.RecurrenceFrequency
	DueDays              int
	Currency             string
	TaxInclusive         bool
	AccountsReceivableID string
	Lines                []CreateRecurringInvoiceLineInput
}

type CreateRecurringInvoiceLineInput struct {
	Description     string
	QuantityMillis  int64
	UnitPriceMinor  int64
	IncomeAccountID string
	TaxRateID       *string
	TaxGroupID      *string
}

type GenerateDueRecurringInvoicesResult struct {
	GeneratedInvoices []domain.Invoice `json:"generated_invoices"`
	GeneratedCount    int              `json:"generated_count"`
}

func NewRecurringInvoiceService(db *gorm.DB, tax TaxService) RecurringInvoiceService {
	return RecurringInvoiceService{db: db, tax: tax}
}

func (s RecurringInvoiceService) List(ctx context.Context, organizationID string) ([]domain.RecurringInvoiceTemplate, error) {
	var templates []domain.RecurringInvoiceTemplate
	err := s.db.WithContext(ctx).
		Preload("Customer").
		Preload("Lines").
		Where("organization_id = ?", organizationID).
		Order("next_run_date ASC, name ASC").
		Find(&templates).
		Error
	return templates, err
}

func (s RecurringInvoiceService) Create(ctx context.Context, input CreateRecurringInvoiceTemplateInput) (domain.RecurringInvoiceTemplate, error) {
	if len(input.Lines) == 0 {
		return domain.RecurringInvoiceTemplate{}, ErrRecurringInvoiceHasNoLines
	}
	if !isSupportedRecurrenceFrequency(input.Frequency) {
		return domain.RecurringInvoiceTemplate{}, ErrRecurringInvoiceFrequencyUnsupported
	}
	dueDays := input.DueDays
	if dueDays == 0 {
		dueDays = 30
	}
	nextRunDate := input.NextRunDate
	if nextRunDate.IsZero() {
		nextRunDate = input.StartDate
	}

	template := domain.RecurringInvoiceTemplate{
		OrganizationID:       input.OrganizationID,
		CustomerID:           input.CustomerID,
		Name:                 input.Name,
		InvoiceNumberPrefix:  input.InvoiceNumberPrefix,
		StartDate:            input.StartDate,
		NextRunDate:          nextRunDate,
		Frequency:            input.Frequency,
		DueDays:              dueDays,
		Currency:             defaultCurrency(input.Currency),
		TaxInclusive:         input.TaxInclusive,
		AccountsReceivableID: input.AccountsReceivableID,
		IsActive:             true,
		Lines:                make([]domain.RecurringInvoiceLine, 0, len(input.Lines)),
	}
	for _, lineInput := range input.Lines {
		line, err := s.templateLine(ctx, input.OrganizationID, input.TaxInclusive, lineInput)
		if err != nil {
			return domain.RecurringInvoiceTemplate{}, err
		}
		template.SubtotalMinor += line.LineSubtotalMinor
		template.TaxTotalMinor += line.TaxAmountMinor
		template.TotalMinor += line.LineTotalMinor
		template.Lines = append(template.Lines, line)
	}

	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		invoiceLike := domain.Invoice{
			OrganizationID:       template.OrganizationID,
			CustomerID:           template.CustomerID,
			AccountsReceivableID: template.AccountsReceivableID,
			Lines:                make([]domain.InvoiceLine, 0, len(template.Lines)),
		}
		for _, line := range template.Lines {
			invoiceLike.Lines = append(invoiceLike.Lines, domain.InvoiceLine{OrganizationID: template.OrganizationID, IncomeAccountID: line.IncomeAccountID})
		}
		if err := validateInvoiceScope(ctx, tx, input.OrganizationID, invoiceLike); err != nil {
			return err
		}
		return tx.Create(&template).Error
	})
	return template, err
}

func (s RecurringInvoiceService) GenerateDue(ctx context.Context, organizationID string, asOf time.Time) (GenerateDueRecurringInvoicesResult, error) {
	if asOf.IsZero() {
		asOf = time.Now().UTC()
	}
	result := GenerateDueRecurringInvoicesResult{}
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var templates []domain.RecurringInvoiceTemplate
		if err := tx.Preload("Lines").
			Where("organization_id = ? AND is_active = ? AND next_run_date <= ?", organizationID, true, asOf).
			Order("next_run_date ASC, name ASC").
			Find(&templates).Error; err != nil {
			return err
		}
		now := time.Now().UTC()
		for _, template := range templates {
			invoice := invoiceFromRecurringTemplate(template)
			if err := validateInvoiceScope(ctx, tx, organizationID, invoice); err != nil {
				return err
			}
			if err := tx.Create(&invoice).Error; err != nil {
				return err
			}
			nextRunDate, err := advanceRecurringDate(template.NextRunDate, template.Frequency)
			if err != nil {
				return err
			}
			if err := tx.Model(&template).Updates(map[string]any{
				"next_run_date":     nextRunDate,
				"last_generated_at": now,
			}).Error; err != nil {
				return err
			}
			result.GeneratedInvoices = append(result.GeneratedInvoices, invoice)
		}
		return nil
	})
	result.GeneratedCount = len(result.GeneratedInvoices)
	return result, err
}

func (s RecurringInvoiceService) templateLine(ctx context.Context, organizationID string, taxInclusive bool, input CreateRecurringInvoiceLineInput) (domain.RecurringInvoiceLine, error) {
	quantityMillis := input.QuantityMillis
	if quantityMillis == 0 {
		quantityMillis = 1000
	}
	lineSubtotal := roundDiv(quantityMillis*input.UnitPriceMinor, 1000)
	taxAmount := int64(0)
	lineTotal := lineSubtotal
	if input.TaxRateID != nil || input.TaxGroupID != nil {
		calculation, err := s.tax.Calculate(ctx, CalculateTaxInput{
			OrganizationID:  organizationID,
			BaseAmountMinor: lineSubtotal,
			TaxInclusive:    taxInclusive,
			TaxRateID:       input.TaxRateID,
			TaxGroupID:      input.TaxGroupID,
		})
		if err != nil {
			return domain.RecurringInvoiceLine{}, err
		}
		lineSubtotal = calculation.BaseAmountMinor
		taxAmount = calculation.TaxAmountMinor
		lineTotal = calculation.TotalAmountMinor
	}
	return domain.RecurringInvoiceLine{
		OrganizationID:    organizationID,
		Description:       input.Description,
		QuantityMillis:    quantityMillis,
		UnitPriceMinor:    input.UnitPriceMinor,
		LineSubtotalMinor: lineSubtotal,
		TaxAmountMinor:    taxAmount,
		LineTotalMinor:    lineTotal,
		IncomeAccountID:   input.IncomeAccountID,
		TaxRateID:         input.TaxRateID,
		TaxGroupID:        input.TaxGroupID,
	}, nil
}

func invoiceFromRecurringTemplate(template domain.RecurringInvoiceTemplate) domain.Invoice {
	invoice := domain.Invoice{
		OrganizationID:       template.OrganizationID,
		CustomerID:           template.CustomerID,
		InvoiceNumber:        fmt.Sprintf("%s-%s", template.InvoiceNumberPrefix, template.NextRunDate.Format("20060102")),
		IssueDate:            template.NextRunDate,
		DueDate:              template.NextRunDate.AddDate(0, 0, template.DueDays),
		Status:               domain.InvoiceStatusDraft,
		Currency:             template.Currency,
		TaxInclusive:         template.TaxInclusive,
		SubtotalMinor:        template.SubtotalMinor,
		TaxTotalMinor:        template.TaxTotalMinor,
		TotalMinor:           template.TotalMinor,
		AccountsReceivableID: template.AccountsReceivableID,
		Lines:                make([]domain.InvoiceLine, 0, len(template.Lines)),
	}
	for _, line := range template.Lines {
		invoice.Lines = append(invoice.Lines, domain.InvoiceLine{
			OrganizationID:    template.OrganizationID,
			Description:       line.Description,
			QuantityMillis:    line.QuantityMillis,
			UnitPriceMinor:    line.UnitPriceMinor,
			LineSubtotalMinor: line.LineSubtotalMinor,
			TaxAmountMinor:    line.TaxAmountMinor,
			LineTotalMinor:    line.LineTotalMinor,
			IncomeAccountID:   line.IncomeAccountID,
			TaxRateID:         line.TaxRateID,
			TaxGroupID:        line.TaxGroupID,
		})
	}
	return invoice
}

func advanceRecurringDate(date time.Time, frequency domain.RecurrenceFrequency) (time.Time, error) {
	switch frequency {
	case domain.RecurrenceFrequencyWeekly:
		return date.AddDate(0, 0, 7), nil
	case domain.RecurrenceFrequencyMonthly:
		return date.AddDate(0, 1, 0), nil
	case domain.RecurrenceFrequencyYearly:
		return date.AddDate(1, 0, 0), nil
	default:
		return time.Time{}, ErrRecurringInvoiceFrequencyUnsupported
	}
}

func isSupportedRecurrenceFrequency(frequency domain.RecurrenceFrequency) bool {
	return frequency == domain.RecurrenceFrequencyWeekly ||
		frequency == domain.RecurrenceFrequencyMonthly ||
		frequency == domain.RecurrenceFrequencyYearly
}
