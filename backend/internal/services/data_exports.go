package services

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

type DataExportService struct {
	db *gorm.DB
}

var ErrRestoreOrganizationExists = errors.New("restore target organization already exists")

type OrganizationDataExport struct {
	ExportedAt             time.Time                          `json:"exported_at"`
	Organization           domain.Organization                `json:"organization"`
	Accounts               []domain.Account                   `json:"accounts"`
	JournalTransactions    []domain.JournalTransaction        `json:"journal_transactions"`
	AuditLogs              []domain.AuditLog                  `json:"audit_logs"`
	TaxAuthorities         []domain.TaxAuthority              `json:"tax_authorities"`
	TaxRates               []domain.TaxRate                   `json:"tax_rates"`
	TaxGroups              []domain.TaxGroup                  `json:"tax_groups"`
	Customers              []domain.Customer                  `json:"customers"`
	Invoices               []domain.Invoice                   `json:"invoices"`
	RecurringInvoices      []domain.RecurringInvoiceTemplate  `json:"recurring_invoices"`
	Estimates              []domain.Estimate                  `json:"estimates"`
	CreditNotes            []domain.CreditNote                `json:"credit_notes"`
	CustomerPayments       []domain.CustomerPayment           `json:"customer_payments"`
	Vendors                []domain.Vendor                    `json:"vendors"`
	Expenses               []domain.Expense                   `json:"expenses"`
	Bills                  []domain.Bill                      `json:"bills"`
	PurchaseOrders         []domain.PurchaseOrder             `json:"purchase_orders"`
	VendorPayments         []domain.VendorPayment             `json:"vendor_payments"`
	Attachments            []domain.Attachment                `json:"attachments"`
	Employees              []domain.Employee                  `json:"employees"`
	PayrollRuns            []domain.PayrollRun                `json:"payroll_runs"`
	BankStatementImports   []domain.BankStatementImport       `json:"bank_statement_imports"`
	Budgets                []domain.Budget                    `json:"budgets"`
	ExchangeRates          []domain.ExchangeRate              `json:"exchange_rates"`
	FiscalCloses           []domain.FiscalClose               `json:"fiscal_closes"`
	InvestmentLots         []domain.InvestmentLot             `json:"investment_lots"`
	InvestmentDispositions []domain.InvestmentDisposition     `json:"investment_dispositions"`
	InvestmentDividends    []domain.InvestmentDividend        `json:"investment_dividends"`
	InvestmentActions      []domain.InvestmentCorporateAction `json:"investment_corporate_actions"`
	InvestmentPrices       []domain.InvestmentPrice           `json:"investment_prices"`
	BackupSnapshots        []domain.BackupSnapshot            `json:"backup_snapshots"`
}

type CreateBackupSnapshotInput struct {
	OrganizationID string
	StoragePath    string
	RetentionCount int
}

type RestoreOrganizationResult struct {
	OrganizationID      string `json:"organization_id"`
	Accounts            int    `json:"accounts"`
	JournalTransactions int    `json:"journal_transactions"`
	Invoices            int    `json:"invoices"`
	Expenses            int    `json:"expenses"`
	PayrollRuns         int    `json:"payroll_runs"`
	InvestmentLots      int    `json:"investment_lots"`
}

func NewDataExportService(db *gorm.DB) DataExportService {
	return DataExportService{db: db}
}

func (s DataExportService) ListBackupSnapshots(ctx context.Context, organizationID string) ([]domain.BackupSnapshot, error) {
	var snapshots []domain.BackupSnapshot
	err := s.db.WithContext(ctx).
		Where("organization_id = ?", organizationID).
		Order("completed_at DESC, created_at DESC").
		Find(&snapshots).
		Error
	return snapshots, err
}

func (s DataExportService) CreateBackupSnapshot(ctx context.Context, input CreateBackupSnapshotInput) (domain.BackupSnapshot, error) {
	export, err := s.ExportOrganization(ctx, input.OrganizationID)
	if err != nil {
		return domain.BackupSnapshot{}, err
	}
	storagePath := input.StoragePath
	if storagePath == "" {
		storagePath = "./storage/backups"
	}
	if err := os.MkdirAll(storagePath, 0o755); err != nil {
		return domain.BackupSnapshot{}, err
	}

	payload, err := json.MarshalIndent(export, "", "  ")
	if err != nil {
		return domain.BackupSnapshot{}, err
	}
	fileName := fmt.Sprintf("organization-%s-backup-%s.json", input.OrganizationID, time.Now().UTC().Format("20060102T150405.000000000Z"))
	fullPath := filepath.Join(storagePath, fileName)
	if err := os.WriteFile(fullPath, payload, 0o600); err != nil {
		return domain.BackupSnapshot{}, err
	}
	sum := sha256.Sum256(payload)
	now := time.Now().UTC()
	snapshot := domain.BackupSnapshot{
		OrganizationID: input.OrganizationID,
		FileName:       fileName,
		StoragePath:    fullPath,
		SizeBytes:      int64(len(payload)),
		SHA256:         hex.EncodeToString(sum[:]),
		Status:         "completed",
		CompletedAt:    &now,
	}
	if err := s.db.WithContext(ctx).Create(&snapshot).Error; err != nil {
		return domain.BackupSnapshot{}, err
	}
	if input.RetentionCount > 0 {
		if err := s.pruneBackups(ctx, input.OrganizationID, input.RetentionCount); err != nil {
			return domain.BackupSnapshot{}, err
		}
	}
	return snapshot, nil
}

