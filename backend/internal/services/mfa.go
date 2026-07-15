package services

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha1"
	"encoding/base32"
	"encoding/base64"
	"encoding/binary"
	"errors"
	"fmt"
	"math"
	"net/url"
	"strconv"
	"strings"
	"time"

	"accounting.abhashtech.com/internal/auth"
)

const (
	totpStepSeconds    = int64(30)
	totpDigits         = 6
	mfaRecoveryCodeLen = 10
	mfaEncryptedPrefix = "enc:v1:"
)

func generateMFASecret() (string, error) {
	buffer := make([]byte, 20)
	if _, err := rand.Read(buffer); err != nil {
		return "", err
	}
	return base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString(buffer), nil
}

func mfaProvisioningURI(email string, issuer string, secret string) string {
	values := url.Values{}
	values.Set("secret", secret)
	values.Set("issuer", issuer)
	values.Set("algorithm", "SHA1")
	values.Set("digits", strconv.Itoa(totpDigits))
	values.Set("period", strconv.FormatInt(totpStepSeconds, 10))
	return "otpauth://totp/" + url.PathEscape(issuer+":"+email) + "?" + values.Encode()
}

func verifyTOTP(secret string, code string, now time.Time) bool {
	code = strings.TrimSpace(code)
	if len(code) != totpDigits {
		return false
	}
	for offset := int64(-1); offset <= 1; offset++ {
		expected, err := totpCode(secret, now.Add(time.Duration(offset*totpStepSeconds)*time.Second))
		if err == nil && hmac.Equal([]byte(expected), []byte(code)) {
			return true
		}
	}
	return false
}

func totpCode(secret string, now time.Time) (string, error) {
	decoded, err := base32.StdEncoding.WithPadding(base32.NoPadding).DecodeString(strings.ToUpper(strings.TrimSpace(secret)))
	if err != nil {
		return "", err
	}
	counter := uint64(math.Floor(float64(now.Unix()) / float64(totpStepSeconds)))
	payload := make([]byte, 8)
	binary.BigEndian.PutUint64(payload, counter)
	mac := hmac.New(sha1.New, decoded)
	if _, err := mac.Write(payload); err != nil {
		return "", err
	}
	sum := mac.Sum(nil)
	offset := sum[len(sum)-1] & 0x0f
	binaryCode := (int(sum[offset])&0x7f)<<24 |
		(int(sum[offset+1])&0xff)<<16 |
		(int(sum[offset+2])&0xff)<<8 |
		(int(sum[offset+3]) & 0xff)
	modulo := int(math.Pow10(totpDigits))
	return fmt.Sprintf("%0*d", totpDigits, binaryCode%modulo), nil
}

func validateMFACode(secret string, code string) error {
	if secret == "" || !verifyTOTP(secret, code, time.Now().UTC()) {
		return errors.New("invalid MFA code")
	}
	return nil
}

func encryptMFASecret(secret string, rawKey string) (string, error) {
	key, err := parseMFAEncryptionKey(rawKey)
	if err != nil {
		return "", err
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return "", err
	}
	sealed := gcm.Seal(nonce, nonce, []byte(secret), nil)
	return mfaEncryptedPrefix + base64.RawURLEncoding.EncodeToString(sealed), nil
}

func decryptMFASecret(stored string, rawKey string) (string, error) {
	if !isEncryptedMFASecret(stored) {
		return stored, nil
	}
	key, err := parseMFAEncryptionKey(rawKey)
	if err != nil {
		return "", err
	}
	payload, err := base64.RawURLEncoding.DecodeString(strings.TrimPrefix(stored, mfaEncryptedPrefix))
	if err != nil {
		return "", err
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	if len(payload) < gcm.NonceSize() {
		return "", errors.New("encrypted MFA secret payload is too short")
	}
	nonce := payload[:gcm.NonceSize()]
	ciphertext := payload[gcm.NonceSize():]
	plaintext, err := gcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return "", err
	}
	return string(plaintext), nil
}

func isEncryptedMFASecret(stored string) bool {
	return strings.HasPrefix(stored, mfaEncryptedPrefix)
}

func parseMFAEncryptionKey(rawKey string) ([]byte, error) {
	rawKey = strings.TrimSpace(rawKey)
	if rawKey == "" {
		return nil, errors.New("MFA encryption key is required")
	}
	key, err := base64.StdEncoding.DecodeString(rawKey)
	if err != nil {
		key, err = base64.RawStdEncoding.DecodeString(rawKey)
	}
	if err != nil {
		key, err = base64.RawURLEncoding.DecodeString(rawKey)
	}
	if err != nil {
		return nil, errors.New("MFA encryption key must be base64 encoded")
	}
	if len(key) != 32 {
		return nil, errors.New("MFA encryption key must decode to 32 bytes")
	}
	return key, nil
}

func generateMFARecoveryCodes(count int) ([]string, error) {
	codes := make([]string, 0, count)
	for range count {
		buffer := make([]byte, mfaRecoveryCodeLen)
		if _, err := rand.Read(buffer); err != nil {
			return nil, err
		}
		encoded := base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString(buffer)
		encoded = strings.ToUpper(encoded[:mfaRecoveryCodeLen])
		codes = append(codes, encoded[:5]+"-"+encoded[5:])
	}
	return codes, nil
}

func normalizeMFARecoveryCode(code string) string {
	code = strings.ToUpper(strings.TrimSpace(code))
	code = strings.ReplaceAll(code, "-", "")
	code = strings.ReplaceAll(code, " ", "")
	return code
}

func hashMFARecoveryCode(code string) string {
	return auth.HashToken(normalizeMFARecoveryCode(code))
}
