package services

import (
	"context"
	"errors"
	"strings"

	"accounting.abhashtech.com/internal/domain"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

var ErrUserAlreadyMember = errors.New("user is already a member of this organization")

type UserService struct {
	db                *gorm.DB
	emailSender       EmailSender
	invitationBaseURL string
}

type CreateOrganizationUserInput struct {
	OrganizationID string
	Name           string
	Email          string
	Password       string
	Role           domain.Role
}

type OrganizationUser struct {
	UserID           string      `json:"user_id"`
	OrganizationID   string      `json:"organization_id"`
	Name             string      `json:"name"`
	Email            string      `json:"email"`
	Role             domain.Role `json:"role"`
	IsActive         bool        `json:"is_active"`
	InviteEmailSent  bool        `json:"invite_email_sent,omitempty"`
	InviteEmailError string      `json:"invite_email_error,omitempty"`
}

func NewUserService(db *gorm.DB) UserService {
	return UserService{db: db}
}

func NewUserServiceWithOptions(db *gorm.DB, emailSender EmailSender, invitationBaseURL string) UserService {
	return UserService{db: db, emailSender: emailSender, invitationBaseURL: invitationBaseURL}
}

func (s UserService) ListOrganizationUsers(ctx context.Context, organizationID string) ([]OrganizationUser, error) {
	var memberships []domain.OrganizationMembership
	err := s.db.WithContext(ctx).
		Preload("User").
		Where("organization_id = ?", organizationID).
		Find(&memberships).
		Error
	if err != nil {
		return nil, err
	}

	users := make([]OrganizationUser, 0, len(memberships))
	for _, membership := range memberships {
		users = append(users, OrganizationUser{
			UserID:         membership.UserID,
			OrganizationID: membership.OrganizationID,
			Name:           membership.User.Name,
			Email:          membership.User.Email,
			Role:           membership.Role,
			IsActive:       membership.User.IsActive,
		})
	}
	return users, nil
}

func (s UserService) CreateOrganizationUser(ctx context.Context, input CreateOrganizationUserInput) (OrganizationUser, error) {
	passwordHash, err := bcrypt.GenerateFromPassword([]byte(input.Password), bcrypt.DefaultCost)
	if err != nil {
		return OrganizationUser{}, err
	}

	role := input.Role
	if role == "" {
		role = domain.RoleViewer
	}

	var result OrganizationUser
	var organization domain.Organization
	err = s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.First(&organization, "id = ?", input.OrganizationID).Error; err != nil {
			return err
		}

		var user domain.User
		err := tx.Where("email = ?", input.Email).First(&user).Error
		switch {
		case err == nil:
		case errors.Is(err, gorm.ErrRecordNotFound):
			user = domain.User{
				Name:         input.Name,
				Email:        input.Email,
				PasswordHash: string(passwordHash),
				IsActive:     true,
			}
			if err := tx.Create(&user).Error; err != nil {
				return err
			}
		default:
			return err
		}

		var existing int64
		if err := tx.Model(&domain.OrganizationMembership{}).
			Where("organization_id = ? AND user_id = ?", input.OrganizationID, user.ID).
			Count(&existing).
			Error; err != nil {
			return err
		}
		if existing > 0 {
			return ErrUserAlreadyMember
		}

		membership := domain.OrganizationMembership{
			OrganizationID: input.OrganizationID,
			UserID:         user.ID,
			Role:           role,
		}
		if err := tx.Create(&membership).Error; err != nil {
			return err
		}

		result = OrganizationUser{
			UserID:         user.ID,
			OrganizationID: input.OrganizationID,
			Name:           user.Name,
			Email:          user.Email,
			Role:           role,
			IsActive:       user.IsActive,
		}
		return recordAuditWithTx(ctx, tx, RecordAuditInput{
			OrganizationID: input.OrganizationID,
			EntityType:     "organization_membership",
			EntityID:       membership.ID,
			Action:         "create",
			After:          result,
		})
	})
	if err != nil {
		return result, err
	}
	if s.emailSender != nil {
		if err := s.emailSender.Send(ctx, s.invitationEmail(result, organization.Name)); err != nil {
			result.InviteEmailError = err.Error()
		} else {
			result.InviteEmailSent = true
		}
	}
	return result, nil
}

func (s UserService) invitationEmail(user OrganizationUser, organizationName string) EmailMessage {
	link := strings.TrimSpace(s.invitationBaseURL)
	body := "You have been added to " + organizationName + " in AbhashTech Accounting as " + string(user.Role) + ".\n\n"
	if link != "" {
		body += "Open the app here:\n" + link + "\n\n"
	}
	body += "Use the email address " + user.Email + " to sign in. If you do not have your temporary password, contact your organization admin or use the password reset flow.\n"
	return EmailMessage{
		To:      user.Email,
		Subject: "You have been invited to AbhashTech Accounting",
		Text:    body,
	}
}