func (s DataExportService) ExportOrganization(ctx context.Context, organizationID string) (OrganizationDataExport, error) {
	export := OrganizationDataExport{ExportedAt: time.Now().UTC()}
	if err := s.db.WithContext(ctx).Where("id = ?", organizationID).First(&export.Organization).Error; err != nil {
		return OrganizationDataExport{}, err
	}

	loaders := []func() error{
		func() error { return s.list(ctx, organizationID, "code ASC", &export.Accounts) },
		func() error {
			return s.db.WithContext(ctx).
				Preload("Splits").
				Where("organization_id = ?", organizationID).
				Order("transaction_date ASC, created_at ASC").
				Find(&export.JournalTransactions).Error
		},
		func() error { return s.list(ctx, organizationID, "created_at ASC", &export.AuditLogs) },
		func() error { return s.list(ctx, organizationID, "name ASC", &export.TaxAuthorities) },
		func() error { return s.list(ctx, organizationID, "name ASC", &export.TaxRates) },
		func() error {
			return s.db.WithContext(ctx).
				Preload("Components").
				Where("organization_id = ?", organizationID).
				Order("name ASC").
				Find(&export.TaxGroups).Error
		},
		func() error { return s.list(ctx, organizationID, "display_name ASC", &export.Customers) },
		func() error {
			return s.preloadLines(ctx, organizationID, "issue_date ASC, created_at ASC", &export.Invoices)
		},
		func() error {
			return s.preloadLines(ctx, organizationID, "next_run_date ASC, created_at ASC", &export.RecurringInvoices)
		},
		func() error {
			return s.preloadLines(ctx, organizationID, "issue_date ASC, created_at ASC", &export.Estimates)
		},
		func() error {
			return s.preloadLines(ctx, organizationID, "issue_date ASC, created_at ASC", &export.CreditNotes)
		},
		func() error {
			return s.list(ctx, organizationID, "payment_date ASC, created_at ASC", &export.CustomerPayments)
		},
		func() error { return s.list(ctx, organizationID, "display_name ASC", &export.Vendors) },
		func() error { return s.list(ctx, organizationID, "expense_date ASC, created_at ASC", &export.Expenses) },
		func() error {
			return s.preloadLines(ctx, organizationID, "issue_date ASC, created_at ASC", &export.Bills)
		},
		func() error {
			return s.preloadLines(ctx, organizationID, "issue_date ASC, created_at ASC", &export.PurchaseOrders)
		},
		func() error {
			return s.list(ctx, organizationID, "payment_date ASC, created_at ASC", &export.VendorPayments)
		},
		func() error { return s.list(ctx, organizationID, "created_at ASC", &export.Attachments) },
		func() error { return s.list(ctx, organizationID, "display_name ASC", &export.Employees) },
		func() error {
			return s.db.WithContext(ctx).
				Preload("Items").
				Where("organization_id = ?", organizationID).
				Order("pay_date ASC, created_at ASC").
				Find(&export.PayrollRuns).Error
		},
		func() error {
			return s.db.WithContext(ctx).
				Preload("Lines").
				Where("organization_id = ?", organizationID).
				Order("created_at ASC").
				Find(&export.BankStatementImports).Error
		},
		func() error {
			return s.preloadLines(ctx, organizationID, "start_date ASC, created_at ASC", &export.Budgets)
		},
		func() error {
			return s.list(ctx, organizationID, "rate_date ASC, created_at ASC", &export.ExchangeRates)
		},
		func() error { return s.list(ctx, organizationID, "fiscal_year_start ASC", &export.FiscalCloses) },
		func() error {
			return s.list(ctx, organizationID, "symbol ASC, acquisition_date ASC", &export.InvestmentLots)
		},
		func() error {
			return s.list(ctx, organizationID, "sale_date ASC, created_at ASC", &export.InvestmentDispositions)
		},
		func() error {
			return s.list(ctx, organizationID, "dividend_date ASC, created_at ASC", &export.InvestmentDividends)
		},
		func() error {
			return s.list(ctx, organizationID, "action_date ASC, created_at ASC", &export.InvestmentActions)
		},
		func() error {
			return s.list(ctx, organizationID, "symbol ASC, price_date ASC", &export.InvestmentPrices)
		},
		func() error {
			return s.list(ctx, organizationID, "completed_at ASC, created_at ASC", &export.BackupSnapshots)
		},
	}

	for _, load := range loaders {
		if err := load(); err != nil {
			return OrganizationDataExport{}, err
		}
	}

	return export, nil
}

