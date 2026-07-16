package services

import (
	"context"
	"errors"
	"strings"
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

func TestAuthServiceCurrentUserAndUpdate(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	passwordHash, err := bcrypt.GenerateFromPassword([]byte("secret-pass"), bcrypt.MinCost)
	if err != nil {
		t.Fatalf("hash password: %v", err)
	}

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	user := domain.User{Email: "profile@example.com", Name: "Profile User", PasswordHash: string(passwordHash), IsActive: true}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}
	membership := domain.OrganizationMembership{OrganizationID: org.ID, UserID: user.ID, Role: domain.RoleAccountant}
	if err := db.Create(&membership).Error; err != nil {
		t.Fatalf("create membership: %v", err)
	}

	service := NewAuthService(db, auth.NewTokenManager("access-secret", "refresh-secret", time.Minute, time.Hour))
	profile, err := service.CurrentUser(ctx, user.ID)
	if err != nil {
		t.Fatalf("CurrentUser() error = %v", err)
	}
	if profile.Email != user.Email || profile.OrganizationRoles[org.ID] != domain.RoleAccountant {
		t.Fatalf("profile = %+v, want email and accountant role", profile)
	}

	updated, err := service.UpdateCurrentUser(ctx, user.ID, "Updated Name")
	if err != nil {
		t.Fatalf("UpdateCurrentUser() error = %v", err)
	}
	if updated.Name != "Updated Name" {
		t.Fatalf("updated name = %q, want Updated Name", updated.Name)
	}
}

func TestAuthServiceChangePasswordRevokesSessions(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	passwordHash, err := bcrypt.GenerateFromPassword([]byte("old-password"), bcrypt.MinCost)
	if err != nil {
		t.Fatalf("hash password: %v", err)
	}
	user := domain.User{Email: "change-password@example.com", Name: "Change Password", PasswordHash: string(passwordHash), IsActive: true}
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}

	service := NewAuthService(db, auth.NewTokenManager("access-secret", "refresh-secret", time.Minute, time.Hour))
	login, err := service.Login(ctx, user.Email, "old-password")
	if err != nil {
		t.Fatalf("Login() error = %v", err)
	}
	if err := service.ChangePassword(ctx, user.ID, "wrong-password", "new-secure-password"); !errors.Is(err, ErrInvalidCredentials) {
		t.Fatalf("wrong password change error = %v, want %v", err, ErrInvalidCredentials)
	}
	if err := service.ChangePassword(ctx, user.ID, "old-password", "new-secure-password"); err != nil {
		t.Fatalf("ChangePassword() error = %v", err)
	}
	if _, err := service.Refresh(ctx, login.RefreshToken); !errors.Is(err, ErrInvalidRefreshToken) {
		t.Fatalf("refresh old session error = %v, want %v", err, ErrInvalidRefreshToken)
	}
	if _, err := service.Login(ctx, user.Email, "old-password"); !errors.Is(err, ErrInvalidCredentials) {
		t.Fatalf("old password login error = %v, want %v", err, ErrInvalidCredentials)
	}
	if _, err := service.Login(ctx, user.Email, "new-secure-password"); err != nil {
		t.Fatalf("new password login error = %v", err)
	}
}

func TestAuthServiceRevokesSessions(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	passwordHash, err := bcrypt.GenerateFromPassword([]byte("secret-pass"), bcrypt.MinCost)
	if err != nil {
		t.Fatalf("hash password: %v", err)
	}
	user := domain.User{Email: "admin@example.com", Name: "Admin", PasswordHash: string(passwordHash), IsActive: true}
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}

	service := NewAuthService(db, auth.NewTokenManager("access-secret", "refresh-secret", time.Minute, time.Hour))
	first, err := service.Login(ctx, "admin@example.com", "secret-pass")
	if err != nil {
		t.Fatalf("first Login() error = %v", err)
	}
	second, err := service.Login(ctx, "admin@example.com", "secret-pass")
	if err != nil {
		t.Fatalf("second Login() error = %v", err)
	}

	if err := service.RevokeRefreshToken(ctx, first.RefreshToken); err != nil {
		t.Fatalf("RevokeRefreshToken() error = %v", err)
	}
	if _, err := service.Refresh(ctx, first.RefreshToken); !errors.Is(err, ErrInvalidRefreshToken) {
		t.Fatalf("revoked refresh error = %v, want %v", err, ErrInvalidRefreshToken)
	}
	count, err := service.RevokeUserSessions(ctx, user.ID)
	if err != nil {
		t.Fatalf("RevokeUserSessions() error = %v", err)
	}
	if count != 1 {
		t.Fatalf("revoked count = %d, want 1", count)
	}
	if _, err := service.Refresh(ctx, second.RefreshToken); !errors.Is(err, ErrInvalidRefreshToken) {
		t.Fatalf("second refresh error = %v, want %v", err, ErrInvalidRefreshToken)
	}
}

