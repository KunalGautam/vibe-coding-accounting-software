package services

import (
	"context"
	"errors"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

var (
	ErrEstimateHasNoLines         = errors.New("estimate must contain at least one line")
	ErrCreditNoteHasNoLines       = errors.New("credit note must contain at least one line")
	ErrCreditNoteAlreadyPosted    = errors.New("credit note has already been posted")
	ErrCommercialAccountScope     = errors.New("commercial document accounts must belong to the organization")
	ErrCommercialCustomerScope    = errors.New("commercial document customer must belong to the organization")
	ErrPurchaseOrderHasNoLines    = errors.New("purchase order must contain at least one line")
	ErrPurchaseOrderVendorScope   = errors.New("purchase order vendor must belong to the organization")
	ErrEstimateCannotConvert      = errors.New("estimate cannot be converted from its current status")
	ErrPurchaseOrderCannotConvert = errors.New("purchase order cannot be converted from its current status")
	ErrEstimateStatusInvalid      = errors.New("estimate status transition is not allowed")
	ErrPurchaseOrderStatusInvalid = errors.New("purchase order status transition is not allowed")
)

type CommercialDocumentService struct {
	db  *gorm.DB
	tax TaxService
}

type CreateEstimateInput struct {
	OrganizationID string
	CustomerID     string
	EstimateNumber string
	IssueDate      time.Time
	ExpiryDate     time.Time
	Currency       string
	TaxInclusive   bool
	Lines          []CreateEstimateLineInput
}

type CreateEstimateLineInput struct {
	Description     string
	QuantityMillis  int64
	UnitPriceMinor  int64
	IncomeAccountID string
	TaxRateID       *string
	TaxGroupID      *string
}

type CreateCreditNoteInput struct {
	OrganizationID       string
	CustomerID           string
	InvoiceID            *string
	CreditNoteNumber     string
	IssueDate            time.Time
	Currency             string
	TaxInclusive         bool
	AccountsReceivableID string
	Lines                []CreateCreditNoteLineInput
}

type CreateCreditNoteLineInput struct {
	Description     string
	QuantityMillis  int64
	UnitPriceMinor  int64
	IncomeAccountID string
	TaxRateID       *string
	TaxGroupID      *string
}

type CreatePurchaseOrderInput struct {
	OrganizationID      string
	VendorID            string
	PurchaseOrderNumber string
	IssueDate           time.Time
	ExpectedDate        *time.Time
	Currency            string
	TaxInclusive        bool
	Lines               []CreatePurchaseOrderLineInput
}

type CreatePurchaseOrderLineInput struct {
	Description      string
	QuantityMillis   int64
	UnitPriceMinor   int64
	ExpenseAccountID string
	TaxRateID        *string
	TaxGroupID       *string
}

type ConvertEstimateToInvoiceInput struct {
	OrganizationID       string
	EstimateID           string
	InvoiceNumber        string
	IssueDate            time.Time
	DueDate              time.Time
	AccountsReceivableID string
	PDFAttachmentID      *string
}

type ConvertPurchaseOrderToBillInput struct {
	OrganizationID       string
	PurchaseOrderID      string
	BillNumber           string
	IssueDate            time.Time
	DueDate              time.Time
	AccountsPayableID    string
	DocumentAttachmentID *string
}

type UpdateEstimateStatusInput struct {
	OrganizationID string
	EstimateID     string
	Status         domain.EstimateStatus
}

type UpdatePurchaseOrderStatusInput struct {
	OrganizationID  string
	PurchaseOrderID string
	Status          domain.PurchaseOrderStatus
}

func NewCommercialDocumentService(db *gorm.DB, tax TaxService) CommercialDocumentService {
	return CommercialDocumentService{db: db, tax: tax}
}

func (s CommercialDocumentService) ListEstimates(ctx context.Context, organizationID string) ([]domain.Estimate, error) {
	var estimates []domain.Estimate
	err := s.db.WithContext(ctx).
		Preload("Customer").
		Preload("Lines").
		Where("organization_id = ?", organizationID).
		Order("issue_date DESC, created_at DESC").
		Find(&estimates).
		Error
	return estimates, err
}

func (s CommercialDocumentService) CreateEstimate(ctx context.Context, input CreateEstimateInput) (domain.Estimate, error) {
	if len(input.Lines) == 0 {
		return domain.Estimate{}, ErrEstimateHasNoLines
	}
	estimate := domain.Estimate{
		OrganizationID: input.OrganizationID,
		CustomerID:     input.CustomerID,
		EstimateNumber: input.EstimateNumber,
		IssueDate:      input.IssueDate,
		ExpiryDate:     input.ExpiryDate,
		Status:         domain.EstimateStatusDraft,
		Currency:       defaultCurrency(input.Currency),
		TaxInclusive:   input.TaxInclusive,
		Lines:          make([]domain.EstimateLine, 0, len(input.Lines)),
	}
	for _, lineInput := range input.Lines {
		line, err := s.estimateLine(ctx, input.OrganizationID, input.TaxInclusive, lineInput)
		if err != nil {
			return domain.Estimate{}, err
		}
		estimate.SubtotalMinor += line.LineSubtotalMinor
		estimate.TaxTotalMinor += line.TaxAmountMinor
		estimate.TotalMinor += line.LineTotalMinor
		estimate.Lines = append(estimate.Lines, line)
	}
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := validateCustomerAndAccounts(ctx, tx, input.OrganizationID, input.CustomerID, estimateAccountIDs(estimate)); err != nil {
			return err
		}
		return tx.Create(&estimate).Error
	})
	return estimate, err
}

