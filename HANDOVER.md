# Handover

## Project
This is a full-stack, multi-platform accounting and bookkeeping platform for small to medium-sized businesses. The backend is a Go/Gin/GORM REST API with MySQL production support and SQLite local/offline support. The web app is React + TypeScript. The mobile/desktop app is Flutter. The accounting core is double-entry bookkeeping with tenant-scoped organizations.

Project identity:

- Go module: `accounting.abhashtech.com`
- Flutter native app ID/package: `com.abhashtech.accounting`
- Dart package name: `accounting_app`

## Repository Layout
- `backend/`: Go API, domain models, handlers, services, worker.
- `web/`: React TypeScript web app.
- `flutter_app/`: Flutter mobile/desktop app.
- `docs/openapi.yaml`: canonical OpenAPI 3 contract.
- `docs/accounting-api.postman_collection.json`: Postman collection.
- `docs/API_DOCUMENTATION.md`: REST/Swagger usage and validation workflow.
- `docs/PROJECT_STATUS.md`: current status, completed areas, remaining work, next build order.
- `PROJECT_CONTEXT.md`: primary onboarding/context file for coding agents.
- `scripts/validate_openapi_routes.rb`: validates Gin route coverage in OpenAPI.
- `scripts/validate_postman_collection.rb`: validates Postman coverage against OpenAPI.

## Current State
Major backend modules are implemented and tested for:

- Organizations, users, JWT auth, optional TOTP MFA with one-time recovery codes, refresh tokens, password reset token flow with optional SMTP delivery, organization invitation emails, gated self-service registration, RBAC.
- Chart of accounts, double-entry ledger, journal posting, account registers.
- Invoicing, recurring invoices, estimates, credit notes, customer payments.
- Vendors, expenses, bills, purchase orders, vendor payments.
- Config-driven GST/VAT tax catalog, India GST seed data, tax calculation, tax reports.
- Payroll employees, payroll runs, India payroll preview with professional-tax starter presets, fixed/flat-rate/progressive-slab TDS and employer PF/ESI contribution cost, payroll summary report plus PF/ESI/PT/TDS statutory component CSV export, payslip preview, payslip CSV/PDF export in React, payroll GL posting including optional employer contribution expense/liability splits.
- Reports: trial balance, P&L, balance sheet, cash flow, AR/AP aging, tax reports, budget vs actual, account drilldown with source-document references, realized gains, investment dividends, investment tax lots, investment valuation, expanded core report PDF/CSV exports, and managed scheduled report snapshots with optional SMTP delivery for core financial reports.
- Bank imports: structured lines, browser CSV mapper, QIF, OFX, duplicate candidate detection, conservative matching-rule suggestions, reconciliation summaries, matching, reconciliation.
- Budgeting, fiscal close, exchange rates, unrealized FX revaluation.
- Investment lots, dividends, stock split/bonus corporate actions, corporate-action reporting/export, specific-lot sales, average-cost sales, realized gains, tax-lot reporting, configurable loss-repurchase tax-adjustment reporting, prices, CSV price imports, India AMFI NAV feed-text imports, BSE/NSE-style equity CSV imports, Yahoo Finance historical CSV imports, Alpha Vantage daily CSV imports, scheduled worker market-data file imports, generic provider URL imports with optional bearer auth, valuation.
- Attachment metadata, local binary upload/download, organization JSON export, local backup snapshots.
- Swagger UI and OpenAPI/Postman validation in CI.

React web currently has broad admin/control surfaces, password reset request/confirm UX with reset-link token detection/password guidance, MFA recovery-code copy/download, organization-user onboarding helper with role guidance, invite-status summary, temporary-password generation/copy/download, and invite delivery status, offline-oriented localStorage snapshots, manual draft queues, report CSV exports, report-row account drilldowns with an inline ledger movement panel, source-document module actions, focused-row highlighting, invoice/estimate/purchase-order/bill detail review, invoice/bill payment history tables, payroll preview/payslip flows, and typed API support.

