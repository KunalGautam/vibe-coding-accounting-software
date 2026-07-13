package services

import (
	"context"
	"errors"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

var (
	ErrBillHasNoLines    = errors.New("bill must contain at least one line")
	ErrBillAlreadyPosted = errors.New("bill has already been posted")
	ErrBillAccountScope  = errors.New("bill accounts must belong to the organization")
	ErrBillVendorScope   = errors.New("bill vendor must belong to the organization")
)

type BillService struct {
	db  *gorm.DB
	tax TaxService
}

type CreateBillInput struct {
	OrganizationID       string
	VendorID             string
	BillNumber           string
	IssueDate            time.Time
	DueDate              time.Time
	Currency             string
	TaxInclusive         bool
	AccountsPayableID    string
	DocumentAttachmentID *string
	Lines                []CreateBillLineInput
}

type CreateBillLineInput struct {
	Description      string
	QuantityMillis   int64
	UnitPriceMinor   int64
	ExpenseAccountID string
	TaxRateID        *string
	TaxGroupID       *string
}

func NewBillService(db *gorm.DB, tax TaxService) BillService {
	return BillService{db: db, tax: tax}
}

func (s BillService) List(ctx context.Context, organizationID string) ([]domain.Bill, error) {
	var bills []domain.Bill
	err := s.db.WithContext(ctx).
		Preload("Vendor").
		Preload("Lines").
		Where("organization_id = ?", organizationID).
		Order("issue_date DESC, created_at DESC").
		Find(&bills).
		Error
	return bills, err
}

func (s BillService) Create(ctx context.Context, input CreateBillInput) (domain.Bill, error) {
	if len(input.Lines) == 0 {
		return domain.Bill{}, ErrBillHasNoLines
	}
	currency := input.Currency
	if currency == "" {
		currency = "INR"
	}

	bill := domain.Bill{
		OrganizationID:       input.OrganizationID,
		VendorID:             input.VendorID,
		BillNumber:           input.BillNumber,
		IssueDate:            input.IssueDate,
		DueDate:              input.DueDate,
		Status:               domain.BillStatusDraft,
		Currency:             currency,
		TaxInclusive:         input.TaxInclusive,
		AccountsPayableID:    input.AccountsPayableID,
		DocumentAttachmentID: input.DocumentAttachmentID,
		Lines:                make([]domain.BillLine, 0, len(input.Lines)),
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
				return domain.Bill{}, err
			}
			lineSubtotal = calculation.BaseAmountMinor
			taxAmount = calculation.TaxAmountMinor
			lineTotal = calculation.TotalAmountMinor
		}
		bill.SubtotalMinor += lineSubtotal
		bill.TaxTotalMinor += taxAmount
		bill.TotalMinor += lineTotal
		bill.Lines = append(bill.Lines, domain.BillLine{
			OrganizationID:    input.OrganizationID,
			Description:       lineInput.Description,
			QuantityMillis:    quantityMillis,
			UnitPriceMinor:    lineInput.UnitPriceMinor,
			LineSubtotalMinor: lineSubtotal,
			TaxAmountMinor:    taxAmount,
			LineTotalMinor:    lineTotal,
			ExpenseAccountID:  lineInput.ExpenseAccountID,
			TaxRateID:         lineInput.TaxRateID,
			TaxGroupID:        lineInput.TaxGroupID,
		})
	}

	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := validateBillScope(ctx, tx, input.OrganizationID, bill); err != nil {
			return err
		}
		return tx.Create(&bill).Error
	})
	return bill, err
}

