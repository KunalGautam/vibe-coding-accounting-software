package services

import (
	"context"
	"errors"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

var (
	ErrPaymentAmountRequired = errors.New("payment amount must be greater than zero")
	ErrPaymentDocumentStatus = errors.New("payment document must be posted or paid")
	ErrPaymentAccountScope   = errors.New("payment account must belong to the organization")
)

type PaymentService struct {
	db *gorm.DB
}

type RecordCustomerPaymentInput struct {
	OrganizationID   string
	InvoiceID        string
	PaymentNumber    string
	PaymentDate      time.Time
	PaymentMethod    string
	Reference        string
	Currency         string
	AmountMinor      int64
	PaymentAccountID string
}

type RecordVendorPaymentInput struct {
	OrganizationID   string
	BillID           string
	PaymentNumber    string
	PaymentDate      time.Time
	PaymentMethod    string
	Reference        string
	Currency         string
	AmountMinor      int64
	PaymentAccountID string
}

func NewPaymentService(db *gorm.DB) PaymentService {
	return PaymentService{db: db}
}

func (s PaymentService) ListCustomerPayments(ctx context.Context, organizationID string, invoiceID string) ([]domain.CustomerPayment, error) {
	var payments []domain.CustomerPayment
	err := s.db.WithContext(ctx).
		Where("organization_id = ? AND invoice_id = ?", organizationID, invoiceID).
		Order("payment_date DESC, created_at DESC").
		Find(&payments).
		Error
	return payments, err
}

func (s PaymentService) ListVendorPayments(ctx context.Context, organizationID string, billID string) ([]domain.VendorPayment, error) {
	var payments []domain.VendorPayment
	err := s.db.WithContext(ctx).
		Where("organization_id = ? AND bill_id = ?", organizationID, billID).
		Order("payment_date DESC, created_at DESC").
		Find(&payments).
		Error
	return payments, err
}

func (s PaymentService) RecordCustomerPayment(ctx context.Context, input RecordCustomerPaymentInput) (domain.CustomerPayment, error) {
	if input.AmountMinor <= 0 {
		return domain.CustomerPayment{}, ErrPaymentAmountRequired
	}
	currency := input.Currency
	if currency == "" {
		currency = "INR"
	}

	var payment domain.CustomerPayment
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var invoice domain.Invoice
		if err := tx.Where("organization_id = ? AND id = ?", input.OrganizationID, input.InvoiceID).First(&invoice).Error; err != nil {
			return err
		}
		if invoice.Status != domain.InvoiceStatusPosted && invoice.Status != domain.InvoiceStatusPaid {
			return ErrPaymentDocumentStatus
		}
		if err := validatePaymentAccount(ctx, tx, input.OrganizationID, input.PaymentAccountID); err != nil {
			return err
		}

		now := time.Now().UTC()
		transaction := domain.JournalTransaction{
			OrganizationID:  input.OrganizationID,
			TransactionDate: input.PaymentDate,
			Memo:            "Customer payment " + input.PaymentNumber + " for invoice " + invoice.InvoiceNumber,
			SourceModule:    domain.SourceModulePayment,
			Status:          domain.JournalStatusPosted,
			PostedAt:        &now,
			Splits: []domain.LedgerSplit{
				{
					OrganizationID: input.OrganizationID,
					AccountID:      input.PaymentAccountID,
					DebitMinor:     input.AmountMinor,
					Currency:       currency,
				},
				{
					OrganizationID: input.OrganizationID,
					AccountID:      invoice.AccountsReceivableID,
					CreditMinor:    input.AmountMinor,
					Currency:       currency,
				},
			},
		}
		if err := transaction.ValidateBalanced(); err != nil {
			return err
		}
		if err := validateSplitAccounts(ctx, tx, input.OrganizationID, transaction.Splits); err != nil {
			return err
		}
		if err := tx.Create(&transaction).Error; err != nil {
			return err
		}

		payment = domain.CustomerPayment{
			OrganizationID:       input.OrganizationID,
			InvoiceID:            invoice.ID,
			PaymentNumber:        input.PaymentNumber,
			PaymentDate:          input.PaymentDate,
			PaymentMethod:        input.PaymentMethod,
			Reference:            input.Reference,
			Currency:             currency,
			AmountMinor:          input.AmountMinor,
			PaymentAccountID:     input.PaymentAccountID,
			JournalTransactionID: transaction.ID,
		}
		if err := tx.Create(&payment).Error; err != nil {
			return err
		}
		if err := s.refreshInvoicePaymentStatus(ctx, tx, invoice); err != nil {
			return err
		}
		return recordAuditWithTx(ctx, tx, RecordAuditInput{
			OrganizationID: input.OrganizationID,
			EntityType:     "customer_payment",
			EntityID:       payment.ID,
			Action:         "record",
			After:          payment,
		})
	})
	return payment, err
}