Flutter currently has an offline-ready expense/invoice/investment/report shell with SQLite-backed pending sync operations, sync settings, account cache, customer/vendor party cache, tax catalog cache, invoice cache, investment cache, Trial Balance/P&L/Balance Sheet/Cash Flow/AR Aging/AP Aging/Tax Liability/Tax Summary/Budget vs Actual report cache, prior-period comparison for statements, aging, and tax reports, selected-vs-previous budget comparison, local CSV export generation and app-storage/Downloads/share-sheet support, attachment metadata cache, downloaded attachment binary cache, and queued-attachment upload manifests, plus typed API transport, plugin-backed file/gallery/camera attachment capture, attachment handling, and tests. The sync coordinator can now replay queued expense drafts, invoice drafts, draft expense/invoice edits, customer payments, vendor payments, invoice/expense/bill/credit-note posting actions, estimate status transitions/conversions, purchase-order status transitions/conversions, structured/QIF/OFX bank statement imports, attachment metadata creation, binary attachment uploads, manual investment price captures, and average-cost investment sales with shared retry/error/conflict metadata. Queued local attachment uploads record operation IDs, local file paths, file names, sizes, timestamps, and optional content types.

## Git Notes
The normal `.git` path in this workspace is a read-only/busy placeholder. The actual Git metadata was initialized in `.gitrepo`.

Use:

```bash
GIT_DIR=.gitrepo GIT_WORK_TREE=. git status
GIT_DIR=.gitrepo GIT_WORK_TREE=. git log --oneline -5
```

Remote:

```text
origin git@github.com:KunalGautam/vibe-coding-accounting-software.git
```

Check the latest pushed commit with:

```bash
GIT_DIR=.gitrepo GIT_WORK_TREE=. git log --oneline -1
```

When pushing over SSH in this environment, bypass the broken system SSH config:

```bash
GIT_SSH_COMMAND='ssh -F /dev/null' GIT_DIR=.gitrepo GIT_WORK_TREE=. git push
```

## Validation Commands
Run these before handoff or commit:

```bash
cd backend
env GOCACHE=/tmp/go-build go test ./...
```

```bash
cd web
npm run build
```

```bash
cd flutter_app
/home/kunal/development/flutter/bin/flutter analyze
/home/kunal/development/flutter/bin/flutter test
```

```bash
ruby -e 'require "yaml"; YAML.load_file("docs/openapi.yaml")'
node -e 'JSON.parse(require("fs").readFileSync("docs/accounting-api.postman_collection.json", "utf8"))'
ruby scripts/validate_openapi_routes.rb
ruby scripts/validate_postman_collection.rb
```

Current API coverage: `151` OpenAPI route/method pairs, matched to Gin handlers and Postman.

