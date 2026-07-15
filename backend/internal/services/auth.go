package services

import (
	"context"
	"errors"
	"net/url"
	"strings"
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
	ErrMFARequired         = errors.New("multi-factor authentication code is required")
	ErrInvalidMFACode      = errors.New("invalid multi-factor authentication code")
)

type AuthService struct {
	db                       *gorm.DB
	tokens                   auth.TokenManager
	mfaEncryptionKey         string
	emailSender              EmailSender
	passwordResetBaseURL     string
	exposePasswordResetToken bool
}

type AuthResult struct {
	AccessToken  string
	RefreshToken string
	TokenType    string
	ExpiresIn    int64
}

type MFASetupResult struct {
	Secret     string `json:"secret"`
	OTPAuthURL string `json:"otpauth_url"`
	MFAEnabled bool   `json:"mfa_enabled"`
}

type MFAStatusResult struct {
	MFAEnabled    bool     `json:"mfa_enabled"`
	RecoveryCodes []string `json:"recovery_codes,omitempty"`
}

type PasswordResetRequestResult struct {
	Requested       bool       `json:"requested"`
	EmailSent       bool       `json:"email_sent"`
	ResetToken      string     `json:"reset_token,omitempty"`
	ResetTokenUntil *time.Time `json:"reset_token_expires_at,omitempty"`
}

type AuthServiceOptions struct {
	MFAEncryptionKey         string
	EmailSender              EmailSender
	PasswordResetBaseURL     string
	ExposePasswordResetToken bool
}

func NewAuthService(db *gorm.DB, tokens auth.TokenManager, mfaEncryptionKey ...string) AuthService {
	key := ""
	if len(mfaEncryptionKey) > 0 {
		key = mfaEncryptionKey[0]
	}
	return NewAuthServiceWithOptions(db, tokens, AuthServiceOptions{
		MFAEncryptionKey:         key,
		ExposePasswordResetToken: true,
	})
}

func NewAuthServiceWithOptions(db *gorm.DB, tokens auth.TokenManager, options AuthServiceOptions) AuthService {
	return AuthService{
		db:                       db,
		tokens:                   tokens,
		mfaEncryptionKey:         options.MFAEncryptionKey,
		emailSender:              options.EmailSender,
		passwordResetBaseURL:     options.PasswordResetBaseURL,
		exposePasswordResetToken: options.ExposePasswordResetToken,
	}
}

func (s AuthService) Login(ctx context.Context, email string, password string, mfaCode ...string) (AuthResult, error) {
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
	if user.MFAEnabled {
		secret, err := s.mfaSecret(user.MFASecret)
		if err != nil {
			return AuthResult{}, err
		}
		code := ""
		if len(mfaCode) > 0 {
			code = mfaCode[0]
		}
		if code == "" {
			return AuthResult{}, ErrMFARequired
		}
		if err := validateMFACode(secret, code); err != nil {
			if err := s.consumeMFARecoveryCode(ctx, user.ID, code); err != nil {
				return AuthResult{}, ErrInvalidMFACode
			}
		}
	}

	return s.issueTokens(ctx, user)
}

func (s AuthService) SetupMFA(ctx context.Context, userID string) (MFASetupResult, error) {
	var user domain.User
	if err := s.db.WithContext(ctx).Where("id = ? AND is_active = ?", userID, true).First(&user).Error; err != nil {
		return MFASetupResult{}, err
	}
	secret, err := s.mfaSecret(user.MFASecret)
	if err != nil {
		return MFASetupResult{}, err
	}
	if secret == "" || user.MFAEnabled {
		nextSecret, err := generateMFASecret()
		if err != nil {
			return MFASetupResult{}, err
		}
		secret = nextSecret
		storedSecret, err := s.storeMFASecret(secret)
		if err != nil {
			return MFASetupResult{}, err
		}
		if err := s.db.WithContext(ctx).Model(&user).Updates(map[string]any{
			"mfa_secret":  storedSecret,
			"mfa_enabled": false,
		}).Error; err != nil {
			return MFASetupResult{}, err
		}
	}
	return MFASetupResult{
		Secret:     secret,
		OTPAuthURL: mfaProvisioningURI(user.Email, "AbhashTech Accounting", secret),
		MFAEnabled: false,
	}, nil
}

func (s AuthService) EnableMFA(ctx context.Context, userID string, code string) (MFAStatusResult, error) {
	var user domain.User
	if err := s.db.WithContext(ctx).Where("id = ? AND is_active = ?", userID, true).First(&user).Error; err != nil {
		return MFAStatusResult{}, err
	}
	secret, err := s.mfaSecret(user.MFASecret)
	if err != nil {
		return MFAStatusResult{}, err
	}
	if err := validateMFACode(secret, code); err != nil {
		return MFAStatusResult{}, ErrInvalidMFACode
	}
	recoveryCodes, err := generateMFARecoveryCodes(10)
	if err != nil {
		return MFAStatusResult{}, err
	}
	err = s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Model(&user).Update("mfa_enabled", true).Error; err != nil {
			return err
		}
		return s.replaceMFARecoveryCodes(tx, user.ID, recoveryCodes)
	})
	if err != nil {
		return MFAStatusResult{}, err
	}
	return MFAStatusResult{MFAEnabled: true, RecoveryCodes: recoveryCodes}, nil
}