func (s CommercialDocumentService) ConvertEstimateToInvoice(ctx context.Context, input ConvertEstimateToInvoiceInput) (domain.Invoice, error) {
	var invoice domain.Invoice
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var estimate domain.Estimate
		if err := tx.Preload("Lines").Where("organization_id = ? AND id = ?", input.OrganizationID, input.EstimateID).First(&estimate).Error; err != nil {
			return err
		}
		if estimate.Status == domain.EstimateStatusConverted || estimate.Status == domain.EstimateStatusVoid {
			return ErrEstimateCannotConvert
		}

		invoice = domain.Invoice{
			OrganizationID:       estimate.OrganizationID,
			CustomerID:           estimate.CustomerID,
			InvoiceNumber:        input.InvoiceNumber,
			IssueDate:            input.IssueDate,
			DueDate:              input.DueDate,
			Status:               domain.InvoiceStatusDraft,
			Currency:             estimate.Currency,
			TaxInclusive:         estimate.TaxInclusive,
			SubtotalMinor:        estimate.SubtotalMinor,
			TaxTotalMinor:        estimate.TaxTotalMinor,
			TotalMinor:           estimate.TotalMinor,
			AccountsReceivableID: input.AccountsReceivableID,
			PDFAttachmentID:      input.PDFAttachmentID,
			Lines:                make([]domain.InvoiceLine, 0, len(estimate.Lines)),
		}
		for _, line := range estimate.Lines {
			invoice.Lines = append(invoice.Lines, domain.InvoiceLine{
				OrganizationID:    estimate.OrganizationID,
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
		if err := validateInvoiceScope(ctx, tx, input.OrganizationID, invoice); err != nil {
			return err
		}
		if err := tx.Create(&invoice).Error; err != nil {
			return err
		}
		if err := tx.Model(&estimate).Update("status", domain.EstimateStatusConverted).Error; err != nil {
			return err
		}
		return recordAuditWithTx(ctx, tx, RecordAuditInput{
			OrganizationID: input.OrganizationID,
			EntityType:     "estimate",
			EntityID:       estimate.ID,
			Action:         "convert_to_invoice",
			After:          invoice,
		})
	})
	return invoice, err
}

func (s CommercialDocumentService) UpdateEstimateStatus(ctx context.Context, input UpdateEstimateStatusInput) (domain.Estimate, error) {
	if !isAllowedEstimateStatus(input.Status) {
		return domain.Estimate{}, ErrEstimateStatusInvalid
	}
	var estimate domain.Estimate
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Preload("Lines").Where("organization_id = ? AND id = ?", input.OrganizationID, input.EstimateID).First(&estimate).Error; err != nil {
			return err
		}
		if estimate.Status == domain.EstimateStatusConverted {
			return ErrEstimateStatusInvalid
		}
		if err := tx.Model(&estimate).Update("status", input.Status).Error; err != nil {
			return err
		}
		estimate.Status = input.Status
		return recordAuditWithTx(ctx, tx, RecordAuditInput{
			OrganizationID: input.OrganizationID,
			EntityType:     "estimate",
			EntityID:       estimate.ID,
			Action:         "update_status",
			After:          estimate,
		})
	})
	return estimate, err
}

