package services

import (
	"context"
	"errors"
	"testing"

	"golang.org/x/crypto/bcrypt"
)

func TestBootstrapServiceCreateFirstAdmin(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	service := NewBootstrapService(db)

	result, err := service.CreateFirstAdmin(ctx, BootstrapInput{
		OrganizationName: "Acme India",
		AdminName:        "Admin",
		AdminEmail:       "admin@example.com",
		AdminPassword:    "very-secret-password",
	})
	if err != nil {
		t.Fatalf("CreateFirstAdmin() error = %v", err)
	}
	if result.Organization.BaseCurrency != "INR" {
		t.Fatalf("base currency = %s, want INR", result.Organization.BaseCurrency)
	}
	if result.Organization.CountryCode != "IN" {
		t.Fatalf("country code = %s, want IN", result.Organization.CountryCode)
	}
	if result.Membership.Role != "admin" {
		t.Fatalf("role = %s, want admin", result.Membership.Role)
	}
	if err := bcrypt.CompareHashAndPassword([]byte(result.User.PasswordHash), []byte("very-secret-password")); err != nil {
		t.Fatalf("stored password hash did not verify: %v", err)
	}

	_, err = service.CreateFirstAdmin(ctx, BootstrapInput{
		OrganizationName: "Second",
		AdminName:        "Admin",
		AdminEmail:       "second@example.com",
		AdminPassword:    "very-secret-password",
	})
	if !errors.Is(err, ErrBootstrapAlreadyCompleted) {
		t.Fatalf("second bootstrap error = %v, want %v", err, ErrBootstrapAlreadyCompleted)
	}
}