func (s DataExportService) RestoreOrganization(ctx context.Context, export OrganizationDataExport) (RestoreOrganizationResult, error) {
	if export.Organization.ID == "" {
		return RestoreOrganizationResult{}, fmt.Errorf("restore export is missing organization")
	}

	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var count int64
		if err := tx.Model(&domain.Organization{}).Where("id = ?", export.Organization.ID).Count(&count).Error; err != nil {
			return err
		}
		if count > 0 {
			return ErrRestoreOrganizationExists
		}

		if err := tx.Create(&export.Organization).Error; err != nil {
			return err
		}

		creates := []func() error{
			func() error { return createIfAny(tx, &export.Accounts) },
			func() error { return createIfAny(tx, &export.TaxAuthorities) },
			func() error {
				return createIfAny(tx.Session(&gorm.Session{FullSaveAssociations: true}), &export.TaxRates)
			},
			func() error {
				return createIfAny(tx.Session(&gorm.Session{FullSaveAssociations: true}), &export.TaxGroups)
			},
			func() error { return createIfAny(tx, &export.Customers) },
			func() error { return createIfAny(tx, &export.Vendors) },
			func() error { return createIfAny(tx, &export.Attachments) },
			func() error { return createIfAny(tx, &export.Employees) },
			func() error { return createIfAny(tx, &export.ExchangeRates) },
			func() error {
				return createIfAny(tx.Session(&gorm.Session{FullSaveAssociations: true}), &export.JournalTransactions)
			},
			func() error {
				return createIfAny(tx.Session(&gorm.Session{FullSaveAssociations: true}), &export.Invoices)
			},
			func() error {
				return createIfAny(tx.Session(&gorm.Session{FullSaveAssociations: true}), &export.RecurringInvoices)
			},
			func() error {
				return createIfAny(tx.Session(&gorm.Session{FullSaveAssociations: true}), &export.Estimates)
			},
			func() error {
				return createIfAny(tx.Session(&gorm.Session{FullSaveAssociations: true}), &export.CreditNotes)
			},
			func() error { return createIfAny(tx, &export.CustomerPayments) },
			func() error { return createIfAny(tx, &export.Expenses) },
			func() error { return createIfAny(tx.Session(&gorm.Session{FullSaveAssociations: true}), &export.Bills) },
			func() error {
				return createIfAny(tx.Session(&gorm.Session{FullSaveAssociations: true}), &export.PurchaseOrders)
			},
			func() error { return createIfAny(tx, &export.VendorPayments) },
			func() error {
				return createIfAny(tx.Session(&gorm.Session{FullSaveAssociations: true}), &export.PayrollRuns)
			},
			func() error {
				return createIfAny(tx.Session(&gorm.Session{FullSaveAssociations: true}), &export.BankStatementImports)
			},
			func() error {
				return createIfAny(tx.Session(&gorm.Session{FullSaveAssociations: true}), &export.Budgets)
			},
			func() error { return createIfAny(tx, &export.FiscalCloses) },
			func() error { return createIfAny(tx, &export.InvestmentLots) },
			func() error { return createIfAny(tx, &export.InvestmentDispositions) },
			func() error { return createIfAny(tx, &export.InvestmentDividends) },
			func() error { return createIfAny(tx, &export.InvestmentActions) },
			func() error { return createIfAny(tx, &export.InvestmentPrices) },
			func() error { return createIfAny(tx, &export.AuditLogs) },
			func() error { return createIfAny(tx, &export.BackupSnapshots) },
		}
		for _, create := range creates {
			if err := create(); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return RestoreOrganizationResult{}, err
	}

	return RestoreOrganizationResult{
		OrganizationID:      export.Organization.ID,
		Accounts:            len(export.Accounts),
		JournalTransactions: len(export.JournalTransactions),
		Invoices:            len(export.Invoices),
		Expenses:            len(export.Expenses),
		PayrollRuns:         len(export.PayrollRuns),
		InvestmentLots:      len(export.InvestmentLots),
	}, nil
}

func (s DataExportService) list(ctx context.Context, organizationID string, order string, out any) error {
	return s.db.WithContext(ctx).
		Where("organization_id = ?", organizationID).
		Order(order).
		Find(out).
		Error
}

func (s DataExportService) preloadLines(ctx context.Context, organizationID string, order string, out any) error {
	return s.db.WithContext(ctx).
		Preload("Lines").
		Where("organization_id = ?", organizationID).
		Order(order).
		Find(out).
		Error
}

func (s DataExportService) pruneBackups(ctx context.Context, organizationID string, retentionCount int) error {
	var snapshots []domain.BackupSnapshot
	if err := s.db.WithContext(ctx).
		Where("organization_id = ?", organizationID).
		Order("completed_at DESC, created_at DESC").
		Find(&snapshots).
		Error; err != nil {
		return err
	}
	for _, snapshot := range snapshots[retentionCount:] {
		_ = os.Remove(snapshot.StoragePath)
		if err := s.db.WithContext(ctx).Delete(&snapshot).Error; err != nil {
			return err
		}
	}
	return nil
}

func createIfAny[T any](tx *gorm.DB, values *[]T) error {
	if values == nil || len(*values) == 0 {
		return nil
	}
	return tx.Create(values).Error
}