func (s CommercialDocumentService) ListCreditNotes(ctx context.Context, organizationID string) ([]domain.CreditNote, error) {
	var creditNotes []domain.CreditNote
	err := s.db.WithContext(ctx).
		Preload("Customer").
		Preload("Lines").
		Where("organization_id = ?", organizationID).
		Order("issue_date DESC, created_at DESC").
		Find(&creditNotes).
		Error
	return creditNotes, err
}

func (s CommercialDocumentService) CreateCreditNote(ctx context.Context, input CreateCreditNoteInput) (domain.CreditNote, error) {
	if len(input.Lines) == 0 {
		return domain.CreditNote{}, ErrCreditNoteHasNoLines
	}
	creditNote := domain.CreditNote{
		OrganizationID:       input.OrganizationID,
		CustomerID:           input.CustomerID,
		InvoiceID:            input.InvoiceID,
		CreditNoteNumber:     input.CreditNoteNumber,
		IssueDate:            input.IssueDate,
		Status:               domain.CreditNoteStatusDraft,
		Currency:             defaultCurrency(input.Currency),
		TaxInclusive:         input.TaxInclusive,
		AccountsReceivableID: input.AccountsReceivableID,
		Lines:                make([]domain.CreditNoteLine, 0, len(input.Lines)),
	}
	for _, lineInput := range input.Lines {
		line, err := s.creditNoteLine(ctx, input.OrganizationID, input.TaxInclusive, lineInput)
		if err != nil {
			return domain.CreditNote{}, err
		}
		creditNote.SubtotalMinor += line.LineSubtotalMinor
		creditNote.TaxTotalMinor += line.TaxAmountMinor
		creditNote.TotalMinor += line.LineTotalMinor
		creditNote.Lines = append(creditNote.Lines, line)
	}
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		accountIDs := append([]string{creditNote.AccountsReceivableID}, creditNoteAccountIDs(creditNote)...)
		if err := validateCustomerAndAccounts(ctx, tx, input.OrganizationID, input.CustomerID, accountIDs); err != nil {
			return err
		}
		if input.InvoiceID != nil {
			var count int64
			if err := tx.Model(&domain.Invoice{}).Where("organization_id = ? AND id = ?", input.OrganizationID, *input.InvoiceID).Count(&count).Error; err != nil {
				return err
			}
			if count != 1 {
				return domain.ErrTenantScope
			}
		}
		return tx.Create(&creditNote).Error
	})
	return creditNote, err
}

