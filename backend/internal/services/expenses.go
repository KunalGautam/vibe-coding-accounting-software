package services

import (
	"context"
	"errors"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

var (
	ErrExpenseAlreadyPosted = errors.New("expense has already been posted")
	ErrExpenseAccountScope  = errors.New("expense accounts must belong to the organization")
	ErrExpenseVendorScope   = errors.New("expense vendor must belong to the organization")
)

type ExpenseService struct {
	db  *gorm.DB
	tax TaxService
}

type CreateExpenseInput struct {
	OrganizationID      string
	VendorID            *string
	ExpenseNumber       string
	ExpenseDate         time.Time
	Currency            string
	TaxInclusive        bool
	AmountMinor         int64
	ExpenseAccountID    string
	PaymentAccountID    string
	ReceiptAttachmentID *string
	TaxRateID           *string
	TaxGroupID          *string
	Reimbursable        bool
}

func NewExpenseService(db *gorm.DB, tax TaxService) ExpenseService {
	return ExpenseService{db: db, tax: tax}
}

func (s ExpenseService) List(ctx context.Context, organizationID string) ([]domain.Expense, error) {
	var expenses []domain.Expense
	err := s.db.WithContext(ctx).
		Preload("Vendor").
		Where("organization_id = ?", organizationID).
		Order("expense_date DESC, created_at DESC").
		Find(&expenses).
		Error
	return expenses, err
}

func (s ExpenseService) Create(ctx context.Context, input CreateExpenseInput) (domain.Expense, error) {
	currency := input.Currency
	if currency == "" {
		currency = "INR"
	}

	subtotal := input.AmountMinor
	taxAmount := int64(0)
	total := input.AmountMinor
	if input.TaxRateID != nil || input.TaxGroupID != nil {
		calculation, err := s.tax.Calculate(ctx, CalculateTaxInput{
			OrganizationID:  input.OrganizationID,
			BaseAmountMinor: input.AmountMinor,
			TaxInclusive:    input.TaxInclusive,
			TaxRateID:       input.TaxRateID,
			TaxGroupID:      input.TaxGroupID,
		})
		if err != nil {
			return domain.Expense{}, err
		}
		subtotal = calculation.BaseAmountMinor
		taxAmount = calculation.TaxAmountMinor
		total = calculation.TotalAmountMinor
	}

	expense := domain.Expense{
		OrganizationID:      input.OrganizationID,
		VendorID:            input.VendorID,
		ExpenseNumber:       input.ExpenseNumber,
		ExpenseDate:         input.ExpenseDate,
		Status:              domain.ExpenseStatusDraft,
		Currency:            currency,
		TaxInclusive:        input.TaxInclusive,
		SubtotalMinor:       subtotal,
		TaxTotalMinor:       taxAmount,
		TotalMinor:          total,
		ExpenseAccountID:    input.ExpenseAccountID,
		PaymentAccountID:    input.PaymentAccountID,
		ReceiptAttachmentID: input.ReceiptAttachmentID,
		TaxRateID:           input.TaxRateID,
		TaxGroupID:          input.TaxGroupID,
		Reimbursable:        input.Reimbursable,
	}

	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := validateExpenseScope(ctx, tx, input.OrganizationID, expense); err != nil {
			return err
		}
		return tx.Create(&expense).Error
	})
	return expense, err
}

