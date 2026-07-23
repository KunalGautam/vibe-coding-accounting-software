package services

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func TestDataExportServiceExportOrganization(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	otherOrg := domain.Organization{Name: "Other Org", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if err := db.Create(&otherOrg).Error; err != nil {
		t.Fatalf("create other organization: %v", err)
	}

	cash := domain.Account{OrganizationID: org.ID, Code: "1000", Name: "Cash", Type: domain.AccountTypeAsset, Currency: "INR", IsActive: true}
	otherCash := domain.Account{OrganizationID: otherOrg.ID, Code: "1000", Name: "Other Cash", Type: domain.AccountTypeAsset, Currency: "INR", IsActive: true}
	if err := db.Create(&cash).Error; err != nil {
		t.Fatalf("create account: %v", err)
	}
	if err := db.Create(&otherCash).Error; err != nil {
		t.Fatalf("create other account: %v", err)
	}

	customer := domain.Customer{OrganizationID: org.ID, DisplayName: "Acme Customer", IsActive: true}
	if err := db.Create(&customer).Error; err != nil {
		t.Fatalf("create customer: %v", err)
	}

	invoice := domain.Invoice{
		OrganizationID:       org.ID,
		CustomerID:           customer.ID,
		InvoiceNumber:        "INV-001",
		IssueDate:            time.Date(2026, 7, 13, 0, 0, 0, 0, time.UTC),
		DueDate:              time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC),
		Status:               domain.InvoiceStatusDraft,
		Currency:             "INR",
		AccountsReceivableID: cash.ID,
		SubtotalMinor:        10000,
		TotalMinor:           10000,
		Lines: []domain.InvoiceLine{
			{
				OrganizationID:    org.ID,
				Description:       "Consulting",
				QuantityMillis:    1000,
				UnitPriceMinor:    10000,
				LineSubtotalMinor: 10000,
				LineTotalMinor:    10000,
				IncomeAccountID:   cash.ID,
			},
		},
	}
	if err := db.Create(&invoice).Error; err != nil {
		t.Fatalf("create invoice: %v", err)
	}

	export, err := NewDataExportService(db).ExportOrganization(ctx, org.ID)
	if err != nil {
		t.Fatalf("ExportOrganization() error = %v", err)
	}

	if export.Organization.ID != org.ID {
		t.Fatalf("organization id = %s, want %s", export.Organization.ID, org.ID)
	}
	if len(export.Accounts) != 1 || export.Accounts[0].ID != cash.ID {
		t.Fatalf("exported accounts = %+v, want only %s", export.Accounts, cash.ID)
	}
	if len(export.Invoices) != 1 || len(export.Invoices[0].Lines) != 1 {
		t.Fatalf("exported invoices = %+v, want invoice with line", export.Invoices)
	}
}