func (s CommercialDocumentService) PostCreditNote(ctx context.Context, organizationID string, creditNoteID string) (domain.CreditNote, error) {
	var creditNote domain.CreditNote
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Preload("Lines").Where("organization_id = ? AND id = ?", organizationID, creditNoteID).First(&creditNote).Error; err != nil {
			return err
		}
		if creditNote.Status != domain.CreditNoteStatusDraft {
			return ErrCreditNoteAlreadyPosted
		}

		splits := make([]domain.LedgerSplit, 0, len(creditNote.Lines)+2)
		for _, line := range creditNote.Lines {
			splits = append(splits, domain.LedgerSplit{
				OrganizationID: creditNote.OrganizationID,
				AccountID:      line.IncomeAccountID,
				DebitMinor:     line.LineSubtotalMinor,
				Currency:       creditNote.Currency,
			})
			if line.TaxAmountMinor > 0 {
				taxAccountID, err := creditNoteOutputTaxAccountID(ctx, tx, creditNote.OrganizationID, line)
				if err != nil {
					return err
				}
				splits = append(splits, domain.LedgerSplit{
					OrganizationID: creditNote.OrganizationID,
					AccountID:      taxAccountID,
					DebitMinor:     line.TaxAmountMinor,
					Currency:       creditNote.Currency,
				})
			}
		}
		splits = append(splits, domain.LedgerSplit{
			OrganizationID: creditNote.OrganizationID,
			AccountID:      creditNote.AccountsReceivableID,
			CreditMinor:    creditNote.TotalMinor,
			Currency:       creditNote.Currency,
		})

		now := time.Now().UTC()
		transaction := domain.JournalTransaction{
			OrganizationID:  creditNote.OrganizationID,
			TransactionDate: creditNote.IssueDate,
			Memo:            "Credit note " + creditNote.CreditNoteNumber,
			SourceModule:    domain.SourceModuleCredit,
			Status:          domain.JournalStatusPosted,
			PostedAt:        &now,
			Splits:          splits,
		}
		if err := transaction.ValidateBalanced(); err != nil {
			return err
		}
		if err := validateSplitAccounts(ctx, tx, creditNote.OrganizationID, transaction.Splits); err != nil {
			return err
		}
		if err := tx.Create(&transaction).Error; err != nil {
			return err
		}
		if err := tx.Model(&creditNote).Updates(map[string]any{
			"status":                 domain.CreditNoteStatusPosted,
			"journal_transaction_id": transaction.ID,
		}).Error; err != nil {
			return err
		}
		creditNote.Status = domain.CreditNoteStatusPosted
		creditNote.JournalTransactionID = &transaction.ID
		return recordAuditWithTx(ctx, tx, RecordAuditInput{
			OrganizationID: creditNote.OrganizationID,
			EntityType:     "credit_note",
			EntityID:       creditNote.ID,
			Action:         "post",
			After:          creditNote,
		})
	})
	return creditNote, err
}

func (s CommercialDocumentService) ListPurchaseOrders(ctx context.Context, organizationID string) ([]domain.PurchaseOrder, error) {
	var purchaseOrders []domain.PurchaseOrder
	err := s.db.WithContext(ctx).
		Preload("Vendor").
		Preload("Lines").
		Where("organization_id = ?", organizationID).
		Order("issue_date DESC, created_at DESC").
		Find(&purchaseOrders).
		Error
	return purchaseOrders, err
}

func (s CommercialDocumentService) CreatePurchaseOrder(ctx context.Context, input CreatePurchaseOrderInput) (domain.PurchaseOrder, error) {
	if len(input.Lines) == 0 {
		return domain.PurchaseOrder{}, ErrPurchaseOrderHasNoLines
	}
	purchaseOrder := domain.PurchaseOrder{
		OrganizationID:      input.OrganizationID,
		VendorID:            input.VendorID,
		PurchaseOrderNumber: input.PurchaseOrderNumber,
		IssueDate:           input.IssueDate,
		ExpectedDate:        input.ExpectedDate,
		Status:              domain.PurchaseOrderStatusDraft,
		Currency:            defaultCurrency(input.Currency),
		TaxInclusive:        input.TaxInclusive,
		Lines:               make([]domain.PurchaseOrderLine, 0, len(input.Lines)),
	}
	for _, lineInput := range input.Lines {
		line, err := s.purchaseOrderLine(ctx, input.OrganizationID, input.TaxInclusive, lineInput)
		if err != nil {
			return domain.PurchaseOrder{}, err
		}
		purchaseOrder.SubtotalMinor += line.LineSubtotalMinor
		purchaseOrder.TaxTotalMinor += line.TaxAmountMinor
		purchaseOrder.TotalMinor += line.LineTotalMinor
		purchaseOrder.Lines = append(purchaseOrder.Lines, line)
	}
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := validateVendorAndAccounts(ctx, tx, input.OrganizationID, input.VendorID, purchaseOrderAccountIDs(purchaseOrder)); err != nil {
			return err
		}
		return tx.Create(&purchaseOrder).Error
	})
	return purchaseOrder, err
}

