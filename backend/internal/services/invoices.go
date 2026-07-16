package services

import (
	"context"
	"errors"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

var (
	ErrInvoiceHasNoLines    = errors.New("invoice must contain at least one line")
	ErrInvoiceAlreadyPosted = errors.New("invoice has already been posted")
	ErrInvoiceAccountScope  = errors.New("invoice accounts must belong to the organization")
	ErrInvoiceCustomerScope = errors.New("invoice customer must belong to the organization")
)

type InvoiceService struct {
	db  *gorm.DB
	tax TaxService
}

type CreateInvoiceInput struct {
	OrganizationID       string
	CustomerID           string
	InvoiceNumber        string
	IssueDate            time.Time
	DueDate              time.Time
	Currency             string
	TaxInclusive         bool
	AccountsReceivableID string
	PDFAttachmentID      *string
	Lines                []CreateInvoiceLineInput
}

type UpdateInvoiceInput struct {
	CreateInvoiceInput
	InvoiceID string
}

type CreateInvoiceLineInput struct {
	Description     string
	QuantityMillis  int64
	UnitPriceMinor  int64
	IncomeAccountID string
	TaxRateID       *string
	TaxGroupID      *string
}

func NewInvoiceService(db *gorm.DB, tax TaxService) InvoiceService {
	return InvoiceService{db: db, tax: tax}
}

func (s InvoiceService) List(ctx context.Context, organizationID string) ([]domain.Invoice, error) {
	var invoices []domain.Invoice
	err := s.db.WithContext(ctx).
		Preload("Customer").
		Preload("Lines").
		Where("organization_id = ?", organizationID).
		Order("issue_date DESC, created_at DESC").
		Find(&invoices).
		Error
	return invoices, err
}

func (s InvoiceService) Create(ctx context.Context, input CreateInvoiceInput) (domain.Invoice, error) {
	invoice, err := s.buildDraft(ctx, input)
	if err != nil {
		return domain.Invoice{}, err
	}

	err = s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := validateInvoiceScope(ctx, tx, input.OrganizationID, invoice); err != nil {
			return err
		}
		return tx.Create(&invoice).Error
	})
	return invoice, err
}

func (s InvoiceService) Update(ctx context.Context, input UpdateInvoiceInput) (domain.Invoice, error) {
	next, err := s.buildDraft(ctx, input.CreateInvoiceInput)
	if err != nil {
		return domain.Invoice{}, err
	}

	var invoice domain.Invoice
	err = s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Preload("Lines").
			Where("organization_id = ? AND id = ?", input.OrganizationID, input.InvoiceID).
			First(&invoice).
			Error; err != nil {
			return err
		}
		if invoice.Status != domain.InvoiceStatusDraft {
			return ErrInvoiceAlreadyPosted
		}
		if err := validateInvoiceScope(ctx, tx, input.OrganizationID, next); err != nil {
			return err
		}
		if err := tx.Model(&invoice).Updates(map[string]any{
			"customer_id":            next.CustomerID,
			"invoice_number":         next.InvoiceNumber,
			"issue_date":             next.IssueDate,
			"due_date":               next.DueDate,
			"currency":               next.Currency,
			"tax_inclusive":          next.TaxInclusive,
			"subtotal_minor":         next.SubtotalMinor,
			"tax_total_minor":        next.TaxTotalMinor,
			"total_minor":            next.TotalMinor,
			"accounts_receivable_id": next.AccountsReceivableID,
			"pdf_attachment_id":      next.PDFAttachmentID,
		}).Error; err != nil {
			return err
		}
		if err := tx.Where("invoice_id = ?", invoice.ID).Delete(&domain.InvoiceLine{}).Error; err != nil {
			return err
		}
		for index := range next.Lines {
			next.Lines[index].InvoiceID = invoice.ID
		}
		if err := tx.Create(&next.Lines).Error; err != nil {
			return err
		}
		next.ID = invoice.ID
		next.CreatedAt = invoice.CreatedAt
		next.UpdatedAt = time.Now().UTC()
		next.Status = invoice.Status
		if err := recordAuditWithTx(ctx, tx, RecordAuditInput{
			OrganizationID: invoice.OrganizationID,
			EntityType:     "invoice",
			EntityID:       invoice.ID,
			Action:         "update",
			Before:         invoice,
			After:          next,
		}); err != nil {
			return err
		}
		invoice = next
		return nil
	})
	return invoice, err
}