func (s AuthService) DisableMFA(ctx context.Context, userID string, code string) error {
	var user domain.User
	if err := s.db.WithContext(ctx).Where("id = ? AND is_active = ?", userID, true).First(&user).Error; err != nil {
		return err
	}
	if user.MFAEnabled {
		if err := s.validateMFAOrRecoveryCode(ctx, user, code); err != nil {
			return ErrInvalidMFACode
		}
	}
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Model(&user).Updates(map[string]any{
			"mfa_enabled": false,
			"mfa_secret":  "",
		}).Error; err != nil {
			return err
		}
		return tx.Where("user_id = ?", user.ID).Delete(&domain.MFARecoveryCode{}).Error
	})
}

func (s AuthService) RegenerateMFARecoveryCodes(ctx context.Context, userID string, code string) (MFAStatusResult, error) {
	var user domain.User
	if err := s.db.WithContext(ctx).Where("id = ? AND is_active = ?", userID, true).First(&user).Error; err != nil {
		return MFAStatusResult{}, err
	}
	if !user.MFAEnabled {
		return MFAStatusResult{}, ErrMFARequired
	}
	secret, err := s.mfaSecret(user.MFASecret)
	if err != nil {
		return MFAStatusResult{}, err
	}
	if err := validateMFACode(secret, code); err != nil {
		return MFAStatusResult{}, ErrInvalidMFACode
	}
	recoveryCodes, err := generateMFARecoveryCodes(10)
	if err != nil {
		return MFAStatusResult{}, err
	}
	if err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		return s.replaceMFARecoveryCodes(tx, user.ID, recoveryCodes)
	}); err != nil {
		return MFAStatusResult{}, err
	}
	return MFAStatusResult{MFAEnabled: true, RecoveryCodes: recoveryCodes}, nil
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

func (s AuthService) RevokeRefreshToken(ctx context.Context, rawRefreshToken string) error {
	tokenHash := auth.HashToken(rawRefreshToken)
	now := time.Now().UTC()
	result := s.db.WithContext(ctx).
		Model(&domain.RefreshToken{}).
		Where("token_hash = ? AND revoked_at IS NULL", tokenHash).
		Update("revoked_at", now)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return ErrInvalidRefreshToken
	}
	return nil
}

func (s AuthService) RevokeUserSessions(ctx context.Context, userID string) (int64, error) {
	now := time.Now().UTC()
	result := s.db.WithContext(ctx).
		Model(&domain.RefreshToken{}).
		Where("user_id = ? AND revoked_at IS NULL", userID).
		Update("revoked_at", now)
	return result.RowsAffected, result.Error
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
	result := PasswordResetRequestResult{
		Requested:       true,
		ResetTokenUntil: &expiresAt,
	}
	if s.emailSender != nil {
		if err := s.emailSender.Send(ctx, s.passwordResetEmail(user, rawToken, expiresAt)); err != nil {
			return PasswordResetRequestResult{}, err
		}
		result.EmailSent = true
	}
	if s.exposePasswordResetToken || s.emailSender == nil {
		result.ResetToken = rawToken
	}
	return result, nil
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

func (s AuthService) validateMFAOrRecoveryCode(ctx context.Context, user domain.User, code string) error {
	secret, err := s.mfaSecret(user.MFASecret)
	if err != nil {
		return err
	}
	if err := validateMFACode(secret, code); err == nil {
		return nil
	}
	return s.consumeMFARecoveryCode(ctx, user.ID, code)
}

func (s AuthService) mfaSecret(stored string) (string, error) {
	return decryptMFASecret(stored, s.mfaEncryptionKey)
}

func (s AuthService) storeMFASecret(secret string) (string, error) {
	if strings.TrimSpace(s.mfaEncryptionKey) == "" {
		return secret, nil
	}
	return encryptMFASecret(secret, s.mfaEncryptionKey)
}

func (s AuthService) passwordResetEmail(user domain.User, rawToken string, expiresAt time.Time) EmailMessage {
	resetLink := strings.TrimRight(s.passwordResetBaseURL, "/")
	if resetLink != "" {
		resetLink += "?token=" + url.QueryEscape(rawToken)
	}
	body := "A password reset was requested for your AbhashTech Accounting account.\n\n"
	if resetLink != "" {
		body += "Reset your password using this link:\n" + resetLink + "\n\n"
	} else {
		body += "Use this reset token:\n" + rawToken + "\n\n"
	}
	body += "This reset link expires at " + expiresAt.Format(time.RFC3339) + ".\n"
	body += "If you did not request this reset, you can ignore this email.\n"
	return EmailMessage{
		To:      user.Email,
		Subject: "Reset your AbhashTech Accounting password",
		Text:    body,
	}
}

func (s AuthService) replaceMFARecoveryCodes(tx *gorm.DB, userID string, codes []string) error {
	if err := tx.Where("user_id = ?", userID).Delete(&domain.MFARecoveryCode{}).Error; err != nil {
		return err
	}
	records := make([]domain.MFARecoveryCode, 0, len(codes))
	for _, code := range codes {
		records = append(records, domain.MFARecoveryCode{
			UserID:   userID,
			CodeHash: hashMFARecoveryCode(code),
		})
	}
	if len(records) == 0 {
		return nil
	}
	return tx.Create(&records).Error
}

func (s AuthService) consumeMFARecoveryCode(ctx context.Context, userID string, code string) error {
	normalized := normalizeMFARecoveryCode(code)
	if normalized == "" {
		return ErrInvalidMFACode
	}
	now := time.Now().UTC()
	result := s.db.WithContext(ctx).
		Model(&domain.MFARecoveryCode{}).
		Where("user_id = ? AND code_hash = ? AND used_at IS NULL", userID, auth.HashToken(normalized)).
		Update("used_at", now)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return ErrInvalidMFACode
	}
	return nil
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