func (s CommercialDocumentService) ConvertPurchaseOrderToBill(ctx context.Context, input ConvertPurchaseOrderToBillInput) (domain.Bill, error) {
	var bill domain.Bill
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var purchaseOrder domain.PurchaseOrder
		if err := tx.Preload("Lines").Where("organization_id = ? AND id = ?", input.OrganizationID, input.PurchaseOrderID).First(&purchaseOrder).Error; err != nil {
			return err
		}
		if purchaseOrder.Status == domain.PurchaseOrderStatusConverted || purchaseOrder.Status == domain.PurchaseOrderStatusVoid {
			return ErrPurchaseOrderCannotConvert
		}

		bill = domain.Bill{
			OrganizationID:       purchaseOrder.OrganizationID,
			VendorID:             purchaseOrder.VendorID,
			BillNumber:           input.BillNumber,
			IssueDate:            input.IssueDate,
			DueDate:              input.DueDate,
			Status:               domain.BillStatusDraft,
			Currency:             purchaseOrder.Currency,
			TaxInclusive:         purchaseOrder.TaxInclusive,
			SubtotalMinor:        purchaseOrder.SubtotalMinor,
			TaxTotalMinor:        purchaseOrder.TaxTotalMinor,
			TotalMinor:           purchaseOrder.TotalMinor,
			AccountsPayableID:    input.AccountsPayableID,
			DocumentAttachmentID: input.DocumentAttachmentID,
			Lines:                make([]domain.BillLine, 0, len(purchaseOrder.Lines)),
		}
		for _, line := range purchaseOrder.Lines {
			bill.Lines = append(bill.Lines, domain.BillLine{
				OrganizationID:    purchaseOrder.OrganizationID,
				Description:       line.Description,
				QuantityMillis:    line.QuantityMillis,
				UnitPriceMinor:    line.UnitPriceMinor,
				LineSubtotalMinor: line.LineSubtotalMinor,
				TaxAmountMinor:    line.TaxAmountMinor,
				LineTotalMinor:    line.LineTotalMinor,
				ExpenseAccountID:  line.ExpenseAccountID,
				TaxRateID:         line.TaxRateID,
				TaxGroupID:        line.TaxGroupID,
			})
		}
		if err := validateBillScope(ctx, tx, input.OrganizationID, bill); err != nil {
			return err
		}
		if err := tx.Create(&bill).Error; err != nil {
			return err
		}
		if err := tx.Model(&purchaseOrder).Update("status", domain.PurchaseOrderStatusConverted).Error; err != nil {
			return err
		}
		return recordAuditWithTx(ctx, tx, RecordAuditInput{
			OrganizationID: input.OrganizationID,
			EntityType:     "purchase_order",
			EntityID:       purchaseOrder.ID,
			Action:         "convert_to_bill",
			After:          bill,
		})
	})
	return bill, err
}

func (s CommercialDocumentService) UpdatePurchaseOrderStatus(ctx context.Context, input UpdatePurchaseOrderStatusInput) (domain.PurchaseOrder, error) {
	if !isAllowedPurchaseOrderStatus(input.Status) {
		return domain.PurchaseOrder{}, ErrPurchaseOrderStatusInvalid
	}
	var purchaseOrder domain.PurchaseOrder
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Preload("Lines").Where("organization_id = ? AND id = ?", input.OrganizationID, input.PurchaseOrderID).First(&purchaseOrder).Error; err != nil {
			return err
		}
		if purchaseOrder.Status == domain.PurchaseOrderStatusConverted {
			return ErrPurchaseOrderStatusInvalid
		}
		if err := tx.Model(&purchaseOrder).Update("status", input.Status).Error; err != nil {
			return err
		}
		purchaseOrder.Status = input.Status
		return recordAuditWithTx(ctx, tx, RecordAuditInput{
			OrganizationID: input.OrganizationID,
			EntityType:     "purchase_order",
			EntityID:       purchaseOrder.ID,
			Action:         "update_status",
			After:          purchaseOrder,
		})
	})
	return purchaseOrder, err
}

