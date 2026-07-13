package services

import (
	"context"
	"os"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/domain"
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
}
