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
- Reports: trial balance, P&L, balance sheet, cash flow, AR/AP aging, tax reports, budget vs actual, realized gains, investment dividends, investment tax lots, investment valuation, core statement PDF exports, and managed scheduled report snapshots with optional SMTP delivery for core financial reports.
- Bank imports: structured lines, browser CSV mapper, QIF, OFX, duplicate candidate detection, conservative matching-rule suggestions, reconciliation summaries, matching, reconciliation.
- Budgeting, fiscal close, exchange rates, unrealized FX revaluation.
- Investment lots, dividends, stock split/bonus corporate actions, corporate-action reporting/export, specific-lot sales, average-cost sales, realized gains, tax-lot reporting, configurable loss-repurchase tax-adjustment reporting, prices, CSV price imports, India AMFI NAV feed-text imports, NSE-style equity CSV imports, Yahoo Finance historical CSV imports, scheduled worker market-data file imports, generic provider URL imports with optional bearer auth, valuation.
- Attachment metadata, local binary upload/download, organization JSON export, local backup snapshots.
- Swagger UI and OpenAPI/Postman validation in CI.

React web currently has broad admin/control surfaces, offline-oriented localStorage snapshots, manual draft queues, report CSV exports, payroll preview/payslip flows, and typed API support.

Flutter currently has an offline-ready expense/invoice/investment shell with file-backed caches/queues, typed API transport, attachment handling, sync settings, and tests. The sync coordinator can now replay queued expense drafts, invoice drafts, attachment metadata creation, binary attachment uploads, and manual investment price captures with shared retry/error/conflict metadata.

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

Current API coverage: `132` OpenAPI route/method pairs, matched to Gin handlers and Postman.

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

## Highest-Value Remaining Work
1. Investment depth: additional broker/provider-specific market-data adapters beyond AMFI, NSE-style CSV, and Yahoo Finance CSV.
2. Production readiness: deeper operational monitoring runbooks and managed-cloud deployment notes.
3. Security hardening polish: broader auth UX and account recovery flows.
4. Email/account flows: richer onboarding and account-management polish.
5. Offline sync depth: native Flutter SQLite persistence and additional write queues for payments/status changes/import drafts.
6. Export/reporting polish: broader PDF/Excel exports and comparative reports.
7. UI polish: complete CRUD flows, validation UX, module dashboards, broader Flutter parity.

## Recommended Next Step
Continue offline depth by replacing Flutter file-backed repositories with SQLite-backed repositories and adding a durable blob manifest for queued attachment uploads. Keep the current operation keys (`expenses.create_draft`, `invoices.create_draft`, `attachments.create_metadata`, `attachments.upload_binary`, `investments.create_price`) and conflict metadata fields (`retry_count`, `last_attempt_at`, `last_error`, `conflict_reason`) as the sync-state contract while migrating persistence.

## Files To Read First
1. `PROJECT_CONTEXT.md`
2. `docs/PROJECT_STATUS.md`
3. `docs/API_DOCUMENTATION.md`
4. `backend/internal/services/payroll.go`
5. `backend/internal/http/handlers/payroll.go`
6. `web/src/App.tsx`
7. `web/src/api/client.ts`
8. `docs/openapi.yaml`