func isAllowedEstimateStatus(status domain.EstimateStatus) bool {
	return status == domain.EstimateStatusDraft ||
		status == domain.EstimateStatusSent ||
		status == domain.EstimateStatusAccepted ||
		status == domain.EstimateStatusVoid
}

func isAllowedPurchaseOrderStatus(status domain.PurchaseOrderStatus) bool {
	return status == domain.PurchaseOrderStatusDraft ||
		status == domain.PurchaseOrderStatusSent ||
		status == domain.PurchaseOrderStatusApproved ||
		status == domain.PurchaseOrderStatusVoid
}

func (s CommercialDocumentService) estimateLine(ctx context.Context, organizationID string, taxInclusive bool, input CreateEstimateLineInput) (domain.EstimateLine, error) {
	subtotal, taxAmount, total, err := s.lineAmounts(ctx, organizationID, taxInclusive, input.QuantityMillis, input.UnitPriceMinor, input.TaxRateID, input.TaxGroupID)
	if err != nil {
		return domain.EstimateLine{}, err
	}
	return domain.EstimateLine{OrganizationID: organizationID, Description: input.Description, QuantityMillis: defaultQuantity(input.QuantityMillis), UnitPriceMinor: input.UnitPriceMinor, LineSubtotalMinor: subtotal, TaxAmountMinor: taxAmount, LineTotalMinor: total, IncomeAccountID: input.IncomeAccountID, TaxRateID: input.TaxRateID, TaxGroupID: input.TaxGroupID}, nil
}

func (s CommercialDocumentService) creditNoteLine(ctx context.Context, organizationID string, taxInclusive bool, input CreateCreditNoteLineInput) (domain.CreditNoteLine, error) {
	subtotal, taxAmount, total, err := s.lineAmounts(ctx, organizationID, taxInclusive, input.QuantityMillis, input.UnitPriceMinor, input.TaxRateID, input.TaxGroupID)
	if err != nil {
		return domain.CreditNoteLine{}, err
	}
	return domain.CreditNoteLine{OrganizationID: organizationID, Description: input.Description, QuantityMillis: defaultQuantity(input.QuantityMillis), UnitPriceMinor: input.UnitPriceMinor, LineSubtotalMinor: subtotal, TaxAmountMinor: taxAmount, LineTotalMinor: total, IncomeAccountID: input.IncomeAccountID, TaxRateID: input.TaxRateID, TaxGroupID: input.TaxGroupID}, nil
}

func (s CommercialDocumentService) purchaseOrderLine(ctx context.Context, organizationID string, taxInclusive bool, input CreatePurchaseOrderLineInput) (domain.PurchaseOrderLine, error) {
	subtotal, taxAmount, total, err := s.lineAmounts(ctx, organizationID, taxInclusive, input.QuantityMillis, input.UnitPriceMinor, input.TaxRateID, input.TaxGroupID)
	if err != nil {
		return domain.PurchaseOrderLine{}, err
	}
	return domain.PurchaseOrderLine{OrganizationID: organizationID, Description: input.Description, QuantityMillis: defaultQuantity(input.QuantityMillis), UnitPriceMinor: input.UnitPriceMinor, LineSubtotalMinor: subtotal, TaxAmountMinor: taxAmount, LineTotalMinor: total, ExpenseAccountID: input.ExpenseAccountID, TaxRateID: input.TaxRateID, TaxGroupID: input.TaxGroupID}, nil
}

func (s CommercialDocumentService) lineAmounts(ctx context.Context, organizationID string, taxInclusive bool, quantityMillis int64, unitPriceMinor int64, taxRateID *string, taxGroupID *string) (int64, int64, int64, error) {
	quantity := defaultQuantity(quantityMillis)
	subtotal := roundDiv(quantity*unitPriceMinor, 1000)
	if taxRateID == nil && taxGroupID == nil {
		return subtotal, 0, subtotal, nil
	}
	calculation, err := s.tax.Calculate(ctx, CalculateTaxInput{
		OrganizationID:  organizationID,
		BaseAmountMinor: subtotal,
		TaxInclusive:    taxInclusive,
		TaxRateID:       taxRateID,
		TaxGroupID:      taxGroupID,
	})
	if err != nil {
		return 0, 0, 0, err
	}
	return calculation.BaseAmountMinor, calculation.TaxAmountMinor, calculation.TotalAmountMinor, nil
}

