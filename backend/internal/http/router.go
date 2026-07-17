package http

import (
	"errors"
	"log/slog"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"accounting.abhashtech.com/internal/auth"
	"accounting.abhashtech.com/internal/domain"
	"accounting.abhashtech.com/internal/http/handlers"
	"accounting.abhashtech.com/internal/services"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type RouterConfig struct {
	SwaggerEnabled                 bool
	DB                             *gorm.DB
	Tokens                         auth.TokenManager
	MFAEncryptionKey               string
	EmailSender                    services.EmailSender
	PasswordResetBaseURL           string
	InvitationBaseURL              string
	ExposePasswordResetToken       bool
	SelfServiceRegistrationEnabled bool
	CORSAllowedOrigins             string
	AttachmentStorageDriver        string
	AttachmentStoragePath          string
	AttachmentMaxUploadBytes       int64
	RateLimitEnabled               bool
	RateLimitRequests              int
	RateLimitWindow                time.Duration
	Logger                         *slog.Logger
	MetricsEnabled                 bool
	Metrics                        *HTTPMetrics
}

func NewRouter(cfg RouterConfig) *gin.Engine {
	router := gin.New()
	metrics := cfg.Metrics
	if metrics == nil {
		metrics = NewHTTPMetrics()
	}
	middleware := []gin.HandlerFunc{RequestIDMiddleware(), CORSMiddleware(cfg.CORSAllowedOrigins)}
	if cfg.MetricsEnabled {
		middleware = append(middleware, MetricsMiddleware(metrics))
	}
	middleware = append(middleware, StructuredLoggerMiddleware(cfg.Logger), gin.Recovery())
	router.Use(middleware...)

	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})
	if cfg.MetricsEnabled {
		router.GET("/metrics", metrics.Handler())
	}

	api := router.Group("/api/v1")
	api.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	seedService := services.NewSeedService(cfg.DB)
	authHandler := handlers.NewAuthHandler(services.NewAuthServiceWithOptions(cfg.DB, cfg.Tokens, services.AuthServiceOptions{
		MFAEncryptionKey:         cfg.MFAEncryptionKey,
		EmailSender:              cfg.EmailSender,
		PasswordResetBaseURL:     cfg.PasswordResetBaseURL,
		ExposePasswordResetToken: cfg.ExposePasswordResetToken,
	}))
	bootstrapHandler := handlers.NewBootstrapHandler(services.NewBootstrapService(cfg.DB), seedService, cfg.SelfServiceRegistrationEnabled)
	organizationHandler := handlers.NewOrganizationHandler(services.NewOrganizationService(cfg.DB))
	accountHandler := handlers.NewAccountHandler(services.NewAccountService(cfg.DB))
	ledgerHandler := handlers.NewLedgerHandler(services.NewLedgerService(cfg.DB))
	seedHandler := handlers.NewSeedHandler(seedService)
	taxHandler := handlers.NewTaxHandler(services.NewTaxService(cfg.DB))
	customerHandler := handlers.NewCustomerHandler(services.NewCustomerService(cfg.DB))
	invoiceHandler := handlers.NewInvoiceHandler(services.NewInvoiceService(cfg.DB, services.NewTaxService(cfg.DB)))
	recurringInvoiceHandler := handlers.NewRecurringInvoiceHandler(services.NewRecurringInvoiceService(cfg.DB, services.NewTaxService(cfg.DB)))
	vendorHandler := handlers.NewVendorHandler(services.NewVendorService(cfg.DB))
	expenseHandler := handlers.NewExpenseHandler(services.NewExpenseService(cfg.DB, services.NewTaxService(cfg.DB)))
	billHandler := handlers.NewBillHandler(services.NewBillService(cfg.DB, services.NewTaxService(cfg.DB)))
	paymentHandler := handlers.NewPaymentHandler(services.NewPaymentService(cfg.DB))
	commercialDocumentHandler := handlers.NewCommercialDocumentHandler(services.NewCommercialDocumentService(cfg.DB, services.NewTaxService(cfg.DB)))
	attachmentHandler := handlers.NewAttachmentHandler(
		services.NewAttachmentService(cfg.DB),
		cfg.AttachmentStorageDriver,
		cfg.AttachmentStoragePath,
		cfg.AttachmentMaxUploadBytes,
	)
	reportHandler := handlers.NewReportHandler(services.NewReportServiceWithEmail(cfg.DB, cfg.EmailSender))
	employeeHandler := handlers.NewEmployeeHandler(services.NewEmployeeService(cfg.DB))
	payrollHandler := handlers.NewPayrollHandler(services.NewPayrollService(cfg.DB))
	reconciliationHandler := handlers.NewReconciliationHandler(services.NewReconciliationService(cfg.DB))
	budgetHandler := handlers.NewBudgetHandler(services.NewBudgetService(cfg.DB))
	exchangeRateHandler := handlers.NewExchangeRateHandler(services.NewExchangeRateService(cfg.DB))
	investmentHandler := handlers.NewInvestmentHandler(services.NewInvestmentService(cfg.DB))
	revaluationHandler := handlers.NewRevaluationHandler(services.NewRevaluationService(cfg.DB))
	closingHandler := handlers.NewClosingHandler(services.NewClosingService(cfg.DB))
	auditHandler := handlers.NewAuditHandler(services.NewAuditService(cfg.DB))
	userHandler := handlers.NewUserHandler(services.NewUserServiceWithOptions(cfg.DB, cfg.EmailSender, cfg.InvitationBaseURL))
	dataExportHandler := handlers.NewDataExportHandler(services.NewDataExportService(cfg.DB))

	public := api.Group("")
	if cfg.RateLimitEnabled {
		public.Use(RateLimitMiddleware(cfg.RateLimitRequests, cfg.RateLimitWindow))
	}
	authHandler.RegisterRoutes(public)
	bootstrapHandler.RegisterRoutes(public)

	protected := api.Group("")
	protected.Use(AuthMiddleware(cfg.Tokens))
	authHandler.RegisterProtectedRoutes(protected)
	organizationHandler.RegisterRoutes(protected)

	organizationReadRoutes := protected.Group("/organizations/:organizationId")
	organizationReadRoutes.Use(RequireOrganizationRole(
		domain.RoleAdmin,
		domain.RoleAccountant,
		domain.RoleBookkeeper,
		domain.RolePayrollManager,
		domain.RoleViewer,
	))
	accountHandler.RegisterReadRoutes(organizationReadRoutes)
	ledgerHandler.RegisterReadRoutes(organizationReadRoutes)
	taxHandler.RegisterReadRoutes(organizationReadRoutes)
	customerHandler.RegisterReadRoutes(organizationReadRoutes)
	invoiceHandler.RegisterReadRoutes(organizationReadRoutes)
	recurringInvoiceHandler.RegisterReadRoutes(organizationReadRoutes)
	vendorHandler.RegisterReadRoutes(organizationReadRoutes)
	expenseHandler.RegisterReadRoutes(organizationReadRoutes)
	billHandler.RegisterReadRoutes(organizationReadRoutes)
	paymentHandler.RegisterReadRoutes(organizationReadRoutes)
	commercialDocumentHandler.RegisterReadRoutes(organizationReadRoutes)
	attachmentHandler.RegisterReadRoutes(organizationReadRoutes)
	reportHandler.RegisterRoutes(organizationReadRoutes)
	reconciliationHandler.RegisterReadRoutes(organizationReadRoutes)
	budgetHandler.RegisterReadRoutes(organizationReadRoutes)
	exchangeRateHandler.RegisterReadRoutes(organizationReadRoutes)
	investmentHandler.RegisterReadRoutes(organizationReadRoutes)
	revaluationHandler.RegisterReadRoutes(organizationReadRoutes)
	closingHandler.RegisterReadRoutes(organizationReadRoutes)

	auditRoutes := protected.Group("/organizations/:organizationId")
	auditRoutes.Use(RequireOrganizationRole(
		domain.RoleAdmin,
		domain.RoleAccountant,
	))
	auditHandler.RegisterRoutes(auditRoutes)
	userHandler.RegisterReadRoutes(auditRoutes)
	dataExportHandler.RegisterRoutes(auditRoutes)

	payrollReadRoutes := protected.Group("/organizations/:organizationId")
	payrollReadRoutes.Use(RequireOrganizationRole(
		domain.RoleAdmin,
		domain.RoleAccountant,
		domain.RolePayrollManager,
		domain.RoleViewer,
	))
	employeeHandler.RegisterReadRoutes(payrollReadRoutes)
	payrollHandler.RegisterReadRoutes(payrollReadRoutes)

	organizationWriteRoutes := protected.Group("/organizations/:organizationId")
	organizationWriteRoutes.Use(RequireOrganizationRole(
		domain.RoleAdmin,
		domain.RoleAccountant,
		domain.RoleBookkeeper,
	))
	accountHandler.RegisterWriteRoutes(organizationWriteRoutes)
	ledgerHandler.RegisterWriteRoutes(organizationWriteRoutes)
	customerHandler.RegisterWriteRoutes(organizationWriteRoutes)
	invoiceHandler.RegisterWriteRoutes(organizationWriteRoutes)
	recurringInvoiceHandler.RegisterWriteRoutes(organizationWriteRoutes)
	vendorHandler.RegisterWriteRoutes(organizationWriteRoutes)
	expenseHandler.RegisterWriteRoutes(organizationWriteRoutes)
	billHandler.RegisterWriteRoutes(organizationWriteRoutes)
	paymentHandler.RegisterWriteRoutes(organizationWriteRoutes)
	commercialDocumentHandler.RegisterWriteRoutes(organizationWriteRoutes)
	attachmentHandler.RegisterWriteRoutes(organizationWriteRoutes)
	reportHandler.RegisterWriteRoutes(organizationWriteRoutes)
	reconciliationHandler.RegisterWriteRoutes(organizationWriteRoutes)
	budgetHandler.RegisterWriteRoutes(organizationWriteRoutes)
	exchangeRateHandler.RegisterWriteRoutes(organizationWriteRoutes)
	investmentHandler.RegisterWriteRoutes(organizationWriteRoutes)
	revaluationHandler.RegisterWriteRoutes(organizationWriteRoutes)

	closingWriteRoutes := protected.Group("/organizations/:organizationId")
	closingWriteRoutes.Use(RequireOrganizationRole(
		domain.RoleAdmin,
		domain.RoleAccountant,
	))
	closingHandler.RegisterWriteRoutes(closingWriteRoutes)

	userWriteRoutes := protected.Group("/organizations/:organizationId")
	userWriteRoutes.Use(RequireOrganizationRole(domain.RoleAdmin))
	userHandler.RegisterWriteRoutes(userWriteRoutes)

	payrollWriteRoutes := protected.Group("/organizations/:organizationId")
	payrollWriteRoutes.Use(RequireOrganizationRole(
		domain.RoleAdmin,
		domain.RolePayrollManager,
	))
	employeeHandler.RegisterWriteRoutes(payrollWriteRoutes)
	payrollHandler.RegisterWriteRoutes(payrollWriteRoutes)

	organizationTaxWriteRoutes := protected.Group("/organizations/:organizationId")
	organizationTaxWriteRoutes.Use(RequireOrganizationRole(
		domain.RoleAdmin,
		domain.RoleAccountant,
	))
	taxHandler.RegisterWriteRoutes(organizationTaxWriteRoutes)

	organizationAdminRoutes := protected.Group("/organizations/:organizationId")
	organizationAdminRoutes.Use(RequireOrganizationRole(domain.RoleAdmin))
	seedHandler.RegisterIndiaRoutes(organizationAdminRoutes)

	if cfg.SwaggerEnabled {
		registerSwaggerRoutes(router)
	}

	return router
}

