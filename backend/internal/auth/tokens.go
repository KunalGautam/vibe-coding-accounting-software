package auth

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

type TokenManager struct {
	accessSecret  []byte
	refreshSecret []byte
	accessTTL     time.Duration
	refreshTTL    time.Duration
}

type AccessClaims struct {
	UserID            string                 `json:"user_id"`
	Email             string                 `json:"email"`
	OrganizationRoles map[string]domain.Role `json:"organization_roles"`
	jwt.RegisteredClaims
}

func NewTokenManager(accessSecret string, refreshSecret string, accessTTL time.Duration, refreshTTL time.Duration) TokenManager {
	return TokenManager{
		accessSecret:  []byte(accessSecret),
		refreshSecret: []byte(refreshSecret),
		accessTTL:     accessTTL,
		refreshTTL:    refreshTTL,
	}
}

func (m TokenManager) AccessTTL() time.Duration {
	return m.accessTTL
}

func (m TokenManager) RefreshTTL() time.Duration {
	return m.refreshTTL
}

func (m TokenManager) NewAccessToken(user domain.User, roles map[string]domain.Role) (string, error) {
	now := time.Now().UTC()
	claims := AccessClaims{
		UserID:            user.ID,
		Email:             user.Email,
		OrganizationRoles: roles,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   user.ID,
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(m.accessTTL)),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(m.accessSecret)
}

func (m TokenManager) ParseAccessToken(rawToken string) (AccessClaims, error) {
	token, err := jwt.ParseWithClaims(rawToken, &AccessClaims{}, func(token *jwt.Token) (any, error) {
		if token.Method != jwt.SigningMethodHS256 {
			return nil, errors.New("unexpected signing method")
		}
		return m.accessSecret, nil
	})
	if err != nil {
		return AccessClaims{}, err
	}

	claims, ok := token.Claims.(*AccessClaims)
	if !ok || !token.Valid {
		return AccessClaims{}, errors.New("invalid access token")
	}
	return *claims, nil
}

func (m TokenManager) NewRefreshToken() (string, string, time.Time) {
	raw := uuid.NewString() + "." + uuid.NewString()
	expiresAt := time.Now().UTC().Add(m.refreshTTL)
	return raw, HashToken(raw), expiresAt
}

func HashToken(raw string) string {
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:])
}
