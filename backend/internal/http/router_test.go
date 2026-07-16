package http

import (
	"bytes"
	"encoding/json"
	"io"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"accounting.abhashtech.com/internal/auth"
	"accounting.abhashtech.com/internal/domain"
	"github.com/gin-gonic/gin"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func TestOrganizationRoutesRequireAuth(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db := routerTestDB(t)
	router := NewRouter(RouterConfig{
		DB:             db,
		SwaggerEnabled: false,
		Tokens:         auth.NewTokenManager("access-secret", "refresh-secret", time.Minute, time.Hour),
	})

	request := httptest.NewRequest(http.MethodGet, "/api/v1/organizations", nil)
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)

	if response.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusUnauthorized)
	}
}

func TestViewerCannotCreateAccount(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db := routerTestDB(t)
	tokens := auth.NewTokenManager("access-secret", "refresh-secret", time.Minute, time.Hour)

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	user := domain.User{Email: "viewer@example.com", Name: "Viewer", PasswordHash: "unused", IsActive: true}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}

	accessToken, err := tokens.NewAccessToken(user, map[string]domain.Role{org.ID: domain.RoleViewer})
	if err != nil {
		t.Fatalf("create access token: %v", err)
	}

	router := NewRouter(RouterConfig{
		DB:             db,
		SwaggerEnabled: false,
		Tokens:         tokens,
	})
	request := httptest.NewRequest(http.MethodPost, "/api/v1/organizations/"+org.ID+"/accounts", nil)
	request.Header.Set("Authorization", "Bearer "+accessToken)
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)

	if response.Code != http.StatusForbidden {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusForbidden)
	}
}

func TestOrganizationRoutePermissionMatrix(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db := routerTestDB(t)
	tokens := auth.NewTokenManager("access-secret", "refresh-secret", time.Minute, time.Hour)
	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}

	router := NewRouter(RouterConfig{
		DB:             db,
		SwaggerEnabled: false,
		Tokens:         tokens,
	})

	tests := []struct {
		name       string
		role       domain.Role
		method     string
		path       string
		body       string
		wantStatus int
	}{
		{name: "viewer can read accounts", role: domain.RoleViewer, method: http.MethodGet, path: "/accounts", wantStatus: http.StatusOK},
		{name: "viewer cannot write accounts", role: domain.RoleViewer, method: http.MethodPost, path: "/accounts", body: `{}`, wantStatus: http.StatusForbidden},
		{name: "bookkeeper reaches account write handler", role: domain.RoleBookkeeper, method: http.MethodPost, path: "/accounts", body: `{}`, wantStatus: http.StatusBadRequest},
		{name: "bookkeeper cannot write payroll", role: domain.RoleBookkeeper, method: http.MethodPost, path: "/payroll/runs", body: `{}`, wantStatus: http.StatusForbidden},
		{name: "payroll manager reaches payroll write handler", role: domain.RolePayrollManager, method: http.MethodPost, path: "/payroll/runs", body: `{}`, wantStatus: http.StatusBadRequest},
		{name: "payroll manager can read payroll", role: domain.RolePayrollManager, method: http.MethodGet, path: "/payroll/runs", wantStatus: http.StatusOK},
		{name: "accountant can read organization users", role: domain.RoleAccountant, method: http.MethodGet, path: "/users", wantStatus: http.StatusOK},
		{name: "accountant cannot create organization users", role: domain.RoleAccountant, method: http.MethodPost, path: "/users", body: `{}`, wantStatus: http.StatusForbidden},
		{name: "accountant cannot update organization users", role: domain.RoleAccountant, method: http.MethodPatch, path: "/users/00000000-0000-0000-0000-000000000001", body: `{}`, wantStatus: http.StatusForbidden},
		{name: "admin reaches organization user write handler", role: domain.RoleAdmin, method: http.MethodPost, path: "/users", body: `{}`, wantStatus: http.StatusBadRequest},
		{name: "admin reaches organization user update handler", role: domain.RoleAdmin, method: http.MethodPatch, path: "/users/00000000-0000-0000-0000-000000000001", body: `{}`, wantStatus: http.StatusNotFound},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			accessToken := mustAccessToken(t, tokens, map[string]domain.Role{org.ID: test.role})
			var body io.Reader
			if test.body != "" {
				body = strings.NewReader(test.body)
			}
			request := httptest.NewRequest(test.method, "/api/v1/organizations/"+org.ID+test.path, body)
			request.Header.Set("Authorization", "Bearer "+accessToken)
			if test.body != "" {
				request.Header.Set("Content-Type", "application/json")
			}
			response := httptest.NewRecorder()
			router.ServeHTTP(response, request)
			if response.Code != test.wantStatus {
				t.Fatalf("status = %d, want %d; body=%s", response.Code, test.wantStatus, response.Body.String())
			}
		})
	}
}