func (s InvoiceService) buildDraft(ctx context.Context, input CreateInvoiceInput) (domain.Invoice, error) {
	if len(input.Lines) == 0 {
		return domain.Invoice{}, ErrInvoiceHasNoLines
	}

	currency := input.Currency
	if currency == "" {
		currency = "INR"
	}

	invoice := domain.Invoice{
		OrganizationID:       input.OrganizationID,
		CustomerID:           input.CustomerID,
		InvoiceNumber:        input.InvoiceNumber,
		IssueDate:            input.IssueDate,
		DueDate:              input.DueDate,
		Status:               domain.InvoiceStatusDraft,
		Currency:             currency,
		TaxInclusive:         input.TaxInclusive,
		AccountsReceivableID: input.AccountsReceivableID,
		PDFAttachmentID:      input.PDFAttachmentID,
		Lines:                make([]domain.InvoiceLine, 0, len(input.Lines)),
	}

	for _, lineInput := range input.Lines {
		quantityMillis := lineInput.QuantityMillis
		if quantityMillis == 0 {
			quantityMillis = 1000
		}

		lineSubtotal := roundDiv(quantityMillis*lineInput.UnitPriceMinor, 1000)
		taxAmount := int64(0)
		lineTotal := lineSubtotal
		if lineInput.TaxRateID != nil || lineInput.TaxGroupID != nil {
			calculation, err := s.tax.Calculate(ctx, CalculateTaxInput{
				OrganizationID:  input.OrganizationID,
				BaseAmountMinor: lineSubtotal,
				TaxInclusive:    input.TaxInclusive,
				TaxRateID:       lineInput.TaxRateID,
				TaxGroupID:      lineInput.TaxGroupID,
			})
			if err != nil {
				return domain.Invoice{}, err
			}
			lineSubtotal = calculation.BaseAmountMinor
			taxAmount = calculation.TaxAmountMinor
			lineTotal = calculation.TotalAmountMinor
		}

		invoice.SubtotalMinor += lineSubtotal
		invoice.TaxTotalMinor += taxAmount
		invoice.TotalMinor += lineTotal
		invoice.Lines = append(invoice.Lines, domain.InvoiceLine{
			OrganizationID:    input.OrganizationID,
			Description:       lineInput.Description,
			QuantityMillis:    quantityMillis,
			UnitPriceMinor:    lineInput.UnitPriceMinor,
			LineSubtotalMinor: lineSubtotal,
			TaxAmountMinor:    taxAmount,
			LineTotalMinor:    lineTotal,
			IncomeAccountID:   lineInput.IncomeAccountID,
			TaxRateID:         lineInput.TaxRateID,
			TaxGroupID:        lineInput.TaxGroupID,
		})
	}
	return invoice, nil
}