func TestDataExportServiceRestoreOrganization(t *testing.T) {
	sourceDB := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Restore Co", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := sourceDB.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	cash := domain.Account{OrganizationID: org.ID, Code: "1000", Name: "Cash", Type: domain.AccountTypeAsset, Currency: "INR", IsActive: true}
	revenue := domain.Account{OrganizationID: org.ID, Code: "4000", Name: "Revenue", Type: domain.AccountTypeIncome, Currency: "INR", IsActive: true}
	if err := sourceDB.Create(&cash).Error; err != nil {
		t.Fatalf("create cash account: %v", err)
	}
	if err := sourceDB.Create(&revenue).Error; err != nil {
		t.Fatalf("create revenue account: %v", err)
	}
	customer := domain.Customer{OrganizationID: org.ID, DisplayName: "Restore Customer", IsActive: true}
	if err := sourceDB.Create(&customer).Error; err != nil {
		t.Fatalf("create customer: %v", err)
	}
	invoice := domain.Invoice{
		OrganizationID:       org.ID,
		CustomerID:           customer.ID,
		InvoiceNumber:        "REST-001",
		IssueDate:            time.Date(2026, 7, 13, 0, 0, 0, 0, time.UTC),
		DueDate:              time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC),
		Status:               domain.InvoiceStatusDraft,
		Currency:             "INR",
		AccountsReceivableID: cash.ID,
		SubtotalMinor:        15000,
		TotalMinor:           15000,
		Lines: []domain.InvoiceLine{
			{
				OrganizationID:    org.ID,
				Description:       "Restore consulting",
				QuantityMillis:    1000,
				UnitPriceMinor:    15000,
				LineSubtotalMinor: 15000,
				LineTotalMinor:    15000,
				IncomeAccountID:   revenue.ID,
			},
		},
	}
	if err := sourceDB.Create(&invoice).Error; err != nil {
		t.Fatalf("create invoice: %v", err)
	}

	export, err := NewDataExportService(sourceDB).ExportOrganization(ctx, org.ID)
	if err != nil {
		t.Fatalf("ExportOrganization() error = %v", err)
	}

	targetDB := restoreTargetDB(t)
	result, err := NewDataExportService(targetDB).RestoreOrganization(ctx, export)
	if err != nil {
		t.Fatalf("RestoreOrganization() error = %v", err)
	}
	if result.OrganizationID != org.ID || result.Accounts != 2 || result.Invoices != 1 {
		t.Fatalf("unexpected restore result: %+v", result)
	}

	var restoredInvoice domain.Invoice
	if err := targetDB.Preload("Lines").First(&restoredInvoice, "id = ?", invoice.ID).Error; err != nil {
		t.Fatalf("load restored invoice: %v", err)
	}
	if restoredInvoice.OrganizationID != org.ID || len(restoredInvoice.Lines) != 1 || restoredInvoice.Lines[0].Description != "Restore consulting" {
		t.Fatalf("unexpected restored invoice: %+v", restoredInvoice)
	}

	_, err = NewDataExportService(targetDB).RestoreOrganization(ctx, export)
	if !errors.Is(err, ErrRestoreOrganizationExists) {
		t.Fatalf("second restore error = %v, want ErrRestoreOrganizationExists", err)
	}
}

