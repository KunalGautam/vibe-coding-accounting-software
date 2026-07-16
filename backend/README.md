# Accounting Backend

Go API for the AbhashTech accounting platform.

Module path:

```text
accounting.abhashtech.com
```

## Run Locally

```bash
go run ./cmd/api
```

Run the background worker for recurring invoice generation:

```bash
go run ./cmd/worker
```

Run database migrations explicitly:

```bash
go run ./cmd/migrate -direction=up
```

Restore an organization export/backup into a database where that organization ID does not already exist:

```bash
go run ./cmd/restore -file ./storage/backups/organization-<id>-backup-<timestamp>.json
```

Defaults:

- `DATABASE_DRIVER=sqlite`
- `DATABASE_DSN=file:accounting.db?cache=shared`
- `AUTO_MIGRATE=true`
- `DEFAULT_COUNTRY=IN`
- `DEFAULT_CURRENCY=INR`
- `BACKUP_STORAGE_PATH=./storage/backups`
- `BACKUP_RETENTION_COUNT=7`
- `WORKER_RUN_ONCE=false`
- `WORKER_INTERVAL_SECONDS=3600`
- `MARKET_DATA_IMPORT_ENABLED=false`
- `MARKET_DATA_IMPORT_PATH=`
- `MARKET_DATA_IMPORT_URL=`
- `MARKET_DATA_BEARER_TOKEN=`
- `MARKET_DATA_TIMEOUT_SECONDS=30`
- `MARKET_DATA_IMPORT_FORMAT=amfi`
- `MARKET_DATA_SYMBOL_MODE=scheme_code`
- `MARKET_DATA_SOURCE=scheduled_market_data`
- `MARKET_DATA_SYMBOL=`
- `MARKET_DATA_ORGANIZATION_ID=`
- `RATE_LIMIT_ENABLED=true`
- `RATE_LIMIT_REQUESTS=20`
- `RATE_LIMIT_WINDOW_SECONDS=60`
- `LOG_FORMAT=text`
- `LOG_LEVEL=info`
- `METRICS_ENABLED=true`

Production mode validates unsafe defaults at startup. With `APP_ENV=production`, API runtime processes require non-default JWT secrets, `MFA_ENCRYPTION_KEY`, explicit CORS origins, `SWAGGER_ENABLED=false`, `DATABASE_DRIVER=mysql`, `MYSQL_DSN`, and `AUTO_MIGRATE=false`.

Generate a production MFA encryption key with:

```bash
openssl rand -base64 32
```

Password reset email delivery is optional and enabled with:

```env
EMAIL_DELIVERY_ENABLED=true
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=optional-user
SMTP_PASSWORD=optional-password
SMTP_FROM=no-reply@example.com
PASSWORD_RESET_BASE_URL=https://app.example.com/reset-password
INVITATION_BASE_URL=https://app.example.com/login
```

When email delivery is enabled, reset tokens are emailed and omitted from API responses unless `EXPOSE_PASSWORD_RESET_TOKEN=true` is explicitly set for non-production troubleshooting. Organization user creation also sends invitation emails when SMTP delivery is enabled.

## Current Scope

The backend currently contains the first implementation slice:

- Configuration loading.
- SQLite/MySQL database opening through GORM.
- GORM models for organizations, users, memberships, chart of accounts, journal transactions, ledger splits, and audit logs.
- Ledger transaction balance validation.
- JWT login, refresh-token rotation, and password reset token services.
- Organization membership RBAC middleware for protected accounting routes.
- First-admin bootstrap endpoint.
- India starter chart of accounts and GST seed endpoint.
- Tax authority, rate, group, and calculation endpoints.
- Customer and invoice endpoints with draft invoice creation and GL posting.
- Vendor and expense endpoints with draft expense creation and GL posting.
- Attachment metadata plus local binary upload/download endpoints for receipt and invoice PDF file references.
- Ledger-based Trial Balance, Profit & Loss, and Balance Sheet reports.
- Posted-document Tax Liability and Tax Summary reports.
- Employee and payroll run endpoints with GL posting, configurable India payroll preview, payslip preview, and payslip CSV export support in React.
- Structured bank statement import, statement-line matching, and ledger split reconciliation.
- Budget creation/listing and Budget vs Actual reporting.
- Exchange-rate storage, base-currency ledger split support, and unrealized FX revaluation posting.
- Fiscal year close posting to retained earnings.
- Investment lots, specific-lot and average-cost sale tracking, GL sale posting, market prices, CSV/AMFI NAV imports, scheduled worker market-data file imports, valuation, tax-adjustment candidates, and realized gain/loss reporting.
- Admin/Accountant organization JSON data export plus local backup snapshot endpoints for portable backups.
- Cron-style background worker for due recurring invoice draft generation, scheduled local backup snapshots, and optional scheduled investment market-data file imports.
- Explicit migration CLI at `cmd/migrate`, restore CLI at `cmd/restore`, plus Docker/Compose deployment scaffolding for MySQL-backed API, worker, and React web.
- Audit log service and audit log listing endpoint for key posting/reconciliation workflows.
- Admin-managed organization user creation and membership role assignment.
- Request ID and CORS middleware.
- Configurable in-memory rate limiting for public auth/bootstrap endpoints.
- Production configuration validation that fails fast on unsafe runtime defaults.
- Structured `slog` request/job logging with configurable text or JSON output.
- Prometheus-compatible `/metrics` endpoint with HTTP request counters, latency sums, and process uptime.
- OpenAPI served at `/openapi.yaml` and `/swagger/openapi.yaml`, with Swagger UI at `/swagger/index.html` when enabled.
- API route/Postman coverage validators for 139 route/method pairs.
- Health endpoints at `/health` and `/api/v1/health`, plus operational metrics at `/metrics`.

