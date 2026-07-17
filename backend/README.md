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
- `BACKUP_MIRROR_PATH=` optional secondary mounted backup directory for checksum-verified backup copies
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
- Investment lots, specific-lot and average-cost sale tracking, GL sale posting, market prices, CSV/AMFI NAV/NSE/BSE/Yahoo/Alpha Vantage/broker-holdings imports, scheduled worker market-data file imports, valuation, tax-adjustment candidates, and realized gain/loss reporting.
- Admin/Accountant organization JSON data export plus local backup snapshot endpoints for portable backups with optional checksum-verified mirror copies.
- Cron-style background worker for due recurring invoice draft generation, scheduled local/mirrored backup snapshots, and optional scheduled investment market-data file imports.
- Explicit migration CLI at `cmd/migrate`, restore CLI at `cmd/restore`, plus Docker/Compose deployment scaffolding for MySQL-backed API, worker, and React web.
- Audit log service and audit log listing endpoint for key posting/reconciliation workflows.
- Admin-managed organization user creation and membership role assignment.
- Request ID and CORS middleware.
- Configurable in-memory rate limiting for public auth/bootstrap endpoints.
- Production configuration validation that fails fast on unsafe runtime defaults.
- Structured `slog` request/job logging with configurable text or JSON output.
- Prometheus-compatible `/metrics` endpoint with HTTP request counters, latency sums, and process uptime.
- OpenAPI served at `/openapi.yaml` and `/swagger/openapi.yaml`, with Swagger UI at `/swagger/index.html` when enabled.
- API route/Postman coverage validators for 180 route/method pairs.
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

For managed-cloud deployment, migration, rollback, backup, monitoring, and incident-response guidance, see `../docs/MANAGED_CLOUD_RUNBOOK.md`.

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
- `bse_equity_csv`: BSE-style equity CSV rows with `SC_CODE`/`SCRIP_CODE`, `TRADING_DATE`/`DATE`, and `CLOSE`/`CLOSE_PRICE`; common equity groups are imported when a group column is present.
- `yahoo_finance_csv`: Yahoo Finance historical CSV rows with `Date` and `Close`; set `MARKET_DATA_SYMBOL` for raw single-symbol downloads, or include a `Symbol`/`Ticker` column in multi-symbol files.
- `alpha_vantage_csv`: Alpha Vantage daily CSV rows with `timestamp` and `close`; set `MARKET_DATA_SYMBOL` for raw single-symbol downloads, or include a `Symbol`/`Ticker` column in multi-symbol files.
- `broker_holdings_csv`: Broker holdings exports with symbol/trading-symbol/ticker or ISIN plus LTP/current/last-traded price columns; if no date column is present, the current UTC date is used.
- `zerodha_holdings_csv`: Zerodha Console holdings exports with Instrument/ISIN plus LTP/current price columns; defaults the source to `zerodha_holdings_csv`.
- `groww_holdings_csv`: Groww holdings exports with Company Name/ISIN plus LTP/current price columns; if no ticker column is present, the ISIN is used as the local investment symbol.
- `upstox_holdings_csv`: Upstox holdings exports with Symbol/ISIN plus LTP/current price columns; defaults the source to `upstox_holdings_csv`.
- `angelone_holdings_csv`: Angel One holdings exports with Scrip/Symbol/ISIN plus LTP/current price columns; defaults the source to `angelone_holdings_csv`.
- `dhan_holdings_csv`: Dhan holdings exports with Trading Symbol/Symbol/ISIN plus LTP/current price columns; defaults the source to `dhan_holdings_csv`.
- `icicidirect_holdings_csv`: ICICI Direct holdings exports with Symbol/ISIN plus Market Price/LTP/current price columns; defaults the source to `icicidirect_holdings_csv`.
- `hdfcsky_holdings_csv`: HDFC Sky holdings exports with Symbol/ISIN plus LTP/current price columns; defaults the source to `hdfcsky_holdings_csv`.
- `kotakneo_holdings_csv`: Kotak Neo holdings exports with Trading Symbol/Symbol/ISIN plus LTP/current price columns; defaults the source to `kotakneo_holdings_csv`.
- `paytmmoney_holdings_csv`: Paytm Money holdings exports with Symbol/ISIN plus LTP/current price columns; defaults the source to `paytmmoney_holdings_csv`.
- `motilaloswal_holdings_csv`: Motilal Oswal holdings exports with Symbol/ISIN plus LTP/current price columns; defaults the source to `motilaloswal_holdings_csv`.
- `sharekhan_holdings_csv`: Sharekhan holdings exports with Symbol/ISIN plus LTP/current price columns; defaults the source to `sharekhan_holdings_csv`.
- `fivepaisa_holdings_csv`: 5paisa holdings exports with Symbol/ISIN plus LTP/current price columns; defaults the source to `fivepaisa_holdings_csv`.
- `axisdirect_holdings_csv`: Axis Direct holdings exports with Symbol/ISIN plus LTP/current price columns; defaults the source to `axisdirect_holdings_csv`.
- `sbisecurities_holdings_csv`: SBI Securities holdings exports with Symbol/ISIN plus LTP/current price columns; defaults the source to `sbisecurities_holdings_csv`.
- `nuvama_holdings_csv`: Nuvama holdings exports with Symbol/ISIN plus LTP/current price columns; defaults the source to `nuvama_holdings_csv`.
- `geojit_holdings_csv`: Geojit holdings exports with Symbol/ISIN plus LTP/current price columns; defaults the source to `geojit_holdings_csv`.
- `iiflsecurities_holdings_csv`: IIFL Securities holdings exports with Symbol/ISIN plus LTP/current price columns; defaults the source to `iiflsecurities_holdings_csv`.
- `fyers_holdings_csv`: FYERS holdings exports with Symbol/ISIN plus LTP/current price columns; defaults the source to `fyers_holdings_csv`.
- `edelweiss_holdings_csv`: Edelweiss holdings exports with Symbol/ISIN plus LTP/current price columns; defaults the source to `edelweiss_holdings_csv`.
- `aliceblue_holdings_csv`: Alice Blue holdings exports with Symbol/ISIN plus LTP/current price columns; defaults the source to `aliceblue_holdings_csv`.
- `samco_holdings_csv`: Samco holdings exports with Symbol/ISIN plus LTP/current price columns; defaults the source to `samco_holdings_csv`.
- `choice_holdings_csv`: Choice holdings exports with Symbol/ISIN plus LTP/current price columns; defaults the source to `choice_holdings_csv`.
- `religare_holdings_csv`: Religare holdings exports with Symbol/ISIN plus LTP/current price columns; defaults the source to `religare_holdings_csv`.
- `jainam_holdings_csv`: Jainam holdings exports with Symbol/ISIN plus LTP/current price columns; defaults the source to `jainam_holdings_csv`.

Leave `MARKET_DATA_ORGANIZATION_ID` blank to import the same feed into every organization, or set it to one organization UUID to scope the worker import.

To restore a mounted backup with Compose:

```bash
docker compose run --rm api /app/restore -file /app/storage/backups/<backup-file>.json
```