func TestAuthServiceMFASetupEnableAndLogin(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	passwordHash, err := bcrypt.GenerateFromPassword([]byte("secret-pass"), bcrypt.MinCost)
	if err != nil {
		t.Fatalf("hash password: %v", err)
	}
	user := domain.User{Email: "mfa@example.com", Name: "MFA User", PasswordHash: string(passwordHash), IsActive: true}
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}

	service := NewAuthService(db, auth.NewTokenManager("access-secret", "refresh-secret", time.Minute, time.Hour), "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=")
	setup, err := service.SetupMFA(ctx, user.ID)
	if err != nil {
		t.Fatalf("SetupMFA() error = %v", err)
	}
	if setup.Secret == "" || setup.OTPAuthURL == "" || setup.MFAEnabled {
		t.Fatalf("unexpected MFA setup result: %+v", setup)
	}
	var storedUser domain.User
	if err := db.First(&storedUser, "id = ?", user.ID).Error; err != nil {
		t.Fatalf("load stored MFA user: %v", err)
	}
	if storedUser.MFASecret == setup.Secret || !isEncryptedMFASecret(storedUser.MFASecret) {
		t.Fatalf("stored MFA secret was not encrypted: %q", storedUser.MFASecret)
	}
	code, err := totpCode(setup.Secret, time.Now().UTC())
	if err != nil {
		t.Fatalf("totpCode() error = %v", err)
	}
	enabled, err := service.EnableMFA(ctx, user.ID, code)
	if err != nil {
		t.Fatalf("EnableMFA() error = %v", err)
	}
	if !enabled.MFAEnabled || len(enabled.RecoveryCodes) != 10 {
		t.Fatalf("unexpected EnableMFA() result: %+v", enabled)
	}
	if _, err := service.Login(ctx, "mfa@example.com", "secret-pass"); !errors.Is(err, ErrMFARequired) {
		t.Fatalf("login without MFA error = %v, want %v", err, ErrMFARequired)
	}
	if _, err := service.Login(ctx, "mfa@example.com", "secret-pass", "000000"); !errors.Is(err, ErrInvalidMFACode) {
		t.Fatalf("login bad MFA error = %v, want %v", err, ErrInvalidMFACode)
	}
	if _, err := service.Login(ctx, "mfa@example.com", "secret-pass", enabled.RecoveryCodes[0]); err != nil {
		t.Fatalf("login with recovery code error = %v", err)
	}
	if _, err := service.Login(ctx, "mfa@example.com", "secret-pass", enabled.RecoveryCodes[0]); !errors.Is(err, ErrInvalidMFACode) {
		t.Fatalf("reused recovery code error = %v, want %v", err, ErrInvalidMFACode)
	}
	if _, err := service.Login(ctx, "mfa@example.com", "secret-pass", code); err != nil {
		t.Fatalf("login with MFA error = %v", err)
	}
	regenerated, err := service.RegenerateMFARecoveryCodes(ctx, user.ID, code)
	if err != nil {
		t.Fatalf("RegenerateMFARecoveryCodes() error = %v", err)
	}
	if !regenerated.MFAEnabled || len(regenerated.RecoveryCodes) != 10 {
		t.Fatalf("unexpected RegenerateMFARecoveryCodes() result: %+v", regenerated)
	}
	if _, err := service.Login(ctx, "mfa@example.com", "secret-pass", enabled.RecoveryCodes[1]); !errors.Is(err, ErrInvalidMFACode) {
		t.Fatalf("old recovery code after regeneration error = %v, want %v", err, ErrInvalidMFACode)
	}
	if err := service.DisableMFA(ctx, user.ID, regenerated.RecoveryCodes[0]); err != nil {
		t.Fatalf("DisableMFA() error = %v", err)
	}
	if _, err := service.Login(ctx, "mfa@example.com", "secret-pass"); err != nil {
		t.Fatalf("login after disabling MFA error = %v", err)
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

func TestAuthServicePasswordResetSendsEmailAndHidesToken(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	passwordHash, err := bcrypt.GenerateFromPassword([]byte("old-password"), bcrypt.MinCost)
	if err != nil {
		t.Fatalf("hash password: %v", err)
	}
	user := domain.User{Email: "email-reset@example.com", Name: "Email Reset", PasswordHash: string(passwordHash), IsActive: true}
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}

	sender := &captureEmailSender{}
	service := NewAuthServiceWithOptions(db, auth.NewTokenManager("access-secret", "refresh-secret", time.Minute, time.Hour), AuthServiceOptions{
		EmailSender:          sender,
		PasswordResetBaseURL: "https://app.example.com/reset-password",
	})
	request, err := service.RequestPasswordReset(ctx, user.Email)
	if err != nil {
		t.Fatalf("RequestPasswordReset() error = %v", err)
	}
	if !request.Requested || !request.EmailSent || request.ResetToken != "" || request.ResetTokenUntil == nil {
		t.Fatalf("unexpected reset email result: %+v", request)
	}
	if len(sender.messages) != 1 {
		t.Fatalf("sent messages = %d, want 1", len(sender.messages))
	}
	message := sender.messages[0]
	if message.To != user.Email || !strings.Contains(message.Text, "https://app.example.com/reset-password?token=") {
		t.Fatalf("unexpected reset email: %+v", message)
	}
}

type captureEmailSender struct {
	messages []EmailMessage
}

func (s *captureEmailSender) Send(_ context.Context, message EmailMessage) error {
	s.messages = append(s.messages, message)
	return nil
}
