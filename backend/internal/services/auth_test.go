package services

import (
	"context"
	"errors"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/auth"
	"accounting.abhashtech.com/internal/domain"
	"golang.org/x/crypto/bcrypt"
)

func TestAuthServiceLoginAndRefresh(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	passwordHash, err := bcrypt.GenerateFromPassword([]byte("secret-pass"), bcrypt.MinCost)
	if err != nil {
		t.Fatalf("hash password: %v", err)
	}

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	user := domain.User{Email: "admin@example.com", Name: "Admin", PasswordHash: string(passwordHash), IsActive: true}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}
	membership := domain.OrganizationMembership{OrganizationID: org.ID, UserID: user.ID, Role: domain.RoleAdmin}
	if err := db.Create(&membership).Error; err != nil {
		t.Fatalf("create membership: %v", err)
	}

	service := NewAuthService(db, auth.NewTokenManager("access-secret", "refresh-secret", time.Minute, time.Hour))
	login, err := service.Login(ctx, "admin@example.com", "secret-pass")
	if err != nil {
		t.Fatalf("Login() error = %v", err)
	}
	if login.AccessToken == "" || login.RefreshToken == "" {
		t.Fatalf("Login() returned empty tokens")
	}

	refreshed, err := service.Refresh(ctx, login.RefreshToken)
	if err != nil {
		t.Fatalf("Refresh() error = %v", err)
	}
	if refreshed.AccessToken == "" || refreshed.RefreshToken == "" {
		t.Fatalf("Refresh() returned empty tokens")
	}

	if _, err := service.Refresh(ctx, login.RefreshToken); err != ErrInvalidRefreshToken {
		t.Fatalf("reusing refresh token error = %v, want %v", err, ErrInvalidRefreshToken)
	}
}

func TestAuthServicePasswordReset(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	passwordHash, err := bcrypt.GenerateFromPassword([]byte("old-password"), bcrypt.MinCost)
	if err != nil {
		t.Fatalf("hash password: %v", err)
	}

	user := domain.User{Email: "owner@example.com", Name: "Owner", PasswordHash: string(passwordHash), IsActive: true}
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}

	service := NewAuthService(db, auth.NewTokenManager("access-secret", "refresh-secret", time.Minute, time.Hour))
	request, err := service.RequestPasswordReset(ctx, "owner@example.com")
	if err != nil {
		t.Fatalf("RequestPasswordReset() error = %v", err)
	}
	if !request.Requested || request.ResetToken == "" || request.ResetTokenUntil == nil {
		t.Fatalf("unexpected reset request result: %+v", request)
	}

	if err := service.ConfirmPasswordReset(ctx, request.ResetToken, "new-secure-password"); err != nil {
		t.Fatalf("ConfirmPasswordReset() error = %v", err)
	}
	if _, err := service.Login(ctx, "owner@example.com", "old-password"); !errors.Is(err, ErrInvalidCredentials) {
		t.Fatalf("old password login error = %v, want %v", err, ErrInvalidCredentials)
	}
	if _, err := service.Login(ctx, "owner@example.com", "new-secure-password"); err != nil {
		t.Fatalf("new password login error = %v", err)
	}
	if err := service.ConfirmPasswordReset(ctx, request.ResetToken, "another-password"); !errors.Is(err, ErrInvalidResetToken) {
		t.Fatalf("reset token reuse error = %v, want %v", err, ErrInvalidResetToken)
	}
}
