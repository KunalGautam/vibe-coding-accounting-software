package services

import (
	"context"
	"testing"

	"accounting.abhashtech.com/internal/domain"
)

func TestAttachmentServiceCreateDefaultsStorageDriver(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	service := NewAttachmentService(db)
	attachment, err := service.Create(ctx, CreateAttachmentInput{
		OrganizationID: org.ID,
		FileName:       "receipt.jpg",
		ContentType:    "image/jpeg",
		StorageKey:     "receipts/receipt.jpg",
		SizeBytes:      2048,
		ChecksumSHA256: "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	if attachment.StorageDriver != "local" {
		t.Fatalf("storage driver = %s, want local", attachment.StorageDriver)
	}
	if attachment.OrganizationID != org.ID {
		t.Fatalf("organization id = %s, want %s", attachment.OrganizationID, org.ID)
	}
	if attachment.ChecksumSHA256 == "" {
		t.Fatalf("checksum was not persisted")
	}
}

func TestAttachmentServiceListIsTenantScoped(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	otherOrg := domain.Organization{Name: "Other India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if err := db.Create(&otherOrg).Error; err != nil {
		t.Fatalf("create other organization: %v", err)
	}

	service := NewAttachmentService(db)
	if _, err := service.Create(ctx, CreateAttachmentInput{
		OrganizationID: org.ID,
		FileName:       "invoice.pdf",
		ContentType:    "application/pdf",
		StorageKey:     "invoices/invoice.pdf",
	}); err != nil {
		t.Fatalf("create attachment: %v", err)
	}
	if _, err := service.Create(ctx, CreateAttachmentInput{
		OrganizationID: otherOrg.ID,
		FileName:       "other.pdf",
		ContentType:    "application/pdf",
		StorageKey:     "invoices/other.pdf",
	}); err != nil {
		t.Fatalf("create other attachment: %v", err)
	}

	attachments, err := service.List(ctx, org.ID)
	if err != nil {
		t.Fatalf("List() error = %v", err)
	}
	if len(attachments) != 1 {
		t.Fatalf("attachments = %d, want 1", len(attachments))
	}
	if attachments[0].FileName != "invoice.pdf" {
		t.Fatalf("file name = %s, want invoice.pdf", attachments[0].FileName)
	}
}
