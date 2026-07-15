package services

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/auth"
	"accounting.abhashtech.com/internal/domain"
)

func TestUserServiceCreateOrganizationUser(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	service := NewUserService(db)
	user, err := service.CreateOrganizationUser(ctx, CreateOrganizationUserInput{
		OrganizationID: org.ID,
		Name:           "Bookkeeper",
		Email:          "bookkeeper@example.com",
		Password:       "secure-password",
		Role:           domain.RoleBookkeeper,
	})
	if err != nil {
		t.Fatalf("CreateOrganizationUser() error = %v", err)
	}
	if user.Role != domain.RoleBookkeeper {
		t.Fatalf("role = %s, want %s", user.Role, domain.RoleBookkeeper)
	}

	authService := NewAuthService(db, auth.NewTokenManager("access", "refresh", time.Minute, time.Hour))
	login, err := authService.Login(ctx, "bookkeeper@example.com", "secure-password")
	if err != nil {
		t.Fatalf("created user login failed: %v", err)
	}
	if login.AccessToken == "" {
		t.Fatalf("login returned empty access token")
	}

	_, err = service.CreateOrganizationUser(ctx, CreateOrganizationUserInput{
		OrganizationID: org.ID,
		Name:           "Bookkeeper",
		Email:          "bookkeeper@example.com",
		Password:       "secure-password",
		Role:           domain.RoleBookkeeper,
	})
	if !errors.Is(err, ErrUserAlreadyMember) {
		t.Fatalf("duplicate membership error = %v, want %v", err, ErrUserAlreadyMember)
	}
}

func TestUserServiceCreateOrganizationUserSendsInvitationEmail(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	sender := &captureEmailSender{}
	service := NewUserServiceWithOptions(db, sender, "https://app.example.com/login")
	user, err := service.CreateOrganizationUser(ctx, CreateOrganizationUserInput{
		OrganizationID: org.ID,
		Name:           "Invited User",
		Email:          "invited@example.com",
		Password:       "secure-password",
		Role:           domain.RoleViewer,
	})
	if err != nil {
		t.Fatalf("CreateOrganizationUser() error = %v", err)
	}
	if !user.InviteEmailSent || user.InviteEmailError != "" {
		t.Fatalf("unexpected invite email status: %+v", user)
	}
	if len(sender.messages) != 1 {
		t.Fatalf("sent messages = %d, want 1", len(sender.messages))
	}
	message := sender.messages[0]
	if message.To != "invited@example.com" || !strings.Contains(message.Text, "https://app.example.com/login") || !strings.Contains(message.Text, "Acme India") {
		t.Fatalf("unexpected invitation email: %+v", message)
	}
}