## Important Constraints
- Double-entry ledger is the source of truth.
- Do not delete posted ledger entries; use reversing entries/corrections.
- Every organization-scoped object must be tenant-scoped.
- Do not allow unbalanced ledger posting.
- Store monetary values as integer minor units.
- Keep tax and payroll configurable; do not hardcode country logic except editable India-first seed/default support.
- Prefer database-agnostic GORM operations for SQLite/MySQL portability.
- Keep OpenAPI and Postman updated in the same change as API behavior.
- Preserve offline-first direction for React and Flutter.
- Production Compose uses a one-shot `/app/migrate -direction=up` container; API/worker should run with `AUTO_MIGRATE=false` outside local development.
- Backup restore is available with `backend/cmd/restore` or `/app/restore -file /app/storage/backups/<file>.json`; it refuses to overwrite an existing organization ID.
- Public auth/bootstrap endpoints use configurable in-memory rate limiting (`RATE_LIMIT_ENABLED`, `RATE_LIMIT_REQUESTS`, `RATE_LIMIT_WINDOW_SECONDS`).
- `APP_ENV=production` validates unsafe runtime defaults and rejects dev JWT secrets, wildcard CORS, Swagger, SQLite, missing MySQL DSN, and API/worker auto-migration.
- TOTP MFA secrets are encrypted at rest with `MFA_ENCRYPTION_KEY`; set it to 32 random bytes encoded as base64, for example `openssl rand -base64 32`.
- Password reset and organization invitation email delivery are available with `EMAIL_DELIVERY_ENABLED=true`, SMTP settings, `PASSWORD_RESET_BASE_URL`, and `INVITATION_BASE_URL`; reset tokens are hidden from API responses unless `EXPOSE_PASSWORD_RESET_TOKEN=true`.
- Self-service organization registration is available at `POST /api/v1/auth/register` only when `SELF_SERVICE_REGISTRATION_ENABLED=true`; keep it disabled for invitation-only deployments.
- Structured logging is implemented with `LOG_FORMAT=text|json` and `LOG_LEVEL=debug|info|warn|error`; Compose defaults to JSON logs.
- Basic Prometheus metrics are exposed at `/metrics` when `METRICS_ENABLED=true`.
- Prometheus scrape/rule config, Alertmanager email routing template, and Grafana datasource/dashboard provisioning are in `ops/` and wired through the optional Compose `monitoring` profile.
- Managed-cloud deployment, migration, rollback, backup, monitoring, and incident-response guidance is in `docs/MANAGED_CLOUD_RUNBOOK.md`.

## Highest-Value Remaining Work
1. Investment depth: additional broker/provider-specific market-data adapters beyond AMFI, BSE/NSE-style CSV, Yahoo Finance CSV, and Alpha Vantage CSV.
2. Security hardening polish: broader account-management UX, recovery tests, and account lifecycle polish.
3. Email/account flows: account lifecycle controls beyond create/list, richer onboarding journeys, and account-management tests.
4. Offline sync depth: backend draft-edit endpoints and Flutter edit replay for draft invoice/expense updates are implemented; remaining work is mainly UI breadth and conflict-resolution polish.
5. Export/reporting polish: core drilldown, source-document focus, commercial document detail panels, and payment history panels are implemented; remaining work is broader frontend polish.
6. UI polish: complete CRUD flows, validation UX, module dashboards, broader Flutter parity.

## Recommended Next Step
Continue with additional broker/provider-specific market-data adapters or deeper document detail pages, then continue toward full mobile/desktop parity. `SyncOperationRepository`, `SyncSettingsRepository`, `AccountCacheRepository`, `PartyCacheRepository`, `TaxCatalogCacheRepository`, `InvoiceCacheRepository`, `InvestmentCacheRepository`, `ReportCacheRepository`, `AttachmentCacheRepository`, `AttachmentBinaryCacheRepository`, and `AttachmentUploadManifestRepository` now default to SQLite. Keep the current operation keys (`expenses.create_draft`, `expenses.update_draft`, `invoices.create_draft`, `invoices.update_draft`, `payments.record_customer`, `payments.record_vendor`, `ledger.post_invoice`, `ledger.post_expense`, `ledger.post_bill`, `ledger.post_credit_note`, `commercial_documents.update_estimate_status`, `commercial_documents.update_purchase_order_status`, `commercial_documents.convert_estimate_to_invoice`, `commercial_documents.convert_purchase_order_to_bill`, `imports.bank_statement_structured`, `imports.bank_statement_qif`, `imports.bank_statement_ofx`, `attachments.create_metadata`, `attachments.upload_binary`, `investments.create_price`, `investments.sell_average_cost`) and conflict metadata fields (`retry_count`, `last_attempt_at`, `last_error`, `conflict_reason`) as the sync-state contract.

## Files To Read First
1. `PROJECT_CONTEXT.md`
2. `docs/PROJECT_STATUS.md`
3. `docs/API_DOCUMENTATION.md`
4. `backend/internal/services/payroll.go`
5. `backend/internal/http/handlers/payroll.go`
6. `web/src/App.tsx`
7. `web/src/api/client.ts`
8. `docs/openapi.yaml`
