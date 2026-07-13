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

Defaults:

- `DATABASE_DRIVER=sqlite`
- `DATABASE_DSN=file:accounting.db?cache=shared`
- `DEFAULT_COUNTRY=IN`
- `DEFAULT_CURRENCY=INR`
- `BACKUP_STORAGE_PATH=./storage/backups`
- `BACKUP_RETENTION_COUNT=7`
- `WORKER_RUN_ONCE=false`
- `WORKER_INTERVAL_SECONDS=3600`

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
- Investment lots, specific-lot and average-cost sale tracking, GL sale posting, market prices, valuation, and realized gain/loss reporting.
- Admin/Accountant organization JSON data export plus local backup snapshot endpoints for portable backups.
- Cron-style background worker for due recurring invoice draft generation and scheduled local backup snapshots.
- Audit log service and audit log listing endpoint for key posting/reconciliation workflows.
- Admin-managed organization user creation and membership role assignment.
- Request ID and CORS middleware.
- OpenAPI served at `/openapi.yaml` and `/swagger/openapi.yaml`, with Swagger UI at `/swagger/index.html` when enabled.
- API route/Postman coverage validators for 102 route/method pairs.
- Health endpoint at `/health` and `/api/v1/health`.

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

## Auth Status

Implemented:

- `POST /api/v1/bootstrap/first-admin`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/password-reset/request`
- `POST /api/v1/auth/password-reset/confirm`
- JWT middleware for protected routes.
- Organization-scoped RBAC for account and ledger routes.

Not implemented yet:

- Email invitations, email delivery for password resets, and self-service registration.

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
