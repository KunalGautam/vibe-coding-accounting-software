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

func TestUserServiceUpdateOrganizationUser(t *testing.T) {
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
		Email:          "bookkeeper-update@example.com",
		Password:       "secure-password",
		Role:           domain.RoleBookkeeper,
	})
	if err != nil {
		t.Fatalf("CreateOrganizationUser() error = %v", err)
	}

	nextRole := domain.RoleAccountant
	nextActive := false
	nextName := "Senior Accountant"
	updated, err := service.UpdateOrganizationUser(ctx, UpdateOrganizationUserInput{
		OrganizationID: org.ID,
		UserID:         user.UserID,
		Name:           &nextName,
		Role:           &nextRole,
		IsActive:       &nextActive,
	})
	if err != nil {
		t.Fatalf("UpdateOrganizationUser() error = %v", err)
	}
	if updated.Name != nextName || updated.Role != nextRole || updated.IsActive {
		t.Fatalf("updated user = %+v, want name %q role %s inactive", updated, nextName, nextRole)
	}

	users, err := service.ListOrganizationUsers(ctx, org.ID)
	if err != nil {
		t.Fatalf("ListOrganizationUsers() error = %v", err)
	}
	if len(users) != 1 || users[0].Name != nextName || users[0].Role != nextRole || users[0].IsActive {
		t.Fatalf("listed users = %+v, want updated inactive accountant", users)
	}
}

func TestUserServiceUpdateOrganizationUserProtectsLastActiveAdmin(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	service := NewUserService(db)
	admin, err := service.CreateOrganizationUser(ctx, CreateOrganizationUserInput{
		OrganizationID: org.ID,
		Name:           "Admin",
		Email:          "only-admin@example.com",
		Password:       "secure-password",
		Role:           domain.RoleAdmin,
	})
	if err != nil {
		t.Fatalf("CreateOrganizationUser() error = %v", err)
	}

	inactive := false
	if _, err := service.UpdateOrganizationUser(ctx, UpdateOrganizationUserInput{
		OrganizationID: org.ID,
		UserID:         admin.UserID,
		IsActive:       &inactive,
	}); !errors.Is(err, ErrLastActiveAdmin) {
		t.Fatalf("deactivate last admin error = %v, want %v", err, ErrLastActiveAdmin)
	}

	viewerRole := domain.RoleViewer
	if _, err := service.UpdateOrganizationUser(ctx, UpdateOrganizationUserInput{
		OrganizationID: org.ID,
		UserID:         admin.UserID,
		Role:           &viewerRole,
	}); !errors.Is(err, ErrLastActiveAdmin) {
		t.Fatalf("demote last admin error = %v, want %v", err, ErrLastActiveAdmin)
	}
}