func (s PaymentService) RecordVendorPayment(ctx context.Context, input RecordVendorPaymentInput) (domain.VendorPayment, error) {
	if input.AmountMinor <= 0 {
		return domain.VendorPayment{}, ErrPaymentAmountRequired
	}
	currency := input.Currency
	if currency == "" {
		currency = "INR"
	}

	var payment domain.VendorPayment
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var bill domain.Bill
		if err := tx.Where("organization_id = ? AND id = ?", input.OrganizationID, input.BillID).First(&bill).Error; err != nil {
			return err
		}
		if bill.Status != domain.BillStatusPosted && bill.Status != domain.BillStatusPaid {
			return ErrPaymentDocumentStatus
		}
		if err := validatePaymentAccount(ctx, tx, input.OrganizationID, input.PaymentAccountID); err != nil {
			return err
		}

		now := time.Now().UTC()
		transaction := domain.JournalTransaction{
			OrganizationID:  input.OrganizationID,
			TransactionDate: input.PaymentDate,
			Memo:            "Vendor payment " + input.PaymentNumber + " for bill " + bill.BillNumber,
			SourceModule:    domain.SourceModulePayment,
			Status:          domain.JournalStatusPosted,
			PostedAt:        &now,
			Splits: []domain.LedgerSplit{
				{
					OrganizationID: input.OrganizationID,
					AccountID:      bill.AccountsPayableID,
					DebitMinor:     input.AmountMinor,
					Currency:       currency,
				},
				{
					OrganizationID: input.OrganizationID,
					AccountID:      input.PaymentAccountID,
					CreditMinor:    input.AmountMinor,
					Currency:       currency,
				},
			},
		}
		if err := transaction.ValidateBalanced(); err != nil {
			return err
		}
		if err := validateSplitAccounts(ctx, tx, input.OrganizationID, transaction.Splits); err != nil {
			return err
		}
		if err := tx.Create(&transaction).Error; err != nil {
			return err
		}

		payment = domain.VendorPayment{
			OrganizationID:       input.OrganizationID,
			BillID:               bill.ID,
			PaymentNumber:        input.PaymentNumber,
			PaymentDate:          input.PaymentDate,
			PaymentMethod:        input.PaymentMethod,
			Reference:            input.Reference,
			Currency:             currency,
			AmountMinor:          input.AmountMinor,
			PaymentAccountID:     input.PaymentAccountID,
			JournalTransactionID: transaction.ID,
		}
		if err := tx.Create(&payment).Error; err != nil {
			return err
		}
		if err := s.refreshBillPaymentStatus(ctx, tx, bill); err != nil {
			return err
		}
		return recordAuditWithTx(ctx, tx, RecordAuditInput{
			OrganizationID: input.OrganizationID,
			EntityType:     "vendor_payment",
			EntityID:       payment.ID,
			Action:         "record",
			After:          payment,
		})
	})
	return payment, err
}

func (s PaymentService) refreshInvoicePaymentStatus(ctx context.Context, tx *gorm.DB, invoice domain.Invoice) error {
	paid, err := sumCustomerPayments(ctx, tx, invoice.OrganizationID, invoice.ID, nil)
	if err != nil {
		return err
	}
	status := domain.InvoiceStatusPosted
	if paid >= invoice.TotalMinor {
		status = domain.InvoiceStatusPaid
	}
	return tx.WithContext(ctx).Model(&domain.Invoice{}).
		Where("organization_id = ? AND id = ?", invoice.OrganizationID, invoice.ID).
		Update("status", status).
		Error
}

func (s PaymentService) refreshBillPaymentStatus(ctx context.Context, tx *gorm.DB, bill domain.Bill) error {
	paid, err := sumVendorPayments(ctx, tx, bill.OrganizationID, bill.ID, nil)
	if err != nil {
		return err
	}
	status := domain.BillStatusPosted
	if paid >= bill.TotalMinor {
		status = domain.BillStatusPaid
	}
	return tx.WithContext(ctx).Model(&domain.Bill{}).
		Where("organization_id = ? AND id = ?", bill.OrganizationID, bill.ID).
		Update("status", status).
		Error
}

func validatePaymentAccount(ctx context.Context, tx *gorm.DB, organizationID string, accountID string) error {
	var count int64
	if err := tx.WithContext(ctx).
		Model(&domain.Account{}).
		Where("organization_id = ? AND id = ?", organizationID, accountID).
		Count(&count).
		Error; err != nil {
		return err
	}
	if count != 1 {
		return ErrPaymentAccountScope
	}
	return nil
}

func sumCustomerPayments(ctx context.Context, tx *gorm.DB, organizationID string, invoiceID string, through *time.Time) (int64, error) {
	var total struct {
		AmountMinor int64
	}
	query := tx.WithContext(ctx).
		Model(&domain.CustomerPayment{}).
		Select("COALESCE(SUM(amount_minor), 0) AS amount_minor").
		Where("organization_id = ? AND invoice_id = ?", organizationID, invoiceID)
	if through != nil {
		query = query.Where("payment_date <= ?", *through)
	}
	if err := query.Scan(&total).Error; err != nil {
		return 0, err
	}
	return total.AmountMinor, nil
}

func sumVendorPayments(ctx context.Context, tx *gorm.DB, organizationID string, billID string, through *time.Time) (int64, error) {
	var total struct {
		AmountMinor int64
	}
	query := tx.WithContext(ctx).
		Model(&domain.VendorPayment{}).
		Select("COALESCE(SUM(amount_minor), 0) AS amount_minor").
		Where("organization_id = ? AND bill_id = ?", organizationID, billID)
	if through != nil {
		query = query.Where("payment_date <= ?", *through)
	}
	if err := query.Scan(&total).Error; err != nil {
		return 0, err
	}
	return total.AmountMinor, nil
}
