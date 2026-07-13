package services

import (
	"context"
	"errors"
	"time"

	"accounting.abhashtech.com/internal/auth"
	"accounting.abhashtech.com/internal/domain"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

var (
	ErrInvalidCredentials  = errors.New("invalid email or password")
	ErrInvalidRefreshToken = errors.New("invalid refresh token")
	ErrInvalidResetToken   = errors.New("invalid or expired password reset token")
)

type AuthService struct {
	db     *gorm.DB
	tokens auth.TokenManager
}

type AuthResult struct {
	AccessToken  string
	RefreshToken string
	TokenType    string
	ExpiresIn    int64
}

type PasswordResetRequestResult struct {
	Requested       bool       `json:"requested"`
	ResetToken      string     `json:"reset_token,omitempty"`
	ResetTokenUntil *time.Time `json:"reset_token_expires_at,omitempty"`
}

func NewAuthService(db *gorm.DB, tokens auth.TokenManager) AuthService {
	return AuthService{db: db, tokens: tokens}
}

func (s AuthService) Login(ctx context.Context, email string, password string) (AuthResult, error) {
	var user domain.User
	if err := s.db.WithContext(ctx).Where("email = ? AND is_active = ?", email, true).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return AuthResult{}, ErrInvalidCredentials
		}
		return AuthResult{}, err
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		return AuthResult{}, ErrInvalidCredentials
	}

	return s.issueTokens(ctx, user)
}

func (s AuthService) Refresh(ctx context.Context, rawRefreshToken string) (AuthResult, error) {
	tokenHash := auth.HashToken(rawRefreshToken)

	var stored domain.RefreshToken
	if err := s.db.WithContext(ctx).
		Preload("User").
		Where("token_hash = ? AND revoked_at IS NULL AND expires_at > ?", tokenHash, time.Now().UTC()).
		First(&stored).
		Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return AuthResult{}, ErrInvalidRefreshToken
		}
		return AuthResult{}, err
	}

	now := time.Now().UTC()
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Model(&stored).Update("revoked_at", now).Error; err != nil {
			return err
		}
		return nil
	})
	if err != nil {
		return AuthResult{}, err
	}

	return s.issueTokens(ctx, stored.User)
}

func (s AuthService) RequestPasswordReset(ctx context.Context, email string) (PasswordResetRequestResult, error) {
	var user domain.User
	if err := s.db.WithContext(ctx).Where("email = ? AND is_active = ?", email, true).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return PasswordResetRequestResult{Requested: true}, nil
		}
		return PasswordResetRequestResult{}, err
	}

	rawToken := uuid.NewString() + "." + uuid.NewString()
	expiresAt := time.Now().UTC().Add(time.Hour)
	resetToken := domain.PasswordResetToken{
		UserID:    user.ID,
		TokenHash: auth.HashToken(rawToken),
		ExpiresAt: expiresAt,
	}
	if err := s.db.WithContext(ctx).Create(&resetToken).Error; err != nil {
		return PasswordResetRequestResult{}, err
	}
	return PasswordResetRequestResult{
		Requested:       true,
		ResetToken:      rawToken,
		ResetTokenUntil: &expiresAt,
	}, nil
}

func (s AuthService) ConfirmPasswordReset(ctx context.Context, rawResetToken string, newPassword string) error {
	tokenHash := auth.HashToken(rawResetToken)
	passwordHash, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		return err
	}

	now := time.Now().UTC()
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var resetToken domain.PasswordResetToken
		if err := tx.
			Where("token_hash = ? AND used_at IS NULL AND expires_at > ?", tokenHash, now).
			First(&resetToken).
			Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return ErrInvalidResetToken
			}
			return err
		}

		if err := tx.Model(&domain.User{}).Where("id = ?", resetToken.UserID).Update("password_hash", string(passwordHash)).Error; err != nil {
			return err
		}
		if err := tx.Model(&resetToken).Update("used_at", now).Error; err != nil {
			return err
		}
		return tx.Model(&domain.RefreshToken{}).
			Where("user_id = ? AND revoked_at IS NULL", resetToken.UserID).
			Update("revoked_at", now).
			Error
	})
}

func (s AuthService) issueTokens(ctx context.Context, user domain.User) (AuthResult, error) {
	roles, err := s.organizationRoles(ctx, user.ID)
	if err != nil {
		return AuthResult{}, err
	}

	accessToken, err := s.tokens.NewAccessToken(user, roles)
	if err != nil {
		return AuthResult{}, err
	}

	rawRefreshToken, refreshHash, refreshExpiresAt := s.tokens.NewRefreshToken()
	refreshToken := domain.RefreshToken{
		UserID:    user.ID,
		TokenHash: refreshHash,
		ExpiresAt: refreshExpiresAt,
	}
	if err := s.db.WithContext(ctx).Create(&refreshToken).Error; err != nil {
		return AuthResult{}, err
	}

	return AuthResult{
		AccessToken:  accessToken,
		RefreshToken: rawRefreshToken,
		TokenType:    "Bearer",
		ExpiresIn:    int64(s.tokens.AccessTTL().Seconds()),
	}, nil
}

func (s AuthService) organizationRoles(ctx context.Context, userID string) (map[string]domain.Role, error) {
	var memberships []domain.OrganizationMembership
	err := s.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Find(&memberships).
		Error
	if err != nil {
		return nil, err
	}

	roles := make(map[string]domain.Role, len(memberships))
	for _, membership := range memberships {
		roles[membership.OrganizationID] = membership.Role
	}
	return roles, nil
}