func defaultCurrency(currency string) string {
	if currency == "" {
		return "INR"
	}
	return currency
}

func defaultQuantity(quantityMillis int64) int64 {
	if quantityMillis == 0 {
		return 1000
	}
	return quantityMillis
}

func validateCustomerAndAccounts(ctx context.Context, tx *gorm.DB, organizationID string, customerID string, accountIDs []string) error {
	var customerCount int64
	if err := tx.WithContext(ctx).Model(&domain.Customer{}).Where("organization_id = ? AND id = ?", organizationID, customerID).Count(&customerCount).Error; err != nil {
		return err
	}
	if customerCount != 1 {
		return ErrCommercialCustomerScope
	}
	return validateDocumentAccounts(ctx, tx, organizationID, accountIDs)
}

func validateVendorAndAccounts(ctx context.Context, tx *gorm.DB, organizationID string, vendorID string, accountIDs []string) error {
	var vendorCount int64
	if err := tx.WithContext(ctx).Model(&domain.Vendor{}).Where("organization_id = ? AND id = ?", organizationID, vendorID).Count(&vendorCount).Error; err != nil {
		return err
	}
	if vendorCount != 1 {
		return ErrPurchaseOrderVendorScope
	}
	return validateDocumentAccounts(ctx, tx, organizationID, accountIDs)
}

func validateDocumentAccounts(ctx context.Context, tx *gorm.DB, organizationID string, accountIDs []string) error {
	var count int64
	uniqueIDs := uniqueStrings(accountIDs)
	if err := tx.WithContext(ctx).Model(&domain.Account{}).Where("organization_id = ? AND id IN ?", organizationID, uniqueIDs).Count(&count).Error; err != nil {
		return err
	}
	if count != int64(len(uniqueIDs)) {
		return ErrCommercialAccountScope
	}
	return nil
}

func estimateAccountIDs(estimate domain.Estimate) []string {
	accountIDs := make([]string, 0, len(estimate.Lines))
	for _, line := range estimate.Lines {
		accountIDs = append(accountIDs, line.IncomeAccountID)
	}
	return accountIDs
}

func creditNoteAccountIDs(creditNote domain.CreditNote) []string {
	accountIDs := make([]string, 0, len(creditNote.Lines))
	for _, line := range creditNote.Lines {
		accountIDs = append(accountIDs, line.IncomeAccountID)
	}
	return accountIDs
}

func purchaseOrderAccountIDs(purchaseOrder domain.PurchaseOrder) []string {
	accountIDs := make([]string, 0, len(purchaseOrder.Lines))
	for _, line := range purchaseOrder.Lines {
		accountIDs = append(accountIDs, line.ExpenseAccountID)
	}
	return accountIDs
}

func creditNoteOutputTaxAccountID(ctx context.Context, tx *gorm.DB, organizationID string, line domain.CreditNoteLine) (string, error) {
	if line.TaxRateID != nil {
		var rate domain.TaxRate
		if err := tx.WithContext(ctx).Where("organization_id = ? AND id = ?", organizationID, *line.TaxRateID).First(&rate).Error; err != nil {
			return "", err
		}
		if rate.OutputAccountID == nil {
			return "", domain.ErrTenantScope
		}
		return *rate.OutputAccountID, nil
	}
	var group domain.TaxGroup
	if err := tx.WithContext(ctx).Preload("Components.TaxRate").Where("organization_id = ? AND id = ?", organizationID, *line.TaxGroupID).First(&group).Error; err != nil {
		return "", err
	}
	for _, component := range group.Components {
		if component.TaxRate.OutputAccountID != nil {
			return *component.TaxRate.OutputAccountID, nil
		}
	}
	return "", domain.ErrTenantScope
}