func registerSwaggerRoutes(router *gin.Engine) {
	serveOpenAPI := func(c *gin.Context) {
		path := filepath.Join("..", "docs", "openapi.yaml")
		if _, err := os.Stat(path); err != nil {
			if errors.Is(err, os.ErrNotExist) {
				path = filepath.Join("docs", "openapi.yaml")
			}
		}
		c.File(path)
	}
	router.GET("/openapi.yaml", serveOpenAPI)
	router.GET("/swagger/openapi.yaml", serveOpenAPI)
	router.GET("/swagger", func(c *gin.Context) {
		c.Redirect(http.StatusMovedPermanently, "/swagger/index.html")
	})
	router.GET("/swagger/", func(c *gin.Context) {
		c.Redirect(http.StatusMovedPermanently, "/swagger/index.html")
	})
	router.GET("/swagger/index.html", func(c *gin.Context) {
		c.Data(http.StatusOK, "text/html; charset=utf-8", []byte(swaggerHTML))
	})
}

const swaggerHTML = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>AbhashTech Accounting API Docs</title>
  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css" />
  <style>
    body {
      margin: 0;
      background: #f6f8fb;
    }
    .swagger-ui .topbar {
      background: #102033;
    }
    .docs-fallback {
      max-width: 720px;
      margin: 24px auto;
      padding: 16px 20px;
      border: 1px solid #d7dde8;
      border-radius: 10px;
      background: #ffffff;
      color: #243244;
      font-family: ui-sans-serif, system-ui, sans-serif;
    }
    .docs-fallback a {
      color: #0f5f9f;
    }
  </style>
</head>
<body>
  <noscript>
    <div class="docs-fallback">
      JavaScript is required for the interactive Swagger UI. The raw OpenAPI contract is available at
      <a href="/openapi.yaml">/openapi.yaml</a>.
    </div>
  </noscript>
  <div id="swagger-ui">
    <div class="docs-fallback" id="swagger-loading">
      Loading Swagger UI for the AbhashTech Accounting API. If this message stays visible, check network access to the Swagger UI CDN or open
      <a href="/openapi.yaml">/openapi.yaml</a> directly.
    </div>
  </div>
  <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
  <script>
    window.onload = () => {
      if (!window.SwaggerUIBundle) {
        document.getElementById("swagger-loading").textContent = "Swagger UI assets failed to load. Open /openapi.yaml directly or vendor swagger-ui-dist assets for offline environments.";
        return;
      }
      window.ui = SwaggerUIBundle({
        url: "/openapi.yaml",
        dom_id: "#swagger-ui",
        deepLinking: true,
        displayRequestDuration: true,
        filter: true,
        persistAuthorization: true,
        tryItOutEnabled: true,
        defaultModelsExpandDepth: 1,
        defaultModelExpandDepth: 2
      });
    };
  </script>
</body>
</html>`