func TestOrganizationRoutesDenyCrossTenantAccess(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db := routerTestDB(t)
	tokens := auth.NewTokenManager("access-secret", "refresh-secret", time.Minute, time.Hour)
	orgOne := domain.Organization{Name: "Acme One", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	orgTwo := domain.Organization{Name: "Acme Two", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	if err := db.Create(&orgOne).Error; err != nil {
		t.Fatalf("create org one: %v", err)
	}
	if err := db.Create(&orgTwo).Error; err != nil {
		t.Fatalf("create org two: %v", err)
	}

	router := NewRouter(RouterConfig{
		DB:             db,
		SwaggerEnabled: false,
		Tokens:         tokens,
	})
	accessToken := mustAccessToken(t, tokens, map[string]domain.Role{orgOne.ID: domain.RoleAdmin})

	request := httptest.NewRequest(http.MethodGet, "/api/v1/organizations/"+orgTwo.ID+"/accounts", nil)
	request.Header.Set("Authorization", "Bearer "+accessToken)
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)

	if response.Code != http.StatusForbidden {
		t.Fatalf("status = %d, want %d; body=%s", response.Code, http.StatusForbidden, response.Body.String())
	}
	if !strings.Contains(response.Body.String(), "organization_access_denied") {
		t.Fatalf("body = %s, want organization_access_denied", response.Body.String())
	}
}

func TestBookkeeperCanCreateAttachmentMetadata(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db := routerTestDB(t)
	tokens := auth.NewTokenManager("access-secret", "refresh-secret", time.Minute, time.Hour)

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	user := domain.User{Email: "bookkeeper@example.com", Name: "Bookkeeper", PasswordHash: "unused", IsActive: true}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}

	accessToken, err := tokens.NewAccessToken(user, map[string]domain.Role{org.ID: domain.RoleBookkeeper})
	if err != nil {
		t.Fatalf("create access token: %v", err)
	}

	router := NewRouter(RouterConfig{
		DB:             db,
		SwaggerEnabled: false,
		Tokens:         tokens,
	})
	request := httptest.NewRequest(
		http.MethodPost,
		"/api/v1/organizations/"+org.ID+"/attachments",
		strings.NewReader(`{"file_name":"receipt.jpg","content_type":"image/jpeg","storage_key":"receipts/receipt.jpg","size_bytes":2048}`),
	)
	request.Header.Set("Authorization", "Bearer "+accessToken)
	request.Header.Set("Content-Type", "application/json")
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)

	if response.Code != http.StatusCreated {
		t.Fatalf("status = %d, want %d; body=%s", response.Code, http.StatusCreated, response.Body.String())
	}
	var attachment domain.Attachment
	if err := json.Unmarshal(response.Body.Bytes(), &attachment); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if attachment.FileName != "receipt.jpg" {
		t.Fatalf("file name = %s, want receipt.jpg", attachment.FileName)
	}
}

func TestViewerCannotCreateAttachmentMetadata(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db := routerTestDB(t)
	tokens := auth.NewTokenManager("access-secret", "refresh-secret", time.Minute, time.Hour)

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	user := domain.User{Email: "viewer2@example.com", Name: "Viewer", PasswordHash: "unused", IsActive: true}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}

	accessToken, err := tokens.NewAccessToken(user, map[string]domain.Role{org.ID: domain.RoleViewer})
	if err != nil {
		t.Fatalf("create access token: %v", err)
	}

	router := NewRouter(RouterConfig{
		DB:             db,
		SwaggerEnabled: false,
		Tokens:         tokens,
	})
	request := httptest.NewRequest(
		http.MethodPost,
		"/api/v1/organizations/"+org.ID+"/attachments",
		strings.NewReader(`{"file_name":"receipt.jpg","storage_key":"receipts/receipt.jpg"}`),
	)
	request.Header.Set("Authorization", "Bearer "+accessToken)
	request.Header.Set("Content-Type", "application/json")
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)

	if response.Code != http.StatusForbidden {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusForbidden)
	}
}

func TestLegacyBankStatementImportRouteIsRegistered(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db := routerTestDB(t)
	tokens := auth.NewTokenManager("access-secret", "refresh-secret", time.Minute, time.Hour)

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	user := domain.User{Email: "bookkeeper-import@example.com", Name: "Bookkeeper", PasswordHash: "unused", IsActive: true}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}

	accessToken, err := tokens.NewAccessToken(user, map[string]domain.Role{org.ID: domain.RoleBookkeeper})
	if err != nil {
		t.Fatalf("create access token: %v", err)
	}

	router := NewRouter(RouterConfig{
		DB:             db,
		SwaggerEnabled: false,
		Tokens:         tokens,
	})
	request := httptest.NewRequest(
		http.MethodPost,
		"/api/v1/organizations/"+org.ID+"/imports/bank-statements",
		strings.NewReader(`{}`),
	)
	request.Header.Set("Authorization", "Bearer "+accessToken)
	request.Header.Set("Content-Type", "application/json")
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)

	if response.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d; body=%s", response.Code, http.StatusBadRequest, response.Body.String())
	}
	if !strings.Contains(response.Body.String(), "invalid_request") {
		t.Fatalf("body = %s, want invalid_request", response.Body.String())
	}
}