func (s BillService) Post(ctx context.Context, organizationID string, billID string) (domain.Bill, error) {
	var bill domain.Bill
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Preload("Lines").Where("organization_id = ? AND id = ?", organizationID, billID).First(&bill).Error; err != nil {
			return err
		}
		if bill.Status != domain.BillStatusDraft {
			return ErrBillAlreadyPosted
		}

		splits := make([]domain.LedgerSplit, 0, len(bill.Lines)+2)
		for _, line := range bill.Lines {
			splits = append(splits, domain.LedgerSplit{
				OrganizationID: bill.OrganizationID,
				AccountID:      line.ExpenseAccountID,
				DebitMinor:     line.LineSubtotalMinor,
				Currency:       bill.Currency,
			})
			if line.TaxAmountMinor > 0 {
				taxAccountID, err := s.inputTaxAccountID(ctx, tx, bill.OrganizationID, line)
				if err != nil {
					return err
				}
				splits = append(splits, domain.LedgerSplit{
					OrganizationID: bill.OrganizationID,
					AccountID:      taxAccountID,
					DebitMinor:     line.TaxAmountMinor,
					Currency:       bill.Currency,
				})
			}
		}
		splits = append(splits, domain.LedgerSplit{
			OrganizationID: bill.OrganizationID,
			AccountID:      bill.AccountsPayableID,
			CreditMinor:    bill.TotalMinor,
			Currency:       bill.Currency,
		})

		now := time.Now().UTC()
		transaction := domain.JournalTransaction{
			OrganizationID:  bill.OrganizationID,
			TransactionDate: bill.IssueDate,
			Memo:            "Bill " + bill.BillNumber,
			SourceModule:    domain.SourceModuleBill,
			Status:          domain.JournalStatusPosted,
			PostedAt:        &now,
			Splits:          splits,
		}
		if err := transaction.ValidateBalanced(); err != nil {
			return err
		}
		if err := validateSplitAccounts(ctx, tx, bill.OrganizationID, transaction.Splits); err != nil {
			return err
		}
		if err := tx.Create(&transaction).Error; err != nil {
			return err
		}
		if err := tx.Model(&bill).Updates(map[string]any{
			"status":                 domain.BillStatusPosted,
			"journal_transaction_id": transaction.ID,
		}).Error; err != nil {
			return err
		}
		bill.Status = domain.BillStatusPosted
		bill.JournalTransactionID = &transaction.ID
		if err := recordAuditWithTx(ctx, tx, RecordAuditInput{
			OrganizationID: bill.OrganizationID,
			EntityType:     "bill",
			EntityID:       bill.ID,
			Action:         "post",
			After:          bill,
		}); err != nil {
			return err
		}
		return nil
	})
	return bill, err
}

func (s BillService) inputTaxAccountID(ctx context.Context, tx *gorm.DB, organizationID string, line domain.BillLine) (string, error) {
	if line.TaxRateID != nil {
		var rate domain.TaxRate
		if err := tx.WithContext(ctx).Where("organization_id = ? AND id = ?", organizationID, *line.TaxRateID).First(&rate).Error; err != nil {
			return "", err
		}
		if rate.InputAccountID == nil {
			return "", domain.ErrTenantScope
		}
		return *rate.InputAccountID, nil
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
		if component.TaxRate.InputAccountID != nil {
			return *component.TaxRate.InputAccountID, nil
		}
	}
	return "", domain.ErrTenantScope
}

func validateBillScope(ctx context.Context, tx *gorm.DB, organizationID string, bill domain.Bill) error {
	var vendorCount int64
	if err := tx.WithContext(ctx).Model(&domain.Vendor{}).Where("organization_id = ? AND id = ?", organizationID, bill.VendorID).Count(&vendorCount).Error; err != nil {
		return err
	}
	if vendorCount != 1 {
		return ErrBillVendorScope
	}

	accountIDs := []string{bill.AccountsPayableID}
	for _, line := range bill.Lines {
		accountIDs = append(accountIDs, line.ExpenseAccountID)
	}
	var accountCount int64
	if err := tx.WithContext(ctx).Model(&domain.Account{}).Where("organization_id = ? AND id IN ?", organizationID, accountIDs).Count(&accountCount).Error; err != nil {
		return err
	}
	if accountCount != int64(len(uniqueStrings(accountIDs))) {
		return ErrBillAccountScope
	}
	if bill.DocumentAttachmentID != nil {
		var attachmentCount int64
		if err := tx.WithContext(ctx).Model(&domain.Attachment{}).Where("organization_id = ? AND id = ?", organizationID, *bill.DocumentAttachmentID).Count(&attachmentCount).Error; err != nil {
			return err
		}
		if attachmentCount != 1 {
			return domain.ErrTenantScope
		}
	}
	return nil
}