## API Documentation

The canonical REST contract lives at:

```text
../docs/openapi.yaml
```

The human-readable API documentation workflow is maintained at:

```text
../docs/API_DOCUMENTATION.md
```

The Postman collection is maintained at:

```text
../docs/accounting-api.postman_collection.json
```

Current status and remaining work are tracked at:

```text
../docs/PROJECT_STATUS.md
```

Set `SWAGGER_ENABLED=true` in development or staging to expose:

```text
GET /openapi.yaml
GET /swagger/index.html
GET /swagger/openapi.yaml
```

The convenience paths `/swagger` and `/swagger/` redirect to `/swagger/index.html`. Disable or auth-gate Swagger in production with `SWAGGER_ENABLED=false`.

Starter Prometheus alert rules and a Grafana dashboard are available under `../ops/`. They use the built-in `accounting_*` metrics emitted by `/metrics` and assume a Prometheus scrape job named `accounting-api`.

## Auth Status

Implemented:

- `POST /api/v1/bootstrap/first-admin`
- `POST /api/v1/auth/register` when `SELF_SERVICE_REGISTRATION_ENABLED=true`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/password-reset/request`
- `POST /api/v1/auth/password-reset/confirm`
- Optional SMTP password reset and organization invitation emails.
- JWT middleware for protected routes.
- Organization-scoped RBAC for account and ledger routes.

## First Local Setup

Start the API, then create the first admin and seed India defaults:

```bash
curl -X POST http://localhost:8080/api/v1/bootstrap/first-admin \
  -H 'Content-Type: application/json' \
  -d '{
    "organization_name": "Acme India",
    "admin_name": "Admin User",
    "admin_email": "admin@example.com",
    "admin_password": "change-me-securely",
    "base_currency": "INR",
    "country_code": "IN",
    "seed_india_defaults": true
  }'
```

This endpoint returns `409 Conflict` after the first user exists.

## Docker Compose

From the repository root:

```bash
cp .env.example .env
# edit secrets in .env before first real use
docker compose up --build
```

Compose starts MySQL, runs `/app/migrate -direction=up`, then starts the API, worker, and web containers. In Compose, `AUTO_MIGRATE=false` for long-running services so schema changes are applied by the one-shot migration container.

To enable scheduled investment market-data imports, mount or write a feed file under the shared app storage volume and set:

```env
MARKET_DATA_IMPORT_ENABLED=true
MARKET_DATA_IMPORT_PATH=/app/storage/market-data/amfi.txt
MARKET_DATA_IMPORT_FORMAT=amfi
MARKET_DATA_SYMBOL_MODE=scheme_code
```

Alternatively, point the worker at a provider URL:

```env
MARKET_DATA_IMPORT_ENABLED=true
MARKET_DATA_IMPORT_URL=https://example.com/prices.csv
MARKET_DATA_IMPORT_FORMAT=csv
MARKET_DATA_BEARER_TOKEN=optional-provider-token
MARKET_DATA_TIMEOUT_SECONDS=30
```

Supported market-data formats are:

- `amfi`: India AMFI NAV feed text for mutual funds.
- `csv`: canonical `symbol,price_date,price_minor,currency,source` rows.
- `nse_equity_csv`: NSE-style equity bhavcopy/security CSV rows with `SYMBOL`/`TckrSymb`, `DATE1`/`TradDt`, and `CLOSE_PRICE`/`ClsPric`; `EQ` series rows are imported when a series column is present.
- `yahoo_finance_csv`: Yahoo Finance historical CSV rows with `Date` and `Close`; set `MARKET_DATA_SYMBOL` for raw single-symbol downloads, or include a `Symbol`/`Ticker` column in multi-symbol files.

Leave `MARKET_DATA_ORGANIZATION_ID` blank to import the same feed into every organization, or set it to one organization UUID to scope the worker import.

To restore a mounted backup with Compose:

```bash
docker compose run --rm api /app/restore -file /app/storage/backups/<backup-file>.json
```