func (s InvoiceService) Post(ctx context.Context, organizationID string, invoiceID string) (domain.Invoice, error) {
	var invoice domain.Invoice
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Preload("Lines").
			Where("organization_id = ? AND id = ?", organizationID, invoiceID).
			First(&invoice).
			Error; err != nil {
			return err
		}
		if invoice.Status != domain.InvoiceStatusDraft {
			return ErrInvoiceAlreadyPosted
		}

		splits := []domain.LedgerSplit{
			{
				OrganizationID: invoice.OrganizationID,
				AccountID:      invoice.AccountsReceivableID,
				DebitMinor:     invoice.TotalMinor,
				Currency:       invoice.Currency,
			},
		}

		for _, line := range invoice.Lines {
			splits = append(splits, domain.LedgerSplit{
				OrganizationID: invoice.OrganizationID,
				AccountID:      line.IncomeAccountID,
				CreditMinor:    line.LineSubtotalMinor,
				Currency:       invoice.Currency,
			})
			if line.TaxAmountMinor > 0 {
				taxAccountID, err := s.outputTaxAccountID(ctx, tx, invoice.OrganizationID, line)
				if err != nil {
					return err
				}
				splits = append(splits, domain.LedgerSplit{
					OrganizationID: invoice.OrganizationID,
					AccountID:      taxAccountID,
					CreditMinor:    line.TaxAmountMinor,
					Currency:       invoice.Currency,
				})
			}
		}

		now := time.Now().UTC()
		transaction := domain.JournalTransaction{
			OrganizationID:  invoice.OrganizationID,
			TransactionDate: invoice.IssueDate,
			Memo:            "Invoice " + invoice.InvoiceNumber,
			SourceModule:    domain.SourceModuleInvoice,
			Status:          domain.JournalStatusPosted,
			PostedAt:        &now,
			Splits:          splits,
		}
		if err := transaction.ValidateBalanced(); err != nil {
			return err
		}
		if err := validateSplitAccounts(ctx, tx, invoice.OrganizationID, transaction.Splits); err != nil {
			return err
		}
		if err := tx.Create(&transaction).Error; err != nil {
			return err
		}

		if err := tx.Model(&invoice).
			Updates(map[string]any{
				"status":                 domain.InvoiceStatusPosted,
				"journal_transaction_id": transaction.ID,
			}).
			Error; err != nil {
			return err
		}
		invoice.Status = domain.InvoiceStatusPosted
		invoice.JournalTransactionID = &transaction.ID
		if err := recordAuditWithTx(ctx, tx, RecordAuditInput{
			OrganizationID: invoice.OrganizationID,
			EntityType:     "invoice",
			EntityID:       invoice.ID,
			Action:         "post",
			After:          invoice,
		}); err != nil {
			return err
		}
		return nil
	})
	return invoice, err
}

func (s InvoiceService) outputTaxAccountID(ctx context.Context, tx *gorm.DB, organizationID string, line domain.InvoiceLine) (string, error) {
	if line.TaxRateID != nil {
		var rate domain.TaxRate
		if err := tx.WithContext(ctx).
			Where("organization_id = ? AND id = ?", organizationID, *line.TaxRateID).
			First(&rate).
			Error; err != nil {
			return "", err
		}
		if rate.OutputAccountID == nil {
			return "", domain.ErrTenantScope
		}
		return *rate.OutputAccountID, nil
	}

	var group domain.TaxGroup
	if err := tx.WithContext(ctx).
		Preload("Components.TaxRate").
		Where("organization_id = ? AND id = ?", organizationID, *line.TaxGroupID).
		First(&group).
		Error; err != nil {
		return "", err
	}
	for _, component := range group.Components {
		if component.TaxRate.OutputAccountID != nil {
			return *component.TaxRate.OutputAccountID, nil
		}
	}
	return "", domain.ErrTenantScope
}

func validateInvoiceScope(ctx context.Context, tx *gorm.DB, organizationID string, invoice domain.Invoice) error {
	var customerCount int64
	if err := tx.WithContext(ctx).
		Model(&domain.Customer{}).
		Where("organization_id = ? AND id = ?", organizationID, invoice.CustomerID).
		Count(&customerCount).
		Error; err != nil {
		return err
	}
	if customerCount != 1 {
		return ErrInvoiceCustomerScope
	}

	accountIDs := []string{invoice.AccountsReceivableID}
	for _, line := range invoice.Lines {
		accountIDs = append(accountIDs, line.IncomeAccountID)
	}

	var accountCount int64
	if err := tx.WithContext(ctx).
		Model(&domain.Account{}).
		Where("organization_id = ? AND id IN ?", organizationID, accountIDs).
		Count(&accountCount).
		Error; err != nil {
		return err
	}
	if accountCount != int64(len(uniqueStrings(accountIDs))) {
		return ErrInvoiceAccountScope
	}
	if invoice.PDFAttachmentID != nil {
		var attachmentCount int64
		if err := tx.WithContext(ctx).
			Model(&domain.Attachment{}).
			Where("organization_id = ? AND id = ?", organizationID, *invoice.PDFAttachmentID).
			Count(&attachmentCount).
			Error; err != nil {
			return err
		}
		if attachmentCount != 1 {
			return domain.ErrTenantScope
		}
	}
	return nil
}

func uniqueStrings(values []string) []string {
	seen := make(map[string]struct{}, len(values))
	unique := make([]string, 0, len(values))
	for _, value := range values {
		if _, ok := seen[value]; ok {
			continue
		}
		seen[value] = struct{}{}
		unique = append(unique, value)
	}
	return unique
}