func (s ExpenseService) Post(ctx context.Context, organizationID string, expenseID string) (domain.Expense, error) {
	var expense domain.Expense
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("organization_id = ? AND id = ?", organizationID, expenseID).First(&expense).Error; err != nil {
			return err
		}
		if expense.Status != domain.ExpenseStatusDraft {
			return ErrExpenseAlreadyPosted
		}

		splits := []domain.LedgerSplit{
			{
				OrganizationID: expense.OrganizationID,
				AccountID:      expense.ExpenseAccountID,
				DebitMinor:     expense.SubtotalMinor,
				Currency:       expense.Currency,
			},
			{
				OrganizationID: expense.OrganizationID,
				AccountID:      expense.PaymentAccountID,
				CreditMinor:    expense.TotalMinor,
				Currency:       expense.Currency,
			},
		}
		if expense.TaxTotalMinor > 0 {
			taxAccountID, err := s.inputTaxAccountID(ctx, tx, expense.OrganizationID, expense)
			if err != nil {
				return err
			}
			splits = append(splits, domain.LedgerSplit{
				OrganizationID: expense.OrganizationID,
				AccountID:      taxAccountID,
				DebitMinor:     expense.TaxTotalMinor,
				Currency:       expense.Currency,
			})
		}

		now := time.Now().UTC()
		transaction := domain.JournalTransaction{
			OrganizationID:  expense.OrganizationID,
			TransactionDate: expense.ExpenseDate,
			Memo:            "Expense " + expense.ExpenseNumber,
			SourceModule:    domain.SourceModuleExpense,
			Status:          domain.JournalStatusPosted,
			PostedAt:        &now,
			Splits:          splits,
		}
		if err := transaction.ValidateBalanced(); err != nil {
			return err
		}
		if err := validateSplitAccounts(ctx, tx, expense.OrganizationID, transaction.Splits); err != nil {
			return err
		}
		if err := tx.Create(&transaction).Error; err != nil {
			return err
		}
		if err := tx.Model(&expense).
			Updates(map[string]any{
				"status":                 domain.ExpenseStatusPosted,
				"journal_transaction_id": transaction.ID,
			}).
			Error; err != nil {
			return err
		}
		expense.Status = domain.ExpenseStatusPosted
		expense.JournalTransactionID = &transaction.ID
		if err := recordAuditWithTx(ctx, tx, RecordAuditInput{
			OrganizationID: expense.OrganizationID,
			EntityType:     "expense",
			EntityID:       expense.ID,
			Action:         "post",
			After:          expense,
		}); err != nil {
			return err
		}
		return nil
	})
	return expense, err
}

func (s ExpenseService) inputTaxAccountID(ctx context.Context, tx *gorm.DB, organizationID string, expense domain.Expense) (string, error) {
	if expense.TaxRateID != nil {
		var rate domain.TaxRate
		if err := tx.WithContext(ctx).Where("organization_id = ? AND id = ?", organizationID, *expense.TaxRateID).First(&rate).Error; err != nil {
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
		Where("organization_id = ? AND id = ?", organizationID, *expense.TaxGroupID).
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

func validateExpenseScope(ctx context.Context, tx *gorm.DB, organizationID string, expense domain.Expense) error {
	if expense.VendorID != nil {
		var vendorCount int64
		if err := tx.WithContext(ctx).Model(&domain.Vendor{}).Where("organization_id = ? AND id = ?", organizationID, *expense.VendorID).Count(&vendorCount).Error; err != nil {
			return err
		}
		if vendorCount != 1 {
			return ErrExpenseVendorScope
		}
	}

	accountIDs := []string{expense.ExpenseAccountID, expense.PaymentAccountID}
	var accountCount int64
	if err := tx.WithContext(ctx).Model(&domain.Account{}).Where("organization_id = ? AND id IN ?", organizationID, accountIDs).Count(&accountCount).Error; err != nil {
		return err
	}
	if accountCount != int64(len(uniqueStrings(accountIDs))) {
		return ErrExpenseAccountScope
	}

	if expense.ReceiptAttachmentID != nil {
		var attachmentCount int64
		if err := tx.WithContext(ctx).Model(&domain.Attachment{}).Where("organization_id = ? AND id = ?", organizationID, *expense.ReceiptAttachmentID).Count(&attachmentCount).Error; err != nil {
			return err
		}
		if attachmentCount != 1 {
			return domain.ErrTenantScope
		}
	}
	return nil
}