func TestBookkeeperCanUploadAndDownloadAttachment(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db := routerTestDB(t)
	tokens := auth.NewTokenManager("access-secret", "refresh-secret", time.Minute, time.Hour)

	org := domain.Organization{Name: "Acme India", BaseCurrency: "INR", CountryCode: "IN", FiscalYearStartMonth: 4}
	user := domain.User{Email: "uploader@example.com", Name: "Uploader", PasswordHash: "unused", IsActive: true}
	if err := db.Create(&org).Error; err != nil {
		t.Fatalf("create organization: %v", err)
	}
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}

	accessToken, err := tokens.NewAccessToken(user, map[string]domain.Role{org.ID: domain.RoleBookkeeper})
	if err != nil {
		t.Fatalf("create access token: %v", err)
	}

	router := NewRouter(RouterConfig{
		DB:                      db,
		SwaggerEnabled:          false,
		Tokens:                  tokens,
		AttachmentStorageDriver: "local",
		AttachmentStoragePath:   t.TempDir(),
	})

	var body bytes.Buffer
	writer := multipart.NewWriter(&body)
	part, err := writer.CreateFormFile("file", "receipt.txt")
	if err != nil {
		t.Fatalf("create form file: %v", err)
	}
	if _, err := part.Write([]byte("hello receipt")); err != nil {
		t.Fatalf("write form file: %v", err)
	}
	if err := writer.Close(); err != nil {
		t.Fatalf("close multipart writer: %v", err)
	}

	uploadRequest := httptest.NewRequest(
		http.MethodPost,
		"/api/v1/organizations/"+org.ID+"/attachments/upload",
		&body,
	)
	uploadRequest.Header.Set("Authorization", "Bearer "+accessToken)
	uploadRequest.Header.Set("Content-Type", writer.FormDataContentType())
	uploadResponse := httptest.NewRecorder()
	router.ServeHTTP(uploadResponse, uploadRequest)

	if uploadResponse.Code != http.StatusCreated {
		t.Fatalf("upload status = %d, want %d; body=%s", uploadResponse.Code, http.StatusCreated, uploadResponse.Body.String())
	}
	var attachment domain.Attachment
	if err := json.Unmarshal(uploadResponse.Body.Bytes(), &attachment); err != nil {
		t.Fatalf("decode upload response: %v", err)
	}
	if attachment.FileName != "receipt.txt" {
		t.Fatalf("file name = %s, want receipt.txt", attachment.FileName)
	}
	if attachment.SizeBytes != int64(len("hello receipt")) {
		t.Fatalf("size bytes = %d, want %d", attachment.SizeBytes, len("hello receipt"))
	}
	if !strings.Contains(attachment.StorageKey, org.ID) || !strings.Contains(attachment.StorageKey, attachment.ID) {
		t.Fatalf("storage key = %s, want org and attachment ids", attachment.StorageKey)
	}

	downloadRequest := httptest.NewRequest(
		http.MethodGet,
		"/api/v1/organizations/"+org.ID+"/attachments/"+attachment.ID+"/download",
		nil,
	)
	downloadRequest.Header.Set("Authorization", "Bearer "+accessToken)
	downloadResponse := httptest.NewRecorder()
	router.ServeHTTP(downloadResponse, downloadRequest)

	if downloadResponse.Code != http.StatusOK {
		t.Fatalf("download status = %d, want %d; body=%s", downloadResponse.Code, http.StatusOK, downloadResponse.Body.String())
	}
	downloaded, err := io.ReadAll(downloadResponse.Body)
	if err != nil {
		t.Fatalf("read download body: %v", err)
	}
	if string(downloaded) != "hello receipt" {
		t.Fatalf("downloaded body = %q, want %q", string(downloaded), "hello receipt")
	}
}

func routerTestDB(t *testing.T) *gorm.DB {
	t.Helper()

	name := strings.NewReplacer("/", "_", " ", "_").Replace(t.Name())
	db, err := gorm.Open(sqlite.Open("file:"+name+"?mode=memory&cache=shared"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open test database: %v", err)
	}
	if err := db.AutoMigrate(domain.AllModels()...); err != nil {
		t.Fatalf("auto migrate test database: %v", err)
	}
	return db
}

func mustAccessToken(t *testing.T, tokens auth.TokenManager, roles map[string]domain.Role) string {
	t.Helper()
	user := domain.User{
		BaseModel: domain.BaseModel{ID: "test-user-id"},
		Email:     "test-user@example.com",
		Name:      "Test User",
		IsActive:  true,
	}
	accessToken, err := tokens.NewAccessToken(user, roles)
	if err != nil {
		t.Fatalf("create access token: %v", err)
	}
	return accessToken
}