func restoreTargetDB(t *testing.T) *gorm.DB {
	t.Helper()

	name := strings.NewReplacer("/", "_", " ", "_").Replace(t.Name() + "_target")
	db, err := gorm.Open(sqlite.Open("file:"+name+"?mode=memory&cache=shared"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open restore target database: %v", err)
	}
	if err := db.AutoMigrate(domain.AllModels()...); err != nil {
		t.Fatalf("auto migrate restore target database: %v", err)
	}
	return db
}

func TestDataExportServiceCreateBackupSnapshotPrunesRetention(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	service := NewDataExportService(db)
	storagePath := t.TempDir()
	first, err := service.CreateBackupSnapshot(ctx, CreateBackupSnapshotInput{
		OrganizationID: org.ID,
		StoragePath:    storagePath,
		RetentionCount: 1,
	})
	if err != nil {
		t.Fatalf("CreateBackupSnapshot(first) error = %v", err)
	}
	if first.SizeBytes == 0 || first.SHA256 == "" || first.CompletedAt == nil {
		t.Fatalf("first snapshot metadata incomplete: %+v", first)
	}
	if _, err := os.Stat(first.StoragePath); err != nil {
		t.Fatalf("expected first backup file to exist: %v", err)
	}
	if _, err := os.Stat(first.StoragePath + ".sha256"); err != nil {
		t.Fatalf("expected first backup checksum file to exist: %v", err)
	}

	second, err := service.CreateBackupSnapshot(ctx, CreateBackupSnapshotInput{
		OrganizationID: org.ID,
		StoragePath:    storagePath,
		RetentionCount: 1,
	})
	if err != nil {
		t.Fatalf("CreateBackupSnapshot(second) error = %v", err)
	}
	if _, err := os.Stat(second.StoragePath); err != nil {
		t.Fatalf("expected second backup file to exist: %v", err)
	}
	if _, err := os.Stat(second.StoragePath + ".sha256"); err != nil {
		t.Fatalf("expected second backup checksum file to exist: %v", err)
	}

	snapshots, err := service.ListBackupSnapshots(ctx, org.ID)
	if err != nil {
		t.Fatalf("ListBackupSnapshots() error = %v", err)
	}
	if len(snapshots) != 1 || snapshots[0].ID != second.ID {
		t.Fatalf("snapshots = %+v, want only second snapshot", snapshots)
	}
	if _, err := os.Stat(first.StoragePath); !os.IsNotExist(err) {
		t.Fatalf("expected first backup file to be pruned, stat error = %v", err)
	}
	if _, err := os.Stat(first.StoragePath + ".sha256"); !os.IsNotExist(err) {
		t.Fatalf("expected first backup checksum file to be pruned, stat error = %v", err)
	}
}

func TestDataExportServiceCreateBackupSnapshotMirrorsAndPrunesRetention(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Mirror Backup Co", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	service := NewDataExportService(db)
	storagePath := t.TempDir()
	mirrorPath := t.TempDir()
	first, err := service.CreateBackupSnapshot(ctx, CreateBackupSnapshotInput{
		OrganizationID: org.ID,
		StoragePath:    storagePath,
		MirrorPath:     mirrorPath,
		RetentionCount: 1,
	})
	if err != nil {
		t.Fatalf("CreateBackupSnapshot(first) error = %v", err)
	}
	firstMirrorPath := filepath.Join(mirrorPath, first.FileName)
	if _, err := os.Stat(firstMirrorPath); err != nil {
		t.Fatalf("expected first mirrored backup file to exist: %v", err)
	}
	if _, err := os.Stat(firstMirrorPath + ".sha256"); err != nil {
		t.Fatalf("expected first mirrored backup checksum file to exist: %v", err)
	}

	second, err := service.CreateBackupSnapshot(ctx, CreateBackupSnapshotInput{
		OrganizationID: org.ID,
		StoragePath:    storagePath,
		MirrorPath:     mirrorPath,
		RetentionCount: 1,
	})
	if err != nil {
		t.Fatalf("CreateBackupSnapshot(second) error = %v", err)
	}
	secondMirrorPath := filepath.Join(mirrorPath, second.FileName)
	if _, err := os.Stat(secondMirrorPath); err != nil {
		t.Fatalf("expected second mirrored backup file to exist: %v", err)
	}
	if _, err := os.Stat(secondMirrorPath + ".sha256"); err != nil {
		t.Fatalf("expected second mirrored backup checksum file to exist: %v", err)
	}
	if _, err := os.Stat(firstMirrorPath); !os.IsNotExist(err) {
		t.Fatalf("expected first mirrored backup file to be pruned, stat error = %v", err)
	}
	if _, err := os.Stat(firstMirrorPath + ".sha256"); !os.IsNotExist(err) {
		t.Fatalf("expected first mirrored backup checksum file to be pruned, stat error = %v", err)
	}
}

func TestDataExportServiceCreateBackupSnapshotCleansFilesWhenMetadataInsertFails(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	org := domain.Organization{Name: "Cleanup Backup Co", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	service := NewDataExportService(db)
	storagePath := t.TempDir()
	mirrorPath := t.TempDir()
	if err := db.Callback().Create().Before("gorm:create").Register("fail_backup_snapshot_metadata", func(tx *gorm.DB) {
		if tx.Statement != nil && tx.Statement.Schema != nil && tx.Statement.Schema.Name == "BackupSnapshot" {
			tx.AddError(errors.New("forced backup snapshot metadata failure"))
		}
	}); err != nil {
		t.Fatalf("register create callback: %v", err)
	}

	_, err := service.CreateBackupSnapshot(ctx, CreateBackupSnapshotInput{
		OrganizationID: org.ID,
		StoragePath:    storagePath,
		MirrorPath:     mirrorPath,
	})
	if err == nil {
		t.Fatalf("CreateBackupSnapshot() error = nil, want metadata insert failure")
	}
	if entries, readErr := os.ReadDir(storagePath); readErr != nil {
		t.Fatalf("read storage dir: %v", readErr)
	} else if len(entries) != 0 {
		t.Fatalf("primary backup files left behind: %+v", entries)
	}
	if entries, readErr := os.ReadDir(mirrorPath); readErr != nil {
		t.Fatalf("read mirror dir: %v", readErr)
	} else if len(entries) != 0 {
		t.Fatalf("mirrored backup files left behind: %+v", entries)
	}
}
